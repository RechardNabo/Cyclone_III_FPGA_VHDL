-- ============================================================================
-- 16-Bit Arithmetic Logic Unit (ALU) Implementation - Programming Guidance
-- ============================================================================
-- 
-- PROJECT OVERVIEW:
-- This file implements a 16-bit Arithmetic Logic Unit (ALU) optimized for
-- general-purpose computing and digital signal processing applications. The
-- 16-bit ALU provides enhanced computational capabilities while maintaining
-- reasonable resource requirements, making it suitable for mid-range FPGA
-- implementations and embedded processors. This implementation demonstrates
-- balanced performance and resource utilization for 16-bit data processing.
--
-- LEARNING OBJECTIVES:
-- 1. Understand 16-bit ALU architecture and scaling considerations
-- 2. Learn enhanced arithmetic and logical operations for wider data paths
-- 3. Practice advanced flag generation for 16-bit operations
-- 4. Understand word-level processing optimization techniques
-- 5. Learn carry-lookahead and fast arithmetic implementation
-- 6. Practice medium-complexity combinational logic design
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
-- - Consider additional packages for optimized 16-bit operations
-- 
-- TODO: Add library IEEE;
-- TODO: Add use IEEE.std_logic_1164.all;
-- TODO: Add use IEEE.numeric_std.all;
-- TODO: Consider adding IEEE.std_logic_arith for extended arithmetic
--
-- ============================================================================
-- STEP 2: ENTITY DECLARATION
-- ============================================================================
-- The entity defines the interface for the 16-bit ALU
--
-- Entity Requirements:
-- - Name: alu_16bit (specific to 16-bit implementation)
-- - Two 16-bit data inputs for operands
-- - 4-bit operation control input to select function
-- - 16-bit result output for computed value
-- - Enhanced flag outputs for status indication
-- - Optional carry input for multi-word operations
--
-- Port Specifications:
-- Data Interface:
-- - a : in std_logic_vector(15 downto 0) (First 16-bit operand)
-- - b : in std_logic_vector(15 downto 0) (Second 16-bit operand)
-- - result : out std_logic_vector(15 downto 0) (16-bit operation result)
-- - carry_in : in std_logic (Carry input for multi-word arithmetic)
--
-- Control Interface:
-- - alu_op : in std_logic_vector(3 downto 0) (Operation select - 16 operations)
-- - enable : in std_logic (ALU enable signal)
-- - mode : in std_logic_vector(1 downto 0) (Operation mode select)
--
-- Status Interface:
-- - zero : out std_logic (Zero flag - result is zero)
-- - carry : out std_logic (Carry flag - arithmetic overflow)
-- - overflow : out std_logic (Overflow flag - signed arithmetic overflow)
-- - negative : out std_logic (Negative flag - result is negative)
-- - parity : out std_logic (Parity flag - even/odd parity)
-- - half_carry : out std_logic (Half carry flag - nibble overflow)
-- - flags : out std_logic_vector(7 downto 0) (Combined flag output)
--
-- ============================================================================
-- STEP 3: 16-BIT ALU OPERATION PRINCIPLES
-- ============================================================================
--
-- Arithmetic Operations (16-bit specific):
-- 1. Addition (ADD)
--    - 16-bit unsigned addition with carry detection
--    - Signed addition with overflow detection
--    - Multi-word arithmetic support via carry_in/carry_out
--    - Fast carry-lookahead implementation for performance
--    - Saturating arithmetic modes for DSP applications
--
-- 2. Subtraction (SUB)
--    - 16-bit two's complement subtraction
--    - Borrow detection and handling
--    - Comparison operation implementation
--    - Absolute difference calculation
--    - Conditional subtraction based on flags
--
-- 3. Multiplication (MUL)
--    - 16x16 bit multiplication producing 32-bit result
--    - Unsigned and signed multiplication variants
--    - Booth algorithm implementation for efficiency
--    - Partial product optimization for FPGA DSP blocks
--    - Multiply-accumulate (MAC) operation support
--
-- 4. Division (DIV)
--    - 16-bit division with quotient and remainder
--    - Non-restoring division algorithm
--    - Division by zero detection and handling
--    - Signed and unsigned division modes
--    - Iterative implementation for resource efficiency
--
-- Logical Operations (16-bit optimized):
-- 1. Bitwise AND
--    - 16-bit parallel AND operation
--    - Masking and bit filtering for word operations
--    - Address alignment checking
--    - Interrupt and status register manipulation
--
-- 2. Bitwise OR
--    - 16-bit parallel OR operation
--    - Bit setting and combination for control words
--    - Flag register manipulation
--    - Multi-bit status indication
--
-- 3. Bitwise XOR
--    - 16-bit parallel XOR operation
--    - Toggle and comparison operations
--    - Checksum and hash calculation
--    - Simple encryption/decryption operations
--
-- 4. Bitwise NOT
--    - 16-bit inversion operation
--    - One's complement generation
--    - Bit mask inversion for 16-bit words
--    - Logical negation implementation
--
-- Shift and Rotate Operations (16-bit specific):
-- 1. Logical Shift Left (SLL)
--    - 1-bit to 15-bit left shift capability
--    - Multiplication by powers of 2 (up to 32768)
--    - Carry flag from MSB
--    - Barrel shifter implementation for single-cycle operation
--
-- 2. Logical Shift Right (SRL)
--    - 1-bit to 15-bit right shift capability
--    - Division by powers of 2 (up to 32768)
--    - Carry flag from LSB
--    - Zero-fill implementation for unsigned operations
--
-- 3. Arithmetic Shift Right (SRA)
--    - Sign-extended right shift for signed numbers
--    - Signed division by powers of 2
--    - Sign bit preservation across all shift amounts
--    - Two's complement compatibility
--
-- 4. Rotate Operations (ROL/ROR)
--    - Circular bit rotation (1-15 positions)
--    - Carry flag integration for extended rotation
--    - Bit pattern manipulation for 16-bit words
--    - Cyclic redundancy check (CRC) support
--
-- Comparison Operations (16-bit optimized):
-- 1. Equality (EQ)
--    - 16-bit parallel comparison
--    - Zero flag generation for branch conditions
--    - String and array comparison support
--    - Address matching operations
--
-- 2. Less Than (LT)
--    - Unsigned and signed comparison for 16-bit values
--    - Magnitude comparison for sorting algorithms
--    - Range checking for array bounds
--    - Threshold detection for control systems
--
-- 3. Greater Than (GT)
--    - Comparison result generation
--    - Flag-based result indication
--    - Limit checking operations
--    - Conditional execution support
--
-- ============================================================================
-- STEP 4: 16-BIT ARCHITECTURE OPTIONS
-- ============================================================================
--
-- OPTION 1: Standard Combinational ALU (Recommended for 16-bit)
-- - Pure combinational logic implementation
-- - Single-cycle operation completion
-- - Optimized carry-lookahead for fast addition
-- - Direct operation selection with case statement
-- - Balanced resource utilization
--
-- OPTION 2: Enhanced 16-bit ALU (Intermediate)
-- - Integrated DSP block utilization for multiplication
-- - Pipeline support for high-frequency operation
-- - Extended instruction set with MAC operations
-- - Advanced flag generation and condition codes
-- - Performance monitoring and debug features
--
-- OPTION 3: Multi-Cycle 16-bit ALU (Advanced)
-- - State machine for complex operations (MUL/DIV)
-- - Shared resources for area optimization
-- - Variable execution time per operation
-- - Interrupt and exception handling support
-- - Power management and clock gating
--
-- OPTION 4: Parallel 16-bit ALU (Expert)
-- - Multiple execution units for parallel operations
-- - SIMD (Single Instruction, Multiple Data) support
-- - Vector processing capabilities
-- - Advanced scheduling and resource arbitration
-- - Custom instruction extensions
--
-- ============================================================================
-- STEP 5: 16-BIT IMPLEMENTATION CONSIDERATIONS
-- ============================================================================
--
-- Resource Optimization:
-- - Utilize FPGA carry chains for efficient 16-bit addition
-- - Leverage DSP blocks for multiplication operations
-- - Share logic between similar operations
-- - Optimize LUT utilization for complex functions
-- - Balance area vs performance trade-offs
--
-- Timing Optimization:
-- - Implement carry-lookahead for fast arithmetic
-- - Minimize critical path for 16-bit operations
-- - Consider pipeline insertion for high-speed operation
-- - Optimize routing and placement constraints
-- - Target specific frequency requirements (100+ MHz)
--
-- Power Optimization:
-- - Clock gating for unused functional units
-- - Operand isolation to reduce switching activity
-- - Dynamic voltage and frequency scaling support
-- - Low-power operation modes for battery applications
-- - Static power reduction through design optimization
--
-- Flag Generation (16-bit specific):
-- - Efficient zero detection (16-input NOR tree)
-- - Carry/borrow flag calculation with lookahead
-- - Overflow detection for 16-bit signed arithmetic
-- - Parity calculation optimization (XOR tree)
-- - Half-carry flag for BCD and packed operations
--
-- ============================================================================
-- STEP 6: 16-BIT ADVANCED FEATURES
-- ============================================================================
--
-- DSP Integration:
-- - Multiply-accumulate (MAC) operations
-- - Saturating arithmetic for signal processing
-- - Fixed-point arithmetic support
-- - FIR filter coefficient processing
-- - Digital signal processing primitives
--
-- Vector Operations:
-- - Packed 8-bit operations (2x8-bit in 16-bit word)
-- - SIMD arithmetic and logical operations
-- - Parallel comparison operations
-- - Vector dot product calculation
-- - Image and audio processing support
--
-- Conditional Operations:
-- - Predicated execution based on condition codes
-- - Conditional flag updates
-- - Branch-free operation selection
-- - Performance optimization for control flow
-- - Speculative execution support
--
-- Multi-Word Support:
-- - Carry chain for 32/64/128-bit operations
-- - Big-endian and little-endian byte ordering
-- - Word and byte swapping operations
-- - Multi-precision arithmetic building blocks
-- - Extended precision floating-point support
--
-- ============================================================================
-- APPLICATIONS:
-- ============================================================================
-- 1. Microprocessor Design: 16-bit CPU arithmetic core
-- 2. Digital Signal Processing: Audio and image processing
-- 3. Control Systems: Real-time 16-bit calculations
-- 4. Communication Systems: Protocol processing and checksums
-- 5. Graphics Processing: Pixel and coordinate calculations
-- 6. Embedded Systems: Mid-range computational requirements
-- 7. Industrial Control: Sensor data processing and control
-- 8. Automotive Systems: Engine control and diagnostics
--
-- ============================================================================
-- TESTING STRATEGY:
-- ============================================================================
-- 1. Boundary Testing: 0x0000, 0xFFFF, 0x7FFF, 0x8000 values
-- 2. Arithmetic Testing: Comprehensive operation verification
-- 3. Flag Testing: All flag combinations and edge cases
-- 4. Carry Testing: Multi-word operation validation
-- 5. Overflow Testing: Signed arithmetic boundary conditions
-- 6. Performance Testing: Timing analysis and optimization
-- 7. Power Testing: Current consumption across operations
-- 8. Stress Testing: Continuous operation and thermal analysis
--
-- ============================================================================
-- RECOMMENDED IMPLEMENTATION APPROACH:
-- ============================================================================
-- 1. Start with basic arithmetic (ADD, SUB) with carry-lookahead
-- 2. Implement logical operations (AND, OR, XOR, NOT)
-- 3. Add comparison operations and comprehensive flag generation
-- 4. Implement shift operations with barrel shifter
-- 5. Add multiplication using DSP blocks or optimized logic
-- 6. Implement division algorithm (if required)
-- 7. Optimize for target FPGA architecture and timing
-- 8. Add advanced features based on application requirements
--
-- ============================================================================
-- EXTENSION EXERCISES:
-- ============================================================================
-- 1. Implement multiply-accumulate (MAC) operations
-- 2. Add saturating arithmetic modes for DSP
-- 3. Implement packed 8-bit SIMD operations
-- 4. Add floating-point arithmetic support
-- 5. Implement conditional execution and predication
-- 6. Add vector processing capabilities
-- 7. Implement custom application-specific operations
-- 8. Add hardware debugging and performance monitoring
--
-- ============================================================================
-- COMMON MISTAKES TO AVOID:
-- ============================================================================
-- 1. Inefficient carry propagation in 16-bit arithmetic
-- 2. Improper overflow detection for signed operations
-- 3. Missing optimization for FPGA-specific resources
-- 4. Inadequate timing closure for high-speed operation
-- 5. Incorrect flag generation for boundary conditions
-- 6. Poor resource utilization for multiplication
-- 7. Missing multi-word operation support
-- 8. Inadequate test coverage for 16-bit value ranges
--
-- ============================================================================
-- DESIGN VERIFICATION CHECKLIST:
-- ============================================================================
-- □ All 16-bit arithmetic operations produce correct results
-- □ Logical operations function properly for all bit patterns
-- □ Shift and rotate operations work correctly (1-15 positions)
-- □ Flag generation is accurate for all 16-bit values
-- □ Overflow and underflow conditions handled correctly
-- □ Carry propagation works for multi-word operations
-- □ Multiplication produces correct 32-bit results
-- □ Division handles all cases including divide-by-zero
-- □ Timing requirements are met for target frequency
-- □ Resource utilization is optimized for 16-bit operations
--
-- ============================================================================
-- DIGITAL DESIGN CONTEXT:
-- ============================================================================
-- This 16-bit ALU implementation demonstrates:
-- - Scalable combinational logic design for medium data widths
-- - Advanced arithmetic implementation with carry-lookahead
-- - DSP block integration for efficient multiplication
-- - Comprehensive flag generation for processor integration
-- - Performance optimization for mid-range FPGA targets
--
-- ============================================================================
-- PHYSICAL IMPLEMENTATION NOTES:
-- ============================================================================
-- - Utilize FPGA carry chains and DSP blocks effectively
-- - Consider dedicated multiplier resources for MUL operations
-- - Plan for balanced routing and minimal congestion
-- - Optimize for both area and timing constraints
-- - Consider power distribution and thermal management
--
-- ============================================================================
-- ADVANCED CONCEPTS:
-- ============================================================================
-- - Carry-select and carry-skip adder architectures
-- - Wallace tree and Dadda multiplier implementations
-- - Booth recoding for signed multiplication
-- - SRT division algorithm for improved performance
-- - Redundant binary arithmetic for speed optimization
--
-- ============================================================================
-- SIMULATION AND VERIFICATION NOTES:
-- ============================================================================
-- - Use directed and random test vectors for comprehensive coverage
-- - Verify flag generation for all boundary and corner cases
-- - Test carry propagation and multi-word arithmetic
-- - Validate timing relationships and critical path analysis
-- - Check resource utilization and power consumption
-- - Verify operation across process, voltage, and temperature
--
-- ============================================================================
-- IMPLEMENTATION TEMPLATE:
-- ============================================================================
-- Use this template as a starting point for your 16-bit ALU implementation:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity alu_16bit is
    generic (
        ENABLE_MUL      : boolean := true;      -- Enable 16x16 multiplication
        ENABLE_DIV      : boolean := false;     -- Enable 16-bit division
        ENABLE_MAC      : boolean := false;     -- Enable multiply-accumulate
        ENABLE_SATURATE : boolean := false;     -- Enable saturating arithmetic
        ENABLE_SIMD     : boolean := false;     -- Enable packed 8-bit operations
        PIPELINE_STAGES : integer := 0          -- Pipeline depth (0 = combinational)
    );
    port (
        -- System Interface
        clk         : in  std_logic;
        reset       : in  std_logic;
        enable      : in  std_logic;
        
        -- Data Interface (16-bit)
        a           : in  std_logic_vector(15 downto 0);
        b           : in  std_logic_vector(15 downto 0);
        result      : out std_logic_vector(15 downto 0);
        
        -- Control Interface
        alu_op      : in  std_logic_vector(3 downto 0);  -- 16 operations
        mode        : in  std_logic_vector(1 downto 0);  -- Operation mode
        carry_in    : in  std_logic;
        
        -- Status Interface
        zero        : out std_logic;
        carry       : out std_logic;
        overflow    : out std_logic;
        negative    : out std_logic;
        parity      : out std_logic;
        half_carry  : out std_logic;
        flags       : out std_logic_vector(7 downto 0);
        
        -- Extended Interface
        result_hi   : out std_logic_vector(15 downto 0); -- High word for MUL
        accumulator : in  std_logic_vector(31 downto 0); -- MAC accumulator input
        acc_out     : out std_logic_vector(31 downto 0); -- MAC accumulator output
        valid       : out std_logic;                      -- Result valid
        ready       : out std_logic                       -- Ready for operation
    );
