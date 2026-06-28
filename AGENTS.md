# AGENTS.md

## Repository Context

This repository is a personal dotfiles workspace for a portable Linux development environment.

It manages shell, editor, terminal, prompt, agent harness, and supporting development configuration across machines.

## Project Map

- `README.md`: root overview and setup philosophy.
- `bash/`: Bash configuration.
- `ghostty/`: Ghostty terminal configuration.
- `git/`: Git configuration.
- `starship/`: Starship prompt configuration.
- `vscode/`: VSCode configuration and extension notes.
- `zed/`: Zed editor configuration.
- `wallpapers/`: wallpaper assets.
- `agents/`: shared coding-agent configuration and runtime wiring.
- `chezmoi/`: chezmoi source tree used to materialize managed home-directory config.

## Agent Stack

The managed agent stack lives under `agents/`.

- `agents/AGENTS.md` is the canonical global instruction file shared by OpenCode and Pi.
- `agents/apply-agent-stack.sh` applies the managed agent stack to the current machine.
- `agents/test-agent-stack.sh` verifies deterministic harness wiring.
- `agents/opencode/README.md` documents OpenCode targets and integrations.
- `agents/pi/README.md` documents Pi targets and integrations.
- `agents/skills/README.md` documents shared skill layout and managed skill payloads.

Root `AGENTS.md` is repo-local contributor guidance for coding agents working inside this dotfiles repo. It is not the runtime instruction payload for harnesses. The runtime payload is `agents/AGENTS.md`.

## Chezmoi

The chezmoi source tree is `chezmoi/`, not the repository root.

Managed agent files are materialized through:

- `chezmoi/.chezmoitemplates/agents/AGENTS.md`
- `chezmoi/dot_config/opencode/AGENTS.md.tmpl`
- `chezmoi/dot_pi/agent/AGENTS.md.tmpl`

Follow the repo policy: one source of truth, multiple placements.

## Working Rules

- Prefer small, explicit configuration over opaque installers.
- Keep scripts idempotent, inspectable, and safe to rerun.
- Do not broadly refactor dotfiles layout unless asked.
- Do not change unrelated user configuration.
- Preserve the distinction between repo documentation, managed source files, and materialized home-directory targets.
- After agent-stack changes, run `./agents/test-agent-stack.sh` when practical.