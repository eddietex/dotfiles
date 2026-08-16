#!/usr/bin/env bash
#
# Idempotent post-checkout setup for this dotfiles repo. Run manually once
# after the bare-repo clone/checkout documented in README.md — safe to
# re-run any time (e.g. after pulling new dotfiles changes).

# -e is deliberately not set: later steps in this script apply a
# per-section failure boundary (e.g. a missing Homebrew admin right must
# skip that section, not abort the whole run), so every command that must
# succeed is chained with an explicit `|| die` instead.
set -uo pipefail

HOME_DIR=${HOME:?HOME must be set}
GIT_DIR="$HOME_DIR/.cfg"

die() {
  printf 'bootstrap.sh: %s\n' "$1" >&2
  exit 1
}

git_config() {
  git --git-dir="$GIT_DIR" --work-tree="$HOME_DIR" "$@"
}

require_checkout() {
  [ -d "$GIT_DIR" ] \
    || die "$GIT_DIR is missing; run the bare-repo clone/checkout from README.md first"
}

apply_git_config_fixups() {
  echo "==> Local git-config fixups"

  if [ ! -f "$HOME_DIR/.gitignore_global" ]; then
    : > "$HOME_DIR/.gitignore_global" || die "cannot create $HOME_DIR/.gitignore_global"
  fi

  git_config config --local core.excludesfile "$HOME_DIR/.gitignore_global" \
    || die "cannot set local core.excludesfile"
  git_config config --local status.showUntrackedFiles no \
    || die "cannot set local status.showUntrackedFiles"
}

fix_zshrc_local_permissions() {
  echo "==> ~/.zshrc.local permissions"

  if [ -f "$HOME_DIR/.zshrc.local" ]; then
    chmod 600 "$HOME_DIR/.zshrc.local" || die "cannot chmod ~/.zshrc.local to 600"
  fi
}

main() {
  require_checkout
  apply_git_config_fixups
  fix_zshrc_local_permissions
  echo "bootstrap.sh: done"
}

main "$@"
