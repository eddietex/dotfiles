# dotfiles

Personal dotfiles tracked with a bare Git repository, following the pattern
described in [Managing Dotfiles with a Bare Git Repository](https://www.atlassian.com/git/tutorials/dotfiles)
(Atlassian).

## Quick start (recommended)

On a new machine:

```bash
# Clone this repo as a bare repository into $HOME/.cfg
git clone --bare git@github.com:eddietex/dotfiles.git $HOME/.cfg

# Create an alias for Git commands targeting the dotfiles repository
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# Check out the tracked dotfiles into your home directory
config checkout
```

If `config checkout` fails because of existing untracked files, see
[Resolving checkout conflicts](#resolving-checkout-conflicts) below, then
retry `config checkout`.

Once the checkout succeeds, run the bootstrap script:

```bash
~/scripts/bootstrap.sh
```

`bootstrap.sh` is idempotent — safe to re-run any time, including after
pulling new dotfiles changes. It:

- installs [Oh My Zsh](https://ohmyz.sh/) if `~/.oh-my-zsh` isn't already present
- installs Homebrew (if missing and you have admin rights) and runs
  `brew bundle` against `Brewfile`, skipping with a warning if neither
  condition is met
- applies local git-config fixups for the `.cfg` repo (`core.excludesfile`
  pointing at `~/.gitignore_global`, `status.showUntrackedFiles no`)
- tightens `~/.zshrc.local` to mode `600` if that file exists

It intentionally does *not* create `~/.zshrc.local` — that file is
untracked, workstation-specific, and may hold secrets (see
[Oh My Zsh public/private boundary](#oh-my-zsh-publicprivate-boundary)).

To verify the script's behavior without touching your real `$HOME`, run its
black-box test suite:

```bash
~/scripts/verify-bootstrap.sh
```

## Manual setup (fallback)

Everything `bootstrap.sh` does can also be done by hand, if you'd rather not
run the script or need to debug a step it's skipping.

### Initial setup (first machine)

```bash
# Initialize a bare repository in your home directory
git init --bare $HOME/.cfg

# Create an alias for Git commands targeting the dotfiles repository
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# Configure the repository to hide untracked files
config config --local status.showUntrackedFiles no

# Add the alias to your shell configuration for persistence
echo "alias config='/usr/bin/git --git-dir=\$HOME/.cfg/ --work-tree=\$HOME'" >> $HOME/.zshrc
```

### Adding and committing dotfiles

```bash
# Check the status of your dotfiles repository
config status

# Add a dotfile to the repository
config add .vimrc

# Commit the added dotfile with a message
config commit -m "Add vimrc"

# Push changes to a remote repository (ensure you've set up a remote)
config push
```

### Migrating to a new system

```bash
# Clone your dotfiles repository as a bare repository
git clone --bare <git-repo-url> $HOME/.cfg

# Define the config alias in the current shell
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# Attempt to check out the dotfiles into your home directory
config checkout
```

#### Resolving checkout conflicts

If `config checkout` fails due to existing untracked files, back up the
conflicting files:

```bash
# Create a backup directory
mkdir -p .config-backup

# Move untracked files to the backup directory
config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config-backup/{}
```

Then retry the checkout:

```bash
config checkout
```

Finally, configure the repository to hide untracked files:

```bash
config config --local status.showUntrackedFiles no
```

### Manual equivalents of the bootstrap steps

- **Oh My Zsh**: install from https://ohmyz.sh/ if `~/.oh-my-zsh` doesn't
  already exist.
- **Homebrew + packages**: install [Homebrew](https://brew.sh/) if missing,
  then run `brew bundle --file=$HOME/Brewfile`.
- **Local git-config fixups**: create `~/.gitignore_global` if it doesn't
  exist, then run
  `config config --local core.excludesfile "$HOME/.gitignore_global"` and
  `config config --local status.showUntrackedFiles no`.
- **`~/.zshrc.local` permissions**: if the file exists, `chmod 600
  ~/.zshrc.local`.

## Oh My Zsh public/private boundary

The tracked `.zshrc` contains only the portable Oh My Zsh bootstrap: the external
`~/.oh-my-zsh` checkout, the `simple` theme, the `git` plugin, and the optional
private hook. Keep workstation-specific aliases, PATH/SDK/language setup, tool
initialization, credentials, and other machine state in untracked
`~/.zshrc.local` with mode `600`. Never commit or publish credential values.

Oh My Zsh and custom completion state remain an external checkout; they are not
vendored into this repository. Installing, updating, and pinning its version is a
separate follow-up concern (`bootstrap.sh` installs it if absent, but does not
pin or update an existing checkout).

Run the bounded integration check from the home worktree:

```bash
~/scripts/verify-oh-my-zsh-split.sh
```

It exercises both startup paths, the local/private boundary, and clean/dirty Git
prompt indicators without printing secret values or mutating the dotfiles index.
