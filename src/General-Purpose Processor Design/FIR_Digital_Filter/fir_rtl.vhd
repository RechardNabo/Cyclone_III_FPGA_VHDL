-- ============================================================================
-- FIR Filter - RTL (Register Transfer Level) Model
-- ============================================================================
-- This RTL model implements the same 8-tap FIR filter as the other two files
-- but with a more structured, pipelined approach suitable for synthesis.
--
-- FIR filter basics:
--   * A "tap" is one coefficient + one delayed sample + one multiplier.
--   * The "delay line" is a shift register that stores past input samples.
--   * "MAC" stands for Multiply-Accumulate: multiply each tap and sum them.
--   * The output y[n] = sum of h[k]*x[n-k] for k = 0..7.
--
-- Pipeline: Stage 0 captures the input and updates the delay line.
--           Stage 1 registers the MAC sum so the adder tree has a full clock
--           period to settle, improving timing (fmax) on the FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fir_rtl is
    generic (
        NUM_TAPS   : integer := 8;   -- Number of filter taps
        DATA_WIDTH : integer := 8    -- Bit width of input/output samples
    );
    port (
        clk        : in  std_logic;                                -- System clock
        reset      : in  std_logic;                                -- Async reset (active high)
        valid_in   : in  std_logic;                                -- Input sample valid strobe
        data_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);  -- Input sample
        valid_out  : out std_logic;                                -- Output sample valid strobe
        data_out   : out std_logic_vector(DATA_WIDTH-1 downto 0)   -- Filtered output sample
    );
end entity fir_rtl;

architecture rtl of fir_rtl is

    -- -------------------------------------------------------------------------
    -- Coefficients: the filter's impulse response (8 integer values).
    -- Feeding an impulse input makes the output sequence equal to these.
    -- -------------------------------------------------------------------------
    type coeff_array is array (0 to 7) of integer;
    constant COEFFS : coeff_array := (1, 2, 3, 4, 4, 3, 2, 1);

    -- Delay line: shift register of std_logic_vector holding past samples.
    type shift_reg_t is array (0 to NUM_TAPS-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal delay_line : shift_reg_t;

    -- Stage-1 pipeline register for the MAC result
    signal mac_reg   : signed(31 downto 0);
    -- Pipeline registers for the valid handshake (2 clocks of latency)
    signal valid_s1  : std_logic;
    signal valid_s2  : std_logic;

begin

    ---------------------------------------------------------------------------
    -- Pipeline Stage 0: Shift-register delay line.
    -- Accepts a new sample when valid_in is high and shifts the history.
    ---------------------------------------------------------------------------
    process (clk, reset)
    begin
        if reset = '1' then
            for i in 0 to NUM_TAPS-1 loop
                delay_line(i) <= (others => '0');
            end loop;
            valid_s1 <= '0';
        elsif rising_edge(clk) then
            if valid_in = '1' then
                delay_line(0) <= data_in;
                for i in 1 to NUM_TAPS-1 loop
                    delay_line(i) <= delay_line(i-1);
                end loop;
            end if;
            valid_s1 <= valid_in;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Pipeline Stage 1: Multiply-Accumulate (MAC).
    -- Each tap multiplies its delayed sample by its coefficient; the products
    -- are summed combinationally and then registered in mac_reg. This gives
    -- the adder tree a full clock period, improving achievable clock speed.
    ---------------------------------------------------------------------------
    process (clk, reset)
        variable sum : signed(31 downto 0);
    begin
        if reset = '1' then
            mac_reg  <= (others => '0');
            valid_s2 <= '0';
        elsif rising_edge(clk) then
            sum := (others => '0');
            for k in 0 to NUM_TAPS-1 loop
                sum := sum + signed(delay_line(k)) * to_signed(COEFFS(k), 16);
            end loop;
            mac_reg  <= sum;
            valid_s2 <= valid_s1;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Output: lower DATA_WIDTH bits of the registered MAC result.
    -- valid_out is delayed by 2 clocks to match the pipeline depth.
    ---------------------------------------------------------------------------
    data_out  <= std_logic_vector(mac_reg(DATA_WIDTH-1 downto 0));
    valid_out <= valid_s2;

end architecture rtl;
