#!/usr/bin/env bash
set -Eeuo pipefail

# bootstrap-agent-stack.sh
#
# Usage:
#   chmod +x bootstrap-agent-stack.sh
#   ./bootstrap-agent-stack.sh
#
# Optional:
#   DOTFILES_DIR="$HOME/dotfiles" ./bootstrap-agent-stack.sh
#   RUN_AGENT_DOCS=0 ./bootstrap-agent-stack.sh
#   PUSH=1 ./bootstrap-agent-stack.sh
#   BRANCH=chore/agent-stack ./bootstrap-agent-stack.sh
#
# Defaults:
#   - writes changes locally
#   - creates/updates deterministic docs
#   - invokes Pi if available to review docs/extension
#   - does NOT push unless PUSH=1

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CHEZMOI_SRC="${CHEZMOI_SRC:-$DOTFILES_DIR/chezmoi}"
BRANCH="${BRANCH:-chore/agent-stack-chezmoi}"
RUN_AGENT_DOCS="${RUN_AGENT_DOCS:-1}"
PUSH="${PUSH:-0}"
CREATE_BRANCH="${CREATE_BRANCH:-1}"

log() {
  printf '\n==> %s\n' "$*"
}

warn() {
  printf '\nWARN: %s\n' "$*" >&2
}

die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

write_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
}

copy_dir_clean() {
  local src="$1"
  local dst="$2"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
}

copy_file_replace_symlink() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  rm -f "$dst"
  cp "$src" "$dst"
}

