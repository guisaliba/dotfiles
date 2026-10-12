# Obsidian configuration

Source of truth for the Obsidian configuration of the `brain` vault
(`~/brain`) that the user authors. The `obsidian` component of
`install.sh` materializes it into the vault.

## Decision: `.obsidian` stays out of Git (2026-10-12)

Decision: `.obsidian/` stays Git-ignored in the `brain` repository.
This directory in dotfiles tracks the author-owned configuration
instead.

Reasons:

1. `.obsidian` mixes **state** with **config**. `workspace.json` records
   window layout state. Plugin `data.json` files are rewritten by
   plugins at runtime. Git-tracking state produces noisy diffs and
   merge conflicts on every device. This is the "weird JSON values"
   experience that led to the original ignore rule.
2. The `brain` vault has a written rule: "`.obsidian/` is intentionally
   ignored and should not be tracked" (`brain/AGENTS.md`). The rule
   stays.
3. dotfiles is the established home for machine configuration across
   devices. `install.sh` applies files deterministically, with backups.

Alternatives rejected:

- Track `.obsidian` in `brain`: state churn, and config noise in a
  public repository. Also contradicts `brain/AGENTS.md`.
- Copy all of `.obsidian` into dotfiles: would copy plugin state and
  third-party assets, and would fight the apps that rewrite those
  files at runtime.

## What is tracked

Tracked here, materialized into `~/brain/.obsidian/`:

- `snippets/link-colors.css` - visible link colors. Uniform pastel
  white `#F2EFE9` for note and web links, warm gray `#B5AFA6` with a
  dashed underline for dead links. The user confirmed this palette on
  a rendered swatch card (2026-10-12).

Not tracked, left inside ignored `.obsidian`:

- `workspace.json`, plugin data files, plugin downloads, third-party
  themes (`Minimal`, `Omarchy`), caches.

## How to add a managed file

One managed file maps to one `components.tsv` row. A new component
name must also be registered in `lib/dotfiles_installer.py`
(`KNOWN_COMPONENTS`, `EXPECTED_COMPONENT_ORDER`, `ACTION_BY_COMPONENT`,
`EXPECTED_HOSTS`, `EXPECTED_DEFAULTS`, `EXPECTED_RISKS`). Then run
`./test.sh --repo-only`.

## Documented plugin toggles (recorded, not copied)

Plugin `data.json` files belong to the plugins and are rewritten at
runtime, so we do not copy them. We record the decisions here as a
setup checklist:

- Hider (`obsidian-hider`), **Hide tab bar** = ON (2026-10-12).
  Hides the tab container at the top of the window. Reason: the user
  navigates notes through the file explorer and does not use tabs.
  Verified in `plugins/obsidian-hider/main.js` (setting key
  `hideTabs`, command "Toggle tab bar") and `styles.css` (class
  `hider-tabs` hides `.workspace-tab-header-container`).
- Alternatives rejected for tab hiding: native Settings -> Appearance
  has no such option (official help page `en/User interface/
  Appearance.md` lists color scheme, themes, snippets, app icon);
  Minimal Theme Settings `focusMode` also collapses the tab header,
  but with animation and with broader focus effects, so the targeted
  Hider toggle is preferred; a custom CSS snippet was the last resort
  and was not needed.

## Visual changes and color evidence

Rule (2026-10-12): never apply a color from a HEX value alone. Render
a swatch card of the candidate colors on the real background first,
label each swatch with its HEX, and apply only after the user
confirms. See also the profile memory page
`preferences/color-changes-visualize-hexes.md`.
