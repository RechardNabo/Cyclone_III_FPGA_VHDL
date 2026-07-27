-- ============================================================================
-- CORDIC Processor (Rotation Mode)
-- ============================================================================
-- CORDIC = COordinate Rotation DIgital Computer.
-- An iterative algorithm that computes sin/cos using only shifts and adds.
--
-- In ROTATION MODE we start with:
--   X0 = K  (pre-scaling constant to compensate for CORDIC gain)
--   Y0 = 0
--   Z0 = input angle (the angle we want sin/cos of)
--
-- Each iteration i (i = 0..7) performs:
--   if Z >= 0 then d = +1  else d = -1
--   X[i+1] = X[i] - d * (Y[i] >> i)    -- shift right = multiply by 2^-i
--   Y[i+1] = Y[i] + d * (X[i] >> i)
--   Z[i+1] = Z[i] - d * atan(2^-i)
--
-- After all iterations:
--   X = cos(angle),  Y = sin(angle)
--
-- Fixed-point format: Q2.14 (2 integer bits, 14 fractional bits, 16-bit total)
--   This represents values from -2.0 to +1.9999, enough for sin/cos [-1, +1].
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cordic is
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;          -- active-high synchronous reset
        start   : in  std_logic;          -- pulse high to begin computation
        angle   : in  signed(15 downto 0); -- input angle in Q2.14 (-pi to +pi)
        cos_out : out signed(15 downto 0); -- cosine result in Q2.14
        sin_out : out signed(15 downto 0); -- sine result in Q2.14
        done    : out std_logic           -- high when result is valid
    );
end entity cordic;

architecture rtl of cordic is

    -- Number of iterations (more iterations = more precision)
    constant NUM_ITER : natural := 8;

    -- Pre-computed atan(2^-i) values in Q2.14 fixed-point
    -- atan(2^-0) = 0.7854 rad -> 12868
    -- atan(2^-1) = 0.4636 rad -> 7596
    -- atan(2^-2) = 0.2450 rad -> 4014
    -- atan(2^-3) = 0.1244 rad -> 2037
    -- atan(2^-4) = 0.0624 rad -> 1023
    -- atan(2^-5) = 0.0312 rad -> 512
    -- atan(2^-6) = 0.0156 rad -> 256
    -- atan(2^-7) = 0.0078 rad -> 128
    type atan_table_t is array (0 to NUM_ITER-1) of signed(15 downto 0);
    constant ATAN_TABLE : atan_table_t := (
        to_signed(12868, 16),
        to_signed(7596, 16),
        to_signed(4014, 16),
        to_signed(2037, 16),
        to_signed(1023, 16),
        to_signed(512, 16),
        to_signed(256, 16),
        to_signed(128, 16)
    );

    -- CORDIC gain compensation constant: K = 1/1.6467 = 0.6072 in Q2.14 = 9949
    constant K_CONST : signed(15 downto 0) := to_signed(9949, 16);

    -- State machine
    type state_t is (IDLE, CALC, FINISH);
    signal state : state_t := IDLE;

    -- Iteration counter
    signal iter : natural range 0 to NUM_ITER := 0;

    -- Working registers for X, Y, Z during iterations
    signal x_reg : signed(15 downto 0) := (others => '0');
    signal y_reg : signed(15 downto 0) := (others => '0');
    signal z_reg : signed(15 downto 0) := (others => '0');

begin

    -- Main CORDIC iteration process
    process (clk)
        variable d      : integer;          -- rotation direction: +1 or -1
        variable x_shift : signed(15 downto 0);
        variable y_shift : signed(15 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state   <= IDLE;
                iter    <= 0;
                x_reg   <= (others => '0');
                y_reg   <= (others => '0');
                z_reg   <= (others => '0');
                done    <= '0';
                cos_out <= (others => '0');
                sin_out <= (others => '0');
            else
                case state is
                    when IDLE =>
                        done <= '0';
                        if start = '1' then
                            -- Initialize: X0 = K, Y0 = 0, Z0 = input angle
                            x_reg <= K_CONST;
                            y_reg <= (others => '0');
                            z_reg <= angle;
                            iter  <= 0;
                            state <= CALC;
                        end if;

                    when CALC =>
                        -- Determine rotation direction based on sign of Z
                        if z_reg >= 0 then
                            d := 1;
                        else
                            d := -1;
                        end if;

                        -- Shift X and Y right by iter bits (multiply by 2^-iter)
                        -- shift_right on signed preserves the sign bit
                        x_shift := shift_right(x_reg, iter);
                        y_shift := shift_right(y_reg, iter);

                        -- CORDIC rotation equations
                        if d = 1 then
                            x_reg <= x_reg - y_shift;
                            y_reg <= y_reg + x_shift;
                            z_reg <= z_reg - ATAN_TABLE(iter);
                        else
                            x_reg <= x_reg + y_shift;
                            y_reg <= y_reg - x_shift;
                            z_reg <= z_reg + ATAN_TABLE(iter);
                        end if;

                        -- Move to next iteration or finish
                        if iter = NUM_ITER - 1 then
                            state <= FINISH;
                        else
                            iter <= iter + 1;
                        end if;

                    when FINISH =>
                        -- Output the final cosine and sine values
                        cos_out <= x_reg;
                        sin_out <= y_reg;
                        done    <= '1';
                        state   <= IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
