#!/usr/bin/env bash
set -euo pipefail
t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT
cat > "$t/test.c" <<'SRC'
#include <gmp.h>
int main(void){ mpz_t x; mpz_init_set_ui(x,42); mpz_clear(x); return 0; }
SRC
cc "$t/test.c" -I"$HPC_PREFIX/include" -L"$HPC_PREFIX/lib" -Wl,-rpath,"$HPC_PREFIX/lib" -lgmp -o "$t/test"
"$t/test"
