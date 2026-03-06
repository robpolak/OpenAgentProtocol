# Expression Syntax

OAP uses expressions in three contexts:

1. **`when`** on tasks — conditional execution
2. **`trigger`** on policies — activation condition
3. **`${}`** interpolation — value substitution in strings

## Interpolation

Substitute values into strings. Double-dollar `$${}` escapes literal.

### Sources

| Syntax | Resolves To |
|---|---|
| `${ENV_VAR}` | Environment variable |
| `${tasks.<name>.outputs.<key>}` | Output from upstream task |
| `${params.<name>}` | WorkflowTemplate parameter |
| `${secrets.<name>}` | Secret reference (via permissions.secrets) |
| `${metadata.name}` | Current document metadata field |

### Examples

```yaml
description: "Fix ${tasks.diagnose.outputs.root_cause} in ${params.service}"
model: ${AGENT_MODEL}
build_command: ${params.test_command}
```

### Rules

- Unresolved `${ENV_VAR}` → runtime error (unless variable has a default).
- Unresolved `${tasks.*}` → runtime error if the referenced task does not exist in the workflow. The referenced task MUST be in `needs`. If the referenced task was skipped (its `when` evaluated to false), the expression resolves to `null` — not an error.
- Unresolved `${params.*}` → use `defaults` value, or runtime error if required and no default.
- Unresolved `${secrets.*}` → runtime error if `required: true`, empty string if `required: false`.
- Interpolation happens at runtime, not at parse time. Schemas validate the template string, not the resolved value.

## Conditions (`when`)

Task-level conditions that control whether a task executes. Used in the `when` field.

### Grammar

```
condition     := comparison ((" AND " | " OR ") comparison)*
comparison    := path operator value
path          := "tasks." identifier ".outputs." identifier
operator      := "==" | "!=" | ">" | ">=" | "<" | "<="
value         := quoted_string | number | "true" | "false" | "null"
quoted_string := '"' [^"]* '"'
identifier    := [a-z][a-z0-9_-]*
```

### Examples

```yaml
when: tasks.triage.outputs.severity == "critical"
when: tasks.analyze.outputs.line_count > 500
when: tasks.check.outputs.needs_migration == true
when: tasks.triage.outputs.severity != "critical"
when: tasks.a.outputs.ready == true AND tasks.b.outputs.ready == true
```

### Rules

- `AND` has higher precedence than `OR`.
- Comparison with `null` tests whether the output exists.
- Type coercion: numbers compare numerically, everything else compares as strings.
- If a referenced task was skipped (its `when` was false), its outputs are `null`.
- Runtimes MUST evaluate conditions after all `needs` tasks complete (or are skipped).

## Triggers (`trigger`)

Policy-level conditions that control when a policy activates. Used in the `trigger` field on policies.

### Grammar

Same as conditions, plus built-in context variables:

| Variable | Type | Description |
|---|---|---|
| `task.steps` | number | Estimated step count for the current task |
| `task.completing` | boolean | True when agent signals task completion |
| `task.has_architecture_decisions` | boolean | Heuristic: task description mentions architecture |
| `event.user_correction` | boolean | True when user corrects agent behavior |
| `event.build_failure` | boolean | True when build fails during epoch |
| `event.git_push_force` | boolean | True when agent attempts force push |

### Examples

```yaml
trigger: task.steps >= 3 OR task.has_architecture_decisions
trigger: task.completing
trigger: event.user_correction
trigger: event.build_failure AND task.completing
```

### Rules

- Trigger variables are runtime-provided. Runtimes MUST support the built-in set above.
- Runtimes MAY add custom trigger variables prefixed with `x_` (e.g., `x_swarm.is_leader`). Trigger variable names use underscores because hyphens are not valid in expression identifiers.
- Unknown trigger variables evaluate to `false` (not error).
- Policies with trigger `always` activate unconditionally.

## Limits

The expression language is intentionally small. It is NOT a general-purpose language.

- No function calls
- No arithmetic (beyond comparison operators)
- No string manipulation
- No nested property access beyond two levels
- No regular expressions

Complex logic belongs in policy `checks` (shell commands, custom scripts) — not in expressions. If you need more than a simple condition, use a task to compute the value and reference its output.
