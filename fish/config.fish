fish_add_path ~/.local/bin
fish_add_path ~/bin

# cc-recall
set -gx CC_RECALL_VAULT /mnt/c/obsidian_vault # wsl2 path to vault

if status is-interactive
    starship init fish | source
end

# ═══════════════════════════════════════════════════════════════════════════════
# Claude Code: Cloud-first + Remote Control helpers
# Auto-names sessions as "purpose | folder [active|inactive]"
# Usage:
#   cc-cloud "Implement billing"   → cloud session (teleportable)
#   cc-rc                         → Remote Control session (local, web-drivable)
#   cc-tp <id>                    → teleport web session to local
# ═══════════════════════════════════════════════════════════════════════════════

# Auto-generate session name from your ~/projects/active|inactive structure
function __cc_session_name
    set folder (basename (pwd))
    set project_root (dirname (pwd))
    set status "active"

    # Detect if in ~/projects/inactive/
    if string match -q "~/projects/inactive/*" $project_root
        set status "inactive"
    end

    # Prompt for purpose, default to folder name
    echo "Session purpose for '$folder' (default: $folder [$status])?"
    read -l -P "" purpose
    if test -z "$purpose"
        set purpose $folder
    end

    echo "$purpose | $folder [$status]"
end

# 1) Start CLOUD Claude Code task (shows in web, teleportable anywhere)
function cc-cloud
    if test (count $argv) -eq 0
        echo "usage: cc-cloud \"Task description\""
        return 1
    end

    set session_name (__cc_session_name)
    echo "Starting cloud session: $session_name"
    # claude --remote creates web session; --name may not exist, use /rename inside if needed
    claude --remote --name "$session_name" "$argv"
end

# 2) Start LOCAL session with Remote Control (drive from web while local runs)
function cc-rc
    set session_name (__cc_session_name)
    echo "Starting/attaching Remote Control: $session_name"
    claude remote-control --name "$session_name"
end

# 3) Teleport existing web/cloud session into local CLI
function cc-tp
    if test (count $argv) -eq 0
        echo "usage: cc-tp <session-id-or-name>"
        return 1
    end

    echo "Teleporting session '$argv[1]' to local..."
    claude --teleport "$argv[1]"
end

# 4) Quick list/resume local sessions (bonus)
function cc-ls
    echo "Local sessions in (pwd):"
    claude --resume  # shows picker without resuming
end
# ═══════════════════════════════════════════════════════════════════════════════

# java
set -gx JAVA_HOME /usr/lib/jvm/java-21-openjdk-amd64
fish_add_path $JAVA_HOME/bin

fenv source ~/.profile

# pnpm
set -gx PNPM_HOME "/home/guisaliba/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

# cursor: override to always open in Agent Window (--glass)
# if --glass breaks on a Cursor update, remove this function and use cursor-agent instead
function cursor
    /mnt/c/Program\ Files/cursor/resources/app/bin/cursor --glass $argv
end

# opencode
fish_add_path /home/guisaliba/.opencode/bin
# bun
fish_add_path /home/guisaliba/.bun/bin
