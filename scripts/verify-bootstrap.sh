#!/bin/sh
#
# Black-box verification for scripts/bootstrap.sh: runs it as a real
# subprocess against a fake $HOME (with its own fake bare git repo) and
# asserts against observable filesystem/git-config state, never against the
# script's internals. Mirrors the verify-oh-my-zsh-split.sh convention in
# this repo, extended with PATH-stubbed brew/curl/id/sh/bash binaries that
# log invocations instead of touching the real system.
#
# The `sh` stub stands in for the oh-my-zsh installer fetched via
# `sh -c "$(curl ...)"`: it logs its invocation and the KEEP_ZSHRC/CHSH/
# RUNZSH environment it saw, and creates $HOME/.oh-my-zsh as a side effect
# so the script's "already installed, skip" idempotency actually holds
# across repeated runs against the same fake HOME.
#
# The Homebrew installer is fetched via `/bin/bash -c "$(curl ...)"` (the
# official invocation) — `bash` itself is deliberately NOT stubbed: it's
# invoked by absolute path, which bypasses PATH-based stubbing entirely, and
# even an unqualified `bash` couldn't be stubbed anyway since bootstrap.sh's
# own `#!/usr/bin/env bash` shebang resolves through that same PATH, so a
# `bash` stub would swallow the whole script's execution, not just this one
# internal call. Instead the `curl` stub special-cases the Homebrew URL: it
# prints a small, harmless, test-authored fake-installer script to stdout
# (real oh-my-zsh/other URLs still get empty output), which the *real* bash
# then executes for real. That fake installer logs its NONINTERACTIVE
# environment and drops a `brew` stub into $STUB_INSTALL_DIR (passed
# through bootstrap.sh's environment by run_bootstrap) so a "brew becomes
# available after install" run can resolve it afterwards. Two separate
# stub-bin directories exist — one with a `brew` stub pre-installed (brew
# already on PATH), one without (brew absent, exercising the
# admin/non-admin install branches) — selected per scenario via
# run_bootstrap's optional third argument.

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

# --- Stub bin dirs: brew/curl/id/sh log their invocation instead of running
# for real (see the Homebrew-installer note above for why `bash` itself is
# not among them). "Brew absent" scenarios each get their own freshly-built
# stub dir (via make_no_brew_stub_path below) rather than sharing one, since
# the admin-branch scenario's fake installer drops a brew stub into its dir
# as a side effect — reusing that dir would make a later "brew absent"
# scenario find brew already there. ---
STUB_BIN="$TMP_DIR/stub-bin"    # brew pre-installed
STUB_LOG="$TMP_DIR/stub.log"
ID_GROUPS_FILE="$TMP_DIR/id-groups"
mkdir -p "$STUB_BIN" || fail "cannot create stub bin directory"
: > "$STUB_LOG"

reset_stub_log() {
  : > "$STUB_LOG"
}

set_id_groups() {
  printf '%s\n' "$1" > "$ID_GROUPS_FILE"
}

clear_id_groups() {
  rm -f "$ID_GROUPS_FILE"
}

make_stub() {
  stub_dir=$1
  stub_name=$2
  cat > "$stub_dir/$stub_name" <<STUB
#!/bin/sh
printf '%s %s\n' "$stub_name" "\$*" >> "$STUB_LOG"
exit 0
STUB
  chmod +x "$stub_dir/$stub_name" || fail "cannot create $stub_name stub in $stub_dir"
}

# The fake Homebrew installer that curl "fetches" (see install_shared_stubs
# below). Left unexpanded here (quoted heredoc terminator) so STUB_LOG,
# BREW_STUB_TEMPLATE, STUB_INSTALL_DIR and NONINTERACTIVE are all resolved
# later, inside bootstrap.sh's own environment, when this text is actually
# run by a real `bash -c`.
HOMEBREW_FAKE_INSTALLER="$TMP_DIR/homebrew-fake-installer.sh"
cat > "$HOMEBREW_FAKE_INSTALLER" <<'EOF'
printf 'homebrew-install-env NONINTERACTIVE=%s\n' "${NONINTERACTIVE:-unset}" >> "$STUB_LOG"
cp "$BREW_STUB_TEMPLATE" "$STUB_INSTALL_DIR/brew"
chmod +x "$STUB_INSTALL_DIR/brew"
EOF

