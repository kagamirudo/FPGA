#include "lu_io.h"
#include <stdio.h>

int convert_1d_to_2d(uint16_t *input_matrix, uint8_t size, uint16_t output_matrix[size][size])
{
    for (int i = 0; i < size; i++)
    {
        for (int j = 0; j < size; j++)
        {
            output_matrix[i][j] = input_matrix[i * size + j];
        }
    }
    return 0;
}

uint8_t lu_io_get_input_matrix(uint8_t size, uint16_t input_matrix[size][size],
                               uint8_t band_width, uint8_t band_height,
                               uint16_t output_matrix[band_height][band_width], uint8_t *max_k)
{
    // Inputs at port k have nonzeros at tp >= 2*k and (tp - 2*k) % 3 == 0
    // For k >= 0: y(tp,k) = a[t][t+k] where t = (tp - 2*k)/3
    // For k < 0:  y(tp,k) = a[t+|k|][t] where t = (tp - 2*k)/3

    int n = size;
    int r, c, k, tp;
    int delta, t, ii, jj;

    // Clear output matrix (rows = diagonals indexed by k from -max..+max mapped via diag_idx, cols = positions tp)
    for (r = 0; r < band_height; ++r)
        for (c = 0; c < band_width; ++c)
            output_matrix[r][c] = 0;

    for (k = 0; k <= (n - 1); ++k)
    {
        for (tp = 0; tp < band_width; ++tp)
        {
            if (k >= 0 && tp < 2 * k)
            {
                // not started yet for this k (only applies to k >= 0)
                continue;
            }
            delta = tp - 2 * k;
            if ((delta % 3) != 0)
                continue;
            t = delta / 3;
            // k >= 0: y(tp,k) = a[t][t+k]
            ii = t;
            jj = t + k;

            if (ii >= 0 && ii < n && jj >= 0 && jj < n)
            {
                output_matrix[k + (n - 1)][tp] = input_matrix[ii][jj]; // map k in [-(n-1)..(n-1)] to [0..2n-2]
                output_matrix[-k + (n - 1)][tp] = input_matrix[jj][ii];
            }
        }
    }

    *max_k = (uint8_t)(n - 1);
    return 0;
}

// Converts a fixed-point hex code to a floating-point fraction.
// format_fraction: upper 4 bits = integer bits, lower 4 bits = fraction bits (e.g., 0x65 for 6Q5)
float convert_hex_to_fraction(uint16_t hex_code, uint8_t format_fraction)
{
    uint8_t integer_bits = (format_fraction >> 4) & 0xF;
    uint8_t fraction_bits = format_fraction & 0xF;
    uint8_t total_bits = integer_bits + fraction_bits;

    // Mask to get only the relevant bits
    uint16_t mask = (1 << total_bits) - 1;
    uint16_t value = hex_code & mask;

    // Check if the number is negative (two's complement)
    float result;
    if (integer_bits > 0 && (value & (1 << (total_bits - 1))))
    {
        // Negative number
        int32_t signed_value = value | (~mask); // Sign-extend
        result = (float)signed_value / (1 << fraction_bits);
    }
    else
    {
        // Positive number
        result = (float)value / (1 << fraction_bits);
    }
    return result;
}

uint16_t convert_fraction_to_hex(float fraction, uint8_t format_fraction)
{
    uint8_t integer_bits = (format_fraction >> 4) & 0xF;
    uint8_t fraction_bits = format_fraction & 0xF;
    uint8_t total_bits = integer_bits + fraction_bits;

    // Calculate the maximum positive value for this format
    int32_t max_positive = (1 << (total_bits - 1)) - 1;
    int32_t min_negative = -(1 << (total_bits - 1));

    // Clamp the fraction to the valid range
    if (fraction > max_positive)
    {
        fraction = max_positive;
    }
    else if (fraction < min_negative)
    {
        fraction = min_negative;
    }

    // Convert fraction to fixed-point representation
    int32_t fixed_point = (int32_t)(fraction * (1 << fraction_bits));

    // Handle negative numbers with two's complement
    uint16_t result;
    if (fixed_point < 0)
    {
        // For negative numbers, use two's complement
        result = (uint16_t)((1 << total_bits) + fixed_point);
    }
    else
    {
        // For positive numbers, use the value directly
        result = (uint16_t)fixed_point;
    }

    // Mask to keep only the relevant bits
    uint16_t mask = (1 << total_bits) - 1;
    result = result & mask;

    return (uint16_t)result;
}

// Print band matrix in table format with transposed axes (uint16_t)
void print_band_matrix_u16(const char *title, int rows, int cols,
                           uint16_t matrix[rows][cols], int max_k)
{
    printf("%s\n", title);

    printf("      |");
    for (int diag = -max_k; diag <= max_k; diag++)
    {
        printf("  k=%2d  |", diag);
    }
    printf("\n");
    printf("------|");
    for (int diag = -max_k; diag <= max_k; diag++)
    {
        printf("--------|");
    }
    printf("\n");

    // Rows are positions (0..cols-1), columns are diagonals k
    for (int pos = 0; pos < cols; pos++)
    {
        printf("Pos%2d |", pos);
        for (int diag = -max_k; diag <= max_k; diag++)
        {
            int diag_idx = diag + max_k;
            if (diag_idx >= 0 && diag_idx < rows)
            {
                uint16_t v = matrix[diag_idx][pos];
                if (v == 0)
                    printf("    .   |");
                else
                    printf(" %6d |", (int)v);
            }
            else
            {
                printf("    .   |");
            }
        }
        printf("\n");
    }
    printf("\n");
}

