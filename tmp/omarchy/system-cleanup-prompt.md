You are helping me prepare for a migration from my current Arch Linux + GNOME installation to Omarchy 3.6.

Context:
- Current OS: Arch Linux with GNOME.
- Target OS: Omarchy 3.6, fresh installation from ISO.
- Device: Dell Inspiron laptop, Intel i7 CPU with integrated GPU, 16GB DDR4 RAM.
- I have accumulated misconfigured environment files, kernel/module tweaks, dangling scripts, old services, GNOME-specific configs, Fish shell leftovers, Bash leftovers, PipeWire/Bluetooth/video troubleshooting snippets, and one-off fixes.
- My dotfiles are available remotely at https://github.com/guisaliba/dotfiles and locally at ~/dotfiles.
- I am cleaning the dotfiles repo before this audit. The repo is expected to drop arch/ entirely, drop fish/ entirely, and use Bash as the target shell for Omarchy.
- The live Arch system may still contain Fish config because I am not removing Fish from the live environment before migration. Do not confuse live-system leftovers with desired target-state dotfiles.

Primary goal:
Prepare a safe, conservative migration inventory and cleanup plan before I install Omarchy. Do not break the current installation while working. Do not delete or disable anything destructive without explicit confirmation.

Target-state decisions:
- Default shell on Omarchy: Bash.
- Terminal: Ghostty.
- Prompt: Starship.
- Fish: do not migrate.
- arch/ folder in dotfiles: do not migrate.
- Old i3/GNOME/desktop-manager configs: do not migrate unless explicitly justified.
- Keep Starship config.
- Keep Ghostty config if present and still valid.
- Keep minimal Bash aliases/functions only:
  - py alias
  - lg alias for lazygit
  - notes helper for Obsidian vault
  - Claude Code helper functions ported from Fish to Bash
- Do not keep old Claude plugin aliases unless separately justified.
- Do not keep old Docker destructive aliases unless explicitly approved.
- Do not keep i3-specific aliases/scripts.
- Do not keep Fish plugin scaffolding, fish_variables, Fisher, foreign-env, fenv, or nvm.fish.

Non-negotiable rules:
1. Do not guess.
2. Do not delete files without first creating a backup or producing a proposed deletion list.
3. Do not disable system services without explaining what they do, why they seem unnecessary, and what could break.
4. Do not modify bootloader, kernel parameters, initramfs, DKMS, display stack, audio stack, Bluetooth stack, NetworkManager, systemd, or login manager settings without explicit approval.
5. If unsure whether a file/config/service is still needed, ask me.
6. Prefer read-only inspection first.
7. Produce a clear report before making changes.
8. Work deliberately. This cleanup phase is important and should not be rushed.
9. Be especially cautious with anything that could prevent the current system from booting or logging in.

Phase 1: Discover the current system state.

Create ~/migration-audit/ and collect:

- uname -a
- hostnamectl
- lsb_release -a if available
- pacman -Qqe
- pacman -Qqem
- flatpak list --app
- systemctl list-unit-files
- systemctl --user list-unit-files
- systemctl list-timers --all
- systemctl --user list-timers --all
- lsblk -f
- findmnt
- cat /etc/fstab
- cat /proc/cmdline
- bootctl status if available
- efibootmgr -v if available
- dkms status if available
- lsmod
- lspci -k
- journalctl -p warning..alert -b
- journalctl --user -p warning..alert -b

Save outputs under ~/migration-audit/raw/.

Phase 2: Inspect important user configuration.

Inspect these paths:

- ~/dotfiles
- ~/.config
- ~/.local/bin
- ~/.local/share
- ~/.ssh
- ~/.gnupg
- ~/.bashrc
- ~/.bash_aliases
- ~/.profile
- ~/.pam_environment
- ~/.xprofile
- ~/.xinitrc
- ~/.gitconfig
- ~/.config/fish
- ~/.local/share/fish
- ~/.config/starship.toml
- ~/.config/atuin
- ~/.config/zoxide
- ~/.config/nvim
- ~/.config/tmux
- ~/.config/ghostty
- ~/.config/alacritty
- ~/.config/kitty
- ~/.config/hypr
- ~/.config/waybar
- ~/.config/pipewire
- ~/.config/wireplumber
- ~/.config/pulse
- ~/.config/systemd/user
- ~/.local/share/applications
- ~/.local/state

Classify each relevant item as:

A. Migrate to Omarchy immediately
B. Migrate after manual review
C. Do not migrate, likely GNOME-specific or stale
D. Do not migrate, likely workaround for past hardware issue
E. Do not migrate, Fish-specific leftover
F. Unknown, ask user

Phase 3: Inspect dotfiles repository carefully.

In ~/dotfiles:

- Read the README and any install scripts.
- Inspect shell setup.
- Confirm arch/ has been removed or mark it as non-migratable legacy archive.
- Confirm fish/ has been removed or mark it as non-migratable Fish legacy config.
- Inspect Bash setup.
- Inspect Starship setup.
- Inspect Ghostty setup if present.
- Inspect SSH-related helpers.
- Inspect package lists.
- Inspect scripts.
- Inspect AGENTS.md, Claude, Codex, Cursor, OpenCode, or AI-agent related rules.
- Identify what is still useful for Omarchy and what is tied to the previous Arch/GNOME/Fish installation.