# Shared stubs every scenario needs regardless of brew's availability:
# curl (logs its invocation; for the Homebrew URL it also prints the fake
# installer above to stdout, since that's how bootstrap.sh's
# `bash -c "$(curl ...)"` picks it up), id (configurable admin-group
# output) and sh (the oh-my-zsh installer stand-in).
install_shared_stubs() {
  stub_dir=$1

  cat > "$stub_dir/curl" <<STUB
#!/bin/sh
printf 'curl %s\n' "\$*" >> "$STUB_LOG"
case "\$*" in
  *Homebrew/install*) cat "$HOMEBREW_FAKE_INSTALLER" ;;
esac
exit 0
STUB
  chmod +x "$stub_dir/curl" || fail "cannot create curl stub in $stub_dir"

  cat > "$stub_dir/id" <<STUB
#!/bin/sh
printf 'id %s\n' "\$*" >> "$STUB_LOG"
if [ -f "$ID_GROUPS_FILE" ]; then
  cat "$ID_GROUPS_FILE"
fi
exit 0
STUB
  chmod +x "$stub_dir/id" || fail "cannot create id stub in $stub_dir"

  # The oh-my-zsh installer is fetched and run via `sh -c "$(curl ...)"`, so
  # `sh` itself must be stubbed to observe that invocation. It also fakes
  # the installer's real-world side effect (creating ~/.oh-my-zsh) so
  # bootstrap.sh's "already installed" skip path is exercised on a second
  # run.
  cat > "$stub_dir/sh" <<STUB
#!/bin/sh
printf 'sh %s\n' "\$*" >> "$STUB_LOG"
printf 'sh-env KEEP_ZSHRC=%s CHSH=%s RUNZSH=%s\n' "\${KEEP_ZSHRC:-unset}" "\${CHSH:-unset}" "\${RUNZSH:-unset}" >> "$STUB_LOG"
mkdir -p "\$HOME/.oh-my-zsh"
exit 0
STUB
  chmod +x "$stub_dir/sh" || fail "cannot create sh stub in $stub_dir"
}

# Staged in $TMP_DIR (not on any constructed PATH) and copied out to the
# various stub-bin dirs as brew becomes "available" in each scenario.
make_stub "$TMP_DIR" brew
BREW_STUB_TEMPLATE="$TMP_DIR/brew"

install_shared_stubs "$STUB_BIN"
cp "$BREW_STUB_TEMPLATE" "$STUB_BIN/brew" || fail "cannot create brew stub in $STUB_BIN"
chmod +x "$STUB_BIN/brew" || fail "cannot make brew stub executable in $STUB_BIN"

STUB_PATH="$STUB_BIN:/usr/bin:/bin:/usr/sbin:/sbin"

# Builds a fresh stub-bin directory with no brew stub in it and prints the
# PATH to run bootstrap.sh against it, for scenarios exercising the
# brew-absent branches.
make_no_brew_stub_path() {
  no_brew_dir=$1
  mkdir -p "$no_brew_dir" || fail "cannot create stub bin directory $no_brew_dir"
  install_shared_stubs "$no_brew_dir"
  printf '%s' "$no_brew_dir:/usr/bin:/bin:/usr/sbin:/sbin"
}

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
  path=${3:-$STUB_PATH}
  install_dir=${4:-$STUB_BIN}
  env -i \
    HOME="$fake_home" \
    PATH="$path" \
    STUB_LOG="$STUB_LOG" \
    BREW_STUB_TEMPLATE="$BREW_STUB_TEMPLATE" \
    STUB_INSTALL_DIR="$install_dir" \
    TERM=dumb \
    LANG=C \
    LC_ALL=C \
    "$BOOTSTRAP_SCRIPT" >"$TMP_DIR/$label.output" 2>"$TMP_DIR/$label.errors"
}

