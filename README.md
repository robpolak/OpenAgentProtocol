# OpenAgentProtocol

A YAML spec for multi-agent AI workflows. Write it once, run it on any compliant runtime.

OAP is to multi-agent workflows what OpenAPI is to REST — a portable, vendor-neutral contract.

---

```yaml
oap_version: "0.1"
kind: Workflow
metadata:
  name: fix-login-bug

agents:
  - name: engineer
    model_tier: standard
    tools: [shell, file_editor]

tasks:
  - name: diagnose
    agent: engineer
    description: Analyze auth logs, identify root cause.
    outputs: [root_cause]

  - name: fix
    agent: engineer
    needs: [diagnose]
    description: Fix ${tasks.diagnose.outputs.root_cause}.

  - name: verify
    agent: engineer
    needs: [fix]
    description: Run tests, confirm fix, verify no regressions.
```

That's a complete workflow. Any OAP-compliant runtime executes it.

---

## Why OAP

**Your workflow is locked to your framework.** A CrewAI workflow can't run on a CLI. A Swarm config doesn't work in CI. OAP is the interchange format.

**Coordination patterns are tribal knowledge.** DAGs, build epochs, file ownership, error attribution — every team reinvents these. OAP codifies them as validated, shareable JSON schemas.

**Agents have no security model.** Most runtimes give agents full system access. OAP declares filesystem, network, shell, and communication boundaries per agent.

**Agent identity is freeform prose.** System prompts and markdown files aren't portable or enforceable. OAP Personas are structured, validated, and inheritable.

---

## What's in the Box

| | |
|---|---|
| **Schemas** | JSON Schemas for every primitive. Validate files, power IDE autocomplete, enforce contracts. |
| **Spec** | Normative prose covering execution model, coordination, isolation, personas, expressions. |
| **Examples** | 15 complete `.oap.yaml` files covering simple, parallel, conditional, loop, epoch-coordinated, and dynamic-planning patterns. |

---

## Status

**v0.1 — draft.** Primitives are stabilizing. Breaking changes expected before 1.0.

---

## Docs

→ **[TECHNICAL.md](./TECHNICAL.md)** — architecture, primitives, protocol, conformance, project structure  
→ **[spec/WORKFLOW_GUIDE.md](./spec/WORKFLOW_GUIDE.md)** — token-efficient LLM reference for building `.oap.yaml` files  
→ **[spec/SPEC.md](./spec/SPEC.md)** — definitive normative specification  
→ **[spec/examples/](./spec/examples/)** — 15 runnable examples  
→ **[CHANGELOG.md](./CHANGELOG.md)** — what changed  

---

[MIT License](./LICENSE)
