-- ============================================================================
-- 256-BIT ARITHMETIC LOGIC UNIT (ALU) - COMPREHENSIVE IMPLEMENTATION
-- ============================================================================
-- 
-- PROJECT OVERVIEW:
-- This file contains a comprehensive 256-bit ALU implementation designed for
-- high-performance computing applications, cryptographic processing, and
-- advanced digital signal processing. The ALU supports a wide range of
-- operations including arithmetic, logical, shift, rotate, bit manipulation,
-- SIMD, vector, floating-point, and cryptographic operations.
--
-- LEARNING OBJECTIVES:
-- By studying and implementing this 256-bit ALU, you will learn:
-- 1. Advanced VHDL design techniques for large-scale arithmetic units
-- 2. High-performance computing ALU architectures
-- 3. SIMD (Single Instruction, Multiple Data) processing concepts
-- 4. Vector processing and parallel computation
-- 5. Cryptographic hardware acceleration principles
-- 6. Pipeline design for high-frequency operation
-- 7. Exception handling and security features
-- 8. Resource optimization for large bit-width operations
-- 9. Advanced flag generation and status reporting
-- 10. Configurable ALU design using generics
--
-- STEP-BY-STEP IMPLEMENTATION GUIDE:
--
-- Step 1: Library Declarations
-- - Include necessary VHDL libraries
-- - Import required packages for arithmetic and logic operations
--
-- Step 2: Entity Declaration
-- - Define the ALU entity with comprehensive port specifications
-- - Include data ports (256-bit inputs/outputs)
-- - Add control ports (operation selection, mode control)
-- - Define status ports (flags, exceptions, security)
-- - Include system ports (clock, reset, enable)
-- - Add extended interfaces for advanced features
--
-- Step 3: Architecture Implementation
-- - Implement the behavioral architecture
-- - Define internal signals and constants
-- - Implement arithmetic operations (add, subtract, multiply, divide)
-- - Add logical operations (AND, OR, XOR, NOT, etc.)
-- - Include shift and rotate operations
-- - Implement bit manipulation functions
-- - Add SIMD operations for parallel processing
-- - Include vector operations for multimedia
-- - Implement floating-point operations (simplified)
-- - Add cryptographic operation placeholders
-- - Implement comprehensive flag generation
-- - Add pipeline support for high-frequency operation
-- - Include exception handling and security features
--
-- 256-BIT ALU OPERATION PRINCIPLES:
--
-- Arithmetic Operations:
-- - 256-bit addition with carry propagation
-- - 256-bit subtraction with borrow handling
-- - 256-bit multiplication (512-bit result)
-- - 256-bit division with quotient and remainder
-- - Saturated arithmetic for overflow protection
-- - BCD arithmetic for decimal operations
-- - Multi-precision arithmetic support
--
-- Logical Operations:
-- - Bitwise AND, OR, XOR, NOT operations
-- - Advanced logical operations (NAND, NOR, ANDN, ORN)
-- - Bit manipulation (set, clear, toggle, test)
-- - Population count and leading/trailing zero count
-- - Bit reversal and byte swapping
--
-- Shift and Rotate Operations:
-- - Logical shift left/right with configurable amounts
-- - Arithmetic shift right with sign extension
-- - Rotate left/right with wrap-around
-- - Barrel shifter implementation for single-cycle operation
-- - Multi-bit shift operations
--
-- SIMD Operations:
-- - 2x128-bit parallel operations
-- - 4x64-bit parallel operations
-- - 8x32-bit parallel operations
-- - 16x16-bit parallel operations
-- - 32x8-bit parallel operations
-- - Packed arithmetic and logical operations
--
-- Vector Operations:
-- - Element-wise vector arithmetic
-- - Dot product computation
-- - Vector sum and average
-- - Cross product (for 3D vectors)
-- - Vector magnitude calculation
--
-- Cryptographic Operations:
-- - AES encryption/decryption support
-- - SHA hash function acceleration
-- - RSA modular arithmetic
-- - Elliptic curve operations
-- - Random number generation
-- - Key expansion and scheduling
--
-- ARCHITECTURE OPTIONS:
-- 1. Combinational Architecture: All operations complete in one clock cycle
-- 2. Pipelined Architecture: Operations spread across multiple pipeline stages
-- 3. Hybrid Architecture: Simple ops combinational, complex ops pipelined
-- 4. Multi-cycle Architecture: Complex operations take multiple cycles
--
-- IMPLEMENTATION CONSIDERATIONS:
-- - Resource utilization optimization for 256-bit operations
-- - Timing closure for high-frequency operation
-- - Power consumption optimization
-- - Area optimization techniques
-- - Pipeline balancing and hazard handling
-- - Exception handling and error recovery
-- - Security features and side-channel protection
-- - Testability and debugging support
--
-- ADVANCED FEATURES:
-- - Configurable operation enables through generics
-- - Multiple operation modes (normal, saturate, SIMD, vector)
-- - Comprehensive flag generation and status reporting
-- - Exception handling with detailed error codes
-- - Security violation detection
-- - Performance monitoring and profiling
-- - Debug and trace capabilities
-- - Power management features
--
-- APPLICATIONS:
-- - High-performance computing systems
-- - Cryptographic processors and security modules
-- - Digital signal processing accelerators
-- - Graphics and multimedia processing units
-- - Scientific computing applications
-- - Machine learning and AI accelerators
-- - Network processing units
-- - Custom processor designs
--
-- TESTING STRATEGY:
-- 1. Unit Testing: Test each operation individually
-- 2. Integration Testing: Test operation combinations
-- 3. Corner Case Testing: Test edge values and overflow conditions
-- 4. Performance Testing: Measure timing and resource utilization
-- 5. Security Testing: Verify security features and protections
-- 6. Stress Testing: Extended operation under various conditions
-- 7. Formal Verification: Mathematical proof of correctness
-- 8. Hardware-in-the-Loop Testing: Real FPGA validation
--
-- RECOMMENDED IMPLEMENTATION APPROACH:
-- 1. Start with basic arithmetic operations (add, subtract)
-- 2. Add logical operations (AND, OR, XOR, NOT)
-- 3. Implement shift and rotate operations
-- 4. Add bit manipulation functions
-- 5. Implement SIMD operations
-- 6. Add vector operations
-- 7. Include floating-point operations
-- 8. Add cryptographic operations
-- 9. Implement comprehensive flag generation
-- 10. Add pipeline support
-- 11. Include exception handling
-- 12. Add security features
-- 13. Optimize for performance and resources
-- 14. Comprehensive testing and validation
--
-- EXTENSION EXERCISES:
-- 1. Add custom instruction support
-- 2. Implement machine learning operations
-- 3. Add DSP-specific operations
-- 4. Implement multi-precision arithmetic
-- 5. Add specialized cryptographic units
-- 6. Implement advanced vector operations
-- 7. Add custom SIMD operations
-- 8. Implement hardware debugging features
-- 9. Add power management capabilities
-- 10. Implement performance monitoring
--
-- COMMON MISTAKES TO AVOID:
-- 1. Not considering timing closure for large bit-widths
-- 2. Inadequate resource optimization
-- 3. Missing edge case handling
-- 4. Insufficient pipeline balancing
-- 5. Inadequate exception handling
-- 6. Missing security considerations
-- 7. Insufficient testing coverage
-- 8. Poor documentation and comments
-- 9. Not considering power consumption
-- 10. Inadequate performance optimization
--
-- DESIGN VERIFICATION CHECKLIST:
-- □ All arithmetic operations produce correct results
-- □ Logical operations work correctly for all input combinations
-- □ Shift and rotate operations handle all shift amounts
-- □ Bit manipulation functions work correctly
-- □ SIMD operations produce correct parallel results
-- □ Vector operations compute correct results
-- □ Flag generation is accurate for all operations
-- □ Exception handling works correctly
-- □ Security features function properly
-- □ Pipeline operates correctly without hazards
-- □ Timing requirements are met
-- □ Resource utilization is optimized
-- □ Power consumption is acceptable
-- □ All test cases pass
-- □ Documentation is complete and accurate
--
-- DIGITAL DESIGN CONTEXT:
-- This 256-bit ALU represents advanced digital design concepts including:
-- - Large-scale arithmetic unit design
-- - High-performance computing architectures
-- - Parallel processing and SIMD concepts
-- - Cryptographic hardware acceleration
-- - Advanced pipeline design
-- - Exception handling and security
-- - Resource and power optimization
-- - Performance optimization techniques
--
-- PHYSICAL IMPLEMENTATION NOTES:
-- - Consider FPGA resource constraints for 256-bit operations
-- - Optimize for target FPGA architecture (LUTs, DSPs, BRAMs)
-- - Plan for timing closure at target frequency
-- - Consider power consumption and thermal management
-- - Plan for testability and debugging access
-- - Consider security and side-channel protection
-- - Optimize for area and performance trade-offs
--
-- ADVANCED CONCEPTS:
-- - Multi-precision arithmetic algorithms
-- - Cryptographic algorithm acceleration
-- - Vector processing architectures
-- - SIMD instruction set design
-- - Pipeline hazard detection and resolution
-- - Exception handling architectures
-- - Security and trust architectures
-- - Performance monitoring and profiling
--
-- SIMULATION AND VERIFICATION NOTES:
-- - Use comprehensive testbenches with all operation modes
-- - Include corner case and edge value testing
-- - Verify SIMD and vector operations thoroughly
-- - Test pipeline functionality and hazard handling
-- - Verify exception handling and security features
-- - Perform timing simulation for target frequency
-- - Analyze resource utilization and power consumption
-- - Use formal verification for critical operations
--
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- ============================================================================
-- ENTITY DECLARATION
-- ============================================================================

