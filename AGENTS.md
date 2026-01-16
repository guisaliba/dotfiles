# Agent Guidelines for Dotfiles Repository

This repository contains personal dotfiles and configuration files. Read this before making changes.

## Repository Structure

```
dotfiles/
├── arch/          # Arch Linux + i3 window manager configs
├── bash/          # Bash configuration (.bashrc, .bash_aliases, .dircolors)
├── claude/        # Claude Code configuration (CLAUDE.md, plugins, hooks, agents, skills)
├── docs/          # Documentation and notes
├── fish/          # Fish shell configuration
├── git/           # Git configuration (.gitconfig)
├── opencode/      # OpenCode configuration (package.json, scripts)
├── ssh/           # SSH configuration
├── starship/      # Starship prompt configuration
├── vscode/        # VS Code settings and extensions list
├── wallpapers/    # Desktop wallpapers
└── zed/           # Zed editor configuration
```

## Build/Test/Lint Commands

This is a configuration repository with no traditional build process.

### Setup and Installation

```bash
# Claude config setup (symlinks dotfiles/claude/* to ~/.claude/)
./claude/scripts/setup.sh

# OpenCode config setup (symlinks dotfiles/opencode/* to ~/.opencode/)
./opencode/scripts/setup.sh

# Verify symlinks
ls -la ~/.claude
ls -la ~/.opencode

# No automated tests - validation is manual through config application
```

### File Operations

```bash
# Find all shell scripts
find . -name "*.sh"

# Find all fish configs
find . -name "*.fish"

# Count total config files
find . -type f \( -name "*.sh" -o -name "*.fish" -o -name "*.toml" -o -name "*.json" \) | wc -l
```

## Code Style Guidelines

### Shell Scripts (Bash/Fish)

**File Structure:**
- Always use shebang: `#!/bin/bash` or `#!/usr/bin/env bash`
- Use `set -e` or `set -euo pipefail` for error handling
- Document purpose in header comments

**Naming Conventions:**
- Functions: lowercase with underscores: `get_volume()`, `display()`
- Variables: lowercase with underscores: `work_time`, `break_color`
- Constants: UPPERCASE: `CONFIG_FILE`, `DEBUG_LOG`, `MAX_CONSECUTIVE_BLOCKS`
- File names: kebab-case: `setup.sh`, `todo-enforcer.sh`, `file-suggestion.sh`

**Error Handling:**
- Always check command availability: `command -v jq &>/dev/null`
- Validate file existence before reading: `[[ -f "$FILE" ]]`
- Use `|| true` for non-critical operations to prevent exit
- Prefer `die()` or `allow_exit()` helper functions for clean exits

**Style:**
- Use `[[` instead of `[` for conditionals
- Quote variables: `"$VAR"` not `$VAR`
- Prefer `$(command)` over backticks
- Use `readonly` for constants when appropriate
- shellcheck disable comments when needed: `# shellcheck disable=SC2155`

**Example Pattern:**
```bash
#!/usr/bin/env bash
set -euo pipefail

readonly CONFIG_FILE="$HOME/.config/myapp/config.json"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

die() {
  log "ERROR: $1"
  exit 1
}

[[ -f "$CONFIG_FILE" ]] || die "Config not found"
```

### JSON Configuration Files

**Format:**
- Use 2-space indentation
- No trailing commas
- Keep simple configs flat and readable

**Example:**
```json
{
  "model": "opus",
  "enabledPlugins": {
    "plugin-name": true
  }
}
```

### Markdown Documentation

