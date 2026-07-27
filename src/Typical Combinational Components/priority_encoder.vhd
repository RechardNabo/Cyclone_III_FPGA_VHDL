-- ============================================================================
-- 8-to-3 Priority Encoder
-- ============================================================================
-- Encodes the highest-priority active input (bit 7 = highest) into a 3-bit
-- binary code. Valid_Out is '1' when at least one input is active.
--   Requests(7) active -> "111", Requests(0) active -> "000"
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity priority_encoder is
    port (
        Requests : in  std_logic_vector(7 downto 0);  -- 8 active-high request inputs
        Code     : out std_logic_vector(2 downto 0);  -- 3-bit encoded output
        Valid    : out std_logic                      -- '1' when any request is active
    );
end entity priority_encoder;

architecture behavioral of priority_encoder is
begin
    process(Requests)
    begin
        if Requests(7) = '1' then
            Code <= "111"; Valid <= '1';
        elsif Requests(6) = '1' then
            Code <= "110"; Valid <= '1';
        elsif Requests(5) = '1' then
            Code <= "101"; Valid <= '1';
        elsif Requests(4) = '1' then
            Code <= "100"; Valid <= '1';
        elsif Requests(3) = '1' then
            Code <= "011"; Valid <= '1';
        elsif Requests(2) = '1' then
            Code <= "010"; Valid <= '1';
        elsif Requests(1) = '1' then
            Code <= "001"; Valid <= '1';
        elsif Requests(0) = '1' then
            Code <= "000"; Valid <= '1';
        else
            Code <= "000"; Valid <= '0';
        end if;
    end process;
end architecture behavioral;
