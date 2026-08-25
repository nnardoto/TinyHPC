#!/usr/bin/env fish
set mpirun $HPC_PREFIX/bin/mpirun
set mpicc $HPC_PREFIX/bin/mpicc
set mpifort $HPC_PREFIX/bin/mpifort

for exe in $mpirun $mpicc $mpifort
    test -x $exe; or exit 1
end

$mpirun --version | head -n1 | grep -q '5.0.8'; or exit 1
$mpicc --showme:command | grep -q 'gcc'; or exit 1
$mpifort --showme:command | grep -q 'gfortran'; or exit 1

set t (mktemp -d)
function cleanup --on-event fish_exit
    rm -rf $t
end

printf '%s\n' \
    '#include <mpi.h>' \
    '#include <stdio.h>' \
    'int main(int argc, char **argv) {' \
    '  int rank, size;' \
    '  MPI_Init(&argc, &argv);' \
    '  MPI_Comm_rank(MPI_COMM_WORLD, &rank);' \
    '  MPI_Comm_size(MPI_COMM_WORLD, &size);' \
    '  printf("rank=%d size=%d\\n", rank, size);' \
    '  MPI_Finalize();' \
    '  return 0;' \
    '}' > $t/hello.c

$mpicc $t/hello.c -o $t/hello; or exit 1
$mpirun -n 2 $t/hello > $t/out; or exit 1

test (grep -c 'size=2' $t/out) -eq 2; or exit 1
