#!/usr/bin/env fish
source $TINYHPC_REPO/lib/common.fish
hpc_load_defaults $TINYHPC_REPO
hpc_read_manifest $HPC_PACKAGE_DIR/package.conf

set archive $HPC_CACHE/$PKG_archive
set patch_archive $HPC_CACHE/$PKG_patch_archive
set src $HPC_SRC/$PKG_source_dir
set source_dir $src/source
set makefile $source_dir/makefile

hpc_fetch $PKG_source $archive $PKG_sha256
hpc_extract $archive $HPC_SRC $PKG_source_dir
hpc_fetch $PKG_patch_source $patch_archive $PKG_patch_sha256

# Patch oficial OpenMX 4.0.1: extrair dentro de source/ e mover GaAs.dat para work/.
hpc_note "aplicando patch oficial OpenMX $PKG_patch_version"
tar -xzf $patch_archive -C $source_dir; or hpc_die "não foi possível extrair $PKG_patch_archive"
for f in Band_DFT_Dosout.c Mulliken_Charge.c GaAs.dat
    test -f $source_dir/$f; or hpc_die "patch incompleto: $f ausente"
end
mv -f $source_dir/GaAs.dat $src/work/GaAs.dat; or hpc_die "não foi possível instalar GaAs.dat do patch"

# Validação antecipada dos prefixos. Evita erros de link pouco legíveis mais adiante.
test -x $MPI_ROOT/bin/mpicc; or hpc_die "MPI_ROOT inválido: mpicc não encontrado"
test -x $MPI_ROOT/bin/mpifort; or hpc_die "MPI_ROOT inválido: mpifort não encontrado"
test -f $OPENBLAS_ROOT/lib/libopenblas.so; or hpc_die "OPENBLAS_ROOT inválido: libopenblas.so não encontrada"
test -f $FFTW_ROOT/lib/libfftw3.so; or hpc_die "FFTW_ROOT inválido: libfftw3.so não encontrada"
test -f $SCALAPACK_ROOT/lib/libscalapack.so; or hpc_die "SCALAPACK_ROOT inválido: libscalapack.so não encontrada"
test -f $makefile; or hpc_die "makefile do OpenMX não encontrado"

set mpi_link ($MPI_ROOT/bin/mpifort --showme:link | string collect | string trim)
set rpaths "-Wl,-rpath,$SCALAPACK_ROOT/lib -Wl,-rpath,$OPENBLAS_ROOT/lib -Wl,-rpath,$FFTW_ROOT/lib -Wl,-rpath,$MPI_ROOT/lib -Wl,-rpath,$GCC_ROOT/lib64 -Wl,-rpath,$GCC_ROOT/lib"
set libs "-L$SCALAPACK_ROOT/lib -lscalapack -L$OPENBLAS_ROOT/lib -lopenblas -L$FFTW_ROOT/lib -lfftw3 $mpi_link -lgfortran -lpthread -lm -ldl $rpaths"

# O makefile upstream é configurado por variáveis. Mantemos a configuração GNU validada
# e evitamos dependência em MKL/system BLAS.
sed -i -E '/^[[:space:]]*MKLROOT[[:space:]]*=/d' $makefile
sed -i -E "s|^[[:space:]]*CC[[:space:]]*=.*|CC = $MPI_ROOT/bin/mpicc -O3 -march=native -fopenmp -fcommon -I$FFTW_ROOT/include|" $makefile
sed -i -E "s|^[[:space:]]*FC[[:space:]]*=.*|FC = $MPI_ROOT/bin/mpifort -O3 -march=native -fopenmp|" $makefile
sed -i -E "s|^[[:space:]]*LIB[[:space:]]*=.*|LIB = $libs|" $makefile

cd $source_dir
make clean >/dev/null 2>&1; or true
# O makefile do OpenMX possui alvos que podem competir em builds paralelos.
# Build serial por confiabilidade; as bibliotecas pesadas já estão pré-compiladas.
make all; or exit 1
make install; or exit 1

# Instalação autocontida: binário, base DFT e exemplos/work.
rm -rf $HPC_PREFIX
mkdir -p $HPC_PREFIX/bin $HPC_PREFIX/share/tinyhpc

test -x $src/work/openmx; or hpc_die "make install não produziu work/openmx"
cp -a $src/work/openmx $HPC_PREFIX/bin/openmx
cp -a $src/DFT_DATA19 $HPC_PREFIX/DFT_DATA19
cp -a $src/work $HPC_PREFIX/work
rm -f $HPC_PREFIX/work/openmx

printf '%s\n' \
    "OpenMX base version: 4.0" \
    "Official patch: 4.0.1 (08/May/2026)" \
    "Patch archive SHA-256: $PKG_patch_sha256" \
    > $HPC_PREFIX/share/tinyhpc/build-info.txt