file_mode() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null
}

assert_brew_bundle_invoked() {
  fake_home=$1
  grep -q "^brew bundle --file=$fake_home/Brewfile\$" "$STUB_LOG" \
    || fail "brew bundle was not invoked with --file=$fake_home/Brewfile: $(cat "$STUB_LOG")"
}

# Fails if any logged stub call isn't the expected `brew bundle` invocation
# (e.g. a stray oh-my-zsh or Homebrew install call that shouldn't have fired).
assert_only_brew_bundle_logged() {
  msg=$1
  unexpected=$(grep -v '^brew bundle ' "$STUB_LOG")
  [ -z "$unexpected" ] || fail "$msg: $unexpected"
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

assert_brew_bundle_invoked "$FRESH_HOME"
pass "brew bundle is invoked against the Brewfile when brew is already on PATH"

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

grep -q '^sh ' "$STUB_LOG" \
  && fail "oh-my-zsh install was re-invoked on a re-run where ~/.oh-my-zsh already exists: $(cat "$STUB_LOG")"
pass "re-running bootstrap.sh on an already-bootstrapped HOME produces no duplicate config entries and skips oh-my-zsh install"

assert_only_brew_bundle_logged "unexpected stub invocation(s) on an idempotent re-run"
assert_brew_bundle_invoked "$FRESH_HOME"
pass "brew bundle re-runs idempotently against the Brewfile on a re-run"

# ======================================================================
# Scenario B: oh-my-zsh already present up front — install step is a no-op.
# ======================================================================
OMZ_PRESENT_HOME="$TMP_DIR/omz-present-home"
make_fake_home "$OMZ_PRESENT_HOME"
mkdir -p "$OMZ_PRESENT_HOME/.oh-my-zsh" || fail "cannot seed ~/.oh-my-zsh"

reset_stub_log
run_bootstrap omz-present "$OMZ_PRESENT_HOME" \
  || fail "bootstrap.sh exited non-zero with ~/.oh-my-zsh already present: $(cat "$TMP_DIR/omz-present.errors")"

grep -q '^sh ' "$STUB_LOG" \
  && fail "oh-my-zsh install was invoked even though ~/.oh-my-zsh already existed: $(cat "$STUB_LOG")"
pass "oh-my-zsh install step is a no-op when ~/.oh-my-zsh already exists"

assert_only_brew_bundle_logged "unexpected stub invocation(s) with oh-my-zsh already present"
assert_brew_bundle_invoked "$OMZ_PRESENT_HOME"
pass "brew bundle still runs when oh-my-zsh is already present"

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

assert_only_brew_bundle_logged "unexpected stub invocation(s) logged for bootstrap.sh's git-config/permission steps"
assert_brew_bundle_invoked "$READY_HOME"
pass "curl/id/sh installer stubs were not invoked, and brew bundle alone runs (idempotently) by bootstrap.sh's Homebrew/git-config/permission steps"

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

# ============================================================================
# Scenario E: missing bare-repo checkout fails loudly, not silently.
# ============================================================================
NO_CHECKOUT_HOME="$TMP_DIR/no-checkout-home"
mkdir -p "$NO_CHECKOUT_HOME" || fail "cannot create $NO_CHECKOUT_HOME"

reset_stub_log
if run_bootstrap no-checkout "$NO_CHECKOUT_HOME"; then
  fail "bootstrap.sh exited zero with no ~/.cfg bare repo present"
fi
pass "bootstrap.sh fails loudly when the bare-repo checkout hasn't happened yet"

# ============================================================================
# Scenario F: brew absent, admin rights — installs Homebrew then bundles.
# ============================================================================
BREW_ADMIN_HOME="$TMP_DIR/brew-admin-home"
make_fake_home "$BREW_ADMIN_HOME"
mkdir -p "$BREW_ADMIN_HOME/.oh-my-zsh" || fail "cannot seed ~/.oh-my-zsh"

BREW_ADMIN_STUB_DIR="$TMP_DIR/stub-bin-brew-admin"
STUB_PATH_BREW_ADMIN=$(make_no_brew_stub_path "$BREW_ADMIN_STUB_DIR")

set_id_groups "staff everyone admin"
reset_stub_log
run_bootstrap brew-admin "$BREW_ADMIN_HOME" "$STUB_PATH_BREW_ADMIN" "$BREW_ADMIN_STUB_DIR" \
  || fail "bootstrap.sh exited non-zero with brew absent + admin rights: $(cat "$TMP_DIR/brew-admin.errors")"
clear_id_groups

grep -q "Homebrew/install/HEAD/install.sh" "$STUB_LOG" \
  || fail "Homebrew installer was not fetched via curl when brew was absent: $(cat "$STUB_LOG")"
pass "Homebrew installer is fetched when brew is absent and the user has admin rights"

grep -q '^homebrew-install-env NONINTERACTIVE=1$' "$STUB_LOG" \
  || fail "Homebrew installer was not invoked with NONINTERACTIVE=1: $(grep '^homebrew-install-env' "$STUB_LOG")"
pass "Homebrew installer is invoked unattended with NONINTERACTIVE=1"

assert_brew_bundle_invoked "$BREW_ADMIN_HOME"
pass "brew bundle runs against the Brewfile after Homebrew is installed"

# ============================================================================
# Scenario G: brew absent, no admin rights — skips both steps gracefully.
# ============================================================================
BREW_NONADMIN_HOME="$TMP_DIR/brew-nonadmin-home"
make_fake_home "$BREW_NONADMIN_HOME"
mkdir -p "$BREW_NONADMIN_HOME/.oh-my-zsh" || fail "cannot seed ~/.oh-my-zsh"

BREW_NONADMIN_STUB_DIR="$TMP_DIR/stub-bin-brew-nonadmin"
STUB_PATH_BREW_NONADMIN=$(make_no_brew_stub_path "$BREW_NONADMIN_STUB_DIR")

set_id_groups "staff everyone"
reset_stub_log
run_bootstrap brew-nonadmin "$BREW_NONADMIN_HOME" "$STUB_PATH_BREW_NONADMIN" "$BREW_NONADMIN_STUB_DIR" \
  || fail "bootstrap.sh exited non-zero with brew absent + no admin rights: $(cat "$TMP_DIR/brew-nonadmin.errors")"
clear_id_groups

grep -q "Homebrew/install" "$STUB_LOG" \
  && fail "Homebrew installer was fetched despite no admin rights: $(cat "$STUB_LOG")"
grep -q '^brew bundle' "$STUB_LOG" \
  && fail "brew bundle was invoked despite brew being absent with no admin rights: $(cat "$STUB_LOG")"
pass "Homebrew install and brew bundle are both skipped when brew is absent and the user has no admin rights"

grep -qi 'no admin rights' "$TMP_DIR/brew-nonadmin.errors" \
  || fail "no warning naming the skip reason was printed: $(cat "$TMP_DIR/brew-nonadmin.errors")"
pass "a clear warning naming what was skipped and why is printed"

excludesfile=$(fake_config "$BREW_NONADMIN_HOME" config --local --get core.excludesfile) \
  || fail "git-config fixups did not run after the Homebrew section was skipped"
[ "$excludesfile" = "$BREW_NONADMIN_HOME/.gitignore_global" ] \
  || fail "core.excludesfile points at the wrong path after the Homebrew section was skipped: $excludesfile"
pass "bootstrap.sh completes its other steps after a skipped Homebrew section (per-section failure boundary, not a whole-script abort)"

printf '%s\n' 'PASS: bootstrap.sh verification complete'
