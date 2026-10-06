# Setup fzf
# ---------
# Usa el fzf instalado en apps/fzf/.fzf (path absoluto para no depender del
# symlink ~/.fzf, que se eliminó al limpiar la $HOME).
FZF_PREFIX="__HOME__/apps/fzf/.fzf"

if [[ ! "$PATH" == *"$FZF_PREFIX/bin"* ]]; then
  PATH="${PATH:+${PATH}:}$FZF_PREFIX/bin"
fi

# Source shell integration desde los archivos locales (parcheados para evitar
# el warning 'can't change option: zle' del eval final de fzf).
if [[ -f "$FZF_PREFIX/shell/key-bindings.zsh" ]]; then
  source "$FZF_PREFIX/shell/key-bindings.zsh"
fi
if [[ -f "$FZF_PREFIX/shell/completion.zsh" ]]; then
  source "$FZF_PREFIX/shell/completion.zsh"
fi
