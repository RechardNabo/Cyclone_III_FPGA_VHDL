-- ============================================================================
-- IIR Filter (2nd-Order Biquad, Direct Form II)
-- ============================================================================
-- An IIR (Infinite Impulse Response) filter uses feedback to achieve sharp
-- filtering with fewer coefficients than FIR filters. A 2nd-order IIR
-- filter is called a "biquad" and is the building block for higher-order filters.
--
-- Direct Form II uses an intermediate signal w[n]:
--   w[n] = x[n] - a1*w[n-1] - a2*w[n-2]      (feedback / recursive part)
--   y[n] = b0*w[n] + b1*w[n-1] + b2*w[n-2]   (feedforward part)
--
-- The coefficients b0, b1, b2, a1, a2 are provided as generics.
-- They should be pre-scaled to Q1.15 fixed-point integers (multiply the
-- float coefficient by 2^15 = 32768 and round to integer).
--
-- Example: a lowpass filter at 0.1*Fs might have:
--   b0 = 0.0201 -> 659,  b1 = 0.0402 -> 1317,  b2 = 0.0201 -> 659
--   a1 = -1.561 -> -51105, a2 = 0.6419 -> 21030
--
-- Data is 16-bit signed. Products are 32-bit, shifted right by 15 to rescale.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity iir_filter is
    generic (
        -- Coefficients in Q1.15 fixed-point (integer = round(float * 32768))
        B0 : integer := 659;     -- feedforward coefficient 0
        B1 : integer := 1317;    -- feedforward coefficient 1
        B2 : integer := 659;     -- feedforward coefficient 2
        A1 : integer := -51105;  -- feedback coefficient 1 (note: a1 is subtracted)
        A2 : integer := 21030    -- feedback coefficient 2 (note: a2 is subtracted)
    );
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;           -- active-high synchronous reset
        data_in    : in  signed(15 downto 0); -- 16-bit input sample
        data_valid : in  std_logic;           -- pulse high when input is valid
        data_out   : out signed(15 downto 0); -- 16-bit filtered output
        out_valid  : out std_logic            -- pulse high when output is valid
    );
end entity iir_filter;

architecture rtl of iir_filter is

    -- Coefficient width is 16-bit (Q1.15)
    constant COEFF_WIDTH : natural := 16;
    constant FRAC_BITS   : natural := 15;

    -- Convert generic integers to signed coefficients
    constant c_b0 : signed(COEFF_WIDTH-1 downto 0) := to_signed(B0, COEFF_WIDTH);
    constant c_b1 : signed(COEFF_WIDTH-1 downto 0) := to_signed(B1, COEFF_WIDTH);
    constant c_b2 : signed(COEFF_WIDTH-1 downto 0) := to_signed(B2, COEFF_WIDTH);
    constant c_a1 : signed(COEFF_WIDTH-1 downto 0) := to_signed(A1, COEFF_WIDTH);
    constant c_a2 : signed(COEFF_WIDTH-1 downto 0) := to_signed(A2, COEFF_WIDTH);

    -- Delay line registers: w[n-1] and w[n-2]
    signal w1 : signed(15 downto 0) := (others => '0');  -- w[n-1]
    signal w2 : signed(15 downto 0) := (others => '0');  -- w[n-2]

begin

    -- Direct Form II IIR filter process
    process (clk)
        -- 32-bit variables for multiplication results
        variable w_new  : signed(31 downto 0);
        variable y_prod : signed(31 downto 0);
        variable w_val  : signed(15 downto 0);
        variable y_val  : signed(15 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                w1        <= (others => '0');
                w2        <= (others => '0');
                data_out  <= (others => '0');
                out_valid <= '0';
            elsif data_valid = '1' then
                -- Step 1: Compute w[n] = x[n] - a1*w[n-1] - a2*w[n-2]
                -- Multiplications are 16x16 = 32-bit, then shift right by 15
                w_new := resize(data_in, 32)
                       - resize(shift_right(c_a1 * w1, FRAC_BITS), 32)
                       - resize(shift_right(c_a2 * w2, FRAC_BITS), 32);
                w_val := resize(w_new, 16);

                -- Step 2: Compute y[n] = b0*w[n] + b1*w[n-1] + b2*w[n-2]
                y_prod := resize(shift_right(c_b0 * w_val, FRAC_BITS), 32)
                        + resize(shift_right(c_b1 * w1, FRAC_BITS), 32)
                        + resize(shift_right(c_b2 * w2, FRAC_BITS), 32);
                y_val := resize(y_prod, 16);

                -- Step 3: Shift delay line
                w2 <= w1;       -- w[n-2] = old w[n-1]
                w1 <= w_val;    -- w[n-1] = new w[n]

                -- Output
                data_out  <= y_val;
                out_valid <= '1';
            else
                out_valid <= '0';
            end if;
        end if;
    end process;

end architecture rtl;
