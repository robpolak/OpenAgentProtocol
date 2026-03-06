# OAP v0.1 Schema Catalog

JSON Schemas for the OpenAgentProtocol v0.1 specification.

Reference by URL: `https://openagentprotocol.dev/schemas/v0.1/<schema>.json`  
Or vendor locally: copy this directory into your project.

> The canonical URL is the `$id` used in `$ref` resolution. It may not be live yet. For local validation, use the `oap-validate` CLI or reference local file paths.

## Root

| Schema | Description |
|---|---|
| [oap.schema.json](./oap.schema.json) | Root document schema. Dispatches to kind-specific schemas via `kind` field. |

## Primitives

| Schema | Description |
|---|---|
| [agent.schema.json](./agent.schema.json) | Agent — persona, `model`/`model_tier`, tools, permissions, budget, `max_concurrent_tasks`. |
| [persona.schema.json](./persona.schema.json) | Structured identity — role, expertise, style, constraints, context. |
| [task.schema.json](./task.schema.json) | Task — inputs, typed outputs (with `visibility`), `needs` (DAG), `concurrency_group`, `priority`, `resource_locks`, approval, retry, budget, sub-workflow ref. |
| [policy.schema.json](./policy.schema.json) | Behavioral rule — trigger, gate (hard/soft), checks, actions. |
| [artifact.schema.json](./artifact.schema.json) | Persistent workspace file with lifecycle (per_task, per_workflow, persistent). |
| [permissions.schema.json](./permissions.schema.json) | Security sandbox — filesystem, network, shell, secrets, communication boundaries (`can_message`, `can_receive_from`, `can_handoff_to`). |

## Document Kinds

| Schema | Kind | Description |
|---|---|---|
| [workflow.schema.json](./workflow.schema.json) | `Workflow` | Static or dynamic task DAG. Includes phases, `planning` (dynamic DAG), build_policy, runtime (`model_tiers`, concurrency groups, resource locks, isolation), hooks, observability. |
| [agent-profile.schema.json](./agent-profile.schema.json) | `AgentProfile` | Reusable agent definition with policies, lifecycle, artifacts. |
| [workflow-template.schema.json](./workflow-template.schema.json) | `WorkflowTemplate` | Parameterized workflow. Typed parameters, defaults, `${params.*}` interpolation. |

## Coordination

| Schema | Description |
|---|---|
| [coordination/build-policy.schema.json](./coordination/build-policy.schema.json) | Epoch-based build coordination — strategy, timing, file ownership, error attribution. |

## Messages

| Schema | Description |
|---|---|
| [messages/envelope.schema.json](./messages/envelope.schema.json) | CloudEvents-inspired message envelope. Transport-agnostic. |
| [messages/types.schema.json](./messages/types.schema.json) | Well-known message types and payload schemas. |

## Versioning

Schemas are versioned by directory: `schemas/v0.1/`, `schemas/v0.2/`, etc.

- Breaking changes = new version directory
- Additive changes (new optional fields, new enum values) = same directory
- See [spec/VERSIONING.md](../../spec/VERSIONING.md) for full policy

## Extension Points

Every schema supports `x-*` prefixed fields for runtime-specific extensions:

```yaml
agents:
  - name: engineer
    model: claude-sonnet
    x-swarm:
      max_parallel_tools: 8
      checkpoint_interval: 60s
```

Runtimes MUST ignore unknown `x-*` fields. Runtimes MUST NOT require `x-*` fields for core behavior.
