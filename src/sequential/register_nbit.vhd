library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Generic N-bit Register with Load Enable
-- ============================================================================
-- On rising clock edge, if load = '1' the register captures d_in.
-- No reset: generic-width register that holds value when load = '0'.
entity register_nbit is
    generic (
        N : integer := 8                              -- register width
    );
    port (
        clk   : in  std_logic;                        -- clock
        load  : in  std_logic;                        -- load enable
        d_in  : in  std_logic_vector(N-1 downto 0);   -- data input
        d_out : out std_logic_vector(N-1 downto 0)    -- stored data
    );
end entity register_nbit;

architecture rtl of register_nbit is
    signal reg : std_logic_vector(N-1 downto 0) := (others => '0');
begin
    process(clk)
    begin
        -- Rising edge: load new data when enabled
        if rising_edge(clk) then
            if load = '1' then
                reg <= d_in;
            end if;
        end if;
    end process;

    d_out <= reg;
end architecture rtl;
