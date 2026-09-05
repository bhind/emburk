# ADR-0002: Explicit Compatibility Matrix

- Status: Accepted
- Date: 2026-09-05

## Context

The Embulk ecosystem includes independently versioned core releases and plugins. “All plugins” and “100% compatible” are not finite, testable claims.

## Decision

Compatibility is recorded per pinned core and plugin artifact. Hosted, Native, and Verified are independent status dimensions. Embulk 0.11.5 and SPI 0.11 are the initial core references, while each plugin version is admitted separately.

## Consequences

Migration claims remain narrow and reproducible. Compatibility work requires differential evidence and known deviations. Older lines can be added without silently changing the default contract.
