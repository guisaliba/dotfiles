#!/bin/bash
# AI CLI tools wrapper for scheduled activation of usage windows
# Outputs JSON for machine-readable logs with human-friendly summaries

# ============================================================================
# CONFIGURATION - Update these values for your environment
# ============================================================================

# System paths
USER_HOME="/home/guisaliba"

# Tool locations
CLAUDE_BIN="$USER_HOME/.local/bin/claude"
CODEX_BIN="$USER_HOME/.local/bin/codex"

# Timezone (see: timedatectl list-timezones)
TIMEZONE="America/Sao_Paulo"

# Health check prompt
HEALTH_CHECK_PROMPT="Respond with 'Ready' if operational"

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

export HOME="$USER_HOME"
export PATH="/usr/local/bin:$USER_HOME/.local/bin:$USER_HOME/.bun/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
export TZ="$TIMEZONE"
export CLIENT_NAME="claude-code"

# ============================================================================
# STATS STORAGE
# ============================================================================

declare -A STATS_STATUS STATS_TOKENS STATS_LATENCY STATS_COST STATS_RESPONSE

# ============================================================================
# LOGGING HELPER
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ============================================================================
# PARSING FUNCTIONS
# ============================================================================

# Parse Claude JSON response and extract stats
parse_claude() {
    local json="$1"
    local exit_code="$2"

    if [[ $exit_code -ne 0 ]]; then
        STATS_STATUS[claude]="FAIL"
        STATS_RESPONSE[claude]="Exit code: $exit_code"
        STATS_TOKENS[claude]="-"
        STATS_LATENCY[claude]="-"
        STATS_COST[claude]="-"
        return
    fi

    local result=$(echo "$json" | jq -r '.result // ""' | head -c 30 | tr '\n' ' ')
    local duration=$(echo "$json" | jq -r '.duration_ms // 0')
    local cost_raw=$(echo "$json" | jq -r '.total_cost_usd // 0')
    local cost=$(printf "%.4f" "$cost_raw")
    local tokens=$(echo "$json" | jq -r '.num_turns // 0')

    if [[ -n "$result" && "$result" != "null" ]]; then
        STATS_STATUS[claude]="OK"
        STATS_RESPONSE[claude]="$result"
    else
        STATS_STATUS[claude]="FAIL"
        STATS_RESPONSE[claude]="No result"
    fi

    STATS_TOKENS[claude]="$tokens"
    STATS_LATENCY[claude]="${duration}ms"
    STATS_COST[claude]="\$${cost}"
}

# Parse Codex JSONL response and extract stats
parse_codex() {
    local jsonl="$1"
    local exit_code="$2"

    if [[ $exit_code -ne 0 ]]; then
        STATS_STATUS[codex]="FAIL"
        STATS_RESPONSE[codex]="Exit code: $exit_code"
        STATS_TOKENS[codex]="-"
        STATS_LATENCY[codex]="-"
        STATS_COST[codex]="-"
        return
    fi

    local last_line=$(echo "$jsonl" | tail -1)
    local type=$(echo "$last_line" | jq -r '.type // "unknown"')

    if [[ "$type" == "turn.completed" ]]; then
        local tokens=$(echo "$last_line" | jq -r '.usage.input_tokens // 0')
        local response=$(echo "$jsonl" | grep '"type":"message"' | tail -1 | jq -r '.content // ""' | head -c 30 | tr '\n' ' ')
        STATS_STATUS[codex]="OK"
        STATS_RESPONSE[codex]="${response:-Ready}"
        STATS_TOKENS[codex]="$tokens"
    else
        STATS_STATUS[codex]="FAIL"
        STATS_RESPONSE[codex]="Type: $type"
        STATS_TOKENS[codex]="-"
    fi

    STATS_LATENCY[codex]="-"
    STATS_COST[codex]="free"
}

# # Parse Gemini JSON response and extract stats
# parse_gemini() {
#     local output="$1"
#     local exit_code="$2"

#     if [[ $exit_code -ne 0 ]]; then
#         STATS_STATUS[gemini]="FAIL"
#         STATS_RESPONSE[gemini]="Exit code: $exit_code"
#         STATS_TOKENS[gemini]="-"
#         STATS_LATENCY[gemini]="-"
#         STATS_COST[gemini]="-"
#         return
#     fi

#     # Extract JSON block (from first { to last }) - handles multiline JSON
#     local json=$(echo "$output" | sed -n '/^{/,/^}/p')

#     if [[ -z "$json" ]]; then
#         STATS_STATUS[gemini]="FAIL"
#         STATS_RESPONSE[gemini]="No JSON found"
#         STATS_TOKENS[gemini]="-"
#         STATS_LATENCY[gemini]="-"
#         STATS_COST[gemini]="-"
#         return
#     fi

#     local response=$(echo "$json" | jq -r '.response // ""' | head -c 30 | tr '\n' ' ')
#     local error=$(echo "$json" | jq -r '.error.message // empty')
#     local total_tokens=$(echo "$json" | jq -r '[.stats.models // {} | to_entries[] | .value.tokens.total] | add // 0')
#     local total_latency=$(echo "$json" | jq -r '[.stats.models // {} | to_entries[] | .value.api.totalLatencyMs] | add // 0')

#     if [[ -n "$error" ]]; then
#         STATS_STATUS[gemini]="FAIL"
#         STATS_RESPONSE[gemini]="$error"
#     else
#         STATS_STATUS[gemini]="OK"
#         STATS_RESPONSE[gemini]="${response:-Ready}"
#     fi

#     STATS_TOKENS[gemini]="$total_tokens"
#     STATS_LATENCY[gemini]="${total_latency}ms"
#     STATS_COST[gemini]="free"
# }

