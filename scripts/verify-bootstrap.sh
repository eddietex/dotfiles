#!/bin/sh
#
# Black-box verification for scripts/bootstrap.sh: runs it as a real
# subprocess against a fake $HOME (with its own fake bare git repo) and
# asserts against observable filesystem/git-config state, never against the
# script's internals. Mirrors the verify-oh-my-zsh-split.sh convention in
# this repo, extended with PATH-stubbed brew/curl/id/sh binaries that log
# invocations instead of touching the real system, for reuse by later
# bootstrap.sh tickets.
#
# The `sh` stub stands in for the oh-my-zsh installer fetched via
# `sh -c "$(curl ...)"`: it logs its invocation and the KEEP_ZSHRC/CHSH/
# RUNZSH environment it saw, and creates $HOME/.oh-my-zsh as a side effect
# so the script's "already installed, skip" idempotency actually holds
# across repeated runs against the same fake HOME.

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BOOTSTRAP_SCRIPT="$SCRIPT_DIR/bootstrap.sh"
TMP_DIR=

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$1"
}

cleanup() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
    chmod -R u+rwX "$TMP_DIR" >/dev/null 2>&1
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT HUP INT TERM

[ -f "$BOOTSTRAP_SCRIPT" ] || fail "scripts/bootstrap.sh is missing"
[ -x "$BOOTSTRAP_SCRIPT" ] || fail "scripts/bootstrap.sh is not executable"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/verify-bootstrap.XXXXXX") || fail "cannot create temporary directory"

# --- Stub bin dir: brew/curl/id/sh log their invocation instead of running
# for real. brew and id are not exercised by this ticket's steps, but stood
# up here so the later Homebrew/Brewfile ticket can reuse this harness
# without re-deriving it. ---
STUB_BIN="$TMP_DIR/stub-bin"
STUB_LOG="$TMP_DIR/stub.log"
mkdir -p "$STUB_BIN" || fail "cannot create stub bin directory"
: > "$STUB_LOG"

reset_stub_log() {
  : > "$STUB_LOG"
}

make_stub() {
  stub_name=$1
  cat > "$STUB_BIN/$stub_name" <<STUB
#!/bin/sh
printf '%s %s\n' "$stub_name" "\$*" >> "$STUB_LOG"
exit 0
STUB
  chmod +x "$STUB_BIN/$stub_name" || fail "cannot create $stub_name stub"
}

make_stub brew
make_stub curl
make_stub id

# The oh-my-zsh installer is fetched and run via `sh -c "$(curl ...)"`, so
# `sh` itself must be stubbed to observe that invocation. It also fakes the
# installer's real-world side effect (creating ~/.oh-my-zsh) so bootstrap.sh's
# "already installed" skip path is exercised on a second run.
cat > "$STUB_BIN/sh" <<STUB
#!/bin/sh
printf 'sh %s\n' "\$*" >> "$STUB_LOG"
printf 'sh-env KEEP_ZSHRC=%s CHSH=%s RUNZSH=%s\n' "\${KEEP_ZSHRC:-unset}" "\${CHSH:-unset}" "\${RUNZSH:-unset}" >> "$STUB_LOG"
mkdir -p "\$HOME/.oh-my-zsh"
exit 0
STUB
chmod +x "$STUB_BIN/sh" || fail "cannot create sh stub"

STUB_PATH="$STUB_BIN:/usr/bin:/bin:/usr/sbin:/sbin"

make_fake_home() {
  fake_home=$1
  mkdir -p "$fake_home" || fail "cannot create fake HOME at $fake_home"
  git init -q --bare "$fake_home/.cfg" || fail "cannot init fake bare repo at $fake_home/.cfg"
}

fake_config() {
  fake_home=$1
  shift
  git --git-dir="$fake_home/.cfg" --work-tree="$fake_home" "$@"
}

run_bootstrap() {
  label=$1
  fake_home=$2
  env -i \
    HOME="$fake_home" \
    PATH="$STUB_PATH" \
    TERM=dumb \
    LANG=C \
    LC_ALL=C \
    "$BOOTSTRAP_SCRIPT" >"$TMP_DIR/$label.output" 2>"$TMP_DIR/$label.errors"
}

file_mode() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null
}

# ============================================================
# Scenario A: fresh fake $HOME — config/files absent up front.
# ============================================================
FRESH_HOME="$TMP_DIR/fresh-home"
make_fake_home "$FRESH_HOME"

