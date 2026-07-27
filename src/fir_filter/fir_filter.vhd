-- ============================================================================
-- FIR Filter - Top-Level Module
-- ============================================================================
-- A Finite Impulse Response (FIR) filter computes:
--     y[n] = h[0]*x[n] + h[1]*x[n-1] + ... + h[7]*x[n-7]
-- where h[k] are the filter coefficients (the impulse response) and x[n-k]
-- are past input samples stored in a shift register (the "delay line").
--
-- This is the top-level design with a simple valid_in / valid_out handshake.
-- When valid_in is high, the input sample on data_in is clocked into the
-- delay line and a new output is produced one clock later on data_out with
-- valid_out high.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fir_filter is
    generic (
        NUM_TAPS   : integer := 8;   -- Number of filter taps
        DATA_WIDTH : integer := 8    -- Bit width of input and output samples
    );
    port (
        clk        : in  std_logic;                                -- System clock
        reset      : in  std_logic;                                -- Async reset (active high)
        valid_in   : in  std_logic;                                -- New input sample valid
        data_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);  -- Input sample
        valid_out  : out std_logic;                                -- Output sample valid
        data_out   : out std_logic_vector(DATA_WIDTH-1 downto 0)   -- Filtered output
    );
end entity fir_filter;

architecture rtl of fir_filter is

    -- -------------------------------------------------------------------------
    -- Coefficient array type and constant values.
    -- These 8 integers are the filter's impulse response. Feeding an impulse
    -- (a single 1 followed by zeros) into the filter makes the output equal
    -- to these coefficients, one per clock - a great way to test the filter!
    -- -------------------------------------------------------------------------
    type coeff_array is array (0 to 7) of integer;
    constant COEFFS : coeff_array := (1, 2, 3, 4, 4, 3, 2, 1);

    -- Shift register delay line storing the last NUM_TAPS input samples.
    -- delay_line(0) is the newest sample; delay_line(7) is the oldest.
    type shift_reg_t is array (0 to NUM_TAPS-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal delay_line : shift_reg_t;

    -- Accumulator for the multiply-accumulate (MAC) sum.
    -- Width is generous to avoid overflow during accumulation.
    signal acc : signed(31 downto 0);

    -- Pipeline register for the valid handshake (1 clock of latency)
    signal valid_pipe : std_logic;

begin

    ---------------------------------------------------------------------------
    -- Shift register: on each valid input, shift the new sample in and push
    -- older samples down the line. This maintains the x[n-k] history.
    ---------------------------------------------------------------------------
    process (clk, reset)
    begin
        if reset = '1' then
            for i in 0 to NUM_TAPS-1 loop
                delay_line(i) <= (others => '0');
            end loop;
            valid_pipe <= '0';
        elsif rising_edge(clk) then
            if valid_in = '1' then
                delay_line(0) <= data_in;                -- accept newest sample
                for i in 1 to NUM_TAPS-1 loop
                    delay_line(i) <= delay_line(i-1);    -- shift older samples
                end loop;
            end if;
            -- Keep valid_out aligned with the registered output
            valid_pipe <= valid_in;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Multiply-Accumulate (MAC): for each tap, multiply the delayed sample by
    -- its coefficient and add them all together. This is the core DSP math.
    ---------------------------------------------------------------------------
    process (clk, reset)
        variable sum : signed(31 downto 0);
    begin
        if reset = '1' then
            acc <= (others => '0');
        elsif rising_edge(clk) then
            sum := (others => '0');
            for k in 0 to NUM_TAPS-1 loop
                -- signed(data) * coefficient, then accumulate
                sum := sum + signed(delay_line(k)) * to_signed(COEFFS(k), 16);
            end loop;
            acc <= sum;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Output: present the lower DATA_WIDTH bits of the accumulator.
    ---------------------------------------------------------------------------
    data_out  <= std_logic_vector(acc(DATA_WIDTH-1 downto 0));
    valid_out <= valid_pipe;

end architecture rtl;
