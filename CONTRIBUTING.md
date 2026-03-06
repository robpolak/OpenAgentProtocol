# Contributing

Read these first:
1. [KEY_TENETS.md](./KEY_TENETS.md) - every contribution must align
2. [AGENTS.md](./AGENTS.md) - repo structure, primitives, and **writing voice**
3. [spec/VERSIONING.md](./spec/VERSIONING.md) - what counts as breaking

## What We Want

- **Real-world workflow examples.** `.oap.yaml` files for actual use cases, not toy demos.
- **Schema improvements.** Tighter validation, better defaults, clearer errors.
- **Runtime implementations.** CLI, library, or integration that executes OAP files.
- **Conversion tools.** Import/export between OAP and existing formats (CrewAI, LangGraph, etc).
- **Bug reports.** Ambiguities, contradictions, or cases where two runtimes would diverge.

## Spec Changes

Spec changes affect every runtime. Higher bar.

1. **Open an issue first.** Describe the problem with a concrete example.
2. **Schema first.** Update JSON Schema before writing prose. See [schemas/v0.1/README.md](./schemas/v0.1/README.md).
3. **Include examples.** Every spec change needs a `.oap.yaml` example.
4. **Checklist:**
   - Aligns with [KEY_TENETS.md](./KEY_TENETS.md)?
   - Core or extension? Default: extension.
   - Two independent runtimes can implement identically?
   - Simplest OAP file still fits in ~10 lines?
   - Expression syntax follows [spec/EXPRESSIONS.md](./spec/EXPRESSIONS.md)?
5. **Open a PR.** Reference the issue. One logical change per PR.

## Examples and Docs

Low barrier. Open a PR. Add your example to `spec/examples/`. Must validate against the schema (`make validate`).

## Bug Reports

- The OAP file that triggers the problem
- What you expected
- What happened (or what's ambiguous)

## Style

- **YAML:** 2-space indent. No tabs.
- **Prose:** RFC 2119 language (MUST, SHOULD, MAY) in spec docs. Plain English elsewhere. See [AGENTS.md](./AGENTS.md) writing voice section.
- **Commits:** Short subject line. No prefix convention.

## Versioning

Pre-1.0. Breaking changes are expected. See [spec/VERSIONING.md](./spec/VERSIONING.md).

- Adding optional field = same version (OK)
- Renaming or removing a field = new version (justify it)
- New schema file = same version (OK)
- Changing required fields = new version (justify it)

## License

Contributions licensed under [MIT](./LICENSE).
