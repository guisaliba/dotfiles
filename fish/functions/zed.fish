# Zed wrapper function to ensure CLAUDE_CODE_EXECUTABLE is set
# This is required because Zed's settings.json doesn't properly pass
# environment variables to the Claude Code ACP process.
# See: https://github.com/zed-industries/zed/issues/40327

function zed --description 'Launch Zed with CLAUDE_CODE_EXECUTABLE set'
    env CLAUDE_CODE_EXECUTABLE=/home/.local/bin/claude /home/.local/bin/zed $argv
end