json_update_pi_settings() {
  local settings="$HOME/.pi/agent/settings.json"
  mkdir -p "$(dirname "$settings")"

  python3 - "$settings" <<'PY'
import json
import os
import sys

path = sys.argv[1]
data = {}

if os.path.exists(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError:
        backup = path + ".bak"
        os.replace(path, backup)
        data = {}

def uniq(seq):
    out = []
    for item in seq:
        if item not in out:
            out.append(item)
    return out

data["skills"] = uniq(list(data.get("skills", [])) + ["~/.agents/skills"])
data["extensions"] = uniq(list(data.get("extensions", [])) + [
    "~/.pi/agent/extensions/rtk",
    "~/.pi/agent/extensions/cavemem-bridge",
])

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

require_repo() {
  [[ -d "$DOTFILES_DIR" ]] || die "DOTFILES_DIR does not exist: $DOTFILES_DIR"
  [[ -d "$DOTFILES_DIR/.git" ]] || die "DOTFILES_DIR is not a git repo: $DOTFILES_DIR"
}

setup_branch() {
  cd "$DOTFILES_DIR"

  if [[ "$CREATE_BRANCH" != "1" ]]; then
    return
  fi

  if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    git switch "$BRANCH" || warn "Could not switch to existing branch $BRANCH. Continuing on current branch."
  else
    git switch -c "$BRANCH" || warn "Could not create branch $BRANCH. Continuing on current branch."
  fi
}

backup_existing_targets() {
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local backup="$DOTFILES_DIR/.agent-stack-backup/$ts"

  mkdir -p "$backup"

  for p in \
    "$HOME/.codex/AGENTS.md" \
    "$HOME/.config/opencode/AGENTS.md" \
    "$HOME/.pi/agent/AGENTS.md" \
    "$HOME/.pi/agent/settings.json"
  do
    if [[ -e "$p" || -L "$p" ]]; then
      mkdir -p "$backup/$(dirname "${p#$HOME/}")"
      cp -a "$p" "$backup/${p#$HOME/}"
    fi
  done

  log "Backed up existing agent targets to $backup"
}

write_agents_md() {
  log "Writing canonical agents/AGENTS.md"

  write_file "$DOTFILES_DIR/agents/AGENTS.md" <<'EOF'
# Global Agent Instructions

## Role

Act as a senior engineering partner.

Be direct, practical, and precise. No filler. No flattery. No theater.

Default mode is advisory until implementation is explicitly requested.

## Operating model

My preferred workflow is:

1. Clarify the real goal before building.
2. Interview me when requirements are vague, risky, or underspecified.
3. Prefer one question at a time.
4. If the answer is discoverable from the repo, inspect the repo instead of asking.
5. Convert the clarified goal into a short plan.
6. Break plans into phases, milestones, and small implementation steps.
7. Use TDD for implementation unless the task is trivial or testing is impractical.
8. Implement one bounded step at a time.
9. Verify with the closest relevant checks.
10. Commit atomic changes when asked.
11. Open or prepare PRs when asked.
12. Treat my review feedback as the next source of truth.

## Discovery and planning

Before coding:

- Identify the user-facing behavior or developer-facing contract being changed.
- Identify likely files and existing conventions.
- Identify tests or checks that should prove the change.
- State assumptions briefly when proceeding under uncertainty.
- Ask only when ambiguity changes scope, risk, data model, public API, or likely files touched.

For design or product work:

- Use a grilling/interview style.
- Challenge fuzzy terms.
- Push toward concrete examples, edge cases, and explicit tradeoffs.
- Do not accept the first stated solution as the real requirement.

## TDD

Use red-green-refactor for non-trivial feature work and bug fixes.

Rules:

- Test behavior through public interfaces.
- Prefer integration-style tests over implementation-coupled unit tests.
- Write one failing test for one behavior.
- Implement the smallest code needed to pass.
- Repeat vertically.
- Refactor only while green.
- Run tests after each meaningful refactor.

Do not write all tests first and then all implementation.

## Implementation

- Prefer the smallest coherent change.
- Do not refactor broadly unless requested.
- Follow existing repo conventions, package manager, architecture, and naming.
- Do not add dependencies without a clear reason.
- Do not change unrelated files.
- Do not delete failing tests to make checks pass.
- Do not shotgun-debug.
- Do not silently weaken behavior, validation, security, or types.

## Verification

No evidence means not done.

After changes, run the closest relevant checks available:

- focused tests first
- then broader tests if appropriate
- lint/typecheck/build when relevant

If checks fail:

- fix failures caused by the change
- do not fix unrelated failures unless asked
- after repeated failed attempts, stop and report what was tried, current root cause, and next safe option

## Git

When asked to commit:

- Use Conventional Commits.
- Keep commits atomic.
- Use conventional branch names in kebab-case.
- Do not mix unrelated edits.

When asked to open a PR:

- Summarize behavior change.
- Include verification evidence.
- Mention known limitations or skipped checks.

## Communication

- Be concise.
- Use direct answers.
- No emojis.
- No em dashes.
- No preambles unless they prevent confusion.
- Do not explain code unless asked.
- Match my requested depth.
- If something is wrong or risky, say so plainly and give the better option.

## Tooling preferences

- Node: prefer the repo's package manager. If absent, prefer bun.
- Python: prefer uv when practical. Avoid global installs.
- Shell: assume Linux or WSL2.
- Timezone: UTC-3.

## Required global capabilities

These should be available in every coding-agent session when the harness supports them:

- caveman for concise agent output.
- cavemem for cross-session memory.
- rtk for shell/tool safety and command rewriting.
- grill-me for requirement discovery.
- grill-with-docs for requirement discovery grounded in repo docs.
- tdd for red-green-refactor implementation.
EOF
}

write_chezmoi_source() {
  log "Writing chezmoi source tree under $CHEZMOI_SRC"

  mkdir -p "$CHEZMOI_SRC/.chezmoitemplates/agents"
  cp "$DOTFILES_DIR/agents/AGENTS.md" "$CHEZMOI_SRC/.chezmoitemplates/agents/AGENTS.md"

  write_file "$CHEZMOI_SRC/dot_codex/AGENTS.md.tmpl" <<'EOF'
{{ include ".chezmoitemplates/agents/AGENTS.md" }}
EOF

  write_file "$CHEZMOI_SRC/dot_config/opencode/AGENTS.md.tmpl" <<'EOF'
{{ include ".chezmoitemplates/agents/AGENTS.md" }}
EOF

  write_file "$CHEZMOI_SRC/dot_pi/agent/AGENTS.md.tmpl" <<'EOF'
{{ include ".chezmoitemplates/agents/AGENTS.md" }}
EOF
}

materialize_agent_targets() {
  log "Materializing AGENTS.md into global harness locations"

  mkdir -p "$HOME/.codex" "$HOME/.config/opencode" "$HOME/.pi/agent"

  copy_file_replace_symlink "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.codex/AGENTS.md"
  copy_file_replace_symlink "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
  copy_file_replace_symlink "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.pi/agent/AGENTS.md"
}

install_chezmoi_if_missing() {
  if have chezmoi; then
    return
  fi

  log "Installing chezmoi into ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"

  export PATH="$HOME/.local/bin:$PATH"

  have chezmoi || warn "chezmoi install did not put chezmoi on PATH"
}

apply_chezmoi_source() {
  if ! have chezmoi; then
    warn "chezmoi not available. Direct target files were already written."
    return
  fi

  log "Applying chezmoi source from $CHEZMOI_SRC"
  chezmoi apply --source "$CHEZMOI_SRC" --force --no-tty -v || warn "chezmoi apply failed. Direct target files were already written."
}

install_agent_skills() {
  log "Installing shared agent skills"

  have git || die "git is required"
  mkdir -p "$HOME/.agents/skills"
  mkdir -p "$CHEZMOI_SRC/dot_agents/skills"

  local tmp tmp_quoted
  tmp="$(mktemp -d)"
  printf -v tmp_quoted '%q' "$tmp"
  trap "rm -rf $tmp_quoted" EXIT

  git clone --depth 1 https://github.com/mattpocock/skills "$tmp/matt-skills"

  for skill in \
    "productivity/grill-me" \
    "engineering/grill-with-docs" \
    "engineering/tdd"
  do
    local name
    name="$(basename "$skill")"

    copy_dir_clean "$tmp/matt-skills/skills/$skill" "$HOME/.agents/skills/$name"
    copy_dir_clean "$tmp/matt-skills/skills/$skill" "$CHEZMOI_SRC/dot_agents/skills/$name"
  done

  rm -rf "$tmp"
  trap - EXIT
}

install_external_tools() {
  log "Installing cavemem, caveman, and rtk integrations where supported"

  if have npm; then
    if have cavemem; then
      log "cavemem already available. Skipping global npm install."
    else
      mkdir -p "$HOME/.local"
      npm install -g --prefix "$HOME/.local" cavemem || warn "Failed to install cavemem globally"
      export PATH="$HOME/.local/bin:$PATH"
    fi
  else
    warn "npm not found. Skipping npm-based installs: cavemem and caveman skills installer."
  fi

  if have cavemem; then
    cavemem install --ide codex || warn "cavemem codex install failed"
    cavemem install --ide opencode || warn "cavemem opencode install failed"
    cavemem doctor || true
    cavemem status || true
  else
    warn "cavemem not found. Skipping cavemem IDE wiring."
  fi

  if have npm; then
    npx -y skills add JuliusBrussee/caveman -g -a codex -s caveman -y --copy || warn "caveman codex install failed"
    npx -y skills add JuliusBrussee/caveman -g -a opencode -s caveman -y --copy || warn "caveman opencode install failed"

    if [[ -d "$HOME/.agents/skills/caveman" ]]; then
      copy_dir_clean "$HOME/.agents/skills/caveman" "$CHEZMOI_SRC/dot_agents/skills/caveman"
    else
      warn "caveman skill was not found under ~/.agents/skills after install"
    fi
  fi

  if ! have rtk; then
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh || warn "rtk install failed"
    export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
  fi

  if have rtk; then
    rtk init -g --codex || warn "rtk codex init failed"
    rtk init -g --opencode || warn "rtk opencode init failed"

    if [[ -f "$HOME/.config/opencode/plugins/rtk.ts" ]]; then
      mkdir -p "$CHEZMOI_SRC/dot_config/opencode/plugins"
      cp "$HOME/.config/opencode/plugins/rtk.ts" "$CHEZMOI_SRC/dot_config/opencode/plugins/rtk.ts"
    fi

    rtk gain || true
  fi

  if have pi; then
    pi install git:github.com/v2nic/pi-caveman || warn "pi-caveman install failed"
  else
    warn "pi not found. Pi-specific extension files will still be written."
  fi
}

write_pi_rtk_extension() {
  log "Writing Pi RTK extension"

  local dst="$HOME/.pi/agent/extensions/rtk"
  local src="$CHEZMOI_SRC/dot_pi/agent/extensions/rtk"

  mkdir -p "$dst" "$src"

  for base in "$dst" "$src"; do
    write_file "$base/index.ts" <<'EOF'
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;

    const command = event.input.command;
    if (typeof command !== "string" || command.trim() === "") return;
    if (command.startsWith("rtk ")) return;
    if (command.includes("RTK_DISABLED=1")) return;

    try {
      const { stdout } = await execFileAsync("rtk", ["rewrite", command], {
        signal: ctx.signal,
      });

      const rewritten = stdout.trim();

      if (rewritten && rewritten !== command) {
        event.input.command = rewritten;
        ctx.ui.setStatus("rtk", "rtk");
      }
    } catch {
      return;
    }
  });
}
EOF
  done
}

