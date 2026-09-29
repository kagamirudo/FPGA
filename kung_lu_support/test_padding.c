#include "lu_io.h"
#include <stdio.h>
#include <string.h>

// Verifies the block-identity padding scheme: embedding an n x n matrix A as
// [[A, 0], [0, I]] in an m x m matrix, then running simulate_math_lu at size
// m, must reproduce A's standalone n x n L/U factors exactly in the top-left
// block. Also contrasts this against naive zero-padding, which produces a
// singular (all-zero-pivot) extension and must NOT be used.

static const uint8_t FMT = 0x65; // 6Q5 fixed point, matches lu_pkg.vhd (W=11,F=5)

static int compare_top_left_block(uint8_t n, uint16_t L_std[n][n], uint16_t U_std[n][n],
                                  uint8_t m, uint16_t L_pad[m][m], uint16_t U_pad[m][m],
                                  const char *label)
{
    int mismatches = 0;
    for (int i = 0; i < n; i++)
    {
        for (int j = 0; j < n; j++)
        {
            if (L_std[i][j] != L_pad[i][j])
            {
                printf("  DIFF L[%d][%d]: standalone=%.3f padded(m=%d)=%.3f\n", i, j,
                       convert_hex_to_fraction(L_std[i][j], FMT),
                       m, convert_hex_to_fraction(L_pad[i][j], FMT));
                mismatches++;
            }
            if (U_std[i][j] != U_pad[i][j])
            {
                printf("  DIFF U[%d][%d]: standalone=%.3f padded(m=%d)=%.3f\n", i, j,
                       convert_hex_to_fraction(U_std[i][j], FMT),
                       m, convert_hex_to_fraction(U_pad[i][j], FMT));
                mismatches++;
            }
        }
    }
    if (mismatches == 0)
        printf("  [PASS] %s: top-left %dx%d L/U block matches standalone %dx%d exactly\n",
               label, n, n, n, n);
    else
        printf("  [FAIL] %s: %d mismatches\n", label, mismatches);
    return mismatches;
}

static int run_case(const char *name, uint8_t n, uint16_t A[n][n], uint8_t m)
{
    printf("=== %s: n=%d, padded to m=%d ===\n", name, n, m);

    uint16_t L_std[n][n], U_std[n][n];
    simulate_math_lu(n, FMT, A, L_std, U_std);

    uint16_t A_pad[m][m];
    build_padded_matrix(n, m, FMT, A, A_pad);

    uint16_t L_pad[m][m], U_pad[m][m];
    simulate_math_lu(m, FMT, A_pad, L_pad, U_pad);

    int mismatches = compare_top_left_block(n, L_std, U_std, m, L_pad, U_pad, "block-identity padding");

    // Check the extended (bottom-right) diagonal came out as identity pivots,
    // as the block-diagonal proof requires.
    int extension_ok = 1;
    for (int i = n; i < m; i++)
    {
        float lii = convert_hex_to_fraction(L_pad[i][i], FMT);
        float uii = convert_hex_to_fraction(U_pad[i][i], FMT);
        if (lii != 1.0f || uii != 1.0f)
            extension_ok = 0;
    }
    printf("  Extension block identity check: %s\n\n", extension_ok ? "[PASS]" : "[FAIL]");

    return mismatches != 0 || !extension_ok;
}

static void run_naive_zero_padding_contrast(void)
{
    printf("=== Naive zero-padding contrast (expected to break, not used in practice) ===\n");
    uint8_t n = 2, m = 4;
    uint16_t A[2][2] = {
        {convert_fraction_to_hex(2.0f, FMT), convert_fraction_to_hex(1.0f, FMT)},
        {convert_fraction_to_hex(4.0f, FMT), convert_fraction_to_hex(5.0f, FMT)},
    };

    uint16_t A_zero_pad[4][4];
    memset(A_zero_pad, 0, sizeof(A_zero_pad));
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
            A_zero_pad[i][j] = A[i][j];
    // Extended diagonal entries are left at 0 -- this is the unsafe scheme.

    uint16_t L[4][4], U[4][4];
    simulate_math_lu(m, FMT, A_zero_pad, L, U);

    // U[2][2] and U[3][3] are the zero pivots that naive zero-padding creates.
    float u22 = convert_hex_to_fraction(U[2][2], FMT);
    float u33 = convert_hex_to_fraction(U[3][3], FMT);
    printf("  Zero-padded extension pivots: U[2][2]=%.3f, U[3][3]=%.3f\n", u22, u33);
    if (u22 == 0.0f && u33 == 0.0f)
        printf("  [CONFIRMED] naive zero-padding produces zero pivots on the extended diagonal"
               " (simulate_math_lu's divide-by-zero guard returns 0.0 for L there) --"
               " this is exactly why block-identity padding is used instead.\n\n");
    else
        printf("  [UNEXPECTED] zero pivots not reproduced -- re-check assumptions.\n\n");
}

int main(void)
{
    printf("=== LU Padding Validation ===\n\n");

    uint16_t A4[4][4];
    float vals4[] = {2, 1, 0, 2, 4, 5, 1, 3, 2, -2, 1, 7, 6, 9, 2, 9};
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            A4[i][j] = convert_fraction_to_hex(vals4[i * 4 + j], FMT);

    int total_fail = 0;
    total_fail += run_case("4x4 -> 6x6", 4, A4, 6);
    total_fail += run_case("4x4 -> 10x10", 4, A4, 10);

    uint16_t A3[3][3];
    float vals3[] = {3, 1, 2, 1, 4, 1, 2, 1, 5};
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
            A3[i][j] = convert_fraction_to_hex(vals3[i * 3 + j], FMT);
    total_fail += run_case("3x3 -> 10x10", 3, A3, 10);

    run_naive_zero_padding_contrast();

    if (total_fail == 0)
        printf("=== All padding validation cases passed ===\n");
    else
        printf("=== %d case(s) FAILED ===\n", total_fail);

    return total_fail != 0;
}
