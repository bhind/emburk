# T-0032/S02 bounded Boolean File/CSV values

Status: Stage A reviewed; Stage B authorized on Issue #144

## Authority and boundary

The slice uses original fixtures and the already admitted Embulk 0.11.5
executable only as a black box. Its SHA-256 is
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`.
No upstream implementation source is inspected or translated, and no new
artifact, dependency, license, NOTICE, redistribution, patent, or freedom-to-
operate conclusion is adopted.

Vreji's read-only triage confirmed that the T-0014/S01 artifact inventory and
T-0032/S01 provenance boundary are sufficient for exactly three local Boolean
observations. Transitive SBOM/advisories, redistribution, trademark,
jurisdiction-specific rights, patent-family/standards overlap, and FTO remain
unreviewed.

## Stage A cases

- canonical `true` and `false`;
- unquoted and quoted empty fields;
- invalid literals surrounded by valid records.

Raw configuration, inputs, stdout, stderr, exit status, output inventory, and
bytes must be retained in a private external tree and validated before semantic
assertions. Native code must not change until the Project Manager reviews the
first capture.

The first capture at
`/private/tmp/emburk-t0032-s02-boolean-capture-mu9hbxu1` was intentionally
rejected as underdetermined because a blank physical row and quoted empty field
could not be distinguished. No native rule was inferred from it.

The hardened capture is retained at
`/private/tmp/emburk-t0032-s02-boolean-capture-0xl43ape`; root manifest SHA-256
`080cb06e34b881e4a1cba61a3a44fa9e251c137a7e6b09b32bc4beda9bde6a7b`.
Its exact outputs are:

- `true`, `false` -> `true`, `false`;
- labeled unquoted empty and quoted empty -> empty field and `false`;
- `true`, `truthy`, `false` -> `true`, `false`, `false`.

All cases exited zero without timeout or stderr. The summary validator binds
the exact case order, one run UUID, case-manifest hashes, pinned JAR snapshot,
and complete tree. Jitro and Vreji reviewed the capture and authorized Stage B
within this factual boundary.

## Qwen

One 90-second non-applying request is now authorized with only the two files
listed in Issue #144 and default project context disabled. Its answer cannot
select behavior or supply evidence.
