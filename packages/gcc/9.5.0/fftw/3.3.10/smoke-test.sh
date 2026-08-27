#!/usr/bin/env bash
set -euo pipefail

[[ -f "$HPC_PREFIX/lib/libfftw3.so" ]]
[[ -f "$HPC_PREFIX/lib/libfftw3_threads.so" ]]
[[ -f "$HPC_PREFIX/include/fftw3.h" ]]

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

cat > "$temporary/test_fftw.c" <<'C'
#include <fftw3.h>
#include <math.h>

int main(void) {
  const int n = 4;
  fftw_complex *in = fftw_alloc_complex(n);
  fftw_complex *freq = fftw_alloc_complex(n);
  fftw_complex *back = fftw_alloc_complex(n);
  if (!in || !freq || !back) return 1;
  for (int i = 0; i < n; ++i) { in[i][0] = i + 1.0; in[i][1] = 0.0; }
  if (!fftw_init_threads()) return 2;
  fftw_plan_with_nthreads(2);
  fftw_plan pf = fftw_plan_dft_1d(n, in, freq, FFTW_FORWARD, FFTW_ESTIMATE);
  fftw_plan pb = fftw_plan_dft_1d(n, freq, back, FFTW_BACKWARD, FFTW_ESTIMATE);
  if (!pf || !pb) return 3;
  fftw_execute(pf);
  fftw_execute(pb);
  for (int i = 0; i < n; ++i) {
    if (fabs(back[i][0] / n - (i + 1.0)) > 1e-12) return 4;
    if (fabs(back[i][1] / n) > 1e-12) return 5;
  }
  fftw_destroy_plan(pf);
  fftw_destroy_plan(pb);
  fftw_cleanup_threads();
  fftw_free(in);
  fftw_free(freq);
  fftw_free(back);
  return 0;
}
C

"$CC" "$temporary/test_fftw.c" \
    -I"$HPC_PREFIX/include" \
    -L"$HPC_PREFIX/lib" \
    -lfftw3_threads -lfftw3 -lm -lpthread \
    -Wl,-rpath,"$HPC_PREFIX/lib" \
    -o "$temporary/test_fftw"

"$temporary/test_fftw"
