# OAP Examples

Complete, schema-valid `.oap.yaml` files. Start with `simple.oap.yaml`, work up.

## Workflows

| Example | What It Shows |
|---|---|
| [simple.oap.yaml](./simple.oap.yaml) | Minimum viable OAP file — 1 agent, 1 task |
| [parallel.oap.yaml](./parallel.oap.yaml) | 3 agents working independently, final merge task |
| [dag-conditional.oap.yaml](./dag-conditional.oap.yaml) | Conditional branching based on task output (`when`, `any_of`) |
| [full-swarm.oap.yaml](./full-swarm.oap.yaml) | Multi-phase swarm — planning, parallel execution with epoch build coordination, review |
| [production-migration.oap.yaml](./production-migration.oap.yaml) | Full-featured: permissions, budgets, approval gates, observability, hooks |
| [parallel-isolated.oap.yaml](./parallel-isolated.oap.yaml) | Concurrency groups, resource locks, output visibility, communication boundaries, isolation |
| [dynamic-planning.oap.yaml](./dynamic-planning.oap.yaml) | Dynamic DAG generation, model tiers (frontier/fast), replan on failure |
| [sub-workflow-test-suite.oap.yaml](./sub-workflow-test-suite.oap.yaml) | Sub-workflow, called via `workflow_ref` from a parent task |

## Templates

| Example | What It Shows |
|---|---|
| [template-bug-fix.oap.yaml](./template-bug-fix.oap.yaml) | Parameterized workflow — `${params.*}` interpolation, typed parameters with defaults |

## Profiles & Personas

| Example | What It Shows |
|---|---|
| [agent-profile.oap.yaml](./agent-profile.oap.yaml) | Reusable AgentProfile with persona, policies, lifecycle, artifacts |
| [from-agents-md.oap.yaml](./from-agents-md.oap.yaml) | Migration path from unstructured AGENTS.md to structured AgentProfile |
| [personas/senior-go-engineer.oap.yaml](./personas/senior-go-engineer.oap.yaml) | Production persona — Go engineer with constraints and domain context |
| [personas/security-reviewer.oap.yaml](./personas/security-reviewer.oap.yaml) | Inherited persona — extends senior engineer, adds security constraints |

## Progression

If you're new to OAP:

1. **Read** `simple.oap.yaml` — understand the minimum
2. **Read** `dag-conditional.oap.yaml` — understand dependencies and conditions
3. **Read** `agent-profile.oap.yaml` — understand persona + policy reuse
4. **Read** `full-swarm.oap.yaml` — understand build coordination
5. **Read** `parallel-isolated.oap.yaml` — understand parallelism controls and isolation
6. **Read** `dynamic-planning.oap.yaml` — understand model tiers and dynamic DAGs
7. **Read** `production-migration.oap.yaml` — understand the full feature set
