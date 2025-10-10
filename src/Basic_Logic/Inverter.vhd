library  IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity Inverter is
    port(
        x : in std_logic;
        f : out std_logic
    );
end entity;


architecture inverter of Inverter is
    begin
        process(x)
        begin
            if (x = '1') then
                f <= '0';
            else
                f <= '1';
            end if;
        end process;
end architecture;


architecture cocurrent of Inverter is
    begin
        f <= not(x);
end architecture;