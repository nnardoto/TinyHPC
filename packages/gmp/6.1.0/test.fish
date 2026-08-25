#!/usr/bin/env fish
set t (mktemp -d)
printf '%s\n' '#include <gmp.h>' 'int main(void){ mpz_t x; mpz_init_set_ui(x,42); mpz_clear(x); return 0; }' > $t/test.c
cc $t/test.c -I$HPC_PREFIX/include -L$HPC_PREFIX/lib -Wl,-rpath,$HPC_PREFIX/lib -lgmp -o $t/test
or exit 1
$t/test
set rc $status
rm -rf $t
exit $rc
