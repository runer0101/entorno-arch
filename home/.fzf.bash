# Setup fzf
# ---------
# Usa el fzf instalado en apps/fzf/.fzf (path absoluto, no depende del
# symlink ~/.fzf que fue eliminado al limpiar la $HOME).
FZF_PREFIX="__HOME__/apps/fzf/.fzf"

if [[ ! "$PATH" == *"$FZF_PREFIX/bin"* ]]; then
  PATH="${PATH:+${PATH}:}$FZF_PREFIX/bin"
fi

# Genera los bindings de bash via el binario fzf (estable, no se rompe con
# updates como el eval embebido).
eval "$("$FZF_PREFIX/bin/fzf" --bash)"
