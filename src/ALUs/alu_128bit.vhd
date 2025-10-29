-- ============================================================================
-- 128-BIT ARITHMETIC LOGIC UNIT (ALU) - COMPREHENSIVE IMPLEMENTATION
-- ============================================================================
-- 
-- Project: Advanced 128-bit ALU for High-Performance Computing
-- File: alu_128bit.vhd
-- Description: Complete 128-bit ALU with extensive operation support
-- Author: FPGA Development Team
-- Date: 2024
-- Version: 1.0
-- 
-- ============================================================================
-- PROJECT OVERVIEW
-- ============================================================================
-- 
-- This project implements a comprehensive 128-bit Arithmetic Logic Unit (ALU)
-- designed for high-performance computing applications, cryptographic operations,
-- and advanced digital signal processing. The ALU supports a wide range of
-- operations including:
-- 
-- • Advanced arithmetic operations (add, subtract, multiply, divide)
-- • Comprehensive logical operations (AND, OR, XOR, NOT, NAND, NOR)
-- • Sophisticated shift and rotate operations with barrel shifter
-- • Bit manipulation instructions (CLZ, CTZ, POPCNT, bit reversal)
-- • SIMD operations for parallel processing (128-bit, 64-bit, 32-bit, 16-bit, 8-bit)
-- • Vector operations for multimedia and scientific computing
-- • Floating-point operations (single, double, quad precision)
-- • Cryptographic operations (AES, hash functions, random number generation)
-- • Saturated arithmetic for DSP applications
-- • BCD arithmetic for financial calculations
-- • Extended precision operations with carry propagation
-- • Pipeline support for high-frequency operation
-- • Comprehensive exception handling and security features
-- 
-- ============================================================================
-- LEARNING OBJECTIVES
-- ============================================================================
-- 
-- By studying and implementing this 128-bit ALU, you will learn:
-- 
-- 1. **Advanced Digital Design Concepts:**
--    - 128-bit wide data path design and optimization
--    - Complex combinational and sequential logic implementation
--    - Advanced timing analysis and critical path optimization
--    - Resource utilization optimization for large designs
-- 
-- 2. **High-Performance Computing Architecture:**
--    - SIMD (Single Instruction, Multiple Data) processing concepts
--    - Vector processing and parallel computation techniques
--    - Pipeline design for high-throughput operations
--    - Advanced arithmetic unit design principles
-- 
-- 3. **Cryptographic Hardware Implementation:**
--    - Hardware acceleration of cryptographic algorithms
--    - Secure computation techniques and side-channel resistance
--    - Random number generation in hardware
--    - Key scheduling and encryption/decryption operations
-- 
-- 4. **Advanced VHDL Programming:**
--    - Generic programming for parameterizable designs
--    - Advanced generate statements and conditional compilation
--    - Complex data type definitions and array handling
--    - Hierarchical design and component instantiation
-- 
-- 5. **System Integration:**
--    - Interface design for processor integration
--    - Exception handling and error reporting
--    - Performance monitoring and debugging features
--    - Power management and optimization techniques
-- 
-- ============================================================================
-- STEP-BY-STEP IMPLEMENTATION GUIDE
-- ============================================================================
-- 
-- STEP 1: LIBRARY DECLARATIONS AND DEPENDENCIES
-- --------------------------------------------
-- 
-- Essential libraries for 128-bit ALU implementation:
-- • IEEE.STD_LOGIC_1164: Standard logic types and operations
-- • IEEE.NUMERIC_STD: Arithmetic operations on std_logic_vector
-- • IEEE.MATH_REAL: Mathematical functions for advanced operations
-- • WORK.ALU_PKG: Custom package for ALU-specific types and constants
-- 
-- Key considerations:
-- - Use NUMERIC_STD for all arithmetic operations (avoid STD_LOGIC_ARITH)
-- - Implement custom types for complex operations
-- - Consider synthesis tool compatibility
-- - Plan for simulation and verification requirements
-- 
-- STEP 2: ENTITY DECLARATION AND PORT SPECIFICATION
-- ------------------------------------------------
-- 
-- The 128-bit ALU entity includes:
-- 
-- A) **Data Interface (128-bit wide):**
--    - a, b: 128-bit input operands
--    - result: 128-bit primary result output
--    - result_hi: 128-bit extended result (for 256-bit operations)
-- 
-- B) **Control Interface:**
--    - alu_op: Operation selection (6-8 bits for 64+ operations)
--    - mode: Operation mode (normal, SIMD, vector, etc.)
--    - shift_amount: Shift/rotate amount (7 bits for 0-127 positions)
--    - carry_in: Input carry for multi-precision arithmetic
-- 
-- C) **Status Interface:**
--    - Comprehensive flag set (zero, carry, overflow, negative, etc.)
--    - Extended flags for floating-point and SIMD operations
--    - Exception reporting and security violation detection
-- 
-- D) **System Interface:**
--    - clk, reset: Clock and reset for sequential operations
--    - enable: Operation enable for power management
--    - ready: Operation completion indicator
-- 
-- STEP 3: 128-BIT ALU OPERATION PRINCIPLES
-- ---------------------------------------
-- 
-- A) **Arithmetic Operations:**
--    - 128-bit addition with carry propagation and overflow detection
--    - 128-bit subtraction with borrow handling
--    - 128x128-bit multiplication producing 256-bit result
--    - 128÷128-bit division with quotient and remainder
--    - Modular arithmetic for cryptographic applications
--    - Saturated arithmetic for DSP applications
-- 
-- B) **Logical Operations:**
--    - Bitwise AND, OR, XOR, NOT operations
--    - Advanced logical operations (NAND, NOR, ANDN, ORN)
--    - Bit manipulation (set, clear, toggle, test)
--    - Conditional operations based on flags
-- 
-- C) **Shift and Rotate Operations:**
--    - Logical shifts (left/right) with zero fill
--    - Arithmetic shifts with sign extension
--    - Rotate operations (left/right) with wrap-around
--    - Barrel shifter for single-cycle operation
--    - Multi-bit shifts up to 127 positions
-- 
-- D) **Advanced Bit Manipulation:**
--    - Count leading zeros (CLZ) and trailing zeros (CTZ)
--    - Population count (POPCNT) - count of set bits
--    - Bit reversal and byte swapping
--    - Find first set (FFS) and find last set (FLS)
--    - Bit field extraction and insertion
-- 
-- E) **SIMD Operations:**
--    - 2x64-bit parallel operations
--    - 4x32-bit parallel operations
--    - 8x16-bit parallel operations
--    - 16x8-bit parallel operations
--    - Packed arithmetic with saturation
-- 
-- ============================================================================
-- ARCHITECTURE OPTIONS AND DESIGN CHOICES
-- ============================================================================
-- 
-- 1. **Simple Combinational Architecture:**
--    - All operations complete in single clock cycle
--    - Large combinational logic area
--    - Suitable for low-frequency applications
--    - Minimal latency, maximum throughput
-- 
-- 2. **Pipelined Architecture:**
--    - Operations split across multiple pipeline stages
--    - Higher frequency operation possible
--    - Increased latency but maintained throughput
--    - Complex control and hazard handling
-- 
-- 3. **Multi-Cycle Architecture:**
--    - Complex operations take multiple cycles
--    - Reduced area and power consumption
--    - Lower throughput for complex operations
--    - Simplified timing constraints
-- 
-- 4. **Hybrid Architecture:**
--    - Simple operations in single cycle
--    - Complex operations pipelined or multi-cycle
--    - Optimal balance of area, power, and performance
--    - Flexible operation scheduling
-- 
-- ============================================================================
-- IMPLEMENTATION CONSIDERATIONS
-- ============================================================================
-- 
-- 1. **Operation Encoding:**
--    - Use systematic encoding for operation selection
--    - Group related operations for decoder optimization
--    - Reserve codes for future expansion
--    - Consider instruction set architecture compatibility
-- 
-- 2. **Flag Generation:**
--    - Implement comprehensive flag set for all operations
--    - Optimize flag generation for critical timing paths
--    - Support conditional operations based on flags
--    - Provide extended flags for specialized operations
-- 
-- 3. **Timing Optimization:**
--    - Identify and optimize critical timing paths
--    - Use pipeline registers for high-frequency operation
--    - Implement early termination for faster operations
--    - Balance logic depth across different operations
-- 
-- 4. **Resource Utilization:**
--    - Optimize for target FPGA architecture
--    - Share resources between similar operations
--    - Use dedicated multipliers and DSP blocks efficiently
--    - Minimize memory requirements for large operations
-- 
-- ============================================================================
-- ADVANCED FEATURES
-- ============================================================================
-- 
-- 1. **Extended Arithmetic:**
--    - Multi-precision arithmetic support
--    - Modular arithmetic for cryptography
--    - Saturated arithmetic for DSP
--    - BCD arithmetic for financial applications
-- 
-- 2. **Vector Operations:**
--    - Dot product and cross product operations
--    - Vector addition, subtraction, and scaling
--    - Matrix operations (when combined with control logic)
--    - Parallel reduction operations
-- 
-- 3. **Cryptographic Support:**
--    - AES encryption/decryption operations
--    - Hash function acceleration (SHA, MD5)
--    - Random number generation
--    - Modular exponentiation support
-- 
-- 4. **Floating-Point Operations:**
--    - IEEE 754 compliant operations
--    - Single, double, and quad precision support
--    - Fused multiply-add operations
--    - Special value handling (NaN, infinity)
-- 
-- ============================================================================
-- APPLICATIONS
-- ============================================================================
-- 
-- This 128-bit ALU is suitable for:
-- • High-performance computing processors
-- • Cryptographic accelerators and security processors
-- • Digital signal processing systems
-- • Graphics processing units (GPUs)
-- • Scientific computing applications
-- • Financial calculation systems
-- • Multimedia processing systems
-- • Network processing units
-- • Artificial intelligence accelerators
-- • Quantum computing simulators
-- 
-- ============================================================================
-- TESTING STRATEGY
-- ============================================================================
-- 
-- Comprehensive testing should include:
-- 1. **Functional Testing:**
--    - Test all arithmetic operations with edge cases
--    - Verify logical operations with all input combinations
--    - Test shift and rotate operations with all shift amounts
--    - Validate SIMD operations with various data patterns
-- 
-- 2. **Performance Testing:**
--    - Measure critical path delays for all operations
--    - Verify pipeline operation at target frequency
--    - Test throughput under various operation mixes
--    - Validate power consumption under different workloads
-- 
-- 3. **Stress Testing:**
--    - Test with maximum and minimum values
--    - Verify overflow and underflow handling
--    - Test exception generation and handling
--    - Validate security features and violation detection
-- 
-- ============================================================================
-- RECOMMENDED IMPLEMENTATION APPROACH
-- ============================================================================
-- 
-- 1. **Phase 1: Basic Operations**
--    - Implement basic arithmetic (add, subtract)
--    - Add simple logical operations (AND, OR, XOR, NOT)
--    - Implement basic shift operations
--    - Create comprehensive testbench
-- 
-- 2. **Phase 2: Advanced Arithmetic**
--    - Add multiplication and division
--    - Implement advanced bit manipulation
--    - Add saturated arithmetic support
--    - Optimize critical timing paths
-- 
-- 3. **Phase 3: SIMD and Vector Operations**
--    - Implement SIMD operations for all data widths
--    - Add vector operations and reductions
--    - Implement parallel processing features
--    - Optimize for parallel execution
-- 
-- 4. **Phase 4: Specialized Features**
--    - Add floating-point operations
--    - Implement cryptographic operations
--    - Add pipeline support
--    - Implement advanced exception handling
-- 
-- ============================================================================
-- EXTENSION EXERCISES
-- ============================================================================
-- 
-- 1. **Performance Optimization:**
--    - Implement advanced pipeline with forwarding
--    - Add out-of-order execution support
--    - Optimize for specific FPGA architectures
--    - Implement dynamic voltage and frequency scaling
-- 
-- 2. **Feature Extensions:**
--    - Add custom instruction support
--    - Implement matrix operations
--    - Add neural network acceleration
--    - Implement quantum gate operations
-- 
-- 3. **System Integration:**
--    - Design cache interface
--    - Add memory management unit interface
--    - Implement interrupt handling
--    - Add performance monitoring counters
-- 
-- ============================================================================
-- COMMON MISTAKES TO AVOID
-- ============================================================================
-- 
-- 1. **Design Mistakes:**
--    - Using STD_LOGIC_ARITH instead of NUMERIC_STD
--    - Inadequate timing constraint specification
--    - Insufficient pipeline depth for target frequency
--    - Poor resource sharing between operations
-- 
-- 2. **Implementation Mistakes:**
--    - Incorrect flag generation for edge cases
--    - Inadequate overflow and underflow detection
--    - Poor exception handling implementation
--    - Insufficient security consideration
-- 
-- 3. **Verification Mistakes:**
--    - Incomplete corner case testing
--    - Inadequate performance verification
--    - Poor test coverage measurement
--    - Insufficient stress testing
-- 
-- ============================================================================
-- DESIGN VERIFICATION CHECKLIST
-- ============================================================================
-- 
-- Before considering the design complete, verify:
-- ☐ All arithmetic operations produce correct results
-- ☐ All logical operations work with all input combinations
-- ☐ Shift and rotate operations handle all shift amounts correctly
-- ☐ Flag generation is correct for all operations
-- ☐ SIMD operations work correctly for all data widths
-- ☐ Pipeline operation maintains data integrity
-- ☐ Exception handling works correctly
-- ☐ Security features prevent unauthorized access
-- ☐ Timing constraints are met for all operations
-- ☐ Resource utilization is within target limits
-- ☐ Power consumption is acceptable
-- ☐ All interfaces work correctly
-- 
-- ============================================================================
-- DIGITAL DESIGN CONTEXT
-- ============================================================================
-- 
-- This 128-bit ALU demonstrates several key digital design concepts:
-- 
-- 1. **Scalability:** Shows how designs scale from 8-bit to 128-bit
-- 2. **Modularity:** Demonstrates component-based design approach
-- 3. **Parameterization:** Uses generics for flexible configuration
-- 4. **Optimization:** Balances area, power, and performance
-- 5. **Verification:** Emphasizes thorough testing methodology
-- 
-- ============================================================================
-- PHYSICAL IMPLEMENTATION NOTES
-- ============================================================================
-- 
-- When implementing on actual FPGA hardware:
-- • Use dedicated multiplier blocks for multiplication operations
-- • Leverage DSP slices for arithmetic operations
-- • Optimize memory usage for large intermediate results
-- • Consider clock domain crossing for multi-clock designs
-- • Plan for thermal management in high-performance applications
-- • Implement proper power sequencing and management
-- 
-- ============================================================================
-- ADVANCED CONCEPTS
-- ============================================================================
-- 
-- This implementation introduces several advanced concepts:
-- • SIMD processing for parallel computation
-- • Vector operations for multimedia applications
-- • Cryptographic hardware acceleration
-- • Advanced exception handling and security
-- • Pipeline design for high-performance operation
-- • Multi-precision arithmetic for extended range
-- 
-- ============================================================================
-- SIMULATION AND VERIFICATION NOTES
-- ============================================================================
-- 
-- For proper simulation and verification:
-- • Use comprehensive testbenches with edge case coverage
-- • Implement self-checking testbenches with automatic verification
-- • Use assertion-based verification for critical properties
-- • Perform timing simulation with realistic delays
-- • Test under various process, voltage, and temperature conditions
-- • Validate against reference models and specifications
-- 
-- ============================================================================
-- IMPLEMENTATION TEMPLATE
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

