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

The authorized request used `fix` with only
`crates/emburk-core/src/configured_csv.rs` and
`crates/emburk-cli/tests/configured_csv.rs`. It timed out after 90 seconds with
no response; disposition: rejected. A separate implementer-side sandbox-blocked
attempt did not reach the network and returned no output. No model output was
used.

## Primary candidate evidence

At candidate `85c3444`, formatting, workspace check, and strict Clippy passed.
The full Rust workspace completed 146 tests with eight intentional external-
oracle ignores. The existing eight-case configured CSV differential, the new
three-case Boolean differential, and the T-0031/S03 three-case multi-file
regression all matched the pinned reference.

The primary Boolean raw evidence is
`/private/tmp/emburk-t0032-s02-differential-9n1g51fo`; root manifest SHA-256
`c6fc93d91d2e381300b977037442ebbdc72b2534d40565293b233a81e445730d`.
This is selected Differential evidence only. Independent fixed-head acceptance,
Security, and final Vreji review remain pending.

Independent acceptance at `23d4f94` reproduced 146 passes, eight intentional
ignores, existing CSV 8/8, Boolean 3/3, and multi-file 3/3 matches. Its Boolean
evidence root is `/private/tmp/emburk-t0032-s02-differential-vhc2j7f3`, root
manifest SHA-256
`bdca4a6b522882f496f2630fd54f796c4e6aabdb2a74c4a0e08b1580505c610d`.

Security found no actionable issue in the bounded parser, atomic publication,
evidence isolation, dependency, or Qwen boundary. Final Vreji review found no
blocking provenance or source-reuse issue and confirmed that unresolved
redistribution, NOTICE/SBOM, patent/FTO, trademark, standards, and broader
compatibility questions remain non-claims.