entity alu_256bit is
    generic (
        -- Configuration parameters
        DATA_WIDTH      : integer := 256;           -- ALU data width
        ALU_OP_WIDTH    : integer := 8;             -- Operation code width
        MODE_WIDTH      : integer := 4;             -- Operation mode width
        
        -- Feature enables
        ENABLE_MUL      : boolean := true;          -- Enable multiplication
        ENABLE_DIV      : boolean := true;          -- Enable division
        ENABLE_SHIFT    : boolean := true;          -- Enable shift operations
        ENABLE_ROTATE   : boolean := true;          -- Enable rotate operations
        ENABLE_SIMD     : boolean := true;          -- Enable SIMD operations
        ENABLE_VECTOR   : boolean := true;          -- Enable vector operations
        ENABLE_FLOAT    : boolean := true;          -- Enable floating-point
        ENABLE_CRYPTO   : boolean := true;          -- Enable cryptographic ops
        ENABLE_SATURATE : boolean := true;          -- Enable saturated arithmetic
        ENABLE_BCD      : boolean := true;          -- Enable BCD arithmetic
        
        -- Pipeline configuration
        PIPELINE_STAGES : integer := 1              -- Number of pipeline stages
    );
    port (
        -- System signals
        clk             : in  std_logic;            -- Clock
        rst             : in  std_logic;            -- Reset
        enable          : in  std_logic;            -- Enable
        
        -- Data inputs
        a               : in  std_logic_vector(255 downto 0);  -- Operand A
        b               : in  std_logic_vector(255 downto 0);  -- Operand B
        
        -- Control inputs
        alu_op          : in  std_logic_vector(ALU_OP_WIDTH-1 downto 0);    -- Operation
        mode            : in  std_logic_vector(MODE_WIDTH-1 downto 0);      -- Mode
        shift_amount    : in  std_logic_vector(7 downto 0);                 -- Shift amount
        carry_in        : in  std_logic;                                    -- Carry input
        
        -- Data outputs
        result          : out std_logic_vector(255 downto 0);  -- Result
        result_hi       : out std_logic_vector(255 downto 0);  -- High result (for mul/div)
        
        -- Status outputs
        flags           : out std_logic_vector(31 downto 0);   -- Status flags
        extended_flags  : out std_logic_vector(31 downto 0);   -- Extended flags
        valid           : out std_logic;                       -- Result valid
        
        -- Exception handling
        exception       : out std_logic;                       -- Exception occurred
        exception_code  : out std_logic_vector(7 downto 0);    -- Exception code
        security_violation : out std_logic                     -- Security violation
    );
end alu_256bit;

-- ============================================================================
-- ARCHITECTURE IMPLEMENTATION
-- ============================================================================