write_pi_cavemem_bridge_extension() {
  log "Writing Pi cavemem MCP bridge extension"

  local dst="$HOME/.pi/agent/extensions/cavemem-bridge"
  local src="$CHEZMOI_SRC/dot_pi/agent/extensions/cavemem-bridge"

  mkdir -p "$dst" "$src"

  for base in "$dst" "$src"; do
    write_file "$base/package.json" <<'EOF'
{
  "name": "pi-cavemem-bridge",
  "private": true,
  "type": "module",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  }
}
EOF

    write_file "$base/index.ts" <<'EOF'
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { execFile } from "node:child_process";
import { readdir, realpath } from "node:fs/promises";
import { dirname, join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

type TransportCommand = {
  command: string;
  args: string[];
};

let cachedTransportCommand: Promise<TransportCommand> | undefined;

async function resolveCavememTransportCommand(): Promise<TransportCommand> {
  const { stdout } = await execFileAsync("which", ["cavemem"]);
  const cavememBin = stdout.trim().split("\n")[0];
  const realBin = await realpath(cavememBin);
  const distDir = dirname(realBin);
  const entries = await readdir(distDir);
  const serverEntry = entries.find((entry) => /^server-.*\.js$/.test(entry));

  if (!serverEntry) {
    return { command: "cavemem", args: ["mcp"] };
  }

  // cavemem@0.1.3's `cavemem mcp` command imports the server module but does
  // not start it. Executing the bundled server file directly starts MCP stdio.
  return { command: process.execPath, args: [join(distDir, serverEntry)] };
}

async function callCavememTool(name: string, args: Record<string, JsonValue>, signal?: AbortSignal) {
  const transportCommand = await (cachedTransportCommand ??= resolveCavememTransportCommand());
  const transport = new StdioClientTransport(transportCommand);

  const client = new Client(
    { name: "pi-cavemem-bridge", version: "0.1.0" },
    { capabilities: {} },
  );

  try {
    if (signal?.aborted) throw new Error("aborted");
    await client.connect(transport);
    return await client.callTool({ name, arguments: args });
  } finally {
    await client.close().catch(() => undefined);
  }
}

function stringifyResult(result: unknown): string {
  return JSON.stringify(result, null, 2);
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "cavemem_search",
    label: "Cavemem Search",
    description: "Search cavemem memory using compact progressive-disclosure results.",
    parameters: Type.Object({
      query: Type.String({ description: "Natural-language search query." }),
      limit: Type.Optional(Type.Number({ description: "Maximum number of results." })),
    }),
    async execute(_toolCallId, params, signal) {
      const result = await callCavememTool("search", params as Record<string, JsonValue>, signal);
      return {
        content: [{ type: "text", text: stringifyResult(result) }],
        details: { tool: "search" },
      };
    },
  });

  pi.registerTool({
    name: "cavemem_list_sessions",
    label: "Cavemem List Sessions",
    description: "List recent cavemem sessions in reverse chronological order.",
    parameters: Type.Object({
      limit: Type.Optional(Type.Number({ description: "Maximum number of sessions." })),
    }),
    async execute(_toolCallId, params, signal) {
      const result = await callCavememTool("list_sessions", params as Record<string, JsonValue>, signal);
      return {
        content: [{ type: "text", text: stringifyResult(result) }],
        details: { tool: "list_sessions" },
      };
    },
  });

  pi.registerTool({
    name: "cavemem_timeline",
    label: "Cavemem Timeline",
    description: "Get chronological observation identifiers for a cavemem session.",
    parameters: Type.Object({
      session_id: Type.String({ description: "Cavemem session id." }),
      around_id: Type.Optional(Type.Number({ description: "Observation id to center around." })),
      limit: Type.Optional(Type.Number({ description: "Maximum number of observations." })),
    }),
    async execute(_toolCallId, params, signal) {
      const result = await callCavememTool("timeline", params as Record<string, JsonValue>, signal);
      return {
        content: [{ type: "text", text: stringifyResult(result) }],
        details: { tool: "timeline" },
      };
    },
  });

  pi.registerTool({
    name: "cavemem_get_observations",
    label: "Cavemem Get Observations",
    description: "Fetch full cavemem observation bodies by id.",
    parameters: Type.Object({
      ids: Type.Array(Type.Number(), { description: "Observation ids." }),
      expand: Type.Optional(Type.Boolean({ description: "Return expanded human-readable content." })),
    }),
    async execute(_toolCallId, params, signal) {
      const result = await callCavememTool("get_observations", params as Record<string, JsonValue>, signal);
      return {
        content: [{ type: "text", text: stringifyResult(result) }],
        details: { tool: "get_observations" },
      };
    },
  });

  pi.registerCommand("cavemem-status", {
    description: "Show cavemem status.",
    handler: async (_args, ctx) => {
      ctx.ui.notify("Run `cavemem status` in a shell for the full wiring dashboard.", "info");
    },
  });
}
EOF
  done

  if have npm; then
    (cd "$dst" && npm install --omit=dev) || warn "npm install failed for Pi cavemem bridge"
  else
    warn "npm not found. Pi cavemem bridge dependency install skipped."
  fi
}

