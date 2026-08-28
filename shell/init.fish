# TinyHPC user interface for Fish. Source this file; do not execute it.

# Wrap everything in a function so local variables do not leak into the
# user's shell; the function is erased at the end.
function __tinyhpc_initialize
    set -l tinyhpc_home (realpath (dirname (status filename))/..)
    # Set a default TINYHPC_CONFIG from the XDG path if none is set.
    if not set -q TINYHPC_CONFIG
        if set -q XDG_CONFIG_HOME
            set -l default_config $XDG_CONFIG_HOME/tinyhpc/config.toml
        else
            set -l default_config $HOME/.config/tinyhpc/config.toml
        end
        if test -f $default_config
            set -gx TINYHPC_CONFIG $default_config
        end
    end

    # Evaluate the environment emitted by the CLI into the current shell.
    $tinyhpc_home/bin/hpc env --shell fish | source

    complete -c hpc -f
    complete -c hpc -s h -l help -d 'Exibe a ajuda'
    complete -c hpc -n 'not __fish_seen_subcommand_from list installed info compilers compiler resolve config env plan validate new lock install clean remove doctor help' -a 'list installed info compilers compiler resolve config env plan validate new lock install clean remove doctor help'
    complete -c hpc -n '__fish_seen_subcommand_from info resolve plan validate lock install clean' -a '(hpc list 2>/dev/null)'
    complete -c hpc -n '__fish_seen_subcommand_from remove' -a '(hpc installed 2>/dev/null)'
    complete -c hpc -n '__fish_seen_subcommand_from compiler' -a '(hpc compilers 2>/dev/null | string trim | string replace -r "^\\*? +" "") --clear'
    complete -c hpc -n '__fish_seen_subcommand_from env' -a '--shell bash zsh fish'
    complete -c hpc -n '__fish_seen_subcommand_from new' -a '--build-system autotools cmake make script'

    # Fall back to sourcing a system Lmod init script if "module" is unavailable.
    if not type -q module
        for lmod_init in \
            /usr/share/fish/vendor_conf.d/modules.fish \
            /etc/fish/conf.d/modules.fish \
            /usr/share/lmod/lmod/init/fish \
            /usr/local/lmod/lmod/init/fish
            if test -f $lmod_init
                source $lmod_init
                type -q module; and break
            end
        end
    end

    if type -q module
        module use $HPC_MODULEFILES
    else
        echo 'TinyHPC: Lmod não foi inicializado para Fish' >&2
    end
end

__tinyhpc_initialize
functions -e __tinyhpc_initialize
