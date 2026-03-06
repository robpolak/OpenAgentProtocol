# AGENTS.md

Instructions for AI agents working on this repo.

Read [KEY_TENETS.md](./KEY_TENETS.md) first. Tenets win all ties.

## Writing Voice

All prose in this repo follows these rules:

- **No AI voice.** No em dashes. No "leveraging" or "utilizing" or "it's important to note." Write like a senior engineer who's been shipping for 10 years and doesn't have time for filler.
- **Short sentences.** If a sentence has a comma, ask if it needs one.
- **Direct.** Say what something does. Don't say what it "aims to" or "strives to" do.
- **No hype.** No "revolutionary" or "cutting-edge" or "game-changing." The tech speaks for itself.
- **Periods over dashes.** Use periods to separate ideas. Not em dashes, not semicolons.
- **Tables over paragraphs.** If you're listing things, use a table.

Bad: "OAP provides a comprehensive, extensible framework that enables developers to seamlessly orchestrate multi-agent workflows across diverse runtime environments."

Good: "OAP is a spec for multi-agent workflows. Write a `.oap.yaml` file, run it on any compliant runtime."

## What This Repo Is

OAP is an open spec for multi-agent AI workflows. Like OpenAPI for REST or OCI for containers. This repo ships JSON schemas and reference examples. That's it. Users consume schemas in their own workspace. No fork, no PR.

## Repo Structure

```
schemas/v0.1/
  oap.schema.json              Root: dispatches by kind
  agent.schema.json            Agent (persona, model, tools, permissions, budget, max_concurrent_tasks, output_format)
  task-result.schema.json      TaskResult (status, summary, outputs, artifacts, build_ready, error, tokens_used)
  persona.schema.json          Structured identity (role, expertise, style, constraints)
  task.schema.json             Task (inputs, outputs, needs, concurrency_group, priority, resource_locks)
  policy.schema.json           Behavioral rule (trigger, gate, checks, actions)
  artifact.schema.json         Persistent workspace file
  permissions.schema.json      Security sandbox (filesystem, network, shell, secrets, communication, mcp)
  mcp.schema.json              MCP server definition (transport, command/url, auth, env, tools)
  workflow.schema.json         Workflow (phases, mcp_servers, runtime, concurrency, isolation, hooks)
  workflow-template.schema.json Parameterized workflow template
  agent-profile.schema.json    AgentProfile document kind
  coordination/
    build-policy.schema.json   Epoch-based build coordination
  messages/
    envelope.schema.json       Message envelope (CloudEvents-inspired)
    types.schema.json          Message type registry

spec/
  SPEC.md                      Definitive reference
  CONFORMANCE.md               Runtime conformance levels
  PROTOCOL.md                  Agent message protocol
  EPOCH_COORDINATION.md        Build coordination state machine
  PARALLELISM.md               Concurrency groups, resource locks, scheduling
  ISOLATION.md                 Communication boundaries, output visibility, sandboxing
  PERSONAS.md                  Structured agent identity
  VERSIONING.md                Spec versioning policy
  EXPRESSIONS.md               Expression syntax
  examples/                    .oap.yaml examples
    personas/                  Reusable persona examples

cmd/oap-validate/              Go CLI: validate .oap.yaml against schemas
```

## Core Primitives (v0.1)

| Primitive | Schema | Purpose |
|---|---|---|
| Agent | `agent.schema.json` | Who does the work. Persona, model/model_tier, tools, permissions, budget, `max_concurrent_tasks`, `principles`, `output_format` |
| TaskResult | `task-result.schema.json` | Structured result block. Emitted by agents when `output_format: structured`. Contains `status`, `outputs`, `artifacts`, `build_ready` |
| Persona | `persona.schema.json` | Structured identity. Role, expertise, style, constraints, context |
| Task | `task.schema.json` | Unit of work. Inputs, outputs, `needs` (DAG), `concurrency_group`, `priority`, `resource_locks`, approval, sub-workflow delegation |
| Policy | `policy.schema.json` | Behavioral rule. Trigger, gate (hard/soft), checks, actions |
| Artifact | `artifact.schema.json` | Persistent file. Plans, lessons, tracking docs |
| Permissions | `permissions.schema.json` | Security sandbox. Filesystem, network, shell, secrets, communication, MCP access |
| McpServer | `mcp.schema.json` | MCP server connection config. Transport, command/url, auth, env, tool declarations |
| BuildPolicy | `coordination/build-policy.schema.json` | Epoch coordination. Freeze/build/attribute/feedback |

