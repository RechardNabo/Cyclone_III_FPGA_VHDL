library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity XNOR_L is
    port(
        x : in std_logic;
        y : in std_logic;
        f : out std_logic
    );
end entity;


architecture xnor_l of XNOR_L is
    begin
        process(x)
        begin


        end process;
end architecture;

architecture conccurent  of XNOR_L is
    begin
            f <= x xnor y;
end architecture;