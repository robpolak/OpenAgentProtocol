# Agent Personas Spec v0.1

## Problem

Every agent framework solves identity the same way: dump text into a system prompt.

```
You are a senior engineer. Be concise. Always run tests.
Focus on Go and gRPC. Never force push to main.
```

This is unstructured, non-portable, and impossible to compose. A runtime can't programmatically enforce "never force push" when it's buried in prose. A team can't share "our senior engineer persona" as a validated artifact.

## Persona = Structured System Prompt

A persona replaces prose instructions with typed, validated fields:

| Prose | Structured |
|---|---|
| "You are a senior engineer" | `role: senior-engineer` |
| "specializing in Go and gRPC" | `expertise: [go, grpc]` |
| "Be concise" | `style.tone: concise` |
| "Always run tests before done" | `constraints: [{type: always, rule: run tests}]` |
| "Never force push" | `constraints: [{type: never, rule: force push to main}]` |
| "This service uses ClickHouse" | `context: ["ClickHouse backend"]` |

## Schema

```yaml
persona:
  role: senior-engineer
  expertise: [go, grpc, distributed-systems, clickhouse]
  style:
    tone: concise
    autonomy: autonomous
    risk_tolerance: moderate
    explanation_depth: minimal
  constraints:
    - type: never
      rule: Force push to main branch
    - type: never
      rule: Commit secrets, credentials, or API keys
    - type: always
      rule: Run tests before marking task complete
    - type: always
      rule: Format code before committing
    - type: prefer
      rule: Edit existing files over creating new ones
    - type: prefer
      rule: Use existing utilities before writing new ones
  context:
    - "Go service using Coinbase Service Framework (CSF)"
    - "ClickHouse backend for analytics queries"
    - "Use ctxzap.Info/Error/Warn for context-aware logging"
```

## Fields

### `role` (required)

What the agent IS. Freeform string — roles are domain-specific. This is the primary identity signal.

Examples: `senior-engineer`, `security-reviewer`, `architect`, `qa-lead`, `technical-writer`, `devops-engineer`, `data-scientist`

### `expertise`

Domain knowledge areas. Used by runtimes for:
- **Task routing** — assign tasks to agents with matching expertise
- **Prompt injection** — include relevant domain context
- **Capability matching** — warn if a task requires expertise the assigned agent lacks

Examples: `[go, grpc, distributed-systems]`, `[react, typescript, accessibility]`, `[kubernetes, terraform, aws]`

### `style`

Communication and behavioral modifiers. Four dimensions:

| Field | Values | Effect |
|---|---|---|
| `tone` | concise, verbose, technical, conversational | How the agent communicates. Affects output length and vocabulary. |
| `autonomy` | autonomous, collaborative, supervised | How much the agent decides alone. autonomous = acts then reports. supervised = asks before every action. |
| `risk_tolerance` | conservative, moderate, aggressive | How bold the agent is. conservative = smallest possible change. aggressive = will refactor freely. |
| `explanation_depth` | minimal, standard, thorough | How much the agent explains. minimal = just the code. thorough = explains every decision. |

### `constraints`

Always-on rules baked into the agent's identity. Three enforcement levels:

| Type | Enforcement | Example |
|---|---|---|
| `never` | Hard block. Runtime MUST prevent the action. | "Force push to main" |
| `always` | Hard requirement. Runtime MUST enforce. | "Run tests before completing" |
| `prefer` | Soft advisory. Injected as guidance, not enforced. | "Edit existing files over creating new" |

**Constraints vs. Policies**: Constraints are simple, unconditional rules — part of WHO the agent is. Policies are conditional rules with triggers, gates, and checks — part of HOW the agent operates. "Never force push" is a constraint. "Run tests when task has 3+ steps" is a policy.

### `context`

Domain knowledge. Array of strings injected into the agent's context window. Facts about the codebase, team conventions, architectural decisions that the agent needs to know.

Not instructions (use policies for that). Not principles (use `principles` field for that). Just facts.

### `extends`

Composition via inheritance. A persona can extend another persona file, overriding specific fields:

