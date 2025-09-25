#include "lu_io.h"
#include <stdio.h>

int main()
{
    printf("=== LU IO Package Example ===\n\n");

    // Example 1: Basic matrix processing
    printf("1. Basic Matrix Processing:\n");
    printf("============================\n");

    // Define a 4x4 input matrix
    uint16_t input_matrix[16] = {
        0x20, 0x20, 0x80, 0x60,
        0x40, 0x20, 0x7e0, 0x20,
        0x60, 0x7e0, 0x7e0, 0x40,
        0x7e0, 0x40, 0x60, 0x7e0};

    int n = 4;
    int band_height = 2 * n - 1;      // 7 diagonals
    int band_width = 2 * (2 * n - 1); // 14 positions
    uint16_t input_2d[n][n];
    uint16_t band_matrix[band_height][band_width];
    uint8_t max_k;

    // Convert 1D to 2D
    convert_1d_to_2d(input_matrix, n, input_2d);

    // Generate band matrix
    lu_io_get_input_matrix(n, input_2d, band_width, band_height,
                           band_matrix, &max_k);

    // Print band matrix
    print_band_matrix_u16("Generated Band Matrix", band_height, band_width,
                          band_matrix, max_k);

    // Example 2: LU extraction
    printf("\n2. LU Matrix Extraction:\n");
    printf("=========================\n");

    uint16_t L_matrix[n][n], U_matrix[n][n];
    extract_LU_from_band_matrix(n, band_width, band_matrix, L_matrix, U_matrix);

    print_matrix("L Matrix (Lower Triangular)", n, L_matrix);
    print_matrix("U Matrix (Upper Triangular)", n, U_matrix);

    // Example 3: Fixed-point conversion
    printf("\n3. Fixed-Point Conversion:\n");
    printf("===========================\n");

    float test_values[] = {-5.5, 2.25, -1.0, 3.75};
    printf("Testing 6Q5 format (6 integer bits, 5 fraction bits):\n");

    for (int i = 0; i < 4; i++)
    {
        uint16_t hex_val = convert_fraction_to_hex(test_values[i], 0x65);
        float back_to_float = convert_hex_to_fraction(hex_val, 0x65);
        printf("Original: %6.2f -> Hex: 0x%04x -> Back: %6.2f\n",
               test_values[i], hex_val, back_to_float);
    }

    // Example 4: Hardware simulation
    printf("\n4. Hardware Simulation:\n");
    printf("========================\n");

    uint16_t L_hw[n][n], U_hw[n][n];
    simulate_math_lu(n, 0x65, input_2d, L_hw, U_hw);

    print_matrix_decimal("L Matrix (Math Simulated)", n, 0x65, L_hw);
    print_matrix_decimal("U Matrix (Math Simulated)", n, 0x65, U_hw);

    printf("\nExample completed successfully!\n");
    return 0;
}
