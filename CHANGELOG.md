# Changelog

All notable changes to the OAP specification.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- **RetryPolicy: retry_on** — filter which failure types trigger retry. Array of `crash`, `timeout`, `error`, `all`. Default: `["all"]`. Prevents retrying budget errors or logic failures when you only want to recover from crashes.
- **RetryPolicy: inject_context** — when true (default), the runtime prepends the previous attempt's error message to the retried task's description. Agents get context about why the last attempt failed.

### Changed
- **max_attempts semantics clarified** — `max_attempts` is total execution attempts including the first run. `max_attempts: 3` = 1 original + 2 retries. Previously ambiguous.
- **Crash and timeout route through on_failure** — agent process crashes and task timeouts now synthesize a `response.result` with `status: error` and route through `on_failure` (retry, skip, fallback, escalate). Previously, crashes left tasks stuck in running state and timeouts bypassed `on_failure` entirely.

### Fixed
- **Crash without result no longer deadlocks** — when an agent process exits without sending `response.result`, the runtime synthesizes a failure. Tasks no longer remain in running state indefinitely.

- **Loop execution** — tasks and phases can now declare a `loop` block for iterative cycles.
  - `loop.max_iterations` — hard upper bound. Required.
  - `loop.exit_when` — OAP expression evaluated after each iteration. Loop exits when true.
  - `loop.on_max_iterations` — `fail` | `escalate` | `continue_last`. Default: `fail`.
  - `loop.context.strategy` — `fresh` (default, new agent session per iteration, filesystem state injected) or `reuse` (same session).
  - `loop.context.inject_artifacts` — inject previous iteration's artifacts into new session.
  - `loop.context.summary_output` — output name whose value flows as `${loop.previous_summary}` into the next iteration.
  - `loop.budget_per_iteration` — per-iteration token/cost cap, enforced against enclosing ceilings.
  - `loop.*` variables — `loop.iteration`, `loop.max_iterations`, `loop.previous_outputs.<key>`, `loop.previous_summary` available in task descriptions and inputs.
  - Phase-level `loop` — entire phase (all tasks) repeats as a unit.
  - Multiple loops compose naturally in the DAG via `needs`. Nested loops (loop task inside loop phase) are rejected.
  - New message types: `event.loop_iteration`, `event.lifecycle` extended with `loop_iteration_complete`, `loop_max_iterations_reached`, `loop_exited`.
  - New workflow hooks: `on_loop_iteration`, `on_loop_max_iterations`.
  - New spec: `spec/LOOPS.md`. Summary section added to `spec/SPEC.md § Loop Execution`.
  - New example: `spec/examples/loop-refinement.oap.yaml`.

- **Structured agent output** — agents can now declare `output_format: structured` to require a typed `oap-result` JSON block at the end of their response. Eliminates heuristic JSON extraction from prose and enables reliable epoch coordination via `build_ready: true`.
  - `agent.output_format` field with `"stream"` (default) and `"structured"` values
  - New `schemas/v0.1/task-result.schema.json` — `TaskResult` schema with `status`, `summary`, `outputs`, `artifacts`, `build_ready`, `error`, `tokens_used`
  - Runtimes MUST inject the closing instruction into the task prompt, parse the last `oap-result` block, and promote its fields to `signal.output`, `signal.artifact`, and `epoch.MarkReady()` calls
  - `build_ready: true` in `TaskResult` is the preferred replacement for `build_policy.auto_ack`
  - New spec section: `spec/SPEC.md § Structured Agent Output`

- **MCP server access** — agents can now declare which MCP (Model Context Protocol) servers they have access to via `permissions.mcp`. Connection config is defined once at the workflow level in `mcp_servers` and referenced by name per-agent.
  - New `schemas/v0.1/mcp.schema.json` — `McpServer` definition with `transport` (stdio/sse/http), `command`/`url`, `env`, `auth`, `tools`, `startup_timeout`
  - `workflow.mcp_servers` array — declare servers available to any agent in the workflow
  - `permissions.mcp.servers` — per-agent server allowlist (or `["*"]` for all)
  - `permissions.mcp.allow_tools` — restrict to specific tools in `"server:tool"` format
  - `permissions.mcp.deny_tools` — block specific tools (precedence over allow)
  - Secrets (`${secrets.*}`) supported in MCP `env` and `auth` fields
  - New example: `spec/examples/mcp-enabled.oap.yaml`

## [0.1] — 2026-03-05

Initial draft.

### Core Primitives
- Agent — persona, model/model_tier, tools, principles, policies, permissions, budget
- Persona — structured identity with role, expertise, style, constraints
- Task — inputs, typed outputs, `needs` (DAG), approval gates, sub-workflow delegation
- Policy — trigger conditions, hard/soft gates, checks, actions
- Artifact — persistent workspace files with lifecycle
- Permissions — filesystem, network, shell, secrets sandbox
- Phase — task grouping with ordered execution
- Hook — lifecycle callbacks
- Runtime — timeout, concurrency groups, resource locks, isolation, env, budget

### Parallelism
- Concurrency groups with `max_parallel` and `queue` (fifo/priority)
- Resource locks for mutual exclusion on named resources
- `task.priority` (0-100) for scheduling under contention
- `task.concurrency_group` assignment
- `agent.max_concurrent_tasks` (default 1)

### Isolation & Data Boundaries
- `permissions.communication` — `can_message`, `can_receive_from`, `can_handoff_to`
- Output `visibility` on typed outputs — restrict which agents can read data
- `runtime.isolation` — execution isolation levels (shared, process, container)
- `shared_filesystem` and `shared_network` toggles

### Model Tiers
- `agent.model_tier` — portable model selection (frontier, standard, fast, embedding)
- `runtime.model_tiers` — maps tiers to concrete model identifiers
- Frontier model for planning/orchestration, cheap model for defined tasks

### Dynamic Planning
- `workflow.planning` — planner agent generates the task DAG at runtime
- Constraints: max_tasks, max_depth, allowed_agents, require_approval
- `replan_on_failure` — planner adjusts DAG when tasks fail
- Can combine with static `tasks` (seed tasks run first, planner adds more)

### Document Kinds
- `Workflow` — concrete task DAG
- `AgentProfile` — reusable agent definition with policies and lifecycle
- `WorkflowTemplate` — parameterized workflow pattern

### Coordination
- BuildPolicy with epoch-based build coordination
- Five strategies: epoch_batched, on_task_complete, continuous, gated, manual
- File ownership registry with conflict resolution
- Compiler error attribution

### Message Protocol
- CloudEvents-inspired envelope (id, type, source, target, timestamp)
- Signals: status, output, log
- Requests: task, query, handoff, approval
- Responses: result, ack
- Events: lifecycle
- Build messages: intent, ready, file_conflict, build_started, epoch_start, ack, result

### Expression Syntax
- `${}` interpolation (env vars, task outputs, params, secrets)
- `when` conditions on tasks
- `trigger` conditions on policies

### Conformance
- Three conformance levels: Core, Coordination, Full
