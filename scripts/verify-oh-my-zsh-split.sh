#!/bin/sh

set -u

HOME_DIR=${HOME:?HOME must be set}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORKTREE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PUBLIC_ZSHRC="$WORKTREE_DIR/.zshrc"
PRIVATE_ZSHRC="$HOME_DIR/.zshrc.local"
OH_MY_ZSH="$HOME_DIR/.oh-my-zsh"
GIT_DIR="$HOME_DIR/.cfg"
ZSH_BIN=$(command -v zsh 2>/dev/null || true)
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
    find "$TMP_DIR" -depth -type f -exec unlink {} + >/dev/null 2>&1
    find "$TMP_DIR" -depth -type l -exec unlink {} + >/dev/null 2>&1
    find "$TMP_DIR" -depth -type d -exec rmdir {} + >/dev/null 2>&1
  fi
}

trap cleanup EXIT HUP INT TERM

[ -x "$ZSH_BIN" ] || fail "zsh is unavailable"
[ -f "$PUBLIC_ZSHRC" ] || fail "tracked .zshrc is unavailable"
[ -f "$PRIVATE_ZSHRC" ] || fail "~/.zshrc.local is unavailable"
[ -d "$OH_MY_ZSH" ] || fail "external ~/.oh-my-zsh checkout is unavailable"
[ -d "$GIT_DIR" ] || fail "bare dotfiles repository is unavailable"

private_mode=$(stat -f '%Lp' "$PRIVATE_ZSHRC" 2>/dev/null || stat -c '%a' "$PRIVATE_ZSHRC" 2>/dev/null || true)
[ "$private_mode" = 600 ] || fail "~/.zshrc.local must have mode 600"

local_aliases=$(sed -nE 's/^[[:space:]]*alias[[:space:]]+([^=[:space:]]+).*/\1/p' "$PRIVATE_ZSHRC")
[ -n "$local_aliases" ] || fail "no local aliases found"
credential_names=$(sed -nE 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*(KEY|TOKEN|SECRET|PASSWORD|CREDENTIALS?))=.*/\2/p' "$PRIVATE_ZSHRC" | tr '\n' ' ')
[ -n "$credential_names" ] || fail "no private credential names found"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/oh-my-zsh-split.XXXXXX") || fail "cannot create temporary directory"
PUBLIC_HOME="$TMP_DIR/public-home"
PUBLIC_ZDOTDIR="$TMP_DIR/public-zdotdir"
PRIVATE_ZDOTDIR="$TMP_DIR/private-zdotdir"
TEST_REPO="$TMP_DIR/repository"
mkdir -p "$PUBLIC_HOME" "$PUBLIC_ZDOTDIR" "$PRIVATE_ZDOTDIR" "$TEST_REPO" || fail "cannot create temporary test layout"
ln -s "$OH_MY_ZSH" "$PUBLIC_HOME/.oh-my-zsh" || fail "cannot link external Oh My Zsh checkout"
ln -s "$PUBLIC_ZSHRC" "$PUBLIC_ZDOTDIR/.zshrc" || fail "cannot link public .zshrc"
ln -s "$PUBLIC_ZSHRC" "$PRIVATE_ZDOTDIR/.zshrc" || fail "cannot link private test .zshrc"

git -C "$TEST_REPO" init -q || fail "cannot initialize temporary Git repository"
git -C "$TEST_REPO" branch -m main || fail "cannot set temporary Git branch"
git -C "$TEST_REPO" config user.name verifier || fail "cannot configure temporary Git identity"
git -C "$TEST_REPO" config user.email verifier@example.invalid || fail "cannot configure temporary Git identity"
: > "$TEST_REPO/tracked-file"
git -C "$TEST_REPO" add tracked-file || fail "cannot stage temporary Git file"
git -C "$TEST_REPO" commit -qm initial || fail "cannot commit temporary Git file"

git_config() {
  git --git-dir="$GIT_DIR" --work-tree="$HOME_DIR" "$@"
}

gitconfig_before=$(git hash-object "$HOME_DIR/.gitconfig" 2>/dev/null) || fail "cannot hash .gitconfig"

static_public() {
  cmp -s "$PUBLIC_ZSHRC" - <<'ZSH'
# Portable Oh My Zsh startup.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="simple"
plugins=(git)

source "$ZSH/oh-my-zsh.sh"

if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
ZSH
}

static_public || fail "tracked .zshrc contains non-portable or private setup"
pass "tracked .zshrc contains only portable startup setup"

git_config ls-files --error-unmatch -- .zshrc >/dev/null 2>&1 || fail ".zshrc is not tracked"
git_config check-ignore -q -- .zshrc && fail ".zshrc is ignored"
git_config check-ignore -q -- .zshrc.local || fail ".zshrc.local is not locally excluded"
git_config check-ignore -q -- .oh-my-zsh/ || fail ".oh-my-zsh/ is not locally excluded"
git_config ls-files -- .oh-my-zsh | grep -q . && fail "external Oh My Zsh state is tracked"
git_config ls-files --error-unmatch -- .zshrc.local >/dev/null 2>&1 && fail ".zshrc.local is tracked"
dry_run=$(git_config add --dry-run -- .zshrc 2>&1) || fail "public .zshrc dry-run failed"
printf '%s\n' "$dry_run" | grep -Fq '.zshrc.local' && fail "public dry-run references .zshrc.local"
git_config diff --cached --name-only -- .zshrc.local | grep -q . && fail "public dry-run staged .zshrc.local"
pass "local exclusion and public-only dry-run boundaries hold"

