# Loop Execution

Loops let a task or phase run iteratively until exit criteria are met or a maximum iteration count is reached. This enables refinement cycles, critic-drafter patterns, and self-correcting workflows without duplicating tasks in the DAG.

A loop is a first-class construct in OAP. Multiple loops can coexist in the same workflow, chained or parallel via `needs`.

---

## The Ralph Loop Pattern

Research on long-running autonomous agent sessions establishes one key finding: **fresh context per iteration outperforms session continuation**. A continuous 90-minute session degrades as the context window fills — earlier architectural decisions get compressed away, agent focus narrows to recent output, and errors accumulate. A fresh session starting each iteration from filesystem state maintains full cognitive capacity throughout.

OAP loop design follows this pattern directly:

```
Iteration 1: [full context] → writes files, emits outputs
Iteration 2: [full context] → reads artifacts from disk, continues
Iteration 3: [full context] → reads updated state, checks exit criteria
...
Iteration N: [full context] → exit criteria met, loop ends
```

Compare with session reuse (for reference only — not the default):

```
Iteration 1: [200K tokens] → productive
Iteration 2: [160K tokens] → somewhat productive  
Iteration 3: [110K tokens] → degraded, tunnel vision
Iteration N: [compressed] → errors accumulate
```

The default context strategy in OAP is `fresh`. Use `reuse` only for tight loops where the accumulated reasoning is the product (e.g., multi-turn debate, negotiation).

---

## Loop Placement

Loops attach to **tasks** or **phases**. Both use the same `loop` config block.

### Task loop

```yaml
tasks:
  - name: implement-and-verify
    agent: coder
    description: |
      Implement the feature. Iteration ${loop.iteration} of ${loop.max_iterations}.
      Exit when all tests pass.
      Previous output: ${loop.previous_summary}
    loop:
      max_iterations: 5
      exit_when: "tasks.implement-and-verify.outputs.tests_pass == true"
      on_max_iterations: escalate
      context:
        strategy: fresh
        summary_output: loop_summary
    outputs:
      - name: tests_pass
        type: boolean
        required: true
      - name: loop_summary
        type: string
```

The task runs, emits `tests_pass`. If false, the loop re-queues the task with `loop.iteration` incremented. The runtime injects the previous `loop_summary` artifact as context into the next invocation.

### Phase loop

```yaml
phases:
  - name: refine
    loop:
      max_iterations: 3
      exit_when: "tasks.score.outputs.quality_score >= 8"
      on_max_iterations: fail
      context:
        strategy: fresh
        inject_artifacts: true
    tasks:
      - name: draft
        agent: writer
      - name: score
        agent: reviewer
        needs: [draft]
        outputs:
          - name: quality_score
            type: number
            required: true
          - name: feedback
            type: string
```

All tasks in the phase run each iteration. The loop checks the exit condition after the phase's final task completes.

---

## Loop Config

```yaml
loop:
  max_iterations: 5           # REQUIRED. Hard upper bound.
  exit_when: <expression>     # OPTIONAL. OAP expression. Loop ends when true.
  on_max_iterations: fail     # fail | escalate | continue_last. Default: fail.
  escalate_to: user           # When on_max_iterations=escalate. Default: user.
  context:
    strategy: fresh           # fresh | reuse. Default: fresh.
    inject_artifacts: true    # Inject previous iteration's artifacts. Default: true.
    summary_output: <name>    # Output name to use as handoff summary.
  budget_per_iteration:
    max_tokens: 50000
    max_cost_usd: 2.00
```

### Fields

| Field | Required | Description |
|---|---|---|
| `max_iterations` | yes | Hard upper bound on iterations. 1 = runs exactly once (no loop). |
| `exit_when` | no | OAP expression evaluated after each iteration. Loop exits when true. |
| `on_max_iterations` | no | What happens when `max_iterations` is reached without `exit_when` triggering. Default: `fail`. |
| `escalate_to` | no | Escalation target when `on_max_iterations: escalate`. Default: `user`. |
| `context.strategy` | no | `fresh` (default) or `reuse`. |
| `context.inject_artifacts` | no | Whether to inject previous iteration's written artifacts as context. Default: `true` when `strategy: fresh`. |
| `context.summary_output` | no | Name of an output produced by the task/phase. Its value is injected as `${loop.previous_summary}` in the next iteration. |
| `budget_per_iteration` | no | Per-iteration token/cost cap. Both draw from the workflow budget ceiling. |

