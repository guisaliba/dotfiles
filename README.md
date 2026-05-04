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

The bootstrap writes or manages:

- `~/.codex/AGENTS.md`
- `~/.config/opencode/AGENTS.md`
- `~/.opencode/AGENTS.md`
- `~/.pi/agent/AGENTS.md`
- `~/.agents/skills/`
- `~/.pi/agent/extensions/rtk/`
- `~/.pi/agent/extensions/cavemem-bridge/`

## Bootstrap

Run:

```sh
./bootstrap-agent-stack.sh
```

Optional:

```sh
RUN_AGENT_DOCS=0 ./bootstrap-agent-stack.sh
PUSH=1 ./bootstrap-agent-stack.sh
DOTFILES_DIR="$HOME/dotfiles" ./bootstrap-agent-stack.sh
```

## Design

The repo avoids custom Markdown merge scripts. The old base-plus-overlay model was replaced with one canonical instruction file and harness-specific placement.

Chezmoi is used as the durable multi-machine materialization layer. Scripts are limited to installing external tools and creating bridge files that cannot be represented as static config alone.

## Memory

Cavemem is installed natively where supported. Pi uses a local extension bridge that exposes Pi custom tools backed by `cavemem mcp`.

The bridge keeps cavemem as the source of truth. It does not reimplement memory storage.