run_probe() {
  label=$1
  probe_home=$2
  probe_zdotdir=$3
  probe_path=$4
  probe_file=$5
  probe_output="$TMP_DIR/$label.output"
  probe_errors="$TMP_DIR/$label.errors"
  if ! (
    cd "$TEST_REPO" || exit 1
    env -i \
      HOME="$probe_home" \
      ZDOTDIR="$probe_zdotdir" \
      ZSH_COMPDUMP="$TMP_DIR/$label.compdump" \
      PATH="$probe_path" \
      TERM=dumb \
      LANG=C \
      LC_ALL=C \
      SPLIT_LOCAL_ALIASES="$(printf '%s ' $local_aliases)" \
      SPLIT_CREDENTIAL_NAMES="$credential_names" \
      SPLIT_GIT_REPO="$TEST_REPO" \
      "$ZSH_BIN" -di "$probe_file" >"$probe_output" 2>"$probe_errors"
  ); then
    fail "$label startup failed"
  fi
  grep -qx 'SPLIT_READY' "$probe_output" || fail "$label checks failed"
}

public_probe="$TMP_DIR/public-probe.zsh"
cat > "$public_probe" <<'ZSH'
(( ${+functions[git_prompt_info]} )) || exit 1
[[ "$ZSH_THEME" = simple ]] || exit 1
[[ " $plugins[*] " = *" git "* ]] || exit 1
[[ ! -e "$HOME/.zshrc.local" ]] || exit 1
for name in ${=SPLIT_CREDENTIAL_NAMES}; do
  env | grep -q "^${name}=" && exit 1
done
print -r -- SPLIT_READY
ZSH
run_probe public-without-private "$PUBLIC_HOME" "$PUBLIC_ZDOTDIR" "/usr/bin:/bin:/usr/sbin:/sbin" "$public_probe"
pass "public startup works with ~/.zshrc.local absent and credentials isolated"

private_probe="$TMP_DIR/private-probe.zsh"
cat > "$private_probe" <<'ZSH'
(( ${+functions[git_prompt_info]} )) || exit 1
[[ -e "$HOME/.zshrc.local" ]] || exit 1
[[ -n "$PATH" ]] || exit 1
case ":$PATH:" in
  *:"$HOME/Workspace/personal-assistant/scripts":*) : ;;
  *) exit 1 ;;
esac
case ":$PATH:" in
  *:"$HOME/.maestro/bin":*) : ;;
  *) exit 1 ;;
esac
for name in DEVELOPER_DIR JAVA_HOME ANDROID_HOME NVM_DIR TMUX_STATIC_COMPLETIONS; do
  [[ -n ${parameters[$name]-} ]] || exit 1
done
for name in ${=SPLIT_LOCAL_ALIASES}; do
  (( ${+aliases[$name]} )) || exit 1
done
for name in ${=SPLIT_CREDENTIAL_NAMES}; do
  env | grep -q "^${name}=" || exit 1
done
(( ${+functions[rbenv]} )) || exit 1
(( ${+functions[nvm]} )) || exit 1
(( ${+functions[tmux-static]} )) || exit 1
(( ${+functions[_tmux-static]} )) || exit 1
[[ -n "$SPLIT_GIT_REPO" ]] || exit 1
[[ -z "$(git remote)" ]] || exit 1
[[ "$(git symbolic-ref --short HEAD)" = main ]] || exit 1
clean_prompt=$(_omz_git_prompt_info)
[[ "$clean_prompt" = *main* ]] || exit 1
[[ "$clean_prompt" = *✔* ]] || exit 1
[[ "$clean_prompt" != *✗* ]] || exit 1
[[ "$ZSH_THEME_GIT_PROMPT_CLEAN" = *"${fg[green]}"* ]] || exit 1
: > "$SPLIT_GIT_REPO/dirty-file"
dirty_prompt=$(_omz_git_prompt_info)
[[ "$dirty_prompt" = *main* ]] || exit 1
[[ "$dirty_prompt" = *✗* ]] || exit 1
[[ "$dirty_prompt" != *✔* ]] || exit 1
[[ "$ZSH_THEME_GIT_PROMPT_DIRTY" = *"${fg[red]}"* ]] || exit 1
[[ "$clean_prompt" != *↑* && "$clean_prompt" != *↓* && "$clean_prompt" != *⇡* && "$clean_prompt" != *⇣* ]] || exit 1
[[ "$dirty_prompt" != *↑* && "$dirty_prompt" != *↓* && "$dirty_prompt" != *⇡* && "$dirty_prompt" != *⇣* ]] || exit 1
print -r -- SPLIT_READY
ZSH
run_probe private-with-local "$HOME_DIR" "$PRIVATE_ZDOTDIR" "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" "$private_probe"
pass "private startup restores aliases, paths, SDKs, tools, credentials, and tmux completion"
pass "temporary Git prompt shows main with clean ✔ and dirty ✗ without remote indicators"

gitconfig_after=$(git hash-object "$HOME_DIR/.gitconfig" 2>/dev/null) || fail "cannot re-hash .gitconfig"
[ "$gitconfig_before" = "$gitconfig_after" ] || fail ".gitconfig worktree blob changed"
pass "existing .gitconfig worktree blob is unchanged"

printf '%s\n' 'PASS: Oh My Zsh public/private split verification complete'