# # Parse Droid JSON response and extract stats (for Antigravity via CLIProxyAPI)
# parse_droid() {
#     local output="$1"
#     local exit_code="$2"

#     if [[ $exit_code -ne 0 ]]; then
#         STATS_STATUS[droid]="FAIL"
#         STATS_RESPONSE[droid]="Exit code: $exit_code"
#         STATS_LATENCY[droid]="-"
#         STATS_COST[droid]="-"
#         return
#     fi

#     # Strip BEL character (0x07) that droid outputs before JSON, then extract JSON object
#     local json=$(echo "$output" | tr -d '\007' | grep -o '{.*}')

#     local result=$(echo "$json" | jq -r '.result // ""' 2>/dev/null | head -c 30 | tr '\n' ' ')
#     local duration=$(echo "$json" | jq -r '.duration_ms // 0' 2>/dev/null)
#     local is_error=$(echo "$json" | jq -r '.is_error // false' 2>/dev/null)

#     if [[ "$is_error" == "true" ]]; then
#         STATS_STATUS[droid]="FAIL"
#         STATS_RESPONSE[droid]="${result:-Error}"
#     elif [[ -n "$result" && "$result" != "null" ]]; then
#         STATS_STATUS[droid]="OK"
#         STATS_RESPONSE[droid]="$result"
#     else
#         STATS_STATUS[droid]="FAIL"
#         STATS_RESPONSE[droid]="No result"
#     fi

#     STATS_LATENCY[droid]="${duration}ms"
#     STATS_COST[droid]="free"
# }

# ============================================================================
# SUMMARY TABLE
# ============================================================================

print_summary() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║          AI CLI HEALTH CHECK SUMMARY             ║"
    echo "║               $timestamp                ║"
    echo "╠══════════╦════════╦════════════════════╦═════════╣"
    echo "║ CLI      ║ STATUS ║ RESPONSE           ║ LATENCY ║"
    echo "╠══════════╬════════╬════════════════════╬═════════╣"

    # for tool in claude codex gemini droid; do
    for tool in claude codex; do
        local name=$(printf "%-8s" "${tool^}")
        local status="${STATS_STATUS[$tool]:-N/A}"
        local response="${STATS_RESPONSE[$tool]:-N/A}"
        local latency="${STATS_LATENCY[$tool]:-N/A}"

        # Format fields with fixed widths
        response=$(printf "%-18.18s" "$response")
        latency=$(printf "%7s" "$latency")

        # Status formatting (8 chars to match column width)
        if [[ "$status" == "OK" ]]; then
            status_fmt="   OK   "
        else
            status_fmt="  FAIL  "
        fi

        echo "║ $name ║$status_fmt║ $response ║ $latency ║"
    done

    echo "╚══════════╩════════╩════════════════════╩═════════╝"

    # Count successes
    local ok_count=0
    # for tool in claude codex gemini droid; do
    #     [[ "${STATS_STATUS[$tool]}" == "OK" ]] && ((ok_count++))
    # done
    for tool in claude codex; do
        [[ "${STATS_STATUS[$tool]}" == "OK" ]] && ((ok_count++))
    done

    echo ""
    if [[ $ok_count -eq 2 ]]; then
        echo "  ✓ All systems operational ($ok_count/2)"
    elif [[ $ok_count -gt 0 ]]; then
        echo "  ⚠ Partial availability ($ok_count/2 operational)"
    else
        echo "  ✗ All systems failing (0/2)"
    fi
    echo ""
}

# ============================================================================
# TOOL EXECUTION
# ============================================================================

log "Health check batch started"
echo ""

# Run Claude
log "Claude job started"
CLAUDE_OUTPUT=$("$CLAUDE_BIN" --output-format json -p "$HEALTH_CHECK_PROMPT" 2>&1)
CLAUDE_EXIT=$?
echo "$CLAUDE_OUTPUT"
parse_claude "$CLAUDE_OUTPUT" "$CLAUDE_EXIT"
log "Claude job completed (exit: $CLAUDE_EXIT)"
echo ""

# Run Codex
log "Codex job started"
CODEX_OUTPUT=$("$CODEX_BIN" exec --skip-git-repo-check --json "$HEALTH_CHECK_PROMPT" 2>&1)
CODEX_EXIT=$?
echo "$CODEX_OUTPUT"
parse_codex "$CODEX_OUTPUT" "$CODEX_EXIT"
log "Codex job completed (exit: $CODEX_EXIT)"
echo ""

# # Run Gemini
# log "Gemini job started"
# GEMINI_OUTPUT=$("$GEMINI_BIN" -p "$HEALTH_CHECK_PROMPT" --output-format json 2>&1)
# GEMINI_EXIT=$?
# # Compact JSON output for cleaner logs (strip startup noise, compact JSON, no color)
# echo "$GEMINI_OUTPUT" | sed -n '/^{/,/^}/p' | jq -Mc . 2>/dev/null || echo "$GEMINI_OUTPUT"
# parse_gemini "$GEMINI_OUTPUT" "$GEMINI_EXIT"
# log "Gemini job completed (exit: $GEMINI_EXIT)"
# echo ""

# # Run Droid (Antigravity via CLIProxyAPI)
# log "Droid job started (model: $DROID_MODEL)"
# DROID_OUTPUT=$("$DROID_BIN" exec -o json -m "$DROID_MODEL" "$HEALTH_CHECK_PROMPT")
# DROID_EXIT=$?
# echo "$DROID_OUTPUT"
# parse_droid "$DROID_OUTPUT" "$DROID_EXIT"
# log "Droid job completed (exit: $DROID_EXIT)"
# echo ""

# Print summary table
print_summary

log "Health check batch completed"
