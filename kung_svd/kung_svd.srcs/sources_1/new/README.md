# SVD Systolic Array Implementation

This directory contains the VHDL implementation of a Kung's SVD (Singular Value Decomposition) systolic array with AXI-Stream interface and integrated Jacobi controller. The design is modular, scalable, and optimized for FPGA implementation.

## File Structure

### Core Design Files

#### 1. `svd_pkg.vhd` - Shared Package
- **Purpose:** Defines common data types and constants
- **Key Components:**
  - `DATA_WIDTH`: 18-bit fixed-point data width (Q1.16 format)
  - `data_t`: Signed data type for matrix elements
- **Usage:** Imported by all other design files

#### 2. `svd_pe.vhd` - Processing Element
- **Purpose:** Individual systolic cell implementing Givens rotation
- **Features:**
  - Multiply-accumulate operations for rotation
  - Fixed-point arithmetic with proper truncation
  - Single clock cycle per operation
  - Pass-through for cosine/sine parameters
- **Ports:** 4 data inputs (a_in, b_in, c_in, s_in), 4 data outputs (a_out, b_out, c_out, s_out)

#### 3. `cordic_rot.vhd` - CORDIC Rotation Engine
- **Purpose:** Fixed-point CORDIC algorithm for trigonometric computation
- **Features:**
  - Computes cos(θ) and sin(θ) from input coordinates (x, y)
  - 16-bit precision with pre-computed arctangent table
  - Iterative convergence algorithm
  - Valid output handshaking
- **Algorithm:** Vectoring mode CORDIC with 16 iterations
- **Precision:** 16-bit fixed-point with arctangent lookup table

#### 4. `jacobi_ctrl.vhd` - Jacobi Controller
- **Purpose:** One-sided Jacobi controller for SVD computation
- **Features:**
  - Column-pair scheduling for efficient sweeps
  - Fixed-iteration schedule (8 sweeps for 8×8 matrix)
  - CORDIC integration for rotation parameter computation
  - FSM-based control: IDLE → PAIR → CORDIC → BROADCAST
- **Configuration:** 8×8 matrix with 8 sweeps
- **Scheduling:** Pairs (0,1), (2,3), ... then (1,2), (3,4), ...

#### 5. `svd_array_core.vhd` - Systolic Array Core
- **Purpose:** Configurable ROWS×COLS grid with integrated Jacobi controller
- **Configuration:** Default 8×8 array (64 PEs)
- **Features:**
  - Generate statement for PE grid instantiation
  - Internal bus routing (a_bus, b_bus, c_bus, s_bus)
  - Jacobi controller integration with CORDIC
  - Broadcast mechanism for rotation parameters
  - Control logic for start/done handshaking
- **Memory:** ~873 bytes internal storage for 8×8 configuration
- **Controller Integration:**
  - Matrix edge connection to controller
  - Rotation parameter broadcasting to all PEs
  - Synchronized start/done control

#### 6. `svd_axi_stream.vhd` - AXI-Stream Wrapper
- **Purpose:** Interface layer between systolic array and AXI-Stream protocol
- **Features:**
  - 4-state FSM: IDLE → LOAD → COMPUTE → DRAIN
  - Handshaking with ready/valid protocol
  - Data type conversion (std_logic_vector ↔ signed)
  - Stream flow control
- **States:**
  - **IDLE:** Waiting for input data
  - **LOAD:** Streaming input matrix data
  - **COMPUTE:** Processing in systolic array with Jacobi controller
  - **DRAIN:** Outputting results

#### 7. `svd_array.vhd` - Top-Level Wrapper
- **Purpose:** Main entry point for the design
- **Interface:** AXI-Stream master/slave ports
- **Function:** Instantiates and connects the AXI-Stream wrapper

### Testbench Files

#### `tb_svd_array.vhd` - Functional Testbench
- **Purpose:** Comprehensive testing of the SVD systolic array
- **Features:**
  - 100 MHz clock generation (10ns period)
  - 8×8 matrix input (64 data words: 1-64)
  - AXI-Stream handshaking verification
  - Output monitoring and reporting
  - Timeout protection (10μs)
- **Test Flow:**
  1. Reset sequence (5 clock cycles)
  2. Stream 64 words with proper handshaking
  3. Wait for computation and output
  4. Monitor and report results

## Technical Specifications