// Print band matrix in table format with transposed axes (float)
void print_band_matrix_f32(const char *title, int rows, int cols,
                           float matrix[rows][cols], int max_k)
{
    printf("%s\n", title);

    printf("      |");
    for (int diag = -max_k; diag <= max_k; diag++)
    {
        printf("  k=%2d  |", diag);
    }
    printf("\n");
    printf("------|");
    for (int diag = -max_k; diag <= max_k; diag++)
    {
        printf("--------|");
    }
    printf("\n");

    // Rows are positions (0..cols-1), columns are diagonals k
    for (int pos = 0; pos < cols; pos++)
    {
        printf("Pos%2d |", pos);
        for (int diag = -max_k; diag <= max_k; diag++)
        {
            int diag_idx = diag + max_k;
            if (diag_idx >= 0 && diag_idx < rows)
            {
                float v = matrix[diag_idx][pos];
                if (v == 0.0f)
                    printf("    .   |");
                else
                    printf(" %6.3f |", v);
            }
            else
            {
                printf("    .   |");
            }
        }
        printf("\n");
    }
    printf("\n");
}

// Print the internal band matrix layout as stored (diagonals as rows, positions as columns)
void print_band_matrix_raw(const char *title, void *matrix,
                           int matrix_size, int num_rows, int num_cols, int is_float)
{
    printf("%s\n", title);
    // Header
    printf("       ");
    for (int c = 0; c < num_cols; ++c)
    {
        printf("   c%02d  ", c);
    }
    printf("\n");
    // Rows
    for (int r = 0; r < num_rows; ++r)
    {
        printf("r%02d | ", r);
        for (int c = 0; c < num_cols; ++c)
        {
            int idx = r * num_cols + c;
            if (idx < matrix_size)
            {
                if (is_float)
                {
                    float *float_matrix = (float *)matrix;
                    float value = float_matrix[idx];
                    if (value == 0.0)
                        printf("   .    ");
                    else
                        printf(" %6.3f ", value);
                }
                else
                {
                    uint16_t *uint_matrix = (uint16_t *)matrix;
                    if (uint_matrix[idx] == 0)
                        printf("   .    ");
                    else
                        printf(" %6d ", uint_matrix[idx]);
                }
            }
            else
            {
                printf("   .    ");
            }
        }
        printf("\n");
    }
    printf("\n");
}

// Function to capture L and U matrices from hardware output sequence
// Based on the theory: L uses k < 0 diagonals, U uses k >= 0 diagonals
// Both have rate = 1/3, meaning values appear every 3 time steps
void get_result_LU(uint8_t size, uint16_t *l_values, uint16_t *u_values,
                   uint16_t L_matrix[size][size], uint16_t U_matrix[size][size])
{
    int n = size;
    // int l_bound = (size - 1) * 2;
    // int u_bound = size * size - l_bound;
    int i, j, jump;
    int l_idx = 0;
    int u_idx = 0;

    // Initialize matrices
    for (i = 0; i < n; i++)
    {
        for (j = 0; j < n; j++)
        {
            L_matrix[i][j] = 0;
            U_matrix[i][j] = 0;
        }
    }

    // Set diagonal of L to 1
    for (i = 0; i < n; i++)
    {
        L_matrix[i][i] = convert_fraction_to_hex(1.0f, 0x65);
    }

    l_idx = n * (n - 1); // skip 4 cycles
    for (i = 0; i < n - 1; i++)
    {
        jump = 0;
        for (j = i + 1; j < n; j++)
        {
            L_matrix[j][i] = l_values[l_idx + jump];
            // printf("l_values[%d] = %f\n", l_idx + jump, convert_hex_to_fraction(l_values[l_idx + jump], 0x65));
            jump += n;
            if (j == n - 1)
            {
                // printf("l_idx = %d, j = %d\n", l_idx, j);
                l_idx += (j - i) * (n - 1);
            }
        }
    }

    u_idx = (n - 2) * n; // skip 2 cycles
    for (i = 0; i < n; i++)
    {
        jump = 0;
        for (j = i; j < n; j++)
        {
            if (j == n - 1 && i == 0)
            {
                U_matrix[i][j] = u_values[u_idx + 5 * n - 1];
                u_idx = 5 * n;
                continue;
            }
            else
                U_matrix[i][j] = u_values[u_idx + jump];
            jump += n + 1;
            if (j == n - 1)
            {
                // printf("u_idx = %d, j = %d\n", u_idx, j);
                u_idx += j * n;
            }
        }
    }
}

