# Observability Spec

What runtimes MUST and SHOULD log.

Standardizing log field names lets log aggregation tools (Datadog, Grafana Loki,
OpenSearch) work across any compliant runtime without per-runtime configuration.

## Scope

This spec covers structured diagnostic logs emitted to a file or stdout/stderr.
It does not cover OpenTelemetry tracing (see [SPEC.md](./SPEC.md) `observability.tracing`).

## Format

Runtimes MUST emit structured logs as newline-delimited JSON (NDJSON) when
writing to a log file. Each line is a complete JSON object.

Runtimes SHOULD also render human-readable output to stderr for interactive use.

## Required Fields

Every log event MUST include:

| Field | Type | Description |
|---|---|---|
| `time` | string (RFC3339) | Event timestamp |
| `level` | string | `DEBUG`, `INFO`, `WARN`, `ERROR` |
| `msg` | string | Human-readable event description |
| `component` | string | Subsystem (see below) |

## Component Values

| Component | Emitted by |
|---|---|
| `coordinator` | Workflow control plane |
| `epoch` | Build coordination state machine |
| `dag` | Task graph engine |
| `runtime` | Agent container lifecycle |
| `message_bus` | Inter-agent message routing |

## Required Events

### Workflow Events (component: coordinator)

| `msg` | Level | Required Fields |
|---|---|---|
| `workflow execution started` | INFO | `workflow`, `tasks` (count), `agents` (count) |
| `workflow completed` | INFO | `workflow`, `duration_ms`, `cost_usd`, `tokens_used` |
| `workflow failed` | ERROR | `workflow`, `error`, `duration_ms` |

### Task Events (component: coordinator)

| `msg` | Level | Required Fields |
|---|---|---|
| `task started` | INFO | `workflow`, `task`, `agent` |
| `task completed` | INFO | `workflow`, `task`, `agent`, `cost_usd` |
| `task failed` | ERROR | `workflow`, `task`, `agent`, `error` |
| `task skipped` | INFO | `workflow`, `task`, `when` (the expression that evaluated false) |

### Epoch Events (component: epoch)

| `msg` | Level | Required Fields |
|---|---|---|
| `epoch freeze started` | INFO | `epoch` (ID), `agent_count` |
| `epoch ack received` | INFO | `epoch`, `agent`, `acked_count`, `total_count` |
| `epoch build started` | INFO | `epoch`, `build_command` |
| `epoch build complete` | INFO | `epoch`, `status` (passed/failed), `error_count` |
| `epoch distributed` | INFO | `epoch`, `status`, `agents_notified` |
| `auto_ack applied` | WARN | `epoch`, `agent_count` — WARN because this bypasses agent coordination |
| `ack timeout reached` | WARN | `epoch`, `duration_ms` |

`auto_ack` MUST be logged at WARN level. It bypasses agent coordination: agents
that would have received `build.epoch_start` and had a chance to flush pending
writes instead proceed without acknowledgment. This is observable and should
surface in monitoring.

### Agent Container Events (component: runtime)

| `msg` | Level | Required Fields |
|---|---|---|
| `agent spawned` | INFO | `agent`, `runtime` (provider name), `pid` |
| `agent exited` | INFO | `agent`, `exit_code` |
| `agent silence detected` | WARN | `agent`, `task`, `silent_for_ms`, `threshold_ms` |
| `scanner buffer overflow` | WARN | `agent`, `bytes_dropped` (if available) |

### Loop Events (component: coordinator)

| `msg` | Level | Required Fields |
|---|---|---|
| `loop iteration started` | INFO | `task`, `iteration`, `max_iterations` |
| `loop exit_when triggered` | INFO | `task`, `iteration`, `expr` |
| `loop max iterations reached` | WARN or ERROR | `task`, `max_iterations`, `on_max_iterations` |

## Log Level Semantics

| Level | Use for |
|---|---|
| `DEBUG` | Per-message routing, heartbeats, internal state transitions |
| `INFO` | Workflow/task/epoch lifecycle events (structured above) |
| `WARN` | Recoverable issues: silence detection, ack timeout, auto_ack, buffer overflow |
| `ERROR` | Unrecoverable failures: task failed, workflow failed, build error |

## Log Directory

Runtimes SHOULD write one log file per workflow run.

Recommended default path: `~/.oap/logs/<workflow-name>-<timestamp>.log`

Runtimes SHOULD accept a `log_dir` configuration value that overrides the default path.

This can be declared in project config (`.oap/config.yaml`):

```yaml
log_level: debug
log_format: json
log_dir: ~/tmp/oa
```

When `log_dir` is set in workflow `runtime` config, the workflow-declared path takes
precedence over the user's global config.

## Querying Logs

Examples using `jq`:

```bash
# All task events for a workflow
jq 'select(.component == "coordinator" and .task != null)' run.log

# Epoch transitions only
jq 'select(.component == "epoch")' run.log

# Cost summary
jq 'select(.msg == "workflow completed") | {workflow, cost_usd, duration_ms}' run.log

# All WARN and ERROR events
jq 'select(.level == "WARN" or .level == "ERROR")' run.log

# Agent silence events
jq 'select(.msg == "agent silence detected")' run.log
```

## Conformance

Level 2 runtimes MUST:
- Write structured NDJSON log events to a file for each run
- Include all Required Events listed above at the correct log levels
- Accept `log_dir` as a configuration option

Level 1 runtimes MAY write human-readable logs to stderr only.
