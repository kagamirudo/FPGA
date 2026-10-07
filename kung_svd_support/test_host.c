/*
 * Host-side smoke test (no board): SW Jacobi vs golden σ from svd_sigma.mem.
 *
 *   make host-test
 */
#include <stdio.h>

#include "svd_ref.h"
#include "svd_check.h"
#include "svd_test_vectors.h"

#define SWEEPS SVD_N

int main(void)
{
  float A[SVD_N2];
  float sigma_f[SVD_N];
  int32_t sigma_sw[SVD_N];

  for (int i = 0; i < SVD_N2; ++i)
    A[i] = svd_q116_to_f32(kSvdInputQ116[i]);

  svd_onesided_jacobi_f32(A, SVD_N, SWEEPS, sigma_f);
  svd_sort_sigma_desc(sigma_f, SVD_N);
  for (int i = 0; i < SVD_N; ++i)
    sigma_sw[i] = svd_f32_to_q116(sigma_f[i]);

  printf("SW sigma_q:");
  for (int i = 0; i < SVD_N; ++i)
    printf(" %d", (int)sigma_sw[i]);
  printf("\nGolden:   ");
  for (int i = 0; i < SVD_N; ++i)
    printf(" %d", (int)kSvdSigmaQ116[i]);
  printf("\n");

  /* Float Jacobi vs NumPy golden — allow looser tol than fixed-point HW */
  svd_compare_result_t r =
      svd_compare_sigma_q116(sigma_sw, kSvdSigmaQ116, SVD_N, 256, 256);
  printf("SW vs golden: %s  max_diff=%d\n",
         r.pass ? "PASS" : "FAIL", r.max_diff_q);
  return r.pass ? 0 : 1;
}
