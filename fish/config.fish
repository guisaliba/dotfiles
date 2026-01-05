# Claude Code executable for Zed integration
set -gx CLAUDE_CODE_EXECUTABLE /home/.local/bin/claude

if status is-interactive
    # Claude Code aliases
    alias cc="claude --plugin-dir ~/.claude/plugins/feature-dev --plugin-dir ~/.claude/plugins/commit-commands"
    alias cc-learn="claude --plugin-dir ~/.claude/plugins/feature-dev --plugin-dir ~/.claude/plugins/commit-commands --plugin-dir ~/.claude/plugins/learning-output-style"
    alias cc-ralph="claude --plugin-dir ~/.claude/plugins/feature-dev --plugin-dir ~/.claude/plugins/commit-commands --plugin-dir ~/.claude/plugins/ralph-wiggum"
end

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

# WSL2: auto-start cron if not running
if test -f /proc/version; and grep -qi microsoft /proc/version
    if not pgrep -x cron > /dev/null
        sudo service cron start > /dev/null 2>&1
    end
end
