# Epoch Coordination Spec v0.1

## Overview

When multiple agents edit the same codebase, someone has to build and test it. The epoch model solves this: agents work freely during an **epoch window**, then a **coordinator** freezes all agents, runs build + test, attributes errors to the responsible agent, and releases agents to continue.

Build coordination manages concurrent agent edits to a shared codebase.

## The Epoch State Machine

```
                    ┌─────────────────────────────────────────────┐
                    │              EPOCH WINDOW                    │
                    │  Agents work freely. Coordinator watches.    │
                    │                                             │
                    │  Agents emit:                               │
                    │    build.intent  → "I plan to edit X"       │
                    │    build.ready   → "I'm done editing"       │
                    │    signal.status → progress updates          │
                    └──────────────────┬──────────────────────────┘
                                       │
                              Trigger fires
                         (timer / all ready / manual)
                                       │
                                       ▼
                    ┌─────────────────────────────────────────────┐
                    │                 FREEZE                       │
                    │  Coordinator broadcasts: build.epoch_start   │
                    │  Agents MUST stop editing and ACK.           │
                    │                                             │
                    │  Coordinator collects:                      │
                    │    build.ack from each active agent          │
                    │                                             │
                    │  Timeout: unresponsive agents are marked     │
                    │  frozen-by-default after grace period.       │
                    └──────────────────┬──────────────────────────┘
                                       │
                              All ACKs received
                              (or grace period expires)
                                       │
                                       ▼
                    ┌─────────────────────────────────────────────┐
                    │                 BUILD                        │
                    │  Coordinator runs: build_command              │
                    │  Broadcasts: build.build_started              │
                    │                                             │
                    │  If build passes:                           │
                    │    Coordinator runs: test_command             │
                    │                                             │
                    │  Coordinator parses output, maps errors      │
                    │  to agents via file ownership registry.      │
                    └──────────────────┬──────────────────────────┘
                                       │
                              Build + test complete
                                       │
                                       ▼
                    ┌─────────────────────────────────────────────┐
                    │               DISTRIBUTE                     │
                    │                                             │
                    │  If passed:                                 │
                    │    Broadcast: build.result (status: passed)  │
                    │    All agents resume work.                   │
                    │                                             │
                    │  If failed:                                 │
                    │    Targeted: build.result to responsible     │
                    │    agent with attributed errors.             │
                    │    Other agents: build.result (passed,       │
                    │    their files are clean).                   │
                    │    Responsible agent fixes before next epoch.│
                    └──────────────────┬──────────────────────────┘
                                       │
                                       ▼
                              Back to EPOCH WINDOW
```

## Epoch Triggers

What causes a transition from EPOCH WINDOW → FREEZE:

| Strategy | Trigger | Use Case |
|---|---|---|
| `epoch_batched` | Timer fires (`epoch_interval`) | Default. Predictable cadence. Good for 2+ agents with independent tasks. |
| `on_task_complete` | Any agent completes its task | Tight feedback loop. Good for sequential dependencies. |
| `continuous` | Any `build.ready` signal | Most aggressive. Build after every agent finishes editing. |
| `gated` | Explicit gate condition (e.g., all agents in phase ready) | Phase transitions. Build before entering review phase. |
| `manual` | Human triggers via `request.approval` | Full control. Good for high-risk changes. |

## build_policy Scope

`build_policy` applies to all agents with tasks in the workflow. During FREEZE, the coordinator broadcasts `build.epoch_start` to every active agent in that set and waits for ACKs before proceeding to BUILD.

Agents not in the workflow — such as agents in a sub-workflow with its own `build_policy` — are unaffected by the parent's epoch. Sub-workflows coordinate builds independently.

## Message Delivery Model

### How the coordinator talks to agents

The coordinator maintains a **connection** to each active agent. The connection type depends on the transport:

| Transport | Coordinator → Agent | Agent → Coordinator |
|---|---|---|
| **stdin/stdout** | Write NDJSON to agent's stdin pipe | Read NDJSON from agent's stdout pipe |
| **HTTP** | POST to agent's callback URL | Agent POSTs to coordinator endpoint |
| **WebSocket** | Send JSON frame on agent's socket | Agent sends JSON frame on same socket |

For stdin/stdout (the common case with subprocess coding agents):

