#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
tinyhpc_home="${TINYHPC_HOME:-/opt/tinyhpc}"
tinyhpc_root="${TINYHPC_ROOT:-/opt/hpc}"
lmod_init_bash=""

install_system_package() {
    local arch_name="$1" deb_name="$2" fedora_name="$3" suse_name="$4"
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed "$arch_name"
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y "$deb_name"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "$fedora_name"
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper --non-interactive install "$suse_name"
    else
        echo "ERROR: gerenciador de pacotes não suportado." >&2
        return 1
    fi
}

if ! command -v fish >/dev/null 2>&1; then
    echo "==> Fish não encontrado; instalando runtime do TinyHPC"
    install_system_package fish fish fish fish
fi

try_init_lmod() {
    if type module >/dev/null 2>&1; then
        return 0
    fi
    local candidate base
    for candidate in /etc/profile.d/modules.sh /etc/profile.d/lmod.sh /usr/share/lmod/lmod/init/bash /usr/local/lmod/lmod/init/bash; do
        if [[ -f "$candidate" ]]; then
            # shellcheck disable=SC1090
            source "$candidate"
            if type module >/dev/null 2>&1; then
                lmod_init_bash="$candidate"
                return 0
            fi
        fi
    done
    for base in /usr/share/lmod /usr/local/lmod; do
        if [[ -d "$base" ]]; then
            candidate="$(find "$base" -type f -path '*/init/bash' -print -quit 2>/dev/null || true)"
            if [[ -n "$candidate" ]]; then
                # shellcheck disable=SC1090
                source "$candidate"
                if type module >/dev/null 2>&1; then
                    lmod_init_bash="$candidate"
                    return 0
                fi
            fi
        fi
    done
    return 1
}

if ! try_init_lmod; then
    echo "==> Lmod não encontrado; instalando dependência do TinyHPC"
    install_system_package lmod lmod Lmod lmod
    try_init_lmod || { echo "ERROR: Lmod instalado, mas não foi possível inicializá-lo." >&2; exit 1; }
else
    echo "==> Lmod já disponível"
fi

if [[ -z "$lmod_init_bash" ]]; then
    for candidate in /etc/profile.d/modules.sh /etc/profile.d/lmod.sh /usr/share/lmod/lmod/init/bash /usr/local/lmod/lmod/init/bash; do
        [[ -f "$candidate" ]] && { lmod_init_bash="$candidate"; break; }
    done
fi

# Instala uma cópia do gerenciador separada do clone de desenvolvimento.
if [[ "$(realpath "$repo_root")" != "$(realpath -m "$tinyhpc_home")" ]]; then
    echo "==> instalando TinyHPC em $tinyhpc_home"
    sudo rm -rf "$tinyhpc_home"
    sudo mkdir -p "$tinyhpc_home"
    tar --exclude=.git -C "$repo_root" -cf - . | sudo tar -C "$tinyhpc_home" -xf -
fi
sudo chmod +x "$tinyhpc_home/bin/hpc" "$tinyhpc_home/bootstrap.sh" "$tinyhpc_home/bootstrap.fish"
sudo mkdir -p /usr/local/bin
sudo ln -sfn "$tinyhpc_home/bin/hpc" /usr/local/bin/hpc

sudo mkdir -p "$tinyhpc_root"/{cache,src,build,software,modulefiles,logs}
sudo chown -R "$USER:$(id -gn)" "$tinyhpc_root"

mkdir -p "$HOME/.config/tinyhpc"
conf="$HOME/.config/tinyhpc/bashrc"
{
    echo "# gerado por TinyHPC"
    printf 'export TINYHPC_HOME=%q\n' "$tinyhpc_home"
    printf 'export TINYHPC_ROOT=%q\n' "$tinyhpc_root"
    printf 'export TINYHPC_REPO=%q\n' "$tinyhpc_home"
    printf 'export HPC_ROOT=%q\n' "$tinyhpc_root"
    if [[ -n "$lmod_init_bash" ]]; then
        echo 'if ! type module >/dev/null 2>&1; then'
        printf '    source %q\n' "$lmod_init_bash"
        echo 'fi'
    fi
    printf 'module use %q\n' "$tinyhpc_root/modulefiles"
} > "$conf"

bashrc="$HOME/.bashrc"
source_line='[[ -f "$HOME/.config/tinyhpc/bashrc" ]] && source "$HOME/.config/tinyhpc/bashrc"'
if ! grep -Fqx "$source_line" "$bashrc" 2>/dev/null; then
    printf '\n# TinyHPC\n%s\n' "$source_line" >> "$bashrc"
fi

export TINYHPC_HOME="$tinyhpc_home" TINYHPC_ROOT="$tinyhpc_root" TINYHPC_REPO="$tinyhpc_home" HPC_ROOT="$tinyhpc_root"
module use "$tinyhpc_root/modulefiles"

echo "==> TinyHPC instalado em $tinyhpc_home"
echo "==> CLI: /usr/local/bin/hpc"
echo "==> stack HPC: $tinyhpc_root"
echo "==> configuração Bash: $conf"
echo "==> Lmod: $(module --version 2>&1 | head -n1)"
echo "Rode: source '$conf'"
