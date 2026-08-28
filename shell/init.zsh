# TinyHPC user interface for Zsh. Source this file; do not execute it.

# %N is the source path of the current script in Zsh; :A resolves symlinks
# and :h:h yields the repo root. Then default TINYHPC_CONFIG when unset.
_tinyhpc_init="${(%):-%N}"
_tinyhpc_home="${${_tinyhpc_init:A}:h:h}"
_tinyhpc_default_config="${XDG_CONFIG_HOME:-$HOME/.config}/tinyhpc/config.toml"
if [[ -z "${TINYHPC_CONFIG:-}" && -f "$_tinyhpc_default_config" ]]; then
    export TINYHPC_CONFIG="$_tinyhpc_default_config"
fi
# Load the environment computed by the CLI into this shell.
eval "$("$_tinyhpc_home/bin/hpc" env --shell zsh)"

# Fall back to sourcing a system Lmod init script if "module" is unavailable.
if ! type module >/dev/null 2>&1; then
    for _tinyhpc_lmod in \
        /etc/profile.d/modules.sh \
        /etc/profile.d/lmod.sh \
        /usr/share/lmod/lmod/init/zsh \
        /usr/local/lmod/lmod/init/zsh
    do
        if [[ -f "$_tinyhpc_lmod" ]]; then
            source "$_tinyhpc_lmod"
            type module >/dev/null 2>&1 && break
        fi
    done
fi

if type module >/dev/null 2>&1; then
    module use "$HPC_MODULEFILES"
else
    print -u2 'TinyHPC: Lmod não foi inicializado para Zsh'
fi

unset _tinyhpc_init _tinyhpc_home _tinyhpc_default_config _tinyhpc_lmod
