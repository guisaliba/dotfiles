# Claude.md

## Context

Always cache these instructions after reading them for the first time.

## Environment

- Timezone: UTC-3
- Primary OS: Arch Linux, WSL2 Ubuntu

## Python

Use `uv` for everything: `uv run`, `uv pip`, `uv venv`. If not installed, install it first.

## Node

Always use `bun` instead of `npm` unless the project already uses `npm` or another package manager. Stick to the project's choice if that's the case; otherwise, use `bun`. Install it first.

## Principles

### Style

No emojis. No em dashes - use hyphens or colons instead.

### Epistemology

Assumptions are the enemy. Never guess numerical values - benchmark instead of estimating. When uncertain, measure. Say "this needs to be measured" rather than inventing statistics.

### Scaling

Validate at small scale before scaling up. Run a sub-minute version first to verify the full pipeline works. When scaling, only the scale parameter should change.

### Interaction

Clarify unclear requests, then proceed autonomously. Only ask for help when scripts timeout (>2min), sudo is needed, or genuine blockers arise.

### Ground Truth Clarification

For non-trivial tasks, reach ground truth understanding before coding. Simple tasks execute immediately. Complex tasks (refactors, new features, ambiguous requirements) require clarification first: research codebase, ask targeted questions, confirm understanding, persist the plan, then execute autonomously.

### Spec-Driven Development

When starting a new project, after compaction, or when SPEC.md is missing/stale and substantial work is requested: the user can invoke `/spec` to start an interview. The spec persists across compactions and prevents context loss. Update SPEC.md as the project evolves. If stuck or losing track of goals, re-read SPEC.md or suggest the user run `/spec` again.

### First Principles Reimplementation

Building from scratch can beat adapting legacy code when implementations are in wrong languages, carry historical baggage, or need architectural rewrites. Understand domain at spec level, choose optimal stack, implement incrementally with human verification.

### Constraint Persistence

When user defines constraints ("never X", "always Y", "from now on"), immediately persist to project's local CLAUDE.md. Acknowledge, write, confirm.

## Search

Searching is your strongest tool. Rules:

- Use ripgrep (`rg`) as preferred search tool
- Fast recursive search (respects .gitignore)
- Count matches: `rg -c "pattern"`
- Search Markdown docs: `rg -t md "schema" --files`
- Find function calls: `rg "processPayment\s*\(|->processPayment"`
- Case-insensitive: `rg -i "api_key"`
- Multiple patterns: `rg -l 'pattern2' $(rg -l 'pattern1')`
- Exclude paths such as: `rg pattern --glob '!node_modules/**'`

Use `rg` for:
- Codebase searches
- Pattern finding (99% of cases)

Use `grep` for:
- Only for piped input or specific binary file handling

Never: Pipe rg output through grep - rg is faster standalone

Common search patterns:
- `rg "axios|fetch|https?://" -l` for API integration points
- `rg "SELECT|INSERT|UPDATE|DELETE" -A 2 -B 2` for database queries
- `rg "catch|throw|Error" | head -20` for error handling

## Documentations

Documentations are crucial for understanding the codebase and providing context for future developers. When assigned to tasks that would change the codebase significantly, make sure to update relevant documentation files accordingly. This includes updating README files, adding new docs or modifying existing one. Place these in the project's documentation dir. (if none, create one named "docs" by default on the project's root).

## Memory

Memory is essential for maintaining context and ensuring consistency across interactions. Use memory to store important information such as user preferences, project details, and task progress. Memory can be used to store intermediate results of computations or data that is frequently accessed but not critical to the overall state of the system.

## Subagents

Use subagents to offload specific work without polluting the main conversation context.

### Available Subagents

Located in `~/.claude/agents/`:

- **log-analyzer**: Specialized log analysis for parsing errors, warnings, and stack traces. Returns structured JSON with root causes and recommendations.
- **docker-debugger**: Docker container debugging specialist. Analyzes container state, logs, and resource usage. Returns diagnostic JSON.
- **codebase-explorer**: Codebase search and analysis. Finds patterns, traces data flows, returns structured findings with file paths and line numbers.

### When to Use Subagents

Delegate to subagents when:
- The task requires deep exploration that would bloat main context
- You need specialized analysis (logs, containers, codebase search)
- The work is read-only research that can be summarized

### Subagent Guidelines

1. Each subagent gets ONE focused task
2. No inter-agent communication (main agent coordinates)
3. Subagents return only JSON or structured markdown
4. Main agent reads output, continues work
5. Subagents cannot modify code (read-only research only)

### Invocation

You automatically delegate to appropriate subagents, or the user can request explicitly:
- "Use the log-analyzer agent to check these error logs"
- "Have the docker-debugger agent inspect the failing container"
- "Ask the codebase-explorer to find all payment processing code"

## Issues

Before starting work always look in project's ".claude" directory for an "issues" directory. It  contains files named "xyz.md" where "xyz" is the issue's identifier. These files have detailed descriptions of the issue being addressed, including user's requirements, expected behavior, etc.

## Git

When working on user's requests that demands code changes, always create a new branch from the current checked out branch. Adhere to Conventional Branches standards and use the issue's ID e.g. "feature/xyz-123" to name them. Gradually commit your changes on the created branch, adhering to Conventional Commits standards. If the user strictly instructs you to do otherwise, obey their instructions as required.

## Machines

Check the current OS before starting work. If you are on Arch, use `pwd` to check the cwd. If under "/guidance/oficina/" search recursively from it for "credentials" and "connections" text files. These are essential for daily basis tasks like remotely accessing servers or databases.
