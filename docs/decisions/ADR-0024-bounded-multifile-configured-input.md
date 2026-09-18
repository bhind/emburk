# ADR-0024: Bounded multi-file configured input

Status: Accepted through PR #142

## Context

ADR-0017 admits one bounded configured File/CSV input. T-0014/S03 subsequently
observed three selected Embulk 0.11.5 `path_prefix` cases: lexical per-file
outputs, independent header removal, and exclusion of an empty matching
directory. The native runtime needs a deliberately smaller production boundary
that can be verified without claiming general File input compatibility.

## Decision

Ordinary configured `run` may select zero, one, or two metadata-regular prefix
matches. It sorts host filename encoded bytes, opens accepted inputs once, and
retains those descriptors. Inputs map in order to fixed `000` and `001` output
indices. Each input uses the existing bounded parser, formatter, and no-clobber
publication path; successful record counts are added with checked arithmetic.

Selection, the two-input cap, report/input descriptor comparison, calculation
of every final target, existing-node rejection, and canonical report/output
alias rejection all complete before the first output is opened. Processing and
publication then remain sequential. A later failure or cancellation can retain
an already published prefix; there is no cross-output transaction or rollback.

Stateful `run --state` and `resume` remain single-input-only. They require
exactly one opened, descriptor-validated input before state access or output
preflight. This decision supersedes ADR-0017's single-match rule only for
ordinary `run`.

## Consequences

The slice can reproduce the three admitted observations while keeping task
count and output naming bounded. It explicitly does not admit general globbing,
recursive discovery, non-ASCII ordering compatibility, arbitrary task counts,
inter-file parallelism, hostile concurrent namespace replacement, multi-input
resume, or Embulk transaction parity.
