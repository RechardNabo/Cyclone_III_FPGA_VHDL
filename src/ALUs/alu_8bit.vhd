-- ============================================================================
-- 8-Bit Arithmetic Logic Unit (ALU) Implementation - Programming Guidance
-- ============================================================================
-- 
-- PROJECT OVERVIEW:
-- This file implements an 8-bit Arithmetic Logic Unit (ALU) optimized for
-- embedded systems and microcontroller applications. The 8-bit ALU performs
-- essential arithmetic and logical operations with minimal resource usage,
-- making it ideal for FPGA implementations where area and power efficiency
-- are critical. This implementation demonstrates fundamental ALU concepts
-- while providing practical functionality for 8-bit data processing systems.
--
-- LEARNING OBJECTIVES:
-- 1. Understand 8-bit ALU architecture and design constraints
-- 2. Learn resource-efficient arithmetic and logical operations
-- 3. Practice flag generation for 8-bit data widths
-- 4. Understand byte-level processing optimization
-- 5. Learn area-optimized combinational logic design
-- 6. Practice embedded system ALU implementation
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
-- - Consider additional packages for optimized 8-bit operations
-- 
-- TODO: Add library IEEE;
-- TODO: Add use IEEE.std_logic_1164.all;
-- TODO: Add use IEEE.numeric_std.all;
-- TODO: Consider adding IEEE.std_logic_unsigned for simplified arithmetic
--
-- ============================================================================
-- STEP 2: ENTITY DECLARATION
-- ============================================================================
-- The entity defines the interface for the 8-bit ALU
--
-- Entity Requirements:
-- - Name: alu_8bit (specific to 8-bit implementation)
-- - Two 8-bit data inputs for operands
-- - 4-bit operation control input to select function
-- - 8-bit result output for computed value
-- - Flag outputs for status indication
-- - Optional carry input for multi-byte operations
--
-- Port Specifications:
-- Data Interface:
-- - a : in std_logic_vector(7 downto 0) (First 8-bit operand)
-- - b : in std_logic_vector(7 downto 0) (Second 8-bit operand)
-- - result : out std_logic_vector(7 downto 0) (8-bit operation result)
-- - carry_in : in std_logic (Carry input for multi-byte arithmetic)
--
-- Control Interface:
-- - alu_op : in std_logic_vector(3 downto 0) (Operation select - 16 operations)
-- - enable : in std_logic (ALU enable signal)
--
-- Status Interface:
-- - zero : out std_logic (Zero flag - result is zero)
-- - carry : out std_logic (Carry flag - arithmetic overflow)
-- - overflow : out std_logic (Overflow flag - signed arithmetic overflow)
-- - negative : out std_logic (Negative flag - result is negative)
-- - parity : out std_logic (Parity flag - even/odd parity)
-- - flags : out std_logic_vector(7 downto 0) (Combined flag output)
--
-- ============================================================================
-- STEP 3: 8-BIT ALU OPERATION PRINCIPLES
-- ============================================================================
--
-- Arithmetic Operations (8-bit specific):
-- 1. Addition (ADD)
--    - 8-bit unsigned addition with carry detection
--    - Signed addition with overflow detection
--    - Multi-byte arithmetic support via carry_in/carry_out
--    - BCD addition support for decimal applications
--
-- 2. Subtraction (SUB)
--    - 8-bit two's complement subtraction
--    - Borrow detection and handling
--    - Comparison operation implementation
--    - Absolute difference calculation
--
-- 3. Increment/Decrement (INC/DEC)
--    - Efficient single-operand operations
--    - Counter and pointer arithmetic
--    - Minimal resource utilization
--    - Flag generation for boundary conditions
--
-- 4. Multiplication (MUL) - Optional
--    - 8x8 bit multiplication producing 16-bit result
--    - Unsigned and signed multiplication variants
--    - Partial product optimization for FPGA
--    - Resource sharing with addition logic
--
-- Logical Operations (8-bit optimized):
-- 1. Bitwise AND
--    - 8-bit parallel AND operation
--    - Masking and bit filtering
--    - Power-of-2 alignment checking
--    - Flag generation for logical operations
--
-- 2. Bitwise OR
--    - 8-bit parallel OR operation
--    - Bit setting and combination
--    - Status register manipulation
--    - Interrupt flag processing
--
-- 3. Bitwise XOR
--    - 8-bit parallel XOR operation
--    - Toggle and comparison operations
--    - Parity calculation and checking
--    - Simple encryption/decryption
--
-- 4. Bitwise NOT
--    - 8-bit inversion operation
--    - One's complement generation
--    - Bit mask inversion
--    - Logical negation implementation
--
-- Shift and Rotate Operations (8-bit specific):
-- 1. Logical Shift Left (SLL)
--    - 1-bit to 7-bit left shift capability
--    - Multiplication by powers of 2
--    - Carry flag from MSB
--    - Efficient barrel shifter implementation
--
-- 2. Logical Shift Right (SRL)
--    - 1-bit to 7-bit right shift capability
--    - Division by powers of 2
--    - Carry flag from LSB
--    - Zero-fill implementation
--
-- 3. Arithmetic Shift Right (SRA)
--    - Sign-extended right shift
--    - Signed division by powers of 2
--    - Sign bit preservation
--    - Two's complement compatibility
--
-- 4. Rotate Operations (ROL/ROR)
--    - Circular bit rotation (1-7 positions)
--    - Carry flag integration
--    - Bit pattern manipulation
--    - Cyclic redundancy check support
--
-- Comparison Operations (8-bit optimized):
-- 1. Equality (EQ)
--    - 8-bit parallel comparison
--    - Zero flag generation
--    - Branch condition support
--    - String/array comparison
--
-- 2. Less Than (LT)
--    - Unsigned and signed comparison
--    - Magnitude comparison for sorting
--    - Conditional operation support
--    - Range checking applications
--
-- 3. Greater Than (GT)
--    - Comparison result generation
--    - Flag-based result indication
--    - Threshold detection
--    - Limit checking operations
--
-- ============================================================================
-- STEP 4: 8-BIT ARCHITECTURE OPTIONS
-- ============================================================================
--
-- OPTION 1: Minimal Combinational ALU (Recommended for 8-bit)
-- - Pure combinational logic implementation
-- - Single-cycle operation completion
-- - Minimal FPGA resource usage
-- - Direct operation selection with case statement
-- - Optimized for embedded applications
--
-- OPTION 2: Enhanced 8-bit ALU (Intermediate)
-- - Additional BCD arithmetic support
-- - Extended shift/rotate capabilities
-- - Nibble-level operation support
-- - Enhanced flag generation
-- - Microcontroller compatibility features
--
-- OPTION 3: Multi-Function 8-bit ALU (Advanced)
-- - Integrated multiply-accumulate (MAC)
-- - Bit manipulation instructions
-- - Conditional execution support
-- - Performance monitoring counters
-- - Debug and trace capabilities
--
-- OPTION 4: Specialized 8-bit ALU (Expert)
-- - Application-specific operations
-- - Cryptographic primitive support
-- - DSP-oriented enhancements
-- - Custom instruction extensions
-- - Hardware acceleration features
--
-- ============================================================================
-- STEP 5: 8-BIT IMPLEMENTATION CONSIDERATIONS
-- ============================================================================
--
-- Resource Optimization:
-- - Minimize LUT usage for 8-bit operations
-- - Share logic between similar operations
-- - Optimize carry chain utilization
-- - Consider FPGA-specific primitives
-- - Balance area vs performance trade-offs
--
-- Timing Optimization:
-- - Minimize critical path for 8-bit operations
-- - Optimize carry propagation delay
-- - Consider pipeline insertion for high-speed
-- - Balance logic depth across operations
-- - Target specific frequency requirements
--
-- Power Optimization:
-- - Clock gating for unused operations
-- - Operand isolation techniques
-- - Minimize switching activity
-- - Low-power operation modes
-- - Static power reduction strategies
--
-- Flag Generation (8-bit specific):
-- - Efficient zero detection (8-input NOR)
-- - Carry/borrow flag calculation
-- - Overflow detection for 8-bit signed arithmetic
-- - Parity calculation optimization
-- - Combined flag output generation
--
-- ============================================================================
-- STEP 6: 8-BIT ADVANCED FEATURES
-- ============================================================================
--
-- BCD Arithmetic Support:
-- - Binary-coded decimal addition/subtraction
-- - Decimal adjust operations
-- - Multi-digit BCD processing
-- - Calculator and display applications
--
-- Bit Manipulation:
-- - Single bit set/clear/toggle operations
-- - Bit field extraction and insertion
-- - Population count (number of 1s)
-- - Leading zero detection
--
-- Conditional Operations:
-- - Predicated execution based on flags
-- - Conditional flag updates
-- - Branch-free operation selection
-- - Performance optimization techniques
--
-- Multi-Byte Support:
-- - Carry chain for 16/32/64-bit operations
-- - Big-endian and little-endian support
-- - Byte-swapping operations
-- - Multi-precision arithmetic building blocks
--
-- ============================================================================
-- APPLICATIONS:
-- ============================================================================
-- 1. Microcontroller Design: 8-bit processor arithmetic core
-- 2. Embedded Systems: Resource-constrained computational units
-- 3. IoT Devices: Low-power arithmetic processing
-- 4. Control Systems: Real-time 8-bit calculations
-- 5. Communication Protocols: Checksum and CRC calculations
-- 6. Display Controllers: Pixel and color processing
-- 7. Sensor Interfaces: ADC/DAC data processing
-- 8. Motor Control: PWM and feedback calculations
--
-- ============================================================================
-- TESTING STRATEGY:
-- ============================================================================
-- 1. Boundary Testing: 0x00, 0xFF, 0x7F, 0x80 values
-- 2. Arithmetic Testing: All combinations for small operations
-- 3. Flag Testing: Comprehensive flag generation validation
-- 4. Carry Testing: Multi-byte operation verification
-- 5. Overflow Testing: Signed arithmetic edge cases
-- 6. Performance Testing: Timing and resource analysis
-- 7. Power Testing: Current consumption measurement
-- 8. Temperature Testing: Operation across temperature range
--
-- ============================================================================
-- RECOMMENDED IMPLEMENTATION APPROACH:
-- ============================================================================
-- 1. Start with basic arithmetic (ADD, SUB, INC, DEC)
-- 2. Implement logical operations (AND, OR, XOR, NOT)
-- 3. Add comparison operations and flag generation
-- 4. Implement shift operations (SLL, SRL, SRA)
-- 5. Add rotate operations if needed
-- 6. Optimize for target FPGA resources
-- 7. Add advanced features based on application needs
-- 8. Validate with comprehensive test patterns
--
-- ============================================================================
-- EXTENSION EXERCISES:
-- ============================================================================
-- 1. Implement BCD arithmetic operations
-- 2. Add bit manipulation instruction set
-- 3. Implement saturating arithmetic modes
-- 4. Add lookup table (LUT) based operations
-- 5. Implement conditional execution support
-- 6. Add hardware multiply-accumulate (MAC)
-- 7. Implement custom application-specific operations
-- 8. Add performance monitoring and debug features
--
-- ============================================================================
-- COMMON MISTAKES TO AVOID:
-- ============================================================================
-- 1. Incorrect carry propagation in 8-bit arithmetic
-- 2. Improper overflow detection for signed operations
-- 3. Missing edge case handling (0x00, 0xFF)
-- 4. Inefficient resource utilization for simple operations
-- 5. Incorrect flag generation for boundary conditions
-- 6. Poor timing optimization for critical paths
-- 7. Missing multi-byte operation support
-- 8. Inadequate test coverage for 8-bit ranges
--
-- ============================================================================
-- DESIGN VERIFICATION CHECKLIST:
-- ============================================================================
-- □ All 8-bit arithmetic operations produce correct results
-- □ Logical operations function properly for all bit patterns
-- □ Shift and rotate operations work correctly (1-7 positions)
-- □ Flag generation is accurate for all 8-bit values
-- □ Overflow and underflow conditions handled correctly
-- □ Carry propagation works for multi-byte operations
-- □ Operation encoding/decoding is correct
-- □ Timing requirements are met for target frequency
-- □ Resource utilization is optimized for 8-bit operations
-- □ Test coverage includes all 256 possible 8-bit values
--
-- ============================================================================
-- DIGITAL DESIGN CONTEXT:
-- ============================================================================
-- This 8-bit ALU implementation demonstrates:
-- - Efficient combinational logic design for small data widths
-- - Resource optimization techniques for FPGA implementation
-- - Flag generation and status indication for embedded systems
-- - Multi-byte operation support through carry chaining
-- - Power-efficient design for battery-powered applications
--
-- ============================================================================
-- PHYSICAL IMPLEMENTATION NOTES:
-- ============================================================================
-- - Utilize FPGA carry chains for efficient 8-bit addition
-- - Consider LUT-based implementation for complex operations
-- - Plan for minimal routing congestion
-- - Optimize for low static and dynamic power consumption
-- - Consider temperature and voltage variations
--
-- ============================================================================
-- ADVANCED CONCEPTS:
-- ============================================================================
-- - Carry-select adder for improved performance
-- - Parallel prefix networks for fast carry generation
-- - Booth recoding for efficient multiplication
-- - Redundant binary representation
-- - Approximate computing for power efficiency
--
-- ============================================================================
-- SIMULATION AND VERIFICATION NOTES:
-- ============================================================================
-- - Test all 65536 possible input combinations for thorough verification
-- - Verify flag generation for all boundary conditions
-- - Test carry propagation and multi-byte operations
-- - Validate timing relationships and setup/hold requirements
-- - Check resource utilization and power consumption
-- - Verify operation across temperature and voltage ranges
--
-- ============================================================================
-- IMPLEMENTATION TEMPLATE:
-- ============================================================================
-- Use this template as a starting point for your 8-bit ALU implementation:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity alu_8bit is
    generic (
        ENABLE_MUL    : boolean := false;     -- Enable 8x8 multiplication
        ENABLE_DIV    : boolean := false;     -- Enable 8-bit division
        ENABLE_BCD    : boolean := false;     -- Enable BCD arithmetic
        ENABLE_ROTATE : boolean := true;      -- Enable rotate operations
        ENABLE_BITMAN : boolean := false      -- Enable bit manipulation
    );
    port (
        -- System Interface
        clk         : in  std_logic;
        reset       : in  std_logic;
        enable      : in  std_logic;
        
        -- Data Interface (8-bit)
        a           : in  std_logic_vector(7 downto 0);
        b           : in  std_logic_vector(7 downto 0);
        result      : out std_logic_vector(7 downto 0);
        
        -- Control Interface
        alu_op      : in  std_logic_vector(3 downto 0);  -- 16 operations
        carry_in    : in  std_logic;
        
        -- Status Interface
        zero        : out std_logic;
        carry       : out std_logic;
        overflow    : out std_logic;
        negative    : out std_logic;
        parity      : out std_logic;
        flags       : out std_logic_vector(7 downto 0);
        
        -- Extended Interface (optional)
        result_hi   : out std_logic_vector(7 downto 0);  -- High byte for MUL
        bcd_carry   : out std_logic;                      -- BCD carry out
        valid       : out std_logic;                      -- Result valid
        ready       : out std_logic                       -- Ready for operation
    );
