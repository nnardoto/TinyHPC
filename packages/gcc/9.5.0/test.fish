#!/usr/bin/env fish
test -x $HPC_PREFIX/bin/gcc; or exit 1
test -x $HPC_PREFIX/bin/gfortran; or exit 1
$HPC_PREFIX/bin/gcc --version | head -n1 | grep -q 9.5.0; or exit 1
$HPC_PREFIX/bin/gfortran --version | head -n1 | grep -q 9.5.0; or exit 1
set t (mktemp -d)
printf '%s\n' 'program x' 'print *, "gcc9-ok"' 'end program' > $t/x.f90
$HPC_PREFIX/bin/gfortran $t/x.f90 -o $t/x; or exit 1
$t/x | grep -q gcc9-ok; or exit 1
rm -rf $t
