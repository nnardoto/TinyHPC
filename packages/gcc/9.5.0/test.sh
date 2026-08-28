#!/usr/bin/env bash
set -euo pipefail

[[ -x "$HPC_PREFIX/bin/gcc" ]]
[[ -x "$HPC_PREFIX/bin/gfortran" ]]
"$HPC_PREFIX/bin/gcc" --version | head -n1 | grep -q '9.5.0'
"$HPC_PREFIX/bin/gfortran" --version | head -n1 | grep -q '9.5.0'

t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT
cat > "$t/x.f90" <<'SRC'
program x
  print *, "gcc9-ok"
end program
SRC
"$HPC_PREFIX/bin/gfortran" "$t/x.f90" -o "$t/x"
"$t/x" | grep -q 'gcc9-ok'
