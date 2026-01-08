---
allowed-tools: AskUserQuestion, Read, Glob, Grep, Write, Edit
argument-hint: [plan-file]
description: Interview to flesh out a plan/spec
---

Here's the current plan:

@$ARGUMENTS

Interview me in detail using the AskUserQuestion tool about literally anything: technical implementation, UI & UX, concerns, tradeoffs, etc. but make sure the questions are not obvious.


Gather core information through questions:
  - What is this project? (one sentence)
  - What problem does it solve?
  - Who is the target user?
  - What are the key features/capabilities?
  - What are explicit non-goals (things this will NOT do)?
  - What technologies/stack are you using or prefer?
  - Are there constraints (performance, compatibility, licensing)?

Be very in-depth and continue interviewing me continually until it's complete, then write the spec back to `$ARGUMENTS`
