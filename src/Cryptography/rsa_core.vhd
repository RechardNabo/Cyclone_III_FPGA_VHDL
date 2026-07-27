-- ============================================================================
-- RSA Core - Simplified Modular Exponentiation (Educational)
-- ============================================================================
-- RSA is a public-key cryptosystem. The core operation is modular
-- exponentiation: C = M^e mod N. This is computationally expensive, so we use
-- the "square-and-multiply" algorithm which processes one exponent bit at a
-- time, dramatically reducing the number of multiplications.
--
-- This educational version uses 16-bit numbers so the math fits in small
-- FPGA resources and is easy to verify by hand.
--
-- Square-and-multiply algorithm:
--   result = 1
--   for each bit of exponent (from MSB to LSB):
--       result = (result * result) mod N   -- square
--       if exponent_bit == 1:
--           result = (result * base) mod N  -- multiply
--
-- LEARNING CONCEPTS:
-- 1. Public-key cryptography basics
-- 2. Modular arithmetic in hardware
-- 3. Iterative algorithms with a control FSM
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rsa_core is
    port (
        clk      : in  std_logic;                      -- Clock
        reset    : in  std_logic;                      -- Async reset (active high)
        start    : in  std_logic;                      -- Start the computation
        base     : in  std_logic_vector(15 downto 0);  -- Message/base value (M)
        exponent : in  std_logic_vector(15 downto 0);  -- Public exponent (e)
        modulus  : in  std_logic_vector(15 downto 0);  -- Modulus (N)
        result   : out std_logic_vector(15 downto 0);  -- C = M^e mod N
        done     : out std_logic                       -- High when done
    );
end entity rsa_core;

architecture rtl of rsa_core is

    -- Simple FSM: idle, compute, finished
    type state_type is (IDLE, COMPUTE, FINISH);
    signal state : state_type := IDLE;

    -- Working registers (use 32 bits internally to avoid overflow when
    -- multiplying two 16-bit numbers: 16x16 = 32 bits max).
    signal result_reg  : unsigned(31 downto 0) := (others => '0');
    signal base_reg    : unsigned(31 downto 0) := (others => '0');
    signal exp_reg     : unsigned(15 downto 0) := (others => '0');
    signal mod_reg     : unsigned(31 downto 0) := (others => '0');
    signal bit_counter : integer range 0 to 16 := 0;
    signal done_reg    : std_logic := '0';

begin

    ----------------------------------------------------------------------------
    -- Main FSM process: implements square-and-multiply.
    ----------------------------------------------------------------------------
    process(clk, reset)
        variable temp : unsigned(31 downto 0);
    begin
        if reset = '1' then
            state       <= IDLE;
            result_reg  <= (others => '0');
            base_reg    <= (others => '0');
            exp_reg     <= (others => '0');
            mod_reg     <= (others => '0');
            bit_counter <= 0;
            done_reg    <= '0';
        elsif rising_edge(clk) then
            done_reg <= '0';  -- default
            case state is

                when IDLE =>
                    if start = '1' then
                        -- Latch inputs and initialize.
                        -- result = 1 (the multiplicative identity).
                        result_reg  <= to_unsigned(1, 32);
                        base_reg    <= resize(unsigned(base), 32);
                        exp_reg     <= unsigned(exponent);
                        mod_reg     <= resize(unsigned(modulus), 32);
                        bit_counter <= 15;  -- start from MSB (bit 15)
                        state       <= COMPUTE;
                    end if;

                when COMPUTE =>
                    -- Process one exponent bit per clock cycle.
                    -- STEP 1: Square - result = (result * result) mod N
                    temp := (result_reg * result_reg) mod mod_reg;
                    result_reg <= temp;

                    -- STEP 2: Multiply - if current exponent bit is 1,
                    --          result = (result * base) mod N
                    -- We check the bit AFTER the square completes, so we
                    -- use the new result_reg value on the next cycle.
                    -- To keep it in one process, we use the variable temp.
                    if exp_reg(bit_counter) = '1' then
                        temp := (temp * base_reg) mod mod_reg;
                        result_reg <= temp;
                    end if;

                    -- Move to the next lower bit of the exponent.
                    if bit_counter = 0 then
                        state <= FINISH;
                    else
                        bit_counter <= bit_counter - 1;
                    end if;

                when FINISH =>
                    done_reg <= '1';
                    state    <= IDLE;

            end case;
        end if;
    end process;

    -- Output the lower 16 bits of the result (numbers are small by design).
    result <= std_logic_vector(result_reg(15 downto 0));
    done   <= done_reg;

end architecture rtl;
