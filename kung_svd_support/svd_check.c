#include "svd_check.h"
#include "svd_ref.h"

#include <math.h>
#include <stdlib.h>

static int abs_i(int x) { return x < 0 ? -x : x; }

void svd_sigma_from_matrix_q116(const int32_t *A, int n, int32_t *sigma_q)
{
  float *Af = (float *)malloc((size_t)n * (size_t)n * sizeof(float));
  float *sig = (float *)malloc((size_t)n * sizeof(float));
  for (int i = 0; i < n * n; ++i)
    Af[i] = svd_q116_to_f32(A[i]);
  for (int j = 0; j < n; ++j) {
    double acc = 0.0;
    for (int r = 0; r < n; ++r) {
      double v = (double)Af[r * n + j];
      acc += v * v;
    }
    sig[j] = (float)sqrt(acc);
  }
  svd_sort_sigma_desc(sig, n);
  for (int i = 0; i < n; ++i)
    sigma_q[i] = svd_f32_to_q116(sig[i]);
  free(Af);
  free(sig);
}

svd_compare_result_t svd_compare_sigma_q116(const int32_t *got,
                                            const int32_t *expected,
                                            int n,
                                            int rel_div,
                                            int tol_floor_q)
{
  svd_compare_result_t r = {0, 0, true};
  int tol = expected[0] / rel_div;
  if (tol < tol_floor_q) tol = tol_floor_q;
  for (int i = 0; i < n; ++i) {
    int d = abs_i((int)got[i] - (int)expected[i]);
    if (d > r.max_diff_q) r.max_diff_q = d;
    if (d > tol) {
      r.fail_count++;
      r.pass = false;
    }
  }
  return r;
}
