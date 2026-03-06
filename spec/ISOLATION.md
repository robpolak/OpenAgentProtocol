# Agent Isolation & Data Boundaries

## Problem

Multi-agent workflows introduce three trust questions:

1. **Who can talk to whom?** — Communication boundaries
2. **Who can see what data?** — Output visibility
3. **How isolated is execution?** — Process/filesystem/network sandboxing

OAP answers all three declaratively. Runtimes MUST enforce.

---

## Communication Boundaries (Walled Gardens)

By default, any agent can message any other agent (via coordinator routing). The `communication` permission restricts this.

```yaml
agents:
  - name: untrusted-plugin
    permissions:
      communication:
        can_message: [coordinator]
        can_receive_from: [coordinator]
        can_handoff_to: []

  - name: lead-engineer
    permissions:
      communication:
        can_message: ["*"]
        can_receive_from: ["*"]
        can_handoff_to: [backend-1, backend-2]

  - name: backend-1
    # no communication block — unrestricted
```

### Enforcement Rules

| Field | Omitted | Set to `["*"]` | Set to specific names |
|---|---|---|---|
| `can_message` | Unrestricted | Unrestricted | Only listed targets |
| `can_receive_from` | Unrestricted | Unrestricted | Only listed sources |
| `can_handoff_to` | Handoff disabled | Any agent | Only listed agents |

Handoffs are opt-in because they transfer task ownership. Messaging is opt-out because it's informational.

- Coordinator-to-agent messages (task assignment, build coordination) are **always allowed** regardless of `can_receive_from`. The coordinator is privileged.
- `request.handoff` is checked against `can_handoff_to` on the source agent. If the target isn't listed, runtime MUST reject with `response.result` status `rejected`.
- Dropped messages SHOULD be logged as warnings, not errors.

### Pattern: Untrusted Agent

An agent running third-party code should only communicate through the coordinator:

```yaml
- name: community-plugin
  permissions:
    filesystem:
      allow_read: ["src/plugins/community/"]
      allow_write: ["src/plugins/community/output/"]
      deny: ["**/.env", "**/secrets/**"]
    network:
      allow: none
    shell:
      allow: false
    communication:
      can_message: [coordinator]
      can_receive_from: [coordinator]
      can_handoff_to: []
```

This agent can't read outside its directory, can't access the network, can't run shell commands, and can't talk to other agents directly. A walled garden.

### Pattern: Tiered Trust

```yaml
agents:
  # Tier 1: Full access
  - name: lead
    permissions:
      communication:
        can_message: ["*"]
        can_receive_from: ["*"]
        can_handoff_to: ["*"]

  # Tier 2: Can talk to lead and peers, not untrusted
  - name: backend-1
    permissions:
      communication:
        can_message: [lead, backend-2, coordinator]
        can_receive_from: [lead, backend-2, coordinator]
        can_handoff_to: [backend-2]

  # Tier 3: Coordinator only
  - name: linter
    permissions:
      communication:
        can_message: [coordinator]
        can_receive_from: [coordinator]
```

---

## Output Visibility (Data Isolation)

By default, any agent can reference any upstream task's outputs via `${tasks.<name>.outputs.<key>}`. The `visibility` field on typed outputs restricts this.

```yaml
tasks:
  - name: security-scan
    agent: scanner
    outputs:
      - name: vulnerabilities
        type: json
        visibility: [lead, reviewer]   # only these agents can read it
      - name: summary
        type: markdown                 # no visibility — everyone can see

  - name: fix-vulnerabilities
    agent: lead                        # allowed — in visibility list
    needs: [security-scan]
    inputs:
      vulns: ${tasks.security-scan.outputs.vulnerabilities}

  - name: implement-feature
    agent: backend-1                   # NOT in visibility list
    needs: [security-scan]
    inputs:
      # This would FAIL at parse time:
      # vulns: ${tasks.security-scan.outputs.vulnerabilities}
      report: ${tasks.security-scan.outputs.summary}  # OK — no restriction
```

### Enforcement Rules

- Omitted `visibility` = visible to all agents
- Empty array `visibility: []` = visible to no one (output is recorded but not consumable)
- Runtimes MUST validate at parse time: if a task's `inputs` interpolate a visibility-restricted output, and the task's agent isn't in the list, reject the workflow
- Untyped outputs (string names) have no visibility controls — use typed outputs for data isolation

---

## Execution Isolation

The `runtime.isolation` config controls how agents are sandboxed at the process level.

```yaml
runtime:
  isolation:
    level: container
    shared_filesystem: false
    shared_network: false
```

### Isolation Levels

| Level | Description | Use Case |
|---|---|---|
| `shared` | All agents run in the same process. No isolation. | Single-agent workflows, testing. |
| `process` | Each agent is a separate OS process. Shared filesystem by default. **This is the default.** | Standard multi-agent workflows. |
| `container` | Each agent runs in an OCI container. Full isolation available. | Untrusted agents, production, regulated environments. |

