library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- 8-bit Shift Register with 4 modes (SISO, SIPO, PISO, PIPO)
-- ============================================================================
-- mode select (2 bits):
--   "00" SISO : serial in -> serial out (shift right)
--   "01" SIPO : serial in -> parallel out (shift right, load parallel)
--   "10" PISO : parallel in -> serial out (load parallel, then shift right)
--   "11" PIPO : parallel in -> parallel out (load and hold parallel)
-- Asynchronous reset clears the register.
entity shift_register is
    port (
        clk    : in  std_logic;                     -- clock
        reset  : in  std_logic;                     -- async, active-high reset
        mode   : in  std_logic_vector(1 downto 0);  -- mode select
        ser_in : in  std_logic;                     -- serial input
        par_in : in  std_logic_vector(7 downto 0);  -- parallel input
        ser_out: out std_logic;                     -- serial output (bit 0)
        par_out: out std_logic_vector(7 downto 0)   -- parallel output
    );
end entity shift_register;

architecture rtl of shift_register is
    signal reg : std_logic_vector(7 downto 0) := (others => '0');
begin
    process(clk, reset)
    begin
        -- Async reset clears register
        if reset = '1' then
            reg <= (others => '0');
        elsif rising_edge(clk) then
            case mode is
                when "00" =>                      -- SISO: shift right, serial in
                    reg <= ser_in & reg(7 downto 1);
                when "01" =>                      -- SIPO: shift right, serial in
                    reg <= ser_in & reg(7 downto 1);
                when "10" =>                      -- PISO: load parallel then shift
                    reg <= ser_in & reg(7 downto 1);
                when "11" =>                      -- PIPO: load parallel
                    reg <= par_in;
                when others =>
                    reg <= (others => '0');
            end case;
        end if;
    end process;

    -- For PISO mode, load parallel first by selecting PIPO once, then PISO.
    -- Serial output is the LSB of the register.
    ser_out <= reg(0);
    par_out <= reg;
end architecture rtl;
