library  IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity Driver is
    port(
        x : in std_logic;
        f : out std_logic
    );
end entity;

architecture driver of Driver is
    begin
        process(x)
        begin
            if (x = '1') then
                f <= '1';
            else
                f <= '0';
            end if;

        end process;
end architecture;

architecture concurrent of Driver is
    begin
        f <= x;
end architecture;