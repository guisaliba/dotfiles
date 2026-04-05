#!/usr/bin/env bash
# Regenerate .cursor/rules/agents.mdc from repository-root AGENTS.md (always-apply Cursor rule).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="${ROOT}/AGENTS.md"
OUT_DIR="${ROOT}/.cursor/rules"
OUT="${OUT_DIR}/agents.mdc"

[[ -f "$SOURCE" ]] || {
  echo "error: missing ${SOURCE}" >&2
  exit 1
}

mkdir -p "$OUT_DIR"

{
  cat <<'FRONTMATTER'
---
description: Agent instructions (generated from AGENTS.md - run cursor/scripts/sync-agents-rule.sh after edits)
alwaysApply: true
---

<!-- Generated file: do not edit by hand. Source: AGENTS.md at repository root. -->

FRONTMATTER
  cat "$SOURCE"
} >"$OUT"

echo "wrote ${OUT}"