```yaml
# base-engineer.oap.yaml
persona:
  role: engineer
  expertise: [software-engineering]
  style:
    tone: concise
    autonomy: collaborative
  constraints:
    - type: always
      rule: Run tests before completing

# security-engineer.oap.yaml
persona:
  extends: ./base-engineer.oap.yaml
  role: security-engineer
  expertise: [security, penetration-testing, owasp]
  style:
    risk_tolerance: conservative    # override: more cautious
  constraints:                       # appended to base constraints
    - type: always
      rule: Check for injection vulnerabilities
    - type: never
      rule: Disable authentication or authorization checks
```

Override semantics:
- Scalar fields (`role`, `style.tone`): child replaces parent
- Array fields (`expertise`, `constraints`, `context`): child appends to parent
- `style` object: child fields override parent fields, unset fields inherited

## Persona in Agent vs. AgentProfile

Persona can appear at two levels:

```yaml
# 1. Inline in a workflow agent definition
agents:
  - name: backend-1
    persona:
      role: senior-engineer
      expertise: [go, grpc]
      style: { tone: concise, autonomy: autonomous }
    model: ${AGENT_MODEL}
    tools: [shell, file_editor, test_runner]

# 2. In a reusable AgentProfile
kind: AgentProfile
metadata:
  name: senior-go-engineer
agent:
  persona:
    role: senior-engineer
    expertise: [go, grpc, distributed-systems]
    style: { tone: concise, autonomy: autonomous, risk_tolerance: moderate }
    constraints:
      - type: always
        rule: Run tests before completing
  model: ${AGENT_MODEL}
  tools: [shell, file_editor, test_runner]
```

When a workflow agent references an `agent_profile`, the profile's persona is the default. Inline persona fields override profile defaults (same merge semantics as `extends`).

## Persona as External Ref

Personas are independently referenceable:

```yaml
agents:
  - name: backend-1
    persona: ./personas/senior-go-engineer.yaml
    model: ${AGENT_MODEL}
    tools: [shell, file_editor]

  - name: backend-2
    persona: ./personas/senior-go-engineer.yaml
    model: ${AGENT_MODEL}
    tools: [shell, file_editor]
```

Both agents share the same persona but are independent instances. Different tasks, different file scopes, same identity.

## Migration from AGENTS.md

A typical AGENTS.md:

```markdown
You are a senior Go engineer working on base-ml-gateway.
Be concise — no filler. Always run tests. Never force push.
Use ctxzap for logging. ClickHouse backend.
```

Becomes:

```yaml
persona:
  role: senior-engineer
  expertise: [go, grpc, clickhouse]
  style:
    tone: concise
    autonomy: autonomous
  constraints:
    - type: always
      rule: Run tests before completing
    - type: never
      rule: Force push to main
  context:
    - "Use ctxzap.Info/Error/Warn for context-aware logging"
    - "ClickHouse backend for analytics queries"
    - "Service: base-ml-gateway"
```

The `instructions` field provides a migration path from unstructured system prompts. Prefer `persona` for new definitions.

## How Runtimes Use Personas

Runtimes SHOULD translate persona fields into their native format:

1. **System prompt construction**: Combine `role`, `expertise`, `style`, `context`, and `constraints` into the system prompt. Order and formatting is runtime-specific.

2. **Constraint enforcement**: `never` and `always` constraints MUST be enforced programmatically where possible (e.g., git hook for force push, pre-commit test runner), not just via prompt injection.

3. **Style application**: `autonomy` affects whether the runtime pauses for approval. `risk_tolerance` affects diff size warnings. `tone` and `explanation_depth` affect output formatting.

4. **Task routing**: When a task has no explicit `agent` assignment, the runtime MAY use `expertise` matching to auto-assign.

5. **Capability warnings**: If a task's `file_scope` involves Python files but the assigned agent's `expertise` is `[go, grpc]`, the runtime SHOULD warn.

## Related Schemas

- [`persona.schema.json`](../schemas/v0.1/persona.schema.json) — Persona primitive
- [`agent.schema.json`](../schemas/v0.1/agent.schema.json) — Agent (includes persona field)
- [`agent-profile.schema.json`](../schemas/v0.1/agent-profile.schema.json) — AgentProfile document kind

## Related Docs

- [PROTOCOL.md](./PROTOCOL.md) — How agents communicate
- [EXPRESSIONS.md](./EXPRESSIONS.md) — Expression syntax for policy triggers