end entity alu_16bit;

architecture behavioral of alu_16bit is
    -- 16-bit ALU Operation codes
    constant ALU_ADD    : std_logic_vector(3 downto 0) := "0000";  -- Addition
    constant ALU_SUB    : std_logic_vector(3 downto 0) := "0001";  -- Subtraction
    constant ALU_AND    : std_logic_vector(3 downto 0) := "0010";  -- Bitwise AND
    constant ALU_OR     : std_logic_vector(3 downto 0) := "0011";  -- Bitwise OR
    constant ALU_XOR    : std_logic_vector(3 downto 0) := "0100";  -- Bitwise XOR
    constant ALU_NOT    : std_logic_vector(3 downto 0) := "0101";  -- Bitwise NOT
    constant ALU_SLL    : std_logic_vector(3 downto 0) := "0110";  -- Shift Left Logical
    constant ALU_SRL    : std_logic_vector(3 downto 0) := "0111";  -- Shift Right Logical
    constant ALU_SRA    : std_logic_vector(3 downto 0) := "1000";  -- Shift Right Arithmetic
    constant ALU_ROL    : std_logic_vector(3 downto 0) := "1001";  -- Rotate Left
    constant ALU_ROR    : std_logic_vector(3 downto 0) := "1010";  -- Rotate Right
    constant ALU_CMP    : std_logic_vector(3 downto 0) := "1011";  -- Compare
    constant ALU_MUL    : std_logic_vector(3 downto 0) := "1100";  -- Multiply
    constant ALU_DIV    : std_logic_vector(3 downto 0) := "1101";  -- Divide
    constant ALU_MAC    : std_logic_vector(3 downto 0) := "1110";  -- Multiply-Accumulate
    constant ALU_PASS   : std_logic_vector(3 downto 0) := "1111";  -- Pass through A
    
    -- Operation modes
    constant MODE_NORMAL   : std_logic_vector(1 downto 0) := "00";  -- Normal operation
    constant MODE_SATURATE : std_logic_vector(1 downto 0) := "01";  -- Saturating arithmetic
    constant MODE_SIMD     : std_logic_vector(1 downto 0) := "10";  -- SIMD 8-bit operations
    constant MODE_EXTENDED : std_logic_vector(1 downto 0) := "11";  -- Extended precision
    
    -- Internal signals
    signal result_int     : std_logic_vector(15 downto 0);
    signal result_ext     : std_logic_vector(16 downto 0);  -- Extended for carry
    signal result_hi_int  : std_logic_vector(15 downto 0);
    signal acc_out_int    : std_logic_vector(31 downto 0);
    signal zero_int       : std_logic;
    signal carry_int      : std_logic;
    signal overflow_int   : std_logic;
    signal negative_int   : std_logic;
    signal parity_int     : std_logic;
    signal half_carry_int : std_logic;
    
    -- Arithmetic operation signals
    signal add_result     : std_logic_vector(16 downto 0);
    signal sub_result     : std_logic_vector(16 downto 0);
    signal mul_result     : std_logic_vector(31 downto 0);
    signal div_quotient   : std_logic_vector(15 downto 0);
    signal div_remainder  : std_logic_vector(15 downto 0);
    signal mac_result     : std_logic_vector(31 downto 0);
    
    -- Shift operation signals
    signal shift_amount   : integer range 0 to 15;
    signal sll_result     : std_logic_vector(15 downto 0);
    signal srl_result     : std_logic_vector(15 downto 0);
    signal sra_result     : std_logic_vector(15 downto 0);
    signal rol_result     : std_logic_vector(15 downto 0);
    signal ror_result     : std_logic_vector(15 downto 0);
    
    -- SIMD operation signals
    signal simd_add_result : std_logic_vector(15 downto 0);
    signal simd_sub_result : std_logic_vector(15 downto 0);
    signal simd_and_result : std_logic_vector(15 downto 0);
    signal simd_or_result  : std_logic_vector(15 downto 0);
    signal simd_xor_result : std_logic_vector(15 downto 0);
    
    -- Saturating arithmetic signals
    signal sat_add_result : std_logic_vector(15 downto 0);
    signal sat_sub_result : std_logic_vector(15 downto 0);
    
    -- Pipeline registers (if enabled)
    type pipeline_array is array (0 to PIPELINE_STAGES) of std_logic_vector(15 downto 0);
    signal pipeline_data  : pipeline_array;
    signal pipeline_valid : std_logic_vector(PIPELINE_STAGES downto 0);
    