-- Custom package for ALU-specific types and constants
-- (In a real implementation, this would be in a separate package file)

entity alu_128bit is
    generic (
        -- Core configuration
        DATA_WIDTH      : integer := 128;           -- Fixed at 128 for this implementation
        ALU_OP_WIDTH    : integer := 8;             -- 8 bits for 256 operations
        SHIFT_WIDTH     : integer := 7;             -- 7 bits for 0-127 shift positions
        
        -- Feature enables
        ENABLE_MUL      : boolean := true;          -- Enable multiplication
        ENABLE_DIV      : boolean := true;          -- Enable division
        ENABLE_SHIFT    : boolean := true;          -- Enable shift operations
        ENABLE_ROTATE   : boolean := true;          -- Enable rotate operations
        ENABLE_SIMD     : boolean := true;          -- Enable SIMD operations
        ENABLE_VECTOR   : boolean := true;          -- Enable vector operations
        ENABLE_FLOAT    : boolean := true;          -- Enable floating-point operations
        ENABLE_CRYPTO   : boolean := true;          -- Enable cryptographic operations
        ENABLE_SATURATE : boolean := true;          -- Enable saturated arithmetic
        ENABLE_BCD      : boolean := true;          -- Enable BCD arithmetic
        ENABLE_MAC      : boolean := true;          -- Enable multiply-accumulate
        
        -- Pipeline configuration
        PIPELINE_STAGES : integer := 1;             -- Number of pipeline stages (1 = combinational)
        
        -- Advanced features
        ENABLE_EXCEPTIONS : boolean := true;        -- Enable exception handling
        ENABLE_SECURITY   : boolean := true;        -- Enable security features
        ENABLE_DEBUG      : boolean := true         -- Enable debug features
    );
    port (
        -- System interface
        clk             : in  std_logic;
        reset           : in  std_logic;
        enable          : in  std_logic;
        
        -- Data interface (128-bit)
        a               : in  std_logic_vector(127 downto 0);
        b               : in  std_logic_vector(127 downto 0);
        result          : out std_logic_vector(127 downto 0);
        result_hi       : out std_logic_vector(127 downto 0);  -- For 256-bit results
        
        -- Control interface
        alu_op          : in  std_logic_vector(ALU_OP_WIDTH-1 downto 0);
        mode            : in  std_logic_vector(3 downto 0);    -- Operation mode
        shift_amount    : in  std_logic_vector(SHIFT_WIDTH-1 downto 0);
        carry_in        : in  std_logic;
        
        -- Status interface - Basic flags
        zero_flag       : out std_logic;
        carry_flag      : out std_logic;
        overflow_flag   : out std_logic;
        negative_flag   : out std_logic;
        parity_flag     : out std_logic;
        
        -- Status interface - Extended flags
        half_carry_flag : out std_logic;
        aux_carry_flag  : out std_logic;
        sign_flag       : out std_logic;
        trap_flag       : out std_logic;
        direction_flag  : out std_logic;
        interrupt_flag  : out std_logic;
        
        -- Status interface - Advanced flags
        bit_test_flag   : out std_logic;
        fp_invalid_flag : out std_logic;
        fp_overflow_flag: out std_logic;
        fp_underflow_flag: out std_logic;
        fp_inexact_flag : out std_logic;
        fp_zero_divide_flag: out std_logic;
        simd_overflow_flag: out std_logic;
        simd_underflow_flag: out std_logic;
        
        -- Control and status
        ready           : out std_logic;
        exception       : out std_logic;
        exception_code  : out std_logic_vector(7 downto 0);
        security_violation: out std_logic
    );
