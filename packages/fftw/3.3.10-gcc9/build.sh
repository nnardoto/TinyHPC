#!/usr/bin/env bash
set -euo pipefail

source "$TINYHPC_REPO/lib/common.sh"
hpc_load_defaults "$TINYHPC_REPO"
hpc_read_manifest "$HPC_PACKAGE_DIR/package.conf"

archive="$HPC_CACHE/$PKG_archive"
src="$HPC_SRC/$PKG_source_dir"
build="$HPC_BUILD/$PKG_build_dir"

hpc_fetch "$PKG_source" "$archive" "$PKG_sha256"
hpc_extract "$archive" "$HPC_SRC" "$PKG_source_dir"
hpc_apply_patches "$src" "$HPC_PACKAGE_DIR/patches"

command -v "$CC" >/dev/null 2>&1 || hpc_die "CC inválido: $CC"
command -v "$FC" >/dev/null 2>&1 || hpc_die "FC inválido: $FC"

rm -rf "$build"
mkdir -p "$build"
cd "$build"

"$src/configure" \
    --prefix="$HPC_PREFIX" \
    --enable-shared \
    --disable-static \
    --enable-threads \
    CC="$CC" \
    F77="$FC" \
    FC="$FC"

make -j"$HPC_JOBS"
make install
