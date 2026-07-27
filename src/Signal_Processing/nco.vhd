-- ============================================================================
-- Numerically Controlled Oscillator (NCO)
-- ============================================================================
-- An NCO generates a digital sine wave by using a phase accumulator and a
-- sine lookup table (LUT). This is the core of Direct Digital Synthesis (DDS).
--
-- How it works:
-- 1. A 32-bit PHASE ACCUMULATOR adds a Frequency Tuning Word (FTW) every clock.
--    The accumulator overflows and wraps around, representing 0 to 2*pi phase.
-- 2. The top 8 bits of the accumulator index into a sine LUT.
-- 3. The LUT outputs an 8-bit sine value.
--
-- Output frequency = FTW * clk_freq / 2^32
-- Example: clk = 50 MHz, FTW = 0x0167A9F5 -> freq = 0.586 * 50e6 / 2^32 ≈ 6.8 kHz
--
-- The sine LUT uses quarter-wave symmetry: only 64 values (0 to pi/2) are
-- stored. The top 2 phase bits select the quadrant, and the logic mirrors
-- or inverts the table value to cover the full 0 to 2*pi range.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity nco is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;            -- active-high synchronous reset
        ftw      : in  std_logic_vector(31 downto 0); -- frequency tuning word
        enable   : in  std_logic;            -- '1' to run, '0' to hold
        sine_out : out signed(7 downto 0)    -- 8-bit sine wave output
    );
end entity nco;

architecture rtl of nco is

    -- 32-bit phase accumulator
    signal phase_acc : unsigned(31 downto 0) := (others => '0');

    -- Quarter-wave sine lookup table: 64 entries, 0 to pi/2
    -- Values: round(127 * sin(i * pi/128)) for i = 0..63
    -- Range: 0 to 127 (positive only, since it's first quadrant)
    type sine_lut_t is array (0 to 63) of integer;
    constant SINE_LUT : sine_lut_t := (
        0,   3,   6,   9,  12,  16,  19,  22,
       25,  28,  31,  34,  37,  40,  43,  46,
       49,  51,  54,  57,  60,  63,  65,  68,
       71,  73,  76,  78,  81,  83,  85,  88,
       90,  92,  94,  96,  98, 100, 102, 104,
      106, 107, 109, 111, 112, 113, 115, 116,
      117, 118, 120, 121, 122, 122, 123, 124,
      125, 125, 126, 126, 126, 127, 127, 127
    );

begin

    -- Phase accumulator: adds FTW every clock cycle when enabled
    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                phase_acc <= (others => '0');
            elsif enable = '1' then
                phase_acc <= phase_acc + unsigned(ftw);
            end if;
        end if;
    end process;

    -- Phase-to-amplitude conversion using quarter-wave sine LUT
    -- Top 8 bits of phase: bits 31..24
    --   bits 31..30 = quadrant (00=Q1, 01=Q2, 10=Q3, 11=Q4)
    --   bits 29..24 = index into 64-entry quarter-wave table
    process (phase_acc)
        variable quadrant : unsigned(1 downto 0);
        variable lut_idx  : unsigned(5 downto 0);
        variable lut_val  : integer;
    begin
        quadrant := phase_acc(31 downto 30);
        lut_idx  := phase_acc(29 downto 24);

        -- Read the base sine value from LUT (first quadrant: 0 to pi/2)
        lut_val := SINE_LUT(to_integer(lut_idx));

        -- Apply quadrant symmetry to cover full 0 to 2*pi
        case quadrant is
            when "00" =>
                -- Quadrant 1 (0 to pi/2): sin(theta)
                sine_out <= to_signed(lut_val, 8);
            when "01" =>
                -- Quadrant 2 (pi/2 to pi): sin(pi - theta) = sin(theta)
                -- Index is mirrored: use (63 - idx)
                sine_out <= to_signed(SINE_LUT(63 - to_integer(lut_idx)), 8);
            when "10" =>
                -- Quadrant 3 (pi to 3pi/2): -sin(theta)
                sine_out <= to_signed(-lut_val, 8);
            when others =>
                -- Quadrant 4 (3pi/2 to 2pi): -sin(pi - theta)
                sine_out <= to_signed(-SINE_LUT(63 - to_integer(lut_idx)), 8);
        end case;
    end process;

end architecture rtl;
