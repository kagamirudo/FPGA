#include "svd_hw_dma.h"

#ifdef SVD_HOST_ONLY

bool svd_hw_run(const int32_t *in_q, int32_t *out_q, int n)
{
  (void)in_q;
  (void)out_q;
  (void)n;
  return false;
}

#else

#include "xaxidma.h"
#include "xil_cache.h"
#include "xparameters.h"

#ifndef XPAR_AXI_DMA_0_DEVICE_ID
/* Vitis 2025 may emit base-address macros instead of DEVICE_ID. */
#define SVD_DMA_DEVICE_ID 0
#else
#define SVD_DMA_DEVICE_ID XPAR_AXI_DMA_0_DEVICE_ID
#endif

static XAxiDma s_dma;
static int s_dma_ready = 0;

static int dma_init(void)
{
  if (s_dma_ready) return 0;
  XAxiDma_Config *cfg = XAxiDma_LookupConfig(SVD_DMA_DEVICE_ID);
  if (!cfg) return -1;
  if (XAxiDma_CfgInitialize(&s_dma, cfg) != XST_SUCCESS) return -2;
  if (XAxiDma_HasSg(&s_dma)) return -3; /* expect simple mode */
  XAxiDma_IntrDisable(&s_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
  XAxiDma_IntrDisable(&s_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
  s_dma_ready = 1;
  return 0;
}

bool svd_hw_run(const int32_t *in_q, int32_t *out_q, int n)
{
  const int n2 = n * n;
  const UINTPTR bytes = (UINTPTR)n2 * sizeof(int32_t);

  if (dma_init() != 0) return false;

  /* DMA buffers must be cache-line aligned and non-cache-coherent flushes. */
  static int32_t tx[64] __attribute__((aligned(32)));
  static int32_t rx[64] __attribute__((aligned(32)));
  if (n2 > 64) return false;

  for (int i = 0; i < n2; ++i) {
    /* Sign-extend Q1.16 18-bit into 32-bit lane */
    int32_t v = in_q[i] & 0x3ffff;
    if (v & 0x20000) v |= ~0x3ffff;
    tx[i] = v;
    rx[i] = 0xDEADBEEF;
  }

  Xil_DCacheFlushRange((UINTPTR)tx, bytes);
  Xil_DCacheFlushRange((UINTPTR)rx, bytes);

  /* Start S2MM first so the core never blocks on m_axis_tready */
  if (XAxiDma_SimpleTransfer(&s_dma, (UINTPTR)rx, (u32)bytes,
                             XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS)
    return false;
  if (XAxiDma_SimpleTransfer(&s_dma, (UINTPTR)tx, (u32)bytes,
                             XAXIDMA_DMA_TO_DEVICE) != XST_SUCCESS)
    return false;

  /* Wait for both channels (timeout ~ tens of ms at 25 MHz / 3k cycles) */
  int guard = 10000000;
  while (guard-- > 0) {
    int busy_mm2s = XAxiDma_Busy(&s_dma, XAXIDMA_DMA_TO_DEVICE);
    int busy_s2mm = XAxiDma_Busy(&s_dma, XAXIDMA_DEVICE_TO_DMA);
    if (!busy_mm2s && !busy_s2mm) break;
  }
  if (guard <= 0) return false;

  Xil_DCacheInvalidateRange((UINTPTR)rx, bytes);
  for (int i = 0; i < n2; ++i) {
    int32_t v = rx[i] & 0x3ffff;
    if (v & 0x20000) v |= ~0x3ffff;
    out_q[i] = v;
  }
  return true;
}

#endif /* SVD_HOST_ONLY */
