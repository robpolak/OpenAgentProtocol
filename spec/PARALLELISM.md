# Parallelism Model

## Default Behavior

Tasks with no mutual `needs` are **parallel-eligible**. The runtime schedules them concurrently, bounded by `runtime.max_concurrent_agents`.

```yaml
tasks:
  - name: a          # ─┐
  - name: b          # ─┤ all three run in parallel
  - name: c          # ─┘
  - name: d
    needs: [a, b, c] # waits for all three
```

This is the implicit DAG model. No configuration needed.

## Restricting Parallelism

### Concurrency Groups

Named groups throttle parallel execution of tasks that compete for a shared concern.

```yaml
runtime:
  concurrency:
    database:
      max_parallel: 1     # mutex — one task at a time
      queue: priority      # waiting tasks ordered by priority field
    external-api:
      max_parallel: 3     # semaphore — max 3 concurrent

tasks:
  - name: migrate-users
    concurrency_group: database
    priority: 90           # runs first when competing
  - name: migrate-orders
    concurrency_group: database
    priority: 50           # queued behind migrate-users
  - name: fetch-prices
    concurrency_group: external-api
  - name: fetch-balances
    concurrency_group: external-api
  - name: fetch-metadata
    concurrency_group: external-api
```

**Rules:**
- Tasks in the same group compete for `max_parallel` slots
- `queue: fifo` (default) = first-ready runs first
- `queue: priority` = highest `task.priority` runs first
- Tasks NOT in any group are unrestricted (bounded only by `max_concurrent_agents`)
- Runtimes MUST respect group limits even when `max_concurrent_agents` has capacity

### Resource Locks

For mutual exclusion on named resources. More granular than concurrency groups — a task can hold multiple locks.

```yaml
runtime:
  resource_locks: [database, redis-cache, artifact-store]

tasks:
  - name: full-migration
    resource_locks: [database, redis-cache]  # needs both
  - name: cache-warmup
    resource_locks: [redis-cache]            # blocks if full-migration holds it
  - name: archive
    resource_locks: [artifact-store]         # independent, runs in parallel
```

**Rules:**
- Task blocks until ALL its locks are acquired
- Locks are released when the task completes (success, failure, or skip)
- Deadlock prevention: runtimes MUST acquire locks in alphabetical order
- If a task times out while waiting for a lock, `on_failure` fires

### Phases (Sequential Barriers)

Phases are the coarsest parallelism boundary. Phase N+1 starts only after ALL tasks in phase N complete.

```yaml
phases:
  - name: plan
    tasks: [analyze, triage]     # run in parallel
  - name: execute
    tasks: [fix-a, fix-b, fix-c] # all start after plan completes
  - name: review
    tasks: [code-review, test]   # starts after execute completes
```

### Global Cap

```yaml
runtime:
  max_concurrent_agents: 4   # hard ceiling on parallel agent execution
```

This is the backstop. Regardless of DAG structure, concurrency groups, or lock availability, the runtime never exceeds this limit.

## Maximizing Parallelism

### Minimize `needs`

Every `needs` edge reduces parallelism. Only add dependencies where data actually flows.

```yaml
# Bad — unnecessary serialization
tasks:
  - name: lint
  - name: typecheck
    needs: [lint]        # lint output isn't used — why wait?

# Good — independent tasks run in parallel
tasks:
  - name: lint
  - name: typecheck       # no dependency — runs alongside lint
  - name: test
    needs: [lint, typecheck]
```

### Use `any_of` for Fan-In

When a task needs data from ANY upstream (not all), use `any_of: true`:

```yaml
tasks:
  - name: search-github
  - name: search-npm
  - name: search-docs
  - name: summarize
    needs: [search-github, search-npm, search-docs]
    any_of: true    # proceeds as soon as ANY search completes
```

### Agent Concurrency

By default, one agent handles one task at a time. For agents that can safely parallelize:

```yaml
agents:
  - name: file-formatter
    max_concurrent_tasks: 4    # can format 4 files simultaneously
```

**When to increase:**
- Agent tasks are independent (no shared state)
- Agent doesn't use exclusive resources
- Agent's model supports concurrent sessions

**When to keep at 1:**
- Agent edits files that interact (imports, shared types)
- Agent uses epoch coordination (build policy)
- Agent's context window is task-specific

### Sub-Workflow Parallelism

A `workflow_ref` task runs an entire sub-workflow as a single DAG node. The sub-workflow's internal parallelism is independent of the parent.

```yaml
tasks:
  - name: backend-tests
    workflow_ref: ./test-backend.oap.yaml    # has 8 parallel test tasks
  - name: frontend-tests
    workflow_ref: ./test-frontend.oap.yaml   # has 6 parallel test tasks
  # Both sub-workflows run in parallel (no needs)
```

## Interaction with Epoch Coordination

During a build epoch (FREEZE → BUILD → DISTRIBUTE), all agents in the `build_policy` scope are paused. This is a **global serialization point** for correctness.

Parallelism resumes after DISTRIBUTE. To minimize the impact:

- Use `continuous` strategy for fast feedback (builds after each agent finishes)
- Keep `build_timeout` tight to avoid long pauses
- Agents in a sub-workflow with its own `build_policy` are unaffected — they coordinate builds independently and run in parallel with the parent epoch. See [EPOCH_COORDINATION.md](./EPOCH_COORDINATION.md#build_policy-scope) for scope definition.

## Scheduling Summary

```
Task ready to run?
  │
  ├─ Has unmet `needs`?  → WAIT (dependency)
  │
  ├─ `when` evaluates false?  → SKIP
  │
  ├─ In a `concurrency_group`?  → Check group's max_parallel
  │     └─ Full?  → QUEUE (by priority or FIFO)
  │
  ├─ Has `resource_locks`?  → Acquire all locks (alphabetical)
  │     └─ Any locked?  → WAIT (mutex)
  │
  ├─ Agent at `max_concurrent_tasks`?  → WAIT (agent busy)
  │
  ├─ `max_concurrent_agents` reached?  → WAIT (global cap)
  │
  └─ All clear  → RUN
```

## Related Schemas

- [`task.schema.json`](../schemas/v0.1/task.schema.json) — `concurrency_group`, `priority`, `resource_locks`, `needs`, `any_of`
- [`workflow.schema.json`](../schemas/v0.1/workflow.schema.json) — `runtime.concurrency`, `runtime.resource_locks`, `runtime.max_concurrent_agents`
- [`agent.schema.json`](../schemas/v0.1/agent.schema.json) — `max_concurrent_tasks`
- [`coordination/build-policy.schema.json`](../schemas/v0.1/coordination/build-policy.schema.json) — Epoch serialization

## Related Docs

- [SPEC.md](./SPEC.md) — Workflow execution model (DAG, phases, conditions)
- [EPOCH_COORDINATION.md](./EPOCH_COORDINATION.md) — Build coordination state machine
- [ISOLATION.md](./ISOLATION.md) — Walled gardens and data boundaries
