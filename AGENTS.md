# AGENTS.md

## Boundaries

- This repository stores selectively applied dotfiles; there is no repository-wide installer for shell, editor, terminal, or prompt configuration.
- Root `AGENTS.md` guides work in this repository. `agents/AGENTS.md` is the canonical OpenCode global instruction payload copied to `~/.config/opencode/AGENTS.md`.
- Keep managed repository sources distinct from materialized files under `$HOME`; do not edit or overwrite home-directory targets unless explicitly asked.

## Agent Stack

- Read `agents/README.md` for the detailed agent setup, runtime wiring, and integration commands.
- `agents/apply.sh` is the executable source of truth for OpenCode setup. It requires `curl`, `git`, `npm`, `npx`, Python 3.11 or newer, and a systemd user manager. It uses `yay` when the native `ai-memory` or `ai-jail` command is absent. It performs network installs and changes files under `~/.config/opencode`, `~/.config/ai-memory`, `~/.local/share/ai-memory`, `~/.agents/skills`, and other integration directories. Do not run it as a read-only verification step.
- The apply script converges the global primary model, explicit Plan model, default agent, available built-in subagent model routing, Plannotator plugin, ai-memory instruction reference, and managed MCP servers in the existing `~/.config/opencode/opencode.json`. It preserves unrelated valid runtime fields and copies, rather than symlinks, `agents/AGENTS.md`.
- Scout routing is applied only when the installed OpenCode exposes native `scout (subagent)`. The apply script does not create a custom Scout fallback.
- `agents/AGENTS.md` contains the canonical global policy that requires the primary agent to review and verify delegated implementation before final acceptance.
- ai-memory runs as the native per-user service. Dotfiles owns its service setup, the OpenCode MCP entry, and the OpenCode instruction reference. The installed ai-memory binary owns the generated `~/.config/opencode/plugins/ai-memory.ts`, `~/.config/opencode/ai-memory.md`, and five `~/.agents/skills/ai-memory-*` skill directories.
- Dotfiles owns the ai-memory LLM profile, provider, model, approval, and scheduler assignments in `~/.config/ai-memory/env`. The default profile uses DeepSeek V4 Flash through the OpenCode Go API. Apply keeps zero-LLM mode until `OPENCODE_API_KEY` is present in that environment file.
- Keep `~/.config/ai-memory/config.toml`, `~/.config/ai-memory/env`, ai-memory data, OpenCode credentials, and native sessions out of Git. The config contains a generated token pepper. The environment file can contain provider keys.
- `ai-memory run opencode` is an opt-in managed-workstream launch. Plain `opencode` stays valid and must not be shadowed by a repository wrapper or alias.
- ai-jail is installed for contained dangerous-mode launches, but this repository does not own `~/.ai-jail`. Keep capability choices explicit or add them to the trusted global file after review.
- Most skills are fetched live on every apply. Only local tracked skills belong under `agents/skills/`: `find-skills` and `auto-pr-review` are copied by `apply.sh`. ai-memory skills are also generated live and must not be vendored.
- Do not vendor upstream plugin or skill payloads. Update their source/version declarations in `agents/apply.sh` instead.

## Verification

- After agent-stack changes, run `./agents/test.sh` from the repository root.
- `agents/test.sh` is not a hermetic unit test: it checks repository files and the current machine's installed commands, OpenCode config, and global skills. Run `./agents/apply.sh` first only when setup/update side effects were requested.
- Use `./agents/test.sh --repo-only` for deterministic merge, idempotence, safe-failure, and private-file fixtures without current-machine assertions.
- For syntax-only checks that avoid machine-state assertions, use `bash -n agents/apply.sh agents/test.sh`.
