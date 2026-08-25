#!/usr/bin/env bash
# Shared helpers for Bash package recipes.
# Keep behavior aligned with lib/common.fish.

hpc_die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

hpc_note() {
    printf '==> %s\n' "$*"
}

hpc_load_defaults() {
    local repo="$1" key value
    local cfg="$repo/config/defaults.conf"
    if [[ -f "$cfg" ]]; then
        while IFS='=' read -r key value; do
            key="${key#${key%%[![:space:]]*}}"
            key="${key%${key##*[![:space:]]*}}"
            value="${value#${value%%[![:space:]]*}}"
            value="${value%${value##*[![:space:]]}}"
            [[ -z "$key" || "$key" == \#* ]] && continue
            case "$key" in
                TINYHPC_HOME|TINYHPC_ROOT|HPC_JOBS|HPC_PROFILE)
                    if [[ -z "${!key+x}" ]]; then
                        printf -v "$key" '%s' "$value"
                    fi
                    ;;
            esac
        done < "$cfg"
    fi

    : "${TINYHPC_HOME:=/opt/tinyhpc}"
    : "${TINYHPC_ROOT:=/opt/hpc}"
    : "${HPC_JOBS:=4}"
    : "${HPC_PROFILE:=native}"

    export TINYHPC_HOME TINYHPC_ROOT HPC_JOBS HPC_PROFILE
    export HPC_ROOT="$TINYHPC_ROOT"  # compatibilidade
    export HPC_CACHE="$TINYHPC_ROOT/cache"
    export HPC_SRC="$TINYHPC_ROOT/src"
    export HPC_BUILD="$TINYHPC_ROOT/build"
    export HPC_SOFTWARE="$TINYHPC_ROOT/software"
    export HPC_MODULEFILES="$TINYHPC_ROOT/modulefiles"
    export HPC_LOGS="$TINYHPC_ROOT/logs"
}

hpc_read_manifest() {
    local manifest="$1"
    [[ -f "$manifest" ]] || hpc_die "manifesto não encontrado: $manifest"

    local v key value
    while IFS= read -r v; do
        unset "$v"
    done < <(compgen -A variable PKG_ || true)

    while IFS='=' read -r key value; do
        key="${key#${key%%[![:space:]]*}}"
        key="${key%${key##*[![:space:]]*}}"
        value="${value#${value%%[![:space:]]*}}"
        value="${value%${value##*[![:space:]]}}"
        [[ -z "$key" || "$key" == \#* ]] && continue
        printf -v "PKG_${key}" '%s' "$value"
        export "PKG_${key}"
    done < "$manifest"
}

hpc_fetch() {
    local url="$1" out="$2" expected="$3" got
    if [[ ! -f "$out" ]]; then
        hpc_note "baixando $(basename "$out")"
        curl -fL --retry 3 -o "$out" "$url" || hpc_die "download falhou"
    else
        hpc_note "usando cache $(basename "$out")"
    fi

    got="$(sha256sum "$out" | awk '{print $1}')"
    [[ "$expected" != UNSET ]] || hpc_die "checksum não travado; SHA-256 atual: $got"
    [[ "$got" == "$expected" ]] || hpc_die "checksum inválido: $got"
}

hpc_extract() {
    local archive="$1" dest="$2" srcdir="$3"
    rm -rf "$dest/$srcdir"
    case "$archive" in
        *.tar.gz|*.tgz)  tar -xzf "$archive" -C "$dest" ;;
        *.tar.xz)        tar -xJf "$archive" -C "$dest" ;;
        *.tar.bz2)       tar -xjf "$archive" -C "$dest" ;;
        *)               hpc_die "formato não suportado: $archive" ;;
    esac
}

hpc_apply_patches() {
    local src="$1" patchdir="$2" p
    [[ -d "$patchdir" ]] || return 0

    while IFS= read -r p; do
        [[ -n "$p" ]] || continue
        hpc_note "aplicando patch $(basename "$p")"
        patch -d "$src" -p1 < "$p" || hpc_die "patch falhou: $p"
    done < <(find "$patchdir" -maxdepth 1 -type f -name '*.patch' | sort)
}