---

## Exit Criteria

Exit criteria are evaluated **after each iteration completes**. Three mechanisms are checked in order:

1. **`exit_when` expression** — if true, loop exits with status `completed`.
2. **`max_iterations` reached** — triggers `on_max_iterations`.
3. **Budget exhaustion** — treated identically to `max_iterations` reached.

### Writing exit criteria

Exit conditions MUST be machine-verifiable. They reference typed outputs from the current iteration.

**Good:**
```yaml
exit_when: "tasks.test.outputs.all_passed == true"
exit_when: "tasks.score.outputs.quality_score >= 8"
exit_when: "tasks.lint.outputs.error_count == 0"
exit_when: "tasks.build.outputs.status == \"ok\""
```

**Bad** (avoid — these pass trivially or are unverifiable):
```yaml
exit_when: "tasks.draft.outputs.done == true"   # agent can always emit done=true
exit_when: "tasks.impl.outputs.looks_good"       # subjective, no type constraint
```

The worst failure mode: an agent that writes trivially-passing criteria. Pair `exit_when` with typed outputs (`required: true`) and external validators (test runners, linters, compilers). Let the machine decide, not the agent.

### on_max_iterations behaviors

| Value | Behavior |
|---|---|
| `fail` | Loop task/phase fails. `on_failure` on the containing task fires. |
| `escalate` | Runtime pauses. Sends `request.approval` to `escalate_to`. Human decides: approve (mark loop completed with last output), retry (reset iteration count), or fail. |
| `continue_last` | Use the last iteration's output as-is. Mark task/phase status as `partial`. |

---

## Context Strategy

### `fresh` (default)

Each iteration spawns a new agent session. The session starts clean — no conversation history from prior iterations. The runtime injects:

- `${loop.iteration}` — current iteration number (1-based)
- `${loop.max_iterations}` — upper bound
- `${loop.previous_outputs.<key>}` — outputs from the previous iteration
- `${loop.previous_summary}` — value of `context.summary_output` from the previous iteration (if configured)
- Previous iteration's artifacts — injected as readable files when `inject_artifacts: true`

**Why this works:** Each iteration gets the full context window. The agent reads current filesystem state, not accumulated conversation weight. This matches observed performance: fresh sessions on iteration 5 match iteration 1. Session continuation degrades 20-50% by iteration 3-4.

**Trade-off:** The agent must re-read its working state from disk each iteration. This is by design. It forces explicit state persistence, which also makes the loop resumable after runtime failures.

### `reuse`

The same agent session continues across iterations. The runtime appends iteration metadata to the existing conversation.

Use only when:
- `max_iterations <= 3`
- The accumulated reasoning IS the product (debate, negotiation, brainstorming)
- Each iteration is short (< 10 minutes, < 20K tokens)

Runtimes SHOULD emit a warning when `strategy: reuse` and `max_iterations > 3`.

---

## Iteration Variables

These variables are available in task `description`, `inputs`, and `when` expressions during loop execution:

| Variable | Type | Description |
|---|---|---|
| `loop.iteration` | integer | Current iteration, 1-based. |
| `loop.max_iterations` | integer | Max iterations from config. |
| `loop.previous_outputs.<key>` | any | Named output from the previous iteration. Null on iteration 1. |
| `loop.previous_summary` | string | Value of `context.summary_output` from the previous iteration. Empty string on iteration 1. |
| `loop.exit_when` | string | The exit condition string, so the agent knows what it is working toward. |

---

## Budget

Loops multiply agent cost. Declare explicit budgets.

```yaml
loop:
  max_iterations: 5
  budget_per_iteration:
    max_tokens: 50000
    max_cost_usd: 2.00
```

