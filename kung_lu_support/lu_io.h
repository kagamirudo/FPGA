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
void extract_LU_from_band_matrix(uint8_t size, uint8_t band_width, uint16_t band_matrix[][band_width],
                                 uint16_t L_matrix[size][size], uint16_t U_matrix[size][size]);
void simulate_math_lu(uint8_t size, uint8_t format_fraction, uint16_t A[size][size],
                      uint16_t L_matrix[size][size], uint16_t U_matrix[size][size]);
void print_matrix(const char *title, uint8_t size, uint16_t matrix[size][size]);
void print_matrix_decimal(const char *title, uint8_t size,
                          uint8_t format_fraction, uint16_t matrix[size][size]);

#endif
