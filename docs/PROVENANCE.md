# Traceable, License-Aware Reimplementation

This policy is an engineering control, not legal advice or a legal conclusion. Emburk maintainers may inspect upstream source, so the project does not claim formal clean-room separation.

## Objective

Reproduce documented and observed behavior while giving every consulted, borrowed, or redistributed element an explicit origin, license classification, and attribution decision.

## Permitted Source Categories

Compatibility work may use:

1. observed CLI or plugin behavior;
2. Embulk EEPs published under CC0;
3. Embulk source and design documents under Apache License, Version 2.0;
4. third-party specifications or source under their applicable terms;
5. independently authored tests and fixtures.

License classification changes what may be reused; it never removes the requirement to record provenance.

## Default Rule

Implement original Rust designs from behavior and specifications. Do not translate or paraphrase Java or Ruby code, comments, or tests into Rust unless the tracking issue explicitly records derivative reuse and satisfies Apache-2.0 and all third-party obligations.

Tests must be independently authored from behavioral requirements by default. Copied test vectors, constants, schemas, examples, or output fixtures count as copied material and require exact provenance and license review.

## Required Record

Every compatibility capability and plugin version has a record under `docs/provenance/`, linked from its index, with:

```md
# Capability or plugin
- Tracking issue:
- Implementer(s):
- Reviewer:
- Upstream repository and immutable commit/tag:
- Files, documents, and URLs consulted:
- Source categories consulted:
- Tested upstream artifact versions:
- Behavioral observations and local requirements:
- Copied or adapted material: none | exact excerpts/files
- Applicable license and NOTICE obligations:
- Runtime-only or redistributed artifacts:
- Transitive dependency audit or SBOM reference:
- Patent or trademark escalation: none | link
- Review date and approval:
```

`None` is an affirmative declaration, not an omitted field. Update the record whenever an artifact version, redistribution mode, implementation input, or compatibility claim changes. Use immutable URLs and commit identifiers rather than moving branches.

## Distribution

- Audit the core, every plugin version, and transitive dependencies independently.
- Unknown, conflicting, missing, or non-redistributable licensing blocks bundling until reviewed.
- Process isolation is a technical boundary, not a licensing boundary.
- Source archives, binaries, and containers include the project license, only relevant notices, and an SBOM of shipped components.
- Runtime installation and redistribution are classified separately.
- Human release review confirms generated notices and actual package contents.

## Patent and Trademark Escalation

Apache-2.0 has a limited contributor patent grant; it is not freedom-to-operate clearance. Novel execution, scheduling, resume, and compatibility-bridge designs require escalation before commercial release. Documentation must not claim that Emburk is patent-free or patent-safe.

Apache-2.0 grants no trademark rights. Use Embulk only for nominative compatibility statements, do not use its logo or trade dress, and never imply that Emburk is official, endorsed, or certified by Embulk. The Emburk name requires separate review before public commercial branding.
