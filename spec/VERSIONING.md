# Spec Versioning

## Version Format

```
0.x   — Pre-stable. Breaking changes expected.
1.0   — Stable. At least two independent runtimes pass conformance.
1.x   — Stable with additive changes only.
2.0   — Next major. Breaking changes from 1.x.
```

Current version: **0.1**

## What Lives in `oap_version`

Every OAP document declares its version:

```yaml
oap_version: "0.1"
```

Runtimes use this to select the correct schema set. A runtime MAY support multiple versions simultaneously.

## Schema Directory Layout

```
schemas/
  v0.1/    — Current draft
  v0.2/    — Next draft (when needed)
  v1.0/    — First stable release (future)
```

Each version directory is self-contained. No cross-version `$ref` allowed.

## Change Classification

| Change | Version Impact | Example |
|---|---|---|
| New optional field | Same version | Add `budget` to agent |
| New enum value | Same version | Add `gated` to build strategy |
| New schema file | Same version | Add `permissions.schema.json` |
| Rename field | **New version** | `file_scope` → `allowed_paths` |
| Remove field | **New version** | Drop `instructions` from agent |
| Change field type | **New version** | `timeout: string` → `timeout: integer` |
| Change required fields | **New version** | Make `model` required on agent |
| Change validation rules | **New version** | Tighten `name` pattern |
| New document kind | Same version | Add `WorkflowTemplate` |

## Pre-1.0 Rules

While `oap_version` starts with `0`:

1. Breaking changes are encouraged when they improve abstractions.
2. No formal deprecation cycle. Old version directories remain for reference but are not maintained.
3. The CHANGELOG tracks what broke and why.
4. Runtimes SHOULD pin to a specific `oap_version` and document which versions they support.

## Post-1.0 Rules

Once `oap_version: "1.0"` ships:

1. Additive changes only within a major version (1.0 → 1.1 → 1.2).
2. Breaking changes require a new major version (1.x → 2.0).
3. Deprecated fields get a 2-minor-version grace period before removal in the next major.
4. `oap_version` in documents MUST match a published schema directory.

## Runtime Compatibility

A runtime declares which OAP versions it supports in its own documentation or configuration. When a runtime encounters an `oap_version` it doesn't support, it MUST reject the document with a clear error, not silently ignore unknown fields.

## Forward Compatibility

OAP documents SHOULD be forward-compatible within a major version:

- Unknown fields at any level MUST be ignored by runtimes (not rejected).
- Unknown enum values SHOULD be treated as errors (explicit fail, not silent default).
- Unknown `x-*` extension fields MUST be ignored.
- Unknown `kind` values MUST be rejected.
