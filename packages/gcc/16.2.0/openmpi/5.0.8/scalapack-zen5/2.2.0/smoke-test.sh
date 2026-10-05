#!/usr/bin/env bash
set -euo pipefail

library="$HPC_PREFIX/lib/libscalapack.so"
[[ -f "$library" ]]

cpu_flags="$(LC_ALL=C lscpu | awk -F: '/^Flags:/ {print $2}')"
for required_flag in avx512f avx512dq avx512bw avx512vl; do
  if [[ " ${cpu_flags} " != *" ${required_flag} "* ]]; then
    printf 'CPU de destino sem a extensão obrigatória: %s\n' "$required_flag" >&2
    exit 1
  fi
done

dependencies="$(LC_ALL=C ldd "$library")"
if [[ "$dependencies" == *"not found"* ]]; then
  printf '%s\n' "$dependencies" >&2
  exit 1
fi

# Loading the shared object checks its complete runtime dependency closure.
# The OpenMX target test performs the end-to-end numerical/MPI exercise.
python3 - "$library" <<'PY'
import ctypes
import sys

ctypes.CDLL(sys.argv[1])
print("ScaLAPACK Zen5 runtime linkage: OK")
PY
