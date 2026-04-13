# Agent Methodology

## Default operating cycle

### 1. Plan

Use planning to produce a worklist with bounded steps.

Good steps are:

- dependency-aware
- reviewable
- small enough to validate clearly
- large enough to avoid needless fragmentation

### 2. Prepare

Before building, restate:

- the exact step being executed
- expected files or areas affected
- validation to run
- what would count as step completion

### 3. Build

Implement only the current bounded step.

Multi-file work is allowed when it belongs to the same step. Do not sprawl into adjacent work just because the agent can see it.

### 4. Validate

Run the strongest practical checks for the current stack and scope.

### 5. Review

Audit whether the step actually satisfied the plan. If not, name the gap precisely and either fix it or update the plan.

## Working with Cursor Plan mode

This framework is designed to fit Cursor's planning flow.

Use Plan mode for:

- discovery
- clarification
- outlining the implementation sequence
- revising or splitting steps
- deciding whether a step is build-ready

Use Build only after the current plan step is specific enough to execute.

## Definition of a good plan step

A good step answers:

- what is changing?
- why now?
- which files or components are likely involved?
- how will success be checked?
- what is intentionally out of scope for this step?

## Escalation rule

If the current step unexpectedly expands, do one of these:

- continue only if it is still one coherent bounded step
- otherwise stop, explain the expansion, and split or revise the plan

## Recovery rule

When validation fails, do not improvise blindly.

Instead:

1. identify the failing signal
2. identify the likely cause
3. inspect the smallest relevant surface area
4. propose the next bounded correction
5. validate again

## Reviewer mindset

Review is not a vibe check.

Review should compare:

- plan vs implementation
- expected behavior vs observed evidence
- local success vs system impact

The review output should be concrete enough to act on immediately.
