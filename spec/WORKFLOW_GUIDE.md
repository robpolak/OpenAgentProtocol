# OAP Workflow Guide for LLM Agents

Token-efficient reference for building `.oap.yaml` files.
Full spec: [SPEC.md](./SPEC.md). Loop spec: [LOOPS.md](./LOOPS.md).

---

## Required Skeleton

Every OAP file needs exactly this:

```yaml
oap_version: "0.1"
kind: Workflow          # Workflow | AgentProfile | WorkflowTemplate
metadata:
  name: my-workflow     # ^[a-z][a-z0-9-]*$  required
  description: ...      # optional

agents:
  - name: coder         # required in Workflow context
    model_tier: standard

tasks:
  - name: first-task    # ^[a-z][a-z0-9-]*$  required
    agent: coder
    description: What the agent should do.
```

---

## Execution Model — Pick One

| Mode | Use When | Field |
|---|---|---|
| Static flat | You know all tasks upfront | `tasks:` |
| Static phased | Tasks group into ordered stages | `phases:` |
| Dynamic | Task list unknown until runtime | `planning:` |

`tasks` and `phases` are mutually exclusive. `planning` + `tasks` is valid — static tasks run first as seeds.

---

## Agents

```yaml
agents:
  - name: planner
    model_tier: frontier     # frontier | standard | fast | embedding
    tools: [shell, file_editor, web_search]
    output_format: structured  # emits oap-result block; enables reliable output extraction
    permissions:
      filesystem:
        allow_write: ["src/"]
        deny: [".env"]
      shell:
        allow: true
        blocked_commands: ["rm -rf /"]
    budget:
      max_cost_usd: 5.00
      on_exceed: stop          # stop | warn
    principles:
      - "Prefer reversible changes."
      - "Never modify files outside your file_scope."
```

**Model tiers** map to concrete models at runtime via `runtime.model_tiers`. Use tiers for portability.

| Tier | Use For |
|---|---|
| `frontier` | Planning, architecture, complex reasoning |
| `standard` | Implementation, reviews, general coding |
| `fast` | Linting, formatting, mechanical transforms |

**`output_format: structured`** — strongly preferred for any task whose outputs feed downstream tasks. The agent must emit a final ` ```oap-result ``` ` JSON block. Eliminates heuristic extraction.

---

## Tasks and DAG Construction

```yaml
tasks:
  - name: triage
    agent: analyzer
    description: Analyze the bug report.
    outputs:
      - name: severity
        type: string
        enum: [low, medium, high, critical]
        required: true
      - name: affected_files
        type: file_list

  - name: fix
    agent: coder
    needs: [triage]                                        # runs after triage
    when: tasks.triage.outputs.severity == "critical"      # skip if not critical
    description: Fix the issue in ${tasks.triage.outputs.affected_files}.
    outputs:
      - name: patch_applied
        type: boolean
        required: true

  - name: review
    agent: reviewer
    needs: [fix]
    description: Review the patch.
```

**DAG rules:**
- Tasks with no `needs` are roots — they run immediately.
- A task runs when ALL deps complete (unless `any_of: true`, then ANY).
- Circular `needs` is a parse error.
- `when: false` → task is skipped; its outputs are `null`; downstream tasks still run.
- Use `when` on downstream tasks to handle the skip case.

**Output types:** `string` `number` `boolean` `file_list` `markdown` `json` `action`

**Typed outputs with `required: true` are validated by the runtime.** Missing required outputs fail the task.

---

## Interpolation and Expressions

### `${}` — value substitution in strings

| Syntax | Resolves To |
|---|---|
| `${tasks.name.outputs.key}` | Upstream task output |
| `${ENV_VAR}` | Environment variable |
| `${params.name}` | WorkflowTemplate parameter |
| `${secrets.name}` | Secret (from permissions.secrets) |
| `${loop.iteration}` | Current loop iteration (1-based) |
| `${loop.previous_summary}` | Summary from previous loop iteration |
| `${loop.previous_outputs.key}` | Named output from previous iteration |

### `when:` — conditional task execution

```
tasks.name.outputs.key == "value"
tasks.name.outputs.count > 5
tasks.a.outputs.ok == true AND tasks.b.outputs.ok == true
tasks.a.outputs.flag == true OR tasks.b.outputs.flag == true
```

Operators: `==` `!=` `>` `>=` `<` `<=`
No function calls. No arithmetic. Complex logic → compute in a task, reference its output.

---

## Phases

Use phases when tasks group into strict ordered stages.

```yaml
phases:
  - name: plan
    tasks:
      - name: analyze
        agent: planner
        description: Analyze the codebase.

  - name: execute
    tasks:
      - name: implement
        agent: coder
        needs: [analyze]       # cross-phase needs are valid
        description: Implement based on ${tasks.analyze.outputs.plan}.

  - name: verify
    tasks:
      - name: test
        agent: tester
        description: Run the test suite.
```

