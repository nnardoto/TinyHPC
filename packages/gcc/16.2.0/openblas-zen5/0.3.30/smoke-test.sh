#!/usr/bin/env bash
set -euo pipefail

[[ -f "$HPC_PREFIX/lib/libopenblas.so" ]]
[[ -d "$HPC_PREFIX/include" ]]

cpu_flags="$(LC_ALL=C lscpu | awk -F: '/^Flags:/ {print $2}')"
for required_flag in avx512f avx512dq avx512bw avx512vl; do
  if [[ " ${cpu_flags} " != *" ${required_flag} "* ]]; then
    printf 'CPU de destino sem a extensão obrigatória: %s\n' "$required_flag" >&2
    exit 1
  fi
done

# Exercise DGEMM through the CBLAS ABI without compiling on the target node.
python3 - "$HPC_PREFIX/lib/libopenblas.so" <<'PY'
import ctypes
import sys

library = ctypes.CDLL(sys.argv[1])
double_pointer = ctypes.POINTER(ctypes.c_double)
library.cblas_dgemm.argtypes = [
    ctypes.c_int, ctypes.c_int, ctypes.c_int,
    ctypes.c_int, ctypes.c_int, ctypes.c_int,
    ctypes.c_double, double_pointer, ctypes.c_int,
    double_pointer, ctypes.c_int, ctypes.c_double,
    double_pointer, ctypes.c_int,
]
a = (ctypes.c_double * 4)(1.0, 2.0, 3.0, 4.0)
b = (ctypes.c_double * 4)(5.0, 6.0, 7.0, 8.0)
c = (ctypes.c_double * 4)()
library.cblas_dgemm(101, 111, 111, 2, 2, 2, 1.0, a, 2, b, 2, 0.0, c, 2)
expected = (19.0, 22.0, 43.0, 50.0)
if any(abs(value - wanted) > 1e-12 for value, wanted in zip(c, expected)):
    raise SystemExit(f"resultado DGEMM incorreto: {tuple(c)}")
print("OpenBLAS Zen5 DGEMM: OK")
PY