write_pi_settings() {
  log "Updating Pi settings"
  json_update_pi_settings

  mkdir -p "$CHEZMOI_SRC/dot_pi/agent"
  cp "$HOME/.pi/agent/settings.json" "$CHEZMOI_SRC/dot_pi/agent/settings.json"
}

write_docs() {
  log "Writing README documentation"

  write_file "$DOTFILES_DIR/README.md" <<'EOF'
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
EOF

write_file "$DOTFILES_DIR/agents/README.md" <<'EOF'

# Agents

This folder contains shared coding-agent configuration.

## Files

* `AGENTS.md`: canonical global instructions used by Codex, OpenCode, and Pi.
* `codex/README.md`: Codex-specific notes.
* `opencode/README.md`: OpenCode-specific notes.
* `pi/README.md`: Pi-specific notes.
* `skills/README.md`: shared skills notes.

## Policy

Do not maintain separate base and overlay Markdown files unless a harness genuinely needs different behavior.

Default rule: one source of truth, multiple placements.
EOF

mkdir -p "$DOTFILES_DIR/agents/codex" "$DOTFILES_DIR/agents/opencode" "$DOTFILES_DIR/agents/pi" "$DOTFILES_DIR/agents/skills"

write_file "$DOTFILES_DIR/agents/codex/README.md" <<'EOF'

# Codex

Codex uses:

* global instructions: `~/.codex/AGENTS.md`
* shared skills: `~/.agents/skills`

Managed integrations:

* caveman via `npx skills add JuliusBrussee/caveman -a codex`
* cavemem via `cavemem install --ide codex`
* rtk via `rtk init -g --codex`

Codex should follow the shared workflow in `agents/AGENTS.md`: clarify, plan, use TDD, verify, commit atomically when asked.
EOF

write_file "$DOTFILES_DIR/agents/opencode/README.md" <<'EOF'

# OpenCode

OpenCode uses:

* global instructions: `~/.config/opencode/AGENTS.md`
* shared skills: `~/.agents/skills`

Managed integrations:

* caveman via `npx skills add JuliusBrussee/caveman -g -a opencode -s caveman -y --copy`
* cavemem via `cavemem install --ide opencode`
* rtk via `rtk init -g --opencode`

OpenCode should follow the shared workflow in `agents/AGENTS.md`: clarify, plan, use TDD, verify, commit atomically when asked.
EOF

write_file "$DOTFILES_DIR/agents/pi/README.md" <<'EOF'

# Pi

Pi uses:

* global instructions: `~/.pi/agent/AGENTS.md`
* shared skills: `~/.agents/skills`
* global extensions: `~/.pi/agent/extensions/`

Managed integrations:

* caveman through `pi-caveman`
* rtk through a Pi extension that rewrites bash tool commands with `rtk rewrite`
* cavemem through a Pi extension bridge that exposes custom tools backed by `cavemem mcp`

## Cavemem bridge

Pi does not currently use cavemem through a documented native MCP client configuration in this setup.

Instead, `~/.pi/agent/extensions/cavemem-bridge/` registers Pi custom tools:

* `cavemem_search`
* `cavemem_list_sessions`
* `cavemem_timeline`
* `cavemem_get_observations`

The bridge calls cavemem's MCP stdio server and keeps cavemem as the storage/source-of-truth layer.
EOF

write_file "$DOTFILES_DIR/agents/skills/README.md" <<'EOF'

# Skills

Shared skills are installed into:

```text
~/.agents/skills
```

Managed skills:

* `grill-me`
* `grill-with-docs`
* `tdd`

These are copied from `mattpocock/skills`.

The global AGENTS instructions expect agents to use these skills for requirement discovery and TDD-oriented implementation.
EOF
}

