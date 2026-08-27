#!/usr/bin/env bash
set -euo pipefail

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

cat > "$temporary/test_mpi.f90" <<'FORTRAN'
program test_mpi
  use mpi
  implicit none
  integer :: error, size
  call MPI_Init(error)
  call MPI_Comm_size(MPI_COMM_WORLD, size, error)
  if (size /= 2) call MPI_Abort(MPI_COMM_WORLD, 1, error)
  call MPI_Finalize(error)
end program test_mpi
FORTRAN

"$HPC_PREFIX/bin/mpifort" "$temporary/test_mpi.f90" -o "$temporary/test_mpi"
OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
  "$HPC_PREFIX/bin/mpirun" --oversubscribe -n 2 "$temporary/test_mpi"
