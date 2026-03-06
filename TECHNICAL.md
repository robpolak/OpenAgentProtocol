# OAP Technical Reference

Architecture, primitives, protocol, conformance, and project structure.

For the definitive normative spec: [spec/SPEC.md](./spec/SPEC.md).  
For building workflows: [spec/WORKFLOW_GUIDE.md](./spec/WORKFLOW_GUIDE.md).

---

## Architecture

OAP sits one layer above MCP and A2A. It defines the workflow — who runs, what they do, how they coordinate. It does not replace tool execution (MCP) or agent discovery (A2A).

```
┌────────────────────────────────────────────────┐
│              Your Application                   │
├────────────────────────────────────────────────┤
│          OAP  (.oap.yaml files)                 │  ← workflows, agents, policies
│  Agents · Tasks · Loops · Build Coordination   │
│  Messages · Personas · Permissions · Isolation  │
├──────────┬──────────┬──────────────────────────┤
│   MCP    │   A2A    │  Runtime Extensions       │  ← tools, agent discovery
│  (tools) │ (comms)  │  (x-swarm, x-crewai)     │
├──────────┴──────────┴──────────────────────────┤
│    Runtime  (Swarm, CLI, CrewAI, custom)        │  ← execution
└────────────────────────────────────────────────┘
```

Two runtimes given the same `.oap.yaml` MUST produce the same observable outcomes.

---

## Document Kinds

| Kind | Schema | Purpose |
|---|---|---|
| `Workflow` | `workflow.schema.json` | Concrete DAG of tasks with agents, phases, or dynamic planning |
| `AgentProfile` | `agent-profile.schema.json` | Reusable agent definition — persona, policies, lifecycle |
| `WorkflowTemplate` | `workflow-template.schema.json` | Parameterized workflow pattern |

Every OAP file:

```yaml
oap_version: "0.1"   # required
kind: Workflow        # required
metadata:
  name: my-workflow   # required. ^[a-z][a-z0-9-]*$
```

---

## Core Primitives

| Primitive | Schema | What It Does |
|---|---|---|
| **Agent** | `agent.schema.json` | Who does the work. Model/model_tier, tools, persona, permissions, budget, principles, output_format. |
| **Persona** | `persona.schema.json` | Structured agent identity. Role, expertise, style, constraints, context. Inheritable via `extends`. |
| **Task** | `task.schema.json` | Unit of work. Inputs, typed outputs, `needs` (DAG), `when`, loops, approval gates, retry, sub-workflow delegation. |
| **Policy** | `policy.schema.json` | Behavioral rule. Trigger condition, hard/soft gate, checks, actions. Applied at task start, completion, or events. |
| **Artifact** | `artifact.schema.json` | Persistent workspace file. Tracked across agents; registered in the file ownership registry during epoch coordination. |
| **Permissions** | `permissions.schema.json` | Agent security sandbox. Filesystem, network, shell, secrets, communication boundaries, MCP access. |
| **McpServer** | `mcp.schema.json` | MCP server connection config. Transport (stdio/sse/http), auth, env, tool declarations. |
| **BuildPolicy** | `coordination/build-policy.schema.json` | Epoch coordination. Freeze/build/attribute/feedback cycle for multi-agent codebase editing. |

Workflow-level config (declared inside `Workflow`, not standalone):

| Config | Location | Purpose |
|---|---|---|
| Runtime | `workflow.schema.json` | Timeout, concurrency groups, resource locks, isolation, model_tiers, env, budget |
| Hook | `workflow.schema.json` | Lifecycle callbacks: on_task_start, on_build_fail, on_loop_iteration, etc. |
| Planning | `workflow.schema.json` | Dynamic DAG generation by a planner agent at runtime |
| Loop | `task.schema.json` | Iterative execution on a task or phase |

---

## Execution Models

Three modes — a workflow uses exactly one:

| Mode | Field | When to Use |
|---|---|---|
| Static flat | `tasks` | Task list is fully known upfront |
| Static phased | `phases` | Tasks group into ordered stages |
| Dynamic | `planning` | Task list depends on runtime discovery by a planner agent |

