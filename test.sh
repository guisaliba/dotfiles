#!/usr/bin/env bash
set -Eeuo pipefail

# test.sh
#
# Deterministic fixture suite for the root dotfiles installer.
# It uses temporary HOME and repository fixtures only. It never modifies a
# real home directory and never contacts GitHub. Use --repo-only to make the
# intent explicit; every check in this file is already hermetic.

if [[ $# -gt 0 ]]; then
  if [[ $# -eq 1 && "$1" == "--repo-only" ]]; then
    :
  else
    printf 'Usage: %s [--repo-only]\n' "$0" >&2
    exit 2
  fi
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
INSTALLER="$REPO_DIR/install.sh"
HELPER="$REPO_DIR/lib/dotfiles_installer.py"
ALIASES_BLOCK_START="# >>> dotfiles aliases >>>"
ALIASES_BLOCK_END="# <<< dotfiles aliases <<<"
OPENCODE_BLOCK_START="# >>> dotfiles OpenCode ai-memory wrapper >>>"
OPENCODE_BLOCK_END="# <<< dotfiles OpenCode ai-memory wrapper <<<"

failures=0

ok() {
  printf 'ok: %s\n' "$*"
}

not_ok() {
  printf 'not ok: %s\n' "$*" >&2
  failures=$((failures + 1))
}

FIXTURE_ROOT=""
FIXTURE_HOME=""
FIXTURE_PROC=""
FIXTURE_ETC=""
EXTRA_ENV=()
INVOKE_RC=0
AGENT_SOURCE=""
AGENT_REMOTE=""
AGENT_CHECKOUT=""
AGENT_LOG=""
CODE_LOG=""
OMARCHY_LOG=""

new_fixture() {
  if [[ -n "$FIXTURE_ROOT" && -d "$FIXTURE_ROOT" ]]; then
    rm -rf -- "$FIXTURE_ROOT"
  fi
  FIXTURE_ROOT="$(mktemp -d)"
  FIXTURE_HOME="$FIXTURE_ROOT/home"
  mkdir -p "$FIXTURE_HOME"
  FIXTURE_PROC="$FIXTURE_ROOT/proc"
  FIXTURE_ETC="$FIXTURE_ROOT/etc"
  mkdir -p "$FIXTURE_PROC/sys/kernel" "$FIXTURE_ETC"
  printf '%s\n' 'NAME=Linux' 'ID=debian' >"$FIXTURE_ETC/os-release"
  : >"$FIXTURE_PROC/version"
  : >"$FIXTURE_PROC/sys/kernel/osrelease"
  EXTRA_ENV=()
  INVOKE_RC=0
}

cleanup() {
  rm -rf -- "$FIXTURE_ROOT"
}
trap cleanup EXIT

invoke() {
  local stdin_text="$1" expected_rc="$2"
  shift 2
  local stdin_file="$FIXTURE_ROOT/stdin"
  printf '%b' "$stdin_text" >"$stdin_file"
  set +e
  env \
    HOME="$FIXTURE_HOME" \
    DOTFILES_TEST_MODE=1 \
    DOTFILES_PROC_DIR="$FIXTURE_PROC" \
    DOTFILES_ETC_DIR="$FIXTURE_ETC" \
    "${EXTRA_ENV[@]}" \
    bash "$INSTALLER" "$@" <"$stdin_file" \
    >"$FIXTURE_ROOT/out" 2>"$FIXTURE_ROOT/err"
  INVOKE_RC=$?
  set -e
  if [[ "$INVOKE_RC" != "$expected_rc" ]]; then
    not_ok "expected exit $expected_rc, got $INVOKE_RC: install.sh $*"
    printf '  stdout:\n' >&2
    sed 's/^/    /' "$FIXTURE_ROOT/out" >&2 || true
    printf '  stderr:\n' >&2
    sed 's/^/    /' "$FIXTURE_ROOT/err" >&2 || true
  fi
}

out_contains() {
  if grep -qF -- "$1" "$FIXTURE_ROOT/out"; then
    ok "stdout contains: $1"
  else
    not_ok "stdout missing: $1"
  fi
}

err_contains() {
  if grep -qF -- "$1" "$FIXTURE_ROOT/err"; then
    ok "stderr contains: $1"
  else
    not_ok "stderr missing: $1"
  fi
}

out_not_contains() {
  if grep -qF -- "$1" "$FIXTURE_ROOT/out"; then
    not_ok "stdout unexpectedly contains: $1"
  else
    ok "stdout lacks: $1"
  fi
}

file_exists() {
  [[ -f "$1" ]] && ok "file exists: $1" || not_ok "missing file: $1"
}

file_absent() {
  [[ ! -e "$1" ]] && ok "path absent: $1" || not_ok "unexpected path: $1"
}

file_empty() {
  [[ -f "$1" && ! -s "$1" ]] && ok "file empty: $1" || not_ok "file missing or not empty: $1"
}

file_contains() {
  if grep -qF -- "$2" "$1"; then
    ok "contains '$2': $1"
  else
    not_ok "missing '$2': $1"
  fi
}

file_not_contains() {
  if grep -qF -- "$2" "$1"; then
    not_ok "unexpected '$2': $1"
  else
    ok "lacks '$2': $1"
  fi
}

same_file() {
  if cmp -s "$1" "$2"; then
    ok "files match: $2"
  else
    not_ok "files differ: $1 != $2"
  fi
}

file_mode() {
  local actual
  actual="$(stat -c %a "$1" 2>/dev/null || true)"
  if [[ "$actual" == "$2" ]]; then
    ok "file mode $2: $1"
  else
    not_ok "file mode mismatch on $1 (expected $2, got $actual)"
  fi
}

require_file() {
  [[ -f "$1" ]] && ok "file exists: $1" || not_ok "missing file: $1"
}

require_dir() {
  [[ -d "$1" ]] && ok "dir exists: $1" || not_ok "missing dir: $1"
}

require_executable() {
  [[ -x "$1" ]] && ok "executable: $1" || not_ok "not executable: $1"
}

require_text_count() {
  local path="$1" needle="$2" expected="$3"
  local count
  count="$(grep -cF -- "$needle" "$path" 2>/dev/null || true)"
  if [[ "$count" == "$expected" ]]; then
    ok "text count $needle == $expected in $path"
  else
    not_ok "text count mismatch: $needle in $path (expected $expected, got $count)"
  fi
}

count_occ() {
  local path="$1" needle="$2"
  grep -c -- "$needle" "$path" 2>/dev/null || echo 0
}

host_wsl2() {
  printf '%s\n' '6.6.36.1-microsoft-standard-WSL2' >"$FIXTURE_PROC/sys/kernel/osrelease"
  printf '%s\n' 'Linux version 6.6.36.1-microsoft-standard-WSL2' >"$FIXTURE_PROC/version"
}

host_omarchy() {
  printf '%s\n' 'NAME=Omarchy' 'ID=omarchy' >"$FIXTURE_ETC/os-release"
  : >"$FIXTURE_PROC/version"
  : >"$FIXTURE_PROC/sys/kernel/osrelease"
}

make_code_stub() {
  local bindir="$FIXTURE_ROOT/bin"
  mkdir -p "$bindir"
  cat >"$bindir/code" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$DOTFILES_FIXTURE_CODE_LOG"
EOF
  chmod +x "$bindir/code"
  EXTRA_ENV+=(
    "PATH=$bindir:$PATH"
    "DOTFILES_FIXTURE_CODE_LOG=$FIXTURE_ROOT/code.log"
  )
  CODE_LOG="$FIXTURE_ROOT/code.log"
  : >"$CODE_LOG"
}

restrict_path() {
  local excluded="$1"
  local bindir="$FIXTURE_ROOT/stub-bin"
  local tool
  mkdir -p "$bindir"
  for tool in bash python3 cat grep awk cut dirname; do
    ln -sf "/usr/bin/$tool" "$bindir/$tool"
  done
  IFS=',' read -r -a excluded_tools <<<"$excluded"
  for tool in "${excluded_tools[@]}"; do
    rm -f "$bindir/$tool"
  done
  EXTRA_ENV+=("PATH=$bindir")
}

make_agents_repo() {
  local source="$FIXTURE_ROOT/agents-source"
  AGENT_SOURCE="$source"
  AGENT_REMOTE="$FIXTURE_ROOT/agents.git"
  AGENT_CHECKOUT="$FIXTURE_ROOT/managed/agents-checkout"
  AGENT_LOG="$FIXTURE_ROOT/agents.log"
  git init "$source" >/dev/null
  git -C "$source" branch -M main
  git -C "$source" config user.email fixture@example.invalid
  git -C "$source" config user.name fixture
  cat >"$source/apply.sh" <<'EOF'
#!/usr/bin/env bash
printf 'apply ran\n' >>"$DOTFILES_FIXTURE_AGENTS_LOG"
EOF
  cat >"$source/test.sh" <<'EOF'
#!/usr/bin/env bash
printf 'test ran\n' >>"$DOTFILES_FIXTURE_AGENTS_LOG"
EOF
  chmod +x "$source/apply.sh" "$source/test.sh"
  git -C "$source" add apply.sh test.sh
  git -C "$source" commit -m fixture >/dev/null
  git init --bare "$AGENT_REMOTE" >/dev/null
  git -C "$source" remote add origin "$AGENT_REMOTE"
  git -C "$source" push -u origin main >/dev/null
  EXTRA_ENV+=(
    "DOTFILES_AGENTS_URL=$AGENT_REMOTE"
    "DOTFILES_AGENTS_REMOTE=$AGENT_REMOTE"
    "DOTFILES_AGENTS_CHECKOUT=$AGENT_CHECKOUT"
    "DOTFILES_FIXTURE_AGENTS_LOG=$AGENT_LOG"
  )
  : >"$AGENT_LOG"
}

clone_agent_checkout() {
  mkdir -p "$(dirname -- "$AGENT_CHECKOUT")"
  git clone --quiet --branch main "$AGENT_REMOTE" "$AGENT_CHECKOUT"
}

agents_repo_push_fail_apply() {
  printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"$AGENT_SOURCE/apply.sh"
  chmod +x "$AGENT_SOURCE/apply.sh"
  git -C "$AGENT_SOURCE" add apply.sh
  git -C "$AGENT_SOURCE" commit -m fail-apply >/dev/null
  git -C "$AGENT_SOURCE" push origin main >/dev/null
}

agents_repo_push_fail_test() {
  printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"$AGENT_SOURCE/test.sh"
  chmod +x "$AGENT_SOURCE/test.sh"
  git -C "$AGENT_SOURCE" add test.sh
  git -C "$AGENT_SOURCE" commit -m fail-test >/dev/null
  git -C "$AGENT_SOURCE" push origin main >/dev/null
}

# --- Repo structure ---

printf '\n--- Repo Structure ---\n'

require_file "$REPO_DIR/install.sh"
require_file "$REPO_DIR/components.tsv"
require_file "$REPO_DIR/lib/dotfiles_installer.py"
require_file "$REPO_DIR/test.sh"
require_file "$REPO_DIR/.github/workflows/test.yml"
require_file "$REPO_DIR/bash/aliases.bash"
require_file "$REPO_DIR/vscode/extensions.tsv"
require_executable "$REPO_DIR/install.sh"
require_executable "$REPO_DIR/test.sh"
require_executable "$REPO_DIR/omarchy/mx-mini-recover.sh"
require_file "$REPO_DIR/omarchy/display-plugin/Panel.qml"
require_file "$REPO_DIR/omarchy/display-plugin/Model.js"
require_file "$REPO_DIR/omarchy/display-plugin/layout.py"
require_file "$REPO_DIR/omarchy/install-display.py"
if python3 "$HELPER" manifest "$REPO_DIR/components.tsv" >/dev/null 2>&1; then
  ok "components manifest is valid"
else
  not_ok "components manifest is invalid"
fi
require_text_count "$REPO_DIR/bash/aliases.bash" "$ALIASES_BLOCK_START" "1"
require_text_count "$REPO_DIR/bash/aliases.bash" "$ALIASES_BLOCK_END" "1"
require_text_count "$REPO_DIR/bash/aliases.bash" "$OPENCODE_BLOCK_START" "0"
if [[ -s "$REPO_DIR/vscode/extensions.tsv" ]]; then
  ok "extensions.tsv is non-empty"
else
  not_ok "extensions.tsv is empty"
fi

# --- CLI validation ---

printf '\n--- CLI Validation ---\n'

test_cli_validation() {
  new_fixture
  invoke '' 2 --bogus
  err_contains 'unknown option'
  invoke '' 2 --components bash --components git
  err_contains 'duplicate option'
  invoke '' 2 --check --check
  err_contains 'duplicate option'
  invoke '' 2 --yes --yes --components bash
  err_contains 'duplicate option'
  invoke '' 2 --components ''
  err_contains 'requires a comma-separated list'
  invoke '' 2 --host bogus
  err_contains 'invalid host'
  invoke '' 2 --host ''
  err_contains 'requires a value'
  invoke '' 2 --components bogus
  err_contains 'unknown component'
  invoke '' 2 --components bashrc
  err_contains 'unknown component'
  invoke '' 2 --yes
  err_contains 'valid only with --components'
  invoke '' 2 --vscode-extensions all
  err_contains 'valid only with --components'
  invoke '' 2 --vscode-extensions '' --components bash
  err_contains 'requires a value'
  invoke '' 2 --components bash --vscode-extensions all
  err_contains 'requires vscode'
  invoke '' 2 --components vscode --vscode-extensions bogus.extension
  err_contains 'unknown VS Code extension'
  invoke '' 2 --components vscode --yes
  err_contains 'is required with --yes'
  invoke '' 2 --components omarchy-power
  err_contains 'unknown component'
  invoke '' 2 --components bash,bash
  err_contains 'duplicate component'
  invoke '' 2 positional
  err_contains 'unexpected argument'
  invoke '' 0 --help
  out_contains 'Usage: install.sh'
}

test_cli_validation

# --- Host detection ---

printf '\n--- Host Detection ---\n'

test_host_detection() {
  new_fixture
  invoke '' 0 --check --components bash
  out_contains 'Detected host: linux'
  host_wsl2
  invoke '' 0 --check --components bash
  out_contains 'Detected host: wsl2'
  host_omarchy
  invoke '' 0 --check --components bash
  out_contains 'Detected host: omarchy'

  new_fixture
  invoke '' 0 --check --host wsl2 --components bash
  out_contains 'Detected host: wsl2'

  new_fixture
  invoke 'a\n\n' 0 --check
  out_contains 'Detected host: linux'
  out_contains 'Selected components: bash,git,wallpapers,starship,vscode,zed,agents'
  out_contains 'Component: agents'
  out_not_contains 'omarchy-power'
}

test_host_detection

# --- Guided flows ---

printf '\n--- Guided Flows ---\n'

test_guided_flows() {
  new_fixture
  invoke '\n' 0
  file_exists "$FIXTURE_HOME/.bash_aliases"
  file_contains "$FIXTURE_HOME/.bash_aliases" "$ALIASES_BLOCK_START"
  file_contains "$FIXTURE_HOME/.bash_aliases" "alias py='python3'"
  file_exists "$FIXTURE_HOME/.gitconfig"
  require_dir "$FIXTURE_HOME/Pictures/wallpapers"
  file_absent "$FIXTURE_HOME/.config/starship.toml"
  file_absent "$FIXTURE_HOME/.config/zed/settings.json"
  file_absent "$FIXTURE_HOME/.local/share/dotfiles/agents"
  out_contains 'Completed: bash,git,wallpapers'

  new_fixture
  invoke 'q\n' 0
  file_absent "$FIXTURE_HOME/.bash_aliases"
  file_absent "$FIXTURE_HOME/.gitconfig"

  new_fixture
  invoke 'n\n' 0
  file_absent "$FIXTURE_HOME/.bash_aliases"
  file_absent "$FIXTURE_HOME/.gitconfig"

  new_fixture
  invoke '1\n' 0
  file_absent "$FIXTURE_HOME/.bash_aliases"
  file_exists "$FIXTURE_HOME/.gitconfig"
  require_dir "$FIXTURE_HOME/Pictures/wallpapers"
  out_contains 'Completed: git,wallpapers'
}

test_guided_flows

# --- Automation and --yes ---

printf '\n--- Automation ---\n'

test_automation() {
  new_fixture
  invoke '' 0 --components bash,git --yes
  file_exists "$FIXTURE_HOME/.bash_aliases"
  file_exists "$FIXTURE_HOME/.gitconfig"
  out_contains 'Completed: bash,git'

  new_fixture
  invoke 'n\n' 0 --components bash,git
  file_absent "$FIXTURE_HOME/.bash_aliases"
  out_contains 'Aborted. No changes made.'

  new_fixture
  invoke 'y\n' 0 --components bash,git
  file_exists "$FIXTURE_HOME/.bash_aliases"
}

test_automation

# --- VS Code extensions ---

printf '\n--- VS Code Extensions ---\n'

test_vscode_extensions() {
  local total original_installer fixture_repo
  total="$(grep -cv '^#' "$REPO_DIR/vscode/extensions.tsv" || true)"

  new_fixture
  original_installer="$INSTALLER"
  fixture_repo="$FIXTURE_ROOT/repo"
  mkdir -p "$fixture_repo/lib" "$fixture_repo/bash" "$fixture_repo/vscode"
  cp "$REPO_DIR/install.sh" "$REPO_DIR/components.tsv" "$fixture_repo/"
  cp "$REPO_DIR/lib/dotfiles_installer.py" "$fixture_repo/lib/"
  cp "$REPO_DIR/bash/aliases.bash" "$fixture_repo/bash/"
  printf '%s\n' 'malformed' >"$fixture_repo/vscode/extensions.tsv"
  INSTALLER="$fixture_repo/install.sh"
  invoke '' 1 --check --components bash
  err_contains 'invalid tracked VS Code extension ID'

  printf '%s\n' 'bierner.markdown-mermaid' 'bierner.markdown-mermaid' >"$fixture_repo/vscode/extensions.tsv"
  invoke '' 1 --check --components bash
  err_contains 'duplicate tracked VS Code extension ID'
  INSTALLER="$original_installer"

  new_fixture
  make_code_stub
  invoke '' 0 --components vscode --vscode-extensions none --yes
  file_exists "$FIXTURE_HOME/.config/Code/User/settings.json"
  file_empty "$CODE_LOG"

  new_fixture
  make_code_stub
  invoke '' 0 --components vscode --vscode-extensions all --yes
  file_exists "$FIXTURE_HOME/.config/Code/User/settings.json"
  if [[ "$(count_occ "$CODE_LOG" '^--install-extension ')" == "$total" ]]; then
    ok "all $total extensions installed"
  else
    not_ok "expected $total extension installs"
  fi
  out_contains 'code --install-extension bierner.markdown-mermaid'

  new_fixture
  make_code_stub
  invoke '' 0 --components vscode --vscode-extensions bierner.markdown-mermaid,prisma.prisma --yes
  file_contains "$CODE_LOG" '--install-extension bierner.markdown-mermaid'
  file_contains "$CODE_LOG" '--install-extension prisma.prisma'
  if [[ "$(count_occ "$CODE_LOG" '^--install-extension ')" == "2" ]]; then
    ok "exactly 2 extensions installed"
  else
    not_ok "expected exactly 2 extension installs"
  fi

  new_fixture
  restrict_path code
  invoke '' 1 --components vscode --vscode-extensions all --yes
  file_exists "$FIXTURE_HOME/.config/Code/User/settings.json"
  err_contains 'code command not found'
  out_contains 'Failed: vscode'

  new_fixture
  restrict_path code
  invoke '' 0 --check --components vscode --vscode-extensions all --yes
  out_contains 'missing prerequisite: code command is missing'
}

test_vscode_extensions

# --- Check mode no writes ---

printf '\n--- Check Mode ---\n'

test_check_no_writes() {
  new_fixture
  invoke '' 0 --check --components bash,git,wallpapers,starship,vscode,zed
  file_absent "$FIXTURE_HOME/.bash_aliases"
  file_absent "$FIXTURE_HOME/.gitconfig"
  file_absent "$FIXTURE_HOME/.config/starship.toml"
  file_absent "$FIXTURE_HOME/.config/zed/settings.json"
  file_absent "$FIXTURE_HOME/.config/Code/User/settings.json"
  file_absent "$FIXTURE_HOME/.local"
  out_contains 'Check completed. No changes were made.'
  out_contains 'Detected host: linux'
  out_contains 'required backup:'

  new_fixture
  make_agents_repo
  invoke '' 0 --check --components agents
  out_contains 'clone would occur'
  file_absent "$AGENT_CHECKOUT"
}

test_check_no_writes

# --- File operations and backups ---

printf '\n--- File Operations and Backups ---\n'

test_file_operations() {
  local first_run run_dir manifest backup_file

  new_fixture
  invoke '' 0 --components git --yes
  same_file "$REPO_DIR/git/.gitconfig" "$FIXTURE_HOME/.gitconfig"
  file_mode "$FIXTURE_HOME/.gitconfig" "644"
  first_run="$(ls "$FIXTURE_HOME/.local/state/dotfiles/backups" | head -1)"
  if [[ "$first_run" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
    ok "backup run id format: $first_run"
  else
    not_ok "backup run id format: $first_run"
  fi
  require_dir "$FIXTURE_HOME/.local/state/dotfiles/backups/$first_run"

  invoke '' 0 --components git --yes
  if [[ "$(ls "$FIXTURE_HOME/.local/state/dotfiles/backups" | wc -l)" -eq 1 ]]; then
    ok "second run is idempotent and creates no new backup"
  else
    not_ok "second run created a new backup"
  fi

  new_fixture
  printf '%s\n' 'stale gitconfig' >"$FIXTURE_HOME/.gitconfig"
  invoke '' 0 --components git --yes
  same_file "$REPO_DIR/git/.gitconfig" "$FIXTURE_HOME/.gitconfig"
  run_dir="$(ls "$FIXTURE_HOME/.local/state/dotfiles/backups" | head -1)"
  manifest="$FIXTURE_HOME/.local/state/dotfiles/backups/$run_dir/MANIFEST.tsv"
  file_exists "$manifest"
  if [[ "$(awk -F'\t' '$3=="git" && $4=="copy-file"' "$manifest" | wc -l)" -eq 1 ]]; then
    ok "manifest records the git copy-file backup"
  else
    not_ok "manifest misses the git copy-file backup"
  fi
  backup_file="$(awk -F'\t' '$3=="git" && $4=="copy-file" {print $2}' "$manifest" | head -1)"
  file_contains "$backup_file" "stale gitconfig"

  if compgen -G "$FIXTURE_HOME/.dotfiles-*" >/dev/null 2>&1; then
    not_ok "temporary file left in home"
  else
    ok "no temporary files left in home"
  fi

  printf '#!/usr/bin/env bash\ntrue\n' >"$FIXTURE_ROOT/tool"
  chmod 755 "$FIXTURE_ROOT/tool"
  if env HOME="$FIXTURE_HOME" python3 "$HELPER" copy-file "$FIXTURE_ROOT/tool" "~/bin/tool" >/dev/null 2>&1; then
    file_mode "$FIXTURE_HOME/bin/tool" "755"
  else
    not_ok "helper copy-file failed for mode-preservation fixture"
  fi
}

test_file_operations

# --- Tree operations ---

printf '\n--- Tree Operations ---\n'

test_tree_operations() {
  local target run_dir backup_file

  new_fixture
  target="$FIXTURE_HOME/Pictures/wallpapers"
  invoke '' 0 --components wallpapers --yes
  require_dir "$target"
  require_dir "$target/art"
  require_dir "$target/manga"
  require_dir "$target/unix"
  file_absent "$target/README.md"
  if diff -r --exclude=README.md "$REPO_DIR/wallpapers" "$target" >/dev/null 2>&1; then
    ok "wallpaper tree matches source excluding README.md"
  else
    not_ok "wallpaper tree differs from source"
  fi

  invoke '' 0 --components wallpapers --yes
  if [[ "$(ls "$FIXTURE_HOME/.local/state/dotfiles/backups" | wc -l)" -eq 1 ]]; then
    ok "tree second run is idempotent"
  else
    not_ok "tree changed on the second run"
  fi

  new_fixture
  target="$FIXTURE_HOME/Pictures/wallpapers"
  mkdir -p "$target/custom"
  printf '%s\n' 'old' >"$target/custom/old.txt"
  invoke '' 0 --components wallpapers --yes
  run_dir="$(ls "$FIXTURE_HOME/.local/state/dotfiles/backups" | head -1)"
  backup_file="$FIXTURE_HOME/.local/state/dotfiles/backups/$run_dir/${FIXTURE_HOME#/}/Pictures/wallpapers/custom/old.txt"
  file_contains "$backup_file" "old"
  file_absent "$target/custom"
}

test_tree_operations

# --- Bash merge ---

printf '\n--- Bash Merge ---\n'

test_bash_merge() {
  new_fixture
  invoke '' 0 --components bash --yes
  file_contains "$FIXTURE_HOME/.bash_aliases" "$ALIASES_BLOCK_START"
  file_contains "$FIXTURE_HOME/.bash_aliases" "$ALIASES_BLOCK_END"
  file_contains "$FIXTURE_HOME/.bash_aliases" "alias py='python3'"
  file_contains "$FIXTURE_HOME/.bash_aliases" "alias alert="
  file_not_contains "$FIXTURE_HOME/.bash_aliases" "$OPENCODE_BLOCK_START"
  require_text_count "$FIXTURE_HOME/.bash_aliases" "$ALIASES_BLOCK_START" "1"
  require_text_count "$FIXTURE_HOME/.bash_aliases" "$ALIASES_BLOCK_END" "1"

  new_fixture
  cat >"$FIXTURE_HOME/.bash_aliases" <<EOF
alias user-alias='printf user'
$OPENCODE_BLOCK_START
opencode() { command ai-memory run opencode "\$@"; }
$OPENCODE_BLOCK_END
$ALIASES_BLOCK_START
alias py='python2-stale'
$ALIASES_BLOCK_END
alias trailing='printf trailing'
EOF
  invoke '' 0 --components bash --yes
  file_contains "$FIXTURE_HOME/.bash_aliases" "alias user-alias='printf user'"
  file_contains "$FIXTURE_HOME/.bash_aliases" "alias trailing='printf trailing'"
  file_contains "$FIXTURE_HOME/.bash_aliases" "alias py='python3'"
  require_text_count "$FIXTURE_HOME/.bash_aliases" "$ALIASES_BLOCK_START" "1"
  require_text_count "$FIXTURE_HOME/.bash_aliases" "$OPENCODE_BLOCK_START" "1"
  awk "/$OPENCODE_BLOCK_START/,/$OPENCODE_BLOCK_END/" "$FIXTURE_HOME/.bash_aliases" \
    >"$FIXTURE_ROOT/after-opencode"
  printf '%s\n' \
    "$OPENCODE_BLOCK_START" \
    'opencode() { command ai-memory run opencode "$@"; }' \
    "$OPENCODE_BLOCK_END" >"$FIXTURE_ROOT/expected-opencode"
  same_file "$FIXTURE_ROOT/expected-opencode" "$FIXTURE_ROOT/after-opencode"

  cp "$FIXTURE_HOME/.bash_aliases" "$FIXTURE_ROOT/after-first"
  invoke '' 0 --components bash --yes
  same_file "$FIXTURE_ROOT/after-first" "$FIXTURE_HOME/.bash_aliases"

  new_fixture
  printf '%s\n' "alias keep='printf keep'" "$ALIASES_BLOCK_START" >"$FIXTURE_HOME/.bash_aliases"
  invoke '' 1 --components bash --yes
  file_contains "$FIXTURE_HOME/.bash_aliases" "alias keep='printf keep'"
  err_contains 'balanced managed block'

  new_fixture
  printf '%s\n' 'elsewhere' >"$FIXTURE_ROOT/elsewhere"
  ln -s "$FIXTURE_ROOT/elsewhere" "$FIXTURE_HOME/.bash_aliases"
  invoke '' 1 --components bash --yes
  err_contains 'must not be a symlink'
  file_contains "$FIXTURE_ROOT/elsewhere" "elsewhere"
}

test_bash_merge

# --- Editors ---

printf '\n--- Editors ---\n'

test_editors() {
  new_fixture
  file_not_contains "$REPO_DIR/zed/.config/settings.json" "wsl_connections"
  invoke '' 0 --components zed --yes
  file_exists "$FIXTURE_HOME/.config/zed/settings.json"
  file_exists "$FIXTURE_HOME/.config/zed/keymap.json"
  file_not_contains "$FIXTURE_HOME/.config/zed/settings.json" "wsl_connections"

  new_fixture
  mkdir -p "$FIXTURE_HOME/.config/zed"
  printf '%s\n' '{"stale":true}' >"$FIXTURE_HOME/.config/zed/settings.json"
  printf '%s\n' 'outside' >"$FIXTURE_ROOT/outside-keymap"
  ln -s "$FIXTURE_ROOT/outside-keymap" "$FIXTURE_HOME/.config/zed/keymap.json"
  invoke '' 1 --components zed --yes
  file_contains "$FIXTURE_HOME/.config/zed/settings.json" '"stale":true'
  file_contains "$FIXTURE_ROOT/outside-keymap" 'outside'
}

test_editors

# --- WSL2 bashrc ---

printf '\n--- WSL2 ---\n'

test_wsl2_bashrc() {
  new_fixture
  host_wsl2
  invoke '' 0 --components bash --yes
  file_exists "$FIXTURE_HOME/.bashrc"
  file_contains "$FIXTURE_HOME/.bashrc" 'export PATH="$HOME/.opencode/bin:$PATH"'
  file_not_contains "$FIXTURE_HOME/.bashrc" '/home/guisaliba/.opencode/bin'
  file_exists "$FIXTURE_HOME/.bash_aliases"
  out_contains 'Completed: bash,bashrc'
}

test_wsl2_bashrc

# --- Starship without binary ---

printf '\n--- Starship ---\n'

test_starship_missing_binary() {
  new_fixture
  restrict_path starship
  invoke '' 0 --components starship --yes
  file_exists "$FIXTURE_HOME/.config/starship.toml"
  err_contains 'starship command is missing'
}

test_starship_missing_binary

# --- Agents component ---

printf '\n--- Agents Component ---\n'

test_agents_clone_and_update() {
  new_fixture
  make_agents_repo
  invoke 'y\n' 0 --components agents --yes
  require_dir "$AGENT_CHECKOUT"
  file_exists "$AGENT_CHECKOUT/apply.sh"
  file_exists "$AGENT_CHECKOUT/test.sh"
  file_contains "$AGENT_LOG" "apply ran"
  file_contains "$AGENT_LOG" "test ran"

  : >"$AGENT_LOG"
  invoke 'y\n' 0 --components agents --yes
  file_contains "$AGENT_LOG" "apply ran"
  file_contains "$AGENT_LOG" "test ran"

  : >"$AGENT_LOG"
  invoke 'n\n' 0 --components agents --yes
  file_empty "$AGENT_LOG"
  out_contains 'Skipped'

  new_fixture
  make_agents_repo
  clone_agent_checkout
  printf '%s\n' 'new line' >"$AGENT_SOURCE/new.txt"
  git -C "$AGENT_SOURCE" add new.txt
  git -C "$AGENT_SOURCE" commit -m update >/dev/null
  git -C "$AGENT_SOURCE" push origin main >/dev/null
  : >"$AGENT_LOG"
  invoke 'y\n' 0 --components agents --yes
  file_contains "$AGENT_CHECKOUT/new.txt" "new line"
  file_contains "$AGENT_LOG" "apply ran"
}

test_agents_clone_and_update

test_agents_refusals_and_failures() {
  local sha

  new_fixture
  make_agents_repo
  clone_agent_checkout
  git init --bare "$FIXTURE_ROOT/other.git" >/dev/null
  git -C "$AGENT_CHECKOUT" remote set-url origin "$FIXTURE_ROOT/other.git"
  invoke 'y\n' 1 --components agents --yes
  err_contains 'does not match'

  new_fixture
  make_agents_repo
  clone_agent_checkout
  printf '%s\n' 'dirty' >>"$AGENT_CHECKOUT/apply.sh"
  invoke 'y\n' 1 --components agents --yes
  err_contains 'uncommitted changes'

  new_fixture
  make_agents_repo
  clone_agent_checkout
  git -C "$AGENT_CHECKOUT" checkout -b dev >/dev/null
  invoke 'y\n' 1 --components agents --yes
  err_contains 'must use branch main'

  new_fixture
  make_agents_repo
  clone_agent_checkout
  sha="$(git -C "$AGENT_CHECKOUT" rev-parse HEAD)"
  git -C "$AGENT_CHECKOUT" checkout --detach "$sha" >/dev/null
  invoke 'y\n' 1 --components agents --yes
  err_contains 'detached'

  new_fixture
  make_agents_repo
  clone_agent_checkout
  printf '%s\n' 'remote' >"$AGENT_SOURCE/remote.txt"
  git -C "$AGENT_SOURCE" add remote.txt
  git -C "$AGENT_SOURCE" commit -m remote >/dev/null
  git -C "$AGENT_SOURCE" push origin main >/dev/null
  git -C "$AGENT_CHECKOUT" config user.email fixture@example.invalid
  git -C "$AGENT_CHECKOUT" config user.name fixture
  printf '%s\n' 'local' >"$AGENT_CHECKOUT/local.txt"
  git -C "$AGENT_CHECKOUT" add local.txt
  git -C "$AGENT_CHECKOUT" commit -m local >/dev/null
  invoke 'y\n' 1 --components agents --yes
  err_contains 'diverged'

  new_fixture
  make_agents_repo
  agents_repo_push_fail_apply
  invoke 'y\n' 1 --components bash,agents --yes
  file_exists "$FIXTURE_HOME/.bash_aliases"
  out_contains 'Completed: bash'
  out_contains 'Failed: agents'
  err_contains 'agents apply.sh failed'

  new_fixture
  make_agents_repo
  agents_repo_push_fail_test
  invoke 'y\n' 1 --components agents --yes
  err_contains 'agents test.sh failed'
}

test_agents_refusals_and_failures

# --- Display enhancement installer ---

printf '\n--- Omarchy Display ---\n'

test_display_component() {
  new_fixture
  host_omarchy
  local native="$FIXTURE_ROOT/native-display"
  local target="$FIXTURE_HOME/.config/omarchy/plugins/guisaliba.monitor"
  local config="$FIXTURE_HOME/.config/omarchy/shell.json"
  mkdir -p "$native" "$(dirname "$config")"
  printf 'panel fixture\n' >"$native/Panel.qml"
  printf 'model fixture\n' >"$native/Model.js"
  printf 'manifest fixture\n' >"$native/manifest.json"
  ( cd "$native" && sha256sum Panel.qml Model.js manifest.json ) >"$FIXTURE_ROOT/upstream.sha256"
  printf '{"bar":{"layout":{"left":[],"center":[],"right":[{"id":"omarchy.monitor","keep":true}]}},"plugins":[],"other":42}\n' >"$config"
  EXTRA_ENV+=("DOTFILES_DISPLAY_NATIVE_DIR=$native" "DOTFILES_DISPLAY_SIGNATURES=$FIXTURE_ROOT/upstream.sha256")

  invoke '' 0 --check --host omarchy --components omarchy-display
  out_contains 'no writes'
  file_absent "$target"
  file_not_contains "$config" 'guisaliba.monitor'

  invoke '' 0 --host omarchy --components omarchy-display --yes
  file_exists "$target/Panel.qml"
  file_exists "$target/.dotfiles-display-receipt.json"
  file_contains "$config" 'guisaliba.monitor'
  file_contains "$config" '"keep": true'
  file_contains "$config" '"other": 42'
  invoke '' 0 --host omarchy --components omarchy-display --yes
  out_contains 'already installed'

  printf 'local edit\n' >>"$target/Panel.qml"
  invoke '' 1 --host omarchy --components omarchy-display --yes
  err_contains 'local changes'
  file_contains "$target/Panel.qml" 'local edit'

  printf 'upstream changed\n' >>"$native/Panel.qml"
  invoke '' 1 --check --host omarchy --components omarchy-display
  err_contains 'native Display contract differs'
  file_contains "$config" 'guisaliba.monitor'
  invoke '' 1 --host omarchy --components omarchy-display --yes
  err_contains 'Native Display restored'
  file_contains "$config" 'omarchy.monitor'
  file_not_contains "$config" 'guisaliba.monitor'

  new_fixture
  host_omarchy
  mkdir -p "$FIXTURE_HOME/.config/omarchy/plugins/guisaliba.monitor" "$FIXTURE_HOME/.config/omarchy"
  printf 'unmanaged\n' >"$FIXTURE_HOME/.config/omarchy/plugins/guisaliba.monitor/manifest.json"
  printf '{"bar":{"layout":{"right":[{"id":"omarchy.monitor"}]}}}\n' >"$FIXTURE_HOME/.config/omarchy/shell.json"
  # A matching fake native contract isolates the unmanaged-target gate.
  native="$FIXTURE_ROOT/native-display"
  mkdir -p "$native"
  printf 'panel fixture\n' >"$native/Panel.qml"
  printf 'model fixture\n' >"$native/Model.js"
  printf 'manifest fixture\n' >"$native/manifest.json"
  ( cd "$native" && sha256sum Panel.qml Model.js manifest.json ) >"$FIXTURE_ROOT/upstream.sha256"
  EXTRA_ENV+=("DOTFILES_DISPLAY_NATIVE_DIR=$native" "DOTFILES_DISPLAY_SIGNATURES=$FIXTURE_ROOT/upstream.sha256")
  invoke '' 1 --host omarchy --components omarchy-display --yes
  err_contains 'unmanaged Display plugin'
  file_contains "$FIXTURE_HOME/.config/omarchy/plugins/guisaliba.monitor/manifest.json" 'unmanaged'
}

test_display_component

# --- Helper safety ---

printf '\n--- Helper Safety ---\n'

test_helper_safety() {
  new_fixture
  if env HOME="$FIXTURE_HOME" python3 "$HELPER" check-file \
    "$REPO_DIR/git/.gitconfig" "~/../../etc/passwd" >/dev/null 2>"$FIXTURE_ROOT/helper-err"; then
    not_ok "unsafe target was accepted"
  else
    ok "unsafe target is rejected"
  fi
  if grep -qF 'outside HOME' "$FIXTURE_ROOT/helper-err"; then
    ok "unsafe path error is explicit"
  else
    not_ok "unsafe path error is unclear"
  fi

  printf '%s\n' 'x' >"$FIXTURE_ROOT/real"
  ln -s "$FIXTURE_ROOT/real" "$FIXTURE_ROOT/link"
  if env HOME="$FIXTURE_HOME" python3 "$HELPER" copy-file \
    "$REPO_DIR/git/.gitconfig" "$FIXTURE_ROOT/link" >/dev/null 2>&1; then
    not_ok "symlink target was accepted"
  else
    ok "symlink target is rejected"
  fi
  file_contains "$FIXTURE_ROOT/real" "x"

  printf '%s\n' "$ALIASES_BLOCK_START" "alias py='x'" >"$FIXTURE_ROOT/bad-source"
  if env HOME="$FIXTURE_HOME" python3 "$HELPER" check-merge \
    "$FIXTURE_ROOT/bad-source" "~/.bash_aliases" \
    "$ALIASES_BLOCK_START" "$ALIASES_BLOCK_END" >/dev/null 2>&1; then
    not_ok "malformed source markers were accepted"
  else
    ok "malformed source markers are rejected"
  fi

  printf '%s\n' "$ALIASES_BLOCK_START" >"$FIXTURE_ROOT/bad-target"
  if env HOME="$FIXTURE_HOME" python3 "$HELPER" check-merge \
    "$REPO_DIR/bash/aliases.bash" "$FIXTURE_ROOT/bad-target" \
    "$ALIASES_BLOCK_START" "$ALIASES_BLOCK_END" >/dev/null 2>&1; then
    not_ok "malformed target markers were accepted"
  else
    ok "malformed target markers are rejected"
  fi
}

test_helper_safety

# --- Result ---

printf '\n'
if [[ "$failures" -gt 0 ]]; then
  printf 'dotfiles installer tests failed: %s\n' "$failures" >&2
  exit 1
fi

printf 'dotfiles installer tests passed\n'
