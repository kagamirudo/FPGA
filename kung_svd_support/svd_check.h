#ifndef SVD_CHECK_H
#define SVD_CHECK_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Column L2 norms of row-major Q1.16 matrix → sorted descending Q1.16 σ. */
void svd_sigma_from_matrix_q116(const int32_t *A, int n, int32_t *sigma_q);

/* Compare HW/SW σ against golden. tol_q is absolute Q1.16 tolerance floor;
 * also allows relative tol = top_sigma / rel_div (BLV uses 512). */
typedef struct {
  int max_diff_q;
  int fail_count;
  bool pass;
} svd_compare_result_t;

svd_compare_result_t svd_compare_sigma_q116(const int32_t *got,
                                            const int32_t *expected,
                                            int n,
                                            int rel_div,
                                            int tol_floor_q);

#ifdef __cplusplus
}
#endif

#endif /* SVD_CHECK_H */
