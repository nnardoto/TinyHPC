#!/usr/bin/env fish
set lib $HPC_PREFIX/lib/libopenblas.so
set inc $HPC_PREFIX/include

test -f $lib; or exit 1
test -d $inc; or exit 1

set t (mktemp -d)
function cleanup --on-event fish_exit
    rm -rf $t
end

printf '%s\n' \
    'program test_openblas' \
    '  implicit none' \
    '  real(8) :: a(2,2), b(2,2), c(2,2), rhs(2,1)' \
    '  integer :: ipiv(2), info' \
    '  external dgemm, dgesv' \
    '' \
    '  a = reshape([1.d0, 3.d0, 2.d0, 4.d0], [2,2])' \
    '  b = reshape([5.d0, 7.d0, 6.d0, 8.d0], [2,2])' \
    '  c = 0.d0' \
    "  call dgemm('N','N',2,2,2,1.d0,a,2,b,2,0.d0,c,2)" \
    '  if (maxval(abs(c - reshape([19.d0,43.d0,22.d0,50.d0],[2,2]))) > 1.d-12) stop 1' \
    '' \
    '  a = reshape([3.d0, 1.d0, 1.d0, 2.d0], [2,2])' \
    '  rhs(:,1) = [9.d0, 8.d0]' \
    '  call dgesv(2,1,a,2,ipiv,rhs,2,info)' \
    '  if (info /= 0) stop 2' \
    '  if (maxval(abs(rhs(:,1) - [2.d0,3.d0])) > 1.d-12) stop 3' \
    'end program test_openblas' > $t/test.f90

$FC $t/test.f90 \
    -L$HPC_PREFIX/lib -lopenblas \
    -Wl,-rpath,$HPC_PREFIX/lib \
    -Wl,-rpath,$GCC_ROOT/lib64 \
    -Wl,-rpath,$GCC_ROOT/lib \
    -o $t/test_openblas
or exit 1

$t/test_openblas