**Style:**
- Use concise, direct language (no fluff)
- Code blocks must specify language
- File/path references use backticks: `~/.claude/settings.json`
- Headers follow hierarchy (# then ## then ###)

### Git Configuration

**Conventions:**
- Default branch: `main`
- Auto-setup remote on push: enabled
- Email: guisaliba@gmail.com
- Commits: never commit unless explicitly requested

**Branching:**
- Check existing local branches before creating new ones
- Infer and follow the git flow pattern in use

## Environment and Preferences

**Primary OS:** Arch Linux  
**Secondary OS:** Ubuntu WSL2  
**Timezone:** UTC-3

**Package Managers:**
- Node: prefer `bun`; stick to existing PM if repo already uses one
- Python: use `uv` for all workflows; avoid global installs

**Shell:** Fish shell with Starship prompt

## Claude-Specific Instructions

This repository includes Claude Code configuration in `claude/CLAUDE.md`. Key principles:

**Interaction:**
- No emojis, no em dashes (use hyphens/colons)
- Be concise: no preambles, acknowledgments, or status updates
- Never guess numbers - measure/benchmark
- Clarify unclear requests, then proceed autonomously

**Code Quality:**
- Match existing patterns in disciplined code
- Bugfix = minimal change (no refactoring)
- Never use `as any`, `@ts-ignore`, or `@ts-expect-error`

**Verification:**
- Run diagnostics on changed files
- No evidence = not complete
- Don't fix pre-existing failures unless asked

**Task Management:**
- Create todos for 2+ step tasks
- Keep one `in_progress`, complete immediately
- Update on scope changes

**Search Strategy (by codebase size):**
- Small (<50 files): direct tools only (Glob, Grep, Read)
- Medium (50-200): direct tools first, agent if inconclusive after 2-3 attempts
- Large (>200): spawn agent in background + direct tools in parallel

**Git:**
- Check `.claude/issues/*.md` for issue details first
- Never commit unless explicitly requested

## Common Operations

### Adding New Configurations

1. Create config file in appropriate directory
2. Update setup script if symlinking is needed
3. Document purpose in this file or relevant README
4. Test manually by applying config

### Modifying Existing Configs

1. Read existing file first
2. Preserve formatting and structure
3. Match existing style (indentation, naming)
4. Verify changes don't break symlinks or references

### Working with Claude Configs

```bash
# Claude directory structure
~/.claude/
  ├── CLAUDE.md          # Core behavior instructions
  ├── settings.json      # Claude settings
  ├── agents/            # Custom agents
  ├── commands/          # Custom commands  
  ├── hooks/             # Lifecycle hooks
  ├── plugins/           # Custom plugins
  ├── rules/             # Additional rules
  ├── scripts/           # Helper scripts
  └── skills/            # Custom skills
```

Files in `dotfiles/claude/` are symlinked to `~/.claude/` via setup script.

## Agent Skills

This repository includes agent skills following the [Agent Skills](https://agentskills.io/) format.

### Installed Skills

Skills are located in `claude/skills/` (symlinked to `~/.claude/skills`):

1. **planning-with-files**
   - Manus-style persistent markdown planning workflow
   - Use for: complex tasks, multi-step projects, research
   - Triggers: planning, organizing work, tracking progress

2. **vercel-react-best-practices** (via add-skill CLI)
   - Source: vercel-labs/agent-skills
   - React/Next.js performance optimization (40+ rules, 8 categories)
   - Triggers: React components, Next.js pages, data fetching, bundle optimization

3. **web-design-guidelines** (via add-skill CLI)
   - Source: vercel-labs/agent-skills
   - UI/accessibility audit (100+ rules)
   - Triggers: "review UI", "check accessibility", "audit design"

4. **vercel-deploy** (via add-skill CLI)
   - Source: vercel-labs/agent-skills
   - Deploy to Vercel directly from Codex/Claude Code
   - Triggers: "deploy my app", "deploy to production", "push this live"

### Update Agent Skills

To update skills to latest version:
```bash
npx add-skill vercel-labs/agent-skills
```

## OpenCode Configuration

OpenCode-specific configuration is in `opencode/`:

```bash
opencode/
├── .gitignore         # Excludes binaries and node_modules
├── package.json       # Plugin dependencies (@opencode-ai/plugin)
├── bun.lock          # Lockfile for reproducible installs
└── scripts/
    └── setup.sh      # Symlink setup script
```

Files are symlinked to `~/.opencode/` via `opencode/scripts/setup.sh`.

**Note:** Binary (`~/.opencode/bin/opencode`) and `node_modules/` are NOT version-controlled (regenerated via `bun install`).

## Anti-Patterns to Avoid

- Empty catch blocks: `catch(e){}`
- Deleting failing tests
- Shotgun debugging
- Direct visual/styling edits without logic changes
- Making assumptions - measure instead
- Creating files unnecessarily - prefer editing existing

## File Modification Protocol

1. **Read first:** Always use Read tool before editing
2. **Match style:** Preserve exact indentation and formatting
3. **Verify changes:** Check file still works after modification
4. **No new files:** Unless absolutely necessary; prefer editing existing

## Constraints and Preferences

- Prefer existing libraries over reinventing
- Keep changes small and focused
- When unsure about scope, ask first
- Follow "understand before coding" principle
- For complex work: research + questions + confirmed plan