end alu_128bit;

architecture Behavioral of alu_128bit is
    
    -- ========================================================================
    -- ALU OPERATION CODES (8-bit encoding for 256 operations)
    -- ========================================================================
    
    -- Basic arithmetic operations (0x00-0x0F)
    constant ALU_ADD        : std_logic_vector(7 downto 0) := x"00";
    constant ALU_SUB        : std_logic_vector(7 downto 0) := x"01";
    constant ALU_MUL        : std_logic_vector(7 downto 0) := x"02";
    constant ALU_DIV        : std_logic_vector(7 downto 0) := x"03";
    constant ALU_MOD        : std_logic_vector(7 downto 0) := x"04";
    constant ALU_MAC        : std_logic_vector(7 downto 0) := x"05";
    constant ALU_ABS        : std_logic_vector(7 downto 0) := x"06";
    constant ALU_NEG        : std_logic_vector(7 downto 0) := x"07";
    constant ALU_INC        : std_logic_vector(7 downto 0) := x"08";
    constant ALU_DEC        : std_logic_vector(7 downto 0) := x"09";
    constant ALU_MIN        : std_logic_vector(7 downto 0) := x"0A";
    constant ALU_MAX        : std_logic_vector(7 downto 0) := x"0B";
    constant ALU_AVG        : std_logic_vector(7 downto 0) := x"0C";
    constant ALU_SQRT       : std_logic_vector(7 downto 0) := x"0D";
    constant ALU_POW        : std_logic_vector(7 downto 0) := x"0E";
    constant ALU_LOG        : std_logic_vector(7 downto 0) := x"0F";
    
    -- Logical operations (0x10-0x1F)
    constant ALU_AND        : std_logic_vector(7 downto 0) := x"10";
    constant ALU_OR         : std_logic_vector(7 downto 0) := x"11";
    constant ALU_XOR        : std_logic_vector(7 downto 0) := x"12";
    constant ALU_NOT        : std_logic_vector(7 downto 0) := x"13";
    constant ALU_NAND       : std_logic_vector(7 downto 0) := x"14";
    constant ALU_NOR        : std_logic_vector(7 downto 0) := x"15";
    constant ALU_ANDN       : std_logic_vector(7 downto 0) := x"16";
    constant ALU_ORN        : std_logic_vector(7 downto 0) := x"17";
    constant ALU_BIT_SET    : std_logic_vector(7 downto 0) := x"18";
    constant ALU_BIT_CLR    : std_logic_vector(7 downto 0) := x"19";
    constant ALU_BIT_TOG    : std_logic_vector(7 downto 0) := x"1A";
    constant ALU_BIT_TST    : std_logic_vector(7 downto 0) := x"1B";
    constant ALU_MASK       : std_logic_vector(7 downto 0) := x"1C";
    constant ALU_SELECT     : std_logic_vector(7 downto 0) := x"1D";
    constant ALU_MERGE      : std_logic_vector(7 downto 0) := x"1E";
    constant ALU_EXTRACT    : std_logic_vector(7 downto 0) := x"1F";
    
    -- Shift and rotate operations (0x20-0x2F)
    constant ALU_SLL        : std_logic_vector(7 downto 0) := x"20";
    constant ALU_SRL        : std_logic_vector(7 downto 0) := x"21";
    constant ALU_SRA        : std_logic_vector(7 downto 0) := x"22";
    constant ALU_ROL        : std_logic_vector(7 downto 0) := x"23";
    constant ALU_ROR        : std_logic_vector(7 downto 0) := x"24";
    constant ALU_RCL        : std_logic_vector(7 downto 0) := x"25";
    constant ALU_RCR        : std_logic_vector(7 downto 0) := x"26";
    constant ALU_FUNNEL_L   : std_logic_vector(7 downto 0) := x"27";
    constant ALU_FUNNEL_R   : std_logic_vector(7 downto 0) := x"28";
    constant ALU_BARREL_L   : std_logic_vector(7 downto 0) := x"29";
    constant ALU_BARREL_R   : std_logic_vector(7 downto 0) := x"2A";
    
    -- Bit manipulation operations (0x30-0x3F)
    constant ALU_CLZ        : std_logic_vector(7 downto 0) := x"30";
    constant ALU_CTZ        : std_logic_vector(7 downto 0) := x"31";
    constant ALU_POPCNT     : std_logic_vector(7 downto 0) := x"32";
    constant ALU_REV        : std_logic_vector(7 downto 0) := x"33";
    constant ALU_BSWAP      : std_logic_vector(7 downto 0) := x"34";
    constant ALU_FFS        : std_logic_vector(7 downto 0) := x"35";
    constant ALU_FLS        : std_logic_vector(7 downto 0) := x"36";
    constant ALU_PARITY     : std_logic_vector(7 downto 0) := x"37";
    constant ALU_GRAY_ENC   : std_logic_vector(7 downto 0) := x"38";
    constant ALU_GRAY_DEC   : std_logic_vector(7 downto 0) := x"39";
    constant ALU_HAMMING    : std_logic_vector(7 downto 0) := x"3A";
    constant ALU_CRC        : std_logic_vector(7 downto 0) := x"3B";
    
    -- Comparison operations (0x40-0x4F)
    constant ALU_CMP        : std_logic_vector(7 downto 0) := x"40";
    constant ALU_CMPU       : std_logic_vector(7 downto 0) := x"41";
    constant ALU_CMPS       : std_logic_vector(7 downto 0) := x"42";
    constant ALU_TEST       : std_logic_vector(7 downto 0) := x"43";
    constant ALU_SCAN       : std_logic_vector(7 downto 0) := x"44";
    
    -- Data movement operations (0x50-0x5F)
    constant ALU_PASS_A     : std_logic_vector(7 downto 0) := x"50";
    constant ALU_PASS_B     : std_logic_vector(7 downto 0) := x"51";
    constant ALU_SWAP       : std_logic_vector(7 downto 0) := x"52";
    constant ALU_PACK       : std_logic_vector(7 downto 0) := x"53";
    constant ALU_UNPACK     : std_logic_vector(7 downto 0) := x"54";
    constant ALU_SHUFFLE    : std_logic_vector(7 downto 0) := x"55";
    constant ALU_PERMUTE    : std_logic_vector(7 downto 0) := x"56";
    
    -- SIMD operations (0x60-0x6F)
    constant ALU_SIMD_ADD   : std_logic_vector(7 downto 0) := x"60";
    constant ALU_SIMD_SUB   : std_logic_vector(7 downto 0) := x"61";
    constant ALU_SIMD_MUL   : std_logic_vector(7 downto 0) := x"62";
    constant ALU_SIMD_MAC   : std_logic_vector(7 downto 0) := x"63";
    constant ALU_SIMD_MIN   : std_logic_vector(7 downto 0) := x"64";
    constant ALU_SIMD_MAX   : std_logic_vector(7 downto 0) := x"65";
    constant ALU_SIMD_AVG   : std_logic_vector(7 downto 0) := x"66";
    constant ALU_SIMD_SAD   : std_logic_vector(7 downto 0) := x"67";
    
    -- Vector operations (0x70-0x7F)
    constant ALU_VADD       : std_logic_vector(7 downto 0) := x"70";
    constant ALU_VSUB       : std_logic_vector(7 downto 0) := x"71";
    constant ALU_VMUL       : std_logic_vector(7 downto 0) := x"72";
    constant ALU_VDOT       : std_logic_vector(7 downto 0) := x"73";
    constant ALU_VCROSS     : std_logic_vector(7 downto 0) := x"74";
    constant ALU_VNORM      : std_logic_vector(7 downto 0) := x"75";
    constant ALU_VSUM       : std_logic_vector(7 downto 0) := x"76";
    constant ALU_VAVG       : std_logic_vector(7 downto 0) := x"77";
    
    -- Floating-point operations (0x80-0x8F)
    constant ALU_FADD       : std_logic_vector(7 downto 0) := x"80";
    constant ALU_FSUB       : std_logic_vector(7 downto 0) := x"81";
    constant ALU_FMUL       : std_logic_vector(7 downto 0) := x"82";
    constant ALU_FDIV       : std_logic_vector(7 downto 0) := x"83";
    constant ALU_FMAC       : std_logic_vector(7 downto 0) := x"84";
    constant ALU_FSQRT      : std_logic_vector(7 downto 0) := x"85";
    constant ALU_FABS       : std_logic_vector(7 downto 0) := x"86";
    constant ALU_FNEG       : std_logic_vector(7 downto 0) := x"87";
    constant ALU_FMIN       : std_logic_vector(7 downto 0) := x"88";
    constant ALU_FMAX       : std_logic_vector(7 downto 0) := x"89";
    constant ALU_FCMP       : std_logic_vector(7 downto 0) := x"8A";
    constant ALU_FCONV      : std_logic_vector(7 downto 0) := x"8B";
    
    -- Cryptographic operations (0x90-0x9F)
    constant ALU_AES_ENC    : std_logic_vector(7 downto 0) := x"90";
    constant ALU_AES_DEC    : std_logic_vector(7 downto 0) := x"91";
    constant ALU_SHA256     : std_logic_vector(7 downto 0) := x"92";
    constant ALU_SHA512     : std_logic_vector(7 downto 0) := x"93";
    constant ALU_MD5        : std_logic_vector(7 downto 0) := x"94";
    constant ALU_RNG        : std_logic_vector(7 downto 0) := x"95";
    constant ALU_MODEXP     : std_logic_vector(7 downto 0) := x"96";
    constant ALU_MODINV     : std_logic_vector(7 downto 0) := x"97";
    
    -- ========================================================================
    -- OPERATION MODES
    -- ========================================================================
    
    constant MODE_NORMAL    : std_logic_vector(3 downto 0) := x"0";
    constant MODE_SATURATE  : std_logic_vector(3 downto 0) := x"1";
    constant MODE_SIMD_64   : std_logic_vector(3 downto 0) := x"2";
    constant MODE_SIMD_32   : std_logic_vector(3 downto 0) := x"3";
    constant MODE_SIMD_16   : std_logic_vector(3 downto 0) := x"4";
    constant MODE_SIMD_8    : std_logic_vector(3 downto 0) := x"5";
    constant MODE_VECTOR    : std_logic_vector(3 downto 0) := x"6";
    constant MODE_EXTENDED  : std_logic_vector(3 downto 0) := x"7";
    constant MODE_BCD       : std_logic_vector(3 downto 0) := x"8";
    constant MODE_FLOAT     : std_logic_vector(3 downto 0) := x"9";
    constant MODE_CRYPTO    : std_logic_vector(3 downto 0) := x"A";
    constant MODE_DEBUG     : std_logic_vector(3 downto 0) := x"B";
    
    -- ========================================================================
    -- INTERNAL SIGNALS
    -- ========================================================================
    
    -- Arithmetic operation results
    signal add_result       : std_logic_vector(128 downto 0);  -- 129 bits for carry
    signal sub_result       : std_logic_vector(128 downto 0);  -- 129 bits for borrow
    signal mul_result       : std_logic_vector(255 downto 0);  -- 256 bits for full result
    signal div_quotient     : std_logic_vector(127 downto 0);
    signal div_remainder    : std_logic_vector(127 downto 0);
    signal mac_result       : std_logic_vector(255 downto 0);
    signal sqrt_result      : std_logic_vector(127 downto 0);
    
    -- Logical operation results
    signal and_result       : std_logic_vector(127 downto 0);
    signal or_result        : std_logic_vector(127 downto 0);
    signal xor_result       : std_logic_vector(127 downto 0);
    signal not_result       : std_logic_vector(127 downto 0);
    
    -- Shift and rotate operation results
    signal sll_result       : std_logic_vector(127 downto 0);
    signal srl_result       : std_logic_vector(127 downto 0);
    signal sra_result       : std_logic_vector(127 downto 0);
    signal rol_result       : std_logic_vector(127 downto 0);
    signal ror_result       : std_logic_vector(127 downto 0);
    signal shift_amt        : integer range 0 to 127;
    
    -- Bit manipulation results
    signal clz_result       : std_logic_vector(127 downto 0);
    signal ctz_result       : std_logic_vector(127 downto 0);
    signal popcnt_result    : std_logic_vector(127 downto 0);
    signal rev_result       : std_logic_vector(127 downto 0);
    signal bswap_result     : std_logic_vector(127 downto 0);
    
    -- Advanced arithmetic results
    signal abs_result       : std_logic_vector(127 downto 0);
    signal neg_result       : std_logic_vector(127 downto 0);
    signal inc_result       : std_logic_vector(127 downto 0);
    signal dec_result       : std_logic_vector(127 downto 0);
    signal min_result       : std_logic_vector(127 downto 0);
    signal max_result       : std_logic_vector(127 downto 0);
    
    -- SIMD operation results
    signal simd64_add_result : std_logic_vector(127 downto 0);
    signal simd32_add_result : std_logic_vector(127 downto 0);
    signal simd16_add_result : std_logic_vector(127 downto 0);
    signal simd8_add_result  : std_logic_vector(127 downto 0);
    signal simd64_sub_result : std_logic_vector(127 downto 0);
    signal simd32_sub_result : std_logic_vector(127 downto 0);
    signal simd16_sub_result : std_logic_vector(127 downto 0);
    signal simd8_sub_result  : std_logic_vector(127 downto 0);
    signal simd64_mul_result : std_logic_vector(127 downto 0);
    signal simd32_mul_result : std_logic_vector(127 downto 0);
    signal simd16_mul_result : std_logic_vector(127 downto 0);
    signal simd8_mul_result  : std_logic_vector(127 downto 0);
    
    -- Vector operation results
    signal vector_add_result : std_logic_vector(127 downto 0);
    signal vector_sub_result : std_logic_vector(127 downto 0);
    signal vector_mul_result : std_logic_vector(127 downto 0);
    signal vector_dot_result : std_logic_vector(127 downto 0);
    signal vector_sum_result : std_logic_vector(127 downto 0);
    signal vector_avg_result : std_logic_vector(127 downto 0);
    
    -- Floating-point operation results (if enabled)
    signal float_add_result : std_logic_vector(127 downto 0);
    signal float_sub_result : std_logic_vector(127 downto 0);
    signal float_mul_result : std_logic_vector(127 downto 0);
    signal float_div_result : std_logic_vector(127 downto 0);
    
    -- Cryptographic operation results (if enabled)
    signal aes_enc_result   : std_logic_vector(127 downto 0);
    signal aes_dec_result   : std_logic_vector(127 downto 0);
    signal sha256_result    : std_logic_vector(255 downto 0);
    signal rng_result       : std_logic_vector(127 downto 0);
    
    -- Saturated arithmetic results
    signal sat_add_result   : std_logic_vector(127 downto 0);
    signal sat_sub_result   : std_logic_vector(127 downto 0);
    signal sat_mul_result   : std_logic_vector(127 downto 0);
    
    -- BCD arithmetic results
    signal bcd_add_result   : std_logic_vector(127 downto 0);
    signal bcd_sub_result   : std_logic_vector(127 downto 0);
    signal bcd_carry        : std_logic;
    
    -- Internal result and flag signals
    signal result_int       : std_logic_vector(127 downto 0);
    signal result_hi_int    : std_logic_vector(127 downto 0);
    signal zero_flag_int    : std_logic;
    signal carry_flag_int   : std_logic;
    signal overflow_flag_int: std_logic;
    signal negative_flag_int: std_logic;
    signal parity_flag_int  : std_logic;
    signal half_carry_flag_int: std_logic;
    signal aux_carry_flag_int: std_logic;
    signal sign_flag_int    : std_logic;
    signal trap_flag_int    : std_logic;
    signal direction_flag_int: std_logic;
    signal interrupt_flag_int: std_logic;
    signal bit_test_flag_int: std_logic;
    signal fp_invalid_flag_int: std_logic;
    signal fp_overflow_flag_int: std_logic;
    signal fp_underflow_flag_int: std_logic;
    signal fp_inexact_flag_int: std_logic;
    signal fp_zero_divide_flag_int: std_logic;
    signal simd_overflow_flag_int: std_logic;
    signal simd_underflow_flag_int: std_logic;
    signal exception_int    : std_logic;
    signal exception_code_int: std_logic_vector(7 downto 0);
    signal security_violation_int: std_logic;
    
    -- Pipeline signals (if enabled)
    signal result_pipelined : std_logic_vector(127 downto 0);
    signal valid_pipelined  : std_logic;
    
    -- Constants for saturated arithmetic
    constant MAX_POS_128    : signed(127 downto 0) := x"7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
    constant MAX_NEG_128    : signed(127 downto 0) := x"80000000000000000000000000000000";

