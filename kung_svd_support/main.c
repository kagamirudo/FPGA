/*
 * Vitis bare-metal app: compare PL SVD (AXI DMA) vs pure-C one-sided Jacobi.
 *
 * Build inside a Vitis platform created from build/svd_system/svd_system.xsa.
 * Do NOT define SVD_HOST_ONLY for the board target.
 */
#include <stdio.h>
#include <string.h>

#include "platform.h"
#include "xil_printf.h"
#include "xtime_l.h"

#include "svd_ref.h"
#include "svd_check.h"
#include "svd_hw_dma.h"
#include "svd_test_vectors.h"

#define SWEEPS SVD_N /* matches RTL SWEEPS = N */

static void print_sigma(const char *tag, const int32_t *s, int n)
{
  xil_printf("%s:", tag);
  for (int i = 0; i < n; ++i)
    xil_printf(" %d", (int)s[i]);
  xil_printf("\r\n");
}

int main(void)
{
  init_platform();
  xil_printf("\r\n=== kung_svd HW vs SW compare (N=%d) ===\r\n", SVD_N);

  float A_sw[SVD_N2];
  float sigma_f[SVD_N];
  int32_t sigma_sw[SVD_N];
  int32_t sigma_hw[SVD_N];
  int32_t out_hw[SVD_N2];

  for (int i = 0; i < SVD_N2; ++i)
    A_sw[i] = svd_q116_to_f32(kSvdInputQ116[i]);

  XTime t0, t1;
  XTime_GetTime(&t0);
  svd_onesided_jacobi_f32(A_sw, SVD_N, SWEEPS, sigma_f);
  svd_sort_sigma_desc(sigma_f, SVD_N);
  for (int i = 0; i < SVD_N; ++i)
    sigma_sw[i] = svd_f32_to_q116(sigma_f[i]);
  XTime_GetTime(&t1);
  xil_printf("SW Jacobi cycles (approx timer): %u\r\n",
             (unsigned)(t1 - t0));

  print_sigma("SW sigma_q", sigma_sw, SVD_N);
  print_sigma("Golden   ", kSvdSigmaQ116, SVD_N);

  svd_compare_result_t sw_vs_gold =
      svd_compare_sigma_q116(sigma_sw, kSvdSigmaQ116, SVD_N, 512, 128);
  xil_printf("SW vs golden: %s  max_diff=%d\r\n",
             sw_vs_gold.pass ? "PASS" : "FAIL", sw_vs_gold.max_diff_q);

  XTime_GetTime(&t0);
  if (!svd_hw_run(kSvdInputQ116, out_hw, SVD_N)) {
    xil_printf("HW DMA transfer FAILED\r\n");
    cleanup_platform();
    return 1;
  }
  XTime_GetTime(&t1);
  xil_printf("HW DMA+SVD wall timer: %u\r\n", (unsigned)(t1 - t0));

  svd_sigma_from_matrix_q116(out_hw, SVD_N, sigma_hw);
  print_sigma("HW sigma_q", sigma_hw, SVD_N);

  svd_compare_result_t hw_vs_gold =
      svd_compare_sigma_q116(sigma_hw, kSvdSigmaQ116, SVD_N, 512, 128);
  svd_compare_result_t hw_vs_sw =
      svd_compare_sigma_q116(sigma_hw, sigma_sw, SVD_N, 512, 128);

  xil_printf("HW vs golden: %s  max_diff=%d\r\n",
             hw_vs_gold.pass ? "PASS" : "FAIL", hw_vs_gold.max_diff_q);
  xil_printf("HW vs SW:     %s  max_diff=%d\r\n",
             hw_vs_sw.pass ? "PASS" : "FAIL", hw_vs_sw.max_diff_q);

  int rc = (hw_vs_gold.pass && hw_vs_sw.pass) ? 0 : 1;
  xil_printf("=== %s ===\r\n", rc == 0 ? "PASS" : "FAIL");
  cleanup_platform();
  return rc;
}
