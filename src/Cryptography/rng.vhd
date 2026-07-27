-- ============================================================================
-- Random Number Generator (RNG) - LFSR Based
-- ============================================================================
-- A Linear Feedback Shift Register (LFSR) is a simple pseudo-random number
-- generator. It shifts bits and XORs specific "tap" positions back into the
-- input. With the right taps, the sequence has a long period before repeating.
--
-- This 32-bit LFSR uses taps at positions 32, 22, 2, 1 (a maximal-length
-- polynomial) giving a period of 2^32 - 1 before repeating.
--
-- LEARNING CONCEPTS:
-- 1. Pseudo-random vs true random numbers
-- 2. Shift registers and feedback logic
-- 3. Why tap positions matter (maximal-length sequence)
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rng is
    port (
        clk     : in  std_logic;                      -- Clock signal
        reset   : in  std_logic;                      -- Asynchronous reset (active high)
        enable  : in  std_logic;                      -- Enable the RNG when high
        seed    : in  std_logic_vector(31 downto 0);  -- Initial seed value
        load    : in  std_logic;                      -- Load seed into register when high
        rnd_out : out std_logic_vector(31 downto 0)   -- Current random value
    );
end entity rng;

architecture rtl of rng is
    -- The shift register holding the current random state.
    -- We use variable/signal to hold the 32-bit LFSR state.
    signal lfsr_reg : std_logic_vector(31 downto 0) := (others => '1');

begin

    ----------------------------------------------------------------------------
    -- LFSR Process: On each clock, shift left and feed back XOR of taps.
    -- Taps at positions 32, 22, 2, 1 (1-indexed from the left).
    -- In VHDL bit indexing (0-indexed from right), these map to bits 31, 21, 1, 0.
    ----------------------------------------------------------------------------
    process(clk, reset)
        variable feedback : std_logic;
    begin
        if reset = '1' then
            -- Reset to a non-zero default (all ones) so the LFSR is never zero.
            -- An all-zero LFSR would stay zero forever (degenerate case).
            lfsr_reg <= (others => '1');
        elsif rising_edge(clk) then
            if load = '1' then
                -- Load the seed. A seed of all zeros is invalid for an LFSR,
                -- so we force at least one bit high to avoid the stuck state.
                if seed = x"00000000" then
                    lfsr_reg <= (0 => '1', others => '0');
                else
                    lfsr_reg <= seed;
                end if;
            elsif enable = '1' then
                -- XOR the tap bits together to form the feedback bit.
                -- Taps: bit 31, bit 21, bit 1, bit 0
                feedback := lfsr_reg(31) xor lfsr_reg(21)
                            xor lfsr_reg(1) xor lfsr_reg(0);
                -- Shift the register left by one and insert feedback at bit 0.
                lfsr_reg <= lfsr_reg(30 downto 0) & feedback;
            end if;
        end if;
    end process;

    -- Output the current LFSR value continuously.
    rnd_out <= lfsr_reg;

end architecture rtl;