invoke_pi_for_docs_and_bridge_review() {
  if [[ "$RUN_AGENT_DOCS" != "1" ]]; then
    log "Skipping agent-driven documentation review"
    return
  fi

  if ! have pi; then
    warn "Pi not found. Skipping agent-driven documentation review."
    return
  fi

  log "Invoking Pi to review docs and Pi cavemem bridge"

  local prompt
  prompt="$(mktemp)"

  cat > "$prompt" <<'EOF'
You are working inside my dotfiles repo.

Task:
Review and update the documentation for the new global agent stack.

Scope:

* Root README.md
* agents/README.md
* agents/codex/README.md
* agents/opencode/README.md
* agents/pi/README.md
* agents/skills/README.md
* Pi extensions under chezmoi/dot_pi/agent/extensions/

Context:

* The repo now uses one canonical agents/AGENTS.md.
* The old base-plus-overlay merge model should be considered deprecated.
* Chezmoi source lives under ./chezmoi to avoid treating the whole repo root as chezmoi source.
* Codex target: ~/.codex/AGENTS.md
* OpenCode target: ~/.config/opencode/AGENTS.md
* Pi target: ~/.pi/agent/AGENTS.md
* Shared skills target: ~/.agents/skills
* Required skills: grill-me, grill-with-docs, tdd.
* Required tools: caveman, cavemem, rtk.
* Cavemem exposes a stdio MCP server through `cavemem mcp`.
* Pi does not have documented native MCP client config in this setup, so the repo scaffolds a Pi extension bridge that registers custom Pi tools and forwards to cavemem MCP.
* Do not invent unsupported claims.
* Keep docs concise.
* Do not remove the deterministic documentation structure unless there is a clear reason.
* If the Pi cavemem bridge is wrong or fragile, fix it with the smallest coherent change.
* After editing, run the closest relevant checks available, at least TypeScript/package install checks for the extension if practical.
EOF

  (
    cd "$DOTFILES_DIR"
    pi -p "$(cat "$prompt")" || warn "Pi documentation/bridge review failed"
  )

  rm -f "$prompt"
}

git_commit_and_push() {
  cd "$DOTFILES_DIR"

  log "Git status"
  git status --short

  git add .gitignore README.md agents codex opencode chezmoi bootstrap-agent-stack.sh

  if git diff --cached --quiet; then
    log "No git changes to commit"
    return
  fi

  git commit -m "chore(agent-stack): simplify global agent configuration" || warn "git commit failed"

  if [[ "$PUSH" == "1" ]]; then
    git push -u origin "$(git branch --show-current)" || warn "git push failed"
  else
    log "Skipping push. Re-run with PUSH=1 to push the branch."
  fi
}

main() {
  require_repo
  setup_branch
  backup_existing_targets

  write_agents_md
  write_chezmoi_source
  materialize_agent_targets

  install_chezmoi_if_missing
  apply_chezmoi_source

  install_agent_skills
  install_external_tools

  write_pi_rtk_extension
  write_pi_cavemem_bridge_extension
  write_pi_settings

  write_docs
  invoke_pi_for_docs_and_bridge_review

  git_commit_and_push

  log "Done"
}

main "$@"
