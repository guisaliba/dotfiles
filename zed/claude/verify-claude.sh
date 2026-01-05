#!/usr/bin/env bash

# Verification script for Zed + Claude Code integration
# Tests that CLAUDE_CODE_EXECUTABLE is properly configured

set -e

CLAUDE_EXECUTABLE="/home/.local/bin/claude"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Zed + Claude Code Integration Verification"
echo "=========================================="
echo ""

# Test 1: Check if Claude Code binary exists
echo -n "1. Claude Code binary exists... "
if [ -f "$CLAUDE_EXECUTABLE" ] || [ -L "$CLAUDE_EXECUTABLE" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "   Claude binary not found at: $CLAUDE_EXECUTABLE"
    exit 1
fi

# Test 2: Check Fish config
echo -n "2. Fish config has CLAUDE_CODE_EXECUTABLE... "
if grep -q "CLAUDE_CODE_EXECUTABLE" "$HOME/dotfiles/fish/config.fish" 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Test 3: Check Fish function exists
echo -n "3. Fish zed function exists... "
if [ -f "$HOME/dotfiles/fish/functions/zed.fish" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Test 4: Check Bash config
echo -n "4. Bash config has CLAUDE_CODE_EXECUTABLE... "
if grep -q "CLAUDE_CODE_EXECUTABLE" "$HOME/dotfiles/bash/.bashrc" 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Test 5: Check Bash alias
echo -n "5. Bash alias for zed exists... "
if grep -q "alias zed=" "$HOME/dotfiles/bash/.bash_aliases" 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Test 6: Check desktop file
echo -n "6. Custom desktop file installed... "
if [ -f "$HOME/.local/share/applications/dev.zed.Zed.desktop" ]; then
    if grep -q "CLAUDE_CODE_EXECUTABLE" "$HOME/.local/share/applications/dev.zed.Zed.desktop"; then
        echo -e "${GREEN}✓ PASS${NC}"
    else
        echo -e "${YELLOW}⚠ WARNING${NC}"
        echo "   Desktop file exists but doesn't set CLAUDE_CODE_EXECUTABLE"
    fi
else
    echo -e "${YELLOW}⚠ WARNING${NC}"
    echo "   Desktop file not found (run setup script)"
fi

# Test 7: Check environment variable in current shell
echo -n "7. CLAUDE_CODE_EXECUTABLE set in current shell... "
if [ -n "$CLAUDE_CODE_EXECUTABLE" ]; then
    if [ "$CLAUDE_CODE_EXECUTABLE" = "$CLAUDE_EXECUTABLE" ]; then
        echo -e "${GREEN}✓ PASS${NC}"
    else
        echo -e "${YELLOW}⚠ WARNING${NC}"
        echo "   Set to: $CLAUDE_CODE_EXECUTABLE (expected: $CLAUDE_EXECUTABLE)"
    fi
else
    echo -e "${YELLOW}⚠ WARNING${NC}"
    echo "   Not set in current shell (reload your config)"
fi

# Test 8: Test Fish function (if Fish is available)
echo -n "8. Fish zed function works... "
if command -v fish &> /dev/null; then
    FISH_TEST=$(fish -c "source $HOME/dotfiles/fish/config.fish 2>/dev/null; type zed 2>&1 | head -1" 2>&1)
    if echo "$FISH_TEST" | grep -q "function"; then
        echo -e "${GREEN}✓ PASS${NC}"
    else
        echo -e "${YELLOW}⚠ WARNING${NC}"
        echo "   Fish function may not be working correctly"
    fi
else
    echo -e "${YELLOW}⊘ SKIP${NC} (Fish not installed)"
fi

# Test 9: Test Bash alias (if Bash is available)
echo -n "9. Bash zed alias works... "
if command -v bash &> /dev/null; then
    BASH_TEST=$(bash -c "source $HOME/dotfiles/bash/.bashrc 2>/dev/null; source $HOME/dotfiles/bash/.bash_aliases 2>/dev/null; alias zed 2>&1")
    if echo "$BASH_TEST" | grep -q "CLAUDE_CODE_EXECUTABLE"; then
        echo -e "${GREEN}✓ PASS${NC}"
    else
        echo -e "${YELLOW}⚠ WARNING${NC}"
        echo "   Bash alias may not be working correctly"
    fi
else
    echo -e "${YELLOW}⊘ SKIP${NC} (Bash not installed)"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "Setup appears to be complete!"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Reload your shell config:"
echo "     ${YELLOW}source ~/dotfiles/fish/config.fish${NC}  (Fish)"
echo "     ${YELLOW}source ~/.bashrc${NC}                    (Bash)"
echo ""
echo "  2. Close any running Zed instances:"
echo "     ${YELLOW}pkill zed${NC}"
echo ""
echo "  3. Launch Zed and test Claude Code:"
echo "     ${YELLOW}zed${NC}  (from terminal)"
echo "     or use your application menu"
echo ""
echo "  4. Verify in Zed:"
echo "     - Open a terminal in Zed"
echo "     - Run: ${YELLOW}echo \$CLAUDE_CODE_EXECUTABLE${NC}"
echo "     - Should show: /home/.local/bin/claude"
echo ""
