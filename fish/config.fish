fish_add_path ~/.local/bin

if status is-interactive
    starship init fish | source

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
