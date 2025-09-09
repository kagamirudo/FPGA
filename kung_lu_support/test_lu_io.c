#include "lu_io.h"
#include <stdio.h>

int main()
{
    printf("=== LU IO Package Test ===\n");
    printf("convert_fraction_to_hex(-5.5, 0x65) = %x\n", convert_fraction_to_hex(-5.5, 0x65));
    printf("convert_hex_to_fraction(0x6f0, 0x65) = %f\n", convert_hex_to_fraction(0x6f0, 0x65));
    
    // Test the function with a 4x4 input matrix (actual data, no padding)
    uint16_t input_matrix[16] = {
        0x20, 0x20, 0x80, 0x60,
        0x40, 0x20, 0x7e0, 0x20,
        0x60, 0x7e0, 0x7e0, 0x40,
        0x7e0, 0x40, 0x60, 0x7e0};

    int n = 4;                        // Size of input matrix (4x4)
    int band_height = 2 * n - 1;      // number of diagonals (7)
    int band_width = 2 * (2 * n - 1); // positions (14)
    uint16_t input_matrix_2d[n][n];
    uint16_t output_band_matrix[band_height][band_width];
    uint8_t matrix_size = band_height * band_width; // For flatten 1D array
    uint8_t dim_size = band_height;
    uint8_t max_k = 6;

    convert_1d_to_2d(input_matrix, n, input_matrix_2d);
    lu_io_get_input_matrix(n, input_matrix_2d, band_width, band_height, output_band_matrix, &max_k);

    // Print the output matrix (rows=diagonals, cols=positions)
    print_band_matrix_u16("Output matrix (7 diagonals x 14 elements)", band_height, band_width, output_band_matrix, max_k);
    // Also print raw (rows=diagonals, cols=positions)
    print_band_matrix_raw("Output matrix RAW (rows: diagonals, cols: positions)", output_band_matrix,
                          matrix_size, band_height, band_width, 0);

    // Convert the output matrix to fractions and store in a separate array
    float fraction_matrix[band_height][band_width];
    for (int i = 0; i < band_height; i++)
    {
        for (int j = 0; j < band_width; j++)
        {
            fraction_matrix[i][j] = convert_hex_to_fraction(output_band_matrix[i][j], 0x65);
        }
    }

    // Print the fraction matrix
    print_band_matrix_f32("Fraction matrix (7 diagonals x 14 elements)", band_height, band_width, fraction_matrix, max_k);
    print_band_matrix_raw("Fraction matrix RAW (rows: diagonals, cols: positions)", fraction_matrix,
                          matrix_size, band_height, band_width, 1);

    // print the original input matrix as fraction with format 4x4 matrix
    printf("Original input matrix as fraction:\n");
    for (int i = 0; i < 4; i++)
    {
        for (int j = 0; j < 4; j++)
        {
            printf("%8.3f ", convert_hex_to_fraction(input_matrix[i * 4 + j], 0x65));
        }
        printf("\n");
    }
    printf("\n");

    // get the fraction matrix and convert to hex
    uint16_t hex_matrix[band_height][band_width];
    for (int i = 0; i < band_height; i++)
    {
        for (int j = 0; j < band_width; j++)
        {
            hex_matrix[i][j] = convert_fraction_to_hex(fraction_matrix[i][j], 0x65);
        }
    }

    // print the hex matrix
    print_band_matrix_u16("Hex matrix (13 diagonals x 7 elements)", band_height, band_width, hex_matrix, max_k);
    // print_band_matrix_raw("Hex matrix RAW (rows: diagonals, cols: positions)", hex_matrix,
    //                       matrix_size, band_height, band_width, 0);

    // Demonstrate LU extraction
    printf("\n=== LU Matrix Extraction Demo ===\n");

    // Method 1: Extract from band matrix
    uint16_t L_matrix[n][n], U_matrix[n][n];
    extract_LU_from_band_matrix(n, output_band_matrix, L_matrix, U_matrix);
    print_matrix("L Matrix (from band matrix)", n, L_matrix);
    print_matrix("U Matrix (from band matrix)", n, U_matrix);

    // Method 2: Simulate hardware sequence
    uint16_t L_hw[n][n], U_hw[n][n];
    simulate_hardware_sequence(n, L_hw, U_hw);
    print_matrix("L Matrix (simulated hardware)", n, L_hw);
    print_matrix("U Matrix (simulated hardware)", n, U_hw);

    return 0;
}
