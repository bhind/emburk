# Embulk Reference Inventory

- Tracking issue: [T-0011](https://github.com/bhind/emburk/issues/14)
- Branch: `chore/t-0002-project-bootstrap` (shared initial integration branch)
- Implementer(s): Project Manager
- Reviewer: Librarian
- Access date: 2026-09-05

## Pinned references

| Reference | Immutable identity | Locator | License classification | Admission |
|---|---|---|---|---|
| Embulk core `v0.11.5` | annotated tag `3612e23d7c634cdad6ab42031143249e79da2681`; commit `c5ac2d471edac465b45088669d376a7e2a525f8f` | [repository](https://github.com/embulk/embulk/tree/c5ac2d471edac465b45088669d376a7e2a525f8f), [LICENSE](https://github.com/embulk/embulk/blob/c5ac2d471edac465b45088669d376a7e2a525f8f/LICENSE), and [executable NOTICE](https://github.com/embulk/embulk/blob/c5ac2d471edac465b45088669d376a7e2a525f8f/NOTICE-executable) | Apache-2.0 source; executable redistribution also requires review of the pinned NOTICE and bundled dependencies | Behavior reference only; no source or notice text reused |
| Embulk SPI `0.11` | annotated tag `098192a80a3f6d9df89e5cc4e77304b0798e5bbc`; commit `576e98033a14ba8ac994ed581d3c9d8fcdda2749` | [repository](https://github.com/embulk/embulk-spi/tree/576e98033a14ba8ac994ed581d3c9d8fcdda2749) and [LICENSE](https://github.com/embulk/embulk-spi/blob/576e98033a14ba8ac994ed581d3c9d8fcdda2749/LICENSE) | Apache-2.0 | Interface reference only; no source text reused |

The selected design inputs are EEPs
[3](https://github.com/embulk/embulk/blob/c5ac2d471edac465b45088669d376a7e2a525f8f/docs/eeps/eep-0003.md),
[5](https://github.com/embulk/embulk/blob/c5ac2d471edac465b45088669d376a7e2a525f8f/docs/eeps/eep-0005.md),
[6](https://github.com/embulk/embulk/blob/c5ac2d471edac465b45088669d376a7e2a525f8f/docs/eeps/eep-0006.md),
[7](https://github.com/embulk/embulk/blob/c5ac2d471edac465b45088669d376a7e2a525f8f/docs/eeps/eep-0007.md),
[9](https://github.com/embulk/embulk/blob/c5ac2d471edac465b45088669d376a7e2a525f8f/docs/eeps/eep-0009.md), and
[10](https://github.com/embulk/embulk/blob/c5ac2d471edac465b45088669d376a7e2a525f8f/docs/eeps/eep-0010.md)
at the pinned core commit. Each declares CC0-1.0 Universal. They are consulted
only for design and compatibility rationale; no text is copied or adapted.

No external plugin artifact is admitted by T-0011. The artifact coordinates
embedded by Embulk 0.11.5 are discovery candidates only. Each candidate needs
its own immutable source or package identity, license and NOTICE classification,
artifact checksum, redistribution decision, and differential fixture before it
can enter the compatibility matrix.

## Use and evidence boundary

- Source categories consulted: repository structure and build metadata,
  Apache-2.0 source and notices, and CC0 EEPs.
- Tested upstream artifact versions: none; this task pins references and does
  not run a compatibility fixture.
- Copied or adapted material: none.
- Runtime-only or redistributed artifacts: none.
- Transitive dependency audit or SBOM reference: pending T-0005.
- Patent or trademark escalation: branding and novel-mechanism review pending
  T-0006.
- Behavioral observations: SPI 0.11 is separately versioned; plugin artifacts
  are packaged independently; lifecycle and resume behavior still require
  contracts and differential tests; JRuby is optional in the selected line.
- Review state: independent Librarian review passed after corrections on
  2026-09-05; Project Manager review and final integration remain pending in
  [Draft PR #53](https://github.com/bhind/emburk/pull/53).

This is Planning evidence. It does not establish compatibility, exactly-once
delivery, performance advantage, production readiness, redistribution or legal
clearance, freedom to operate, upstream endorsement, or completion of T-0011.
