# OAP v0.1 Specification

Prose documentation for the OpenAgentProtocol v0.1 specification.

For schemas: [schemas/v0.1/README.md](../schemas/v0.1/README.md).
For examples: [examples/README.md](./examples/README.md).

## Spec Documents

| Document | Scope |
|---|---|
| [SPEC.md](./SPEC.md) | **Definitive reference** — execution model, merging, types, resolution order, enforcement rules |
| [CONFORMANCE.md](./CONFORMANCE.md) | Runtime conformance levels — what a runtime MUST/SHOULD/MAY implement |
| [PROTOCOL.md](./PROTOCOL.md) | Agent message protocol — envelope, types, transport bindings |
| [EPOCH_COORDINATION.md](./EPOCH_COORDINATION.md) | Build coordination — state machine, delivery model, error attribution |
| [PERSONAS.md](./PERSONAS.md) | Structured agent identity — role, expertise, style, constraints |
| [VERSIONING.md](./VERSIONING.md) | Spec versioning policy — breaking vs. additive, pre/post 1.0 |
| [PARALLELISM.md](./PARALLELISM.md) | Parallelism model — concurrency groups, resource locks, scheduling |
| [ISOLATION.md](./ISOLATION.md) | Agent isolation — communication boundaries, output visibility, execution sandboxing |
| [EXPRESSIONS.md](./EXPRESSIONS.md) | Expression syntax — interpolation, conditions, triggers |

## Reading Order

For **users** writing OAP files:
1. [Main README](../README.md) — 30-second overview
2. [examples/](./examples/) — start with `simple.oap.yaml`
3. [SPEC.md](./SPEC.md) — reference when questions arise

For **implementers** building runtimes:
1. [SPEC.md](./SPEC.md) — the definitive reference
2. [CONFORMANCE.md](./CONFORMANCE.md) — what your runtime must support
3. [schemas/v0.1/](../schemas/v0.1/) — validate against these
4. [PROTOCOL.md](./PROTOCOL.md) — if implementing multi-agent communication

## RFC 2119

Spec documents use [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) language:

- **MUST** / **MUST NOT** — Absolute requirement.
- **SHOULD** / **SHOULD NOT** — Recommended. Deviation requires justification.
- **MAY** — Optional.
