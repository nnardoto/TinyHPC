#!/usr/bin/env bash
set -euo pipefail

source_dir="${HPC_SRC}/wannier_tools-2.7.0/src"

# GCC 10+ rejects legacy implicit-interface calls into BLAS/LAPACK. Gate the
# relaxation on the compiler version, matching the OpenMX/QE recipes.
fortran_major="$("${MPI_ROOT}/bin/mpifort" -dumpversion | cut -d. -f1)"
mismatch_flag=""
if [[ "${fortran_major}" -ge 10 ]]; then
  mismatch_flag="-fallow-argument-mismatch"
fi

# The upstream Makefile has no module-dependency rules, so parallel builds race
# on the .mod files produced by module.f90. Build serially.
# ARPACK must precede OpenBLAS on the link line (ARPACK depends on LAPACK/BLAS).
make -C "${source_dir}" -f Makefile.gfortran-mpi -j1 \
  "F90=${MPI_ROOT}/bin/mpifort -cpp -DMPI -ffree-line-length-512" \
  "FFLAG=${HPC_OPT_FLAGS} ${mismatch_flag}" \
  "LFLAG=${HPC_OPT_FLAGS}" \
  "LIBS=-L${ARPACK_ROOT}/lib -larpack -L${OPENBLAS_ROOT}/lib -lopenblas -Wl,-rpath,${ARPACK_ROOT}/lib -Wl,-rpath,${OPENBLAS_ROOT}/lib -Wl,-rpath,${MPI_ROOT}/lib -Wl,-rpath,${GCC_ROOT}/lib64 -Wl,-rpath,${GCC_ROOT}/lib"

mkdir -p "${HPC_PREFIX}/bin"
install -m 0755 "${source_dir}/../bin/wt.x" "${HPC_PREFIX}/bin/wt.x"
