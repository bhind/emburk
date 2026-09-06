# Experimental File-to-File transfer

`transfer-lines` is an experimental native text-record path, not Embulk's `run`
command. It does not load YAML or parse CSV/JSON.

```sh
cargo run -p emburk-cli -- transfer-lines input.txt output.txt
```

Input must be an existing regular UTF-8 file. Output must not exist. Paths with
spaces must be quoted. Each physical input line becomes a single Text-cell
record, passes through the core's synchronous owned-record handoff, and is
written with LF. CRLF becomes LF and an unterminated final line gains LF.
Blank lines remain records; an empty file creates an empty output.

Each physical record is limited to 1 MiB including its input terminator. This
bounds line-buffer growth, not total process memory. Processing is sequential.
There is no file-wide record queue, schema inference, transformation expression,
plugin loading, YAML configuration or Embulk compatibility claim.

An existing output is never overwritten. On Unix, new output is created with
mode 0600 (or stricter under umask). On non-Unix systems directory/OS ACLs
apply; no portable owner-only guarantee is made. After output creation, a read,
encoding, size, write or flush failure may leave a **partial output**. The
command reports failure; inspect the new file before removing it or choosing a
different output name. There is no automatic deletion, rollback, crash-durability,
atomic publication, transaction or resume guarantee. Input must not be modified
concurrently; hostile filesystem races are outside this experimental contract.

Success reports a record count and exits 0. Invalid command arguments exit 2;
transfer failures exit 1. The full File-to-File MVP roadmap gate remains open.
