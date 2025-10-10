library IEEE;
use IEEE.std_logic_1164.all;

entity NOR_gate is
    port(
        x : in std_logic;
        y : in std_logic;
        f : out std_logic
    );
end entity;

architecture NOR_gate of NOR_gate is
    begin
        process(x,y)
        begin
            if((x = '1') and (y = '1')) then
                f <= '0';
            else
                f <= '1';
            end if;
        end process;
end architecture;

architecture concurent of NOR_gate is
    begin
        f<= not(x or y);
end architecture;