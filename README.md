# OpenAgentProtocol

You've got agents. They stomp each other's files. Builds break and nobody knows whose fault it is. Token costs are a black box. Task ordering is hand-rolled every time. There's no standard for any of it, so every team ships the same orchestration glue from scratch.

OAP fixes this. A YAML spec for multi-agent workflows. Write it once. Run it on any compliant runtime.

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

That's a complete workflow. DAG ordering, output chaining, agent assignment. Any OAP-compliant runtime executes it.

---

## The Problem

Agent coordination is an engineering problem, not an AI problem. Who runs when. What files they can touch. What happens when the build breaks. Which agent caused it. How much it costs.

Every framework invents its own answers. Every team reimplements them from scratch. The ecosystem is fractured and the coordination tax is real.

OAP standardizes the layer. Like OpenAPI did for REST. Like OCI did for containers.

---

## What You Get

**Any engineer can ship a multi-agent workflow.** No framework expertise. No custom plumbing. If you can write YAML, you can define a multi-agent system.

**Coordination patterns that work in production:**

| Pattern | How |
|---|---|
| Task ordering | `needs` field builds a DAG. Tasks run in dependency order, parallel where the graph allows. |
| Output chaining | `${tasks.name.outputs.field}` passes typed values between tasks. No glue code. |
| File ownership | Epoch coordination freezes agents before builds. Errors attribute to the agent that wrote the file. |
| Permission sandboxes | Declare per-agent filesystem, network, shell, and communication boundaries in the spec. |
| Budget enforcement | Token and cost limits per task, per agent, per workflow. Hard stops. |
| Dynamic task graphs | A planner agent extends the DAG at runtime based on what it discovers. |
| Loop cycles | Iterative refinement with machine-verifiable exit conditions, not LLM judgment calls. |

**Vendor-neutral.** OAP is a YAML file checked into your repo. Switch runtimes without rewriting workflows.

---

## What's in the Box

| | |
|---|---|
| **Schemas** | JSON Schemas for every primitive. Validate files, power IDE autocomplete, enforce contracts. |
| **Spec** | Normative prose covering execution model, coordination, isolation, personas, expressions. |
| **Examples** | 15 complete `.oap.yaml` files covering simple, parallel, conditional, loop, epoch-coordinated, and dynamic-planning patterns. |

---

## Status

**v0.1. Draft.** Primitives are stabilizing. Breaking changes expected before 1.0.

---

## Docs

Start here:

- **[TECHNICAL.md](./TECHNICAL.md)** full architecture, all primitives, execution models, coordination, isolation, message protocol
- **[spec/WORKFLOW_GUIDE.md](./spec/WORKFLOW_GUIDE.md)** build `.oap.yaml` files fast. Token-efficient LLM reference.
- **[spec/examples/](./spec/examples/)** 15 runnable examples, from 10-line basics to epoch-coordinated multi-agent builds

Go deeper:

- **[spec/SPEC.md](./spec/SPEC.md)** definitive normative spec. Resolves all ambiguities.
- **[spec/EPOCH_COORDINATION.md](./spec/EPOCH_COORDINATION.md)** how multi-agent builds stay coherent
- **[spec/PARALLELISM.md](./spec/PARALLELISM.md)** concurrency groups, resource locks, scheduling
- **[spec/ISOLATION.md](./spec/ISOLATION.md)** communication boundaries, sandboxing
- **[CHANGELOG.md](./CHANGELOG.md)** what changed

---

[MIT License](./LICENSE)
