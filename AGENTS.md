# AGENTS.md

## Boundaries

- This repository stores selectively applied dotfiles; there is no repository-wide installer for shell, editor, terminal, or prompt configuration.
- Root `AGENTS.md` guides work in this repository. `agents/AGENTS.md` is the canonical OpenCode global instruction payload copied to `~/.config/opencode/AGENTS.md`.
- Keep managed repository sources distinct from materialized files under `$HOME`; do not edit or overwrite home-directory targets unless explicitly asked.

## Agent Stack

- Read `agents/README.md` for the detailed agent setup, runtime wiring, and integration commands.
- `agents/apply.sh` is the executable source of truth for OpenCode setup. It requires `curl`, `git`, `npm`, `npx`, and `python3` and performs network installs plus mutations under `~/.config/opencode`, `~/.agents/skills`, and other harness config directories. Do not run it as a read-only verification step.
- The apply script converges the global primary model, explicit Plan model, default agent, available built-in subagent model routing, Plannotator plugin, and managed MCP servers in the existing `~/.config/opencode/opencode.json`. It preserves unrelated valid runtime fields and copies, rather than symlinks, `agents/AGENTS.md`.
- Scout routing is applied only when the installed OpenCode exposes native `scout (subagent)`. The apply script does not create a custom Scout fallback.
- `agents/AGENTS.md` contains the canonical global policy that requires the primary agent to review and verify delegated implementation before final acceptance.
- Most skills are fetched live on every apply. Only local tracked skills belong under `agents/skills/`: `find-skills` and `auto-pr-review` are copied by `apply.sh`.
- Do not vendor upstream plugin or skill payloads. Update their source/version declarations in `agents/apply.sh` instead.

## Verification

- After agent-stack changes, run `./agents/test.sh` from the repository root.
- `agents/test.sh` is not a hermetic unit test: it checks repository files and the current machine's installed commands, OpenCode config, and global skills. Run `./agents/apply.sh` first only when setup/update side effects were requested.
- For syntax-only checks that avoid machine-state assertions, use `bash -n agents/apply.sh agents/test.sh`.