`planning` + `tasks` is valid: static tasks run as seeds, planner adds more.

---

## Loops

Tasks and phases can declare a `loop` block for iterative refinement cycles.

Key design: **fresh context per iteration** (default). Each iteration spawns a new agent session with filesystem artifacts injected. Avoids the context window degradation that compounds in long sessions.

```yaml
- name: implement
  agent: coder
  loop:
    max_iterations: 5
    exit_when: "tasks.implement.outputs.tests_pass == true"
    on_max_iterations: escalate   # fail | escalate | continue_last
    context:
      strategy: fresh             # fresh (default) | reuse
      summary_output: loop_summary
```

Exit criteria must reference typed, required outputs — not free-form agent judgment. Machine-verifiable conditions only (test pass/fail, quality scores, build status).

Multiple loops compose in the DAG via `needs`. Nested loops are rejected.

Full spec: [spec/LOOPS.md](./spec/LOOPS.md).

---

## Concurrency and Scheduling

Four mechanisms control parallelism:

| Mechanism | Field | Scope |
|---|---|---|
| Concurrency groups | `task.concurrency_group` + `runtime.concurrency` | Named groups with `max_parallel` |
| Resource locks | `task.resource_locks` | Named mutexes; acquired alphabetically to prevent deadlock |
| Agent concurrency | `agent.max_concurrent_tasks` | Per-agent task parallelism (default 1) |
| Global cap | `runtime.max_concurrent_agents` | Hard ceiling on total parallel agents |

When tasks compete for a slot: `queue: priority` uses `task.priority` (0–100, higher first). Default: `fifo`.

Full spec: [spec/PARALLELISM.md](./spec/PARALLELISM.md).

---

## Isolation

Six independent isolation controls:

| Primitive | Scope | Controls |
|---|---|---|
| `permissions.filesystem` | Per-agent | File read/write paths |
| `permissions.network` | Per-agent | Host-level network access |
| `permissions.shell` | Per-agent | Shell command execution |
| `permissions.communication` | Per-agent | Which agents can be messaged |
| `output.visibility` | Per-output | Which agents can read a specific output |
| `runtime.isolation` | Workflow | Process/container boundaries, filesystem/network sharing |

Isolation levels: `shared` (one process), `process` (default), `container` (OCI per agent).

Full spec: [spec/ISOLATION.md](./spec/ISOLATION.md).

---

## Build Coordination (Epoch Model)

For multi-agent workflows that edit a shared codebase, OAP defines an epoch-based coordination model.

State machine: **WINDOW → FREEZE → BUILD → DISTRIBUTE → loop**

- Agents signal `build.ready` when finished writing files
- Coordinator freezes edits, runs the build/test command
- Errors are attributed per-file to the agent that last wrote it
- Guilty agent gets its errors. Clean agents resume.

Five strategies: `epoch_batched`, `on_task_complete`, `continuous`, `gated`, `manual`.

Full spec: [spec/EPOCH_COORDINATION.md](./spec/EPOCH_COORDINATION.md).

---

## Message Protocol

Transport-agnostic JSON messages over stdin/stdout, HTTP, WebSocket, or message queues.

| Category | Types |
|---|---|
| Signals | `signal.status`, `signal.output`, `signal.log` |
| Requests | `request.task`, `request.query`, `request.handoff`, `request.approval` |
| Responses | `response.result`, `response.ack` |
| Events | `event.lifecycle` (task/phase/workflow/loop lifecycle) |
| Build | `build.intent`, `build.ready`, `build.ack`, `build.result`, `build.epoch_start` |

CloudEvents-inspired envelope. A2A-compatible `parts` array.

Full spec: [spec/PROTOCOL.md](./spec/PROTOCOL.md).

---

## Structured Agent Output

When `output_format: structured` is set on an agent, the runtime:

1. Injects a closing instruction requiring an `oap-result` fenced block as final output
2. Parses the last such block as the authoritative TaskResult
3. Promotes its fields to `signal.output`, `signal.artifact`, and epoch ready signals

