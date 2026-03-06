# OAP Message Protocol v0.1

## Overview

The OAP Message Protocol defines how agents communicate with each other, with coordinators, and with the runtime. It is **transport-agnostic** — the same message format works over stdin/stdout, HTTP, WebSocket, gRPC, or message queues.

Design influences: CloudEvents (envelope), A2A (Parts), Temporal (Signal/Query taxonomy).

## Principles

1. **Envelope + Payload** — Every message has a fixed envelope (who, what, when) and a typed payload (the content). The envelope never changes; the payload varies by message type.
2. **Transport-agnostic** — The protocol defines message format, not delivery. Runtimes choose their transport.
3. **Extensible by default** — Custom message types use namespace prefixes. Extensions live in the `extensions` object. Unknown types MUST be ignored, not rejected.
4. **Typed payloads** — Each message type has a JSON Schema. Runtimes SHOULD validate payloads against the type's schema.

## Envelope

Every OAP message:

```json
{
  "oap_version": "0.1",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "signal.status",
  "source": "agent:backend-1",
  "target": "coordinator",
  "timestamp": "2026-03-05T14:30:00Z",
  "correlation_id": "task:migrate-models",
  "payload": { ... },
  "extensions": { }
}
```

| Field | Required | Description |
|---|---|---|
| `oap_version` | MUST | Always `"0.1"` |
| `id` | MUST | Unique message ID. UUID v4 recommended. |
| `type` | MUST | Message type in `category.action` format. |
| `source` | MUST | Sender: `agent:<name>`, `coordinator`, `runtime`, `user`. |
| `target` | SHOULD | Recipient. Omit for broadcast. |
| `timestamp` | MUST | ISO 8601. |
| `correlation_id` | MAY | Links related messages. Task name or request ID. |
| `reply_to` | MAY | Message ID this responds to. MUST be set for `response.*` types. |
| `payload` | MAY | Typed message body. Schema determined by `type`. |
| `parts` | MAY | Rich content: text, files, structured data. A2A-compatible. |
| `extensions` | MAY | Namespaced extensions under `x-*` keys. |

Responses MUST set `reply_to` to the `id` of the message they respond to.

## Addressing

```
agent:<name>       — A specific agent (e.g., agent:backend-1)
coordinator        — The workflow coordinator / orchestrator
runtime            — The execution runtime itself
user               — The human operator
*                  — Broadcast to all agents (use sparingly)
```

## Message Types

Four categories, inspired by Temporal's Signal/Query/Update taxonomy:

### Signals — Fire-and-forget, no response expected

| Type | Direction | Description |
|---|---|---|
| `signal.status` | Agent → Coordinator | Agent reports state (idle, working, blocked, done, error) with optional progress 0.0-1.0 |
| `signal.output` | Agent → Coordinator | Agent emits a named output value |
| `signal.log` | Agent → Runtime | Structured log entry (debug, info, warn, error) |

### Requests — Expect a response

| Type | Direction | Description |
|---|---|---|
| `request.task` | Coordinator → Agent | Assign a task with description, inputs, criteria, file scope, timeout |
| `request.query` | Any → Any | Ask a question, expect `response.result` |
| `request.handoff` | Agent → Agent | Hand off work with reason, context, and history filter |
| `request.approval` | Agent → User/Coordinator | Request approval before proceeding |

### Responses — Reply to a request

| Type | Direction | Description |
|---|---|---|
| `response.result` | Any → Any | Response with status (ok, error, rejected) and optional data |
| `response.ack` | Any → Any | Simple acknowledgment, no data |

### Events — System lifecycle notifications

| Type | Direction | Description |
|---|---|---|
| `event.lifecycle` | Runtime → All | Task/phase/workflow started, completed, or failed |

### Build Coordination — Well-known extension

See [EPOCH_COORDINATION.md](./EPOCH_COORDINATION.md) for the full state machine.

| Type | Direction | Description |
|---|---|---|
| `build.intent` | Agent → Coordinator | Declares files the agent intends to modify |
| `build.ready` | Agent → Coordinator | Agent finished editing, ready for build |
| `build.file_conflict` | Coordinator → Agent | Notifies agent of file ownership conflict |
| `build.build_started` | Coordinator → Agents | Build is now running (epoch_id + command) |
| `build.epoch_start` | Coordinator → Agents | Epoch begins, agents must freeze edits |
| `build.ack` | Agent → Coordinator | Agent acknowledges epoch freeze |
| `build.result` | Coordinator → Agents | Build/test outcome (passed/failed/timeout) with per-file error attribution |

## Parts (Rich Content)

Messages can carry rich content via the `parts` array, compatible with A2A:

```json
{
  "parts": [
    { "type": "text", "text": "Here's the analysis..." },
    { "type": "data", "data": { "severity": "critical", "root_cause": "null pointer" } },
    { "type": "file", "file": { "name": "fix.patch", "mime_type": "text/x-diff", "uri": "./patches/fix.patch" } }
  ]
}
```

## Custom Message Types

Runtimes add custom types with a namespace prefix:

