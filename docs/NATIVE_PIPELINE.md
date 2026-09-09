# Experimental native pipeline

This guide describes the selected native profile, not general Embulk plugin
compatibility. Use a new output prefix: existing final files are never replaced.
The configured path is intended for trusted local Unix filesystems.

## Minimal configured transfer

Build with `cargo build --locked`. In a separate job directory create an
`input.csv` file containing:

```csv
id,name
1,Ada
2,"comma, snowman ☃"
```

Create the `output` directory and save this as `config.yml`:

```yaml
in:
  type: file
  path_prefix: input.csv
  parser:
    type: csv
    charset: UTF-8
    newline: LF
    delimiter: ','
    quote: '"'
    escape: '"'
    skip_header_lines: 1
    columns:
    - {name: id, type: long}
    - {name: name, type: string}
out:
  type: file
  path_prefix: output/result
  file_ext: csv
  formatter:
    type: csv
    charset: UTF-8
    newline: LF
    delimiter: ','
    quote: '"'
    escape: '"'
    header_line: true
    quote_policy: MINIMAL
exec:
  max_threads: 4
  min_output_tasks: 1
```

Run `/path/to/emburk/target/debug/emburk run config.yml` from the job directory.
Relative paths resolve against the process working directory, not the config
file's parent. The selected single-task output is `output/result000.00.csv`.
At most one regular input may match the prefix. An unmatched ordinary run
produces no output. The output directory must already exist.

### Optional native result report

For an ordinary configured run, reserve a new machine-readable result file:

```sh
emburk run config.yml --report run-result.json
```

The report is an experimental Emburk-owned CLI contract. Its fixed v1 object is
written as UTF-8 JSON followed by LF:

```json
{"schema":"emburk.run-result/v1","command":"run","outcome":"succeeded","exit_code":0,"records":2,"error":null}
```

Successful reports contain the exact emitted record count. Failed and cancelled
reports use `records: null`, exit codes 1 and 130 respectively, and copy the
complete `emburk: run failed: ...` stderr diagnostic into `error`. The report is
reserved exclusively with owner-only permissions after successful SIGINT-handler
installation and before configuration loading. This ordering prevents a handled
SIGINT from leaving an empty reserved report. An existing report path exits 2
without executing the pipeline. Choose a report path outside the configured
input `path_prefix` and distinct from the configured final output. A collision
can affect the existing input selection or output no-overwrite checks, so the
pipeline fails explicitly and leaves a failed report rather than silently
excluding the reserved path.

Report writing is flushed but is not atomic or durability-guaranteed. A crash
or report I/O failure may leave an empty or partial report; a configured output
already published before a report-write failure can remain valid. Reports are
not implemented for stateful run, resume, guess, or `transfer-lines` commands.
This format is not an Embulk structured-error or report compatibility claim.

## Selected formats and filters

- JSON input: replace the parser with `type: json` and the same `columns` list;
  omit CSV parser options. Input is a sequence of JSON objects. Only configured
  long/string/null fields are supported, not arbitrary coercions.
- Compressed input: add `decoders: [{type: gzip}]` or
  `decoders: [{type: bzip2}]` under `in`.
- Compressed output: add `encoders: [{type: gzip, level: 6}]` or
  `encoders: [{type: bzip2, level: 9}]` under `out`.
- Column filters: top-level `filters` may contain
  `{type: rename, columns: {name: label}}` and
  `{type: remove_columns, remove: [label]}` in the intended order. References
  use the schema at that point; swapping filters can be invalid.

Unknown options and unsupported profiles fail explicitly. Configuration is
bounded to 64 KiB; logical records are bounded to 1 MiB and 256 columns. One
to eight workers format records; source parsing is serial. The whole admitted,
not-yet-written window is bounded to twice the worker count, with ordered output.

## Cancellation and output safety

SIGINT requests cooperative cancellation. Before publication, cancellation
returns exit 130 and does not expose a partial final file. Blocking filesystem
operations do not have a hard interruption deadline. Once a final file is
linked, cancellation or cleanup errors cannot roll it back.