end entity alu_8bit;

architecture behavioral of alu_8bit is
    -- 8-bit ALU Operation codes
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
    constant ALU_INC    : std_logic_vector(3 downto 0) := "1100";  -- Increment
    constant ALU_DEC    : std_logic_vector(3 downto 0) := "1101";  -- Decrement
    constant ALU_MUL    : std_logic_vector(3 downto 0) := "1110";  -- Multiply (if enabled)
    constant ALU_PASS   : std_logic_vector(3 downto 0) := "1111";  -- Pass through A
    
    -- Internal signals
    signal result_int     : std_logic_vector(7 downto 0);
    signal result_ext     : std_logic_vector(8 downto 0);  -- Extended for carry
    signal result_hi_int  : std_logic_vector(7 downto 0);
    signal zero_int       : std_logic;
    signal carry_int      : std_logic;
    signal overflow_int   : std_logic;
    signal negative_int   : std_logic;
    signal parity_int     : std_logic;
    signal bcd_carry_int  : std_logic;
    
    -- Arithmetic operation signals
    signal add_result     : std_logic_vector(8 downto 0);
    signal sub_result     : std_logic_vector(8 downto 0);
    signal mul_result     : std_logic_vector(15 downto 0);
    signal inc_result     : std_logic_vector(8 downto 0);
    signal dec_result     : std_logic_vector(8 downto 0);
    
    -- Shift operation signals
    signal shift_amount   : integer range 0 to 7;
    signal sll_result     : std_logic_vector(7 downto 0);
    signal srl_result     : std_logic_vector(7 downto 0);
    signal sra_result     : std_logic_vector(7 downto 0);
    signal rol_result     : std_logic_vector(7 downto 0);
    signal ror_result     : std_logic_vector(7 downto 0);
    
    -- BCD operation signals
    signal bcd_add_result : std_logic_vector(8 downto 0);
    signal bcd_sub_result : std_logic_vector(8 downto 0);
    