Workflow-level config (declared inside `workflow.schema.json` or `agent-profile.schema.json`, not standalone primitives):

| Config | Location | Purpose |
|---|---|---|
| Runtime | `workflow.schema.json` | Timeout, concurrency groups, resource locks, isolation, model_tiers, env, budget |
| Hook | `workflow.schema.json` | Lifecycle callbacks: on_task_start, on_build_fail, etc. |
| Lifecycle | `agent-profile.schema.json` | Ordered phase template: plan, execute, review |
| Planning | `workflow.schema.json` | Dynamic DAG generation. Planner agent builds the task graph at runtime |

## Document Kinds

| Kind | Schema | Purpose |
|---|---|---|
| `Workflow` | `workflow.schema.json` | Concrete DAG of tasks |
| `AgentProfile` | `agent-profile.schema.json` | Reusable agent definition with policies and lifecycle |
| `WorkflowTemplate` | `workflow-template.schema.json` | Parameterized workflow pattern |

## Message Protocol

Transport-agnostic JSON messages. See [spec/PROTOCOL.md](./spec/PROTOCOL.md).

| Category | Types | Pattern |
|---|---|---|
| Signals | status, output, log | Fire-and-forget |
| Requests | task, query, handoff, approval | Expect response |
| Responses | result, ack | Reply to request |
| Events | lifecycle (started/completed/failed) | Broadcast |
| Build | intent, ready, file_conflict, build_started, epoch_start, ack, result | Epoch coordination |

## Build Coordination

See [spec/EPOCH_COORDINATION.md](./spec/EPOCH_COORDINATION.md).

State machine: **EPOCH WINDOW** > **FREEZE** > **BUILD** > **DISTRIBUTE** > loop.

Key concepts: file ownership registry, ACK collection with timeout, compiler error attribution, targeted error delivery (guilty agent gets errors, clean agents resume).

## Expression Syntax

See [spec/EXPRESSIONS.md](./spec/EXPRESSIONS.md).

Used in `when`, `trigger`, and `${}` interpolation. Simple and intentionally limited.

```
tasks.triage.outputs.severity == "critical"    # when condition
task.steps >= 3 OR task.has_architecture_decisions  # policy trigger
${tasks.diagnose.outputs.root_cause}           # interpolation
${AGENT_MODEL}                                 # env var
${params.service}                              # template parameter
${secrets.api_key}                             # secret reference
```

## Key References

- [spec/WORKFLOW_GUIDE.md](./spec/WORKFLOW_GUIDE.md) - LLM workflow guide. Token-efficient reference for building `.oap.yaml` files. Link this to any agent asked to write OAP workflows.
- [TECHNICAL.md](./TECHNICAL.md) - Full architecture, primitives, protocol, conformance, schema catalog, project structure.
- [spec/SPEC.md](./spec/SPEC.md) - Definitive normative spec. Resolves all ambiguities.
- [spec/CONFORMANCE.md](./spec/CONFORMANCE.md) - What runtimes must implement at each level.
- [spec/PARALLELISM.md](./spec/PARALLELISM.md) - Concurrency groups, resource locks, scheduling.
- [spec/ISOLATION.md](./spec/ISOLATION.md) - Communication boundaries, output visibility, sandboxing.
- [spec/LOOPS.md](./spec/LOOPS.md) - Loop execution and iterative agent cycles.
- [CHANGELOG.md](./CHANGELOG.md) - What changed per version.

## When Modifying the Spec

1. Does it align with [KEY_TENETS.md](./KEY_TENETS.md)?
2. Is it core or extension? Default: extension.
3. Can two independent runtimes produce the same observable result?
4. Does the simplest OAP file still fit in ~10 lines?
5. Schema first, then prose, then example.
6. Check [spec/SPEC.md](./spec/SPEC.md) for existing behavior before changing.
7. Follow [spec/VERSIONING.md](./spec/VERSIONING.md) for version bumps.
8. Update [CHANGELOG.md](./CHANGELOG.md).
9. Follow the writing voice rules above. No AI-sounding prose.