**Total effective budget:** `budget_per_iteration` × `max_iterations`. This must fit within the enclosing task's budget, the agent's budget, and the workflow budget. All three ceilings are enforced.

When budget is exhausted mid-loop, the runtime treats it as `max_iterations` reached and executes `on_max_iterations`.

If `budget_per_iteration` is not set, per-iteration usage is uncapped (only workflow/agent/task ceilings apply).

---

## Multiple Loops in a DAG

Loops are tasks and phases. They compose via `needs` exactly like any other DAG node.

### Sequential loops

```yaml
tasks:
  - name: research
    agent: researcher
    loop:
      max_iterations: 3
      exit_when: "tasks.research.outputs.sources_found >= 5"

  - name: implement
    agent: coder
    needs: [research]
    loop:
      max_iterations: 5
      exit_when: "tasks.implement.outputs.tests_pass == true"
    description: |
      Implement based on research: ${tasks.research.outputs.summary}
```

### Parallel loops

```yaml
tasks:
  - name: setup
    agent: coordinator
    description: Set up the project structure.

  - name: frontend-loop
    agent: frontend-dev
    needs: [setup]
    loop:
      max_iterations: 4
      exit_when: "tasks.frontend-loop.outputs.e2e_pass == true"

  - name: backend-loop
    agent: backend-dev
    needs: [setup]
    loop:
      max_iterations: 4
      exit_when: "tasks.backend-loop.outputs.api_tests_pass == true"

  - name: integrate
    agent: lead
    needs: [frontend-loop, backend-loop]
    description: Integration review.
```

### Phase loops with downstream tasks

```yaml
phases:
  - name: refine
    loop:
      max_iterations: 3
      exit_when: "tasks.review.outputs.approved == true"
    tasks:
      - name: write
        agent: writer
      - name: review
        agent: critic
        needs: [write]

  - name: publish
    tasks:
      - name: deploy
        agent: publisher
```

`publish` runs once, after the `refine` phase loop completes.

---

## Nested Loops

Nested loops (a looping phase containing another looping task) are **not supported**. Runtimes MUST reject documents where a task with `loop` appears inside a phase with `loop`.

Use sub-workflow delegation for nested scenarios:

```yaml
# outer-workflow.oap.yaml
tasks:
  - name: outer-loop
    workflow_ref: ./inner-workflow.oap.yaml
    loop:
      max_iterations: 3
      exit_when: "tasks.outer-loop.outputs.converged == true"
```

The sub-workflow handles its own iteration. The outer loop sees the sub-workflow's final output each cycle.

---

## Spawn Budget

Loops involving agents that can spawn sub-agents (via dynamic planning) carry a spawn budget. The budget is **inherited**, not incremented.

A loop task with `planning:` and `max_iterations: 3` does not multiply its planning agent's spawn capacity by 3. Each iteration draws from the same pool. Set `planning.constraints.max_tasks` accordingly.

This prevents the failure mode where an unguarded loop with a planning agent spawns exponentially more sub-agents per iteration. Runtimes MUST enforce the spawn budget across iterations.

---

## Conformance

Runtimes implementing loops MUST:

- Enforce `max_iterations` as a hard stop
- Evaluate `exit_when` after each complete iteration
- Inject `loop.*` variables into task descriptions and inputs when `strategy: fresh`
- Reject documents with nested loops (loop task inside loop phase)
- Enforce `budget_per_iteration` against enclosing budget ceilings

Runtimes implementing loops SHOULD:

- Warn when `strategy: reuse` and `max_iterations > 3`
- Emit `lifecycle.loop.iteration_complete` events with iteration number and current outputs
- Surface loop iteration count in observability spans

Runtimes MAY:

- Support resuming a loop after a runtime crash (re-read last persisted iteration state from artifacts)
- Track per-iteration token usage separately in observability

Loop support is optional at the Core conformance level. It is REQUIRED at Full conformance level. See [CONFORMANCE.md](./CONFORMANCE.md).
