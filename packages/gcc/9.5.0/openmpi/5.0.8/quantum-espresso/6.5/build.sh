#!/usr/bin/env bash
set -euo pipefail

source_dir="${HPC_SRC}/q-e-qe-6.5"

# GCC 10 and newer reject legacy implicit-interface calls into BLAS/LAPACK;
# allow the mismatch so this older QE release still links cleanly.
fortran_major="$("${MPI_ROOT}/bin/mpifort" -dumpversion | cut -d. -f1)"
mismatch_flag=""
if [[ "${fortran_major}" -ge 10 ]]; then
  mismatch_flag="-fallow-argument-mismatch"
fi

optimization="${HPC_OPT_FLAGS} -fgraphite-identity -floop-nest-optimize ${mismatch_flag}"

export CC="${MPI_ROOT}/bin/mpicc"
export F90="${MPI_ROOT}/bin/mpifort"
export F77="${MPI_ROOT}/bin/mpifort"
export MPIF90="${MPI_ROOT}/bin/mpifort"
export FC="${MPI_ROOT}/bin/mpifort"
export CFLAGS="${optimization}"
export FFLAGS="${optimization}"
export FCFLAGS="${optimization}"

export BLAS_LIBS="-L${OPENBLAS_ROOT}/lib -lopenblas"
export LAPACK_LIBS="-L${OPENBLAS_ROOT}/lib -lopenblas"
export FFT_LIBS="-L${FFTW_ROOT}/lib -lfftw3"
export SCALAPACK_LIBS="-L${SCALAPACK_ROOT}/lib -lscalapack"
export FFTW_INCLUDE="${FFTW_ROOT}/include"

export LDFLAGS="-Wl,-rpath,${OPENBLAS_ROOT}/lib -Wl,-rpath,${FFTW_ROOT}/lib -Wl,-rpath,${SCALAPACK_ROOT}/lib -Wl,-rpath,${MPI_ROOT}/lib -Wl,-rpath,${GCC_ROOT}/lib64 -Wl,-rpath,${GCC_ROOT}/lib"

cd "${source_dir}"

./configure \
  --prefix="${HPC_PREFIX}" \
  --enable-openmp \
  --enable-parallel \
  --with-scalapack

make -j"${HPC_JOBS}" all
make install