architecture Behavioral of alu_256bit is

    -- ========================================================================
    -- ALU OPERATION CODES
    -- ========================================================================
    
    -- Basic arithmetic operations
    constant ALU_ADD        : std_logic_vector(7 downto 0) := x"00";
    constant ALU_SUB        : std_logic_vector(7 downto 0) := x"01";
    constant ALU_MUL        : std_logic_vector(7 downto 0) := x"02";
    constant ALU_DIV        : std_logic_vector(7 downto 0) := x"03";
    constant ALU_MOD        : std_logic_vector(7 downto 0) := x"04";
    
    -- Logical operations
    constant ALU_AND        : std_logic_vector(7 downto 0) := x"10";
    constant ALU_OR         : std_logic_vector(7 downto 0) := x"11";
    constant ALU_XOR        : std_logic_vector(7 downto 0) := x"12";
    constant ALU_NOT        : std_logic_vector(7 downto 0) := x"13";
    constant ALU_NAND       : std_logic_vector(7 downto 0) := x"14";
    constant ALU_NOR        : std_logic_vector(7 downto 0) := x"15";
    constant ALU_ANDN       : std_logic_vector(7 downto 0) := x"16";
    constant ALU_ORN        : std_logic_vector(7 downto 0) := x"17";
    
    -- Shift and rotate operations
    constant ALU_SLL        : std_logic_vector(7 downto 0) := x"20";
    constant ALU_SRL        : std_logic_vector(7 downto 0) := x"21";
    constant ALU_SRA        : std_logic_vector(7 downto 0) := x"22";
    constant ALU_ROL        : std_logic_vector(7 downto 0) := x"23";
    constant ALU_ROR        : std_logic_vector(7 downto 0) := x"24";
    
    -- Bit manipulation operations
    constant ALU_CLZ        : std_logic_vector(7 downto 0) := x"30";
    constant ALU_CTZ        : std_logic_vector(7 downto 0) := x"31";
    constant ALU_POPCNT     : std_logic_vector(7 downto 0) := x"32";
    constant ALU_REV        : std_logic_vector(7 downto 0) := x"33";
    constant ALU_BSWAP      : std_logic_vector(7 downto 0) := x"34";
    constant ALU_BITSET     : std_logic_vector(7 downto 0) := x"35";
    constant ALU_BITCLR     : std_logic_vector(7 downto 0) := x"36";
    constant ALU_BITTOG     : std_logic_vector(7 downto 0) := x"37";
    constant ALU_BITTEST    : std_logic_vector(7 downto 0) := x"38";
    
    -- Comparison operations
    constant ALU_CMP        : std_logic_vector(7 downto 0) := x"40";
    constant ALU_CMPU       : std_logic_vector(7 downto 0) := x"41";
    constant ALU_MIN        : std_logic_vector(7 downto 0) := x"42";
    constant ALU_MAX        : std_logic_vector(7 downto 0) := x"43";
    constant ALU_MINU       : std_logic_vector(7 downto 0) := x"44";
    constant ALU_MAXU       : std_logic_vector(7 downto 0) := x"45";
    
    -- Data movement operations
    constant ALU_PASS_A     : std_logic_vector(7 downto 0) := x"50";
    constant ALU_PASS_B     : std_logic_vector(7 downto 0) := x"51";
    constant ALU_SWAP       : std_logic_vector(7 downto 0) := x"52";
    constant ALU_MERGE      : std_logic_vector(7 downto 0) := x"53";
    constant ALU_EXTRACT    : std_logic_vector(7 downto 0) := x"54";
    
    -- Advanced arithmetic
    constant ALU_ABS        : std_logic_vector(7 downto 0) := x"60";
    constant ALU_NEG        : std_logic_vector(7 downto 0) := x"61";
    constant ALU_INC        : std_logic_vector(7 downto 0) := x"62";
    constant ALU_DEC        : std_logic_vector(7 downto 0) := x"63";
    constant ALU_SQRT       : std_logic_vector(7 downto 0) := x"64";
    constant ALU_SQUARE     : std_logic_vector(7 downto 0) := x"65";
    
    -- SIMD operations
    constant ALU_SIMD_ADD   : std_logic_vector(7 downto 0) := x"70";
    constant ALU_SIMD_SUB   : std_logic_vector(7 downto 0) := x"71";
    constant ALU_SIMD_MUL   : std_logic_vector(7 downto 0) := x"72";
    constant ALU_SIMD_AND   : std_logic_vector(7 downto 0) := x"73";
    constant ALU_SIMD_OR    : std_logic_vector(7 downto 0) := x"74";
    constant ALU_SIMD_XOR   : std_logic_vector(7 downto 0) := x"75";
    
    -- Vector operations
    constant ALU_VDOT       : std_logic_vector(7 downto 0) := x"80";
    constant ALU_VCROSS     : std_logic_vector(7 downto 0) := x"81";
    constant ALU_VSUM       : std_logic_vector(7 downto 0) := x"82";
    constant ALU_VAVG       : std_logic_vector(7 downto 0) := x"83";
    constant ALU_VMAG       : std_logic_vector(7 downto 0) := x"84";
    constant ALU_VNORM      : std_logic_vector(7 downto 0) := x"85";
    
    -- Floating-point operations
    constant ALU_FADD       : std_logic_vector(7 downto 0) := x"90";
    constant ALU_FSUB       : std_logic_vector(7 downto 0) := x"91";
    constant ALU_FMUL       : std_logic_vector(7 downto 0) := x"92";
    constant ALU_FDIV       : std_logic_vector(7 downto 0) := x"93";
    constant ALU_FSQRT      : std_logic_vector(7 downto 0) := x"94";
    constant ALU_FABS       : std_logic_vector(7 downto 0) := x"95";
    constant ALU_FNEG       : std_logic_vector(7 downto 0) := x"96";
    
    -- Cryptographic operations
    constant ALU_AES_ENC    : std_logic_vector(7 downto 0) := x"A0";
    constant ALU_AES_DEC    : std_logic_vector(7 downto 0) := x"A1";
    constant ALU_SHA256     : std_logic_vector(7 downto 0) := x"A2";
    constant ALU_SHA512     : std_logic_vector(7 downto 0) := x"A3";
    constant ALU_RSA_MOD    : std_logic_vector(7 downto 0) := x"A4";
    constant ALU_ECC_ADD    : std_logic_vector(7 downto 0) := x"A5";
    constant ALU_RNG        : std_logic_vector(7 downto 0) := x"A6";
    
    -- ========================================================================
    -- OPERATION MODES
    -- ========================================================================
    
    constant MODE_NORMAL    : std_logic_vector(3 downto 0) := x"0";
    constant MODE_SATURATE  : std_logic_vector(3 downto 0) := x"1";
    constant MODE_SIMD_128  : std_logic_vector(3 downto 0) := x"2";
    constant MODE_SIMD_64   : std_logic_vector(3 downto 0) := x"3";
    constant MODE_SIMD_32   : std_logic_vector(3 downto 0) := x"4";
    constant MODE_SIMD_16   : std_logic_vector(3 downto 0) := x"5";
    constant MODE_SIMD_8    : std_logic_vector(3 downto 0) := x"6";
    constant MODE_VECTOR    : std_logic_vector(3 downto 0) := x"7";
    constant MODE_BCD       : std_logic_vector(3 downto 0) := x"8";
    constant MODE_FLOAT     : std_logic_vector(3 downto 0) := x"9";
    constant MODE_CRYPTO    : std_logic_vector(3 downto 0) := x"A";
    constant MODE_EXTENDED  : std_logic_vector(3 downto 0) := x"B";
    
    -- ========================================================================
    -- INTERNAL SIGNALS
    -- ========================================================================
    
    -- Arithmetic operation results
    signal add_result       : std_logic_vector(256 downto 0);
    signal sub_result       : std_logic_vector(256 downto 0);
    signal mul_result       : std_logic_vector(511 downto 0);
    signal div_quotient     : std_logic_vector(255 downto 0);
    signal div_remainder    : std_logic_vector(255 downto 0);
    
    -- Logical operation results
    signal and_result       : std_logic_vector(255 downto 0);
    signal or_result        : std_logic_vector(255 downto 0);
    signal xor_result       : std_logic_vector(255 downto 0);
    signal not_result       : std_logic_vector(255 downto 0);
    
    -- Shift and rotate results
    signal sll_result       : std_logic_vector(255 downto 0);
    signal srl_result       : std_logic_vector(255 downto 0);
    signal sra_result       : std_logic_vector(255 downto 0);
    signal rol_result       : std_logic_vector(255 downto 0);
    signal ror_result       : std_logic_vector(255 downto 0);
    signal shift_amt        : integer range 0 to 255;
    
    -- Bit manipulation results
    signal clz_result       : std_logic_vector(255 downto 0);
    signal ctz_result       : std_logic_vector(255 downto 0);
    signal popcnt_result    : std_logic_vector(255 downto 0);
    signal rev_result       : std_logic_vector(255 downto 0);
    signal bswap_result     : std_logic_vector(255 downto 0);
    
    -- Advanced arithmetic results
    signal abs_result       : std_logic_vector(255 downto 0);
    signal neg_result       : std_logic_vector(255 downto 0);
    signal inc_result       : std_logic_vector(255 downto 0);
    signal dec_result       : std_logic_vector(255 downto 0);
    signal min_result       : std_logic_vector(255 downto 0);
    signal max_result       : std_logic_vector(255 downto 0);
    signal sqrt_result      : std_logic_vector(255 downto 0);
    signal square_result    : std_logic_vector(511 downto 0);
    
    -- SIMD operation results
    signal simd128_add_result : std_logic_vector(255 downto 0);
    signal simd128_sub_result : std_logic_vector(255 downto 0);
    signal simd128_mul_result : std_logic_vector(255 downto 0);
    signal simd64_add_result  : std_logic_vector(255 downto 0);
    signal simd64_sub_result  : std_logic_vector(255 downto 0);
    signal simd64_mul_result  : std_logic_vector(255 downto 0);
    signal simd32_add_result  : std_logic_vector(255 downto 0);
    signal simd32_sub_result  : std_logic_vector(255 downto 0);
    signal simd32_mul_result  : std_logic_vector(255 downto 0);
    signal simd16_add_result  : std_logic_vector(255 downto 0);
    signal simd16_sub_result  : std_logic_vector(255 downto 0);
    signal simd16_mul_result  : std_logic_vector(255 downto 0);
    signal simd8_add_result   : std_logic_vector(255 downto 0);
    signal simd8_sub_result   : std_logic_vector(255 downto 0);
    signal simd8_mul_result   : std_logic_vector(255 downto 0);
    
    -- Vector operation results
    signal vector_add_result  : std_logic_vector(255 downto 0);
    signal vector_sub_result  : std_logic_vector(255 downto 0);
    signal vector_mul_result  : std_logic_vector(255 downto 0);
    signal vector_dot_result  : std_logic_vector(255 downto 0);
    signal vector_cross_result: std_logic_vector(255 downto 0);
    signal vector_sum_result  : std_logic_vector(255 downto 0);
    signal vector_avg_result  : std_logic_vector(255 downto 0);
    signal vector_mag_result  : std_logic_vector(255 downto 0);
    
    -- Floating-point operation results
    signal float_add_result   : std_logic_vector(255 downto 0);
    signal float_sub_result   : std_logic_vector(255 downto 0);
    signal float_mul_result   : std_logic_vector(255 downto 0);
    signal float_div_result   : std_logic_vector(255 downto 0);
    signal float_sqrt_result  : std_logic_vector(255 downto 0);
    
    -- Cryptographic operation results
    signal aes_enc_result     : std_logic_vector(255 downto 0);
    signal aes_dec_result     : std_logic_vector(255 downto 0);
    signal sha256_result      : std_logic_vector(255 downto 0);
    signal sha512_result      : std_logic_vector(255 downto 0);
    signal rsa_mod_result     : std_logic_vector(255 downto 0);
    signal ecc_add_result     : std_logic_vector(255 downto 0);
    signal rng_result         : std_logic_vector(255 downto 0);
    
    -- Saturated arithmetic results
    signal sat_add_result     : std_logic_vector(255 downto 0);
    signal sat_sub_result     : std_logic_vector(255 downto 0);
    signal sat_mul_result     : std_logic_vector(255 downto 0);
    
    -- BCD arithmetic results
    signal bcd_add_result     : std_logic_vector(255 downto 0);
    signal bcd_sub_result     : std_logic_vector(255 downto 0);
    signal bcd_carry          : std_logic;
    
    -- Internal result signals
    signal result_int         : std_logic_vector(255 downto 0);
    signal result_hi_int      : std_logic_vector(255 downto 0);
    
    -- Flag signals
    signal zero_flag          : std_logic;
    signal carry_flag         : std_logic;
    signal overflow_flag      : std_logic;
    signal negative_flag      : std_logic;
    signal parity_flag        : std_logic;
    signal half_carry_flag    : std_logic;
    signal aux_carry_flag     : std_logic;
    signal sign_flag          : std_logic;
    signal trap_flag          : std_logic;
    signal direction_flag     : std_logic;
    signal interrupt_flag     : std_logic;
    signal bit_test_flag      : std_logic;
    
    -- Floating-point flags
    signal fp_invalid_flag    : std_logic;
    signal fp_div_zero_flag   : std_logic;
    signal fp_overflow_flag   : std_logic;
    signal fp_underflow_flag  : std_logic;
    signal fp_inexact_flag    : std_logic;
    
    -- SIMD flags
    signal simd_zero_flags    : std_logic_vector(31 downto 0);
    
    -- Exception signals
    signal exception_int      : std_logic;
    signal exception_code_int : std_logic_vector(7 downto 0);
    signal security_violation_int : std_logic;

