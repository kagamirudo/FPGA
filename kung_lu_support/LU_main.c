#include <stdint.h>
#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"

#include "xparameters.h"
#include "lu_ip.h"
#include "xil_io.h"
#include "xil_types.h"
#include "lu_io.h"

#define BASE_ADDR XPAR_LU_IP_0_BASEADDR
int main()
{
    init_platform();

    uint16_t a[16] = {
        0x20, 0x20, 0x0, 0x60,
        0x40, 0x20, 0x7e0, 0x20,
        0x60, 0x7e0, 0x7e0, 0x40,
        0x7e0, 0x40, 0x60, 0x7e0};

    int i, j;
    int n = 4;
    int band_height = 2 * n - 1;
    int band_width = 2 * band_height;
    int input_size = band_height;
    int L_size = n - 1;
    int U_size = n;

    uint8_t max_k;
    uint8_t format = 0x65;
    uint8_t reg_offset = n * band_width;

    uint16_t input_2d[n][n];
    uint16_t input_band[band_height][band_width];
    uint16_t L_matrix[n][n];
    uint16_t U_matrix[n][n];
    uint16_t l_value[band_width * L_size];
    uint16_t u_value[band_width * U_size];

    float input_float_band[band_height][band_width];

    convert_1d_to_2d(a, n, input_2d);
    lu_io_get_input_matrix(n, input_2d, band_width, band_height, input_band, &max_k);

    for (i = 0; i < band_height; i++)
        for (j = 0; j < band_width; j++)
            input_float_band[i][j] = convert_hex_to_fraction(input_band[i][j], format);

    print_band_matrix_f32("Generated Band Matrix (float)", band_height, band_width, input_float_band, (int)max_k);

    // reset => slv_reg14(0), step => slv_reg14(1), reset_step => slv_reg14(2)
    // ------------------------------------------------------------
    // reset step
    LU_IP_mWriteReg(BASE_ADDR, reg_offset, 0x4); // sly_reg14(2) <= '1'
    // reset array
    LU_IP_mWriteReg(BASE_ADDR, reg_offset, 0x1); // slv_reg14 address is 56
    // step
    LU_IP_mWriteReg(BASE_ADDR, reg_offset, 0x2); // slv_reg14(1) <= '1'
    // apply ith test vector
    for (i = 0; i < band_width; i++)
    {
        // xil_printf("ck=%d\n\r", i);
        // reset step
        LU_IP_mWriteReg(BASE_ADDR, reg_offset, 0x4); // sly_reg14(2) <= '1'
        // write to slv reg input ports j = 0..(input_size)
        for (j = 0; j < input_size; j++)
            LU_IP_mWriteReg(BASE_ADDR, n * j, input_band[j][i]);
        // step in
        LU_IP_mWriteReg(BASE_ADDR, reg_offset, 0x2); // slv_reg14(1) <= '1'
        // read l slv_reg (input_size)..(input_size + L_size)
        for (j = input_size; j < input_size + L_size; j++)
        {
            // float num = convert_hex_to_fraction(LU_IP_mReadReg(BASE_ADDR, j * n), format);
            // printf("l%d = %f\n\r", j - input_size + 2, num);
            l_value[i * L_size + (j - input_size)] = LU_IP_mReadReg(BASE_ADDR, n * j);
        }
        // read u slv_reg (input_size + L_size)..(input_size + L_size + U_size)
        for (j = input_size + L_size; j < input_size + L_size + U_size; j++)
        {
            // float num = convert_hex_to_fraction(LU_IP_mReadReg(BASE_ADDR, j * n), format);
            // printf("u%d = %f\n\r", j - input_size - L_size + 1, num);
            u_value[i * U_size + (j - input_size - L_size)] = LU_IP_mReadReg(BASE_ADDR, n * j);
        }
    }
    get_result_LU(n, l_value, u_value, L_matrix, U_matrix);
    print_matrix_decimal("L Matrix", n, format, L_matrix);
    print_matrix_decimal("U Matrix", n, format, U_matrix);

    cleanup_platform();
    return 0;
}