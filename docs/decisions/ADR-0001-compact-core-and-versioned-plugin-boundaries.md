# ADR-0001: Compact Core and Versioned Plugin Boundaries

- Status: Accepted
- Date: 2026-09-05

## Context

A plugin ecosystem becomes difficult to evolve when plugins depend on core implementation details or share uncontrolled dependency graphs.

## Decision

The Rust core owns orchestration and stable contracts only. Provider behavior and utilities belong to plugins or separate libraries. Built-ins are statically linked; third-party plugins use a separately versioned process protocol rather than Rust's unstable dynamic ABI. Dependency resolution happens before execution.

## Consequences

The core stays reviewable and native built-ins stay efficient. External plugins pay a process-boundary cost but gain dependency and crash isolation. Protocol compatibility becomes a maintained public contract.
