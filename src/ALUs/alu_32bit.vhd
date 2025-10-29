-- ============================================================================
-- 32-Bit Arithmetic Logic Unit (ALU) Implementation - Programming Guidance
-- ============================================================================
-- 
-- PROJECT OVERVIEW:
-- This file implements a 32-bit Arithmetic Logic Unit (ALU) designed for
-- high-performance computing applications, embedded processors, and digital
-- signal processing systems. The 32-bit ALU provides comprehensive computational
-- capabilities with optimized resource utilization for modern FPGA architectures.
-- This implementation demonstrates advanced arithmetic operations, extensive
-- flag generation, and performance optimization techniques for 32-bit processing.
--
-- LEARNING OBJECTIVES:
-- 1. Understand 32-bit ALU architecture and advanced scaling considerations
-- 2. Learn high-performance arithmetic and logical operations for wide data paths
-- 3. Practice comprehensive flag generation for 32-bit operations
-- 4. Understand advanced carry-lookahead and parallel arithmetic techniques
-- 5. Learn DSP block integration and multiplication optimization
-- 6. Practice complex combinational and sequential logic design
-- 7. Understand multi-word arithmetic and extended precision operations
--
-- ============================================================================
-- STEP-BY-STEP IMPLEMENTATION GUIDE:
-- ============================================================================
--
-- STEP 1: LIBRARY DECLARATIONS
-- ----------------------------------------------------------------------------
-- Required Libraries:
-- - IEEE library for standard logic types
-- - std_logic_1164 package for std_logic and logical operators
-- - numeric_std package for arithmetic operations and type conversions
-- - Additional packages for optimized 32-bit operations and DSP functions
-- 
-- TODO: Add library IEEE;
-- TODO: Add use IEEE.std_logic_1164.all;
-- TODO: Add use IEEE.numeric_std.all;
-- TODO: Consider adding IEEE.std_logic_arith for extended arithmetic
-- TODO: Consider adding work.alu_pkg.all for custom ALU functions
--
-- ============================================================================
-- STEP 2: ENTITY DECLARATION
-- ============================================================================
-- The entity defines the interface for the 32-bit ALU
--
-- Entity Requirements:
-- - Name: alu_32bit (specific to 32-bit implementation)
-- - Two 32-bit data inputs for operands
-- - 5-bit operation control input to select function (32 operations)
-- - 32-bit result output for computed value
-- - Comprehensive flag outputs for status indication
-- - Extended interface for multi-word and DSP operations
--
-- Port Specifications:
-- Data Interface:
-- - a : in std_logic_vector(31 downto 0) (First 32-bit operand)
-- - b : in std_logic_vector(31 downto 0) (Second 32-bit operand)
-- - result : out std_logic_vector(31 downto 0) (32-bit operation result)
-- - carry_in : in std_logic (Carry input for multi-word arithmetic)
--
-- Control Interface:
-- - alu_op : in std_logic_vector(4 downto 0) (Operation select - 32 operations)
-- - enable : in std_logic (ALU enable signal)
-- - mode : in std_logic_vector(2 downto 0) (Operation mode select)
-- - precision : in std_logic_vector(1 downto 0) (Precision control)
--
-- Status Interface:
-- - zero : out std_logic (Zero flag - result is zero)
-- - carry : out std_logic (Carry flag - arithmetic overflow)
-- - overflow : out std_logic (Overflow flag - signed arithmetic overflow)
-- - negative : out std_logic (Negative flag - result is negative)
-- - parity : out std_logic (Parity flag - even/odd parity)
-- - half_carry : out std_logic (Half carry flag - nibble overflow)
-- - auxiliary_carry : out std_logic (Auxiliary carry for BCD operations)
-- - flags : out std_logic_vector(15 downto 0) (Extended flag output)
--
-- Extended Interface:
-- - result_hi : out std_logic_vector(31 downto 0) (High word for 64-bit results)
-- - accumulator : in std_logic_vector(63 downto 0) (MAC accumulator input)
-- - acc_out : out std_logic_vector(63 downto 0) (MAC accumulator output)
-- - condition_codes : out std_logic_vector(7 downto 0) (Processor condition codes)
--
-- ============================================================================
-- STEP 3: 32-BIT ALU OPERATION PRINCIPLES
-- ============================================================================
--
-- Arithmetic Operations (32-bit optimized):
-- 1. Addition (ADD)
--    - 32-bit unsigned addition with advanced carry-lookahead
--    - Signed addition with comprehensive overflow detection
--    - Multi-word arithmetic support for 64/128/256-bit operations
--    - Carry-select and carry-skip optimization for high speed
--    - Saturating arithmetic modes for DSP and multimedia applications
--    - BCD addition support for decimal arithmetic
--
-- 2. Subtraction (SUB)
--    - 32-bit two's complement subtraction with borrow handling
--    - Advanced comparison operation implementation
--    - Absolute difference calculation with overflow protection
--    - Conditional subtraction based on processor flags
--    - Saturating subtraction for signal processing
--    - BCD subtraction for decimal operations
--
-- 3. Multiplication (MUL)
--    - 32x32 bit multiplication producing 64-bit result
--    - Unsigned, signed, and mixed-mode multiplication
--    - Booth algorithm and modified Booth recoding
--    - Wallace tree and Dadda multiplier architectures
--    - DSP block optimization for FPGA implementations
--    - Multiply-accumulate (MAC) and multiply-subtract operations
--    - Fractional multiplication for fixed-point DSP
--
-- 4. Division (DIV)
--    - 32-bit division with quotient and remainder
--    - SRT (Sweeney, Robertson, Tocher) division algorithm
--    - Non-restoring and restoring division variants
--    - Division by zero detection and exception handling
--    - Signed and unsigned division with proper rounding
--    - Modulo operations for cryptographic applications
--    - Newton-Raphson approximation for high-speed division
--
-- Logical Operations (32-bit parallel):
-- 1. Bitwise AND
--    - 32-bit parallel AND operation with optimized implementation
--    - Masking and bit filtering for 32-bit words and addresses
--    - Memory alignment checking and address validation
--    - Interrupt mask and status register manipulation
--    - Bit field extraction and isolation operations
--
-- 2. Bitwise OR
--    - 32-bit parallel OR operation with carry-free implementation
--    - Bit setting and combination for control registers
--    - Flag register manipulation and status aggregation
--    - Multi-bit status indication and error reporting
--    - Address generation and pointer manipulation
--
-- 3. Bitwise XOR
--    - 32-bit parallel XOR operation for toggle and comparison
--    - Checksum and hash calculation for data integrity
--    - Simple encryption/decryption and obfuscation
--    - Parity generation and error detection codes
--    - Pseudo-random number generation support
--
-- 4. Bitwise NOT
--    - 32-bit inversion operation with single-cycle execution
--    - One's complement generation for arithmetic operations
--    - Bit mask inversion for 32-bit address and data words
--    - Logical negation for boolean operations
--    - Two's complement preparation for subtraction
--
-- Shift and Rotate Operations (32-bit barrel shifter):
-- 1. Logical Shift Left (SLL)
--    - 1-bit to 31-bit left shift capability with barrel shifter
--    - Multiplication by powers of 2 (up to 2^31)
--    - Carry flag from MSB with proper flag handling
--    - Single-cycle operation for all shift amounts
--    - Bit field positioning and alignment operations
--
-- 2. Logical Shift Right (SRL)
--    - 1-bit to 31-bit right shift with zero-fill
--    - Division by powers of 2 for unsigned operands
--    - Carry flag from LSB for precision tracking
--    - Address calculation and pointer arithmetic
--    - Bit field extraction and normalization
--
-- 3. Arithmetic Shift Right (SRA)
--    - Sign-extended right shift for signed 32-bit numbers
--    - Signed division by powers of 2 with proper rounding
--    - Sign bit preservation across all shift amounts
--    - Two's complement arithmetic compatibility
--    - Fixed-point scaling and normalization
--
-- 4. Rotate Operations (ROL/ROR)
--    - Circular bit rotation (1-31 positions) with barrel shifter
--    - Carry flag integration for 33-bit extended rotation
--    - Bit pattern manipulation for cryptographic operations
--    - Cyclic redundancy check (CRC) calculation support
--    - Hash function and pseudo-random generation
--
-- Comparison Operations (32-bit optimized):
-- 1. Equality (EQ)
--    - 32-bit parallel comparison with tree optimization
--    - Zero flag generation for conditional branches
--    - String and array comparison for data processing
--    - Address matching and memory management operations
--    - Cache tag comparison and hit detection
--
-- 2. Less Than (LT)
--    - Unsigned and signed comparison for 32-bit values
--    - Magnitude comparison for sorting and searching
--    - Range checking for array bounds and memory protection
--    - Threshold detection for control and monitoring systems
--    - Priority comparison for scheduling algorithms
--
-- 3. Greater Than (GT)
--    - Comprehensive comparison result generation
--    - Flag-based result indication for processor integration
--    - Limit checking and boundary validation operations
--    - Conditional execution and predicated instruction support
--    - Performance monitoring and profiling operations
--
-- ============================================================================
-- STEP 4: 32-BIT ARCHITECTURE OPTIONS
-- ============================================================================
--
-- OPTION 1: High-Performance Combinational ALU (Recommended)
-- - Pure combinational logic with advanced carry-lookahead
-- - Single-cycle operation for most functions
-- - Optimized barrel shifter for all shift/rotate operations
-- - DSP block integration for multiplication operations
-- - Advanced flag generation with condition code support
-- - Resource-optimized implementation for modern FPGAs
--
-- OPTION 2: Pipelined 32-bit ALU (High-Speed)
-- - Multi-stage pipeline for maximum frequency operation
-- - Separate pipelines for arithmetic, logical, and shift operations
-- - Advanced hazard detection and forwarding logic
-- - Out-of-order execution support for complex operations
-- - Performance monitoring and profiling capabilities
-- - Power management and dynamic frequency scaling
--
-- OPTION 3: Multi-Function 32-bit ALU (Versatile)
-- - Integrated floating-point unit for IEEE 754 operations
-- - Vector processing support for SIMD operations
-- - Cryptographic instruction extensions
-- - Digital signal processing primitives
-- - Custom instruction support and extensibility
-- - Advanced debugging and trace capabilities
--
-- OPTION 4: Distributed 32-bit ALU (Scalable)
-- - Multiple parallel execution units
-- - Dynamic resource allocation and load balancing
-- - Superscalar execution with dependency tracking
-- - Advanced branch prediction and speculation
-- - Multi-threading and context switching support
-- - Fault tolerance and error recovery mechanisms
--
-- ============================================================================
-- STEP 5: 32-BIT IMPLEMENTATION CONSIDERATIONS
-- ============================================================================
--
-- Resource Optimization:
-- - Utilize FPGA carry chains and fast carry logic effectively
-- - Leverage dedicated DSP blocks for multiplication and MAC operations
-- - Implement shared resources for area-critical applications
-- - Optimize LUT utilization with advanced synthesis techniques
-- - Balance area, timing, and power consumption trade-offs
-- - Consider FPGA-specific optimizations (Xilinx, Intel, Lattice)
--
-- Timing Optimization:
-- - Implement 4-bit carry-lookahead groups for fast addition
-- - Use carry-select architecture for critical timing paths
-- - Minimize routing delays with proper floorplanning
-- - Pipeline critical operations for high-frequency targets
-- - Optimize setup and hold timing margins
-- - Target specific frequency requirements (200+ MHz)
--
-- Power Optimization:
-- - Clock gating for unused functional units and operations
-- - Operand isolation to reduce switching activity
-- - Dynamic voltage and frequency scaling (DVFS) support
-- - Low-power operation modes for battery-powered applications
-- - Static power reduction through design optimization
-- - Thermal management and power distribution considerations
--
-- Flag Generation (32-bit specific):
-- - Efficient zero detection using tree-structured NOR gates
-- - Carry/borrow flag calculation with lookahead logic
-- - Overflow detection for 32-bit signed arithmetic operations
-- - Parity calculation optimization using XOR trees
-- - Half-carry and auxiliary carry for BCD operations
-- - Condition code generation for processor integration
--
-- ============================================================================
-- STEP 6: 32-BIT ADVANCED FEATURES
-- ============================================================================
--
-- DSP Integration:
-- - Multiply-accumulate (MAC) operations with 64-bit accumulator
-- - Saturating arithmetic for digital signal processing
-- - Fixed-point arithmetic with configurable scaling
-- - FIR and IIR filter coefficient processing
-- - FFT butterfly operations and complex arithmetic
-- - Vector dot product and matrix operations
-- - Audio and video processing primitives
--
-- Vector Operations:
-- - Packed 16-bit operations (2x16-bit in 32-bit word)
-- - Packed 8-bit operations (4x8-bit in 32-bit word)
-- - SIMD arithmetic, logical, and comparison operations
-- - Parallel reduction operations (sum, min, max)
-- - Vector permutation and shuffle operations
-- - Image and multimedia processing support
-- - Parallel search and pattern matching
--
-- Floating-Point Support:
-- - IEEE 754 single-precision (32-bit) floating-point
-- - Addition, subtraction, multiplication, and division
-- - Comparison and classification operations
-- - Rounding mode control and exception handling
-- - Denormalized number support and gradual underflow
-- - NaN (Not-a-Number) and infinity handling
-- - Conversion between integer and floating-point formats
--
-- Cryptographic Operations:
-- - AES encryption/decryption primitives
-- - SHA hash function support operations
-- - Modular arithmetic for RSA and ECC
-- - Galois field operations for error correction
-- - Random number generation and entropy collection
-- - Bit manipulation for cryptographic algorithms
-- - Side-channel attack resistance features
--
-- Multi-Word Support:
-- - Carry chain for 64/128/256-bit operations
-- - Big-endian and little-endian byte ordering
-- - Word, half-word, and byte swapping operations
-- - Multi-precision arithmetic building blocks
-- - Extended precision floating-point support
-- - Long integer arithmetic for cryptography
-- - Arbitrary precision arithmetic framework
--
-- ============================================================================
-- APPLICATIONS:
-- ============================================================================
-- 1. Microprocessor Design: 32-bit CPU arithmetic and logic core
-- 2. Digital Signal Processing: High-performance audio/video processing
-- 3. Graphics Processing: 3D graphics and image manipulation
-- 4. Communication Systems: Protocol processing and error correction
-- 5. Control Systems: Real-time 32-bit control and monitoring
-- 6. Embedded Systems: High-performance computational requirements
-- 7. Scientific Computing: Numerical analysis and simulation
-- 8. Cryptographic Systems: Security and encryption applications
-- 9. Automotive Systems: Advanced driver assistance and engine control
-- 10. Industrial Automation: Process control and data acquisition
--
-- ============================================================================
-- TESTING STRATEGY:
-- ============================================================================
-- 1. Boundary Testing: 0x00000000, 0xFFFFFFFF, 0x7FFFFFFF, 0x80000000
-- 2. Arithmetic Testing: Comprehensive operation verification with edge cases
-- 3. Flag Testing: All flag combinations and boundary conditions
-- 4. Carry Testing: Multi-word operation validation and propagation
-- 5. Overflow Testing: Signed arithmetic boundary and saturation conditions
-- 6. Performance Testing: Timing analysis and frequency characterization
-- 7. Power Testing: Current consumption across all operations and modes
-- 8. Stress Testing: Continuous operation and thermal characterization
-- 9. Corner Case Testing: Unusual operand combinations and edge conditions
-- 10. Integration Testing: System-level validation with processor cores
--
-- ============================================================================
-- RECOMMENDED IMPLEMENTATION APPROACH:
-- ============================================================================
-- 1. Start with optimized 32-bit arithmetic (ADD, SUB) with carry-lookahead
-- 2. Implement comprehensive logical operations (AND, OR, XOR, NOT)
-- 3. Add advanced comparison operations and flag generation
-- 4. Implement barrel shifter for all shift and rotate operations
-- 5. Add 32x32 multiplication using DSP blocks or optimized logic
-- 6. Implement division algorithm with proper exception handling
-- 7. Add advanced features (MAC, SIMD, floating-point) as required
-- 8. Optimize for target FPGA architecture and performance requirements
-- 9. Implement comprehensive test suite and verification environment
-- 10. Add debugging, profiling, and performance monitoring features
--
-- ============================================================================
-- EXTENSION EXERCISES:
-- ============================================================================
-- 1. Implement IEEE 754 single-precision floating-point operations
-- 2. Add vector processing with packed 16-bit and 8-bit operations
-- 3. Implement cryptographic primitives (AES, SHA, modular arithmetic)
-- 4. Add multiply-accumulate (MAC) with 64-bit accumulator
-- 5. Implement saturating arithmetic modes for DSP applications
-- 6. Add conditional execution and predicated instruction support
-- 7. Implement custom application-specific operations
-- 8. Add hardware debugging, tracing, and performance monitoring
-- 9. Implement fault tolerance and error recovery mechanisms
-- 10. Add power management and dynamic frequency scaling
--
-- ============================================================================
-- COMMON MISTAKES TO AVOID:
-- ============================================================================
-- 1. Inefficient carry propagation in 32-bit arithmetic operations
-- 2. Improper overflow detection for signed 32-bit operations
-- 3. Missing optimization for FPGA-specific DSP and carry resources
-- 4. Inadequate timing closure for high-speed 32-bit operations
-- 5. Incorrect flag generation for boundary and corner cases
-- 6. Poor resource utilization for multiplication and complex operations
-- 7. Missing multi-word operation support and carry propagation
-- 8. Inadequate test coverage for 32-bit value ranges and edge cases
-- 9. Insufficient power optimization for battery-powered applications
-- 10. Missing consideration for thermal management and reliability
--
-- ============================================================================
-- DESIGN VERIFICATION CHECKLIST:
-- ============================================================================
-- □ All 32-bit arithmetic operations produce correct results
-- □ Logical operations function properly for all bit patterns
-- □ Shift and rotate operations work correctly (1-31 positions)
-- □ Flag generation is accurate for all 32-bit values and edge cases
-- □ Overflow and underflow conditions handled correctly
-- □ Carry propagation works for multi-word operations (64/128-bit)
-- □ Multiplication produces correct 64-bit results
-- □ Division handles all cases including divide-by-zero exceptions
-- □ Timing requirements are met for target frequency (200+ MHz)
-- □ Resource utilization is optimized for 32-bit operations
-- □ Power consumption is within acceptable limits
-- □ Thermal characteristics are acceptable for target application
--
-- ============================================================================
-- DIGITAL DESIGN CONTEXT:
-- ============================================================================
-- This 32-bit ALU implementation demonstrates:
-- - Advanced combinational logic design for wide data paths
-- - High-performance arithmetic implementation with carry-lookahead
-- - Comprehensive DSP block integration and optimization
-- - Advanced flag generation and processor integration
-- - Performance optimization for high-speed FPGA implementations
-- - Scalable architecture for multi-word and vector operations
--
-- ============================================================================
-- PHYSICAL IMPLEMENTATION NOTES:
-- ============================================================================
-- - Utilize FPGA carry chains, DSP blocks, and dedicated resources
-- - Consider floorplanning and placement for optimal routing
-- - Plan for balanced power distribution and thermal management
-- - Optimize for both area and timing constraints simultaneously
-- - Consider signal integrity and electromagnetic compatibility
-- - Plan for testability and manufacturing test requirements
--
-- ============================================================================
-- ADVANCED CONCEPTS:
-- ============================================================================
-- - Carry-select, carry-skip, and hybrid adder architectures
-- - Wallace tree, Dadda, and 4:2 compressor multiplier designs
-- - Booth recoding and modified Booth algorithm implementations
-- - SRT division and Newton-Raphson approximation methods
-- - Redundant binary arithmetic for ultra-high-speed operation
-- - Asynchronous and self-timed arithmetic circuit design
--
-- ============================================================================
-- SIMULATION AND VERIFICATION NOTES:
-- ============================================================================
-- - Use comprehensive directed and constrained random test vectors
-- - Verify flag generation for all boundary and corner cases
-- - Test carry propagation and multi-word arithmetic extensively
-- - Validate timing relationships and critical path analysis
-- - Check resource utilization and power consumption characteristics
-- - Verify operation across process, voltage, and temperature variations
-- - Test fault injection and error recovery mechanisms
-- - Validate electromagnetic compatibility and signal integrity
--
-- ============================================================================
-- IMPLEMENTATION TEMPLATE:
-- ============================================================================
-- Use this template as a starting point for your 32-bit ALU implementation:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity alu_32bit is
    generic (
        ENABLE_MUL        : boolean := true;      -- Enable 32x32 multiplication
        ENABLE_DIV        : boolean := false;     -- Enable 32-bit division
        ENABLE_MAC        : boolean := false;     -- Enable multiply-accumulate
        ENABLE_SATURATE   : boolean := false;     -- Enable saturating arithmetic
        ENABLE_SIMD       : boolean := false;     -- Enable packed operations
        ENABLE_FLOAT      : boolean := false;     -- Enable floating-point
        ENABLE_CRYPTO     : boolean := false;     -- Enable cryptographic ops
        PIPELINE_STAGES   : integer := 0;         -- Pipeline depth (0 = combinational)
        CARRY_LOOKAHEAD   : integer := 4;         -- Carry-lookahead group size
        DSP_OPTIMIZATION  : boolean := true       -- Use DSP blocks for multiplication
    );
    port (
        -- System Interface
        clk             : in  std_logic;
        reset           : in  std_logic;
        enable          : in  std_logic;
        
        -- Data Interface (32-bit)
        a               : in  std_logic_vector(31 downto 0);
        b               : in  std_logic_vector(31 downto 0);
        result          : out std_logic_vector(31 downto 0);
        
        -- Control Interface
        alu_op          : in  std_logic_vector(4 downto 0);  -- 32 operations
        mode            : in  std_logic_vector(2 downto 0);  -- Operation mode
        precision       : in  std_logic_vector(1 downto 0);  -- Precision control
        carry_in        : in  std_logic;
        
        -- Status Interface
        zero            : out std_logic;
        carry           : out std_logic;
        overflow        : out std_logic;
        negative        : out std_logic;
        parity          : out std_logic;
        half_carry      : out std_logic;
        auxiliary_carry : out std_logic;
        flags           : out std_logic_vector(15 downto 0);
        condition_codes : out std_logic_vector(7 downto 0);
        
        -- Extended Interface
        result_hi       : out std_logic_vector(31 downto 0); -- High word for 64-bit results
        accumulator     : in  std_logic_vector(63 downto 0); -- MAC accumulator input
        acc_out         : out std_logic_vector(63 downto 0); -- MAC accumulator output
        shift_amount    : in  std_logic_vector(4 downto 0);  -- Shift amount (0-31)
        
        -- Control and Status
        valid           : out std_logic;                      -- Result valid
        ready           : out std_logic;                      -- Ready for operation
        exception       : out std_logic;                      -- Exception occurred
        exception_code  : out std_logic_vector(3 downto 0)   -- Exception type
    );
