#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Apps centralizadas en ~/apps/ (data real, no symlinks)
export CARGO_HOME="$HOME/apps/rust/.cargo"
export RUSTUP_HOME="$HOME/apps/rust/.rustup"
export NVM_DIR="$HOME/apps/node/.nvm"
export BUN_INSTALL="$HOME/apps/bun"
export OLLAMA_MODELS="$HOME/apps/ollama/.ollama/models"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export PATH="__HOME__/.local/bin:__HOME__/scripts:__HOME__/apps/opencode/.opencode/bin:__HOME__/apps/rust/.cargo/bin:$PATH"
export PATH="$PATH:__HOME__/.opencode/bin"
export PATH="$PATH:$HOME/apps/node/.npm/bin"
export PATH="$PATH:$HOME/go/bin"

# Reorden final: ~/.local/bin (wrappers opencode/opencode-max) ANTES que ~/.opencode/bin
# Esto asegura que `opencode` ejecute el wrapper, no el binario directo
export PATH="$HOME/.local/bin:$PATH"

# Scripts propios en ~/scripts: pantalla.sh, info-wifi.sh, refrigeracion.sh

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
alias avd='__HOME__/bin/avd'


# Added by MiniMax Code
export PATH="__HOME__/.minimax/bin:$PATH"
