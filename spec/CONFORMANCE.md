# Runtime Conformance

What it means to implement OAP.

## Conformance Levels

### Level 1: Core (minimum viable runtime)

A Level 1 runtime MUST:

- Parse `oap_version`, `kind`, and `metadata` from any `.oap.yaml` file
- Reject documents with unknown or unsupported `oap_version`
- Reject documents with unknown `kind`
- Support `kind: Workflow` with `agents` and `tasks`
- Resolve `${ENV_VAR}` interpolation in string fields
- Execute tasks respecting `needs` dependency order
- Assign tasks to named agents
- Report task completion or failure
- Ignore unknown `x-*` extension fields without error

A Level 1 runtime MAY:

- Support only a single agent (execute tasks sequentially)
- Ignore `phases` (treat all tasks as flat DAG)
- Ignore `build_policy`
- Ignore `observability`
- Ignore `hooks`

### Level 2: Coordination

A Level 2 runtime MUST satisfy Level 1, plus:

- Support multiple concurrent agents
- Support `phases` (execute phases in order, tasks within phase per DAG)
- Support `when` conditions on tasks (see [EXPRESSIONS.md](./EXPRESSIONS.md))
- Support `any_of` on task dependencies
- Resolve `${tasks.<name>.outputs.<key>}` interpolation
- Support `timeout` on tasks (kill task on expiry)
- Support `retry` policy on tasks
- Support `on_failure` behavior (retry, skip, fail_workflow, escalate, fallback)
- Support `fallback_task` when `on_failure: fallback`
- Deliver task outputs to downstream tasks via `inputs`
- Write structured NDJSON log events to a file for each run (see [OBSERVABILITY.md](./OBSERVABILITY.md))
- Include all required log events (workflow start/complete, task start/complete/fail/skip, agent spawn/exit)
- Accept `log_dir` as a configuration option to control where log files are written

### Level 3: Full

A Level 3 runtime MUST satisfy Level 2, plus:

- Support `kind: AgentProfile` with persona, policies, lifecycle, artifacts
- Support `kind: WorkflowTemplate` with parameter resolution
- Support `build_policy` with at least `epoch_batched` strategy
- Implement the [message protocol](./PROTOCOL.md) for agent communication
- Implement [epoch coordination](./EPOCH_COORDINATION.md) (freeze, ACK, build, distribute)
- Support `permissions` enforcement (filesystem, network, shell, communication)
- Support `secrets` resolution from at least `env` source
- Support `budget` enforcement (stop agent when exceeded)
- Support `approval` gates on tasks
- Support `workflow_ref` for sub-workflow delegation
- Emit [OpenTelemetry](https://opentelemetry.io/) spans when `observability.tracing: opentelemetry`
- Execute `hooks` at the declared lifecycle points
- Support `concurrency_group` and `runtime.concurrency` throttling (see [PARALLELISM.md](./PARALLELISM.md))
- Support `resource_locks` for mutual exclusion scheduling
- Enforce `task.priority` when `queue: priority` is set on a concurrency group
- Respect `agent.max_concurrent_tasks`
- Enforce `output.visibility` -- reject workflows where unauthorized agents interpolate restricted outputs
- Support `runtime.isolation` with at least `process` level
- Enforce `permissions.communication` boundaries (drop unauthorized messages)
- Support `loop` on tasks and phases (see [LOOPS.md](./LOOPS.md)): `max_iterations`, `exit_when`, context propagation, loop hooks
- Support `mcp_servers` declaration and per-agent `permissions.mcp` enforcement
- Support `planning` for dynamic DAG generation at runtime
- Support `output_format: structured` and parse `TaskResult` blocks from agent output
- Support `additional_tasks` continuation tasks emitted via structured output

## Validation Requirements

All conformance levels MUST:

- Validate incoming OAP documents against `oap.schema.json`
- Produce a clear, actionable error when validation fails
- Include the field path and expected type in validation errors

## Extension Rules

All conformance levels MUST:

- Ignore unknown fields prefixed with `x-` at any level
- NOT require `x-*` fields for core behavior
- NOT reject documents containing unknown `x-*` fields

## Reporting Conformance

Runtimes SHOULD declare their conformance level and supported OAP version:

```
OAP Conformance: Level 2
Supported Versions: 0.1
```

## Test Suite

A conformance test suite is planned. Track progress at [github.com/open-agent-protocol](https://github.com/open-agent-protocol).
