-- ============================================================================
-- 3-to-8 Decoder with Enable
-- ============================================================================
-- Converts a 3-bit address into one of 8 active-high outputs.
-- When Enable = '0' all outputs are '0'.
--   Enable = '1' : outputs(to_integer(address)) = '1', rest = '0'
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity decoder_3to8 is
    port (
        Address : in  std_logic_vector(2 downto 0);  -- 3-bit select address
        Enable  : in  std_logic;                     -- Active-high enable
        Outputs : out std_logic_vector(7 downto 0)   -- One-hot 8-bit output
    );
end entity decoder_3to8;

architecture behavioral of decoder_3to8 is
begin
    process(Address, Enable)
    begin
        if Enable = '1' then
            -- Convert address to integer and set that bit high
            Outputs <= (others => '0');
            Outputs(to_integer(unsigned(Address))) <= '1';
        else
            Outputs <= (others => '0');
        end if;
    end process;
end architecture behavioral;