Phase N+1 starts only after ALL tasks in phase N complete. Tasks within a phase run per their own `needs` graph.

---

## Loops

Use loops for iterative refinement — write-test-fix, draft-review, retry-until-passing.

```yaml
- name: implement
  agent: coder
  description: |
    Implement the feature. Iteration ${loop.iteration} of ${loop.max_iterations}.
    Previous result: ${loop.previous_summary}
    Exit goal: tests_pass=true
  outputs:
    - name: tests_pass
      type: boolean
      required: true
    - name: loop_summary    # feeds ${loop.previous_summary} next iteration
      type: string
      required: true
  loop:
    max_iterations: 5
    exit_when: "tasks.implement.outputs.tests_pass == true"
    on_max_iterations: escalate   # fail | escalate | continue_last
    context:
      strategy: fresh             # fresh (default) | reuse
      summary_output: loop_summary
    budget_per_iteration:
      max_tokens: 60000
      max_cost_usd: 2.00
```

**Critical rules:**
- `exit_when` MUST reference typed `required: true` outputs. Vague outputs (agent writes `done=true`) make the loop meaningless.
- `strategy: fresh` (default) — new session each iteration, filesystem artifacts injected. Avoids context degradation. Use unless `max_iterations <= 3` and accumulated reasoning IS the product.
- Multiple loops compose via `needs` — sequential, parallel, or chained.
- Nested loops (loop task inside loop phase) are rejected.

**Phase loop** — wrap the entire phase:
```yaml
phases:
  - name: refine
    loop:
      max_iterations: 3
      exit_when: "tasks.score.outputs.quality >= 8"
    tasks:
      - name: draft
        agent: writer
      - name: score
        agent: critic
        needs: [draft]
        outputs:
          - name: quality
            type: number
            required: true
```

---

## Dynamic Planning

Use when the task list depends on runtime discovery.

```yaml
agents:
  - name: planner
    model_tier: frontier
  - name: worker
    model_tier: standard
    tools: [shell, file_editor]

planning:
  agent: planner
  goal: "Implement all failing tests described in FAILING_TESTS.md"
  constraints:
    max_tasks: 15
    max_depth: 4
    allowed_agents: [worker]
    require_approval: false
  replan_on_failure: true
```

The planner emits a JSON task array in its `oap-result` block. Tasks must conform to the task schema. The coordinator validates and executes them exactly like static tasks.

**Combine with static tasks** — static tasks run first as setup, planner adds more:
```yaml
tasks:
  - name: setup
    agent: worker
    description: Install dependencies.

planning:
  agent: planner
  goal: "Build the feature"
  # planner-generated tasks may have needs: [setup]
```

---

## Common Patterns

### Triage → Conditional Fan-out

```yaml
tasks:
  - name: triage
    agent: analyzer
    outputs:
      - name: severity
        type: string
        enum: [low, medium, high, critical]
        required: true

  - name: hotfix
    agent: coder
    needs: [triage]
    when: tasks.triage.outputs.severity == "critical"
    description: Apply hotfix.

  - name: routine-fix
    agent: coder
    needs: [triage]
    when: tasks.triage.outputs.severity != "critical"
    description: Apply routine fix.
```

### Parallel Workers → Aggregator

```yaml
tasks:
  - name: frontend
    agent: frontend-dev
    outputs: [component_ready]
  - name: backend
    agent: backend-dev
    outputs: [api_ready]
  - name: integrate
    agent: lead
    needs: [frontend, backend]
    description: Integration review.
```

### Loop → Downstream (loop result feeds next task)

```yaml
tasks:
  - name: research
    agent: researcher
    loop:
      max_iterations: 4
      exit_when: "tasks.research.outputs.sources_found >= 5"
    outputs:
      - name: sources_found
        type: number
        required: true
      - name: summary
        type: markdown
        required: true

  - name: write
    agent: writer
    needs: [research]
    description: Write based on: ${tasks.research.outputs.summary}
```

### Critic-Drafter Loop (phase loop)

```yaml
phases:
  - name: draft-and-review
    loop:
      max_iterations: 4
      exit_when: "tasks.review.outputs.approved == true"
      on_max_iterations: continue_last
    tasks:
      - name: draft
        agent: writer
        outputs:
          - name: content
            type: markdown
            required: true
      - name: review
        agent: critic
        needs: [draft]
        outputs:
          - name: approved
            type: boolean
            required: true
          - name: feedback
            type: string

  - name: publish
    tasks:
      - name: deploy
        agent: publisher
```

### Human Approval Gate

```yaml
- name: deploy-prod
  agent: deployer
  description: Deploy to production.
  approval:
    when: before_start       # before_start | after_complete | both
    approvers: [user]
    timeout: 30m
    on_timeout: fail
```

---

## Structured Output Contract

When `output_format: structured`, the agent MUST end its response with:

