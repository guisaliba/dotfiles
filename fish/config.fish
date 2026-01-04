if status is-interactive
    # Commands to run in interactive sessions can go here
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
