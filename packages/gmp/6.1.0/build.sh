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
rm -rf "$build"
mkdir -p "$build"
cd "$build"
CC=gcc CFLAGS="-std=gnu17" "$src/configure" --prefix="$HPC_PREFIX"
make -j"$HPC_JOBS"
make install
