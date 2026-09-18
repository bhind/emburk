# T-0031/S03 bounded multi-file configured input

Status: Done through PR #142 (`3dfb006`)

## Scope and provenance

This implementation is repository-original and is derived from the accepted
black-box observations in T-0014/S03. No upstream implementation source was
inspected or translated. The only external runtime permitted for differential
verification is the already-admitted Embulk 0.11.5 executable with SHA-256
`e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47`
under Java 17. Its existing license, NOTICE, SBOM, redistribution, security,
patent, and freedom-to-operate limitations remain unchanged and unreviewed.

## Implementation boundary

The candidate admits at most two ordinary configured File/CSV inputs, fixed
indexed outputs, checked aggregate reporting, full output-target preflight, and
explicit report alias guards. Publication is sequential and independently
no-clobber per output. Stateful execution remains exactly one input.

## Qwen consultation

The original 2026-09-12 consultation used the Issue allowlist and timed out;
its output was rejected and did not influence implementation. During recovery
on 2026-09-18, one additional non-applying request failed at the network layer
before a response. No Qwen response was received or adopted. Deterministic
repository checks, not model output, remain the evidence boundary.

## Primary candidate evidence

At candidate `903596e`, formatting and strict workspace Clippy passed. The full
workspace completed 144 tests with eight intentional external-oracle ignores.
The pinned live comparison matched all three admitted cases: two regular files,
the same filenames with contents exchanged, and one regular file plus an empty
matching directory. Raw evidence is retained outside the repository at
`/private/tmp/emburk-t0031-s03-differential-cgyphec5`; its root manifest SHA-256
is `14294492f42e1ce754dad38bfca6fff01cffb866c1e4608fe4edc167ce9dff5d`.

Two earlier retained runs exposed and then corrected driver-only defects: the
supplied output directory was inventoried through a nonexistent child, and a
native malformed-input test had been incorrectly substituted for the admitted
contents-exchanged reference case. Their raw results were not converted into
runtime rules or compatibility claims.

Independent acceptance at `a06d49a` reproduced 144 passes, eight intentional
ignores, strict Clippy, and all three live comparisons. Its raw evidence is
`/private/tmp/emburk-t0031-s03-differential-8fgb4n3g`, root manifest SHA-256
`07323b396be1b126b0c0d86cd29635520d87a6ed8237304047535acb4896586d`.

Security review treats concurrent pathname replacement as outside the trusted
local-filesystem profile for both ordinary and stateful execution. Stateful
selection opens and descriptor-validates exactly one candidate before state
access, but the accepted checkpoint path subsequently derives identity and
reads through the pathname. It therefore does not defend against a hostile
same-UID rename between selection and state processing.

This record makes no general compatibility, atomicity, parallelism,
performance, hostile namespace defense, security, redistribution, or
patent-clearance claim.
