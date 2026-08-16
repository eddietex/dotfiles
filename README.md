Reference article for using this system: https://www.atlassian.com/git/tutorials/dotfiles
# Article Contents summary:

# Managing Dotfiles with a Bare Git Repository

[Original article from Atlassian](https://www.atlassian.com/git/tutorials/dotfiles)

Dotfiles are configuration files in Unix-like systems, often residing in the home directory and prefixed with a dot (e.g., `.bashrc`, `.vimrc`). Tracking these files using Git allows for consistent configurations across multiple systems.

## Initial Setup

To begin tracking your dotfiles using a bare Git repository:

```bash
# Initialize a bare repository in your home directory
git init --bare $HOME/.cfg

# Create an alias for Git commands targeting the dotfiles repository
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# Configure the repository to hide untracked files
config config --local status.showUntrackedFiles no

# Add the alias to your shell configuration for persistence
echo "alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'" >> $HOME/.bashrc
```

## Adding and Committing Dotfiles

With the `config` alias set up, you can manage your dotfiles as follows:

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

## Migrating to a New System

To replicate your dotfiles setup on a new machine:

```bash
# Clone your dotfiles repository as a bare repository
git clone --bare <git-repo-url> $HOME/.cfg

# Define the config alias in the current shell
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# Attempt to check out the dotfiles into your home directory
config checkout
```

If the `config checkout` command fails due to existing untracked files, back up the conflicting files:

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

## Oh My Zsh public/private boundary

The tracked `.zshrc` contains only the portable Oh My Zsh bootstrap: the external
`~/.oh-my-zsh` checkout, the `simple` theme, the `git` plugin, and the optional
private hook. Keep workstation-specific aliases, PATH/SDK/language setup, tool
initialization, credentials, and other machine state in untracked
`~/.zshrc.local` with mode `600`. Never commit or publish credential values.

Oh My Zsh and custom completion state remain an external checkout; they are not
vendored into this repository. Installing, updating, and pinning its version is a
separate follow-up concern.

Run the bounded integration check from the home worktree:

```bash
~/scripts/verify-oh-my-zsh-split.sh
```

It exercises both startup paths, the local/private boundary, and clean/dirty Git
prompt indicators without printing secret values or mutating the dotfiles index.
