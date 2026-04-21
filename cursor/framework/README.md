# Cursor Agent Framework

A general-purpose `.cursor` package for plan-first, bounded-step agentic coding across any stack.

## What this package assumes

- You prefer to plan before implementation.
- You use Cursor's Plan Mode to research and draft a reviewable plan.
- Once the plan is good enough, you use Cursor's Build action to execute the current plan state.
- You want the agent to work in bounded, reviewable steps, not giant uncontrolled bursts.

## Included files

- `.cursor/rules/rules.md` - main operating rules
- `.cursor/rules/agent-methodology.md` - planning and execution method
- `.cursor/rules/architecture-guidance.md` - optional architecture guidance
- `.cursor/commands/plan.md` - align the agent to a planning pass
- `.cursor/commands/start.md` - inspect current plan state and prepare the next bounded build step
- `.cursor/commands/review.md` - reviewer-mode audit for errors, omissions, and discrepancies
- `.cursor/commands/unit.md` - create or refine unit tests for the current step
- `.cursor/commands/implement.md` - implement the current bounded step
- `.cursor/commands/integrate.md` - run an integration pass for the current step
- `.cursor/commands/failure.md` - diagnose and recover from failed tests/builds

## Common workflow

1. Start in Plan Mode.
2. Ask the agent to research the codebase and produce a plan with bounded steps.
3. Refine the plan until the current step is crisp enough to execute.
4. Use `/start` to restate the current step, likely files, validations, and risks.
5. Press Build to execute the step.
6. Use `/review` after meaningful progress or when you suspect drift.
7. Use `/failure` whenever implementation diverges or validation fails.

## When to use each command

- `/plan` - use when you want the framework to reshape or tighten a plan, especially after drift or after a large spec dump.
- `/start` - use before Build to anchor the current bounded step.
- `/review` - use after implementation or when you suspect omissions/discrepancies.
- `/unit` - use when the current step should start with or be clarified by unit-level tests.
- `/implement` - use when the step is already clear and you want to push implementation directly without re-running a broader planning pass.
- `/integrate` - use after a bounded step lands and you want a focused integration/validation pass across adjacent modules or behaviors.
- `/failure` - use when tests, builds, or the current step break and you need root-cause analysis plus the smallest safe recovery.

## Core stance

- Plan first.
- Build from the plan.
- Keep each turn bounded.
- Permit multi-file edits when they belong to one coherent step.
- Re-ground from files and plan state often.
- Verify with tests, type checks, linters, or equivalent stack-specific validation.