end entity alu_32bit;

architecture behavioral of alu_32bit is
    -- 32-bit ALU Operation codes (5-bit for 32 operations)
    constant ALU_ADD     : std_logic_vector(4 downto 0) := "00000";  -- Addition
    constant ALU_SUB     : std_logic_vector(4 downto 0) := "00001";  -- Subtraction
    constant ALU_AND     : std_logic_vector(4 downto 0) := "00010";  -- Bitwise AND
    constant ALU_OR      : std_logic_vector(4 downto 0) := "00011";  -- Bitwise OR
    constant ALU_XOR     : std_logic_vector(4 downto 0) := "00100";  -- Bitwise XOR
    constant ALU_NOT     : std_logic_vector(4 downto 0) := "00101";  -- Bitwise NOT
    constant ALU_SLL     : std_logic_vector(4 downto 0) := "00110";  -- Shift Left Logical
    constant ALU_SRL     : std_logic_vector(4 downto 0) := "00111";  -- Shift Right Logical
    constant ALU_SRA     : std_logic_vector(4 downto 0) := "01000";  -- Shift Right Arithmetic
    constant ALU_ROL     : std_logic_vector(4 downto 0) := "01001";  -- Rotate Left
    constant ALU_ROR     : std_logic_vector(4 downto 0) := "01010";  -- Rotate Right
    constant ALU_CMP     : std_logic_vector(4 downto 0) := "01011";  -- Compare
    constant ALU_MUL     : std_logic_vector(4 downto 0) := "01100";  -- Multiply
    constant ALU_DIV     : std_logic_vector(4 downto 0) := "01101";  -- Divide
    constant ALU_MAC     : std_logic_vector(4 downto 0) := "01110";  -- Multiply-Accumulate
    constant ALU_PASS_A  : std_logic_vector(4 downto 0) := "01111";  -- Pass A
    constant ALU_PASS_B  : std_logic_vector(4 downto 0) := "10000";  -- Pass B
    constant ALU_ABS     : std_logic_vector(4 downto 0) := "10001";  -- Absolute value
    constant ALU_NEG     : std_logic_vector(4 downto 0) := "10010";  -- Negate
    constant ALU_INC     : std_logic_vector(4 downto 0) := "10011";  -- Increment
    constant ALU_DEC     : std_logic_vector(4 downto 0) := "10100";  -- Decrement
    constant ALU_MIN     : std_logic_vector(4 downto 0) := "10101";  -- Minimum
    constant ALU_MAX     : std_logic_vector(4 downto 0) := "10110";  -- Maximum
    constant ALU_CLZ     : std_logic_vector(4 downto 0) := "10111";  -- Count Leading Zeros
    constant ALU_CTZ     : std_logic_vector(4 downto 0) := "11000";  -- Count Trailing Zeros
    constant ALU_POPCNT  : std_logic_vector(4 downto 0) := "11001";  -- Population Count
    constant ALU_REV     : std_logic_vector(4 downto 0) := "11010";  -- Bit Reverse
    constant ALU_BSWAP   : std_logic_vector(4 downto 0) := "11011";  -- Byte Swap
    constant ALU_FADD    : std_logic_vector(4 downto 0) := "11100";  -- Floating Add
    constant ALU_FSUB    : std_logic_vector(4 downto 0) := "11101";  -- Floating Subtract
    constant ALU_FMUL    : std_logic_vector(4 downto 0) := "11110";  -- Floating Multiply
    constant ALU_FDIV    : std_logic_vector(4 downto 0) := "11111";  -- Floating Divide
    
    -- Operation modes
    constant MODE_NORMAL    : std_logic_vector(2 downto 0) := "000";  -- Normal operation
    constant MODE_SATURATE  : std_logic_vector(2 downto 0) := "001";  -- Saturating arithmetic
    constant MODE_SIMD_16   : std_logic_vector(2 downto 0) := "010";  -- SIMD 16-bit operations
    constant MODE_SIMD_8    : std_logic_vector(2 downto 0) := "011";  -- SIMD 8-bit operations
    constant MODE_EXTENDED  : std_logic_vector(2 downto 0) := "100";  -- Extended precision
    constant MODE_BCD       : std_logic_vector(2 downto 0) := "101";  -- BCD arithmetic
    constant MODE_CRYPTO    : std_logic_vector(2 downto 0) := "110";  -- Cryptographic ops
    constant MODE_FLOAT     : std_logic_vector(2 downto 0) := "111";  -- Floating-point
    
    -- Precision control
    constant PREC_SINGLE    : std_logic_vector(1 downto 0) := "00";   -- Single precision
    constant PREC_DOUBLE    : std_logic_vector(1 downto 0) := "01";   -- Double precision
    constant PREC_EXTENDED  : std_logic_vector(1 downto 0) := "10";   -- Extended precision
    constant PREC_CUSTOM    : std_logic_vector(1 downto 0) := "11";   -- Custom precision
    
    -- Internal signals
    signal result_int       : std_logic_vector(31 downto 0);
    signal result_ext       : std_logic_vector(32 downto 0);  -- Extended for carry
    signal result_hi_int    : std_logic_vector(31 downto 0);
    signal acc_out_int      : std_logic_vector(63 downto 0);
    signal zero_int         : std_logic;
    signal carry_int        : std_logic;
    signal overflow_int     : std_logic;
    signal negative_int     : std_logic;
    signal parity_int       : std_logic;
    signal half_carry_int   : std_logic;
    signal aux_carry_int    : std_logic;
    signal exception_int    : std_logic;
    signal exception_code_int : std_logic_vector(3 downto 0);
    
    -- Arithmetic operation signals
    signal add_result       : std_logic_vector(32 downto 0);
    signal sub_result       : std_logic_vector(32 downto 0);
    signal mul_result       : std_logic_vector(63 downto 0);
    signal div_quotient     : std_logic_vector(31 downto 0);
    signal div_remainder    : std_logic_vector(31 downto 0);
    signal mac_result       : std_logic_vector(63 downto 0);
    
    -- Advanced arithmetic signals
    signal abs_result       : std_logic_vector(31 downto 0);
    signal neg_result       : std_logic_vector(31 downto 0);
    signal inc_result       : std_logic_vector(31 downto 0);
    signal dec_result       : std_logic_vector(31 downto 0);
    signal min_result       : std_logic_vector(31 downto 0);
    signal max_result       : std_logic_vector(31 downto 0);
    
    -- Bit manipulation signals
    signal clz_result       : std_logic_vector(31 downto 0);
    signal ctz_result       : std_logic_vector(31 downto 0);
    signal popcnt_result    : std_logic_vector(31 downto 0);
    signal rev_result       : std_logic_vector(31 downto 0);
    signal bswap_result     : std_logic_vector(31 downto 0);
    
    -- Shift operation signals
    signal shift_amt        : integer range 0 to 31;
    signal sll_result       : std_logic_vector(31 downto 0);
    signal srl_result       : std_logic_vector(31 downto 0);
    signal sra_result       : std_logic_vector(31 downto 0);
    signal rol_result       : std_logic_vector(31 downto 0);
    signal ror_result       : std_logic_vector(31 downto 0);
    
    -- SIMD operation signals
    signal simd16_add_result : std_logic_vector(31 downto 0);
    signal simd16_sub_result : std_logic_vector(31 downto 0);
    signal simd16_mul_result : std_logic_vector(31 downto 0);
    signal simd8_add_result  : std_logic_vector(31 downto 0);
    signal simd8_sub_result  : std_logic_vector(31 downto 0);
    signal simd8_mul_result  : std_logic_vector(31 downto 0);
    
    -- Saturating arithmetic signals
    signal sat_add_result   : std_logic_vector(31 downto 0);
    signal sat_sub_result   : std_logic_vector(31 downto 0);
    signal sat_mul_result   : std_logic_vector(31 downto 0);
    
    -- Floating-point signals (if enabled)
    signal float_add_result : std_logic_vector(31 downto 0);
    signal float_sub_result : std_logic_vector(31 downto 0);
    signal float_mul_result : std_logic_vector(31 downto 0);
    signal float_div_result : std_logic_vector(31 downto 0);
    signal float_exception  : std_logic;
    
    -- BCD arithmetic signals
    signal bcd_add_result   : std_logic_vector(31 downto 0);
    signal bcd_sub_result   : std_logic_vector(31 downto 0);
    signal bcd_carry        : std_logic;
    
    -- Carry-lookahead signals
    signal carry_generate   : std_logic_vector(31 downto 0);
    signal carry_propagate  : std_logic_vector(31 downto 0);
    signal carry_chain      : std_logic_vector(32 downto 0);
    
    -- Pipeline registers (if enabled)
    type pipeline_array is array (0 to PIPELINE_STAGES) of std_logic_vector(31 downto 0);
    signal pipeline_data    : pipeline_array;
    signal pipeline_valid   : std_logic_vector(PIPELINE_STAGES downto 0);
    signal pipeline_flags   : array (0 to PIPELINE_STAGES) of std_logic_vector(15 downto 0);
    