```json
{
  "status": "ok",
  "summary": "Implemented auth fix",
  "outputs": { "tests_pass": true },
  "artifacts": ["src/auth/handler.go"],
  "build_ready": true
}
```

Eliminates heuristic JSON extraction. Required for reliable output interpolation in downstream tasks.

---

## Expressions

Used in `when` (task conditions), `trigger` (policy conditions), and `${}` (interpolation).

```yaml
when: tasks.triage.outputs.severity == "critical"
when: tasks.a.outputs.ok == true AND tasks.b.outputs.ok == true
description: "Fix ${tasks.diagnose.outputs.root_cause} in ${params.service}"
```

Operators: `==` `!=` `>` `>=` `<` `<=`. Connectives: `AND`, `OR`.

Not a general-purpose language. No function calls, arithmetic, or string manipulation. Complex logic belongs in a task that computes the value.

Full spec: [spec/EXPRESSIONS.md](./spec/EXPRESSIONS.md).

---

## Conformance Levels

| Level | Name | Key Requirements |
|---|---|---|
| 1 | Core | Parse documents, execute `tasks` DAG respecting `needs`, `${ENV_VAR}` interpolation |
| 2 | Coordination | Multiple concurrent agents, `phases`, `when`, `retry`, `on_failure`, output interpolation |
| 3 | Full | Epoch coordination, loops, dynamic planning, `AgentProfile`, structured output, MCP |

Loop support is optional at Level 1–2. Required at Level 3.

Full spec: [spec/CONFORMANCE.md](./spec/CONFORMANCE.md).

---

## Schema Catalog

All schemas live in `schemas/v0.1/`. Versioned by major.minor. Reference by URL or vendor locally.

| Schema | Purpose |
|---|---|
| `oap.schema.json` | Root dispatcher — validates any OAP document by kind |
| `workflow.schema.json` | Workflow: tasks, phases, planning, runtime, hooks, build_policy |
| `agent.schema.json` | Agent: model, persona, tools, permissions, budget, output_format |
| `task.schema.json` | Task: inputs, outputs, needs, when, loop, approval, retry |
| `task-result.schema.json` | Structured agent output (oap-result block) |
| `persona.schema.json` | Agent identity: role, expertise, style, constraints |
| `policy.schema.json` | Behavioral rule: trigger, gate, checks, actions |
| `artifact.schema.json` | Persistent workspace file |
| `permissions.schema.json` | Security sandbox |
| `mcp.schema.json` | MCP server connection config |
| `agent-profile.schema.json` | Reusable agent profile with lifecycle |
| `workflow-template.schema.json` | Parameterized workflow template |
| `coordination/build-policy.schema.json` | Epoch build coordination |
| `messages/envelope.schema.json` | Message envelope |
| `messages/types.schema.json` | Message type registry |

---

## Workspace Directory (`.oa/`)

Every project directory that uses the OAP CLI gets a `.oa/` workspace folder.
Each plan run is stored in its own subdirectory identified by a UUID.

```
.oa/
  .gitignore              keeps workflow files, ignores run artifacts
  {uuid}/
    workflow.yaml         the generated OAP workflow
    state.jsonl           append-only lifecycle event log (JSONL)
    run.log               structured runtime logs for the last run
```

### state.jsonl format

Each line is a JSON object. Field names mirror the OAP `event.lifecycle` protocol.

```json
{"ts":"2026-03-06T14:23:00Z","event":"plan_created","guid":"abc-123","workflow_name":"dead-api-removal"}
{"ts":"2026-03-06T14:24:00Z","event":"run_started","guid":"abc-123","pid":12345}
{"ts":"2026-03-06T14:25:00Z","event":"task_started","task":"query-datadog","agent":"datadog-analyst"}
{"ts":"2026-03-06T14:27:00Z","event":"task_completed","task":"query-datadog","status":"ok"}
{"ts":"2026-03-06T14:30:00Z","event":"run_completed","status":"ok","cost_usd":0.42,"tokens_used":18400}
```

