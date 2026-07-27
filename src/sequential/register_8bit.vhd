library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- 8-bit Register with Load Enable and Asynchronous Reset
-- ============================================================================
-- On rising clock edge, if load = '1' the register captures d_in.
-- Asynchronous reset: reset = '1' clears all bits immediately.
entity register_8bit is
    port (
        clk   : in  std_logic;                      -- clock
        reset : in  std_logic;                      -- async, active-high reset
        load  : in  std_logic;                      -- load enable
        d_in  : in  std_logic_vector(7 downto 0);   -- data input
        d_out : out std_logic_vector(7 downto 0)    -- stored data
    );
end entity register_8bit;

architecture rtl of register_8bit is
    signal reg : std_logic_vector(7 downto 0) := (others => '0');
begin
    process(clk, reset)
    begin
        -- Async reset clears register regardless of clock
        if reset = '1' then
            reg <= (others => '0');
        elsif rising_edge(clk) then
            if load = '1' then
                reg <= d_in;    -- load new data on rising edge
            end if;
        end if;
    end process;

    d_out <= reg;
end architecture rtl;
