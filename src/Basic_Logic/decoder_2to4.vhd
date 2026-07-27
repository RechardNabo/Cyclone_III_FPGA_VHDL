-- 2-to-4 decoder with enable
-- When enable is '1', exactly one output line is active (low)
-- based on the 2-bit select input. When enable is '0', all outputs are '1'.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity decoder_2to4 is
    port (
        A : in  std_logic;                     -- address bit 0 (LSB)
        B : in  std_logic;                     -- address bit 1 (MSB)
        E : in  std_logic;                     -- active-high enable
        Y : out std_logic_vector(3 downto 0)   -- one-hot (active-low) outputs
    );
end entity decoder_2to4;

architecture behavioral of decoder_2to4 is
    -- Combine A and B into a 2-bit select word
    signal sel : std_logic_vector(1 downto 0);
begin
    sel <= B & A;  -- MSB first

    process(sel, E)
    begin
        if E = '0' then
            -- Disabled: all outputs high (inactive)
            Y <= "1111";
        else
            -- Enabled: decode the 2-bit address to one active-low output
            case sel is
                when "00" => Y <= "1110";  -- output 0 active
                when "01" => Y <= "1101";  -- output 1 active
                when "10" => Y <= "1011";  -- output 2 active
                when "11" => Y <= "0111";  -- output 3 active
                when others => Y <= "1111";
            end case;
        end if;
    end process;
end architecture behavioral;
