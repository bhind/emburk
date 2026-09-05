# Provenance Index

This directory contains one reviewed provenance record per compatibility capability or plugin artifact.

Use the schema and rules in [Traceable, License-Aware Reimplementation](../PROVENANCE.md).

| Record | Status |
| --- | --- |
| [T-0011 Embulk reference inventory](T-0011-embulk-reference-inventory.md) | Done (Planning evidence) |
| [T-0012/S01 configuration-presence reference probe](T-0012-config-presence-probe.md) | Done (Reference Observation / Integration) |
| [T-0012/S02 configuration-conversion reference probe](T-0012-config-conversion-probe.md) | Done (Reference Observation / Integration) |
| [T-0012/S03 internal scalar resolution](T-0012-scalar-resolution.md) | Done (Unit/Contract; PR #66) |
| [T-0012/S04 live scalar differential](T-0012-live-scalar-differential.md) | Done (selected typed Differential; PR #67) |
| [T-0012/S05 schema-boundary observation](T-0012-schema-boundary-probe.md) | Done (Reference Observation / Integration; PR #68) |
| [T-0012/S06 ordered schema differential](T-0012-ordered-schema-differential.md) | Done (selected schema Differential; PR #69) |
| [T-0013/S01 input lifecycle observation](T-0013-input-lifecycle-probe.md) | Done (Reference Observation / Integration; PR #70) |
| [T-0013/S02 output lifecycle observation](T-0013-output-lifecycle-probe.md) | Done (Reference Observation / Integration; PR #71) |
| [T-0013/S03 input-run failure observation](T-0013-input-failure-probe.md) | Done (Reference Observation / Integration; PR #72) |
| [T-0021/S03 private empty-task coordinator](T-0021-empty-task-coordinator.md) | Done (Unit/Contract; PR #73) |
| [T-0013/S04 selected empty-lifecycle differential](T-0013-empty-lifecycle-differential.md) | Done (two selected Differential projections; PR #74) |
| [T-0013/S05 output commit failure observation](T-0013-output-commit-failure-probe.md) | Done (Reference Observation / Integration; PR #75) |
| [T-0021/S04 private last-commit failure](T-0021-last-commit-failure.md) | Done (Unit/Contract plus existing regression; PR #76) |
| [T-0013/S06 selected output-commit differential](T-0013-output-commit-differential.md) | Done (two selected Differential projections; PR #77) |
| [T-0013/S07 output commit position observation](T-0013-output-commit-position-probe.md) | Done (bounded reference slice; PR #78, `14cc2a6`) |
| [T-0021/S05 private commit abort suffix](T-0021-commit-abort-suffix.md) | Done (bounded slice; PR #79, `d36cf28`) |
| [T-0013/S08 selected commit-position differential](T-0013-commit-position-differential.md) | In Progress; independent packet readiness passed |
