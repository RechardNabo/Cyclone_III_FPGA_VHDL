library IEEE;
use IEEE.std_logic_1164.all;

entity XOR_gate is
    port(
        x : in std_logic;
        y : in std_logic;
        f : out std_logic
    );
end entity;

architecture XOR_gate_arch of XOR_gate is
    begin
        process(x,y)
        begin
            if(((x = '0') and (y = '0')) or ((x = '1') and (y = '1'))) then
                f <= '0';
            else
                f <= '1';
            end if;
        end process;
end architecture;

--architecture concurent of XOR_gate is
  --  begin
    --    f<= (x xor y);
--end architecture;