begin
    -- 8-bit Arithmetic operations
    add_result <= std_logic_vector(unsigned('0' & a) + unsigned('0' & b) + unsigned'("" & carry_in));
    sub_result <= std_logic_vector(unsigned('0' & a) - unsigned('0' & b) - unsigned'("" & (not carry_in)));
    inc_result <= std_logic_vector(unsigned('0' & a) + 1);
    dec_result <= std_logic_vector(unsigned('0' & a) - 1);
    
    -- 8x8 Multiplication (if enabled)
    mul_gen: if ENABLE_MUL generate
        mul_result <= std_logic_vector(unsigned(a) * unsigned(b));
    end generate;
    
    -- BCD arithmetic (if enabled)
    bcd_gen: if ENABLE_BCD generate
        bcd_arithmetic: process(a, b, carry_in)
            variable temp_add : unsigned(8 downto 0);
            variable temp_sub : unsigned(8 downto 0);
        begin
            -- BCD Addition with decimal adjust
            temp_add := unsigned('0' & a) + unsigned('0' & b) + unsigned'("" & carry_in);
            if temp_add(3 downto 0) > 9 then
                temp_add := temp_add + 6;
            end if;
            if temp_add(7 downto 4) > 9 then
                temp_add := temp_add + 96;  -- Add 6 to upper nibble
            end if;
            bcd_add_result <= std_logic_vector(temp_add);
            
            -- BCD Subtraction with decimal adjust
            temp_sub := unsigned('0' & a) - unsigned('0' & b) - unsigned'("" & (not carry_in));
            if temp_sub(3 downto 0) > 9 then
                temp_sub := temp_sub - 6;
            end if;
            if temp_sub(7 downto 4) > 9 then
                temp_sub := temp_sub - 96;  -- Subtract 6 from upper nibble
            end if;
            bcd_sub_result <= std_logic_vector(temp_sub);
        end process;
    end generate;
    
    -- Shift amount extraction (from lower 3 bits of operand b for 8-bit)
    shift_amount <= to_integer(unsigned(b(2 downto 0)));
    
    -- Shift operations
    sll_result <= std_logic_vector(shift_left(unsigned(a), shift_amount));
    srl_result <= std_logic_vector(shift_right(unsigned(a), shift_amount));
    sra_result <= std_logic_vector(shift_right(signed(a), shift_amount));
    
    -- Rotate operations (if enabled)
    rotate_gen: if ENABLE_ROTATE generate
        rol_result <= std_logic_vector(rotate_left(unsigned(a), shift_amount));
        ror_result <= std_logic_vector(rotate_right(unsigned(a), shift_amount));
    end generate;
    
    -- Main 8-bit ALU operation selection
    alu_operation: process(alu_op, a, b, carry_in, add_result, sub_result, mul_result, 
                          inc_result, dec_result, sll_result, srl_result, sra_result, 
                          rol_result, ror_result, bcd_add_result, bcd_sub_result)
    begin
        result_int <= (others => '0');
        result_hi_int <= (others => '0');
        result_ext <= (others => '0');
        bcd_carry_int <= '0';
        
        case alu_op is
            when ALU_ADD =>
                if ENABLE_BCD then
                    result_int <= bcd_add_result(7 downto 0);
                    result_ext <= bcd_add_result;
                    bcd_carry_int <= bcd_add_result(8);
                else
                    result_int <= add_result(7 downto 0);
                    result_ext <= add_result;
                end if;
                
            when ALU_SUB =>
                if ENABLE_BCD then
                    result_int <= bcd_sub_result(7 downto 0);
                    result_ext <= bcd_sub_result;
                    bcd_carry_int <= bcd_sub_result(8);
                else
                    result_int <= sub_result(7 downto 0);
                    result_ext <= sub_result;
                end if;
                
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
                if ENABLE_ROTATE then
                    result_int <= rol_result;
                    result_ext <= '0' & rol_result;
                end if;
                
            when ALU_ROR =>
                if ENABLE_ROTATE then
                    result_int <= ror_result;
                    result_ext <= '0' & ror_result;
                end if;
                
            when ALU_CMP =>
                -- Comparison: result is 1 if a < b, 0 otherwise
                if unsigned(a) < unsigned(b) then
                    result_int <= "00000001";
                else
                    result_int <= "00000000";
                end if;
                result_ext <= '0' & result_int;
                
            when ALU_INC =>
                result_int <= inc_result(7 downto 0);
                result_ext <= inc_result;
                
            when ALU_DEC =>
                result_int <= dec_result(7 downto 0);
                result_ext <= dec_result;
                
            when ALU_MUL =>
                if ENABLE_MUL then
                    result_int <= mul_result(7 downto 0);
                    result_hi_int <= mul_result(15 downto 8);
                    result_ext <= '0' & mul_result(7 downto 0);
                end if;
                
            when ALU_PASS =>
                result_int <= a;
                result_ext <= '0' & a;
                
            when others =>
                result_int <= (others => '0');
                result_ext <= (others => '0');
        end case;
    end process;
    
    -- 8-bit Flag generation
    flag_generation: process(result_int, result_ext, a, b, alu_op)
        variable parity_calc : std_logic;
    begin
        -- Zero flag (8-bit specific)
        zero_int <= '1' when unsigned(result_int) = 0 else '0';
        
        -- Carry flag
        carry_int <= result_ext(8);
        
        -- Overflow flag (for 8-bit signed arithmetic)
        overflow_int <= '0';
        if alu_op = ALU_ADD or alu_op = ALU_INC then
            overflow_int <= (a(7) and b(7) and not result_int(7)) or
                           (not a(7) and not b(7) and result_int(7));
        elsif alu_op = ALU_SUB or alu_op = ALU_DEC then
            overflow_int <= (a(7) and not b(7) and not result_int(7)) or
                           (not a(7) and b(7) and result_int(7));
        end if;
        
        -- Negative flag (MSB of 8-bit result)
        negative_int <= result_int(7);
        
        -- Parity flag (even parity for 8-bit)
        parity_calc := '0';
        for i in 0 to 7 loop
            parity_calc := parity_calc xor result_int(i);
        end loop;
        parity_int <= not parity_calc;  -- Even parity
    end process;
    
    -- Output assignments
    result <= result_int when enable = '1' else (others => '0');
    result_hi <= result_hi_int;
    zero <= zero_int when enable = '1' else '0';
    carry <= carry_int when enable = '1' else '0';
    overflow <= overflow_int when enable = '1' else '0';
    negative <= negative_int when enable = '1' else '0';
    parity <= parity_int when enable = '1' else '0';
    bcd_carry <= bcd_carry_int when enable = '1' else '0';
    
    -- Combined flags output (8-bit specific)
    flags <= overflow_int & negative_int & zero_int & carry_int & 
             parity_int & bcd_carry_int & "00" when enable = '1' else (others => '0');
    
    -- Control signals
    valid <= enable;
    ready <= '1';  -- Always ready for new operations in combinational design
    
end architecture behavioral;

-- ============================================================================
-- Remember: This 8-bit ALU implementation provides an efficient foundation for
-- embedded systems and microcontroller applications. The design is optimized
-- for minimal resource usage while maintaining full functionality. Ensure
-- proper verification of all operations, especially boundary conditions at
-- 0x00 and 0xFF values. The implementation can be extended with BCD arithmetic,
-- bit manipulation, and other specialized operations based on application needs.
-- ============================================================================