// Function to extract L and U matrices from band matrix output
// This processes the output from lu_io_get_input_matrix to reconstruct L and U
void extract_LU_from_band_matrix(uint8_t size, uint8_t band_width, uint16_t band_matrix[][band_width],
                                 uint16_t L_matrix[size][size], uint16_t U_matrix[size][size])
{
    int n = size;
    int i, j, k, t, t_prime;

    // Initialize matrices
    for (i = 0; i < n; i++)
    {
        for (j = 0; j < n; j++)
        {
            L_matrix[i][j] = 0;
            U_matrix[i][j] = 0;
        }
    }

    // Set diagonal of L to 1
    for (i = 0; i < n; i++)
    {
        L_matrix[i][i] = 1;
    }

    // Process L matrix (lower triangular, k < 0)
    for (k = 1; k < n; k++)
    { // k = 1, 2, ..., n-1 (corresponds to k = -1, -2, ..., -(n-1))
        t = 0;
        t_prime = 0;

        while (t_prime < band_width)
        { // Use dynamic band_width
            if (t_prime >= n - 1)
            {
                if (((t_prime - (n - 1) - k) % 3) == 0)
                {
                    // Extract l(t-k+1, t+1) = -z(t', k)
                    int row = t - k + 1;
                    int col = t + 1;
                    if (row >= 0 && row < n && col >= 0 && col < n)
                    {
                        // Get value from band matrix: diag_idx = -k + (n-1)
                        int diag_idx = -k + (n - 1);
                        uint16_t value = band_matrix[diag_idx][t_prime];
                        L_matrix[row][col] = value;
                    }
                    t++;
                }
            }
            t_prime++;
        }
    }

    // Process U matrix (upper triangular, k >= 0)
    for (k = 0; k < n; k++)
    { // k = 0, 1, 2, ..., n-1
        t = 0;
        t_prime = 0;

        while (t_prime < band_width)
        {
            if (t_prime >= n - 1 && t_prime < 3 * n)
            {
                if (((t_prime - (n - 1) - k) % 3) == 0)
                {
                    // Extract u(t+1, t+k+1) = z(t', k)
                    int row = t;
                    int col = t + k;
                    if (row >= 0 && row < n && col >= 0 && col < n)
                    {
                        // Get value from band matrix: diag_idx = k + (n-1)
                        int diag_idx = k + (n - 1);
                        uint16_t value = band_matrix[diag_idx][t_prime];
                        U_matrix[row][col] = value;
                    }
                    t++;
                }
            }
            t_prime++;
        }
    }
}

// Function to simulate the hardware sequence and extract L and U matrices
// This simulates the xil_printf sequence you provided
void simulate_math_lu(uint8_t size, uint8_t format_fraction, uint16_t A[size][size], uint16_t L_matrix[size][size], uint16_t U_matrix[size][size])
{
    int n = size;
    int i, j, k;

    // Use a temporary float matrix for computation
    float Af[n][n];
    float L[n][n];
    float U[n][n];

    // Convert input A (uint16_t, fixed-point) to float
    for (i = 0; i < n; ++i)
        for (j = 0; j < n; ++j)
            Af[i][j] = convert_hex_to_fraction(A[i][j], format_fraction);

    // Initialize L and U to zero
    for (i = 0; i < n; ++i)
        for (j = 0; j < n; ++j)
            L[i][j] = U[i][j] = 0.0f;

    // Doolittle LU decomposition (no pivoting)
    for (i = 0; i < n; ++i)
    {
        // Upper Triangular
        for (k = i; k < n; ++k)
        {
            float sum = 0.0f;
            for (j = 0; j < i; ++j)
                sum += L[i][j] * U[j][k];
            U[i][k] = Af[i][k] - sum;
        }

        // Lower Triangular
        for (k = i; k < n; ++k)
        {
            if (i == k)
                L[i][i] = 1.0f; // Diagonal as 1
            else
            {
                float sum = 0.0f;
                for (j = 0; j < i; ++j)
                    sum += L[k][j] * U[j][i];
                L[k][i] = (U[i][i] != 0.0f) ? (Af[k][i] - sum) / U[i][i] : 0.0f;
            }
        }
    }

    // Store result in output matrices (convert to uint16_t using fixed-point format)
    for (i = 0; i < n; ++i)
    {
        for (j = 0; j < n; ++j)
        {
            L_matrix[i][j] = convert_fraction_to_hex(L[i][j], format_fraction);
            U_matrix[i][j] = convert_fraction_to_hex(U[i][j], format_fraction);
        }
    }
}

// Print L or U matrix
void print_matrix(const char *title, uint8_t size, uint16_t matrix[size][size])
{
    printf("%s:\n", title);
    for (int i = 0; i < size; i++)
    {
        for (int j = 0; j < size; j++)
        {
            printf("%6x ", matrix[i][j]);
        }
        printf("\n");
    }
    printf("\n");
}

void print_matrix_decimal(const char *title, uint8_t size, uint8_t format_fraction, uint16_t matrix[size][size])
{
    printf("%s:\n", title);
    for (int i = 0; i < size; i++)
    {
        for (int j = 0; j < size; j++)
        {
            printf("%8.3f ", convert_hex_to_fraction(matrix[i][j], format_fraction));
        }
        printf("\n");
    }
    printf("\n");
}