```
Coordinator process
  ├── Agent "backend-1" subprocess
  │     stdin  ← coordinator writes build.epoch_start, request.task, build.result
  │     stdout → coordinator reads build.intent, build.ready, build.ack, signal.status
  │
  ├── Agent "backend-2" subprocess
  │     stdin  ← coordinator writes ...
  │     stdout → coordinator reads ...
  │
  └── Agent "reviewer" subprocess
        stdin  ← coordinator writes ...
        stdout → coordinator reads ...
```

### Broadcast delivery

When the coordinator sends `build.epoch_start` (target: `*`), it MUST:

1. Write the message to **every** active agent's input channel
2. Start an ACK collection timer (`ack_timeout`)
3. Track which agents have ACK'd

```json
// Coordinator writes to EVERY agent's stdin:
{"oap_version":"0.1","id":"e7-start","type":"build.epoch_start","source":"coordinator","target":"*","timestamp":"2026-03-05T15:00:00Z","payload":{"epoch_id":"epoch-7","deadline":"2026-03-05T15:00:30Z"}}
```

### Targeted delivery

When the coordinator sends `build.result` with errors attributed to a specific agent, it sends **different messages** to different agents:

```json
// To agent:backend-1 (responsible for the error):
{"type":"build.result","target":"agent:backend-1","payload":{"epoch_id":"epoch-7","status":"failed","errors":[{"file":"src/models/user.ts","line":42,"message":"Property 'sessionId' does not exist","attributed_to":"backend-1"}]}}

// To agent:backend-2 (not responsible, can resume):
{"type":"build.result","target":"agent:backend-2","payload":{"epoch_id":"epoch-7","status":"passed","errors":[]}}
```

The responsible agent gets the full error list. Other agents get a clean result and resume immediately.

### Collection (ACK gathering)

After broadcasting `build.epoch_start`, the coordinator reads from all agent output channels and collects `build.ack` messages:

```
coordinator reads from backend-1 stdout: {"type":"build.ack","source":"agent:backend-1","payload":{"epoch_id":"epoch-7"}}
coordinator reads from backend-2 stdout: {"type":"build.ack","source":"agent:backend-2","payload":{"epoch_id":"epoch-7"}}
```

Once all active agents ACK (or `ack_timeout` expires), the coordinator proceeds to BUILD.

### auto_ack

Some agent runtimes (e.g., subprocess coding agents that read stdin/stdout but don't
implement the OAP message protocol) cannot parse `build.epoch_start` and respond with
`build.ack`. Setting `auto_ack: true` on `build_policy` causes the coordinator to
immediately ACK all agents without waiting for explicit `build.ack` messages.

**This bypasses agent coordination.** Agents that would have received `build.epoch_start`
and had a chance to flush pending writes before the build starts instead proceed with no
acknowledgment. The build may capture a partially-written file.

Runtimes MUST log `auto_ack applied` at **WARN** level (not INFO) when this path fires.
The log entry MUST include the epoch ID and agent count. This makes the bypass visible
in monitoring without requiring operators to know the `build_policy` config.

```yaml
# Only use auto_ack for runtimes that cannot send build.ack
build_policy:
  auto_ack: true  # logs WARN: "auto_ack applied" on every epoch cycle
```

Prefer `output_format: structured` with `build_ready: true` in the agent's `oap-result`
block over `auto_ack`. When an agent emits `build_ready: true`, the coordinator marks
that agent ready without needing an explicit ACK. This preserves the agent's ability to
signal when it has truly finished editing.

## File Ownership Registry

The coordinator maintains a runtime map of `file_path → agent_name`, built from two sources:

1. **Static**: `file_scope` declared in the workflow's task definitions
2. **Dynamic**: `build.intent` messages from agents declaring files they plan to edit

```
File Registry (epoch-7):
  src/models/user.ts       → backend-1 (from build.intent)
  src/models/session.ts    → backend-1 (from build.intent)
  src/middleware/auth.ts    → backend-2 (from task.file_scope)
  src/middleware/jwt.ts     → backend-2 (from build.intent)
```

### Conflict detection

When an agent emits `build.intent` for a file already owned by another agent:

| Strategy | Behavior |
|---|---|
| `first_writer_wins` | Second agent's intent is rejected. Coordinator sends `response.result` with `status: rejected`. |
| `orchestrator_mediated` | Coordinator decides based on task priority. May reassign or queue. |
| `sequential_access` | Second agent is queued. Coordinator sends `signal.status` with `state: waiting`. |
| `merge_attempt` | Both agents edit. Coordinator attempts merge at build time. Conflicts become build errors. |