reset_stub_log
run_bootstrap fresh-1 "$FRESH_HOME" \
  || fail "bootstrap.sh (first run) exited non-zero on a fresh HOME: $(cat "$TMP_DIR/fresh-1.errors")"
pass "bootstrap.sh exits successfully on a fresh HOME"

[ -f "$FRESH_HOME/.gitignore_global" ] || fail "~/.gitignore_global was not created"
pass "~/.gitignore_global is created when absent"

excludesfile=$(fake_config "$FRESH_HOME" config --local --get core.excludesfile) \
  || fail "core.excludesfile was not set as a local git-config override"
[ "$excludesfile" = "$FRESH_HOME/.gitignore_global" ] \
  || fail "core.excludesfile points at the wrong path: $excludesfile"
pass "local core.excludesfile points at \$HOME/.gitignore_global"

untracked=$(fake_config "$FRESH_HOME" config --local --get status.showUntrackedFiles) \
  || fail "status.showUntrackedFiles was not set locally"
[ "$untracked" = "no" ] || fail "status.showUntrackedFiles is not 'no': $untracked"
pass "local status.showUntrackedFiles is 'no'"

[ ! -e "$FRESH_HOME/.zshrc.local" ] \
  || fail "bootstrap.sh created ~/.zshrc.local, which it must never do"
pass "~/.zshrc.local is left absent when it didn't already exist"

grep -q "ohmyzsh/ohmyzsh/master/tools/install.sh" "$STUB_LOG" \
  || fail "oh-my-zsh installer was not fetched via curl when ~/.oh-my-zsh was absent"
pass "oh-my-zsh installer is fetched when ~/.oh-my-zsh is absent"

grep -q '^sh .*--unattended' "$STUB_LOG" \
  || fail "oh-my-zsh installer was not invoked with --unattended"
grep -q '^sh-env KEEP_ZSHRC=yes CHSH=no RUNZSH=no$' "$STUB_LOG" \
  || fail "oh-my-zsh installer was not invoked with KEEP_ZSHRC=yes CHSH=no RUNZSH=no: $(grep '^sh-env' "$STUB_LOG")"
pass "oh-my-zsh installer is invoked unattended with KEEP_ZSHRC=yes, CHSH=no, RUNZSH=no"

[ -d "$FRESH_HOME/.oh-my-zsh" ] || fail "~/.oh-my-zsh was not present after the install step ran"
pass "~/.oh-my-zsh is present after the install step runs"

# --- Idempotency: run again, expect identical state and no duplicate entries.
reset_stub_log
run_bootstrap fresh-2 "$FRESH_HOME" \
  || fail "bootstrap.sh (second run) exited non-zero: $(cat "$TMP_DIR/fresh-2.errors")"

excludesfile_count=$(fake_config "$FRESH_HOME" config --local --get-all core.excludesfile | wc -l | tr -d ' ')
[ "$excludesfile_count" = 1 ] \
  || fail "core.excludesfile has $excludesfile_count entries after a second run (expected 1)"

untracked_count=$(fake_config "$FRESH_HOME" config --local --get-all status.showUntrackedFiles | wc -l | tr -d ' ')
[ "$untracked_count" = 1 ] \
  || fail "status.showUntrackedFiles has $untracked_count entries after a second run (expected 1)"

[ ! -e "$FRESH_HOME/.zshrc.local" ] || fail "second run created ~/.zshrc.local"

[ -s "$STUB_LOG" ] \
  && fail "oh-my-zsh install was re-invoked on a re-run where ~/.oh-my-zsh already exists: $(cat "$STUB_LOG")"

pass "re-running bootstrap.sh on an already-bootstrapped HOME produces no duplicate config entries and skips oh-my-zsh install"

# ======================================================================
# Scenario B: oh-my-zsh already present up front — install step is a no-op.
# ======================================================================
OMZ_PRESENT_HOME="$TMP_DIR/omz-present-home"
make_fake_home "$OMZ_PRESENT_HOME"
mkdir -p "$OMZ_PRESENT_HOME/.oh-my-zsh" || fail "cannot seed ~/.oh-my-zsh"

reset_stub_log
run_bootstrap omz-present "$OMZ_PRESENT_HOME" \
  || fail "bootstrap.sh exited non-zero with ~/.oh-my-zsh already present: $(cat "$TMP_DIR/omz-present.errors")"

