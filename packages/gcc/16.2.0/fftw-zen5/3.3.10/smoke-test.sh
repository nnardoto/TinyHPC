#!/usr/bin/env bash
set -euo pipefail

[[ -f "$HPC_PREFIX/lib/libfftw3.so" ]]
[[ -f "$HPC_PREFIX/lib/libfftw3_threads.so" ]]
[[ -f "$HPC_PREFIX/include/fftw3.h" ]]

cpu_flags="$(LC_ALL=C lscpu | awk -F: '/^Flags:/ {print $2}')"
for required_flag in avx512f avx512dq avx512bw avx512vl; do
  if [[ " ${cpu_flags} " != *" ${required_flag} "* ]]; then
    printf 'CPU de destino sem a extensão obrigatória: %s\n' "$required_flag" >&2
    exit 1
  fi
done

# Perform a transform through FFTW's C ABI without compiling on the target.
python3 - "$HPC_PREFIX/lib/libfftw3.so" <<'PY'
import ctypes
import sys

library = ctypes.CDLL(sys.argv[1])
complex_value = ctypes.c_double * 2
complex_pointer = ctypes.POINTER(complex_value)
library.fftw_plan_dft_1d.argtypes = [
    ctypes.c_int, complex_pointer, complex_pointer, ctypes.c_int, ctypes.c_uint
]
library.fftw_plan_dft_1d.restype = ctypes.c_void_p
library.fftw_execute.argtypes = [ctypes.c_void_p]
library.fftw_destroy_plan.argtypes = [ctypes.c_void_p]

n = 4
input_values = (complex_value * n)()
frequencies = (complex_value * n)()
back = (complex_value * n)()
for index in range(n):
    input_values[index][0] = index + 1.0

forward = library.fftw_plan_dft_1d(n, input_values, frequencies, -1, 64)
inverse = library.fftw_plan_dft_1d(n, frequencies, back, 1, 64)
if not forward or not inverse:
    raise SystemExit("FFTW não criou os planos")
library.fftw_execute(forward)
library.fftw_execute(inverse)
for index in range(n):
    if abs(back[index][0] / n - (index + 1.0)) > 1e-12:
        raise SystemExit("resultado FFTW incorreto")
    if abs(back[index][1] / n) > 1e-12:
        raise SystemExit("parte imaginária FFTW incorreta")
library.fftw_destroy_plan(forward)
library.fftw_destroy_plan(inverse)
print("FFTW Zen5 forward/backward: OK")
PY
