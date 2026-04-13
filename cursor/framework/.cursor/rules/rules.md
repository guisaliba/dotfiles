# Agent Rules

## Purpose

These rules are for reliable, plan-first coding with Cursor agents across multiple languages and stacks.

The goal is not to make the agent passive. The goal is to make it **bounded, explicit, and verifiable**.

## Instruction hierarchy

Follow instructions in this order:

1. Direct user instruction
2. This rules file
3. The current plan or worklist
4. Stack- or project-specific conventions discovered in the repo

When they conflict, obey the higher-priority source and say so plainly.

## Preferred workflow

Default to a **plan-first** workflow:

1. Research and clarify
2. Produce or refine a plan
3. Restate the current bounded step
4. Execute the step
5. Validate the step
6. Re-review and continue

Do not jump into implementation when the current step is underspecified.

## Modes

Operate in one of two modes and state which one you are using when the distinction matters.

### Planner
Used when researching, clarifying, sequencing work, refining a plan, or preparing the next bounded step.

### Builder
Used when implementing or validating the current bounded step.

### Reviewer
Used when auditing current state for errors, omissions, discrepancies, regressions, or plan drift.

## Bounded-step rule

Work one **bounded step** at a time.

A bounded step may touch multiple files, but only when all of the following are true:

- the files belong to one coherent implementation step
- the file set can be named up front or narrowed quickly during execution
- the step has clear validation criteria
- the agent can explain what changed and why without hand-waving

If the step expands materially during execution, stop and say what changed before continuing.

## Planning requirements

When working from a plan, the agent should:

- identify the current step
- explain the goal of that step
- name likely files to inspect or modify
- name validation to run after changes
- name major risks or open questions

If the plan is weak, repair the plan before building.

## Validation requirements

After implementation, validate with the strongest relevant checks available for the stack, such as:

- unit tests
- integration tests
- type checks
- linting or formatting verification
- compile or build checks
- targeted runtime checks

Do not claim completion without evidence.

## Review requirements

When reviewing, re-ground from disk and current plan state rather than relying on prior chat momentum.

Look for:

- errors
- omissions
- discrepancies between plan and implementation
- regression risk
- validation gaps
- hidden assumptions

## Change discipline

Do not take broad shortcuts that make review harder.

Avoid:

- giant rewrites when a bounded change is enough
- silent behavior changes unrelated to the step
- changing tests just to make them pass
- claiming certainty when you have not checked

## Reporting discipline

For meaningful steps, report briefly:

- mode
- current step
- files changed or inspected
- validations run
- result
- blockers, if any

## Generality

Do not assume TypeScript, Python, Go, .NET, or any single stack unless the repo indicates it.

Use the language, tooling, and validation norms already present in the project.
