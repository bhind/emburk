# ADR-0005: Traceable, License-Aware Reimplementation

- Status: Accepted
- Date: 2026-09-05

## Context

Maintainers may inspect Embulk source and third-party plugins. A formal clean-room claim would therefore be inaccurate, while untracked reuse would create copyright, notice, patent, and trademark risk.

## Decision

Use public behavior and published specifications as primary compatibility inputs. Embulk EEPs are preferred CC0 design references. Source inspection is allowed but recorded. Mechanical translation is prohibited by default; direct reuse requires an explicit derivative-material declaration and satisfaction of all applicable licenses and notices.

Every compatibility capability has a provenance record and independent review. Plugin artifacts are audited per version. Releases include relevant notices and an SBOM, with human review of shipped contents.

## Consequences

Compatibility work cannot be Verified without provenance evidence. Tests are independently authored by default. The project makes no blanket patent or trademark clearance claim and escalates novel or commercial uses for appropriate review.
