# dotfiles

Personal dotfiles and agent harness configuration.

## Agent stack

This repository manages a shared coding-agent setup for:

- Codex
- OpenCode
- Pi

The current architecture uses:

- one canonical global instruction file: `agents/AGENTS.md`
- one shared global skills directory: `~/.agents/skills`
- a chezmoi source tree under `chezmoi/`
- harness-specific target files generated from the same canonical instructions
- external integrations for caveman, cavemem, and rtk

## Managed global targets

The agent stack applier writes or manages:

- `~/.codex/AGENTS.md`
- `~/.codex/config.toml`
- `~/.config/opencode/AGENTS.md`
- `~/.pi/agent/AGENTS.md`
- `~/.agents/skills/`
- `~/.pi/agent/extensions/rtk/`
- `~/.pi/agent/extensions/cavemem-bridge/`

It also backs up and removes known deprecated agent targets, including stale `~/.opencode/AGENTS.md` and symlinks from the removed root `opencode/` workflow.

## Apply agent stack

Run from the repo root:

```sh
./agents/apply-agent-stack.sh
```

The script can also be run directly from `agents/`:

```sh
cd agents
./apply-agent-stack.sh
```

Useful options:

```sh
RUN_AGENT_DOCS=1 ./agents/apply-agent-stack.sh
COMMIT=1 ./agents/apply-agent-stack.sh
COMMIT=1 PUSH=1 ./agents/apply-agent-stack.sh
DOTFILES_DIR="$HOME/dotfiles" ./agents/apply-agent-stack.sh
```

Defaults are safe for another machine: no nested Pi review, no commit, no push, no branch creation.

## Design

The repo avoids custom Markdown merge scripts. The old base-plus-overlay model was replaced with one canonical instruction file and harness-specific placement.

Chezmoi is used as the durable multi-machine materialization layer. Scripts are limited to installing external tools and creating bridge files that cannot be represented as static config alone.

Edit `agents/AGENTS.md` for global instruction changes. The applier copies it into `chezmoi/.chezmoitemplates/agents/AGENTS.md` and materializes the target files.

## Memory

Cavemem is installed natively where supported. Pi uses a local extension bridge that exposes Pi custom tools backed by `cavemem mcp`.

The bridge keeps cavemem as the source of truth. It does not reimplement memory storage.
