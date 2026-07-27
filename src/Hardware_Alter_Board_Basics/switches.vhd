-- ============================================================================
-- Slide Switches Reader with Synchronization
-- Target: Altera/Intel Cyclone III FPGA
-- Reads 10 slide switches and outputs them as a 10-bit vector.
-- Includes a 2-flip-flop synchronizer to avoid metastability.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity switches is
    generic (
        SYNC_ENABLE : boolean := true  -- Enable 2-FF synchronizer
    );
    port (
        clk    : in  std_logic;                    -- System clock
        sw_in  : in  std_logic_vector(9 downto 0); -- Raw switch inputs
        sw_out : out std_logic_vector(9 downto 0)  -- Synchronized outputs
    );
end entity switches;

architecture rtl of switches is
    -- Stage 1 of synchronizer (direct or first FF)
    signal sync1 : std_logic_vector(9 downto 0) := (others => '0');
    -- Stage 2 of synchronizer (second FF)
    signal sync2 : std_logic_vector(9 downto 0) := (others => '0');
begin

    sync_proc : process(clk)
    begin
        if rising_edge(clk) then
            if SYNC_ENABLE then
                -- Two flip-flop synchronizer for each switch
                sync1 <= sw_in;
                sync2 <= sync1;
            else
                -- Bypass synchronizer (direct pass-through)
                sync1 <= sw_in;
                sync2 <= sync1;
            end if;
        end if;
    end process sync_proc;

    -- Output the synchronized switch values
    sw_out <= sync2;

end architecture rtl;
