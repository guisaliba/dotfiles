# Cursor Agent Framework

A general-purpose `.cursor` package for plan-first, bounded-step agentic coding across any stack.

## What this package assumes

- You prefer to **plan before implementation**.
- You use Cursor's **Plan mode** to research and draft a reviewable plan.
- Once the plan is good enough, you use Cursor's **Build** action to execute the current plan state.
- You want the agent to work in **bounded, reviewable steps**, not giant uncontrolled bursts.

## Included files

- `.cursor/rules/rules.md` — main operating rules
- `.cursor/rules/agent-methodology.md` — planning and execution method
- `.cursor/rules/architecture-guidance.md` — optional architecture guidance
- `.cursor/commands/plan.md` — align the agent to a planning pass
- `.cursor/commands/start.md` — inspect current plan state and prepare next bounded build step
- `.cursor/commands/review.md` — reviewer-mode audit for errors, omissions, and discrepancies
- `.cursor/commands/unit.md` — create or refine unit tests for the current step
- `.cursor/commands/implement.md` — implement the current bounded step
- `.cursor/commands/integrate.md` — integration pass for the current step
- `.cursor/commands/failure.md` — diagnose and recover from failed tests/builds

## Recommended usage in Cursor

1. Start in **Plan mode**.
2. Ask the agent to research the codebase and produce a plan with bounded steps.
3. Edit the plan until the current step is crisp enough to execute.
4. Use `/start` to make the agent restate the current step, affected files, validations, and risks.
5. Press **Build** to execute the step.
6. Use `/review` after meaningful progress or when you suspect drift.
7. Use `/failure` whenever the implementation diverges or validation fails.

## Core stance

- Plan first.
- Build from the plan.
- Keep each turn bounded.
- Permit multi-file edits when they belong to one coherent step.
- Re-ground from files and plan state often.
- Verify with tests, type checks, linters, or equivalent stack-specific validation.
