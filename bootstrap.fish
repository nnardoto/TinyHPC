#!/usr/bin/env fish

set repo_root (realpath (dirname (status filename)))
set tinyhpc_home /opt/tinyhpc
set tinyhpc_root /opt/hpc
set -q TINYHPC_HOME; and set tinyhpc_home $TINYHPC_HOME
set -q TINYHPC_ROOT; and set tinyhpc_root $TINYHPC_ROOT

function install_lmod
    echo "==> Lmod não encontrado; instalando dependência do TinyHPC"
    if type -q pacman
        sudo pacman -S --needed lmod; or return 1
    else if type -q apt-get
        sudo apt-get update; and sudo apt-get install -y lmod; or return 1
    else if type -q dnf
        sudo dnf install -y Lmod; or return 1
    else if type -q zypper
        sudo zypper --non-interactive install lmod; or return 1
    else
        echo "ERROR: gerenciador de pacotes não suportado para instalar Lmod." >&2
        return 1
    end
end

function try_init_lmod
    if type -q module
        return 0
    end

    for candidate in \
        /usr/share/fish/vendor_conf.d/modules.fish \
        /etc/fish/conf.d/modules.fish \
        /usr/share/lmod/lmod/init/fish \
        /usr/local/lmod/lmod/init/fish
        if test -f $candidate
            source $candidate
            if type -q module
                set -g lmod_init_fish $candidate
                return 0
            end
        end
    end

    for base in /usr/share/lmod /usr/local/lmod
        if test -d $base
            set candidate (find $base -type f -path '*/init/fish' 2>/dev/null | head -n1)
            if test -n "$candidate"
                source $candidate
                if type -q module
                    set -g lmod_init_fish $candidate
                    return 0
                end
            end
        end
    end
    return 1
end

if not try_init_lmod
    install_lmod; or exit 1
    try_init_lmod; or begin
        echo "ERROR: Lmod instalado, mas não foi possível inicializá-lo para Fish." >&2
        exit 1
    end
else
    echo "==> Lmod já disponível"
end

if not set -q lmod_init_fish
    for candidate in \
        /usr/share/fish/vendor_conf.d/modules.fish \
        /etc/fish/conf.d/modules.fish \
        /usr/share/lmod/lmod/init/fish \
        /usr/local/lmod/lmod/init/fish
        if test -f $candidate
            set -g lmod_init_fish $candidate
            break
        end
    end
end

# Instala uma cópia do gerenciador separada do clone de desenvolvimento.
if test (realpath $repo_root) != (realpath -m $tinyhpc_home)
    echo "==> instalando TinyHPC em $tinyhpc_home"
    sudo rm -rf $tinyhpc_home; or exit 1
    sudo mkdir -p $tinyhpc_home; or exit 1
    tar --exclude=.git -C $repo_root -cf - . | sudo tar -C $tinyhpc_home -xf -; or exit 1
end

sudo chmod +x $tinyhpc_home/bin/hpc $tinyhpc_home/bootstrap.fish $tinyhpc_home/bootstrap.sh; or exit 1
sudo mkdir -p /usr/local/bin; or exit 1
sudo ln -sfn $tinyhpc_home/bin/hpc /usr/local/bin/hpc; or exit 1

sudo mkdir -p $tinyhpc_root/{cache,src,build,software,modulefiles,logs}; or exit 1
sudo chown -R "$USER:"(id -gn) $tinyhpc_root; or exit 1

mkdir -p ~/.config/fish/conf.d
set conf ~/.config/fish/conf.d/tinyhpc.fish
begin
    echo "# gerado por TinyHPC"
    echo "set -gx TINYHPC_HOME '$tinyhpc_home'"
    echo "set -gx TINYHPC_ROOT '$tinyhpc_root'"
    echo "set -gx TINYHPC_REPO '$tinyhpc_home'"
    echo "set -gx HPC_ROOT '$tinyhpc_root'  # compatibilidade"
    if set -q lmod_init_fish
        echo "if not type -q module"
        echo "    source '$lmod_init_fish'"
        echo "end"
    end
    echo "module use '$tinyhpc_root/modulefiles'"
end > $conf

set -gx TINYHPC_HOME $tinyhpc_home
set -gx TINYHPC_ROOT $tinyhpc_root
set -gx TINYHPC_REPO $tinyhpc_home
set -gx HPC_ROOT $tinyhpc_root
module use $tinyhpc_root/modulefiles

echo "==> TinyHPC instalado em $tinyhpc_home"
echo "==> CLI: /usr/local/bin/hpc"
echo "==> stack HPC: $tinyhpc_root"
echo "==> configuração Fish: $conf"
echo "==> Lmod: "(module --version 2>&1 | head -n1)
echo "Rode: source $conf"
