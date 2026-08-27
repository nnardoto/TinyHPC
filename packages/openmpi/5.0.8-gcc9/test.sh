#!/usr/bin/env bash
set -euo pipefail

mpirun="$HPC_PREFIX/bin/mpirun"
mpicc="$HPC_PREFIX/bin/mpicc"
mpifort="$HPC_PREFIX/bin/mpifort"

for exe in "$mpirun" "$mpicc" "$mpifort"; do
    [[ -x "$exe" ]]
done

"$mpirun" --version | head -n1 | grep -q '5.0.8'
"$mpicc" --showme:command | grep -q 'gcc'
"$mpifort" --showme:command | grep -q 'gfortran'

t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT

cat > "$t/hello.c" <<'SRC'
#include <mpi.h>
#include <stdio.h>
int main(int argc, char **argv) {
  int rank, size;
  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  printf("rank=%d size=%d\n", rank, size);
  MPI_Finalize();
  return 0;
}
SRC

"$mpicc" "$t/hello.c" -o "$t/hello"
"$mpirun" -n 2 "$t/hello" > "$t/out"
[[ "$(grep -c 'size=2' "$t/out")" -eq 2 ]]
