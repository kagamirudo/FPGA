#ifndef LU_IO_H
#define LU_IO_H

#include <stdint.h>

int convert_1d_to_2d(uint16_t *input_matrix, uint8_t size,
                     uint16_t output_matrix[size][size]);
uint8_t lu_io_get_input_matrix(uint8_t size, uint16_t input_matrix[size][size],
                               uint8_t band_width, uint8_t band_height,
                               uint16_t output_matrix[band_height][band_width], uint8_t *max_k);
float convert_hex_to_fraction(uint16_t hex_code, uint8_t format_fraction);
uint16_t convert_fraction_to_hex(float fraction, uint8_t format_fraction);
void print_band_matrix_f32(const char *title, int rows, int cols, float matrix[rows][cols], int max_k);
void print_band_matrix_u16(const char *title, int rows, int cols, uint16_t matrix[rows][cols], int max_k);

// LU matrix extraction functions
void get_result_LU(uint8_t size, uint16_t *l_values, uint16_t *u_values,
                   uint16_t L_matrix[size][size], uint16_t U_matrix[size][size]);
// Decodes the input band matrix (from lu_io_get_input_matrix) back into A's
// triangular split. Round-trips the encoder only -- NOT a real LU
// factorization (no elimination has happened). See lu_io.c for details.
void extract_LU_from_band_matrix(uint8_t size, uint8_t band_width, uint16_t band_matrix[][band_width],
                                 uint16_t L_matrix[size][size], uint16_t U_matrix[size][size]);
void simulate_math_lu(uint8_t size, uint8_t format_fraction, uint16_t A[size][size],
                      uint16_t L_matrix[size][size], uint16_t U_matrix[size][size]);

// Embeds an n x n matrix A into the top-left of an m x m matrix as
// [[A, 0], [0, I]] (identity in the bottom-right block). This block-identity
// padding preserves A's LU factors exactly in the padded result's top-left
// n x n block, unlike naive zero-padding (which produces zero pivots on the
// extended diagonal). Requires m >= n.
void build_padded_matrix(uint8_t n, uint8_t m, uint8_t format_fraction,
                         uint16_t A[n][n], uint16_t A_padded[m][m]);
void print_matrix(const char *title, uint8_t size, uint16_t matrix[size][size]);
void print_matrix_decimal(const char *title, uint8_t size,
                          uint8_t format_fraction, uint16_t matrix[size][size]);

#endif
