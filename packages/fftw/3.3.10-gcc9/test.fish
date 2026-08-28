#!/usr/bin/env fish
set lib $HPC_PREFIX/lib/libfftw3.so
set tlib $HPC_PREFIX/lib/libfftw3_threads.so
set inc $HPC_PREFIX/include/fftw3.h

test -f $lib; or exit 1
test -f $tlib; or exit 1
test -f $inc; or exit 1

set t (mktemp -d)
function cleanup --on-event fish_exit
    rm -rf $t
end

printf '%s\n' \
    '#include <fftw3.h>' \
    '#include <math.h>' \
    '#include <stdio.h>' \
    'int main(void) {' \
    '  const int n = 4;' \
    '  fftw_complex *in = fftw_alloc_complex(n);' \
    '  fftw_complex *freq = fftw_alloc_complex(n);' \
    '  fftw_complex *back = fftw_alloc_complex(n);' \
    '  if (!in || !freq || !back) return 1;' \
    '  for (int i = 0; i < n; ++i) { in[i][0] = i + 1.0; in[i][1] = 0.0; }' \
    '  if (!fftw_init_threads()) return 2;' \
    '  fftw_plan_with_nthreads(2);' \
    '  fftw_plan pf = fftw_plan_dft_1d(n, in, freq, FFTW_FORWARD, FFTW_ESTIMATE);' \
    '  fftw_plan pb = fftw_plan_dft_1d(n, freq, back, FFTW_BACKWARD, FFTW_ESTIMATE);' \
    '  if (!pf || !pb) return 3;' \
    '  fftw_execute(pf);' \
    '  fftw_execute(pb);' \
    '  for (int i = 0; i < n; ++i) {' \
    '    if (fabs(back[i][0] / n - (i + 1.0)) > 1e-12) return 4;' \
    '    if (fabs(back[i][1] / n) > 1e-12) return 5;' \
    '  }' \
    '  fftw_destroy_plan(pf);' \
    '  fftw_destroy_plan(pb);' \
    '  fftw_cleanup_threads();' \
    '  fftw_free(in); fftw_free(freq); fftw_free(back);' \
    '  return 0;' \
    '}' > $t/test_fftw.c

$CC $t/test_fftw.c \
    -I$HPC_PREFIX/include \
    -L$HPC_PREFIX/lib \
    -lfftw3_threads -lfftw3 -lm -lpthread \
    -Wl,-rpath,$HPC_PREFIX/lib \
    -o $t/test_fftw
or exit 1

$t/test_fftw