### Data Format
- **Fixed-point:** Q1.16 format (1 integer bit, 16 fractional bits)
- **Data width:** 18 bits total
- **Range:** -2.0 to +1.9999

### Performance Characteristics
- **Array size:** Configurable (default 8×8)
- **Throughput:** 64 elements per computation cycle (8×8)
- **Latency:** ~16 cycles (ROWS + COLS)
- **Clock frequency:** 100 MHz (10ns period)
- **Jacobi sweeps:** 8 iterations for 8×8 matrix
- **CORDIC precision:** 16-bit with 16 iterations

### Memory Requirements
- **8×8 configuration:**
  - Input matrix: 144 bytes
  - Internal buses: 729 bytes
  - CORDIC lookup table: 64 bytes
  - Total: ~937 bytes

### Scalability
- **Small:** 4×4 (16 PEs) for testing
- **Medium:** 8×8 (64 PEs) for development
- **Large:** 16×16 (256 PEs) for production
- **Maximum:** Limited by FPGA resources

## Usage Instructions

### Compilation Order
1. `svd_pkg.vhd` - Package definitions
2. `cordic_rot.vhd` - CORDIC rotation engine
3. `jacobi_ctrl.vhd` - Jacobi controller
4. `svd_pe.vhd` - Processing element
5. `svd_array_core.vhd` - Systolic array with controller
6. `svd_axi_stream.vhd` - AXI-Stream wrapper
7. `svd_array.vhd` - Top-level
8. `tb_svd_array.vhd` - Testbench

### Vivado Integration
- Add all source files to Vivado project in compilation order
- Set `svd_array_top` as top-level entity
- Configure synthesis settings for target FPGA
- Run simulation with `tb_svd_array` as testbench

### Customization
- Modify `DATA_WIDTH` in `svd_pkg.vhd` for different precision
- Change `ROWS` and `COLS` generics for different matrix sizes
- Adjust `SWEEPS` in `jacobi_ctrl.vhd` for convergence control
- Modify CORDIC iterations in `cordic_rot.vhd` for precision/speed trade-off
- Adjust clock frequency in testbench for different timing requirements

## Algorithm Details

### Kung's SVD Method with Jacobi Controller
- **Principle:** Systolic array implementation with one-sided Jacobi method
- **Process:** 
  1. Load matrix into systolic array
  2. Controller performs column-pair sweeps
  3. CORDIC computes rotation parameters (c, s)
  4. PEs apply Givens rotations
  5. Iterate until convergence (8 sweeps)
- **Convergence:** Matrix converges to diagonal form with singular values
- **Advantage:** Highly parallel, suitable for hardware implementation

### Jacobi Controller
- **Scheduling:** Column-pair approach for efficient sweeps
- **Rotation Computation:** CORDIC-based trigonometric calculation
- **Broadcast:** Rotation parameters distributed to all PEs
- **Control:** FSM manages sweep progression and completion

### CORDIC Algorithm
- **Mode:** Vectoring mode for angle computation
- **Precision:** 16-bit fixed-point with lookup table
- **Iterations:** 16 steps for optimal accuracy
- **Output:** Cosine and sine values for rotation

### Givens Rotation
- **Operation:** 2×2 matrix rotation to zero out specific elements
- **Implementation:** MAC operations with cosine/sine parameters
- **Precision:** Fixed-point arithmetic with proper truncation

## Architecture Flow

1. **Input Matrix** → AXI-Stream → Systolic Array
2. **Matrix Edge** → Jacobi Controller
3. **Controller** → CORDIC → Rotation Parameters (c, s)
4. **Broadcast** → All Processing Elements
5. **PEs** → Givens Rotation → Updated Matrix
6. **Iterate** → 8 sweeps until convergence
7. **Output** → Singular values and vectors via AXI-Stream

## Future Enhancements
- [x] Complete controller logic in `svd_array_core.vhd`
- [x] Add Jacobi controller with CORDIC integration
- [ ] Add I/O multiplexing for matrix loading/unloading
- [ ] Implement adaptive convergence detection
- [ ] Add support for larger matrix sizes
- [ ] Optimize for specific FPGA families
- [ ] Add parameterized precision options
- [ ] Implement partial reconfiguration for different matrix sizes

---

This implementation provides a complete SVD computation system in hardware, featuring a systolic array with integrated Jacobi controller and CORDIC-based rotation computation. Suitable for signal processing, machine learning, and scientific computing applications requiring real-time SVD computation.

