# TinyHPC user interface for Bash. Source this file; do not execute it.

_tinyhpc_home="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
_tinyhpc_default_config="${XDG_CONFIG_HOME:-$HOME/.config}/tinyhpc/config.toml"
if [[ -z "${TINYHPC_CONFIG:-}" && -f "$_tinyhpc_default_config" ]]; then
    export TINYHPC_CONFIG="$_tinyhpc_default_config"
fi
eval "$("$_tinyhpc_home/bin/hpc" env --shell bash)"

if ! type module >/dev/null 2>&1; then
    for _tinyhpc_lmod in \
        /etc/profile.d/modules.sh \
        /etc/profile.d/lmod.sh \
        /usr/share/lmod/lmod/init/bash \
        /usr/local/lmod/lmod/init/bash
    do
        if [[ -f "$_tinyhpc_lmod" ]]; then
            # shellcheck disable=SC1090
            source "$_tinyhpc_lmod"
            type module >/dev/null 2>&1 && break
        fi
    done
fi

if type module >/dev/null 2>&1; then
    module use "$HPC_MODULEFILES"
else
    printf 'TinyHPC: Lmod não foi inicializado para Bash\n' >&2
fi

unset _tinyhpc_home _tinyhpc_default_config _tinyhpc_lmod
