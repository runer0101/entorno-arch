#  ╔═╗╔═╗╦ ╦╦═╗╔═╗  ╔═╗╔═╗╔╗╔╔═╗╦╔═╗	- z0mbi3
#  ╔═╝╚═╗╠═╣╠╦╝║    ║  ║ ║║║║╠╣ ║║ ╦	- https://github.com/gh0stzk/dotfiles
#  ╚═╝╚═╝╩ ╩╩╚═╚═╝  ╚═╝╚═╝╝╚╝╚  ╩╚═╝	- My zsh conf

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

#  ┬  ┬┌─┐┬─┐┌─┐
#  └┐┌┘├─┤├┬┘└─┐
#   └┘ ┴ ┴┴└─└─┘
export EDITOR='geany'
export VISUAL="${EDITOR}"
export BROWSER='brave'
export HISTORY_IGNORE="(ls|cd|pwd|exit|sudo reboot|history|cd -|cd ..)"
export SUDO_PROMPT="Deploying root access for %u. Password pls: "
export BAT_THEME="base16"

if [ -d "$HOME/bin" ] ; then PATH="$HOME/bin:$PATH"; fi
if [ -d "$HOME/.local/bin" ] ; then PATH="$HOME/.local/bin:$PATH"; fi
if [ -d "$HOME/scripts" ] ; then PATH="$HOME/scripts:$PATH"; fi

# Set LS_COLORS for completion menu (needed by zstyle below)
[[ -z "$LS_COLORS" ]] && eval "$(dircolors -b)"

#  ┬  ┌─┐┌─┐┌┬┐  ┌─┐┌┐┌┌─┐┬┌┐┌┌─┐
#  │  │ │├─┤ ││  ├┤ ││││ ┬││││├┤
#  ┴─┘└─┘┴ ┴─┴┘  └─┘┘└┘└─┘┴┘└┘└─┘
# Welcome screen: logo Arch + info del sistema (estilo opencode-venjix)
# Solo corre en sesiones interactivas (la línea 6 ya lo garantiza).
# `&!` lo lanza en background + disown: el prompt aparece al instante
# y el banner se imprime sin bloquear la escritura.
if command -v fastfetch >/dev/null 2>&1; then
    fastfetch &!
fi

autoload -Uz compinit

zcompdump="$HOME/.config/zsh/zcompdump"

