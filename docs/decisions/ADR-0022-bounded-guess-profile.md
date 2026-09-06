# ADR-0022: Bounded native guess profile

Status: Accepted and integrated through PR #124 (T-0036/S02).
Date: 2026-09-06.

Guess completes missing seed fields and preserves explicit choices. The initial
native profile uses the existing YAML/CSV/JSON/codec adapters, bounded whole-file
samples, and no new dependencies. JSON syntax is emitted as valid YAML; textual
serialization equality is not required for configuration semantics.

Actual S01 observations show that JSON guessing does not infer columns and
charset detection is not equivalent to UTF-8 validation. Therefore native JSON
column invention and fixture-specific charset guesses are rejected approaches.
Unsupported TSV/charset/header/type cases remain open compatibility gaps, not
silently accepted exceptions. A JSON guess may still require explicit columns
before the selected CSV-output pipeline can execute it.

No-clobber publication protects explicitly requested configuration output. The
packet defines exact bounds, admitted behavior and acceptance commands. Combined
guess/transfer/interruption/resume acceptance is a separate T-0037 slice and
must classify reference gaps honestly.
