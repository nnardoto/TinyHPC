#!/usr/bin/env bash
set -euo pipefail

source_dir="${HPC_SRC}/openmx4.0"
patch_archive="${HPC_CACHE}/patch4.0.1.tar.gz"
patch_sha256="c5312eeee13e17e0123beeb4eb2379bcf7c7cafa1815b1dcf6846452f9620bef"

if [[ ! -f "${patch_archive}" ]]; then
  curl -fL "https://www.openmx-square.org/bugfixed/26May08/patch4.0.1.tar.gz" \
    -o "${patch_archive}.part"
  mv "${patch_archive}.part" "${patch_archive}"
fi
printf '%s  %s\n' "${patch_sha256}" "${patch_archive}" | sha256sum -c -

# The official patch archive contains complete replacements rather than diffs.
tar -xzf "${patch_archive}" -C "${source_dir}/source"
mv "${source_dir}/source/GaAs.dat" "${source_dir}/work/GaAs.dat"

mpi_link="$("${MPI_ROOT}/bin/mpifort" --showme:link)"

# GCC 14+ rejects legacy argument mismatches in elpa1.f90 (OpenMX's bundled
# ELPA passes COMPLEX where the dummy is declared REAL and mixes REAL/COMPLEX
# buffers across MPI calls). -fallow-argument-mismatch is Fortran-only and
# exists only on GCC 10+, so gate it on the compiler version.
fortran_major="$("${MPI_ROOT}/bin/mpifort" -dumpversion | cut -d. -f1)"
mismatch_flag=""
if [[ "${fortran_major}" -ge 10 ]]; then
  mismatch_flag="-fallow-argument-mismatch"
fi

mkdir -p "${HPC_PREFIX}/bin"
# The upstream makefile omits dependencies between some Fortran modules.
make -C "${source_dir}/source" -j1 all \
  "CC=${MPI_ROOT}/bin/mpicc ${HPC_OPT_FLAGS} -fgraphite-identity -floop-nest-optimize -fopenmp -fcommon -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -I${FFTW_ROOT}/include" \
  "FC=${MPI_ROOT}/bin/mpifort ${HPC_OPT_FLAGS} -fgraphite-identity -floop-nest-optimize -fopenmp ${mismatch_flag}" \
  "LIB=-L${SCALAPACK_ROOT}/lib -L${OPENBLAS_ROOT}/lib -L${FFTW_ROOT}/lib -lscalapack -lopenblas -lfftw3_omp -lfftw3 ${mpi_link} -lgfortran -lpthread -lm -ldl -Wl,-rpath,${SCALAPACK_ROOT}/lib:${OPENBLAS_ROOT}/lib:${FFTW_ROOT}/lib:${MPI_ROOT}/lib:${GCC_ROOT}/lib64:${GCC_ROOT}/lib" \
  "DESTDIR=${HPC_PREFIX}/bin"

cp -a "${source_dir}/DFT_DATA19" "${HPC_PREFIX}/"
cp -a "${source_dir}/work" "${HPC_PREFIX}/"
