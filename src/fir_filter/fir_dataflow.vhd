-- ============================================================================
-- FIR Filter - Dataflow Model
-- ============================================================================
-- A Finite Impulse Response (FIR) filter produces each output sample by
-- multiplying a set of coefficients (the "taps") with the most recent input
-- samples and summing the results. This is the classic MAC (Multiply-
-- Accumulate) operation:  y[n] = sum( h[k] * x[n-k] ).
--
-- This dataflow model uses concurrent signal assignments to describe the
-- delay line, the parallel multipliers, and the adder tree. It is the most
-- compact of the three FIR examples and emphasizes parallel computation.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fir_dataflow is
    generic (
        -- Number of filter taps (fixed at 8 for this educational design)
        NUM_TAPS   : integer := 8;
        -- Width of input/output data samples in bits
        DATA_WIDTH : integer := 8
    );
    port (
        clk        : in  std_logic;                                      -- System clock
        reset      : in  std_logic;                                      -- Async reset (active high)
        data_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);        -- New input sample
        valid_in   : in  std_logic;                                      -- Strobe: new sample available
        data_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);        -- Filtered output
        valid_out  : out std_logic                                       -- Strobe: output sample ready
    );
end entity fir_dataflow;

architecture rtl of fir_dataflow is

    -- -------------------------------------------------------------------------
    -- Coefficient array type and constant values.
    -- These 8 integers are the filter's impulse response. Feeding an impulse
    -- (a single 1 followed by zeros) makes the output equal to these values,
    -- one per clock - a great way to verify the filter.
    -- -------------------------------------------------------------------------
    type coeff_array is array (0 to 7) of integer;
    constant COEFFS : coeff_array := (1, 2, 3, 4, 4, 3, 2, 1);

    -- Shift-register delay line: each entry holds one delayed input sample.
    -- delay_line(0) = newest sample, delay_line(NUM_TAPS-1) = oldest sample.
    type sample_array is array (0 to NUM_TAPS-1) of signed(DATA_WIDTH-1 downto 0);
    signal delay_line : sample_array;

    -- Products of each tap: h[k] * x[n-k] (parallel multiplier outputs)
    type product_array is array (0 to NUM_TAPS-1) of signed(DATA_WIDTH+15 downto 0);
    signal products : product_array;

    -- Accumulator wide enough to hold the sum of all products without overflow
    signal acc : signed(DATA_WIDTH+15 downto 0);

    -- Pipeline the valid signal so it lines up with the registered output
    signal valid_pipe : std_logic;

begin

    ---------------------------------------------------------------------------
    -- Delay line: shift the input sample through the register chain on every
    -- valid input. This creates the x[n], x[n-1], ... x[n-7] history.
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
                -- Newest sample goes into position 0; older samples shift down
                delay_line(0) <= signed(data_in);
                for i in 1 to NUM_TAPS-1 loop
                    delay_line(i) <= delay_line(i-1);
                end loop;
            end if;
            -- Delay the valid flag by one clock to align with the MAC output
            valid_pipe <= valid_in;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Parallel multiply: each tap computes h[k] * x[n-k] concurrently.
    -- This is the "dataflow" part - all multiplications happen at once.
    ---------------------------------------------------------------------------
    gen_mult : for k in 0 to NUM_TAPS-1 generate
        products(k) <= delay_line(k) * to_signed(COEFFS(k), 16);
    end generate gen_mult;

    ---------------------------------------------------------------------------
    -- Adder tree: sum all products into the accumulator (registered).
    ---------------------------------------------------------------------------
    process (clk, reset)
        variable sum : signed(DATA_WIDTH+15 downto 0);
    begin
        if reset = '1' then
            acc <= (others => '0');
        elsif rising_edge(clk) then
            sum := (others => '0');
            for k in 0 to NUM_TAPS-1 loop
                sum := sum + products(k);
            end loop;
            acc <= sum;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Output: take the lower DATA_WIDTH bits of the accumulator.
    ---------------------------------------------------------------------------
    data_out  <= std_logic_vector(acc(DATA_WIDTH-1 downto 0));
    valid_out <= valid_pipe;

end architecture rtl;