````
```oap-result
{
  "status": "ok",
  "summary": "What was done",
  "outputs": { "key": "value" },
  "artifacts": ["path/to/file"],
  "build_ready": true
}
```
````

`status` must be `ok` | `error` | `partial`. The runtime uses this block as the sole output source.

**Inject this requirement into every agent's task description** when `output_format: structured` is set on the agent. The runtime injects it automatically — you do not need to repeat it in descriptions.

---

## Budget and Runtime Config

```yaml
runtime:
  max_concurrent_agents: 4
  timeout: 2h
  budget:
    max_cost_usd: 20.00
    on_exceed: stop
  model_tiers:
    frontier: claude-sonnet-4
    standard: claude-haiku
    fast: gpt-4o-mini

agents:
  - name: coder
    budget:
      max_cost_usd: 3.00   # per-agent ceiling within workflow ceiling
      on_exceed: stop
```

---

## Failure Handling

```yaml
- name: api-call
  on_failure: retry          # retry | skip | fail_workflow | escalate | fallback
  retry:
    max_attempts: 3
    backoff: exponential     # none | linear | exponential
  escalate_to: user          # for on_failure=escalate
  fallback_task: use-cache   # for on_failure=fallback
```

---

## Anti-Patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| `loop` with `exit_when` referencing untyped/optional outputs | Agent emits `done=true` trivially; loop never exits for the right reason | Declare outputs with `type:` and `required: true` |
| Long descriptions with all context in every task | Context bloat; agent ignores most of it | Use `${tasks.prev.outputs.key}` to inject exactly what's needed |
| All tasks in one `needs` chain, no parallelism | Serial bottleneck | Identify independent tasks and remove unnecessary `needs` |
| `strategy: reuse` with `max_iterations > 3` | Context window degrades; agent forgets early iteration work | Use `strategy: fresh` and `summary_output` for state handoff |
| Dynamic planning for known, stable workflows | Adds planner cost and latency; less predictable | Use static `tasks` or `phases`; reserve `planning` for truly open-ended work |
| Outputs with type `string` for structured data | Heuristic extraction is fragile | Use `type: json` with a `schema:` for structured data |
| Missing `needs` between dependent tasks | Race condition; downstream reads stale outputs | Every task that reads `${tasks.X.outputs.*}` MUST have `needs: [X]` |

---

## Validation Checklist

Before finalizing a workflow:

- [ ] Every task has exactly one of `agent:` or `workflow_ref:`
- [ ] Every `agent:` value matches a name in the `agents:` array
- [ ] Every `needs:` entry references a task that exists
- [ ] Every `${tasks.X.outputs.Y}` reference has `needs: [X]`
- [ ] Every `exit_when` references a `required: true` typed output
- [ ] `loop` tasks inside a loop phase → remove (nested loops are rejected)
- [ ] `output_format: structured` agents have typed, required outputs matching their `oap-result` fields
- [ ] Budget limits set when `max_iterations > 2`
- [ ] `planning` does NOT use `phases` in the same document

---

## Full Field Reference (condensed)

### Task fields

| Field | Type | Notes |
|---|---|---|
| `name` | string | `^[a-z][a-z0-9-]*$`. Required. |
| `agent` | string | Must match an agent name. Required unless `workflow_ref` set. |
| `description` | string | Supports `${}`. Required. |
| `needs` | string[] | Dependency names. |
| `when` | expression | Skip task if false. |
| `any_of` | bool | Run when ANY dep completes (not all). |
| `outputs` | array | String names or typed objects. |
| `inputs` | object | Named inputs with `${}` values. |
| `success_criteria` | string[] | Checklist for agent before marking done. |
| `loop` | LoopConfig | Iterative execution. |
| `timeout` | duration | e.g. `30m`, `2h`. |
| `retry` | RetryPolicy | `max_attempts`, `backoff`. |
| `on_failure` | enum | `retry\|skip\|fail_workflow\|escalate\|fallback`. |
| `approval` | Approval | Human gate. |
| `priority` | 0-100 | Higher runs first under contention. |
| `concurrency_group` | string | Throttles parallel tasks. |
| `resource_locks` | string[] | Mutex names; acquired alphabetically. |
| `budget` | TaskBudget | Per-task `max_tokens`, `max_cost_usd`. |

### Loop fields

| Field | Required | Default | Notes |
|---|---|---|---|
| `max_iterations` | yes | — | Hard stop. |
| `exit_when` | no | — | OAP expression. True → exit. |
| `on_max_iterations` | no | `fail` | `fail\|escalate\|continue_last` |
| `context.strategy` | no | `fresh` | `fresh\|reuse` |
| `context.inject_artifacts` | no | `true` | Inject prior iteration's artifacts into fresh session. |
| `context.summary_output` | no | — | Output name → `${loop.previous_summary}`. |
| `budget_per_iteration` | no | — | `max_tokens`, `max_cost_usd` per cycle. |
