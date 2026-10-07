#include "svd_ref.h"

#include <math.h>
#include <string.h>

float svd_q116_to_f32(int32_t q)
{
  return (float)q / 65536.0f;
}

int32_t svd_f32_to_q116(float x)
{
  float s = x * 65536.0f;
  if (s >= 131071.0f) return 131071;
  if (s <= -131072.0f) return -131072;
  return (int32_t)lroundf(s);
}

static float col_dot(const float *A, int n, int p, int q)
{
  float s = 0.0f;
  for (int r = 0; r < n; ++r)
    s += A[r * n + p] * A[r * n + q];
  return s;
}

static float col_norm2(const float *A, int n, int p)
{
  return col_dot(A, n, p, p);
}

/* Apply right Givens rotation on columns (p, q). */
static void apply_givens(float *A, int n, int p, int q, float c, float s)
{
  for (int r = 0; r < n; ++r) {
    float ap = A[r * n + p];
    float aq = A[r * n + q];
    A[r * n + p] =  c * ap + s * aq;
    A[r * n + q] = -s * ap + c * aq;
  }
}

void svd_onesided_jacobi_f32(float *A, int n, int sweeps, float *sigma)
{
  const float eps = 1e-12f;
  for (int sw = 0; sw < sweeps; ++sw) {
    for (int p = 0; p < n - 1; ++p) {
      for (int q = p + 1; q < n; ++q) {
        float alpha = col_norm2(A, n, p);
        float beta  = col_norm2(A, n, q);
        float gamma = col_dot(A, n, p, q);
        if (fabsf(gamma) < eps * (alpha + beta + eps))
          continue;
        /* θ = 0.5 * atan2(2γ, α − β) */
        float ang = 0.5f * atan2f(2.0f * gamma, alpha - beta);
        float c = cosf(ang);
        float s = sinf(ang);
        apply_givens(A, n, p, q, c, s);
      }
    }
  }
  for (int j = 0; j < n; ++j)
    sigma[j] = sqrtf(col_norm2(A, n, j));
}

void svd_sort_sigma_desc(float *sigma, int n)
{
  for (int i = 0; i < n - 1; ++i) {
    for (int j = 0; j < n - 1 - i; ++j) {
      if (sigma[j] < sigma[j + 1]) {
        float t = sigma[j];
        sigma[j] = sigma[j + 1];
        sigma[j + 1] = t;
      }
    }
  }
}
