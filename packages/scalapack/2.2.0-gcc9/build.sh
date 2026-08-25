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

command -v cmake >/dev/null 2>&1 || hpc_die "cmake não encontrado"
[[ -x "$MPI_ROOT/bin/mpicc" ]] || hpc_die "MPI_ROOT inválido: mpicc não encontrado"
[[ -x "$MPI_ROOT/bin/mpifort" ]] || hpc_die "MPI_ROOT inválido: mpifort não encontrado"
[[ -f "$OPENBLAS_ROOT/lib/libopenblas.so" ]] || hpc_die "OPENBLAS_ROOT inválido: libopenblas.so não encontrada"

rm -rf "$build"
mkdir -p "$build"

rpath="$OPENBLAS_ROOT/lib;$MPI_ROOT/lib;$GCC_ROOT/lib64;$GCC_ROOT/lib"

cmake -S "$src" -B "$build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$HPC_PREFIX" \
    -DCMAKE_C_COMPILER="$MPI_ROOT/bin/mpicc" \
    -DCMAKE_Fortran_COMPILER="$MPI_ROOT/bin/mpifort" \
    -DMPI_C_COMPILER="$MPI_ROOT/bin/mpicc" \
    -DMPI_Fortran_COMPILER="$MPI_ROOT/bin/mpifort" \
    -DBUILD_SHARED_LIBS=ON \
    -DSCALAPACK_BUILD_TESTS=OFF \
    -DBLAS_LIBRARIES="$OPENBLAS_ROOT/lib/libopenblas.so" \
    -DLAPACK_LIBRARIES="$OPENBLAS_ROOT/lib/libopenblas.so" \
    -DLAPACK_FOUND=TRUE \
    -DCMAKE_INSTALL_RPATH="$rpath" \
    -DCMAKE_BUILD_RPATH="$rpath"

cmake --build "$build" --parallel "$HPC_JOBS"
cmake --install "$build"
