#!/usr/bin/env bash
set -euo pipefail

# Install TinyHPC: ensure Lmod, copy the tree into TINYHPC_HOME, create the
# HPC directory layout, and register per-shell integration files.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
lmod_init_bash=""

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

find_python() {
    local candidate
    for candidate in python3.13 python3.12 python3.11 python3.10 python3.9 python3; do
        command -v "$candidate" >/dev/null 2>&1 || continue
        if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    die "Python 3.9 ou mais recente não encontrado"
}

python="$(find_python)"

# Normalize a path via Python so expansion/resolution matches the CLI's view.
canonical_path() {
    "$python" -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).expanduser().resolve())' "$1"
}

# Load defaults, user config, and environment overrides through the same
# parser the CLI uses; no TOML parsing is duplicated in Bash.
settings="$("$python" "$repo_root/lib/recipe.py" --repo "$repo_root" environment)"
while IFS=$'\t' read -r key value; do
    [[ -n "$key" ]] || continue
    printf -v "$key" '%s' "$value"
    export "$key"
done <<< "$settings"
unset settings key value

tinyhpc_home="$TINYHPC_HOME"
tinyhpc_root="$TINYHPC_ROOT"
tinyhpc_bin="${TINYHPC_BIN:-/usr/local/bin/hpc}"
tinyhpc_sudo="${TINYHPC_SUDO-sudo}"

privileged() {
    if [[ -n "$tinyhpc_sudo" ]]; then
        "$tinyhpc_sudo" "$@"
    else
        "$@"
    fi
}

install_system_package() {
    local arch_name="$1" deb_name="$2" fedora_name="$3" suse_name="$4"
    if command -v pacman >/dev/null 2>&1; then
        privileged pacman -S --needed "$arch_name"
    elif command -v apt-get >/dev/null 2>&1; then
        privileged apt-get update
        privileged apt-get install -y "$deb_name"
    elif command -v dnf >/dev/null 2>&1; then
        privileged dnf install -y "$fedora_name"
    elif command -v zypper >/dev/null 2>&1; then
        privileged zypper --non-interactive install "$suse_name"
    else
        die "gerenciador de pacotes não suportado"
    fi
}

# Locate and source an Lmod init script, recording its path for reuse below.
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

# Ensure Lmod exists: reuse a system install if found, otherwise install the
# distribution package and initialize it.
if ! try_init_lmod; then
    echo "==> Lmod não encontrado; instalando dependência do TinyHPC"
    install_system_package lmod lmod Lmod lmod
    try_init_lmod || die "Lmod instalado, mas não foi possível inicializá-lo"
else
    echo "==> Lmod já disponível"
fi

if [[ -z "$lmod_init_bash" ]]; then
    for candidate in /etc/profile.d/modules.sh /etc/profile.d/lmod.sh /usr/share/lmod/lmod/init/bash /usr/local/lmod/lmod/init/bash; do
        [[ -f "$candidate" ]] && { lmod_init_bash="$candidate"; break; }
    done
fi

# Copy the repository into TINYHPC_HOME unless it is already installed there.
if [[ "$(canonical_path "$repo_root")" != "$(canonical_path "$tinyhpc_home")" ]]; then
    echo "==> instalando TinyHPC em $tinyhpc_home"
    privileged rm -rf "$tinyhpc_home"
    privileged mkdir -p "$tinyhpc_home"
    tar --exclude=.git -C "$repo_root" -cf - . | privileged tar -C "$tinyhpc_home" -xf -
fi
privileged chmod +x "$tinyhpc_home/bin/hpc" "$tinyhpc_home/bootstrap.sh"
privileged mkdir -p "$(dirname "$tinyhpc_bin")"
privileged ln -sfn "$tinyhpc_home/bin/hpc" "$tinyhpc_bin"

privileged mkdir -p "$tinyhpc_root"/{cache,src,build,software,modulefiles,logs}
if [[ -n "$tinyhpc_sudo" || $EUID -eq 0 ]]; then
    privileged chown -R "$USER:$(id -gn)" "$tinyhpc_root"
fi

# Seed a user config.toml on first run; an existing config is left untouched.
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
config_path="${TINYHPC_CONFIG:-$config_home/tinyhpc/config.toml}"
mkdir -p "$(dirname "$config_path")"
quote() { "$python" -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$1"; }
if [[ ! -f "$config_path" ]]; then
    {
        echo "schema = 1"
        echo
        echo "[paths]"
        printf 'home = %s\n' "$(quote "$tinyhpc_home")"
        printf 'root = %s\n' "$(quote "$tinyhpc_root")"
        echo
        echo "[build]"
        printf 'jobs = %s\n' "$HPC_JOBS"
        printf 'profile = %s\n' "$(quote "$HPC_PROFILE")"
    } > "$config_path"
    echo "==> configuração criada em $config_path"
else
    echo "==> configuração existente preservada em $config_path"
fi

# Generate per-shell wrapper files that set TINYHPC_CONFIG and source the
# matching init script.
interface_dir="$config_home/tinyhpc"
conf_bash="$interface_dir/bashrc"
conf_zsh="$interface_dir/zshrc"
conf_fish="$interface_dir/fish.fish"

{
    echo "# gerado por TinyHPC"
    printf 'export TINYHPC_CONFIG=%q\n' "$config_path"
    printf 'source %q\n' "$tinyhpc_home/shell/init.bash"
} > "$conf_bash"
{
    echo "# gerado por TinyHPC"
    printf 'export TINYHPC_CONFIG=%q\n' "$config_path"
    printf 'source %q\n' "$tinyhpc_home/shell/init.zsh"
} > "$conf_zsh"
{
    echo "# gerado por TinyHPC"
    printf 'set -gx TINYHPC_CONFIG %s\n' "$(quote "$config_path")"
    printf 'source %s\n' "$(quote "$tinyhpc_home/shell/init.fish")"
} > "$conf_fish"

# Append a "source" line to a shell rc file only if it is not already present.
append_source_line() {
    local rc_file="$1" source_file="$2" line
    printf -v line 'source %q' "$source_file"
    if ! grep -Fqx "$line" "$rc_file" 2>/dev/null; then
        printf '\n# TinyHPC\n%s\n' "$line" >> "$rc_file"
    fi
}

append_source_line "$HOME/.bashrc" "$conf_bash"
append_source_line "$HOME/.zshrc" "$conf_zsh"
fish_conf_dir="$config_home/fish/conf.d"
mkdir -p "$fish_conf_dir"
printf 'source %s\n' "$(quote "$conf_fish")" > "$fish_conf_dir/tinyhpc.fish"

# Apply the environment inside this bootstrap process before querying Lmod.
export TINYHPC_CONFIG="$config_path"
eval "$("$tinyhpc_home/bin/hpc" env)"
module use "$HPC_MODULEFILES"

echo "==> TinyHPC instalado em $TINYHPC_HOME"
echo "==> CLI: $tinyhpc_bin"
echo "==> stack HPC: $TINYHPC_ROOT"
echo "==> configuração TOML: $config_path"
echo "==> interface Bash: $conf_bash"
echo "==> interface Zsh: $conf_zsh"
echo "==> interface Fish: $conf_fish"
echo "==> Lmod: $(module --version 2>&1 | head -n1)"
echo "Bash: source '$conf_bash'"
echo "Zsh:  source '$conf_zsh'"
echo "Fish: source '$conf_fish'"