Pay special attention to stale or risky items:
- GNOME configs
- GDM configs
- i3 configs
- old Hyprland configs not aligned with Omarchy
- ML4W remnants
- PipeWire/WirePlumber troubleshooting snippets
- Bluetooth troubleshooting snippets
- kernel module tweaks
- modprobe configs
- mkinitcpio hooks
- boot parameters
- systemd services created for one-time fixes
- scripts that assume old paths
- scripts that assume old display manager
- scripts that assume X11
- scripts that assume GNOME
- scripts that assume Fish
- scripts that patch audio/video/network behavior
- anything referencing evdmi, EDID, i915, nvidia, nouveau, amdgpu, pipewire, wireplumber, bluetooth, bluez, NetworkManager, GDM, SDDM, LightDM, grub, systemd-boot, mkinitcpio, dracut, dkms, v4l2loopback, custom kernel params, fish, fisher, fenv, foreign-env, nvm.fish, i3, or old desktop-manager configs

Phase 4: Inspect live Fish leftovers without modifying them.

The live Arch system may still use Fish. Inspect but do not remove:

- ~/.config/fish
- ~/.local/share/fish
- /etc/shells
- current login shell from getent passwd "$USER"
- output of echo "$SHELL"
- output of chsh -l if available

Classify Fish-related files as:
- needed only until migration
- not needed on Omarchy
- potentially useful content to port to Bash
- unsafe/stale session state

Do not remove Fish from the live environment. This audit is not allowed to break the current login shell.

Phase 5: Inspect system-level configuration.

Review these locations:

- /etc/systemd/system
- /etc/systemd/user
- /etc/modprobe.d
- /etc/modules-load.d
- /etc/mkinitcpio.conf
- /etc/mkinitcpio.d
- /etc/default/grub
- /boot/loader
- /etc/X11
- /etc/gdm
- /etc/sddm.conf
- /etc/pipewire
- /etc/wireplumber
- /etc/bluetooth
- /etc/NetworkManager
- /etc/pacman.conf
- /etc/pacman.d
- /etc/environment
- /etc/profile
- /etc/profile.d
- /etc/fstab
- /usr/local/bin
- /opt

For each suspicious item, classify:

- Keep for migration reference
- Recreate manually on Omarchy only if needed
- Do not migrate
- Ask user

Phase 6: Omarchy-specific target checks.

Assume Omarchy already provides many Bash-oriented shell integrations, including aliases/functions under ~/.local/share/omarchy/default/bash.

For target Omarchy:
- Do not duplicate Omarchy’s built-in eza ls aliases unless missing.
- Do not duplicate Omarchy’s c alias for OpenCode unless missing.
- Do not restore old dircolors/ls color config unless explicitly needed.
- Do not restore old Fish config.
- Keep Starship.
- Keep Ghostty.
- Keep a minimal ~/.bashrc.
- If Voxtype is desired, note that it should be installed after Omarchy through Install > AI > Dictation, then used with Super + Ctrl + X.
- If git-delta is desired, add it as a post-install package unless already installed.

Phase 7: Produce migration reports.

Create ~/migration-audit/MIGRATION_REPORT.md with:

1. Executive summary
2. What must be backed up
3. What should be migrated immediately
4. What should be migrated only after review
5. What should not be migrated
6. Fish leftovers found on live system
7. Bash leftovers found on live system
8. Suspicious system services
9. Suspicious user services
10. Suspicious kernel/module/display/audio/bluetooth tweaks
11. Dotfiles repository findings
12. Omarchy-specific migration recommendations
13. Questions for the user
14. Exact safe commands to run before installing Omarchy
15. Exact restore order after Omarchy is installed

Create ~/migration-audit/OMARCHY_RESTORE_PLAN.md with:

1. Restore SSH keys.
2. Authenticate GitHub CLI.
3. Clone ~/dotfiles.
4. Apply Starship config.
5. Apply Ghostty config if present.
6. Apply minimal Bash config.
7. Do not apply Fish config.
8. Do not apply arch/ legacy config.
9. Do not overwrite Omarchy’s ~/.config/hypr, ~/.config/waybar, ~/.config/omarchy, ~/.local/share/omarchy, or Omarchy-managed files unless explicitly reviewed.
10. Preserve Omarchy defaults first.
11. Add user customizations incrementally.
12. After each change, verify login, terminal, browser, audio, Wi-Fi, Bluetooth, suspend, and update behavior.

Phase 8: Optional cleanup proposal.

Only after producing the reports, propose cleanup actions. Do not execute cleanup without approval.

For each proposed cleanup action, include:

- Path or service name
- Why it appears stale or dangerous
- Whether it is backed up
- Risk level
- Exact command that would be run
- How to rollback

Final output:
Give me a clear checklist of what I need to approve, what is safe to keep, what should be discarded, and what questions remain open before I install Omarchy 3.6.