Output is staged in an owned private sibling temporary, finalized and synced,
then linked without clobbering an existing destination. Errors distinguish
unpublished output from published output with uncertain durability or cleanup.
Inspect reported state and retained paths before retrying; never assume a
nonzero exit means that no output exists. Abrupt process death can leave owned
temporary residue. There is no automatic removal of unrelated files.

## Stateful run and resume

T-0025/S02 integrated the following commands through PR #121, after primary and
independent acceptance. Start with a state-directory path that does not exist:

```sh
emburk run config.yml --state job-state
emburk resume config.yml job-state
```

After SIGINT, keep the input, configuration, working directory and state intact.
Resume validates the input/configuration hashes, checkpoint chain and exact
reformatted saved prefix before trimming any uncheckpointed spool tail. It
rejects changed inputs/configuration, conflicting outputs and concurrent state
writers. Repeating resume after success validates the prepared output identity
without replacing it. If the final target was deleted after success, recovery
fails instead of silently publishing it again.

State is private to this native profile and local Unix filesystem. It retains
an uncompressed formatted spool (maximum 8 GiB), bounded 64 KiB manifests and
at most 65,536 generations. Checkpoints occur every 1,024 valid records or
4 MiB, plus the header and completion. Prefix replay and full input hashes take
I/O time; compression restarts from the complete verified spool. This is not a
compressed fast-seek or an Embulk resume-file implementation. Preserve retained
state until inspected; automated state garbage collection is not implemented.

Ordinary `run` does not checkpoint. The earlier `transfer-lines`
commands remain experimental and do not inherit the configured publication
contract.

## Bounded guess

`emburk guess seed.yml -o config.yml` fills missing input parser/decoder fields
while retaining the output and execution configuration. Without `-o`, the
result goes to stdout. Output uses JSON syntax, which is valid YAML; an existing
destination is never overwritten. Provide a file input type/path_prefix and
the desired output settings in the seed.

For the CSV example above, remove the entire `in.parser` section to make a
seed, retaining `in.type`, `in.path_prefix`, `out` and `exec`. Then run:

```sh
emburk guess seed.yml -o config.yml
emburk run config.yml --state job-state
# After interruption, with unchanged job input and configuration:
emburk resume config.yml job-state
```

The initial whole-file profile rejects raw inputs over 1 MiB or decoded inputs
over 32 KiB. It supports selected UTF-8/LF/comma CSV and JSON object inputs,
with one gzip/bzip2 layer. JSON guessing preserves explicit columns but does
not invent them; supply parser.columns to execute the current CSV output.
Headerless numeric CSV needs an explicit parser.charset of UTF-8. TSV, general
charset/type inference and large-input sampling remain unsupported. Explicit
parser fields other than charset/columns are rejected, not silently replaced.

T-0037/S01 (#125) compares seven guessed configurations, six generated-config
transfers and four native interrupted/resumed jobs with pinned reference
results. Recovery fixtures guess from a small sample and create the larger
same-schema job input before execution; this does not demonstrate guessing
directly from a large file. TSV and automatic headerless charset inference are
recorded gaps, not counted as successful comparisons.

## Parallel MVP demonstration

The configured pipeline uses scoped native threads for independent record
formatting and one ordered writer. `exec.max_threads` selects one to eight
workers; the total admitted but unwritten window remains at most twice that
number. Tokio is not a dependency of this local-file profile.

Run a real, self-contained CSV and JSON File-to-File smoke demonstration from
the repository root:

```sh
cargo build --release --locked && \
python3 tools/t0071-benchmark/run.py \
  --binary target/release/emburk \
  --profile smoke \
  --output target/t0071-smoke.json && \
python3 tools/t0071-benchmark/validate.py target/t0071-smoke.json
```

Every worker count must produce byte-identical output. The smoke inputs are
deliberately small and are not performance evidence. Use the documented
`evidence` profile and pinned optional reference only for reproducible
measurement; see [Performance evidence](PERFORMANCE.md).

## Evidence boundary

Eight selected CSV cases and five JSON/codec/filter cases are compared with
pinned Embulk executables. Compressed results are compared after decoding;
compressed bitstream equality is not promised. Native worker and failure tests
do not establish Embulk scheduler, transaction or resume parity. See
[Compatibility](COMPATIBILITY.md) and [Current status](STATUS.md) for accepted
revisions and non-claims.
