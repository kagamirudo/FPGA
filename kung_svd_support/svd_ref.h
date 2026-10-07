#ifndef SVD_REF_H
#define SVD_REF_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Pure-C one-sided Jacobi SVD on an N×N row-major float matrix.
 * On return, A holds the rotated matrix (V applied from the right);
 * sigma[i] is the L2 norm of column i (unsorted).
 * sweeps: number of cyclic sweeps over all column pairs. */
void svd_onesided_jacobi_f32(float *A, int n, int sweeps, float *sigma);

/* Sort sigma descending in place. */
void svd_sort_sigma_desc(float *sigma, int n);

/* Q1.16 helpers (scale = 2^16). */
float    svd_q116_to_f32(int32_t q);
int32_t  svd_f32_to_q116(float x);

#ifdef __cplusplus
}
#endif

#endif /* SVD_REF_H */