Conflict detection message from coordinator:

```json
{"type":"build.file_conflict","source":"coordinator","target":"agent:backend-2","payload":{"file":"src/models/user.ts","owned_by":"backend-1","resolution":"first_writer_wins","action":"choose_different_file"}}
```

## Error Attribution

When a build fails, the coordinator parses compiler/test output and maps errors to agents:

### Attribution strategies

| Strategy | How It Works |
|---|---|
| `compiler_error_mapping` | Parse `file:line: error: message` from compiler output. Look up file in registry. Attribute to owning agent. |
| `file_ownership` | Any error in a file owned by agent X is attributed to agent X. Simpler but less precise. |
| `none` | No attribution. All agents receive the full error list. |

### Unattributed errors

Errors in files not owned by any agent (shared infrastructure, generated files, dependency issues) are:

1. Sent to all agents as `integration_errors` in the build result
2. Optionally escalated to the coordinator for manual resolution

```json
{
  "type": "build.result",
  "target": "*",
  "payload": {
    "epoch_id": "epoch-7",
    "status": "failed",
    "errors": [
      { "file": "src/models/user.ts", "line": 42, "message": "Property 'sessionId' does not exist", "attributed_to": "backend-1" }
    ],
    "integration_errors": [
      { "file": "src/generated/types.ts", "line": 1, "message": "Module not found", "attributed_to": null }
    ],
    "test_results": { "passed": 87, "failed": 2, "skipped": 0 }
  }
}
```

## Timeout and Failure Handling

### ACK timeout

If an agent doesn't ACK within `ack_timeout`:

1. Coordinator sends `request.query` to the agent
2. If no response within `ack_grace_period`, agent is marked **frozen-by-default**
3. Build proceeds. If the unresponsive agent had pending edits, its files are included as-is.
4. If build fails on that agent's files, coordinator sends `build.result` when agent eventually responds.

### Build timeout

If `build_command` or `test_command` exceeds `build_timeout`:

1. Coordinator kills the build process
2. Broadcasts `build.result` with `status: "timeout"`
3. All agents resume. Next epoch retries.

### Agent crash

If an agent's process exits during an epoch:

1. Coordinator detects closed stdin/stdout pipe
2. Agent is removed from active agent list and file registry
3. Coordinator may reassign the agent's tasks (if workflow policy allows)
4. Build proceeds without the crashed agent's pending changes

## Coordinator Lifecycle Messages

Complete message sequence for one epoch:

```
TIME   SOURCE          TYPE                  TARGET       NOTES
─────────────────────────────────────────────────────────────────
t+0    backend-1       build.intent          coordinator  "I'll edit user.ts"
t+1    backend-2       build.intent          coordinator  "I'll edit auth.ts"
t+10   backend-1       signal.status         coordinator  progress: 0.6
t+20   backend-1       build.ready           coordinator  "Done editing"
t+25   backend-2       build.ready           coordinator  "Done editing"

       ── epoch_interval fires ──

t+30   coordinator     build.epoch_start     *            epoch-7, deadline t+60
t+31   backend-1       build.ack             coordinator  epoch-7
t+32   backend-2       build.ack             coordinator  epoch-7

       ── all ACKs received ──

t+33   coordinator     build.build_started   *            "Running make build"
t+45   coordinator     build.result          *            epoch-7, passed/failed + attribution

       ── agents resume ──

t+46   backend-1       build.intent          coordinator  Next edit cycle begins
```

## Related Schemas

- [`coordination/build-policy.schema.json`](../schemas/v0.1/coordination/build-policy.schema.json) — BuildPolicy primitive (strategy, timing, file ownership, error attribution)
- [`messages/types.schema.json`](../schemas/v0.1/messages/types.schema.json) — All build message types (intent, ready, file_conflict, build_started, epoch_start, ack, result)
- [`messages/envelope.schema.json`](../schemas/v0.1/messages/envelope.schema.json) — Message envelope format

## Related Docs

- [PROTOCOL.md](./PROTOCOL.md) — Full message protocol spec
- [EXPRESSIONS.md](./EXPRESSIONS.md) — Expression syntax for `when` conditions
