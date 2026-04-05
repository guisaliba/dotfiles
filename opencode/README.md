# OpenCode

OpenCode reads project-style config under `**~/.config/opencode**`. This repo keeps the tracked copy in `**opencode/**` and links it there with `**scripts/setup.sh**`.

## Setup

From a shell (paths in the script assume your dotfiles checkout lives at `**$HOME/dotfiles**`; change the variables at the top of the script if yours differs):

```bash
./opencode/scripts/setup.sh
```

The script:

1. Ensures `**~/.config/opencode**` exists.
2. Symlinks `**package.json**`, `**bun.lock**`, and `**.gitignore**` from `**$HOME/dotfiles/opencode/**` into `**~/.config/opencode/**` (existing real files are moved aside with a `***.bak.<timestamp>**` suffix; existing symlinks are replaced).
3. Symlinks `**$HOME/dotfiles/AGENTS.md**` to `**~/.config/opencode/AGENTS.md**` so OpenCode and your other tools share the same instruction file.

Then install plugin dependencies:

```bash
cd ~/.config/opencode && bun install
```

Generated paths (`**node_modules/**`, `**bin/**`) stay out of git via `**opencode/.gitignore**`.

## Editing instructions

Change agent behavior in the repo-root `**AGENTS.md**`. Re-run `**setup.sh**` only if the symlink to `**AGENTS.md**` is missing or broken; content updates apply immediately because the link points at the file in dotfiles.

## Files in this folder

- `**package.json**` - OpenCode plugin dependency (`**@opencode-ai/plugin**`).
- `**bun.lock**` - lockfile for `**bun install**`.
- `**scripts/setup.sh**` - symlink installer for `**~/.config/opencode**`.

