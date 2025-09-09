# LU IO Package

A comprehensive C library for LU decomposition matrix processing with hardware integration support for Kung-Lu systolic array architectures.

## Overview

This package provides functions for:
- Converting matrices between 1D and 2D formats
- Generating band matrices for systolic array processing
- Extracting L and U matrices from hardware output sequences
- Converting between fixed-point hex and floating-point representations
- Matrix visualization and debugging tools

## Files Structure

```
kung_lu_support/
├── lu_io.h          # Header file with function declarations
├── lu_io.c          # API implementation (library source)
├── test_lu_io.c     # Test/demo program
├── makefile         # Build configuration
└── README.md        # This documentation
```

## Building the Package

### Prerequisites
- GCC compiler
- Make utility
- Standard C library

### Build Commands

```bash
# Build both library and test executable
make all

# Build only the static library
make liblu_io.a

# Build only the test executable
make lu_io_test

# Run the test program
make run

# Clean generated files
make clean

# Install library system-wide (optional)
sudo make install
```

## API Reference

### Core Functions

#### Matrix Conversion
```c
int convert_1d_to_2d(uint16_t *input_matrix, uint8_t size, 
                     uint16_t output_matrix[size][size]);
```
Converts a 1D array to a 2D square matrix.

#### Band Matrix Generation
```c
uint8_t lu_io_get_input_matrix(uint8_t size, uint16_t input_matrix[size][size],
                               uint8_t band_width, uint8_t band_height,
                               uint16_t output_matrix[band_height][band_width], 
                               uint8_t *max_k);
```
Generates a band matrix from input matrix for systolic array processing.

**Parameters:**
- `size`: Matrix dimension (e.g., 4 for 4x4 matrix)
- `input_matrix`: Input square matrix
- `band_width`: Width of band matrix (typically 2*(2*n-1))
- `band_height`: Height of band matrix (typically 2*n-1)
- `output_matrix`: Output band matrix
- `max_k`: Maximum diagonal index (returned)

#### LU Matrix Extraction

##### From Band Matrix
```c
void extract_LU_from_band_matrix(uint8_t size, uint16_t band_matrix[][14], 
                                 uint16_t L_matrix[size][size], 
                                 uint16_t U_matrix[size][size]);
```
Extracts L and U matrices from band matrix output.

##### From Hardware Sequence
```c
void get_result_LU(uint8_t size, uint16_t *l_values, uint16_t *u_values, 
                   uint16_t L_matrix[size][size], uint16_t U_matrix[size][size]);
```
Extracts L and U matrices from hardware register values.

##### Hardware Simulation
```c
void simulate_hardware_sequence(uint8_t size, uint16_t L_matrix[size][size], 
                               uint16_t U_matrix[size][size]);
```
Simulates hardware sequence for testing purposes.

### Fixed-Point Conversion

#### Hex to Fraction
```c
float convert_hex_to_fraction(uint16_t hex_code, uint8_t format_fraction);
```
Converts fixed-point hex to floating-point fraction.

**Format:** `format_fraction` = `0x65` means 6 integer bits, 5 fraction bits.

#### Fraction to Hex
```c
uint16_t convert_fraction_to_hex(float fraction, uint8_t format_fraction);
```
Converts floating-point fraction to fixed-point hex.

### Visualization Functions

#### Print Band Matrix (uint16_t)
```c
void print_band_matrix_u16(const char *title, int rows, int cols,
                           uint16_t matrix[rows][cols], int max_k);
```

#### Print Band Matrix (float)
```c
void print_band_matrix_f32(const char *title, int rows, int cols,
                           float matrix[rows][cols], int max_k);
```

#### Print Regular Matrix
```c
void print_matrix(const char *title, uint8_t size, uint16_t matrix[size][size]);
```

## Usage Examples

### Basic Usage

