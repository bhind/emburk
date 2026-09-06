# Executable pipeline delivery sequence

Owner authorization: continue through stages 1–7, 2026-09-06. This is an
execution plan, not evidence that any listed capability is complete. Existing
experimental line file/stdout/null consumers remain available throughout.

| Stage | Canonical task | Exit evidence |
| --- | --- | --- |
| 1. Parser | T-0022/S01 | Pinned dependency/license inventory and original syntax experiment; retained mismatches against S13 |
| 2. Configured transfer | T-0022/S02 | Configuration selects real source and sink; invalid configuration fails before output creation; prior commands still pass |
| 3. CSV/schema | T-0032 | Quoted/multiline/empty/type cases through actual file transfer and logical schema; bounded record handling |
| 4. Reference comparison | T-0014, T-0037 | Same selected fixtures run through pinned Embulk/plugin artifacts and native path; exact outputs/errors reviewed; no guessed normalization |
| 5. Failure/publication | T-0025 | Explicit unpublished/committed output state; injected read/write/flush/publish/interruption cases; old destination never damaged |
| 6. Formats/codecs/filter | T-0033, T-0034, T-0035 | JSON records, admitted compression codecs and explicit filters execute in the same pipeline with regression tests |
| 7. Parallel/cancel/resume | T-0024, T-0025 | Bounded admission, deterministic ordering, cancellation, validated resume identity/checkpoints; interruption and input-change tests |

PM will allocate independently acceptable slices monotonically within these
tasks, before implementation; at most two active Project items. Estimates are
per slice, not an invented completion percentage for this sequence. Each packet
fixes artifacts, mutations, Demo, evidence and non-claims; successful acceptance
is committed, reviewed, pushed, merged and mirrored to the private Project.

## Decisions that cannot be replaced by a green unit test

- A native configuration or output policy is not automatically Embulk parity.
  Reference/plugin versions and real mismatch cases must be recorded.
- Configuration parsing must preserve information until compatibility rules
  apply. Lossy encoding or parser-default coercion is not presumed correct.
- Atomic visibility and durable recovery are different properties. Publication
  must specify same-filesystem constraints, existing-target behavior and crash
  windows before implementing checkpoints.
- Resume validates configuration, input identity and committed output state;
  blindly skipping N records is not accepted recovery.
- Parallel worker count is not a memory bound. Account for admitted records,
  maximum record size, result ordering and cancellation ownership.
- Unsupported behavior stays visibly unsupported; no permanent compatibility
  exception follows merely from using Rust instead of Java.

## Resource guard

Read the current conversation's local `event_msg` token-count `rate_limits`
metadata at phase boundaries. Identify weekly windows by `window_minutes=10080`
rather than assuming primary versus secondary. Use the newest timestamp and
report reset/unknown data honestly. Stop before further implementation when
weekly remaining is below 10%; preserve partial work. A generic ability to reply
does not prove allowance. No account identifiers, tokens or raw session text
belong in public Issues. DeepSeek connectivity is deferred, not a prerequisite.