```json
{
  "type": "x-swarm.dag_replan",
  "source": "coordinator",
  "target": "*",
  "payload": {
    "reason": "Task dependency changed",
    "new_dag": { ... }
  }
}
```

Rules for custom types:
- MUST be prefixed with `x-<namespace>.`
- MUST be documented in the runtime's extension spec
- Runtimes MUST ignore unknown types (not reject)

## Examples

### Agent reports progress on a task

```json
{
  "oap_version": "0.1",
  "id": "a1b2c3d4-0001",
  "type": "signal.status",
  // Note: IDs here are abbreviated for readability. Use UUID v4 in practice.
  "source": "agent:backend-1",
  "target": "coordinator",
  "timestamp": "2026-03-05T14:30:00Z",
  "correlation_id": "task:migrate-models",
  "payload": {
    "state": "working",
    "message": "Migrating user model to JWT schema",
    "progress": 0.4
  }
}
```

### Coordinator assigns a task

```json
{
  "oap_version": "0.1",
  "id": "a1b2c3d4-0002",
  "type": "request.task",
  "source": "coordinator",
  "target": "agent:backend-1",
  "timestamp": "2026-03-05T14:00:00Z",
  "payload": {
    "task_name": "migrate-models",
    "description": "Migrate user/session models to JWT token schema",
    "inputs": { "migration_plan": "..." },
    "success_criteria": ["All tests pass", "No data loss"],
    "file_scope": ["src/models/", "src/db/migrations/"],
    "timeout": "30m"
  }
}
```

### Agent hands off to another agent

```json
{
  "oap_version": "0.1",
  "id": "a1b2c3d4-0003",
  "type": "request.handoff",
  "source": "agent:backend-1",
  "target": "agent:backend-2",
  "timestamp": "2026-03-05T15:00:00Z",
  "correlation_id": "task:migrate-middleware",
  "payload": {
    "reason": "Auth middleware touches shared session code — needs middleware specialist",
    "context": {
      "files_modified": ["src/models/user.ts", "src/models/session.ts"],
      "notes": "JWT schema is in place, middleware needs to validate against it"
    },
    "history_filter": "summary"
  }
}
```

### Build epoch lifecycle

```json
// 1. Agent declares file intent
{ "type": "build.intent", "source": "agent:backend-1", "payload": { "files": ["src/models/user.ts"] } }

// 2. Agent finishes editing
{ "type": "build.ready", "source": "agent:backend-1", "payload": { "files_changed": ["src/models/user.ts"] } }

// 3. Coordinator triggers epoch
{ "type": "build.epoch_start", "source": "coordinator", "target": "*", "payload": { "epoch_id": "epoch-7", "deadline": "2026-03-05T15:05:00Z" } }

// 4. Agent acknowledges freeze
{ "type": "build.ack", "source": "agent:backend-1", "payload": { "epoch_id": "epoch-7" } }

// 5. Build result with attribution
{
  "type": "build.result",
  "source": "coordinator",
  "target": "*",
  "payload": {
    "epoch_id": "epoch-7",
    "status": "failed",
    "errors": [
      { "file": "src/models/user.ts", "line": 42, "message": "Property 'sessionId' does not exist", "attributed_to": "backend-1" }
    ],
    "test_results": { "passed": 87, "failed": 2, "skipped": 0 }
  }
}
```

## Transport Bindings

OAP does not mandate a transport. Runtimes SHOULD document which transports they support.

| Transport | Encoding | Notes |
|---|---|---|
| **stdin/stdout** | Newline-delimited JSON (NDJSON) | One message per line. Simplest for subprocess agents. |
| **HTTP** | JSON POST to endpoint | Compatible with A2A's JSON-RPC pattern. |
| **WebSocket** | JSON frames | For real-time bidirectional communication. |
| **Message Queue** | JSON payloads | For distributed systems (Redis, NATS, etc.). |

For stdin/stdout (the common case with coding agents), each message is a single line of JSON terminated by `\n`:

```
{"oap_version":"0.1","id":"...","type":"signal.status","source":"agent:backend-1",...}\n
{"oap_version":"0.1","id":"...","type":"build.intent","source":"agent:backend-1",...}\n
```

## Relationship to Other Protocols

| Protocol | Relationship |
|---|---|
| **MCP** | MCP defines tool call/result messages. OAP messages are for agent-level coordination, not tool invocation. An agent may use MCP internally to call tools while using OAP externally to coordinate with other agents. |
| **A2A** | A2A defines agent-to-agent task delegation. OAP messages are compatible (same Part types) but operate within a coordinated workflow, not between independent services. |
| **CloudEvents** | OAP envelope is inspired by CloudEvents. An OAP message can be wrapped in a CloudEvents envelope for event-driven systems. |

## Related Docs

- [EPOCH_COORDINATION.md](./EPOCH_COORDINATION.md) — Build coordination state machine and delivery model
- [EXPRESSIONS.md](./EXPRESSIONS.md) — Expression syntax for conditions and interpolation
- [PERSONAS.md](./PERSONAS.md) — Structured agent identity
- [schemas/v0.1/messages/](../schemas/v0.1/messages/) — Message schemas
