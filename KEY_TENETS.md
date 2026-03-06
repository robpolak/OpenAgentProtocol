# Key Tenets

## Mission

**Define once, run anywhere.** Open spec for multi-agent AI workflows. No runtime owns it. Everyone can use it.

## Problems We Solve

1. **Coordination has no standard.** Every framework invents its own agent coordination: handoffs, group chat, DAGs, epochs. Hard-won patterns, totally non-portable. OAP codifies them into validated JSON schemas.

2. **Workflows are locked to runtimes.** A CrewAI workflow can't run on LangGraph. A Swarm config can't execute on a CLI. OAP is the interchange format. Same `.oap.yaml` runs everywhere because schemas define the contract, not the implementation.

3. **Customization means forking.** Most frameworks force you to modify their source to change agent behavior. OAP lets users customize everything (profiles, policies, coordination, lifecycle) in their own workspace. Reference our schemas. Never commit to this repo.

4. **Agent identity is freeform text.** System prompts, AGENTS.md, .cursorrules. Not portable, not composable, not enforceable. OAP [Personas](./spec/PERSONAS.md) give agents structured identity: role, expertise, style, and runtime-enforceable constraints.

5. **No security model for agents.** Most frameworks give agents full system access. OAP [Permissions](./schemas/v0.1/permissions.schema.json) declare filesystem, network, shell, secret, and [communication boundaries](./spec/ISOLATION.md). Agents get sandboxed into walled gardens: restricted in who they message, what data they see, and how isolated their execution is.

---

## Tenets

### 1. Portability Over Performance

Your workflow belongs to you, not your vendor. An `.oap.yaml` runs on any compliant runtime: macOS GUI, headless CLI, CI pipeline, or something that doesn't exist yet. Switching tools never means rewriting workflows.

Fast-but-proprietary vs portable-but-slower? We pick portable every time. Runtimes compete on execution. The spec stays neutral.

### 2. Accessible by Default

A solo dev with a local model and `oap run` gets the same primitives as an enterprise team. Simplest OAP file is ~10 lines. No contracts, no API key minimums, no proprietary GUIs.

If you need to read the spec to use the spec, we failed.

### 3. Transparent and Auditable

The OAP file IS the documentation. Read it and you know exactly what agents exist, what tasks they run, how they coordinate, and what gates they pass through. No hidden orchestration. No opaque side channels. No implicit behavior.

If you can't understand an agent's behavior from the file that defines it, the spec is broken.

### 4. Schemas Are the Product

JSON schemas are the portability layer. They validate OAP files, power IDE autocomplete, and guarantee two runtimes interpret the same file identically. Ship as standalone artifacts: reference by URL, vendor into your project, or extend locally.

Coordination patterns get encoded as schema-validated structures, not prose. If a pattern doesn't have a schema, it's not real.

### 5. Customizable Without Contributing

Users MUST be able to customize everything (agent profiles, policies, coordination, lifecycle) in their own workspace. No fork. No PR. The extension mechanism (`x-*` namespaces, `$ref` to local files, custom policies) makes your workspace the source of truth.

This repo ships core schemas. Your repo ships your config.

### 6. Composable and Shareable

Agent profiles, policies, and workflow templates are independent, reusable units. A `verify-before-done` policy from one team works in any workflow, on any runtime. Engineering standards become portable artifacts instead of tribal knowledge.

Community patterns live in their own repos, published as packages or referenced by URL. This repo is the spec, not the pattern library.

### 7. Declarative Over Imperative

OAP describes WHAT, not HOW. The spec defines agents, tasks, dependencies, policies, success criteria. The runtime decides execution strategy, scheduling, concurrency, resource allocation.

Two runtimes given the same file should produce the same observable outcomes even if their internals differ completely.

### 8. Minimal Core, Extensible Surface

Core spec covers 80% of multi-agent workflows with a small primitive set. Runtime-specific features live in namespaced extensions (`x-swarm`, `x-crewai`) that don't break validation and aren't required for execution.

New core addition? Answer this first: "Does this belong in the spec or in an extension?" Default is extension.

### 9. Build Coordination as Public Infrastructure

Multiple agents editing the same codebase simultaneously (epoch-based freeze/build/attribute/feedback cycles, file ownership, conflict resolution, compiler error attribution) should not be proprietary. It belongs in the open spec so every runtime benefits. Compete on quality, not on who invented the pattern.

---

## Anti-Tenets

Things we explicitly do NOT optimize for:

- **Maximum flexibility.** We constrain to prevent ambiguity. Two runtimes must agree on what a file means.
- **Backward compat at all costs.** Pre-1.0, we break things to get abstractions right. Stability comes after correctness.
- **Replacing existing protocols.** OAP doesn't replace MCP (tools), A2A (discovery), or any framework's internals. One layer above.
- **Enterprise-first features.** If it only matters at scale, it's an extension. Core serves everyone.

---

## Design Principles (Spec Authoring)

1. **RFC 2119 language.** MUST, SHOULD, MAY have precise meaning. Use them.
2. **Schema-first.** Every primitive gets a JSON Schema before prose. Can't schema it? Too vague.
3. **Example-driven.** Every section has at least one complete, runnable example.
4. **Forward-compatible.** Unknown fields get ignored, not rejected. Extensions don't break old parsers.
5. **YAML is the authoring format.** 2-space indent. No tabs.
