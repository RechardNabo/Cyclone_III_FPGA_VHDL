library IEEE;
use IEEE.std_logic_1164.all;

entity OR_gate is
    port(
        x : in std_logic;
        y : in std_logic;
        f : out std_logic
    );
end entity;

architecture OR_gate of OR_gate is
    begin
        process(x,y)
        begin
            if((x = '0') and (y = '0')) then
                f <= '0';
            else
                f <= '1';
            end if;
        end process;
end architecture;

architecture concurent of OR_gate is
    begin
        f<= x or y;
end architecture;