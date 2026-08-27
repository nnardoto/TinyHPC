#!/usr/bin/env bash
# Shared helpers for Bash package recipes and script escape hatches.

hpc_die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

hpc_note() {
    printf '==> %s\n' "$*"
}

hpc_load_defaults() {
    local repo="$1" candidate python="" key value settings
    for candidate in python3.13 python3.12 python3.11 python3.10 python3.9 python3; do
        command -v "$candidate" >/dev/null 2>&1 || continue
        if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null; then
            python="$candidate"
            break
        fi
    done
    [[ -n "$python" ]] || hpc_die "Python 3.9 ou mais recente não encontrado"
    settings="$("$python" "$repo/lib/recipe.py" --repo "$repo" environment)" || hpc_die "configuração inválida"
    while IFS=$'\t' read -r key value; do
        [[ -n "$key" ]] || continue
        printf -v "$key" '%s' "$value"
        export "$key"
    done <<< "$settings"
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
