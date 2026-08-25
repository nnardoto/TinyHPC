#!/usr/bin/env fish
set t (mktemp -d)
printf '%s\n' '#include <mpc.h>' 'int main(void){ mpc_t z; mpc_init2(z,128); mpc_set_ui(z,42,MPC_RNDNN); mpc_clear(z); return 0; }' > $t/test.c
cc $t/test.c -I$HPC_PREFIX/include -I$MPFR_ROOT/include -I$GMP_ROOT/include -L$HPC_PREFIX/lib -L$MPFR_ROOT/lib -L$GMP_ROOT/lib -Wl,-rpath,$HPC_PREFIX/lib -Wl,-rpath,$MPFR_ROOT/lib -Wl,-rpath,$GMP_ROOT/lib -lmpc -lmpfr -lgmp -o $t/test
or exit 1
$t/test
set rc $status
rm -rf $t
exit $rc