begin
    -- 16-bit Arithmetic operations with carry-lookahead
    add_result <= std_logic_vector(unsigned('0' & a) + unsigned('0' & b) + unsigned'("" & carry_in));
    sub_result <= std_logic_vector(unsigned('0' & a) - unsigned('0' & b) - unsigned'("" & (not carry_in)));
    
    -- 16x16 Multiplication
    mul_gen: if ENABLE_MUL generate
        mul_result <= std_logic_vector(unsigned(a) * unsigned(b));
    end generate;
    
    -- MAC operation (if enabled)
    mac_gen: if ENABLE_MAC generate
        mac_result <= std_logic_vector(unsigned(mul_result) + unsigned(accumulator));
    end generate;
    
    -- Division (if enabled)
    div_gen: if ENABLE_DIV generate
        division_process: process(a, b)
        begin
            if unsigned(b) /= 0 then
                div_quotient <= std_logic_vector(unsigned(a) / unsigned(b));
                div_remainder <= std_logic_vector(unsigned(a) mod unsigned(b));
            else
                div_quotient <= (others => '1');  -- Error condition
                div_remainder <= (others => '0');
            end if;
        end process;
    end generate;
    
    -- Saturating arithmetic (if enabled)
    saturate_gen: if ENABLE_SATURATE generate
        saturating_arithmetic: process(a, b, carry_in, add_result, sub_result)
        begin
            -- Saturating addition
            if add_result(16) = '1' then  -- Overflow
                sat_add_result <= (others => '1');  -- Saturate to maximum
            else
                sat_add_result <= add_result(15 downto 0);
            end if;
            
            -- Saturating subtraction
            if sub_result(16) = '1' then  -- Underflow
                sat_sub_result <= (others => '0');  -- Saturate to minimum
            else
                sat_sub_result <= sub_result(15 downto 0);
            end if;
        end process;
    end generate;
    
    -- SIMD 8-bit operations (if enabled)
    simd_gen: if ENABLE_SIMD generate
        simd_operations: process(a, b)
            variable a_lo, a_hi, b_lo, b_hi : unsigned(7 downto 0);
            variable add_lo, add_hi : unsigned(8 downto 0);
            variable sub_lo, sub_hi : unsigned(8 downto 0);
        begin
            -- Split 16-bit operands into 8-bit parts
            a_lo := unsigned(a(7 downto 0));
            a_hi := unsigned(a(15 downto 8));
            b_lo := unsigned(b(7 downto 0));
            b_hi := unsigned(b(15 downto 8));
            
            -- Parallel 8-bit operations
            add_lo := ('0' & a_lo) + ('0' & b_lo);
            add_hi := ('0' & a_hi) + ('0' & b_hi);
            sub_lo := ('0' & a_lo) - ('0' & b_lo);
            sub_hi := ('0' & a_hi) - ('0' & b_hi);
            
            -- Pack results back to 16-bit
            simd_add_result <= std_logic_vector(add_hi(7 downto 0)) & std_logic_vector(add_lo(7 downto 0));
            simd_sub_result <= std_logic_vector(sub_hi(7 downto 0)) & std_logic_vector(sub_lo(7 downto 0));
            simd_and_result <= (a(15 downto 8) and b(15 downto 8)) & (a(7 downto 0) and b(7 downto 0));
            simd_or_result  <= (a(15 downto 8) or b(15 downto 8)) & (a(7 downto 0) or b(7 downto 0));
            simd_xor_result <= (a(15 downto 8) xor b(15 downto 8)) & (a(7 downto 0) xor b(7 downto 0));
        end process;
    end generate;
    
    -- Shift amount extraction (from lower 4 bits of operand b for 16-bit)
    shift_amount <= to_integer(unsigned(b(3 downto 0)));
    
    -- Shift operations with barrel shifter
    sll_result <= std_logic_vector(shift_left(unsigned(a), shift_amount));
    srl_result <= std_logic_vector(shift_right(unsigned(a), shift_amount));
    sra_result <= std_logic_vector(shift_right(signed(a), shift_amount));
    
    -- Rotate operations
    rol_result <= std_logic_vector(rotate_left(unsigned(a), shift_amount));
    ror_result <= std_logic_vector(rotate_right(unsigned(a), shift_amount));
    
    -- Main 16-bit ALU operation selection
    alu_operation: process(alu_op, mode, a, b, carry_in, add_result, sub_result, mul_result, 
                          div_quotient, div_remainder, mac_result, sll_result, srl_result, 
                          sra_result, rol_result, ror_result, sat_add_result, sat_sub_result,
                          simd_add_result, simd_sub_result, simd_and_result, simd_or_result, 
                          simd_xor_result, accumulator)
    begin
        result_int <= (others => '0');
        result_hi_int <= (others => '0');
        result_ext <= (others => '0');
        acc_out_int <= (others => '0');
        
        case alu_op is
            when ALU_ADD =>
                case mode is
                    when MODE_NORMAL =>
                        result_int <= add_result(15 downto 0);
                        result_ext <= add_result;
                    when MODE_SATURATE =>
                        if ENABLE_SATURATE then
                            result_int <= sat_add_result;
                            result_ext <= '0' & sat_add_result;
                        end if;
                    when MODE_SIMD =>
                        if ENABLE_SIMD then
                            result_int <= simd_add_result;
                            result_ext <= '0' & simd_add_result;
                        end if;
                    when others =>
                        result_int <= add_result(15 downto 0);
                        result_ext <= add_result;
                end case;
                
            when ALU_SUB =>
                case mode is
                    when MODE_NORMAL =>
                        result_int <= sub_result(15 downto 0);
                        result_ext <= sub_result;
                    when MODE_SATURATE =>
                        if ENABLE_SATURATE then
                            result_int <= sat_sub_result;
                            result_ext <= '0' & sat_sub_result;
                        end if;
                    when MODE_SIMD =>
                        if ENABLE_SIMD then
                            result_int <= simd_sub_result;
                            result_ext <= '0' & simd_sub_result;
                        end if;
                    when others =>
                        result_int <= sub_result(15 downto 0);
                        result_ext <= sub_result;
                end case;
                
            when ALU_AND =>
                if mode = MODE_SIMD and ENABLE_SIMD then
                    result_int <= simd_and_result;
                else
                    result_int <= a and b;
                end if;
                result_ext <= '0' & result_int;
                
            when ALU_OR =>
                if mode = MODE_SIMD and ENABLE_SIMD then
                    result_int <= simd_or_result;
                else
                    result_int <= a or b;
                end if;
                result_ext <= '0' & result_int;
                
            when ALU_XOR =>
                if mode = MODE_SIMD and ENABLE_SIMD then
                    result_int <= simd_xor_result;
                else
                    result_int <= a xor b;
                end if;
                result_ext <= '0' & result_int;
                
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
                    result_int <= x"0001";
                else
                    result_int <= x"0000";
                end if;
                result_ext <= '0' & result_int;
                
            when ALU_MUL =>
                if ENABLE_MUL then
                    result_int <= mul_result(15 downto 0);
                    result_hi_int <= mul_result(31 downto 16);
                    result_ext <= '0' & mul_result(15 downto 0);
                end if;
                
            when ALU_DIV =>
                if ENABLE_DIV then
                    result_int <= div_quotient;
                    result_hi_int <= div_remainder;
                    result_ext <= '0' & div_quotient;
                end if;
                
            when ALU_MAC =>
                if ENABLE_MAC then
                    result_int <= mac_result(15 downto 0);
                    result_hi_int <= mac_result(31 downto 16);
                    acc_out_int <= mac_result;
                    result_ext <= '0' & mac_result(15 downto 0);
                end if;
                
            when ALU_PASS =>
                result_int <= a;
                result_ext <= '0' & a;
                
            when others =>
                result_int <= (others => '0');
                result_ext <= (others => '0');
        end case;
    end process;
    
    -- 16-bit Flag generation
    flag_generation: process(result_int, result_ext, a, b, alu_op, add_result)
        variable parity_calc : std_logic;
    begin
        -- Zero flag (16-bit specific)
        zero_int <= '1' when unsigned(result_int) = 0 else '0';
        
        -- Carry flag
        carry_int <= result_ext(16);
        
        -- Half carry flag (carry from bit 7 to bit 8)
        half_carry_int <= '0';
        if alu_op = ALU_ADD then
            half_carry_int <= add_result(8);
        end if;
        
        -- Overflow flag (for 16-bit signed arithmetic)
        overflow_int <= '0';
        if alu_op = ALU_ADD then
            overflow_int <= (a(15) and b(15) and not result_int(15)) or
                           (not a(15) and not b(15) and result_int(15));
        elsif alu_op = ALU_SUB then
            overflow_int <= (a(15) and not b(15) and not result_int(15)) or
                           (not a(15) and b(15) and result_int(15));
        end if;
        
        -- Negative flag (MSB of 16-bit result)
        negative_int <= result_int(15);
        
        -- Parity flag (even parity for 16-bit)
        parity_calc := '0';
        for i in 0 to 15 loop
            parity_calc := parity_calc xor result_int(i);
        end loop;
        parity_int <= not parity_calc;  -- Even parity
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
                    for i in PIPELINE_STAGES downto 1 loop
                        pipeline_data(i) <= pipeline_data(i-1);
                        pipeline_valid(i) <= pipeline_valid(i-1);
                    end loop;
                    
                    -- Insert new data
                    pipeline_data(0) <= result_int;
                    pipeline_valid(0) <= '1';
                end if;
            end if;
        end process;
        
        -- Output from pipeline
        result <= pipeline_data(PIPELINE_STAGES);
        valid <= pipeline_valid(PIPELINE_STAGES);
        ready <= '1';  -- Always ready for new operations
    end generate;
    
    -- Combinational output (if no pipeline)
    no_pipeline_gen: if PIPELINE_STAGES = 0 generate
        result <= result_int when enable = '1' else (others => '0');
        valid <= enable;
        ready <= '1';
    end generate;
    
    -- Output assignments
    result_hi <= result_hi_int;
    acc_out <= acc_out_int;
    zero <= zero_int when enable = '1' else '0';
    carry <= carry_int when enable = '1' else '0';
    overflow <= overflow_int when enable = '1' else '0';
    negative <= negative_int when enable = '1' else '0';
    parity <= parity_int when enable = '1' else '0';
    half_carry <= half_carry_int when enable = '1' else '0';
    
    -- Combined flags output (16-bit specific)
    flags <= overflow_int & negative_int & zero_int & carry_int & 
             parity_int & half_carry_int & "00" when enable = '1' else (others => '0');
    
end architecture behavioral;

-- ============================================================================
-- Remember: This 16-bit ALU implementation provides enhanced computational
-- capabilities suitable for general-purpose processors and DSP applications.
-- The design balances performance and resource utilization while offering
-- advanced features like SIMD operations, saturating arithmetic, and MAC
-- support. Ensure proper verification of all operations, timing closure,
-- and resource optimization for your target FPGA platform.
-- ============================================================================