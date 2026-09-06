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

T-0025/S02 implements the following explicit commands; final acceptance is
pending. Start with a state-directory path that does not exist:

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

## Evidence boundary

Eight selected CSV cases and five JSON/codec/filter cases are compared with
pinned Embulk executables. Compressed results are compared after decoding;
compressed bitstream equality is not promised. Native worker and failure tests
do not establish Embulk scheduler, transaction or resume parity. See
[Compatibility](COMPATIBILITY.md) and [Current status](STATUS.md) for accepted
revisions and non-claims.
