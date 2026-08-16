# Portable Oh My Zsh startup.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="simple"
plugins=(git)

source "$ZSH/oh-my-zsh.sh"

if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
