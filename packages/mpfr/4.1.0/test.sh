#!/usr/bin/env bash
set -euo pipefail
t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT
cat > "$t/test.c" <<'SRC'
#include <mpfr.h>
int main(void){ mpfr_t x; mpfr_init2(x,128); mpfr_set_ui(x,42,MPFR_RNDN); mpfr_clear(x); return 0; }
SRC
cc "$t/test.c" -I"$HPC_PREFIX/include" -I"$GMP_ROOT/include" -L"$HPC_PREFIX/lib" -L"$GMP_ROOT/lib" -Wl,-rpath,"$HPC_PREFIX/lib" -Wl,-rpath,"$GMP_ROOT/lib" -lmpfr -lgmp -o "$t/test"
"$t/test"