```c
#include "lu_io.h"

int main() {
    // Define input matrix
    uint16_t input_matrix[16] = {
        0x20, 0x20, 0x80, 0x60,
        0x40, 0x20, 0x7e0, 0x20,
        0x60, 0x7e0, 0x7e0, 0x40,
        0x7e0, 0x40, 0x60, 0x7e0
    };
    
    int n = 4;
    int band_height = 2 * n - 1;
    int band_width = 2 * (2 * n - 1);
    uint16_t input_2d[n][n];
    uint16_t band_matrix[band_height][band_width];
    uint8_t max_k;
    
    // Convert to 2D
    convert_1d_to_2d(input_matrix, n, input_2d);
    
    // Generate band matrix
    lu_io_get_input_matrix(n, input_2d, band_width, band_height, 
                          band_matrix, &max_k);
    
    // Extract L and U matrices
    uint16_t L[n][n], U[n][n];
    extract_LU_from_band_matrix(n, band_matrix, L, U);
    
    // Print results
    print_matrix("L Matrix", n, L);
    print_matrix("U Matrix", n, U);
    
    return 0;
}
```

### Hardware Integration

```c
#include "lu_io.h"

// Hardware register addresses (example)
#define BASE_ADDR 0x40000000

void process_hardware_lu(uint8_t size) {
    uint16_t L_matrix[size][size];
    uint16_t U_matrix[size][size];
    uint16_t l_values[3];  // For 4x4 matrix
    uint16_t u_values[4];  // For 4x4 matrix
    
    // Hardware sequence
    for (int i = 0; i < 16; i++) {
        // Reset step
        LU_IP_mWriteReg(BASE_ADDR, 4*14, 0x4);
        
        // Write input data
        for (int j = 0; j < 7; j++) 
            LU_IP_mWriteReg(BASE_ADDR, 4*j, v[i][j]);
        
        // Step
        LU_IP_mWriteReg(BASE_ADDR, 4*14, 0x2);
        
        // Read L values (registers 7-9)
        for (int j = 7; j < 10; j++)
            l_values[j-7] = LU_IP_mReadReg(BASE_ADDR, 4*j);
        
        // Read U values (registers 10-13)
        for (int j = 10; j < 14; j++)
            u_values[j-10] = LU_IP_mReadReg(BASE_ADDR, 4*j);
    }
    
    // Extract matrices
    get_result_LU(size, l_values, u_values, L_matrix, U_matrix);
    
    // Use the matrices...
}
```

### Fixed-Point Conversion

```c
#include "lu_io.h"

void conversion_example() {
    // Convert -5.5 to hex (6Q5 format)
    uint16_t hex_val = convert_fraction_to_hex(-5.5, 0x65);
    printf("Hex value: 0x%x\n", hex_val);
    
    // Convert back to float
    float float_val = convert_hex_to_fraction(hex_val, 0x65);
    printf("Float value: %f\n", float_val);
}
```

## Theory Background

### Band Matrix Generation
The package implements the Kung-Lu systolic array theory:
- **For k ≥ 0**: `y(tp,k) = a[t][t+k]` where `t = (tp - 2*k)/3`
- **For k < 0**: `y(tp,k) = a[t+|k|][t]` where `t = (tp - 2*k)/3`
- **Rate**: 1/3 (values appear every 3 time steps)

### LU Extraction
- **L Matrix**: Lower triangular with diagonal = 1, extracted from k < 0 diagonals
- **U Matrix**: Upper triangular, extracted from k ≥ 0 diagonals
- **Pattern**: Both follow rate = 1/3 timing

## Compilation Flags

The package uses standard C99 features. For optimal performance:

```bash
gcc -Wall -O2 -std=c99 -o your_program your_program.c -llu_io
```

## Error Handling

- All functions return 0 on success
- Matrix bounds are checked internally
- Invalid parameters are handled gracefully

## Testing

Run the included test program:

```bash
make run
```

This will demonstrate all package features with sample data.

## License

This package is provided as-is for educational and research purposes.

## Support

For questions or issues, refer to the source code comments and this documentation.
