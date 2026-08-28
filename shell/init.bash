# TinyHPC user interface for Bash. Source this file; do not execute it.

# Derive the repo path from this script and default TINYHPC_CONFIG to the
# per-user config when unset.
_tinyhpc_home="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
_tinyhpc_default_config="${XDG_CONFIG_HOME:-$HOME/.config}/tinyhpc/config.toml"
if [[ -z "${TINYHPC_CONFIG:-}" && -f "$_tinyhpc_default_config" ]]; then
    export TINYHPC_CONFIG="$_tinyhpc_default_config"
fi
# Load the environment computed by the CLI into this shell.
eval "$("$_tinyhpc_home/bin/hpc" env --shell bash)"

_tinyhpc_complete() {
    local current command output
    local commands="-h --help list installed info compilers compiler resolve config env plan validate new lock install clean remove doctor help"
    current="${COMP_WORDS[COMP_CWORD]}"

    if (( COMP_CWORD == 1 )); then
        COMPREPLY=($(compgen -W "$commands" -- "$current"))
        return
    fi

    command="${COMP_WORDS[1]}"
    case "$command" in
        compiler)
            output="$(command hpc compilers 2>/dev/null)"
            output="${output//\*/}"
            COMPREPLY=($(compgen -W "$output --clear" -- "$current"))
            ;;
        remove)
            COMPREPLY=($(compgen -W "$(command hpc installed 2>/dev/null)" -- "$current"))
            ;;
        info|resolve|plan|validate|lock|install|clean)
            COMPREPLY=($(compgen -W "$(command hpc list 2>/dev/null)" -- "$current"))
            ;;
        env)
            COMPREPLY=($(compgen -W "--shell bash zsh fish" -- "$current"))
            ;;
        new)
            COMPREPLY=($(compgen -W "--build-system autotools cmake make script" -- "$current"))
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
}
complete -F _tinyhpc_complete hpc

# Fall back to sourcing a system Lmod init script if "module" is unavailable.
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
