# TinyHPC user interface for Fish. Source this file; do not execute it.

function __tinyhpc_initialize
    set -l tinyhpc_home (realpath (dirname (status filename))/..)
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

    $tinyhpc_home/bin/hpc env --shell fish | source

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