begin
    -- Carry-lookahead implementation for fast 32-bit addition
    carry_lookahead_gen: for i in 0 to 31 generate
        carry_generate(i) <= a(i) and b(i);
        carry_propagate(i) <= a(i) xor b(i);
    end generate;
    
    -- Carry chain calculation
    carry_chain(0) <= carry_in;
    carry_chain_gen: for i in 0 to 31 generate
        carry_chain(i+1) <= carry_generate(i) or (carry_propagate(i) and carry_chain(i));
    end generate;
    
    -- 32-bit Arithmetic operations with optimized carry handling
    add_result <= std_logic_vector(unsigned('0' & a) + unsigned('0' & b) + unsigned'("" & carry_in));
    sub_result <= std_logic_vector(unsigned('0' & a) - unsigned('0' & b) - unsigned'("" & (not carry_in)));
    
    -- Advanced arithmetic operations
    abs_result <= std_logic_vector(abs(signed(a)));
    neg_result <= std_logic_vector(-signed(a));
    inc_result <= std_logic_vector(unsigned(a) + 1);
    dec_result <= std_logic_vector(unsigned(a) - 1);
    
    -- Min/Max operations
    min_result <= a when signed(a) < signed(b) else b;
    max_result <= a when signed(a) > signed(b) else b;
    
    -- 32x32 Multiplication with DSP optimization
    mul_gen: if ENABLE_MUL generate
        dsp_mul_gen: if DSP_OPTIMIZATION generate
            -- Use FPGA DSP blocks for efficient multiplication
            mul_result <= std_logic_vector(unsigned(a) * unsigned(b));
        end generate;
        
        logic_mul_gen: if not DSP_OPTIMIZATION generate
            -- Use logic-based multiplication for resource-constrained designs
            multiplication_process: process(a, b)
                variable temp_result : unsigned(63 downto 0);
                variable multiplicand : unsigned(31 downto 0);
                variable multiplier : unsigned(31 downto 0);
            begin
                multiplicand := unsigned(a);
                multiplier := unsigned(b);
                temp_result := (others => '0');
                
                for i in 0 to 31 loop
                    if multiplier(i) = '1' then
                        temp_result := temp_result + (multiplicand sll i);
                    end if;
                end loop;
                
                mul_result <= std_logic_vector(temp_result);
            end process;
        end generate;
    end generate;
    
    -- MAC operation (if enabled)
    mac_gen: if ENABLE_MAC generate
        mac_result <= std_logic_vector(unsigned(mul_result) + unsigned(accumulator));
    end generate;
    
    -- Division (if enabled)
    div_gen: if ENABLE_DIV generate
        division_process: process(a, b)
            variable dividend : unsigned(31 downto 0);
            variable divisor : unsigned(31 downto 0);
            variable quotient : unsigned(31 downto 0);
            variable remainder : unsigned(31 downto 0);
            variable temp : unsigned(63 downto 0);
        begin
            dividend := unsigned(a);
            divisor := unsigned(b);
            quotient := (others => '0');
            remainder := (others => '0');
            
            if divisor /= 0 then
                -- Non-restoring division algorithm
                temp := (others => '0');
                temp(31 downto 0) := dividend;
                
                for i in 31 downto 0 loop
                    temp := temp sll 1;
                    if temp(63 downto 32) >= divisor then
                        temp(63 downto 32) := temp(63 downto 32) - divisor;
                        quotient(i) := '1';
                    end if;
                end loop;
                
                remainder := temp(63 downto 32);
                div_quotient <= std_logic_vector(quotient);
                div_remainder <= std_logic_vector(remainder);
            else
                -- Division by zero
                div_quotient <= (others => '1');  -- Error condition
                div_remainder <= (others => '0');
            end if;
        end process;
    end generate;
    
    -- Bit manipulation operations
    bit_manipulation: process(a)
        variable temp : std_logic_vector(31 downto 0);
        variable count : integer;
    begin
        -- Count Leading Zeros
        count := 0;
        for i in 31 downto 0 loop
            if a(i) = '0' then
                count := count + 1;
            else
                exit;
            end if;
        end loop;
        clz_result <= std_logic_vector(to_unsigned(count, 32));
        
        -- Count Trailing Zeros
        count := 0;
        for i in 0 to 31 loop
            if a(i) = '0' then
                count := count + 1;
            else
                exit;
            end if;
        end loop;
        ctz_result <= std_logic_vector(to_unsigned(count, 32));
        
        -- Population Count (number of 1s)
        count := 0;
        for i in 0 to 31 loop
            if a(i) = '1' then
                count := count + 1;
            end if;
        end loop;
        popcnt_result <= std_logic_vector(to_unsigned(count, 32));
        
        -- Bit Reverse
        for i in 0 to 31 loop
            temp(i) := a(31-i);
        end loop;
        rev_result <= temp;
        
        -- Byte Swap
        bswap_result <= a(7 downto 0) & a(15 downto 8) & a(23 downto 16) & a(31 downto 24);
    end process;
    
    -- Saturating arithmetic (if enabled)
    saturate_gen: if ENABLE_SATURATE generate
        saturating_arithmetic: process(a, b, carry_in, add_result, sub_result, mul_result)
            constant MAX_POS : signed(31 downto 0) := x"7FFFFFFF";
            constant MAX_NEG : signed(31 downto 0) := x"80000000";
        begin
            -- Saturating addition
            if add_result(32) = '1' then  -- Overflow
                if signed(a) >= 0 and signed(b) >= 0 then
                    sat_add_result <= std_logic_vector(MAX_POS);  -- Positive saturation
                else
                    sat_add_result <= std_logic_vector(MAX_NEG);  -- Negative saturation
                end if;
            else
                sat_add_result <= add_result(31 downto 0);
            end if;
            
            -- Saturating subtraction
            if sub_result(32) = '1' then  -- Underflow
                if signed(a) >= 0 and signed(b) < 0 then
                    sat_sub_result <= std_logic_vector(MAX_POS);  -- Positive saturation
                else
                    sat_sub_result <= std_logic_vector(MAX_NEG);  -- Negative saturation
                end if;
            else
                sat_sub_result <= sub_result(31 downto 0);
            end if;
            
            -- Saturating multiplication
            if mul_result(63 downto 31) /= (32 downto 0 => mul_result(31)) then
                if signed(mul_result(63 downto 32)) > 0 then
                    sat_mul_result <= std_logic_vector(MAX_POS);
                else
                    sat_mul_result <= std_logic_vector(MAX_NEG);
                end if;
            else
                sat_mul_result <= mul_result(31 downto 0);
            end if;
        end process;
    end generate;
    
    -- SIMD operations (if enabled)
    simd_gen: if ENABLE_SIMD generate
        simd_operations: process(a, b, mode)
            -- 16-bit SIMD variables
            variable a_16_lo, a_16_hi, b_16_lo, b_16_hi : unsigned(15 downto 0);
            variable add_16_lo, add_16_hi : unsigned(16 downto 0);
            variable sub_16_lo, sub_16_hi : unsigned(16 downto 0);
            variable mul_16_lo, mul_16_hi : unsigned(31 downto 0);
            
            -- 8-bit SIMD variables
            variable a_8, b_8 : array(0 to 3) of unsigned(7 downto 0);
            variable add_8, sub_8 : array(0 to 3) of unsigned(8 downto 0);
            variable mul_8 : array(0 to 3) of unsigned(15 downto 0);
        begin
            if mode = MODE_SIMD_16 then
                -- Split 32-bit operands into 16-bit parts
                a_16_lo := unsigned(a(15 downto 0));
                a_16_hi := unsigned(a(31 downto 16));
                b_16_lo := unsigned(b(15 downto 0));
                b_16_hi := unsigned(b(31 downto 16));
                
                -- Parallel 16-bit operations
                add_16_lo := ('0' & a_16_lo) + ('0' & b_16_lo);
                add_16_hi := ('0' & a_16_hi) + ('0' & b_16_hi);
                sub_16_lo := ('0' & a_16_lo) - ('0' & b_16_lo);
                sub_16_hi := ('0' & a_16_hi) - ('0' & b_16_hi);
                mul_16_lo := a_16_lo * b_16_lo;
                mul_16_hi := a_16_hi * b_16_hi;
                
                -- Pack results back to 32-bit
                simd16_add_result <= std_logic_vector(add_16_hi(15 downto 0)) & std_logic_vector(add_16_lo(15 downto 0));
                simd16_sub_result <= std_logic_vector(sub_16_hi(15 downto 0)) & std_logic_vector(sub_16_lo(15 downto 0));
                simd16_mul_result <= std_logic_vector(mul_16_hi(15 downto 0)) & std_logic_vector(mul_16_lo(15 downto 0));
                
            elsif mode = MODE_SIMD_8 then
                -- Split 32-bit operands into 8-bit parts
                for i in 0 to 3 loop
                    a_8(i) := unsigned(a(8*i+7 downto 8*i));
                    b_8(i) := unsigned(b(8*i+7 downto 8*i));
                    
                    -- Parallel 8-bit operations
                    add_8(i) := ('0' & a_8(i)) + ('0' & b_8(i));
                    sub_8(i) := ('0' & a_8(i)) - ('0' & b_8(i));
                    mul_8(i) := a_8(i) * b_8(i);
                end loop;
                
                -- Pack results back to 32-bit
                simd8_add_result <= std_logic_vector(add_8(3)(7 downto 0)) & std_logic_vector(add_8(2)(7 downto 0)) &
                                   std_logic_vector(add_8(1)(7 downto 0)) & std_logic_vector(add_8(0)(7 downto 0));
                simd8_sub_result <= std_logic_vector(sub_8(3)(7 downto 0)) & std_logic_vector(sub_8(2)(7 downto 0)) &
                                   std_logic_vector(sub_8(1)(7 downto 0)) & std_logic_vector(sub_8(0)(7 downto 0));
                simd8_mul_result <= std_logic_vector(mul_8(3)(7 downto 0)) & std_logic_vector(mul_8(2)(7 downto 0)) &
                                   std_logic_vector(mul_8(1)(7 downto 0)) & std_logic_vector(mul_8(0)(7 downto 0));
            end if;
        end process;
    end generate;
    
    -- BCD arithmetic (if enabled)
    bcd_gen: if mode = MODE_BCD generate
        bcd_arithmetic: process(a, b, carry_in)
            variable bcd_a, bcd_b, bcd_result : unsigned(31 downto 0);
            variable digit_sum : unsigned(7 downto 0);
            variable bcd_carry_temp : std_logic;
        begin
            bcd_a := unsigned(a);
            bcd_b := unsigned(b);
            bcd_result := (others => '0');
            bcd_carry_temp := carry_in;
            
            -- BCD addition (8 digits, 4 bits each)
            for i in 0 to 7 loop
                digit_sum := ("0000" & bcd_a(4*i+3 downto 4*i)) + 
                            ("0000" & bcd_b(4*i+3 downto 4*i)) + 
                            ("0000000" & bcd_carry_temp);
                
                if digit_sum > 9 then
                    digit_sum := digit_sum + 6;  -- BCD correction
                    bcd_carry_temp := '1';
                else
                    bcd_carry_temp := '0';
                end if;
                
                bcd_result(4*i+3 downto 4*i) := digit_sum(3 downto 0);
            end loop;
            
            bcd_add_result <= std_logic_vector(bcd_result);
            bcd_carry <= bcd_carry_temp;
        end process;
    end generate;
    
    -- Shift amount extraction (from shift_amount input or lower 5 bits of operand b)
    shift_amt <= to_integer(unsigned(shift_amount)) when shift_amount /= "00000" else
                 to_integer(unsigned(b(4 downto 0)));
    
    -- Barrel shifter implementation for all shift operations
    barrel_shifter: process(a, shift_amt)
        variable temp : std_logic_vector(31 downto 0);
    begin
        temp := a;
        
        -- Shift Left Logical
        sll_result <= std_logic_vector(shift_left(unsigned(temp), shift_amt));
        
        -- Shift Right Logical
        srl_result <= std_logic_vector(shift_right(unsigned(temp), shift_amt));
        
        -- Shift Right Arithmetic
        sra_result <= std_logic_vector(shift_right(signed(temp), shift_amt));
        
        -- Rotate Left
        rol_result <= std_logic_vector(rotate_left(unsigned(temp), shift_amt));
        
        -- Rotate Right
        ror_result <= std_logic_vector(rotate_right(unsigned(temp), shift_amt));
    end process;
    
    -- Floating-point operations (if enabled)
    float_gen: if ENABLE_FLOAT generate
        -- IEEE 754 single-precision floating-point operations
        floating_point: process(a, b, alu_op)
            -- IEEE 754 components
            variable sign_a, sign_b, sign_result : std_logic;
            variable exp_a, exp_b, exp_result : unsigned(7 downto 0);
            variable mant_a, mant_b, mant_result : unsigned(22 downto 0);
            variable temp_result : std_logic_vector(31 downto 0);
        begin
            -- Extract IEEE 754 components
            sign_a := a(31);
            exp_a := unsigned(a(30 downto 23));
            mant_a := unsigned(a(22 downto 0));
            
            sign_b := b(31);
            exp_b := unsigned(b(30 downto 23));
            mant_b := unsigned(b(22 downto 0));
            
            -- Simplified floating-point operations (full implementation would be much larger)
            case alu_op is
                when ALU_FADD =>
                    -- Floating-point addition (simplified)
                    temp_result := std_logic_vector(unsigned(a) + unsigned(b));  -- Placeholder
                    float_add_result <= temp_result;
                    
                when ALU_FSUB =>
                    -- Floating-point subtraction (simplified)
                    temp_result := std_logic_vector(unsigned(a) - unsigned(b));  -- Placeholder
                    float_sub_result <= temp_result;
                    
                when ALU_FMUL =>
                    -- Floating-point multiplication (simplified)
                    temp_result := std_logic_vector(unsigned(a(15 downto 0)) * unsigned(b(15 downto 0)));  -- Placeholder
                    float_mul_result <= temp_result;
                    
                when ALU_FDIV =>
                    -- Floating-point division (simplified)
                    if unsigned(b) /= 0 then
                        temp_result := std_logic_vector(unsigned(a) / unsigned(b));  -- Placeholder
                    else
                        temp_result := x"7FC00000";  -- NaN
                        float_exception <= '1';
                    end if;
                    float_div_result <= temp_result;
                    
                when others =>
                    float_add_result <= (others => '0');
                    float_sub_result <= (others => '0');
                    float_mul_result <= (others => '0');
                    float_div_result <= (others => '0');
                    float_exception <= '0';
            end case;
        end process;
    end generate;
    
    -- Main 32-bit ALU operation selection
    alu_operation: process(alu_op, mode, precision, a, b, carry_in, add_result, sub_result, 
                          mul_result, div_quotient, div_remainder, mac_result, abs_result, 
                          neg_result, inc_result, dec_result, min_result, max_result,
                          clz_result, ctz_result, popcnt_result, rev_result, bswap_result,
                          sll_result, srl_result, sra_result, rol_result, ror_result,
                          sat_add_result, sat_sub_result, sat_mul_result,
                          simd16_add_result, simd16_sub_result, simd16_mul_result,
                          simd8_add_result, simd8_sub_result, simd8_mul_result,
                          bcd_add_result, bcd_sub_result,
                          float_add_result, float_sub_result, float_mul_result, float_div_result,
                          accumulator)
    begin
        result_int <= (others => '0');
        result_hi_int <= (others => '0');
        result_ext <= (others => '0');
        acc_out_int <= (others => '0');
        exception_int <= '0';
        exception_code_int <= (others => '0');
        
        case alu_op is
            when ALU_ADD =>
                case mode is
                    when MODE_NORMAL =>
                        result_int <= add_result(31 downto 0);
                        result_ext <= add_result;
                    when MODE_SATURATE =>
                        if ENABLE_SATURATE then
                            result_int <= sat_add_result;
                            result_ext <= '0' & sat_add_result;
                        end if;
                    when MODE_SIMD_16 =>
                        if ENABLE_SIMD then
                            result_int <= simd16_add_result;
                            result_ext <= '0' & simd16_add_result;
                        end if;
                    when MODE_SIMD_8 =>
                        if ENABLE_SIMD then
                            result_int <= simd8_add_result;
                            result_ext <= '0' & simd8_add_result;
                        end if;
                    when MODE_BCD =>
                        result_int <= bcd_add_result;
                        result_ext <= '0' & bcd_add_result;
                    when others =>
                        result_int <= add_result(31 downto 0);
                        result_ext <= add_result;
                end case;
                
            when ALU_SUB =>
                case mode is
                    when MODE_NORMAL =>
                        result_int <= sub_result(31 downto 0);
                        result_ext <= sub_result;
                    when MODE_SATURATE =>
                        if ENABLE_SATURATE then
                            result_int <= sat_sub_result;
                            result_ext <= '0' & sat_sub_result;
                        end if;
                    when MODE_SIMD_16 =>
                        if ENABLE_SIMD then
                            result_int <= simd16_sub_result;
                            result_ext <= '0' & simd16_sub_result;
                        end if;
                    when MODE_SIMD_8 =>
                        if ENABLE_SIMD then
                            result_int <= simd8_sub_result;
                            result_ext <= '0' & simd8_sub_result;
                        end if;
                    when MODE_BCD =>
                        result_int <= bcd_sub_result;
                        result_ext <= '0' & bcd_sub_result;
                    when others =>
                        result_int <= sub_result(31 downto 0);
                        result_ext <= sub_result;
                end case;
                
            when ALU_AND =>
                result_int <= a and b;
                result_ext <= '0' & (a and b);
                
            when ALU_OR =>
                result_int <= a or b;
                result_ext <= '0' & (a or b);
                
            when ALU_XOR =>
                result_int <= a xor b;
                result_ext <= '0' & (a xor b);
                
            when ALU_NOT =>
                result_int <= not a;
                result_ext <= '0' & (not a);
                
            when ALU_SLL =>
                result_int <= sll_result;
                result_ext <= '0' & sll_result;
                
            when ALU_SRL =>
                result_int <= srl_result;
                result_ext <= '0' & srl_result;
                
            when ALU_SRA =>
                result_int <= sra_result;
                result_ext <= '0' & sra_result;
                
            when ALU_ROL =>
                result_int <= rol_result;
                result_ext <= '0' & rol_result;
                
            when ALU_ROR =>
                result_int <= ror_result;
                result_ext <= '0' & ror_result;
                
            when ALU_CMP =>
                -- Comparison: result is 1 if a < b, 0 otherwise
                if unsigned(a) < unsigned(b) then
                    result_int <= x"00000001";
                else
                    result_int <= x"00000000";
                end if;
                result_ext <= '0' & result_int;
                
            when ALU_MUL =>
                if ENABLE_MUL then
                    case mode is
                        when MODE_SATURATE =>
                            if ENABLE_SATURATE then
                                result_int <= sat_mul_result;
                                result_hi_int <= (others => '0');
                            end if;
                        when MODE_SIMD_16 =>
                            if ENABLE_SIMD then
                                result_int <= simd16_mul_result;
                                result_hi_int <= (others => '0');
                            end if;
                        when MODE_SIMD_8 =>
                            if ENABLE_SIMD then
                                result_int <= simd8_mul_result;
                                result_hi_int <= (others => '0');
                            end if;
                        when others =>
                            result_int <= mul_result(31 downto 0);
                            result_hi_int <= mul_result(63 downto 32);
                    end case;
                    result_ext <= '0' & result_int;
                end if;
                
            when ALU_DIV =>
                if ENABLE_DIV then
                    if unsigned(b) = 0 then
                        exception_int <= '1';
                        exception_code_int <= x"1";  -- Division by zero
                        result_int <= (others => '1');
                        result_hi_int <= (others => '0');
                    else
                        result_int <= div_quotient;
                        result_hi_int <= div_remainder;
                    end if;
                    result_ext <= '0' & result_int;
                end if;
                
            when ALU_MAC =>
                if ENABLE_MAC then
                    result_int <= mac_result(31 downto 0);
                    result_hi_int <= mac_result(63 downto 32);
                    acc_out_int <= mac_result;
                    result_ext <= '0' & mac_result(31 downto 0);
                end if;
                
            when ALU_PASS_A =>
                result_int <= a;
                result_ext <= '0' & a;
                
            when ALU_PASS_B =>
                result_int <= b;
                result_ext <= '0' & b;
                
            when ALU_ABS =>
                result_int <= abs_result;
                result_ext <= '0' & abs_result;
                
            when ALU_NEG =>
                result_int <= neg_result;
                result_ext <= '0' & neg_result;
                
            when ALU_INC =>
                result_int <= inc_result;
                result_ext <= '0' & inc_result;
                
            when ALU_DEC =>
                result_int <= dec_result;
                result_ext <= '0' & dec_result;
                
            when ALU_MIN =>
                result_int <= min_result;
                result_ext <= '0' & min_result;
                
            when ALU_MAX =>
                result_int <= max_result;
                result_ext <= '0' & max_result;
                
            when ALU_CLZ =>
                result_int <= clz_result;
                result_ext <= '0' & clz_result;
                
            when ALU_CTZ =>
                result_int <= ctz_result;
                result_ext <= '0' & ctz_result;
                
            when ALU_POPCNT =>
                result_int <= popcnt_result;
                result_ext <= '0' & popcnt_result;
                
            when ALU_REV =>
                result_int <= rev_result;
                result_ext <= '0' & rev_result;
                
            when ALU_BSWAP =>
                result_int <= bswap_result;
                result_ext <= '0' & bswap_result;
                
            when ALU_FADD =>
                if ENABLE_FLOAT then
                    result_int <= float_add_result;
                    result_ext <= '0' & float_add_result;
                end if;
                
            when ALU_FSUB =>
                if ENABLE_FLOAT then
                    result_int <= float_sub_result;
                    result_ext <= '0' & float_sub_result;
                end if;
                
            when ALU_FMUL =>
                if ENABLE_FLOAT then
                    result_int <= float_mul_result;
                    result_ext <= '0' & float_mul_result;
                end if;
                
            when ALU_FDIV =>
                if ENABLE_FLOAT then
                    result_int <= float_div_result;
                    result_ext <= '0' & float_div_result;
                end if;
                
            when others =>
                result_int <= (others => '0');
                result_ext <= (others => '0');
                exception_int <= '1';
                exception_code_int <= x"F";  -- Invalid operation
        end case;
    end process;
    
    -- 32-bit Flag generation with comprehensive status indication
    flag_generation: process(result_int, result_ext, a, b, alu_op, mode)
        variable parity_temp : std_logic;
        variable half_carry_temp : std_logic;
        variable aux_carry_temp : std_logic;
    begin
        -- Zero flag: result is zero
        if unsigned(result_int) = 0 then
            zero_int <= '1';
        else
            zero_int <= '0';
        end if;
        
        -- Carry flag: arithmetic overflow or carry out
        carry_int <= result_ext(32);
        
        -- Overflow flag: signed arithmetic overflow
        case alu_op is
            when ALU_ADD =>
                if (a(31) = b(31)) and (result_int(31) /= a(31)) then
                    overflow_int <= '1';
                else
                    overflow_int <= '0';
                end if;
            when ALU_SUB =>
                if (a(31) /= b(31)) and (result_int(31) /= a(31)) then
                    overflow_int <= '1';
                else
                    overflow_int <= '0';
                end if;
            when others =>
                overflow_int <= '0';
        end case;
        
        -- Negative flag: result is negative (MSB set)
        negative_int <= result_int(31);
        
        -- Parity flag: even parity of result
        parity_temp := '0';
        for i in 0 to 31 loop
            parity_temp := parity_temp xor result_int(i);
        end loop;
        parity_int <= not parity_temp;  -- Even parity
        
        -- Half carry flag: carry from bit 3 to bit 4 (nibble overflow)
        case alu_op is
            when ALU_ADD =>
                half_carry_temp := (a(3) and b(3)) or 
                                  ((a(3) xor b(3)) and not result_int(3));
            when ALU_SUB =>
                half_carry_temp := (not a(3) and b(3)) or 
                                  ((not a(3) xor b(3)) and result_int(3));
            when others =>
                half_carry_temp := '0';
        end case;
        half_carry_int <= half_carry_temp;
        
        -- Auxiliary carry flag: carry from bit 7 to bit 8 (byte overflow)
        case alu_op is
            when ALU_ADD =>
                aux_carry_temp := (a(7) and b(7)) or 
                                 ((a(7) xor b(7)) and not result_int(7));
            when ALU_SUB =>
                aux_carry_temp := (not a(7) and b(7)) or 
                                 ((not a(7) xor b(7)) and result_int(7));
            when others =>
                aux_carry_temp := '0';
        end case;
        aux_carry_int <= aux_carry_temp;
    end process;
    
    -- Pipeline implementation (if enabled)
    pipeline_gen: if PIPELINE_STAGES > 0 generate
        pipeline_process: process(clk, reset)
        begin
            if reset = '1' then
                for i in 0 to PIPELINE_STAGES loop
                    pipeline_data(i) <= (others => '0');
                    pipeline_valid(i) <= '0';
                end loop;
            elsif rising_edge(clk) then
                if enable = '1' then
                    -- Shift pipeline data
                    pipeline_data(0) <= result_int;
                    pipeline_valid(0) <= '1';
                    
                    for i in 1 to PIPELINE_STAGES loop
                        pipeline_data(i) <= pipeline_data(i-1);
                        pipeline_valid(i) <= pipeline_valid(i-1);
                    end loop;
                end if;
            end if;
        end process;
        
        -- Pipeline outputs
        result <= pipeline_data(PIPELINE_STAGES);
        valid <= pipeline_valid(PIPELINE_STAGES);
        ready <= '1';  -- Always ready for pipelined operation
    end generate;
    
    -- Combinational outputs (if not pipelined)
    combinational_gen: if PIPELINE_STAGES = 0 generate
        result <= result_int;
        valid <= enable;
        ready <= '1';
    end generate;
    
    -- Output assignments
    result_hi <= result_hi_int;
    acc_out <= acc_out_int;
    zero <= zero_int;
    carry <= carry_int;
    overflow <= overflow_int;
    negative <= negative_int;
    parity <= parity_int;
    half_carry <= half_carry_int;
    auxiliary_carry <= aux_carry_int;
    exception <= exception_int;
    exception_code <= exception_code_int;
    
    -- Extended flag output (16-bit status register)
    flags <= exception_code_int & "000" & exception_int & aux_carry_int & half_carry_int & 
             parity_int & negative_int & overflow_int & carry_int & zero_int & "0000";
    
    -- Processor condition codes (8-bit)
    condition_codes <= exception_int & aux_carry_int & half_carry_int & parity_int & 
                      negative_int & overflow_int & carry_int & zero_int;

end architecture behavioral;

-- ============================================================================
-- VERIFICATION AND EXTENSION NOTES:
-- ============================================================================
-- Remember to:
-- 1. Thoroughly test all 32 operations with comprehensive test vectors
-- 2. Verify flag generation for all boundary conditions and edge cases
-- 3. Test carry propagation for multi-word arithmetic operations
-- 4. Validate timing closure for target frequency requirements
-- 5. Optimize resource utilization for specific FPGA architectures
-- 6. Test power consumption across all operational modes
-- 7. Verify thermal characteristics under continuous operation
-- 8. Implement comprehensive error detection and recovery mechanisms
-- 9. Add performance monitoring and profiling capabilities
-- 10. Consider security implications for cryptographic applications