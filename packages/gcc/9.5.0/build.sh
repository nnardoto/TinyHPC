#!/usr/bin/env bash
set -euo pipefail

source "$TINYHPC_REPO/lib/common.sh"
hpc_load_defaults "$TINYHPC_REPO"
hpc_read_manifest "$HPC_PACKAGE_DIR/package.conf"

for dep in GMP MPFR MPC; do
    root_var="${dep}_ROOT"
    root="${!root_var:-}"
    [[ -n "$root" ]] || hpc_die "$root_var não definido; verifique o modulefile da dependência"
    [[ -d "$root/include" ]] || hpc_die "$root_var inválido: $root/include não existe"
    [[ -d "$root/lib" ]] || hpc_die "$root_var inválido: $root/lib não existe"
done

archive="$HPC_CACHE/$PKG_archive"
src="$HPC_SRC/$PKG_source_dir"
build="$HPC_BUILD/$PKG_build_dir"

hpc_fetch "$PKG_source" "$archive" "$PKG_sha256"
hpc_extract "$archive" "$HPC_SRC" "$PKG_source_dir"

rm -rf "$build"
mkdir -p "$build"
cd "$build"

"$src/configure" \
    --prefix="$HPC_PREFIX" \
    --enable-languages=c,c++,fortran \
    --disable-multilib \
    --disable-bootstrap \
    --disable-libsanitizer \
    --with-gmp="$GMP_ROOT" \
    --with-mpfr="$MPFR_ROOT" \
    --with-mpc="$MPC_ROOT" \
    --without-isl

make -j"$HPC_JOBS"
make install
