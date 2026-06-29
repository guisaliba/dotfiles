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
- `agents/`: OpenCode agent setup and runtime wiring.

## Agent Stack

The agent stack lives under `agents/`.

- `agents/AGENTS.md` is the canonical global instruction file for OpenCode.
- `agents/apply.sh` installs and configures OpenCode, RTK, Plannotator, and required skills.
- `agents/test.sh` verifies deterministic harness wiring.
- `agents/opencode/README.md` documents OpenCode targets and integrations.
- `agents/skills/README.md` documents skill layout and managed skill payloads.

Root `AGENTS.md` is repo-local contributor guidance for coding agents working inside this dotfiles repo. It is not the runtime instruction payload for harnesses. The runtime payload is `agents/AGENTS.md`.

## Setup

From the repo root:

```sh
./agents/apply.sh
./agents/test.sh
```

Skills are installed live from upstream sources. No skill payloads are vendored in this repo except `auto-pr-review`, which is a local-only manual skill.

## Working Rules

- Prefer small, explicit configuration over opaque installers.
- Keep scripts idempotent, inspectable, and safe to rerun.
- Do not broadly refactor dotfiles layout unless asked.
- Do not change unrelated user configuration.
- Preserve the distinction between repo documentation, managed source files, and materialized home-directory targets.
- After agent-stack changes, run `./agents/test.sh` when practical.