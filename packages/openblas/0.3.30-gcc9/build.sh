#!/usr/bin/env bash
set -euo pipefail

source "$TINYHPC_REPO/lib/common.sh"
hpc_load_defaults "$TINYHPC_REPO"
hpc_read_manifest "$HPC_PACKAGE_DIR/package.conf"

archive="$HPC_CACHE/$PKG_archive"
src="$HPC_SRC/$PKG_source_dir"

hpc_fetch "$PKG_source" "$archive" "$PKG_sha256"
hpc_extract "$archive" "$HPC_SRC" "$PKG_source_dir"
hpc_apply_patches "$src" "$HPC_PACKAGE_DIR/patches"

# OpenBLAS' gmake build is intentionally in-tree. hpc clean removes this
# extracted source tree afterwards, while the downloaded tarball stays cached.
cd "$src"

[[ -x "$CC" ]] || hpc_die "CC inválido: $CC"
[[ -x "$FC" ]] || hpc_die "FC inválido: $FC"
[[ -d "$GCC_ROOT/lib64" ]] || hpc_die "GCC_ROOT inválido: $GCC_ROOT/lib64 não existe"

rpath_flags="-Wl,-rpath,$GCC_ROOT/lib64 -Wl,-rpath,$GCC_ROOT/lib"

make -j"$HPC_JOBS" \
    CC="$CC" \
    FC="$FC" \
    HOSTCC="$CC" \
    DYNAMIC_ARCH=1 \
    USE_THREAD=1 \
    USE_OPENMP=0 \
    NO_AFFINITY=1 \
    LDFLAGS="$rpath_flags"

make \
    PREFIX="$HPC_PREFIX" \
    CC="$CC" \
    FC="$FC" \
    HOSTCC="$CC" \
    DYNAMIC_ARCH=1 \
    USE_THREAD=1 \
    USE_OPENMP=0 \
    NO_AFFINITY=1 \
    LDFLAGS="$rpath_flags" \
    install