[ -s "$STUB_LOG" ] \
  && fail "oh-my-zsh install was invoked even though ~/.oh-my-zsh already existed: $(cat "$STUB_LOG")"
pass "oh-my-zsh install step is a no-op when ~/.oh-my-zsh already exists"

# ==================================================================
# Scenario C: config/files already correct up front — left untouched.
# ==================================================================
READY_HOME="$TMP_DIR/ready-home"
make_fake_home "$READY_HOME"
mkdir -p "$READY_HOME/.oh-my-zsh" || fail "cannot seed ~/.oh-my-zsh"
printf '*.log\n' > "$READY_HOME/.gitignore_global" || fail "cannot seed ~/.gitignore_global"
fake_config "$READY_HOME" config --local core.excludesfile "$READY_HOME/.gitignore_global" \
  || fail "cannot seed core.excludesfile"
fake_config "$READY_HOME" config --local status.showUntrackedFiles no \
  || fail "cannot seed status.showUntrackedFiles"
printf 'export SECRET=1\n' > "$READY_HOME/.zshrc.local" || fail "cannot seed ~/.zshrc.local"
chmod 600 "$READY_HOME/.zshrc.local" || fail "cannot seed ~/.zshrc.local mode"
gitignore_before=$(git hash-object "$READY_HOME/.gitignore_global") \
  || fail "cannot hash seeded ~/.gitignore_global"

reset_stub_log
run_bootstrap ready "$READY_HOME" \
  || fail "bootstrap.sh exited non-zero on an already-correct HOME: $(cat "$TMP_DIR/ready.errors")"

gitignore_after=$(git hash-object "$READY_HOME/.gitignore_global") \
  || fail "cannot re-hash ~/.gitignore_global"
[ "$gitignore_before" = "$gitignore_after" ] \
  || fail "bootstrap.sh modified an already-existing ~/.gitignore_global"
pass "an already-existing ~/.gitignore_global is left untouched"

mode=$(file_mode "$READY_HOME/.zshrc.local")
[ "$mode" = 600 ] \
  || fail "~/.zshrc.local is not mode 600 after running on an already-correct HOME: $mode"
pass "an already-mode-600 ~/.zshrc.local stays mode 600"

[ -s "$STUB_LOG" ] && fail "unexpected stub invocation(s) logged for bootstrap.sh's git-config/permission steps: $(cat "$STUB_LOG")"
pass "brew/curl/id/sh stubs were not invoked by bootstrap.sh's git-config/permission steps"

# ======================================================================
# Scenario D: ~/.zshrc.local present with loose permissions gets tightened.
# ======================================================================
LOOSE_HOME="$TMP_DIR/loose-home"
make_fake_home "$LOOSE_HOME"
mkdir -p "$LOOSE_HOME/.oh-my-zsh" || fail "cannot seed ~/.oh-my-zsh"
printf 'export SECRET=1\n' > "$LOOSE_HOME/.zshrc.local" || fail "cannot seed ~/.zshrc.local"
chmod 644 "$LOOSE_HOME/.zshrc.local" || fail "cannot seed ~/.zshrc.local mode"

reset_stub_log
run_bootstrap loose "$LOOSE_HOME" \
  || fail "bootstrap.sh exited non-zero: $(cat "$TMP_DIR/loose.errors")"

mode=$(file_mode "$LOOSE_HOME/.zshrc.local")
[ "$mode" = 600 ] || fail "~/.zshrc.local was not chmod'd to 600: $mode"
pass "a pre-existing, loosely-permissioned ~/.zshrc.local is chmod'd to 600"

# ==========================================================
# Scenario E: missing bare-repo checkout fails loudly, not silently.
# ==========================================================
NO_CHECKOUT_HOME="$TMP_DIR/no-checkout-home"
mkdir -p "$NO_CHECKOUT_HOME" || fail "cannot create $NO_CHECKOUT_HOME"

reset_stub_log
if run_bootstrap no-checkout "$NO_CHECKOUT_HOME"; then
  fail "bootstrap.sh exited zero with no ~/.cfg bare repo present"
fi
pass "bootstrap.sh fails loudly when the bare-repo checkout hasn't happened yet"

printf '%s\n' 'PASS: bootstrap.sh verification complete'
