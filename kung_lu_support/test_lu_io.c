#include "lu_io.h"
#include <stdio.h>

int main()
{
    printf("=== LU IO Package Test ===\n\n");

    // Test data
    uint16_t input_matrix[16] = {
        0x20, 0x20, 0x80, 0x60,
        0x40, 0x20, 0x7e0, 0x20,
        0x60, 0x7e0, 0x7e0, 0x40,
        0x7e0, 0x40, 0x60, 0x7e0};

    const int n = 4;
    const int band_height = 2 * n - 1;      // 7 diagonals
    const int band_width = 2 * (2 * n - 1); // 14 positions
    uint16_t input_2d[n][n];
    uint16_t band_matrix[band_height][band_width];
    uint8_t max_k;

    // Test 1: Fixed-point conversion
    printf("1. Fixed-Point Conversion Test:\n");
    printf("   -5.5 -> 0x%x -> %f\n",
           convert_fraction_to_hex(-5.5, 0x65),
           convert_hex_to_fraction(0x750, 0x65));
    printf("\n");

    // Test 2: Matrix conversion and band matrix generation
    printf("2. Band Matrix Generation Test:\n");
    convert_1d_to_2d(input_matrix, n, input_2d);
    lu_io_get_input_matrix(n, input_2d, band_width, band_height, band_matrix, &max_k);
    // Convert band_matrix to float for printing as float format
    float band_matrix_f32[band_height][band_width];
    for (int i = 0; i < band_height; i++)
        for (int j = 0; j < band_width; j++)
            band_matrix_f32[i][j] = convert_hex_to_fraction(band_matrix[i][j], 0x65);

    print_band_matrix_f32("Generated Band Matrix (float)", band_height, band_width, band_matrix_f32, max_k);

    // Test 3: LU extraction
    printf("3. LU Matrix Extraction Test:\n");
    uint16_t L_matrix[n][n], U_matrix[n][n];
    extract_LU_from_band_matrix(n, band_width, band_matrix, L_matrix, U_matrix);
    print_matrix("L Matrix", n, L_matrix);
    print_matrix("U Matrix", n, U_matrix);

    // Test 4: Hardware simulation
    printf("4. Hardware Simulation Test:\n");
    uint16_t L_hw[n][n], U_hw[n][n];
    simulate_hardware_sequence(n, L_hw, U_hw);
    print_matrix("L Matrix (Hardware)", n, L_hw);
    print_matrix("U Matrix (Hardware)", n, U_hw);

    // Test 5: Larger matrices (5x5)
    printf("5. 5x5 Matrix Test:\n");
    uint16_t input_5x5[25] = {
        0x20, 0x20, 0x80, 0x60, 0x40,
        0x40, 0x20, 0x7e0, 0x20, 0x60,
        0x60, 0x7e0, 0x7e0, 0x40, 0x80,
        0x7e0, 0x40, 0x60, 0x7e0, 0x20,
        0x30, 0x50, 0x70, 0x90, 0x100};

    const int n5 = 5;
    const int band_height_5 = 2 * n5 - 1;      // 9 diagonals
    const int band_width_5 = 2 * (2 * n5 - 1); // 18 positions
    uint16_t input_2d_5[n5][n5];
    uint16_t band_matrix_5[band_height_5][band_width_5];
    uint8_t max_k_5;

    convert_1d_to_2d(input_5x5, n5, input_2d_5);
    lu_io_get_input_matrix(n5, input_2d_5, band_width_5, band_height_5, band_matrix_5, &max_k_5);

    // Convert to float for display
    float band_matrix_f32_5[band_height_5][band_width_5];
    for (int i = 0; i < band_height_5; i++)
        for (int j = 0; j < band_width_5; j++)
            band_matrix_f32_5[i][j] = convert_hex_to_fraction(band_matrix_5[i][j], 0x65);

    print_band_matrix_f32("5x5 Band Matrix (float)", band_height_5, band_width_5, band_matrix_f32_5, max_k_5);

    // Extract LU for 5x5
    uint16_t L_5x5[n5][n5], U_5x5[n5][n5];
    extract_LU_from_band_matrix(n5, band_width_5, band_matrix_5, L_5x5, U_5x5);
    print_matrix("L Matrix (5x5)", n5, L_5x5);
    print_matrix("U Matrix (5x5)", n5, U_5x5);

    // Test 6: Even larger matrix (6x6)
    printf("6. 6x6 Matrix Test:\n");
    uint16_t input_6x6[36] = {
        0x20, 0x20, 0x80, 0x60, 0x40, 0x30,
        0x40, 0x20, 0x7e0, 0x20, 0x60, 0x50,
        0x60, 0x7e0, 0x7e0, 0x40, 0x80, 0x70,
        0x7e0, 0x40, 0x60, 0x7e0, 0x20, 0x90,
        0x30, 0x50, 0x70, 0x90, 0x100, 0x110,
        0x120, 0x130, 0x140, 0x150, 0x160, 0x170};

    const int n6 = 6;
    const int band_height_6 = 2 * n6 - 1;      // 11 diagonals
    const int band_width_6 = 2 * (2 * n6 - 1); // 22 positions
    uint16_t input_2d_6[n6][n6];
    uint16_t band_matrix_6[band_height_6][band_width_6];
    uint8_t max_k_6;

    convert_1d_to_2d(input_6x6, n6, input_2d_6);
    lu_io_get_input_matrix(n6, input_2d_6, band_width_6, band_height_6, band_matrix_6, &max_k_6);

    // Convert to float for display
    float band_matrix_f32_6[band_height_6][band_width_6];
    for (int i = 0; i < band_height_6; i++)
        for (int j = 0; j < band_width_6; j++)
            band_matrix_f32_6[i][j] = convert_hex_to_fraction(band_matrix_6[i][j], 0x65);

    print_band_matrix_f32("6x6 Band Matrix (float)", band_height_6, band_width_6, band_matrix_f32_6, max_k_6);

    // Extract LU for 6x6
    uint16_t L_6x6[n6][n6], U_6x6[n6][n6];
    extract_LU_from_band_matrix(n6, band_width_6, band_matrix_6, L_6x6, U_6x6);
    print_matrix("L Matrix (6x6)", n6, L_6x6);
    print_matrix("U Matrix (6x6)", n6, U_6x6);

    printf("All tests completed successfully!\n");
    return 0;
}