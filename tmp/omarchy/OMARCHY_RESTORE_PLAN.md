# Omarchy Restore Plan (Conservative)

Generated: 2026-05-05T22:24:40-03:00

## Restore Order

1. Restore SSH keys: copy ~/.ssh, chmod 700 ~/.ssh, chmod 600 keys, verify ssh -T github.com.
2. Authenticate GitHub CLI: gh auth login.
3. Clone dotfiles: git clone to ~/dotfiles.
4. Apply Starship: place starship.toml under ~/.config.
5. Apply Ghostty: copy config under ~/.config/ghostty.
6. Apply minimal Bash: create ~/.bashrc with only approved aliases/functions.
7. Do not apply Fish config.
8. Do not apply arch/ legacy config.
9. Do not overwrite Omarchy-managed configs: ~/.config/hypr ~/.config/waybar ~/.config/omarchy ~/.local/share/omarchy.
10. Add customizations incrementally. After each change: reboot and verify login, terminal, browser, audio, Wi-Fi, Bluetooth, suspend, updates.

## Post-Install Notes

- Voxtype: install via Omarchy Install > AI > Dictation. Hotkey Super+Ctrl+X.
- Atuin/Zoxide: use Omarchy defaults; do not restore old configs.
- git-delta: install only if needed and not present.