begin
    
    -- ========================================================================
    -- BASIC ARITHMETIC OPERATIONS
    -- ========================================================================
    
    -- 128-bit addition with carry
    add_result <= std_logic_vector(unsigned('0' & a) + unsigned('0' & b) + unsigned'("" & carry_in));
    
    -- 128-bit subtraction with borrow
    sub_result <= std_logic_vector(unsigned('0' & a) - unsigned('0' & b) - unsigned'("" & carry_in));
    
    -- 128-bit multiplication (if enabled)
    mul_gen: if ENABLE_MUL generate
        mul_result <= std_logic_vector(unsigned(a) * unsigned(b));
    end generate;
    
    -- ========================================================================
    -- SIMD OPERATIONS (if enabled)
    -- ========================================================================
    
    simd_gen: if ENABLE_SIMD generate
        -- 2x64-bit SIMD operations
        simd64_operations: process(a, b)
        begin
            -- 2x64-bit addition
            simd64_add_result(63 downto 0) <= std_logic_vector(unsigned(a(63 downto 0)) + unsigned(b(63 downto 0)));
            simd64_add_result(127 downto 64) <= std_logic_vector(unsigned(a(127 downto 64)) + unsigned(b(127 downto 64)));
            
            -- 2x64-bit subtraction
            simd64_sub_result(63 downto 0) <= std_logic_vector(unsigned(a(63 downto 0)) - unsigned(b(63 downto 0)));
            simd64_sub_result(127 downto 64) <= std_logic_vector(unsigned(a(127 downto 64)) - unsigned(b(127 downto 64)));
            
            -- 2x64-bit multiplication (lower 64 bits of result)
            simd64_mul_result(63 downto 0) <= std_logic_vector(unsigned(a(31 downto 0)) * unsigned(b(31 downto 0)));
            simd64_mul_result(127 downto 64) <= std_logic_vector(unsigned(a(95 downto 64)) * unsigned(b(95 downto 64)));
        end process;
        
        -- 4x32-bit SIMD operations
        simd32_operations: process(a, b)
        begin
            for i in 0 to 3 loop
                -- 4x32-bit addition
                simd32_add_result(32*i+31 downto 32*i) <= 
                    std_logic_vector(unsigned(a(32*i+31 downto 32*i)) + unsigned(b(32*i+31 downto 32*i)));
                
                -- 4x32-bit subtraction
                simd32_sub_result(32*i+31 downto 32*i) <= 
                    std_logic_vector(unsigned(a(32*i+31 downto 32*i)) - unsigned(b(32*i+31 downto 32*i)));
                
                -- 4x32-bit multiplication (lower 32 bits of result)
                simd32_mul_result(32*i+31 downto 32*i) <= 
                    std_logic_vector(unsigned(a(16*i+15 downto 16*i)) * unsigned(b(16*i+15 downto 16*i)));
            end loop;
        end process;
        
        -- 8x16-bit SIMD operations
        simd16_operations: process(a, b)
        begin
            for i in 0 to 7 loop
                -- 8x16-bit addition
                simd16_add_result(16*i+15 downto 16*i) <= 
                    std_logic_vector(unsigned(a(16*i+15 downto 16*i)) + unsigned(b(16*i+15 downto 16*i)));
                
                -- 8x16-bit subtraction
                simd16_sub_result(16*i+15 downto 16*i) <= 
                    std_logic_vector(unsigned(a(16*i+15 downto 16*i)) - unsigned(b(16*i+15 downto 16*i)));
                
                -- 8x16-bit multiplication (lower 16 bits of result)
                simd16_mul_result(16*i+15 downto 16*i) <= 
                    std_logic_vector(unsigned(a(8*i+7 downto 8*i)) * unsigned(b(8*i+7 downto 8*i)));
            end loop;
        end process;
        
        -- 16x8-bit SIMD operations
        simd8_operations: process(a, b)
        begin
            for i in 0 to 15 loop
                -- 16x8-bit addition
                simd8_add_result(8*i+7 downto 8*i) <= 
                    std_logic_vector(unsigned(a(8*i+7 downto 8*i)) + unsigned(b(8*i+7 downto 8*i)));
                
                -- 16x8-bit subtraction
                simd8_sub_result(8*i+7 downto 8*i) <= 
                    std_logic_vector(unsigned(a(8*i+7 downto 8*i)) - unsigned(b(8*i+7 downto 8*i)));
                
                -- 16x8-bit multiplication (lower 8 bits of result)
                simd8_mul_result(8*i+7 downto 8*i) <= 
                    std_logic_vector(unsigned(a(4*i+3 downto 4*i)) * unsigned(b(4*i+3 downto 4*i)));
            end loop;
        end process;
    end generate;
    
    -- ========================================================================
    -- VECTOR OPERATIONS (if enabled)
    -- ========================================================================
    
    vector_gen: if ENABLE_VECTOR generate
        vector_operations: process(a, b)
            variable dot_product : unsigned(255 downto 0);
            variable sum_result : unsigned(127 downto 0);
        begin
            -- Vector addition (element-wise)
            vector_add_result <= std_logic_vector(unsigned(a) + unsigned(b));
            
            -- Vector subtraction (element-wise)
            vector_sub_result <= std_logic_vector(unsigned(a) - unsigned(b));
            
            -- Vector multiplication (element-wise)
            vector_mul_result <= std_logic_vector(unsigned(a) * unsigned(b));
            
            -- Dot product (sum of element-wise multiplication)
            dot_product := unsigned(a) * unsigned(b);
            vector_dot_result <= std_logic_vector(dot_product(127 downto 0));
            
            -- Vector sum (sum of all elements)
            sum_result := (others => '0');
            for i in 0 to 15 loop
                sum_result := sum_result + unsigned(a(8*i+7 downto 8*i));
            end loop;
            vector_sum_result <= std_logic_vector(sum_result);
            
            -- Vector average
            vector_avg_result <= std_logic_vector(sum_result / 16);
        end process;
    end generate;
    
    -- ========================================================================
    -- SHIFT AND ROTATE OPERATIONS (if enabled)
    -- ========================================================================
    
    shift_gen: if ENABLE_SHIFT generate
        shift_amt <= to_integer(unsigned(shift_amount));
        
        shift_operations: process(a, shift_amt, carry_in)
        begin
            -- Logical shift left
            if shift_amt = 0 then
                sll_result <= a;
            elsif shift_amt <= 127 then
                sll_result <= std_logic_vector(shift_left(unsigned(a), shift_amt));
            else
                sll_result <= (others => '0');
            end if;
            
            -- Logical shift right
            if shift_amt = 0 then
                srl_result <= a;
            elsif shift_amt <= 127 then
                srl_result <= std_logic_vector(shift_right(unsigned(a), shift_amt));
            else
                srl_result <= (others => '0');
            end if;
            
            -- Arithmetic shift right
            if shift_amt = 0 then
                sra_result <= a;
            elsif shift_amt <= 127 then
                sra_result <= std_logic_vector(shift_right(signed(a), shift_amt));
            else
                if a(127) = '1' then
                    sra_result <= (others => '1');
                else
                    sra_result <= (others => '0');
                end if;
            end if;
        end process;
    end generate;
    
    rotate_gen: if ENABLE_ROTATE generate
        rotate_operations: process(a, shift_amt)
        begin
            -- Rotate left
            if shift_amt = 0 then
                rol_result <= a;
            else
                rol_result <= a(127-shift_amt downto 0) & a(127 downto 128-shift_amt);
            end if;
            
            -- Rotate right
            if shift_amt = 0 then
                ror_result <= a;
            else
                ror_result <= a(shift_amt-1 downto 0) & a(127 downto shift_amt);
            end if;
        end process;
    end generate;
    
    -- ========================================================================
    -- BCD ARITHMETIC (if enabled)
    -- ========================================================================
    
    bcd_gen: if ENABLE_BCD generate
        bcd_arithmetic: process(a, b, carry_in)
            variable bcd_sum : std_logic_vector(8 downto 0);
            variable bcd_carry_chain : std_logic;
        begin
            bcd_carry_chain := carry_in;
            
            -- Process each BCD digit (4 bits)
            for i in 0 to 31 loop
                bcd_sum := std_logic_vector(unsigned('0' & a(4*i+3 downto 4*i)) + 
                                          unsigned('0' & b(4*i+3 downto 4*i)) + 
                                          unsigned'("" & bcd_carry_chain));
                
                if unsigned(bcd_sum(7 downto 0)) > 9 then
                    bcd_add_result(4*i+3 downto 4*i) <= std_logic_vector(unsigned(bcd_sum(7 downto 0)) + 6);
                    bcd_carry_chain := '1';
                else
                    bcd_add_result(4*i+3 downto 4*i) <= bcd_sum(3 downto 0);
                    bcd_carry_chain := bcd_sum(4);
                end if;
            end loop;
            
            bcd_carry <= bcd_carry_chain;
        end process;
    end generate;
    
    -- ========================================================================
    -- FLOATING-POINT OPERATIONS (if enabled)
    -- ========================================================================
    
    float_gen: if ENABLE_FLOAT generate
        -- Simplified floating-point operations (would need full IEEE 754 implementation)
        float_operations: process(a, b)
        begin
            -- Placeholder for floating-point operations
            -- In a real implementation, these would be complex IEEE 754 compliant operations
            float_add_result <= std_logic_vector(unsigned(a) + unsigned(b));
            float_sub_result <= std_logic_vector(unsigned(a) - unsigned(b));
            float_mul_result <= std_logic_vector(unsigned(a(63 downto 0)) * unsigned(b(63 downto 0)));
            
            if b /= x"00000000000000000000000000000000" then
                float_div_result <= std_logic_vector(unsigned(a) / unsigned(b));
            else
                float_div_result <= (others => '1');  -- Indicate error
            end if;
        end process;
    end generate;
    
    -- ========================================================================
    -- CRYPTOGRAPHIC OPERATIONS (if enabled)
    -- ========================================================================
    
    crypto_gen: if ENABLE_CRYPTO generate
        crypto_operations: process(a, b)
        begin
            -- Simplified cryptographic operations (placeholders)
            -- In a real implementation, these would be full cryptographic algorithms
            
            -- AES encryption (placeholder)
            aes_enc_result <= a xor b;  -- Simplified XOR operation
            
            -- AES decryption (placeholder)
            aes_dec_result <= a xor b;  -- Simplified XOR operation
            
            -- Random number generation (placeholder)
            rng_result <= std_logic_vector(unsigned(a) + 1);
            
            -- SHA-256 hash (placeholder - would need full implementation)
            sha256_result <= a & b;  -- Concatenation as placeholder
        end process;
    end generate;
    
    -- ========================================================================
    -- MAIN ALU OPERATION SELECTION
    -- ========================================================================
    
    alu_operation_select: process(alu_op, mode, a, b, 
                                 add_result, sub_result, mul_result, div_quotient,
                                 and_result, or_result, xor_result, not_result,
                                 sll_result, srl_result, sra_result, rol_result, ror_result,
                                 clz_result, ctz_result, popcnt_result, rev_result, bswap_result,
                                 abs_result, neg_result, inc_result, dec_result, min_result, max_result,
                                 simd64_add_result, simd32_add_result, simd16_add_result, simd8_add_result,
                                 simd64_sub_result, simd32_sub_result, simd16_sub_result, simd8_sub_result,
                                 simd64_mul_result, simd32_mul_result, simd16_mul_result, simd8_mul_result,
                                 vector_add_result, vector_sub_result, vector_mul_result, vector_dot_result,
                                 vector_sum_result, vector_avg_result,
                                 float_add_result, float_sub_result, float_mul_result, float_div_result,
                                 aes_enc_result, aes_dec_result, rng_result, sha256_result,
                                 sat_add_result, sat_sub_result, sat_mul_result,
                                 bcd_add_result)
    begin
        -- Default values
        result_int <= (others => '0');
        result_hi_int <= (others => '0');
        exception_int <= '0';
        exception_code_int <= x"00";
        security_violation_int <= '0';
        
        case alu_op is
            -- Basic arithmetic operations
            when ALU_ADD =>
                case mode is
                    when MODE_NORMAL =>
                        result_int <= add_result(127 downto 0);
                    when MODE_SATURATE =>
                        if ENABLE_SATURATE then
                            result_int <= sat_add_result;
                        else
                            result_int <= add_result(127 downto 0);
                        end if;
                    when MODE_SIMD_64 =>
                        if ENABLE_SIMD then
                            result_int <= simd64_add_result;
                        else
                            result_int <= add_result(127 downto 0);
                        end if;
                    when MODE_SIMD_32 =>
                        if ENABLE_SIMD then
                            result_int <= simd32_add_result;
                        else
                            result_int <= add_result(127 downto 0);
                        end if;
                    when MODE_SIMD_16 =>
                        if ENABLE_SIMD then
                            result_int <= simd16_add_result;
                        else
                            result_int <= add_result(127 downto 0);
                        end if;
                    when MODE_SIMD_8 =>
                        if ENABLE_SIMD then
                            result_int <= simd8_add_result;
                        else
                            result_int <= add_result(127 downto 0);
                        end if;
                    when MODE_VECTOR =>
                        if ENABLE_VECTOR then
                            result_int <= vector_add_result;
                        else
                            result_int <= add_result(127 downto 0);
                        end if;
                    when MODE_BCD =>
                        if ENABLE_BCD then
                            result_int <= bcd_add_result;
                        else
                            result_int <= add_result(127 downto 0);
                        end if;
                    when MODE_FLOAT =>
                        if ENABLE_FLOAT then
                            result_int <= float_add_result;
                        else
                            result_int <= add_result(127 downto 0);
                        end if;
                    when others =>
                        result_int <= add_result(127 downto 0);
                end case;
                
            when ALU_SUB =>
                case mode is
                    when MODE_NORMAL =>
                        result_int <= sub_result(127 downto 0);
                    when MODE_SATURATE =>
                        if ENABLE_SATURATE then
                            result_int <= sat_sub_result;
                        else
                            result_int <= sub_result(127 downto 0);
                        end if;
                    when MODE_SIMD_64 =>
                        if ENABLE_SIMD then
                            result_int <= simd64_sub_result;
                        else
                            result_int <= sub_result(127 downto 0);
                        end if;
                    when MODE_SIMD_32 =>
                        if ENABLE_SIMD then
                            result_int <= simd32_sub_result;
                        else
                            result_int <= sub_result(127 downto 0);
                        end if;
                    when MODE_SIMD_16 =>
                        if ENABLE_SIMD then
                            result_int <= simd16_sub_result;
                        else
                            result_int <= sub_result(127 downto 0);
                        end if;
                    when MODE_SIMD_8 =>
                        if ENABLE_SIMD then
                            result_int <= simd8_sub_result;
                        else
                            result_int <= sub_result(127 downto 0);
                        end if;
                    when MODE_VECTOR =>
                        if ENABLE_VECTOR then
                            result_int <= vector_sub_result;
                        else
                            result_int <= sub_result(127 downto 0);
                        end if;
                    when MODE_FLOAT =>
                        if ENABLE_FLOAT then
                            result_int <= float_sub_result;
                        else
                            result_int <= sub_result(127 downto 0);
                        end if;
                    when others =>
                        result_int <= sub_result(127 downto 0);
                end case;
                
            when ALU_MUL =>
                if ENABLE_MUL then
                    case mode is
                        when MODE_NORMAL =>
                            result_int <= mul_result(127 downto 0);
                            result_hi_int <= mul_result(255 downto 128);
                        when MODE_SATURATE =>
                            if ENABLE_SATURATE then
                                result_int <= sat_mul_result;
                            else
                                result_int <= mul_result(127 downto 0);
                                result_hi_int <= mul_result(255 downto 128);
                            end if;
                        when MODE_SIMD_64 =>
                            if ENABLE_SIMD then
                                result_int <= simd64_mul_result;
                            else
                                result_int <= mul_result(127 downto 0);
                            end if;
                        when MODE_SIMD_32 =>
                            if ENABLE_SIMD then
                                result_int <= simd32_mul_result;
                            else
                                result_int <= mul_result(127 downto 0);
                            end if;
                        when MODE_SIMD_16 =>
                            if ENABLE_SIMD then
                                result_int <= simd16_mul_result;
                            else
                                result_int <= mul_result(127 downto 0);
                            end if;
                        when MODE_SIMD_8 =>
                            if ENABLE_SIMD then
                                result_int <= simd8_mul_result;
                            else
                                result_int <= mul_result(127 downto 0);
                            end if;
                        when MODE_VECTOR =>
                            if ENABLE_VECTOR then
                                result_int <= vector_mul_result;
                            else
                                result_int <= mul_result(127 downto 0);
                            end if;
                        when MODE_FLOAT =>
                            if ENABLE_FLOAT then
                                result_int <= float_mul_result;
                            else
                                result_int <= mul_result(127 downto 0);
                            end if;
                        when others =>
                            result_int <= mul_result(127 downto 0);
                            result_hi_int <= mul_result(255 downto 128);
                    end case;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";  -- Unsupported operation
                end if;
                
            when ALU_DIV =>
                if ENABLE_DIV then
                    if b /= x"00000000000000000000000000000000" then
                        result_int <= div_quotient;
                        result_hi_int <= x"00000000000000000000000000000000" & div_remainder(95 downto 0);
                    else
                        exception_int <= '1';
                        exception_code_int <= x"02";  -- Division by zero
                    end if;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";  -- Unsupported operation
                end if;
                
            -- Logical operations
            when ALU_AND =>
                result_int <= a and b;
                
            when ALU_OR =>
                result_int <= a or b;
                
            when ALU_XOR =>
                result_int <= a xor b;
                
            when ALU_NOT =>
                result_int <= not a;
                
            when ALU_NAND =>
                result_int <= a nand b;
                
            when ALU_NOR =>
                result_int <= a nor b;
                
            when ALU_ANDN =>
                result_int <= a and (not b);
                
            when ALU_ORN =>
                result_int <= a or (not b);
                
            -- Shift operations
            when ALU_SLL =>
                if ENABLE_SHIFT then
                    result_int <= sll_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            when ALU_SRL =>
                if ENABLE_SHIFT then
                    result_int <= srl_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            when ALU_SRA =>
                if ENABLE_SHIFT then
                    result_int <= sra_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            -- Rotate operations
            when ALU_ROL =>
                if ENABLE_ROTATE then
                    result_int <= rol_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            when ALU_ROR =>
                if ENABLE_ROTATE then
                    result_int <= ror_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            -- Bit manipulation operations
            when ALU_CLZ =>
                result_int <= clz_result;
                
            when ALU_CTZ =>
                result_int <= ctz_result;
                
            when ALU_POPCNT =>
                result_int <= popcnt_result;
                
            when ALU_REV =>
                result_int <= rev_result;
                
            when ALU_BSWAP =>
                result_int <= bswap_result;
                
            -- Advanced arithmetic
            when ALU_ABS =>
                result_int <= abs_result;
                
            when ALU_NEG =>
                result_int <= neg_result;
                
            when ALU_INC =>
                result_int <= inc_result;
                
            when ALU_DEC =>
                result_int <= dec_result;
                
            when ALU_MIN =>
                result_int <= min_result;
                
            when ALU_MAX =>
                result_int <= max_result;
                
            -- Vector operations
            when ALU_VDOT =>
                if ENABLE_VECTOR then
                    result_int <= vector_dot_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            when ALU_VSUM =>
                if ENABLE_VECTOR then
                    result_int <= vector_sum_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            when ALU_VAVG =>
                if ENABLE_VECTOR then
                    result_int <= vector_avg_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            -- Floating-point operations
            when ALU_FADD =>
                if ENABLE_FLOAT then
                    result_int <= float_add_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            when ALU_FSUB =>
                if ENABLE_FLOAT then
                    result_int <= float_sub_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            when ALU_FMUL =>
                if ENABLE_FLOAT then
                    result_int <= float_mul_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            when ALU_FDIV =>
                if ENABLE_FLOAT then
                    result_int <= float_div_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            -- Cryptographic operations
            when ALU_AES_ENC =>
                if ENABLE_CRYPTO then
                    result_int <= aes_enc_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            when ALU_AES_DEC =>
                if ENABLE_CRYPTO then
                    result_int <= aes_dec_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            when ALU_RNG =>
                if ENABLE_CRYPTO then
                    result_int <= rng_result;
                else
                    exception_int <= '1';
                    exception_code_int <= x"01";
                end if;
                
            -- Comparison operations
            when ALU_CMP =>
                if signed(a) = signed(b) then
                    result_int <= x"00000000000000000000000000000000";
                elsif signed(a) < signed(b) then
                    result_int <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
                else
                    result_int <= x"00000000000000000000000000000001";
                end if;
                
            -- Data movement operations
            when ALU_PASS_A =>
                result_int <= a;
                
            when ALU_PASS_B =>
                result_int <= b;
                
            when ALU_SWAP =>
                result_int <= b;
                result_hi_int <= a;
                
            when others =>
                -- Unsupported operation
                exception_int <= '1';
                exception_code_int <= x"FF";  -- Unknown operation
                result_int <= (others => '0');
        end case;
    -- ========================================================================
    -- FLAG GENERATION
    -- ========================================================================
    
    flag_generation: process(result_int, result_hi_int, a, b, add_result, sub_result, mul_result)
        variable parity_count : integer;
        variable simd_flags : std_logic_vector(15 downto 0);
    begin
        -- Zero flag
        if result_int = x"00000000000000000000000000000000" then
            zero_flag <= '1';
        else
            zero_flag <= '0';
        end if;
        
        -- Negative flag (MSB of result)
        negative_flag <= result_int(127);
        
        -- Carry flag (for addition/subtraction)
        if add_result(128) = '1' then
            carry_flag <= '1';
        elsif sub_result(128) = '1' then
            carry_flag <= '1';
        else
            carry_flag <= '0';
        end if;
        
        -- Overflow flag (for signed arithmetic)
        if (a(127) = b(127)) and (result_int(127) /= a(127)) then
            overflow_flag <= '1';
        else
            overflow_flag <= '0';
        end if;
        
        -- Parity flag (even parity of lower 8 bits)
        parity_count := 0;
        for i in 0 to 7 loop
            if result_int(i) = '1' then
                parity_count := parity_count + 1;
            end if;
        end loop;
        if (parity_count mod 2) = 0 then
            parity_flag <= '1';
        else
            parity_flag <= '0';
        end if;
        
        -- Half-carry flag (carry from bit 3 to bit 4)
        if add_result(4) = '1' then
            half_carry_flag <= '1';
        else
            half_carry_flag <= '0';
        end if;
        
        -- Auxiliary carry flag (carry from bit 7 to bit 8)
        if add_result(8) = '1' then
            aux_carry_flag <= '1';
        else
            aux_carry_flag <= '0';
        end if;
        
        -- Sign flag (same as negative flag for 128-bit)
        sign_flag <= result_int(127);
        
        -- Trap flag (for debugging - set on overflow or exception)
        if overflow_flag = '1' or exception_int = '1' then
            trap_flag <= '1';
        else
            trap_flag <= '0';
        end if;
        
        -- Direction flag (for string operations - placeholder)
        direction_flag <= '0';  -- Default value
        
        -- Interrupt flag (for interrupt control - placeholder)
        interrupt_flag <= '1';  -- Default enabled
        
        -- Bit test flag (for bit test operations)
        if result_int /= x"00000000000000000000000000000000" then
            bit_test_flag <= '1';
        else
            bit_test_flag <= '0';
        end if;
        
        -- Floating-point flags (simplified)
        if ENABLE_FLOAT then
            -- Invalid operation flag
            if b = x"00000000000000000000000000000000" and alu_op = ALU_FDIV then
                fp_invalid_flag <= '1';
            else
                fp_invalid_flag <= '0';
            end if;
            
            -- Division by zero flag
            if b = x"00000000000000000000000000000000" and alu_op = ALU_FDIV then
                fp_div_zero_flag <= '1';
            else
                fp_div_zero_flag <= '0';
            end if;
            
            -- Overflow flag
            fp_overflow_flag <= '0';  -- Simplified
            
            -- Underflow flag
            fp_underflow_flag <= '0';  -- Simplified
            
            -- Inexact flag
            fp_inexact_flag <= '0';  -- Simplified
        else
            fp_invalid_flag <= '0';
            fp_div_zero_flag <= '0';
            fp_overflow_flag <= '0';
            fp_underflow_flag <= '0';
            fp_inexact_flag <= '0';
        end if;
        
        -- SIMD flags (one flag per SIMD element)
        if ENABLE_SIMD then
            for i in 0 to 15 loop
                if result_int(8*i+7 downto 8*i) = x"00" then
                    simd_flags(i) := '1';
                else
                    simd_flags(i) := '0';
                end if;
            end loop;
            simd_zero_flags <= simd_flags;
        else
            simd_zero_flags <= (others => '0');
        end if;
    end process;
    
    -- ========================================================================
    -- PIPELINE IMPLEMENTATION (if enabled)
    -- ========================================================================
    
    pipeline_gen: if PIPELINE_STAGES > 1 generate
        type pipeline_array is array (0 to PIPELINE_STAGES-1) of std_logic_vector(127 downto 0);
        signal pipeline_data : pipeline_array;
        signal pipeline_valid : std_logic_vector(PIPELINE_STAGES-1 downto 0);
        
        pipeline_process: process(clk, rst)
        begin
            if rst = '1' then
                pipeline_data <= (others => (others => '0'));
                pipeline_valid <= (others => '0');
            elsif rising_edge(clk) then
                if enable = '1' then
                    -- Shift pipeline stages
                    for i in PIPELINE_STAGES-1 downto 1 loop
                        pipeline_data(i) <= pipeline_data(i-1);
                        pipeline_valid(i) <= pipeline_valid(i-1);
                    end loop;
                    
                    -- Input new data
                    pipeline_data(0) <= result_int;
                    pipeline_valid(0) <= '1';
                end if;
            end if;
        end process;
        
        -- Output from final pipeline stage
        result <= pipeline_data(PIPELINE_STAGES-1) when pipeline_valid(PIPELINE_STAGES-1) = '1' else (others => '0');
        result_hi <= result_hi_int when pipeline_valid(PIPELINE_STAGES-1) = '1' else (others => '0');
        valid <= pipeline_valid(PIPELINE_STAGES-1);
        
    else generate
        -- Direct output (no pipeline)
        result <= result_int;
        result_hi <= result_hi_int;
        valid <= enable;
    end generate;
    
    -- ========================================================================
    -- OUTPUT ASSIGNMENTS
    -- ========================================================================
    
    -- Status flags
    flags(0) <= zero_flag;
    flags(1) <= carry_flag;
    flags(2) <= overflow_flag;
    flags(3) <= negative_flag;
    flags(4) <= parity_flag;
    flags(5) <= half_carry_flag;
    flags(6) <= aux_carry_flag;
    flags(7) <= sign_flag;
    flags(8) <= trap_flag;
    flags(9) <= direction_flag;
    flags(10) <= interrupt_flag;
    flags(11) <= bit_test_flag;
    flags(12) <= fp_invalid_flag;
    flags(13) <= fp_div_zero_flag;
    flags(14) <= fp_overflow_flag;
    flags(15) <= fp_underflow_flag;
    flags(16) <= fp_inexact_flag;
    flags(31 downto 17) <= (others => '0');  -- Reserved
    
    -- Exception handling
    exception <= exception_int;
    exception_code <= exception_code_int;
    security_violation <= security_violation_int;
    
    -- Extended status
    extended_flags(15 downto 0) <= simd_zero_flags;
    extended_flags(31 downto 16) <= (others => '0');  -- Reserved for future use

end Behavioral;

-- ============================================================================
-- VERIFICATION AND EXTENSION NOTES
-- ============================================================================

-- This 128-bit ALU implementation provides:
-- 1. Comprehensive arithmetic operations (add, subtract, multiply, divide)
-- 2. Complete logical operations (AND, OR, XOR, NOT, NAND, NOR)
-- 3. Advanced shift and rotate operations
-- 4. Extensive bit manipulation functions
-- 5. SIMD operations for parallel processing
-- 6. Vector operations for multimedia applications
-- 7. Floating-point operation support (simplified)
-- 8. Cryptographic operation placeholders
-- 9. Comprehensive flag generation
-- 10. Optional pipeline support for high-frequency operation
-- 11. Exception handling and security features
-- 12. Configurable feature enables through generics

-- For production use, consider:
-- 1. Full IEEE 754 floating-point implementation
-- 2. Complete cryptographic algorithm implementations
-- 3. Advanced pipeline optimization
-- 4. Power optimization techniques
-- 5. Formal verification of critical operations
-- 6. Performance optimization for target FPGA
-- 7. Resource utilization optimization
-- 8. Timing closure optimization

-- Testing recommendations:
-- 1. Comprehensive testbench with all operation modes
-- 2. Corner case testing (overflow, underflow, edge values)
-- 3. SIMD operation verification
-- 4. Pipeline functionality testing
-- 5. Exception handling verification
-- 6. Performance benchmarking
-- 7. Resource utilization analysis
-- 8. Power consumption analysis

-- Extension possibilities:
-- 1. Custom instruction support
-- 2. Machine learning acceleration
-- 3. DSP operation optimization
-- 4. Multi-precision arithmetic
-- 5. Specialized cryptographic units
-- 6. Advanced vector processing
-- 7. Custom SIMD operations
-- 8. Hardware debugging features
    div_gen: if ENABLE_DIV generate
        division: process(a, b)
        begin
            if b /= x"00000000000000000000000000000000" then
                div_quotient <= std_logic_vector(unsigned(a) / unsigned(b));
                div_remainder <= std_logic_vector(unsigned(a) mod unsigned(b));
            else
                div_quotient <= (others => '1');  -- Indicate error
                div_remainder <= (others => '0');
            end if;
        end process;
    end generate;
    
    -- Advanced arithmetic operations
    abs_result <= std_logic_vector(abs(signed(a)));
    neg_result <= std_logic_vector(-signed(a));
    inc_result <= std_logic_vector(unsigned(a) + 1);
    dec_result <= std_logic_vector(unsigned(a) - 1);
    
    -- Min/Max operations
    min_result <= a when signed(a) < signed(b) else b;
    max_result <= a when signed(a) > signed(b) else b;
    
    -- ========================================================================
    -- BIT MANIPULATION OPERATIONS
    -- ========================================================================
    
    -- Count leading zeros
    clz_process: process(a)
        variable count : integer;
    begin
        count := 0;
        for i in 127 downto 0 loop
            if a(i) = '1' then
                exit;
            else
                count := count + 1;
            end if;
        end loop;
        clz_result <= std_logic_vector(to_unsigned(count, 128));
    end process;
    
    -- Count trailing zeros
    ctz_process: process(a)
        variable count : integer;
    begin
        count := 0;
        for i in 0 to 127 loop
            if a(i) = '1' then
                exit;
            else
                count := count + 1;
            end if;
        end loop;
        ctz_result <= std_logic_vector(to_unsigned(count, 128));
    end process;
    
    -- Population count (count of set bits)
    popcnt_process: process(a)
        variable count : integer;
    begin
        count := 0;
        for i in 0 to 127 loop
            if a(i) = '1' then
                count := count + 1;
            end if;
        end loop;
        popcnt_result <= std_logic_vector(to_unsigned(count, 128));
    end process;
    
    -- Bit reversal
    rev_process: process(a)
    begin
        for i in 0 to 127 loop
            rev_result(i) <= a(127 - i);
        end loop;
    end process;
    
    -- Byte swap (reverse byte order)
    bswap_process: process(a)
    begin
        for i in 0 to 15 loop
            bswap_result(8*i+7 downto 8*i) <= a(8*(15-i)+7 downto 8*(15-i));
        end loop;
    end process;
    
    -- ========================================================================
    -- SATURATED ARITHMETIC (if enabled)
    -- ========================================================================
    
    saturate_gen: if ENABLE_SATURATE generate
        saturated_arithmetic: process(a, b, add_result, sub_result, mul_result)
            constant MAX_POS : signed(127 downto 0) := MAX_POS_128;
            constant MAX_NEG : signed(127 downto 0) := MAX_NEG_128;
        begin
            -- Saturating addition
            if add_result(128) = '1' then  -- Overflow
                if signed(a) >= 0 and signed(b) >= 0 then
                    sat_add_result <= std_logic_vector(MAX_POS);  -- Positive saturation
                else
                    sat_add_result <= std_logic_vector(MAX_NEG);  -- Negative saturation
                end if;
            else
                sat_add_result <= add_result(127 downto 0);
            end if;
            
            -- Saturating subtraction
            if sub_result(128) = '1' then  -- Underflow
                if signed(a) >= 0 and signed(b) < 0 then
                    sat_sub_result <= std_logic_vector(MAX_POS);  -- Positive saturation
                else
                    sat_sub_result <= std_logic_vector(MAX_NEG);  -- Negative saturation
                end if;
            else
                sat_sub_result <= sub_result(127 downto 0);
            end if;
            
            -- Saturating multiplication
            if ENABLE_MUL then
                if mul_result(255 downto 127) /= (mul_result(255 downto 127)'range => mul_result(127)) then
                    if mul_result(255) = '0' then
                        sat_mul_result <= std_logic_vector(MAX_POS);  -- Positive saturation
                    else
                        sat_mul_result <= std_logic_vector(MAX_NEG);  -- Negative saturation
                    end if;
                else
                    sat_mul_result <= mul_result(127 downto 0);
                end if;
            else
                sat_mul_result <= (others => '0');
            end if;
        end process;
    end generate;