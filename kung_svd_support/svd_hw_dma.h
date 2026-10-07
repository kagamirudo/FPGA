#ifndef SVD_HW_DMA_H
#define SVD_HW_DMA_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Run one N×N matrix through the PL SVD via AXI DMA.
 * in_q / out_q are row-major Q1.16 values in the low 18 bits of each word.
 * Returns true on success.
 *
 * When SVD_HOST_ONLY is defined, this is a stub that returns false. */
bool svd_hw_run(const int32_t *in_q, int32_t *out_q, int n);

#ifdef __cplusplus
}
#endif

#endif /* SVD_HW_DMA_H */
