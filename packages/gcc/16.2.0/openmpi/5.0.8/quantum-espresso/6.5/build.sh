#!/usr/bin/env bash
set -euo pipefail

source_dir="${HPC_SRC}/q-e-qe-6.5"

# GCC 10+ rejects legacy implicit-interface calls into BLAS/LAPACK, and GCC
# 14+ rejects old-style (K&R) C declarations; relax both so this older QE
# release still builds. -fallow-argument-mismatch is Fortran-only.
fortran_major="$("${MPI_ROOT}/bin/mpifort" -dumpversion | cut -d. -f1)"
mismatch_flag=""
if [[ "${fortran_major}" -ge 10 ]]; then
  mismatch_flag="-fallow-argument-mismatch"
fi

base_optimization="${HPC_OPT_FLAGS} -fgraphite-identity -floop-nest-optimize"

export CC="${MPI_ROOT}/bin/mpicc"
export F90="${MPI_ROOT}/bin/mpifort"
export F77="${MPI_ROOT}/bin/mpifort"
export MPIF90="${MPI_ROOT}/bin/mpifort"
export FC="${MPI_ROOT}/bin/mpifort"
export CFLAGS="${base_optimization} -std=gnu89"
export FFLAGS="${base_optimization} ${mismatch_flag}"
export FCFLAGS="${base_optimization} ${mismatch_flag}"

export BLAS_LIBS="-L${OPENBLAS_ROOT}/lib -lopenblas"
export LAPACK_LIBS="-L${OPENBLAS_ROOT}/lib -lopenblas"
# QE calls fftw_init_threads/dfftw_plan_with_nthreads; link FFTW's OpenMP
# threads library in addition to the core libfftw3.
export FFT_LIBS="-L${FFTW_ROOT}/lib -lfftw3_omp -lfftw3"
export SCALAPACK_LIBS="-L${SCALAPACK_ROOT}/lib -lscalapack"
export FFTW_INCLUDE="${FFTW_ROOT}/include"

# -fopenmp must be present at link time too, or libgomp is never pulled in
# and every OpenMP runtime symbol (GOMP_*, omp_get_*) stays undefined.
export LDFLAGS="-fopenmp -Wl,-rpath,${OPENBLAS_ROOT}/lib -Wl,-rpath,${FFTW_ROOT}/lib -Wl,-rpath,${SCALAPACK_ROOT}/lib -Wl,-rpath,${MPI_ROOT}/lib -Wl,-rpath,${GCC_ROOT}/lib64 -Wl,-rpath,${GCC_ROOT}/lib"

cd "${source_dir}"

./configure \
  --prefix="${HPC_PREFIX}" \
  --enable-openmp \
  --enable-parallel \
  --with-scalapack

# QE 6.5's hand-rolled Makefiles are not parallel-safe: `make -j all`
# propagates the job count into the iotk/Modules sub-makes, which then build
# shared targets concurrently and race. Build serially to stay reproducible.
make all
make install
