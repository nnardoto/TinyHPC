#!/usr/bin/env bash
set -euo pipefail
exe="$HPC_PREFIX/bin/openmx"
data="$HPC_PREFIX/DFT_DATA19"
example="$HPC_PREFIX/work/input_example/H2O.dat"

[[ -x "$exe" ]]
[[ -d "$data" ]]
[[ -f "$example" ]]

if ldd "$exe" | grep -q 'not found'; then
    ldd "$exe"
    exit 1
fi

t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT
cp "$example" "$t/H2O.dat"
sed -i -E "s|^[[:space:]]*DATA\.PATH[[:space:]]+.*|DATA.PATH                        $data|" "$t/H2O.dat"

cd "$t"
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
    "$MPI_ROOT/bin/mpirun" -n 1 "$exe" H2O.dat -nt 1 > H2O.std 2>&1 || {
        cat H2O.std
        exit 1
    }
