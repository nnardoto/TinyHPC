#!/usr/bin/env fish
set lib $HPC_PREFIX/lib/libscalapack.so

test -f $lib; or exit 1
test -x $MPI_ROOT/bin/mpifort; or exit 1
test -x $MPI_ROOT/bin/mpirun; or exit 1

set t (mktemp -d)
function cleanup --on-event fish_exit
    rm -rf $t
end

printf '%s\n' \
    'program test_scalapack' \
    '  implicit none' \
    '  integer :: me, nprocs, ctxt, nprow, npcol, myrow, mycol' \
    '  call blacs_pinfo(me, nprocs)' \
    '  call blacs_get(-1, 0, ctxt)' \
    "  call blacs_gridinit(ctxt, 'R', 1, nprocs)" \
    '  call blacs_gridinfo(ctxt, nprow, npcol, myrow, mycol)' \
    '  if (nprow /= 1) stop 1' \
    '  if (npcol /= nprocs) stop 2' \
    '  if (myrow /= 0) stop 3' \
    '  if (mycol /= me) stop 4' \
    '  call blacs_gridexit(ctxt)' \
    '  call blacs_exit(0)' \
    'end program test_scalapack' > $t/test.f90

$MPI_ROOT/bin/mpifort $t/test.f90 \
    -L$HPC_PREFIX/lib -lscalapack \
    -L$OPENBLAS_ROOT/lib -lopenblas \
    -Wl,-rpath,$HPC_PREFIX/lib \
    -Wl,-rpath,$OPENBLAS_ROOT/lib \
    -Wl,-rpath,$MPI_ROOT/lib \
    -Wl,-rpath,$GCC_ROOT/lib64 \
    -Wl,-rpath,$GCC_ROOT/lib \
    -o $t/test_scalapack
or exit 1

set -lx OPENBLAS_NUM_THREADS 1
$MPI_ROOT/bin/mpirun -n 2 $t/test_scalapack
