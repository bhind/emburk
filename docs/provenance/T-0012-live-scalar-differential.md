# T-0012/S04 live scalar differential

State: In Progress. Compare exactly 13 S01/S02-supported typed outcomes through
the pinned local oracle and private Rust resolver. A Python-stdlib driver retains
raw JSONL externally and writes versioned TSV with hex strings; Rust parses only
that TSV. IDs validate manifest membership/count, never select outcomes. Unknown
oracle errors fail closed. Demo runs the oracle and exactly one ignored Rust test;
normal tests skip it. Negative tests cover missing, duplicate, truncated,
malformed-tag/hex, unknown-exception, and mutated-outcome evidence. No lexical,
decimal, overflow, message/timing, YAML, parser, public API, dependency, or
full-compatibility claim.
