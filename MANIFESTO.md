# Manifesto

## The agents are here. The standards are not.

Software is being rewritten from the inside. AI agents are writing code, reviewing pull requests, coordinating deployments, and making architectural decisions faster than any human team. This isn't theoretical. It's happening right now, in production, at scale.

And the foundation underneath all of it is garbage.

Every framework invents its own way to define an agent. Its own coordination model. Its own failure handling. Your workflows, your carefully tuned agent behaviors, your hard-won coordination patterns... all of it locked inside proprietary formats that become worthless the moment you switch tools.

This isn't how you build infrastructure. This is how you build a trap.

---

## We've watched this happen before.

Before OpenAPI, every REST API was a unique snowflake. Before OCI, every container runtime was a walled garden. Before CloudEvents, every event broker spoke its own dialect.

Same story every time: a wave of innovation creates fragmentation, then an open spec creates common ground so the ecosystem can actually scale.

AI agents are deep in the fragmentation stage right now. CrewAI can't talk to LangGraph. AutoGen can't run on Swarm. Your workflow definition is held hostage by whatever framework you picked first. The coordination patterns you figured out through trial, error, and 3am debugging sessions exist as tribal knowledge in your team's heads. Not as portable, validated, shareable artifacts.

We're building agentic software on formats that won't survive a migration.

---

## We're fixing it.

**OpenAgentProtocol is an open spec for defining, orchestrating, and coordinating multi-agent AI workloads.**

One file. Any runtime.

An `.oap.yaml` describes everything: what agents to spawn, what they do, how they coordinate, what quality gates they pass through, how builds get managed when multiple agents touch the same codebase. A compliant runtime reads that file and runs it. Swap the runtime, keep the workflow. Swap the model, keep the coordination. Swap the team, keep the standards.

The spec is the contract. The runtime is the implementation. They never touch.

---

## What we believe.

**Your workflows belong to you.** Not to your vendor. Not to your framework. Not to the VC-backed startup that might not exist next year. You define your agent coordination patterns once, and they run everywhere, because they validate against an open schema that anyone can implement.

**Schemas are infrastructure.** Agent coordination patterns (handoffs, epoch-based builds, parallel DAGs, plan-then-execute lifecycles) are too valuable to live as undocumented code in proprietary repos. We encode them as JSON schemas. Validated. Versioned. Portable. Unschemaed patterns are undocumented bugs waiting to diverge.

**Customization is a right, not a feature request.** You should never have to fork a framework, open a PR, or wait for a release cycle to change how your agents work. OAP is built so that everything (profiles, policies, coordination patterns, lifecycle templates) lives in your workspace, referencing our schemas. No commits here required.

**Accessibility is not optional.** A solo dev with a local model and a terminal gets the same workflow primitives as a team burning $50k/month on API calls. The simplest OAP file is ten lines. The barrier to multi-agent workflows is zero.

**Build coordination is a solved problem that nobody has shared.** Multiple agents editing the same codebase is the hardest coordination problem in agentic software. Epoch-based freeze cycles, file ownership tracking, compiler error attribution, conflict resolution... these patterns exist today in closed-source tools. We're making them public infrastructure. Every runtime gets them. Compete on execution quality, not on who invented the pattern.

**Agents need walls.** Untrusted agents get sandboxed. Communication boundaries control who talks to whom. Output visibility controls who sees what data. Execution isolation controls how much damage a rogue agent can do. Security isn't a feature you bolt on later. It's in the schema from day one.

---

## What we're building.

JSON schemas that define every primitive: agents, tasks, policies, coordination patterns, build strategies, lifecycle templates, security boundaries.

A spec that uses RFC 2119 language so there's zero ambiguity about what MUST, SHOULD, and MAY happen when a runtime processes an OAP file.

Examples for every scenario worth caring about: single agent, parallel execution, conditional DAGs, full swarm with build coordination, walled-garden isolation.

An ecosystem where your team's agent profile is as portable as a Docker image. Where a `verify-before-done` policy published by a stranger works in your workflow without modification. Where switching orchestration tools is a config change, not a rewrite.

---

## What we're not building.

Not replacing MCP. Tool interfaces are handled. Not replacing A2A. Agent discovery is handled. Not building a runtime. Not building a framework. Not building a product.

We're building the layer that's missing: the workflow definition layer. The thing that sits between "I have agents and tools" and "I have a coordinated, reliable, auditable multi-agent system."

---

## The bet.

The next decade of software gets defined by multi-agent systems the way the last decade was defined by microservices and the one before that by mobile.

The winners won't be the teams with the best models. They'll be the teams with the best coordination. The best workflows. The best policies. The best feedback loops.

And those workflows should be open.

Not "we published a blog post" open. MIT-licensed JSON schemas that any runtime can implement. Your workflow file is yours to read, modify, share, and run wherever you want. The coordination patterns that make multi-agent systems actually work are public goods, not proprietary advantages.

---

## Join or don't.

The spec is at [github.com/openagentprotocol](https://github.com/openagentprotocol). MIT license. Contributions welcome. Arguments encouraged. The schemas are the product.

We're not asking for permission.

The agents are already here. Let's give them a standard worth using.
