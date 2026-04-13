# Architecture Guidance

This file is intentionally lightweight and stack-agnostic.

## Prefer

- explicit boundaries between components
- dependency injection where it improves testability and substitution
- small public interfaces and clear contracts
- tests that reflect real behavior, not just internal mechanics
- changes that preserve readability for the next reviewer

## Avoid

- coupling unrelated work into one step
- hidden global side effects
- architecture rewrites disguised as feature work
- premature abstractions with no present payoff

## Principle

The framework governs **how the agent works** more than **which architecture style the repo must use**.

Project-specific architecture should come from the codebase itself, not be forced from this package.