### Filesystem Sharing

| `shared_filesystem` | Behavior |
|---|---|
| `true` (default) | Agents share `runtime.working_dir`. File reads/writes are visible to all (subject to `permissions.filesystem`). |
| `false` | Each agent gets a private copy of the working directory. Changes are only visible to the agent. Coordinator merges changes during build epochs. |

When `shared_filesystem: false`:
- Epoch coordination becomes **mandatory** — the coordinator merges agent filesystems during BUILD
- `build.intent` and file ownership are critical for merge conflict detection
- Agents that need to read each other's changes must wait for a build epoch

### Network Sharing

| `shared_network` | Behavior |
|---|---|
| `true` (default) | Agents share the host's network. `permissions.network` controls access. |
| `false` | Each agent has an isolated network namespace (container mode only). Only coordinator can bridge. |

When `shared_network: false`:
- Agent-to-agent HTTP communication requires coordinator proxying
- Useful when agents should not discover each other's services
- Only available with `level: container`

---

## Data Interoperability

### Output Contracts

Typed outputs with `schema` define a contract between producer and consumer:

```yaml
tasks:
  - name: analyze
    agent: analyst
    outputs:
      - name: report
        type: json
        schema:
          type: object
          required: [severity, files, recommendation]
          properties:
            severity: { type: string, enum: [low, medium, high, critical] }
            files: { type: array, items: { type: string } }
            recommendation: { type: string }

  - name: fix
    agent: fixer
    needs: [analyze]
    inputs:
      report: ${tasks.analyze.outputs.report}
```

Runtimes MUST validate the output against the declared schema. If validation fails, the task fails.

### Cross-Workflow Data Flow

Sub-workflows receive inputs as key-value pairs and return their final task's outputs:

```yaml
tasks:
  - name: run-analysis
    workflow_ref: ./analysis.oap.yaml
    inputs:
      target_dir: src/models/
      depth: deep
  - name: act-on-results
    needs: [run-analysis]
    agent: lead
    inputs:
      analysis: ${tasks.run-analysis.outputs.report}
```

**Boundary rules:**
- Sub-workflows do NOT inherit parent agent permissions
- Sub-workflows do NOT inherit parent output visibility restrictions
- Sub-workflows define their own isolation level
- Inputs are the ONLY data that crosses the boundary (no implicit context leaking)

### Message-Based Data Exchange

For real-time data exchange (not DAG-bound), agents use the message protocol:

```json
{
  "type": "signal.output",
  "source": "agent:scanner",
  "target": "coordinator",
  "payload": {
    "name": "interim-findings",
    "value": { "issues_found": 3, "severity": "medium" }
  }
}
```

Communication boundaries apply: if the scanner's `can_message` doesn't include the target, the message is dropped.

---

## Combining Isolation Primitives

The six isolation controls are independent and composable:

| Primitive | Scope | Controls |
|---|---|---|
| `permissions.filesystem` | Per-agent | Which files agent can read/write |
| `permissions.network` | Per-agent | Which hosts agent can reach |
| `permissions.shell` | Per-agent | Which commands agent can run |
| `permissions.communication` | Per-agent | Which agents can communicate |
| `output.visibility` | Per-output | Which agents can read this data |
| `runtime.isolation` | Workflow-wide | Process/filesystem/network boundaries |

### Example: Maximum Isolation

```yaml
runtime:
  isolation:
    level: container
    shared_filesystem: false
    shared_network: false

agents:
  - name: untrusted-analyzer
    permissions:
      filesystem:
        allow_read: ["src/"]
        allow_write: []
        deny: ["**/.env", "**/credentials*"]
      network:
        allow: none
      shell:
        allow: false
      communication:
        can_message: [coordinator]
        can_receive_from: [coordinator]
```

This agent:
- Runs in its own container
- Has a private filesystem copy (read-only for `src/`)
- Cannot access the network
- Cannot run shell commands
- Can only communicate through the coordinator
- Its outputs are still visible by default (add `visibility` to restrict)

### Example: Minimum Isolation (Trust Everyone)

```yaml
runtime:
  isolation:
    level: shared

agents:
  - name: backend-1
    # no permissions block — unrestricted everything
```

---

## Related Schemas

- [`permissions.schema.json`](../schemas/v0.1/permissions.schema.json) — Filesystem, network, shell, secrets, communication
- [`task.schema.json`](../schemas/v0.1/task.schema.json) — Output `visibility`
- [`workflow.schema.json`](../schemas/v0.1/workflow.schema.json) — `runtime.isolation`

## Related Docs

- [SPEC.md](./SPEC.md) — Permissions enforcement, output types
- [PARALLELISM.md](./PARALLELISM.md) — Concurrency controls
- [EPOCH_COORDINATION.md](./EPOCH_COORDINATION.md) — File ownership and merge coordination
- [PROTOCOL.md](./PROTOCOL.md) — Message routing and addressing
