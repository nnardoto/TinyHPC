#!/usr/bin/env bash
set -euo pipefail
source "$TINYHPC_REPO/lib/common.sh"
hpc_load_defaults "$TINYHPC_REPO"
hpc_read_manifest "$HPC_PACKAGE_DIR/package.conf"

archive="$HPC_CACHE/$PKG_archive"
patch_archive="$HPC_CACHE/$PKG_patch_archive"
src="$HPC_SRC/$PKG_source_dir"
source_dir="$src/source"
makefile="$source_dir/makefile"

hpc_fetch "$PKG_source" "$archive" "$PKG_sha256"
hpc_extract "$archive" "$HPC_SRC" "$PKG_source_dir"
hpc_fetch "$PKG_patch_source" "$patch_archive" "$PKG_patch_sha256"

hpc_note "aplicando patch oficial OpenMX $PKG_patch_version"
tar -xzf "$patch_archive" -C "$source_dir" || hpc_die "não foi possível extrair $PKG_patch_archive"
for f in Band_DFT_Dosout.c Mulliken_Charge.c GaAs.dat; do
    [[ -f "$source_dir/$f" ]] || hpc_die "patch incompleto: $f ausente"
done
mv -f "$source_dir/GaAs.dat" "$src/work/GaAs.dat" || hpc_die "não foi possível instalar GaAs.dat do patch"

[[ -x "$MPI_ROOT/bin/mpicc" ]] || hpc_die "MPI_ROOT inválido: mpicc não encontrado"
[[ -x "$MPI_ROOT/bin/mpifort" ]] || hpc_die "MPI_ROOT inválido: mpifort não encontrado"
[[ -f "$OPENBLAS_ROOT/lib/libopenblas.so" ]] || hpc_die "OPENBLAS_ROOT inválido: libopenblas.so não encontrada"
[[ -f "$FFTW_ROOT/lib/libfftw3.so" ]] || hpc_die "FFTW_ROOT inválido: libfftw3.so não encontrada"
[[ -f "$SCALAPACK_ROOT/lib/libscalapack.so" ]] || hpc_die "SCALAPACK_ROOT inválido: libscalapack.so não encontrada"
[[ -f "$makefile" ]] || hpc_die "makefile do OpenMX não encontrado"

mpi_link="$($MPI_ROOT/bin/mpifort --showme:link)"
rpaths="-Wl,-rpath,$SCALAPACK_ROOT/lib -Wl,-rpath,$OPENBLAS_ROOT/lib -Wl,-rpath,$FFTW_ROOT/lib -Wl,-rpath,$MPI_ROOT/lib -Wl,-rpath,$GCC_ROOT/lib64 -Wl,-rpath,$GCC_ROOT/lib"
libs="-L$SCALAPACK_ROOT/lib -lscalapack -L$OPENBLAS_ROOT/lib -lopenblas -L$FFTW_ROOT/lib -lfftw3 $mpi_link -lgfortran -lpthread -lm -ldl $rpaths"

sed -i -E '/^[[:space:]]*MKLROOT[[:space:]]*=/d' "$makefile"
sed -i -E "s|^[[:space:]]*CC[[:space:]]*=.*|CC = $MPI_ROOT/bin/mpicc -O3 -march=native -fopenmp -fcommon -I$FFTW_ROOT/include|" "$makefile"
sed -i -E "s|^[[:space:]]*FC[[:space:]]*=.*|FC = $MPI_ROOT/bin/mpifort -O3 -march=native -fopenmp|" "$makefile"
sed -i -E "s|^[[:space:]]*LIB[[:space:]]*=.*|LIB = $libs|" "$makefile"

cd "$source_dir"
make clean >/dev/null 2>&1 || true
make all
make install

rm -rf "$HPC_PREFIX"
mkdir -p "$HPC_PREFIX/bin" "$HPC_PREFIX/share/tinyhpc"
[[ -x "$src/work/openmx" ]] || hpc_die "make install não produziu work/openmx"
cp -a "$src/work/openmx" "$HPC_PREFIX/bin/openmx"
cp -a "$src/DFT_DATA19" "$HPC_PREFIX/DFT_DATA19"
cp -a "$src/work" "$HPC_PREFIX/work"
rm -f "$HPC_PREFIX/work/openmx"

cat > "$HPC_PREFIX/share/tinyhpc/build-info.txt" <<EOF2
OpenMX base version: 4.0
Official patch: 4.0.1 (08/May/2026)
Patch archive SHA-256: $PKG_patch_sha256
EOF2
