#include "lu_io.h"
#include <stdio.h>

int main()
{
    printf("=== Simple LU Test ===\n\n");
    
    const uint8_t size = 4;
    uint16_t L_matrix[size][size];
    uint16_t U_matrix[size][size];
    uint16_t input_matrix[size][size];
    // Test 1: Software simulation
    printf("1. Software LU simulation:\n");
    simulate_math_lu(size, 0x65, input_matrix, L_matrix, U_matrix);
    print_matrix_decimal("L Matrix (Software)", size, 0x65, L_matrix);
    print_matrix_decimal("U Matrix (Software)", size, 0x65, U_matrix);
    
    // Test 2: Direct mapping from your hardware output
    printf("2. Direct mapping from hardware output:\n");
    
    // Initialize matrices
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            L_matrix[i][j] = 0;
            U_matrix[i][j] = 0;
        }
    }
    
    // Set L diagonal to 1
    for (int i = 0; i < size; i++) {
        L_matrix[i][i] = 1;
    }
    
    // Map the actual values from your hardware output
    // Based on the pattern, let's try a direct mapping approach
    
    // L matrix values (lower triangular, excluding diagonal)
    // From your output: l2, l3, l4 values at various ck positions
    L_matrix[1][0] = convert_fraction_to_hex(-2.0f, 0x65);  // l21 from ck=4
    L_matrix[2][1] = convert_fraction_to_hex(-3.0f, 0x65);  // l32 from ck=5  
    L_matrix[3][2] = convert_fraction_to_hex(1.0f, 0x65);   // l43 from ck=6
    L_matrix[2][0] = convert_fraction_to_hex(-4.0f, 0x65);  // l31 from ck=7
    L_matrix[3][1] = convert_fraction_to_hex(3.0f, 0x65);   // l42 from ck=8
    
    // U matrix values (upper triangular)
    // From your output: u1, u2, u3, u4 values at various ck positions
    U_matrix[0][0] = convert_fraction_to_hex(1.0f, 0x65);    // u11 from ck=2
    U_matrix[1][1] = convert_fraction_to_hex(1.0f, 0x65);    // u22 from ck=3
    U_matrix[0][1] = convert_fraction_to_hex(-1.0f, 0x65);   // u12 from ck=5
    U_matrix[1][2] = convert_fraction_to_hex(-1.0f, 0x65);   // u23 from ck=6
    U_matrix[2][2] = convert_fraction_to_hex(-5.0f, 0x65);   // u33 from ck=7
    U_matrix[0][2] = convert_fraction_to_hex(3.0f, 0x65);    // u13 from ck=8
    U_matrix[1][3] = convert_fraction_to_hex(13.0f, 0x65);   // u24 from ck=9
    U_matrix[0][3] = convert_fraction_to_hex(-13.0f, 0x65);  // u14 from ck=11
    U_matrix[3][3] = convert_fraction_to_hex(-24.093750f, 0x65); // u44 from ck=14
    
    print_matrix("L Matrix (Hardware)", size, L_matrix);
    print_matrix("U Matrix (Hardware)", size, U_matrix);
    
    // Test 3: Print in decimal format
    printf("3. Hardware matrices in decimal format:\n");
    printf("L Matrix:\n");
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            float val = convert_hex_to_fraction(L_matrix[i][j], 0x65);
            printf("%8.3f ", val);
        }
        printf("\n");
    }
    printf("\nU Matrix:\n");
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            float val = convert_hex_to_fraction(U_matrix[i][j], 0x65);
            printf("%8.3f ", val);
        }
        printf("\n");
    }
    
    return 0;
}
