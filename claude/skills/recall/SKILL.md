---
name: recall
description: Load context from past Claude Code sessions before starting work. Use /recall to look up what you worked on recently, find past decisions, and plan your day. Triggers on /recall commands.
---

# /recall

Load context from the brain-recall memory layer.

## Commands

### Temporal recall
```
/recall today
/recall yesterday
/recall last-week
/recall range YYYY-MM-DD YYYY-MM-DD
```

### Topic search
```
/recall topic <query>
/recall topic <query> --scope sessions|notes|daily|all
```

### Project recall
```
/recall project <project-slug>
/recall project <project-slug> --since 7d
```

### Daily planning
```
/recall plan
/recall daily
```

---

## Implementation

When the user invokes `/recall`, parse the command and execute the corresponding action below.

### Temporal (/recall today|yesterday|last-week|range)

Run:
```bash
python3 ~/bin/cc-recall-query temporal [--today|--yesterday|--last-week|--start YYYY-MM-DD --end YYYY-MM-DD]
```
Output the result directly to the user.

### Topic (/recall topic <query>)

Run these qmd searches in order. Use `~/bin/qmd` as the binary.
Stop if a search is irrelevant (empty or very low score). Synthesize top results.

```bash
# 1. Session summaries (BM25, most targeted)
~/bin/qmd search "<query>" -c session_summaries -n 10

# 2. Projects
~/bin/qmd search "<query>" -c projects -n 5

# 3. Sessions (full transcripts)
~/bin/qmd search "<query>" -c sessions -n 10

# 4. Notes
~/bin/qmd search "<query>" -c notes -n 10

# 5. Daily (semantic if available, fallback BM25)
~/bin/qmd search "<query>" -c daily -n 10
```

Synthesize into:
- **Top hits** with vault-relative paths
- **Where you left off** (most recent matching session)
- **Next best action** (from summary if available)

If all results are weak, run hybrid:
```bash
~/bin/qmd query "<query>" -c sessions -n 10
```

### Project (/recall project <slug>)

Run:
```bash
python3 ~/bin/cc-recall-query project <slug> [--since 7d]
```
Output the result directly. Also check if there's a project note:
```
/mnt/c/obsidian_vault/AI/ClaudeCode/projects/<slug>.md
```
If it exists, read and include relevant context.

### Plan (/recall plan or /recall daily)

Run:
```bash
python3 ~/bin/cc-recall-query plan
```
Output the result. Then read the created daily note and include its path.

---

## Vault Paths

- Sessions: `/mnt/c/obsidian_vault/AI/ClaudeCode/sessions/<machine>/<project>/`
- Summaries: `/mnt/c/obsidian_vault/AI/ClaudeCode/session_summaries/`
- Projects: `/mnt/c/obsidian_vault/AI/ClaudeCode/projects/`
- Daily: `/mnt/c/obsidian_vault/daily/`
- qmd binary: `~/bin/qmd`
- Query helper: `~/bin/cc-recall-query`

## Sync

To sync all sessions before recall: `cc-recall-sync`
To sync + push: `cc-recall-sync --push`

## Notes

- qmd `collection list` and `collection remove` may segfault on this WSL2 setup; use `search`, `update`, `collection add` instead.
- Collections config is at `~/.config/qmd/index.yml`.
- State of exported sessions is at `~/.config/cc-recall/sync-state.json`.
