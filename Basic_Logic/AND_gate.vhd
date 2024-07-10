library IEEE;
use IEEE.std_logic_1164.all;

entity AND_gate is
    port(
        x : in std_logic;
        y : in std_logic;
        f : out std_logic
    );
end entity;

architecture AND_gate of AND_gate is
    begin
        process(x,y)
        begin
            if((x = '0') or (y = '0')) then
                f <= '0';
            else
                f <= '1';
            end if;
        end process;
end architecture;

architecture concurent of AND_gate is
    begin
        f<= x and y;
end architecture;