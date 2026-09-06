# T-0036/S01 guess reference observations

Issue: [#29](https://github.com/bhind/emburk/issues/29). Done via PR #123; accepted 3 SP.
Owner authorized observation, bounded native guess, then integrated acceptance.
The prior seven-stage slice is integrated through PR #122. Broader parser,
codec and recovery parent contracts remain open; prerequisites here are only
their independently accepted bounded slices, not inferred whole-parent Done.

## Branch and allowlist

Branch research/t-0036-guess-observations. PM owns this packet, docs/STATUS.md,
TODO.md and tools/guess-oracle/run.py plus tests/test_guess_oracle.py. Initial
black-box evidence is retained under fresh /private/tmp directories. Read-only
specialists inspect provenance/runtime prerequisites without modifying sources.
No native implementation is authorized before actual reference review.

## Sources and intended observations

Pinned Embulk 0.11.5 executable from
https://github.com/embulk/embulk/releases/download/v0.11.5/embulk-0.11.5.jar,
SHA256 e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47.
Artifact admission/license/NOTICE is recorded in T-0014/S01 and S02 packets.
Java17 local observation only; no redistribution. Accessed 2026-09-06.

Official https://www.embulk.org/docs/built-in.html#guess-executor documents
ordered gzip/bzip2/json/csv guessing and a default 32 KiB sample target. This
describes a target, not native admission or a hard upstream memory bound.
CLI `guess --help` on the exact JAR confirms partial-config and -o output options.
Observed help exit 255 is not a successful guess execution.

Default embedded module byte identities (outer JAR lib/ locator):

| Module | Version | SHA256 |
| --- | --- | --- |
| embulk-guess-gzip | 0.11.1 | 58b26f44efd3d25b5283c3f2ddb11a865f7081c51bf016b8b61619812ec5e5ed |
| embulk-guess-bzip2 | 0.11.1 | 7e6ae600c8dc4e6b9a076ee94ddbc039ed9c4f255dac4e5def16753cf6cf2c75 |
| embulk-guess-json | 0.11.2 | 6de531904ee34002a2914cc5d9047b4ae08f44881192800151cd6a603f15bbdc |
| embulk-guess-csv | 0.11.6 | f1be4ebefe3b35a862b6f7bbc5a9e889e853406270458b7290a7f589b824a65b |
| embulk-util-guess | 0.4.0 | bebc7762e6338af3168bc9c6b88e9c2ed5bf4b701aef52e7c32f6872eeef0ed5 |

All five contain META-INF/LICENSE (Apache-2.0), SHA256
cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30.
Util-guess additionally carries META-INF/LICENSE-icu4j SHA256
8c00e858a96db33a9e42f2043b66d96f9d2381d76601a1b0c1ee15fa5a17ca48
and META-INF/NOTICE SHA256
3b7b199772a892bb30a5aff925f0fde71dd7e79bfc4dfec20be816516329fc63.
Librarian inspected metadata only, not source bodies. These are admitted only
for local black-box observation. Individual redistribution/security/ICU
attribution and patent/FTO remain unreviewed.

## Initial observations and implementation decision points

Eight actual probes completed in
/var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/emburk-t0036-guess-w03opomv.
CSV/gzip/bzip2 generated long/string columns and explicit false CSV policies.
JSON generated parser type/charset/newline but no columns: a guessed JSON
configuration is not automatically runnable with the existing CSV output.
Empty input exited 1. Prose was treated as one string column named c0, not
rejected as ambiguous. TSV selected a tab delimiter. The tiny headerless ASCII
fixture selected ISO-8859-9, demonstrating that byte-valid UTF-8 alone does not
reproduce upstream charset heuristics. These results must not be normalized
away or turned into hardcoded fixture-specific output.

Before native admission, distinguish a bounded supported profile from open
charset, delimiter and schema gaps. Explicit schema preservation for JSON must
be tested separately; native-only schema inference must not be called parity.

Observe actual CSV, JSON, gzip/bzip2, empty and ambiguous fixtures with fresh
isolated runtime directories, exact input/config/artifact hashes, bounded
subprocess timeouts and retained exits/stdout/stderr/guessed configurations.
Unknown runtime prerequisites are recorded before adoption; no guessed expected
outcome or silent normalization. Do not copy upstream implementation code.
License permission is distinct from patent/FTO; unreviewed gaps are not cleared.

## Demo Command

`PYTHONDONTWRITEBYTECODE=1 python3 tests/test_guess_oracle.py && PYTHONDONTWRITEBYTECODE=1 python3 tools/guess-oracle/run.py && git diff --check`

Requires pinned EMBURK_REFERENCE_JAR and Java17 JAVA_HOME. Ten fixture exit/config
hash projections are pinned after actual review, including added explicit JSON
columns and headerless UTF-8 seed cases; the harness fails on any drift. Those
additional cases preserve columns and charset respectively. Initial ten-case
evidence: /var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/emburk-t0036-guess-pn8pd7ob.
No native dependency, code or interpretation is admitted by this reference slice.

## Evidence class, stop rule and non-claims

Primary and independent exact Demo passed at 1d577dddb2209240fa96c1457fb2f3c669fbe30a.
Three harness tests and ten pinned guess projections matched. Primary retained
root: /var/folders/mh/pwg8ncpd23g7bp63xgnh461r0000gn/T/emburk-t0036-guess-0525q9a5.
Independent /private/tmp/t0036-s01-independent.MjSxrL stdout SHA256
52807f02e310b614a169fbf2453775da9cb2812a948f31621035f254d1ec8439;
stderr 69796c8069b47be836df270a88b29823ad41a084acbab76d06c1d4ae5f567053;
exit 0, SHA256 9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa.
Independent revision/status unchanged. Merge cdb0fdcbcbe8c6ef13dcd2a13d6b1fb0327860c5.

Reference-only observation. Stop native implementation on missing reference
runtime, unreviewed dependency admission, unsafe writes or unexplained behavior.
No full guessing/profile/parity or combined acceptance claim until executable
evidence and independently reviewed PR integration exist.
