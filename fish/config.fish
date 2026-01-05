if status is-interactive
    # Claude Code aliases
    set -l _cc_base "--plugin-dir ~/.claude/plugins/feature-dev --plugin-dir ~/.claude/plugins/commit-commands"

    alias cc="claude $_cc_base"
    alias cc-learn="claude $_cc_base --plugin-dir ~/.claude/plugins/learning-output-style"
    alias cc-ralph="claude $_cc_base --plugin-dir ~/.claude/plugins/ralph-wiggum"
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