begin

    -- ========================================================================
    -- BASIC ARITHMETIC OPERATIONS
    -- ========================================================================
    
    -- 256-bit addition
    add_result <= std_logic_vector(unsigned('0' & a) + unsigned('0' & b) + unsigned'("" & carry_in));
    
    -- 256-bit subtraction
    sub_result <= std_logic_vector(unsigned('0' & a) - unsigned('0' & b) - unsigned'("" & carry_in));
    
    -- 256-bit multiplication (if enabled)
    mul_gen: if ENABLE_MUL generate
        mul_result <= std_logic_vector(unsigned(a) * unsigned(b));
    end generate;
    
    -- ========================================================================
    -- SIMD OPERATIONS (if enabled)
    -- ========================================================================
    
    simd_gen: if ENABLE_SIMD generate
        simd_operations: process(a, b, mode)
        begin
            case mode is
                when MODE_SIMD_128 =>
                    -- 2x128-bit SIMD operations
                    simd128_add_result(127 downto 0) <= std_logic_vector(unsigned(a(127 downto 0)) + unsigned(b(127 downto 0)));
                    simd128_add_result(255 downto 128) <= std_logic_vector(unsigned(a(255 downto 128)) + unsigned(b(255 downto 128)));
                    
                    simd128_sub_result(127 downto 0) <= std_logic_vector(unsigned(a(127 downto 0)) - unsigned(b(127 downto 0)));
                    simd128_sub_result(255 downto 128) <= std_logic_vector(unsigned(a(255 downto 128)) - unsigned(b(255 downto 128)));
                    
                    simd128_mul_result(127 downto 0) <= std_logic_vector(unsigned(a(63 downto 0)) * unsigned(b(63 downto 0)));
                    simd128_mul_result(255 downto 128) <= std_logic_vector(unsigned(a(191 downto 128)) * unsigned(b(191 downto 128)));
                
                when MODE_SIMD_64 =>
                    -- 4x64-bit SIMD operations
                    for i in 0 to 3 loop
                        simd64_add_result(64*(i+1)-1 downto 64*i) <= 
                            std_logic_vector(unsigned(a(64*(i+1)-1 downto 64*i)) + unsigned(b(64*(i+1)-1 downto 64*i)));
                        simd64_sub_result(64*(i+1)-1 downto 64*i) <= 
                            std_logic_vector(unsigned(a(64*(i+1)-1 downto 64*i)) - unsigned(b(64*(i+1)-1 downto 64*i)));
                        simd64_mul_result(64*(i+1)-1 downto 64*i) <= 
                            std_logic_vector(unsigned(a(32*(i+1)-1 downto 32*i)) * unsigned(b(32*(i+1)-1 downto 32*i)));
                    end loop;
                
                when MODE_SIMD_32 =>
                    -- 8x32-bit SIMD operations
                    for i in 0 to 7 loop
                        simd32_add_result(32*(i+1)-1 downto 32*i) <= 
                            std_logic_vector(unsigned(a(32*(i+1)-1 downto 32*i)) + unsigned(b(32*(i+1)-1 downto 32*i)));
                        simd32_sub_result(32*(i+1)-1 downto 32*i) <= 
                            std_logic_vector(unsigned(a(32*(i+1)-1 downto 32*i)) - unsigned(b(32*(i+1)-1 downto 32*i)));
                        simd32_mul_result(32*(i+1)-1 downto 32*i) <= 
                            std_logic_vector(unsigned(a(16*(i+1)-1 downto 16*i)) * unsigned(b(16*(i+1)-1 downto 16*i)));
                    end loop;
                
                when MODE_SIMD_16 =>
                    -- 16x16-bit SIMD operations
                    for i in 0 to 15 loop
                        simd16_add_result(16*(i+1)-1 downto 16*i) <= 
                            std_logic_vector(unsigned(a(16*(i+1)-1 downto 16*i)) + unsigned(b(16*(i+1)-1 downto 16*i)));
                        simd16_sub_result(16*(i+1)-1 downto 16*i) <= 
                            std_logic_vector(unsigned(a(16*(i+1)-1 downto 16*i)) - unsigned(b(16*(i+1)-1 downto 16*i)));
                        simd16_mul_result(16*(i+1)-1 downto 16*i) <= 
                            std_logic_vector(unsigned(a(8*(i+1)-1 downto 8*i)) * unsigned(b(8*(i+1)-1 downto 8*i)));
                    end loop;
                
                when MODE_SIMD_8 =>
                    -- 32x8-bit SIMD operations
                    for i in 0 to 31 loop
                        simd8_add_result(8*(i+1)-1 downto 8*i) <= 
                            std_logic_vector(unsigned(a(8*(i+1)-1 downto 8*i)) + unsigned(b(8*(i+1)-1 downto 8*i)));
                        simd8_sub_result(8*(i+1)-1 downto 8*i) <= 
                            std_logic_vector(unsigned(a(8*(i+1)-1 downto 8*i)) - unsigned(b(8*(i+1)-1 downto 8*i)));
                        simd8_mul_result(8*(i+1)-1 downto 8*i) <= 
                            std_logic_vector(unsigned(a(4*(i+1)-1 downto 4*i)) * unsigned(b(4*(i+1)-1 downto 4*i)));
                    end loop;
                
                when others =>
                    simd128_add_result <= (others => '0');
                    simd128_sub_result <= (others => '0');
                    simd128_mul_result <= (others => '0');
                    simd64_add_result <= (others => '0');
                    simd64_sub_result <= (others => '0');
                    simd64_mul_result <= (others => '0');
                    simd32_add_result <= (others => '0');
                    simd32_sub_result <= (others => '0');
                    simd32_mul_result <= (others => '0');
                    simd16_add_result <= (others => '0');
                    simd16_sub_result <= (others => '0');
                    simd16_mul_result <= (others => '0');
                    simd8_add_result <= (others => '0');
                    simd8_sub_result <= (others => '0');
                    simd8_mul_result <= (others => '0');
            end case;
        end process;
    end generate;
    
    -- ========================================================================
    -- VECTOR OPERATIONS (if enabled)
    -- ========================================================================
    
    vector_gen: if ENABLE_VECTOR generate
        vector_operations: process(a, b)
            variable dot_product : unsigned(511 downto 0);
            variable sum_result : unsigned(255 downto 0);
        begin
            -- Vector addition (element-wise)
            vector_add_result <= std_logic_vector(unsigned(a) + unsigned(b));
            
            -- Vector subtraction (element-wise)
            vector_sub_result <= std_logic_vector(unsigned(a) - unsigned(b));
            
            -- Vector multiplication (element-wise)
            vector_mul_result <= std_logic_vector(unsigned(a(127 downto 0)) * unsigned(b(127 downto 0)));
            
            -- Dot product (simplified for 2x128-bit vectors)
            dot_product := unsigned(a(127 downto 0)) * unsigned(b(127 downto 0)) + 
                          unsigned(a(255 downto 128)) * unsigned(b(255 downto 128));
            vector_dot_result <= std_logic_vector(dot_product(255 downto 0));
            
            -- Vector sum (sum all elements)
            sum_result := unsigned(a(127 downto 0)) + unsigned(a(255 downto 128));
            vector_sum_result <= std_logic_vector(sum_result);
            
            -- Vector average
            vector_avg_result <= std_logic_vector(sum_result(255 downto 1));
            
            -- Vector magnitude (simplified)
            vector_mag_result <= std_logic_vector(unsigned(a(127 downto 0)) + unsigned(a(255 downto 128)));
            
            -- Cross product placeholder (for 3D vectors)
            vector_cross_result <= (others => '0');
        end process;
    end generate;
    
    -- ========================================================================
    -- SHIFT AND ROTATE OPERATIONS (if enabled)
    -- ========================================================================
    
    shift_gen: if ENABLE_SHIFT generate
        shift_amt <= to_integer(unsigned(shift_amount));
        
        shift_rotate: process(a, shift_amt)
        begin
            -- Shift left logical
            if shift_amt < 256 then
                sll_result <= std_logic_vector(shift_left(unsigned(a), shift_amt));
            else
                sll_result <= (others => '0');
            end if;
            
            -- Shift right logical
            if shift_amt < 256 then
                srl_result <= std_logic_vector(shift_right(unsigned(a), shift_amt));
            else
                srl_result <= (others => '0');
            end if;
            
            -- Shift right arithmetic
            if shift_amt < 256 then
                sra_result <= std_logic_vector(shift_right(signed(a), shift_amt));
            else
                if a(255) = '1' then
                    sra_result <= (others => '1');
                else
                    sra_result <= (others => '0');
                end if;
            end if;
        end process;
    end generate;
    
    rotate_gen: if ENABLE_ROTATE generate
        rotate_ops: process(a, shift_amt)
        begin
            -- Rotate left
            if shift_amt < 256 then
                rol_result <= std_logic_vector(rotate_left(unsigned(a), shift_amt));
            else
                rol_result <= a;
            end if;
            
            -- Rotate right
            if shift_amt < 256 then
                ror_result <= std_logic_vector(rotate_right(unsigned(a), shift_amt));
            else
                ror_result <= a;
            end if;
        end process;
    end generate;
    
    -- ========================================================================
    -- BCD ARITHMETIC (if enabled)
    -- ========================================================================
    
    bcd_gen: if ENABLE_BCD generate
        bcd_arithmetic: process(a, b)
            variable bcd_sum : std_logic_vector(259 downto 0);
            variable bcd_diff : std_logic_vector(259 downto 0);
        begin
            -- BCD addition (simplified)
            bcd_sum := std_logic_vector(unsigned('0' & a) + unsigned('0' & b));
            bcd_add_result <= bcd_sum(255 downto 0);
            bcd_carry <= bcd_sum(256);
            
            -- BCD subtraction (simplified)
            bcd_diff := std_logic_vector(unsigned('0' & a) - unsigned('0' & b));
            bcd_sub_result <= bcd_diff(255 downto 0);
        end process;
    end generate;
    
    -- ========================================================================
    -- FLOATING-POINT OPERATIONS (if enabled)
    -- ========================================================================
    
    float_gen: if ENABLE_FLOAT generate
        floating_point: process(a, b)
        begin
            -- Simplified floating-point operations (placeholders)
            float_add_result <= std_logic_vector(unsigned(a) + unsigned(b));
            float_sub_result <= std_logic_vector(unsigned(a) - unsigned(b));
            float_mul_result <= std_logic_vector(unsigned(a(127 downto 0)) * unsigned(b(127 downto 0)));
            
            -- Division placeholder
            if b /= x"0000000000000000000000000000000000000000000000000000000000000000" then
                float_div_result <= std_logic_vector(unsigned(a) / unsigned(b));
            else
                float_div_result <= (others => '1');
            end if;
            
            -- Square root placeholder
            float_sqrt_result <= std_logic_vector(unsigned(a(127 downto 0)));
        end process;
    end generate;
    
    -- ========================================================================
    -- CRYPTOGRAPHIC OPERATIONS (if enabled)
    -- ========================================================================
    
    crypto_gen: if ENABLE_CRYPTO generate
        cryptographic: process(a, b)
        begin
            -- AES encryption (simplified placeholder)
            aes_enc_result <= a xor b;
            
            -- AES decryption (simplified placeholder)
            aes_dec_result <= a xor b;
            
            -- SHA-256 (simplified placeholder)
            sha256_result <= a xor b xor x"5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A";
            
            -- SHA-512 (simplified placeholder)
            sha512_result <= a xor b xor x"A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5";
            
            -- RSA modular arithmetic (simplified placeholder)
            rsa_mod_result <= std_logic_vector(unsigned(a) mod unsigned(b));
            
            -- ECC point addition (simplified placeholder)
            ecc_add_result <= std_logic_vector(unsigned(a) + unsigned(b));
            
            -- Random number generation (simplified placeholder)
            rng_result <= a xor b xor x"DEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF";
        end process;
    end generate;
    
    -- ========================================================================
    -- MAIN ALU OPERATION SELECTION
    -- ========================================================================
    
    alu_operation: process(clk, rst)
    begin
        if rst = '1' then
            result_int <= (others => '0');
            result_hi_int <= (others => '0');
            exception_int <= '0';
            exception_code_int <= (others => '0');
            security_violation_int <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                exception_int <= '0';
                exception_code_int <= (others => '0');
                security_violation_int <= '0';
                
                case alu_op is
                    -- Basic arithmetic operations
                    when ALU_ADD =>
                        case mode is
                            when MODE_NORMAL =>
                                result_int <= add_result(255 downto 0);
                                result_hi_int <= (others => '0');
                            when MODE_SATURATE =>
                                if ENABLE_SATURATE then
                                    result_int <= sat_add_result;
                                else
                                    result_int <= add_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_SIMD_128 =>
                                if ENABLE_SIMD then
                                    result_int <= simd128_add_result;
                                else
                                    result_int <= add_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_SIMD_64 =>
                                if ENABLE_SIMD then
                                    result_int <= simd64_add_result;
                                else
                                    result_int <= add_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_SIMD_32 =>
                                if ENABLE_SIMD then
                                    result_int <= simd32_add_result;
                                else
                                    result_int <= add_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_SIMD_16 =>
                                if ENABLE_SIMD then
                                    result_int <= simd16_add_result;
                                else
                                    result_int <= add_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_SIMD_8 =>
                                if ENABLE_SIMD then
                                    result_int <= simd8_add_result;
                                else
                                    result_int <= add_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_VECTOR =>
                                if ENABLE_VECTOR then
                                    result_int <= vector_add_result;
                                else
                                    result_int <= add_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_BCD =>
                                if ENABLE_BCD then
                                    result_int <= bcd_add_result;
                                else
                                    result_int <= add_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_FLOAT =>
                                if ENABLE_FLOAT then
                                    result_int <= float_add_result;
                                else
                                    result_int <= add_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when others =>
                                result_int <= add_result(255 downto 0);
                                result_hi_int <= (others => '0');
                        end case;
                    
                    when ALU_SUB =>
                        case mode is
                            when MODE_NORMAL =>
                                result_int <= sub_result(255 downto 0);
                                result_hi_int <= (others => '0');
                            when MODE_SATURATE =>
                                if ENABLE_SATURATE then
                                    result_int <= sat_sub_result;
                                else
                                    result_int <= sub_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_SIMD_128 =>
                                if ENABLE_SIMD then
                                    result_int <= simd128_sub_result;
                                else
                                    result_int <= sub_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_SIMD_64 =>
                                if ENABLE_SIMD then
                                    result_int <= simd64_sub_result;
                                else
                                    result_int <= sub_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_SIMD_32 =>
                                if ENABLE_SIMD then
                                    result_int <= simd32_sub_result;
                                else
                                    result_int <= sub_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_SIMD_16 =>
                                if ENABLE_SIMD then
                                    result_int <= simd16_sub_result;
                                else
                                    result_int <= sub_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_SIMD_8 =>
                                if ENABLE_SIMD then
                                    result_int <= simd8_sub_result;
                                else
                                    result_int <= sub_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_VECTOR =>
                                if ENABLE_VECTOR then
                                    result_int <= vector_sub_result;
                                else
                                    result_int <= sub_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_BCD =>
                                if ENABLE_BCD then
                                    result_int <= bcd_sub_result;
                                else
                                    result_int <= sub_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when MODE_FLOAT =>
                                if ENABLE_FLOAT then
                                    result_int <= float_sub_result;
                                else
                                    result_int <= sub_result(255 downto 0);
                                end if;
                                result_hi_int <= (others => '0');
                            when others =>
                                result_int <= sub_result(255 downto 0);
                                result_hi_int <= (others => '0');
                        end case;
                    
                    when ALU_MUL =>
                        if ENABLE_MUL then
                            case mode is
                                when MODE_NORMAL =>
                                    result_int <= mul_result(255 downto 0);
                                    result_hi_int <= mul_result(511 downto 256);
                                when MODE_SATURATE =>
                                    if ENABLE_SATURATE then
                                        result_int <= sat_mul_result;
                                        result_hi_int <= (others => '0');
                                    else
                                        result_int <= mul_result(255 downto 0);
                                        result_hi_int <= mul_result(511 downto 256);
                                    end if;
                                when MODE_SIMD_128 =>
                                    if ENABLE_SIMD then
                                        result_int <= simd128_mul_result;
                                        result_hi_int <= (others => '0');
                                    else
                                        result_int <= mul_result(255 downto 0);
                                        result_hi_int <= mul_result(511 downto 256);
                                    end if;
                                when MODE_SIMD_64 =>
                                    if ENABLE_SIMD then
                                        result_int <= simd64_mul_result;
                                        result_hi_int <= (others => '0');
                                    else
                                        result_int <= mul_result(255 downto 0);
                                        result_hi_int <= mul_result(511 downto 256);
                                    end if;
                                when MODE_SIMD_32 =>
                                    if ENABLE_SIMD then
                                        result_int <= simd32_mul_result;
                                        result_hi_int <= (others => '0');
                                    else
                                        result_int <= mul_result(255 downto 0);
                                        result_hi_int <= mul_result(511 downto 256);
                                    end if;
                                when MODE_SIMD_16 =>
                                    if ENABLE_SIMD then
                                        result_int <= simd16_mul_result;
                                        result_hi_int <= (others => '0');
                                    else
                                        result_int <= mul_result(255 downto 0);
                                        result_hi_int <= mul_result(511 downto 256);
                                    end if;
                                when MODE_SIMD_8 =>
                                    if ENABLE_SIMD then
                                        result_int <= simd8_mul_result;
                                        result_hi_int <= (others => '0');
                                    else
                                        result_int <= mul_result(255 downto 0);
                                        result_hi_int <= mul_result(511 downto 256);
                                    end if;
                                when MODE_VECTOR =>
                                    if ENABLE_VECTOR then
                                        result_int <= vector_mul_result;
                                        result_hi_int <= (others => '0');
                                    else
                                        result_int <= mul_result(255 downto 0);
                                        result_hi_int <= mul_result(511 downto 256);
                                    end if;
                                when MODE_FLOAT =>
                                    if ENABLE_FLOAT then
                                        result_int <= float_mul_result;
                                        result_hi_int <= (others => '0');
                                    else
                                        result_int <= mul_result(255 downto 0);
                                        result_hi_int <= mul_result(511 downto 256);
                                    end if;
                                when others =>
                                    result_int <= mul_result(255 downto 0);
                                    result_hi_int <= mul_result(511 downto 256);
                            end case;
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_DIV =>
                        if ENABLE_DIV then
                            if b = x"0000000000000000000000000000000000000000000000000000000000000000" then
                                result_int <= (others => '1');
                                result_hi_int <= (others => '0');
                                exception_int <= '1';
                                exception_code_int <= x"02";  -- Division by zero
                            else
                                result_int <= div_quotient;
                                result_hi_int <= div_remainder;
                            end if;
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    -- Logical operations
                    when ALU_AND =>
                        result_int <= and_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_OR =>
                        result_int <= or_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_XOR =>
                        result_int <= xor_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_NOT =>
                        result_int <= not_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_NAND =>
                        result_int <= not (a and b);
                        result_hi_int <= (others => '0');
                    
                    when ALU_NOR =>
                        result_int <= not (a or b);
                        result_hi_int <= (others => '0');
                    
                    when ALU_ANDN =>
                        result_int <= a and (not b);
                        result_hi_int <= (others => '0');
                    
                    when ALU_ORN =>
                        result_int <= a or (not b);
                        result_hi_int <= (others => '0');
                    
                    -- Shift and rotate operations
                    when ALU_SLL =>
                        if ENABLE_SHIFT then
                            result_int <= sll_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_SRL =>
                        if ENABLE_SHIFT then
                            result_int <= srl_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_SRA =>
                        if ENABLE_SHIFT then
                            result_int <= sra_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_ROL =>
                        if ENABLE_ROTATE then
                            result_int <= rol_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_ROR =>
                        if ENABLE_ROTATE then
                            result_int <= ror_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    -- Bit manipulation operations
                    when ALU_CLZ =>
                        result_int <= clz_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_CTZ =>
                        result_int <= ctz_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_POPCNT =>
                        result_int <= popcnt_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_REV =>
                        result_int <= rev_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_BSWAP =>
                        result_int <= bswap_result;
                        result_hi_int <= (others => '0');
                    
                    -- Advanced arithmetic operations
                    when ALU_ABS =>
                        result_int <= abs_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_NEG =>
                        result_int <= neg_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_INC =>
                        result_int <= inc_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_DEC =>
                        result_int <= dec_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_MIN =>
                        result_int <= min_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_MAX =>
                        result_int <= max_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_SQRT =>
                        result_int <= sqrt_result;
                        result_hi_int <= (others => '0');
                    
                    when ALU_SQUARE =>
                        result_int <= square_result(255 downto 0);
                        result_hi_int <= square_result(511 downto 256);
                    
                    -- Vector operations
                    when ALU_VDOT =>
                        if ENABLE_VECTOR then
                            result_int <= vector_dot_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_VCROSS =>
                        if ENABLE_VECTOR then
                            result_int <= vector_cross_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_VSUM =>
                        if ENABLE_VECTOR then
                            result_int <= vector_sum_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_VAVG =>
                        if ENABLE_VECTOR then
                            result_int <= vector_avg_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_VMAG =>
                        if ENABLE_VECTOR then
                            result_int <= vector_mag_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    -- Floating-point operations
                    when ALU_FADD =>
                        if ENABLE_FLOAT then
                            result_int <= float_add_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_FSUB =>
                        if ENABLE_FLOAT then
                            result_int <= float_sub_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_FMUL =>
                        if ENABLE_FLOAT then
                            result_int <= float_mul_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_FDIV =>
                        if ENABLE_FLOAT then
                            result_int <= float_div_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_FSQRT =>
                        if ENABLE_FLOAT then
                            result_int <= float_sqrt_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    -- Cryptographic operations
                    when ALU_AES_ENC =>
                        if ENABLE_CRYPTO then
                            result_int <= aes_enc_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_AES_DEC =>
                        if ENABLE_CRYPTO then
                            result_int <= aes_dec_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_SHA256 =>
                        if ENABLE_CRYPTO then
                            result_int <= sha256_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_SHA512 =>
                        if ENABLE_CRYPTO then
                            result_int <= sha512_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_RSA_MOD =>
                        if ENABLE_CRYPTO then
                            result_int <= rsa_mod_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_ECC_ADD =>
                        if ENABLE_CRYPTO then
                            result_int <= ecc_add_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    when ALU_RNG =>
                        if ENABLE_CRYPTO then
                            result_int <= rng_result;
                            result_hi_int <= (others => '0');
                        else
                            result_int <= (others => '0');
                            result_hi_int <= (others => '0');
                            exception_int <= '1';
                            exception_code_int <= x"01";  -- Unsupported operation
                        end if;
                    
                    -- Data movement operations
                    when ALU_PASS_A =>
                        result_int <= a;
                        result_hi_int <= (others => '0');
                    
                    when ALU_PASS_B =>
                        result_int <= b;
                        result_hi_int <= (others => '0');
                    
                    when ALU_SWAP =>
                        result_int <= b;
                        result_hi_int <= a;
                    
                    when others =>
                        result_int <= (others => '0');
                        result_hi_int <= (others => '0');
                        exception_int <= '1';
                        exception_code_int <= x"FF";  -- Unknown operation
                end case;
            end if;
        end if;
    end process;
    
    -- ========================================================================
    -- FLAG GENERATION (256-bit)
    -- ========================================================================
    
    flag_generation: process(clk, rst)
        variable temp_result : std_logic_vector(256 downto 0);
        variable parity_calc : std_logic;
        variable simd_flags : std_logic_vector(31 downto 0);
    begin
        if rst = '1' then
            flags_int <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Zero flag
                if result_int = x"0000000000000000000000000000000000000000000000000000000000000000" then
                    flags_int(FLAG_ZERO) <= '1';
                else
                    flags_int(FLAG_ZERO) <= '0';
                end if;
                
                -- Negative flag (MSB of result)
                flags_int(FLAG_NEGATIVE) <= result_int(255);
                
                -- Carry flag (from addition/subtraction)
                case alu_op is
                    when ALU_ADD =>
                        temp_result := std_logic_vector(unsigned('0' & a) + unsigned('0' & b));
                        flags_int(FLAG_CARRY) <= temp_result(256);
                    when ALU_SUB =>
                        if unsigned(a) >= unsigned(b) then
                            flags_int(FLAG_CARRY) <= '0';
                        else
                            flags_int(FLAG_CARRY) <= '1';
                        end if;
                    when ALU_MUL =>
                        if ENABLE_MUL then
                            if mul_result(511 downto 256) /= x"0000000000000000000000000000000000000000000000000000000000000000" then
                                flags_int(FLAG_CARRY) <= '1';
                            else
                                flags_int(FLAG_CARRY) <= '0';
                            end if;
                        else
                            flags_int(FLAG_CARRY) <= '0';
                        end if;
                    when others =>
                        flags_int(FLAG_CARRY) <= '0';
                end case;
                
                -- Overflow flag (signed arithmetic overflow)
                case alu_op is
                    when ALU_ADD =>
                        if (a(255) = b(255)) and (result_int(255) /= a(255)) then
                            flags_int(FLAG_OVERFLOW) <= '1';
                        else
                            flags_int(FLAG_OVERFLOW) <= '0';
                        end if;
                    when ALU_SUB =>
                        if (a(255) /= b(255)) and (result_int(255) /= a(255)) then
                            flags_int(FLAG_OVERFLOW) <= '1';
                        else
                            flags_int(FLAG_OVERFLOW) <= '0';
                        end if;
                    when others =>
                        flags_int(FLAG_OVERFLOW) <= '0';
                end case;
                
                -- Parity flag (even parity of lower 8 bits)
                parity_calc := '0';
                for i in 0 to 7 loop
                    parity_calc := parity_calc xor result_int(i);
                end loop;
                flags_int(FLAG_PARITY) <= not parity_calc;
                
                -- Half-carry flag (carry from bit 3 to bit 4)
                case alu_op is
                    when ALU_ADD =>
                        if (unsigned(a(3 downto 0)) + unsigned(b(3 downto 0))) > 15 then
                            flags_int(FLAG_HALF_CARRY) <= '1';
                        else
                            flags_int(FLAG_HALF_CARRY) <= '0';
                        end if;
                    when ALU_SUB =>
                        if unsigned(a(3 downto 0)) < unsigned(b(3 downto 0)) then
                            flags_int(FLAG_HALF_CARRY) <= '1';
                        else
                            flags_int(FLAG_HALF_CARRY) <= '0';
                        end if;
                    when others =>
                        flags_int(FLAG_HALF_CARRY) <= '0';
                end case;
                
                -- Auxiliary carry flag (carry from bit 7 to bit 8)
                case alu_op is
                    when ALU_ADD =>
                        if (unsigned(a(7 downto 0)) + unsigned(b(7 downto 0))) > 255 then
                            flags_int(FLAG_AUX_CARRY) <= '1';
                        else
                            flags_int(FLAG_AUX_CARRY) <= '0';
                        end if;
                    when ALU_SUB =>
                        if unsigned(a(7 downto 0)) < unsigned(b(7 downto 0)) then
                            flags_int(FLAG_AUX_CARRY) <= '1';
                        else
                            flags_int(FLAG_AUX_CARRY) <= '0';
                        end if;
                    when others =>
                        flags_int(FLAG_AUX_CARRY) <= '0';
                end case;
                
                -- Sign flag (same as negative flag)
                flags_int(FLAG_SIGN) <= result_int(255);
                
                -- Trap flag (for debugging)
                flags_int(FLAG_TRAP) <= '0';  -- Set by external debug logic
                
                -- Direction flag (for string operations)
                flags_int(FLAG_DIRECTION) <= '0';  -- Set by external control
                
                -- Interrupt flag (for interrupt control)
                flags_int(FLAG_INTERRUPT) <= '0';  -- Set by external control
                
                -- Bit test flag (for bit test operations)
                case alu_op is
                    when ALU_AND | ALU_OR | ALU_XOR =>
                        if result_int = x"0000000000000000000000000000000000000000000000000000000000000000" then
                            flags_int(FLAG_BIT_TEST) <= '1';
                        else
                            flags_int(FLAG_BIT_TEST) <= '0';
                        end if;
                    when others =>
                        flags_int(FLAG_BIT_TEST) <= '0';
                end case;
                
                -- Floating-point flags (if enabled)
                if ENABLE_FLOAT then
                    -- Simplified floating-point flag generation
                    flags_int(FLAG_FP_INVALID) <= '0';
                    flags_int(FLAG_FP_DENORMAL) <= '0';
                    flags_int(FLAG_FP_ZERO_DIV) <= '0';
                    flags_int(FLAG_FP_OVERFLOW) <= '0';
                    flags_int(FLAG_FP_UNDERFLOW) <= '0';
                    flags_int(FLAG_FP_INEXACT) <= '0';
                else
                    flags_int(FLAG_FP_INVALID) <= '0';
                    flags_int(FLAG_FP_DENORMAL) <= '0';
                    flags_int(FLAG_FP_ZERO_DIV) <= '0';
                    flags_int(FLAG_FP_OVERFLOW) <= '0';
                    flags_int(FLAG_FP_UNDERFLOW) <= '0';
                    flags_int(FLAG_FP_INEXACT) <= '0';
                end if;
                
                -- SIMD flags (if enabled)
                if ENABLE_SIMD then
                    -- Generate flags for each SIMD lane
                    simd_flags := (others => '0');
                    case mode is
                        when MODE_SIMD_128 =>
                            -- 2x128-bit SIMD flags
                            if result_int(127 downto 0) = x"00000000000000000000000000000000" then
                                simd_flags(0) := '1';
                            end if;
                            if result_int(255 downto 128) = x"00000000000000000000000000000000" then
                                simd_flags(1) := '1';
                            end if;
                        when MODE_SIMD_64 =>
                            -- 4x64-bit SIMD flags
                            for i in 0 to 3 loop
                                if result_int(64*(i+1)-1 downto 64*i) = x"0000000000000000" then
                                    simd_flags(i) := '1';
                                end if;
                            end loop;
                        when MODE_SIMD_32 =>
                            -- 8x32-bit SIMD flags
                            for i in 0 to 7 loop
                                if result_int(32*(i+1)-1 downto 32*i) = x"00000000" then
                                    simd_flags(i) := '1';
                                end if;
                            end loop;
                        when MODE_SIMD_16 =>
                            -- 16x16-bit SIMD flags
                            for i in 0 to 15 loop
                                if result_int(16*(i+1)-1 downto 16*i) = x"0000" then
                                    simd_flags(i) := '1';
                                end if;
                            end loop;
                        when MODE_SIMD_8 =>
                            -- 32x8-bit SIMD flags
                            for i in 0 to 31 loop
                                if result_int(8*(i+1)-1 downto 8*i) = x"00" then
                                    simd_flags(i) := '1';
                                end if;
                            end loop;
                        when others =>
                            simd_flags := (others => '0');
                    end case;
                    flags_int(FLAG_SIMD_ZERO) <= simd_flags(0);
                else
                    flags_int(FLAG_SIMD_ZERO) <= '0';
                end if;
                
                -- Reserved flags (for future use)
                flags_int(31 downto 19) <= (others => '0');
            end if;
        end if;
    end process;
    
    -- ========================================================================
    -- PIPELINE IMPLEMENTATION (if enabled)
    -- ========================================================================
    
    pipeline_gen: if ENABLE_PIPELINE generate
        pipeline_regs: process(clk, rst)
        begin
            if rst = '1' then
                -- Stage 1 registers
                a_reg1 <= (others => '0');
                b_reg1 <= (others => '0');
                alu_op_reg1 <= (others => '0');
                mode_reg1 <= (others => '0');
                
                -- Stage 2 registers
                a_reg2 <= (others => '0');
                b_reg2 <= (others => '0');
                alu_op_reg2 <= (others => '0');
                mode_reg2 <= (others => '0');
                
                -- Stage 3 registers
                result_reg3 <= (others => '0');
                result_hi_reg3 <= (others => '0');
                flags_reg3 <= (others => '0');
                
            elsif rising_edge(clk) then
                if enable = '1' then
                    -- Pipeline stage 1: Input registration
                    a_reg1 <= a;
                    b_reg1 <= b;
                    alu_op_reg1 <= alu_op;
                    mode_reg1 <= mode;
                    
                    -- Pipeline stage 2: Operation execution
                    a_reg2 <= a_reg1;
                    b_reg2 <= b_reg1;
                    alu_op_reg2 <= alu_op_reg1;
                    mode_reg2 <= mode_reg1;
                    
                    -- Pipeline stage 3: Result registration
                    result_reg3 <= result_int;
                    result_hi_reg3 <= result_hi_int;
                    flags_reg3 <= flags_int;
                end if;
            end if;
        end process;
        
        -- Pipeline output selection
        result <= result_reg3 when ENABLE_PIPELINE else result_int;
        result_hi <= result_hi_reg3 when ENABLE_PIPELINE else result_hi_int;
        flags <= flags_reg3 when ENABLE_PIPELINE else flags_int;
    end generate;
    
    no_pipeline_gen: if not ENABLE_PIPELINE generate
        result <= result_int;
        result_hi <= result_hi_int;
        flags <= flags_int;
    end generate;
    
    -- ========================================================================
    -- OUTPUT ASSIGNMENTS
    -- ========================================================================
    
    -- Status outputs
    ready <= '1' when enable = '1' else '0';
    exception <= exception_int;
    exception_code <= exception_code_int;
    security_violation <= security_violation_int;
    
    -- Performance monitoring (if enabled)
    perf_gen: if ENABLE_PERF generate
        performance_counters: process(clk, rst)
        begin
            if rst = '1' then
                cycle_count <= (others => '0');
                operation_count <= (others => '0');
            elsif rising_edge(clk) then
                if enable = '1' then
                    cycle_count <= std_logic_vector(unsigned(cycle_count) + 1);
                    if ready = '1' then
                        operation_count <= std_logic_vector(unsigned(operation_count) + 1);
                    end if;
                end if;
            end if;
        end process;
    end generate;

end architecture behavioral;

-- ============================================================================
-- VERIFICATION AND TESTING NOTES
-- ============================================================================

-- This 256-bit ALU implementation provides:
-- 1. Comprehensive arithmetic operations (add, subtract, multiply, divide)
-- 2. Full logical operations (AND, OR, XOR, NOT, NAND, NOR, etc.)
-- 3. Advanced bit manipulation (CLZ, CTZ, POPCNT, bit reversal, byte swap)
-- 4. Shift and rotate operations with barrel shifter
-- 5. SIMD operations for parallel processing
-- 6. Vector operations for mathematical computations
-- 7. Saturated arithmetic for DSP applications
-- 8. BCD arithmetic for decimal calculations
-- 9. Floating-point operations (simplified)
-- 10. Cryptographic operations (AES, SHA, RSA, ECC, RNG)
-- 11. Comprehensive flag generation
-- 12. Pipeline support for high-frequency operation
-- 13. Exception handling and security features
-- 14. Performance monitoring capabilities

-- Testing Strategy:
-- 1. Unit tests for each operation type
-- 2. Boundary condition testing (overflow, underflow)
-- 3. SIMD operation verification
-- 4. Pipeline timing verification
-- 5. Flag generation accuracy testing
-- 6. Exception handling verification
-- 7. Performance benchmarking
-- 8. Security feature validation

-- Synthesis Considerations:
-- 1. Large resource requirements (LUTs, DSP blocks, BRAM)
-- 2. Timing closure challenges at high frequencies
-- 3. Power consumption optimization
-- 4. Area optimization through feature selection
-- 5. Clock domain crossing considerations

-- Extension Opportunities:
-- 1. Custom instruction support
-- 2. Advanced cryptographic algorithms
-- 3. Machine learning operations
-- 4. Digital signal processing functions
-- 5. Multi-precision arithmetic
-- 6. Fault tolerance features
-- 7. Debug and trace capabilities
        division: process(a, b)
        begin
            if b /= x"0000000000000000000000000000000000000000000000000000000000000000" then
                div_quotient <= std_logic_vector(unsigned(a) / unsigned(b));
                div_remainder <= std_logic_vector(unsigned(a) mod unsigned(b));
            else
                div_quotient <= (others => '1');  -- Indicate error
                div_remainder <= (others => '0');
            end if;
        end process;
    end generate;
    
    -- ========================================================================
    -- LOGICAL OPERATIONS
    -- ========================================================================
    
    and_result <= a and b;
    or_result <= a or b;
    xor_result <= a xor b;
    not_result <= not a;
    
    -- ========================================================================
    -- BIT MANIPULATION OPERATIONS
    -- ========================================================================
    
    bit_manipulation: process(a, b)
        variable clz_count : integer;
        variable ctz_count : integer;
        variable pop_count : integer;
    begin
        -- Count leading zeros
        clz_count := 0;
        for i in 255 downto 0 loop
            if a(i) = '0' then
                clz_count := clz_count + 1;
            else
                exit;
            end if;
        end loop;
        clz_result <= std_logic_vector(to_unsigned(clz_count, 256));
        
        -- Count trailing zeros
        ctz_count := 0;
        for i in 0 to 255 loop
            if a(i) = '0' then
                ctz_count := ctz_count + 1;
            else
                exit;
            end if;
        end loop;
        ctz_result <= std_logic_vector(to_unsigned(ctz_count, 256));
        
        -- Population count (count of 1s)
        pop_count := 0;
        for i in 0 to 255 loop
            if a(i) = '1' then
                pop_count := pop_count + 1;
            end if;
        end loop;
        popcnt_result <= std_logic_vector(to_unsigned(pop_count, 256));
        
        -- Bit reversal
        for i in 0 to 255 loop
            rev_result(i) <= a(255-i);
        end loop;
        
        -- Byte swap
        for i in 0 to 31 loop
            bswap_result(8*i+7 downto 8*i) <= a(8*(31-i)+7 downto 8*(31-i));
        end loop;
    end process;
    
    -- ========================================================================
    -- ADVANCED ARITHMETIC OPERATIONS
    -- ========================================================================
    
    advanced_arithmetic: process(a, b)
    begin
        -- Absolute value
        if a(255) = '1' then
            abs_result <= std_logic_vector(unsigned(not a) + 1);
        else
            abs_result <= a;
        end if;
        
        -- Negation
        neg_result <= std_logic_vector(unsigned(not a) + 1);
        
        -- Increment
        inc_result <= std_logic_vector(unsigned(a) + 1);
        
        -- Decrement
        dec_result <= std_logic_vector(unsigned(a) - 1);
        
        -- Minimum (signed)
        if signed(a) < signed(b) then
            min_result <= a;
        else
            min_result <= b;
        end if;
        
        -- Maximum (signed)
        if signed(a) > signed(b) then
            max_result <= a;
        else
            max_result <= b;
        end if;
    end process;
    
    -- ========================================================================
    -- SATURATED ARITHMETIC (if enabled)
    -- ========================================================================
    
    saturate_gen: if ENABLE_SATURATE generate
        saturated_arithmetic: process(a, b, add_result, sub_result, mul_result)
        begin
            -- Saturated addition
            if add_result(256) = '1' then
                sat_add_result <= (others => '1');  -- Saturate to maximum
            else
                sat_add_result <= add_result(255 downto 0);
            end if;
            
            -- Saturated subtraction
            if sub_result(256) = '1' then
                sat_sub_result <= (others => '0');  -- Saturate to minimum
            else
                sat_sub_result <= sub_result(255 downto 0);
            end if;
            
            -- Saturated multiplication
            if ENABLE_MUL then
                if mul_result(511 downto 256) /= x"0000000000000000000000000000000000000000000000000000000000000000" then
                    sat_mul_result <= (others => '1');  -- Saturate to maximum
                else
                    sat_mul_result <= mul_result(255 downto 0);
                end if;
            else
                sat_mul_result <= (others => '0');
            end if;
        end process;
    end generate;