# AGENTS.md

## Boundaries

- This repository stores selectively applied dotfiles. `install.sh` is the workstation entry point and applies components from `components.tsv`. It expands every target inside `$HOME`, preserves unrelated shell content, and never overwrites a file that is not a documented managed target. The agent-stack apply script owns only its marked OpenCode block in `~/.bash_aliases`.
- Root `AGENTS.md` guides work in this repository. The public [`guisaliba/agents`](https://github.com/guisaliba/agents) repository owns the canonical OpenCode global instruction payload copied to `~/.config/opencode/AGENTS.md`.
- Keep managed repository sources distinct from materialized files under `$HOME`; do not edit or overwrite home-directory targets unless explicitly asked.

## Root Installer

- `install.sh` is the executable workstation installer. It is a Bash UI and orchestrator. It supports `--check`, `--components`, `--host`, `--yes`, `--vscode-extensions`, and `--help`. It rejects unknown options, duplicate scalar options, invalid hosts, unknown components, and unknown extension identifiers with status 2.
- `components.tsv` is the data manifest: `component<TAB>action<TAB>source<TAB>target<TAB>hosts<TAB>default<TAB>risk`. `install.sh` validates it strictly.
- `lib/dotfiles_installer.py` provides the safe file operations: manifest validation, absolute target expansion inside HOME, atomic copy with source mode, tree compare and managed-tree replacement, backup root and run-id creation, path mirroring, MANIFEST.tsv append, and exact managed-block replacement. It uses the standard library only and never runs external commands.
- `bash/aliases.bash` is the ordinary-dotfiles marked block merged into `~/.bash_aliases`. The OpenCode wrapper block is separate and owned by the agent stack.
- `vscode/extensions.tsv` is the source of truth for tracked VS Code extensions. `vscode/EXTENSIONS.md` is human documentation.
- `--check` performs no writes, clone, fetch, extension install, command, service, or sudo action. A component failure stops later components, and the final message lists completed and failed components.
- Backups use one UTC run id under `~/.local/state/dotfiles/backups/<id>/`, mirroring the absolute target path without the leading slash. There is no backup when the target is equal, and no run directory in `--check`.
- Risk gates: the agents component is a network and service action and shows a separate confirmation before running. The omarchy-power component shows a separate root-power confirmation and runs only on Omarchy. `--yes` never bypasses these separate confirmations. Omarchy-power never runs `mx-mini-recover.sh`.

## Agent Stack

- Read the public [`guisaliba/agents`](https://github.com/guisaliba/agents) repository for the detailed agent setup, runtime wiring, and integration commands.
- The managed checkout at `~/.local/share/dotfiles/agents/apply.sh` is the executable source of truth for OpenCode setup. It requires Bash, Bun, `curl`, `git`, `npm`, `npx`, Python 3.11 or newer, and a systemd user manager. It uses `yay` when the native `ai-memory` command is absent. It reports whether the optional `ai-jail` command is available but does not install or configure it. It performs network installs and changes files under `~/.config/opencode`, `~/.config/ai-memory`, `~/.local/share/ai-memory`, `~/.local/share/opencode/learn`, `~/.agents/skills`, the marked block in `~/.bash_aliases`, and other integration directories. Do not run it as a read-only verification step.
- The apply script converges the global primary model, explicit Plan model, default agent, available built-in subagent model routing, Plannotator plugin, ai-memory instruction reference, and managed MCP servers in the existing `~/.config/opencode/opencode.json`. It also converges the default `lucent-orng` theme and the Learn TUI plugin in `~/.config/opencode/tui.json`, and copies the tracked themes from `~/.local/share/dotfiles/agents/opencode/themes/` to `~/.config/opencode/themes/`. It preserves unrelated valid runtime fields and copies, rather than symlinks, `~/.local/share/dotfiles/agents/AGENTS.md`.
- The apply script fetches the latest `main` commit of `github.com/guisaliba/learn` into the separate managed checkout at `~/.local/share/opencode/learn`, installs its Bun dependencies, and configures that absolute path as both the server and TUI plugin. It does not modify the development checkout at `~/projects/active/self/learn`. Both entries are required. The managed checkout must be clean and must use the expected remote before apply fast-forwards it.
- Scout routing is applied only when the installed OpenCode exposes native `scout (subagent)`. The apply script does not create a custom Scout fallback.
- `~/.local/share/dotfiles/agents/AGENTS.md` contains the canonical global policy that requires the primary agent to review and verify delegated implementation before final acceptance.
- ai-memory runs as the native per-user service. Dotfiles writes `~/.config/systemd/user/ai-memory.service` for the resolved native binary and owns the OpenCode MCP entry and instruction reference. Apply rejects the upstream Docker wrapper because its container data and service lifecycle are a separate deployment model. The installed ai-memory binary owns the generated `~/.config/opencode/plugins/ai-memory.ts`, `~/.config/opencode/ai-memory.md`, and five `~/.agents/skills/ai-memory-*` skill directories.
- Dotfiles owns the ai-memory LLM profile, provider, model, approval, and scheduler assignments in `~/.config/ai-memory/env`. The default profile uses DeepSeek V4 Flash through the OpenCode Go API. Apply keeps zero-LLM mode until `OPENCODE_API_KEY` is present in that environment file.
- Keep `~/.config/ai-memory/config.toml`, `~/.config/ai-memory/env`, ai-memory data, OpenCode credentials, and native sessions out of Git. The config contains a generated token pepper. The environment file can contain provider keys.
- Normal interactive Bash `opencode` commands are an unexported function that runs `ai-memory run opencode`. This keeps every normal interactive session in a managed workstream without causing child-process recursion. `opencode-raw` is the explicit diagnostic and recovery bypass; it must not become the routine path.
- The Bash function rejects `opencode --yolo` and native `opencode --auto` because dangerous mode alone is not a sandbox. Use the documented explicit outer `ai-jail ai-memory ... run opencode --yolo` form.
- ai-jail is an optional, separately installed tool for contained dangerous-mode launches. This repository does not own `~/.ai-jail`. Keep capability choices explicit or add them to the trusted global file after review.
- Most skills are fetched live on every apply. Only local tracked skills belong under `~/.local/share/dotfiles/agents/skills/`: `find-skills` and `auto-pr-review` are copied by the managed `apply.sh`. ai-memory skills are also generated live and must not be vendored.
- Matt Pocock's `teach` is the tracked teaching skill. OpenCode Learn owns `/learn`; the retired Alvar helper skill directories are removed during apply.
- Do not vendor upstream plugin or skill payloads. Update their source/version declarations in the public `guisaliba/agents/apply.sh` instead.

## Verification

- After agent-stack changes, run `~/.local/share/dotfiles/agents/test.sh`.
- The managed `test.sh` is not a hermetic unit test: it checks repository files and the current machine's installed commands, OpenCode config, and global skills. Run the managed `apply.sh` first only when setup/update side effects were requested.
- Use `~/.local/share/dotfiles/agents/test.sh --repo-only` for deterministic merge, idempotence, safe-failure, and private-file fixtures without current-machine assertions.
- `./test.sh --repo-only` is the deterministic root-installer fixture suite. It uses temporary HOME and repository fixtures only, never modifies a real home directory, and never contacts GitHub.
- The agent apply is a network and service action. Do not run it as a read-only verification step. Run the managed `~/.local/share/dotfiles/agents/test.sh --repo-only` and `./test.sh --repo-only` instead.
- For syntax-only checks that avoid machine-state assertions, use `bash -n install.sh test.sh omarchy/apply-power-management.sh omarchy/mx-mini-recover.sh` and `python3 -m py_compile lib/dotfiles_installer.py`.
