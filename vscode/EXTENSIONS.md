# VS Code Extensions

The extension list lives in [`extensions.tsv`](extensions.tsv). That file is the
single source of truth. `install.sh` reads it to validate and install the
selected extensions with `code --install-extension`.

## How to add an extension

1. Open `vscode/extensions.tsv`.
2. Add one line with the exact extension identifier, for example `esbenp.prettier-vscode`.
3. Keep the list sorted or grouped as you prefer; `install.sh` does not require an order.

`install.sh` accepts the identifiers from this file with
`--vscode-extensions <all|none|comma-separated-ids>`.

## Current tracked extensions

The complete list is the non-comment content of `vscode/extensions.tsv`.
`install.sh --check --components vscode` prints the current selection count.