| Event | Written by | Meaning |
|---|---|---|
| `plan_created` | `oa plan` | Workflow YAML saved to `.oa/{guid}/` |
| `run_started` | `oa run` | Coordinator started, PID recorded |
| `task_started` | coordinator | Task dispatched to agent |
| `task_completed` | coordinator | Task finished ok |
| `task_failed` | coordinator | Task finished with error |
| `run_completed` | `oa run` | Workflow finished successfully |
| `run_failed` | `oa run` | Workflow finished with error |

### Status derivation

| Status | Condition |
|---|---|
| `pending` | `plan_created` exists, no `run_started` |
| `running` | `run_started` exists, no terminal event |
| `completed` | `run_completed` with `status: ok` |
| `failed` | `run_failed` or `run_completed` with error |

### Gitignore

`oa` adds `.oa/` to the user's global gitignore on first run (`~/.config/git/ignore` or `~/.gitignore_global`). The `.oa/.gitignore` inside the folder additionally ignores `state.jsonl` and `run.log` per-plan, but not `workflow.yaml` — so you can commit workflows if you choose.

### CLI commands

```bash
oa plan --template software_generic   # creates .oa/{guid}/workflow.yaml
oa ls                                 # list all plans and their status
oa run .oa/{guid}/workflow.yaml       # execute a plan, writes state events
```

---

## Project Structure

```
schemas/v0.1/              JSON Schemas (the portable product)
  messages/                Message protocol schemas
  coordination/            Build coordination schemas
spec/                      Specification prose
  SPEC.md                  Definitive normative reference
  CONFORMANCE.md           Runtime conformance levels
  PROTOCOL.md              Agent message protocol
  EPOCH_COORDINATION.md    Build coordination state machine
  PARALLELISM.md           Concurrency groups, resource locks, scheduling
  ISOLATION.md             Communication boundaries, output visibility, sandboxing
  PERSONAS.md              Structured agent identity
  LOOPS.md                 Loop execution — iterative agent cycles
  EXPRESSIONS.md           Expression syntax
  VERSIONING.md            Spec versioning policy
  WORKFLOW_GUIDE.md        LLM-optimized reference for building .oap.yaml files
  examples/                15 complete .oap.yaml files
cmd/oap-validate/          Go CLI validator
research/                  Prior art analysis, competitive landscape
```

---

## All Docs

| Document | Purpose |
|---|---|
| [spec/SPEC.md](./spec/SPEC.md) | Definitive normative specification |
| [spec/CONFORMANCE.md](./spec/CONFORMANCE.md) | Runtime conformance levels |
| [spec/PROTOCOL.md](./spec/PROTOCOL.md) | Agent message protocol |
| [spec/EPOCH_COORDINATION.md](./spec/EPOCH_COORDINATION.md) | Build coordination state machine |
| [spec/PARALLELISM.md](./spec/PARALLELISM.md) | Concurrency groups, resource locks, scheduling |
| [spec/ISOLATION.md](./spec/ISOLATION.md) | Communication boundaries, output visibility, sandboxing |
| [spec/PERSONAS.md](./spec/PERSONAS.md) | Structured agent identity |
| [spec/LOOPS.md](./spec/LOOPS.md) | Loop execution — iterative agent cycles |
| [spec/EXPRESSIONS.md](./spec/EXPRESSIONS.md) | Expression syntax |
| [spec/VERSIONING.md](./spec/VERSIONING.md) | Versioning policy |
| [spec/WORKFLOW_GUIDE.md](./spec/WORKFLOW_GUIDE.md) | LLM-optimized workflow building reference |
| [spec/examples/](./spec/examples/) | 15 runnable `.oap.yaml` examples |
| [schemas/v0.1/](./schemas/v0.1/) | All JSON Schemas |
| [CHANGELOG.md](./CHANGELOG.md) | What changed per version |
| [KEY_TENETS.md](./KEY_TENETS.md) | Mission, tenets, design principles |
| [MANIFESTO.md](./MANIFESTO.md) | Why this exists |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | How to contribute |
| [AGENTS.md](./AGENTS.md) | Instructions for AI agents working on this repo |