if [[ -n "$zcompdump"(#qN.mh+24) ]]; then
    compinit -i -d "$zcompdump"
else
    compinit -C -d "$zcompdump"
fi

if [[ ! -f "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc" ]]; then
    zcompile -U "$zcompdump"
fi


autoload -Uz add-zsh-hook
autoload -Uz vcs_info
precmd () { vcs_info }
_comp_options+=(globdots)

zstyle ':completion:*' menu select
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' matcher-list \
		'm:{a-zA-Z}={A-Za-z}' \
		'+r:|[._-]=* r:|=*' \
		'+l:|=*'
zstyle ':vcs_info:*' formats ' %B%s-[%F{magenta}%f %F{yellow}%b%f]-'
# fzf-tab styles disabled: fzf uninstalled (uncomment if reinstalled)
# zstyle ':fzf-tab:*' fzf-flags --style=full --height=90% --pointer '>' \
#                 --color 'pointer:green:bold,bg+:-1:,fg+:green:bold,info:blue:bold,marker:yellow:bold,hl:gray:bold,hl+:yellow:bold' \
#                 --input-label ' Search ' --color 'input-border:blue,input-label:blue:bold' \
#                 --list-label ' Results ' --color 'list-border:green,list-label:green:bold' \
#                 --preview-label ' Preview ' --color 'preview-border:magenta,preview-label:magenta:bold'
# zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons=always --color=always -a $realpath'
# zstyle ':fzf-tab:complete:eza:*' fzf-preview 'eza -1 --icons=always --color=always -a $realpath'
# zstyle ':fzf-tab:complete:bat:*' fzf-preview 'bat --color=always --theme=base16 $realpath'
# zstyle ':fzf-tab:*' fzf-bindings 'space:accept'
# zstyle ':fzf-tab:*' accept-line enter

#  ┬ ┬┌─┐┬┌┬┐┬┌┐┌┌─┐  ┌┬┐┌─┐┌┬┐┌─┐
#  │││├─┤│ │ │││││ ┬   │││ │ │ └─┐
#  └┴┘┴ ┴┴ ┴ ┴┘└┘└─┘  ─┴┘└─┘ ┴ └─┘
expand-or-complete-with-dots() {
  echo -n "\e[31m…\e[0m"
  zle expand-or-complete
  zle redisplay
}
zle -N expand-or-complete-with-dots
bindkey "^I" expand-or-complete-with-dots

#  ┬ ┬┬┌─┐┌┬┐┌─┐┬─┐┬ ┬
#  ├─┤│└─┐ │ │ │├┬┘└┬┘
#  ┴ ┴┴└─┘ ┴ └─┘┴└─ ┴
HISTFILE=~/.config/zsh/zhistory
HISTSIZE=5000
SAVEHIST=5000
HISTDUP=erase
setopt inc_append_history
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Descartar comandos sospechosos que rompen el historial:
# - líneas >500 chars (pegado accidental de JSON/scripts)
# - líneas que empiezan con '{' (objetos JSON)
# - líneas que contienen ESC (bytes de control que zsh rechaza)
zshaddhistory() {
    local line=${1%%$'\n'}
    [[ ${#line} -gt 500 ]] && return 1
    [[ $line == \{* ]] && return 1
    [[ $line == *$'\e'* ]] && return 1
    return 0
}

#  ┌─┐┌─┐┬ ┬  ┌─┐┌─┐┌─┐┬    ┌─┐┌─┐┌┬┐┬┌─┐┌┐┌┌─┐
#  ┌─┘└─┐├─┤  │  │ ││ ││    │ │├─┘ │ ││ ││││└─┐
#  └─┘└─┘┴ ┴  └─┘└─┘└─┘┴─┘  └─┘┴   ┴ ┴└─┘┘└┘└─┘
setopt AUTOCD              # change directory just by typing its name
setopt PROMPT_SUBST        # enable command substitution in prompt
setopt MENU_COMPLETE       # Automatically highlight first element of completion menu
setopt LIST_PACKED		   # The completion menu takes less space.
setopt AUTO_LIST           # Automatically list choices on ambiguous completion.
setopt COMPLETE_IN_WORD    # Complete from both ends of a word.

#  ┌┬┐┬ ┬┌─┐  ┌─┐┬─┐┌─┐┌┬┐┌─┐┌┬┐
#   │ ├─┤├┤   ├─┘├┬┘│ ││││├─┘ │
#   ┴ ┴ ┴└─┘  ┴  ┴└─└─┘┴ ┴┴   ┴
function dir_icon {
  if [[ "$PWD" == "$HOME" ]]; then
    echo "%B%F{cyan}%f%b"
  else
    echo "%B%F{cyan}%f%b"
  fi
}

PS1='%B%F{blue}%f%b  %B%F{magenta}%n%f%b $(dir_icon)  %B%F{red}%~%f%b${vcs_info_msg_0_} %(?.%B%F{green}.%F{red})%f%b '

#  ┌─┐┬  ┬ ┬┌─┐┬┌┐┌┌─┐
#  ├─┘│  │ ││ ┬││││└─┐
#  ┴  ┴─┘└─┘└─┘┴┘└┘└─┘
# source /usr/share/zsh/plugins/fzf-tab-git/fzf-tab.zsh  # disabled: fzf uninstalled
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[3~' delete-char
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line

#  ┌─┐┬ ┬┌─┐┌┐┌┌─┐┌─┐  ┌┬┐┌─┐┬─┐┌┬┐┬┌┐┌┌─┐┬  ┌─┐  ┌┬┐┬┌┬┐┬  ┌─┐
#  │  ├─┤├─┤││││ ┬├┤    │ ├┤ ├┬┘│││││││├─┤│  └─┐   │ │ │ │  ├┤
#  └─┘┴ ┴┴ ┴┘└┘└─┘└─┘   ┴ └─┘┴└─┴ ┴┴┘└┘┴ ┴┴─┘└─┘   ┴ ┴ ┴ ┴─┘└─┘
function xterm_title_precmd () {
	print -Pn -- '\e]2;%n@%m %~\a'
	[[ "$TERM" == 'screen'* ]] && print -Pn -- '\e_\005{g}%n\005{-}@\005{m}%m\005{-} \005{B}%~\005{-}\e\\'
}

function xterm_title_preexec () {
	print -Pn -- '\e]2;%n@%m %~ %# ' && print -n -- "${(q)1}\a"
	[[ "$TERM" == 'screen'* ]] && { print -Pn -- '\e_\005{g}%n\005{-}@\005{m}%m\005{-} \005{B}%~\005{-} %# ' && print -n -- "${(q)1}\e\\"; }
}

if [[ "$TERM" == (kitty*|alacritty*|tmux*|screen*|xterm*) ]]; then
	add-zsh-hook -Uz precmd xterm_title_precmd
	add-zsh-hook -Uz preexec xterm_title_preexec
fi

#  ┌─┐┬  ┬┌─┐┌─┐
#  ├─┤│  │├─┤└─┐
#  ┴ ┴┴─┘┴┴ ┴└─┘
alias mirrors="sudo reflector --verbose --latest 5 --country 'United States' --age 6 --sort rate --save /etc/pacman.d/mirrorlist"
alias update="paru -Syu --nocombinedupgrade"
alias grub-update="sudo grub-mkconfig -o /boot/grub/grub.cfg"

alias music="ncmpcpp"

alias cat="bat --theme=base16"
alias ls='eza --icons=always --color=always -a'
alias ll='eza --icons=always --color=always -la'

#  ┌─┐┬ ┬┌┬┐┌─┐  ┌─┐┌┬┐┌─┐┬─┐┌┬┐
#  ├─┤│ │ │ │ │  └─┐ │ ├─┤├┬┘ │
#  ┴ ┴└─┘ ┴ └─┘  └─┘ ┴ ┴ ┴┴└─ ┴
# $HOME/.local/bin/colorscript -r  # disabled: añade latencia al primer prompt



# fzf: usa fd con ~/.fdignore para exclusiones
export FZF_CTRL_T_COMMAND="fd . $HOME --type f --type d --hidden --follow"
export FZF_ALT_C_COMMAND="fd . $HOME --type d --hidden --follow"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Widget Alt+B: directorio → cd, archivo → inserta path
# Busca en todo el sistema, excluyendo solo basura
fzf-file-or-dir-widget() {
  setopt localoptions pipefail no_aliases 2> /dev/null
  local selected
  selected="$(
    FZF_DEFAULT_COMMAND=${FZF_ALT_B_COMMAND:-'fd . / --type f --type d --hidden --follow --max-depth 8 --exclude /proc --exclude /sys --exclude /run --exclude /dev --exclude /var/lib --exclude /var/cache --exclude /tmp --exclude /snap --exclude /lost+found --exclude node_modules --exclude .git --exclude .cache --exclude __pycache__'} \
    FZF_DEFAULT_OPTS=$(__fzf_defaults "--reverse --scheme=path" "${FZF_ALT_B_OPTS-} +m") \
    FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd) < /dev/tty
  )" || { zle redisplay; return 0; }
  [[ -z "$selected" ]] && { zle redisplay; return 0; }
  if [[ -d "$selected" ]]; then
    zle push-line
    BUFFER="builtin cd -- ${(q)selected}"
    zle accept-line
  else
    LBUFFER="${LBUFFER}${selected} "
  fi
  zle reset-prompt
}
zle -N fzf-file-or-dir-widget
bindkey '\eb' fzf-file-or-dir-widget

# Desactivar Alt+C (lo reemplaza Alt+B unificado)
bindkey -r '\ec'
bindkey -M vicmd -r '\ec'
bindkey -M viins -r '\ec'

# NVM lazy-load: nvm.sh carga ~316 ms en cada shell (90% del arranque).
# En lugar de sourcearlo eagerly, definimos stubs que cargan el real
# en el primer uso. Después de la primera invocación, los stubs se borran
# y todo funciona igual que antes. Ganancia: ~280-310 ms.
export NVM_DIR="$HOME/apps/node/.nvm"

_nvm_load() {
  unset -f nvm node npm npx pnpm yarn corepack 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}

# Si nvm está instalado, registrar stubs; si no, no hacer nada.
if [ -s "$NVM_DIR/nvm.sh" ]; then
  nvm()    { _nvm_load; nvm "$@"; }
  node()   { _nvm_load; node "$@"; }
  npm()    { _nvm_load; npm "$@"; }
  npx()    { _nvm_load; npx "$@"; }
  pnpm()   { _nvm_load; pnpm "$@"; }
  yarn()   { _nvm_load; yarn "$@"; }
  corepack(){ _nvm_load; corepack "$@"; }
fi
export CARGO_HOME="$HOME/apps/rust/.cargo"
export RUSTUP_HOME="$HOME/apps/rust/.rustup"
export BUN_INSTALL="$HOME/apps/bun"
# OLLAMA_MODELS se deja SIN exportar a propósito (1 ago 2026).
# Apuntaba a $HOME/apps/ollama/models, que está vacío: los modelos de verdad
# (26 GB) viven en /home/ollama-models, que es lo que declara el servicio en
# /etc/systemd/system/ollama.service.d/models.conf y es de ollama:ollama, así que
# este usuario ni siquiera puede escribir ahí. Como el cliente `ollama` habla por
# HTTP con el servidor, la variable no cambiaba nada en la práctica; solo despista
# a quien mire el entorno y rompería un `ollama serve` lanzado a mano (arrancaría
# sin ningún modelo). Si algún día montás un servidor propio de usuario, ponela
# aquí de nuevo apuntando a una ruta tuya.
# export OLLAMA_MODELS="$HOME/apps/ollama/models"
export PATH="$PATH:__HOME__/go/bin"

# pnpm como único gestor de paquetes (preferencia del usuario)
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"

# SSH agent: ahora lo provee gnome-keyring (ver ~/.config/bspwm/bspwmrc).
# Si por alguna razon SSH_AUTH_SOCK no esta seteado (ej. en TTY sin sesion grafica),
# iniciamos un agent de respaldo.
if [ -z "$SSH_AUTH_SOCK" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
  SSH_AGENT_SOCKET="$HOME/.ssh/agent.sock"
  if [ ! -S "$SSH_AGENT_SOCKET" ]; then
    ssh-agent -a "$SSH_AGENT_SOCKET" >/dev/null 2>&1
  fi
  export SSH_AUTH_SOCK="$SSH_AGENT_SOCKET"
fi

# opencode (binario real — los wrappers en ~/.local/bin vienen antes vía reorden al final)
export PATH=__HOME__/.opencode/bin:$PATH

# Reorden final: ~/.local/bin (wrappers opencode/opencode-venjix) antes que ~/.opencode/bin
# para que los wrappers se ejecuten primero
export PATH="$HOME/.local/bin:$PATH"

# OpenCode: subagentes asíncronos (ctrl+B / btw) — pedido por el instalador de gentle-ai
export OPENCODE_EXPERIMENTAL=true
alias avd='__HOME__/bin/avd'
alias gpu="prime-run"



waydroid_on() {
    echo "Verificando estado de Waydroid..."
    local wd_status=$(sudo waydroid status 2>/dev/null)
    if echo "$wd_status" | grep -q "STOPPED"; then
        echo "Iniciando contenedor..."
        sudo systemctl restart waydroid-container
        sleep 3
    fi
    echo "Iniciando sesion de Android..."
    setsid nohup waydroid session start < /dev/null > /tmp/waydroid_session.log 2>&1 &
    disown
    echo "Esperando a que Android termine de registrar servicios..."
    local tries=0
    while ! grep -q "is ready" /tmp/waydroid_session.log 2>/dev/null; do
        sleep 1
        tries=$((tries + 1))
        if [ "$tries" -gt 30 ]; then
            echo "Waydroid no arranco en 30 segundos. Revisa: waydroid log"
            return 1
        fi
    done
    echo "Android listo. Abriendo interfaz..."
    setsid nohup waydroid show-full-ui < /dev/null > /tmp/waydroid_ui.log 2>&1 &
    disown
    sleep 2
    hyprctl dispatch 'hl.dsp.focus({ window = "class:Waydroid" })' 2>/dev/null
    echo "Waydroid iniciado. Puedes cerrar esta terminal sin problema."
}

waydroid_off() {
    echo "Cerrando Waydroid..."
    waydroid session stop
    sudo systemctl stop waydroid-container
    echo "Waydroid cerrado."
}
[ -f ~/.secrets/keys.env ] && source ~/.secrets/keys.env

# Reparar Waydroid (v2: apply/diagnose/doctor/restart/log/...)
alias wr='bash ~/.config/waydroid-custom/wr'

# MiniMax Code CLI
export PATH="__HOME__/.minimax-code/bin:$PATH"
