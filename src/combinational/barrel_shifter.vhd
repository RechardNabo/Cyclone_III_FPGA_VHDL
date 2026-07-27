-- ============================================================================
-- 8-Bit Barrel Shifter
-- ============================================================================
-- Shifts or rotates an 8-bit input by a 3-bit shift amount.
--   Mode = "00" : logical shift left
--   Mode = "01" : logical shift right
--   Mode = "10" : rotate left
--   Mode = "11" : rotate right
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity barrel_shifter is
    port (
        Data_In  : in  std_logic_vector(7 downto 0);  -- 8-bit input data
        Shift_Amt: in  std_logic_vector(2 downto 0);  -- Shift amount (0-7)
        Mode     : in  std_logic_vector(1 downto 0);  -- Shift mode
        Data_Out : out std_logic_vector(7 downto 0)   -- 8-bit shifted output
    );
end entity barrel_shifter;

architecture behavioral of barrel_shifter is
    constant WIDTH : integer := 8;
    signal amt : integer range 0 to WIDTH-1;
begin
    -- Convert shift amount to integer
    amt <= to_integer(unsigned(Shift_Amt));

    process(Data_In, amt, Mode)
        variable temp : std_logic_vector(WIDTH-1 downto 0);
    begin
        temp := Data_In;
        case Mode is
            when "00" =>  -- Logical shift left
                temp := std_logic_vector(shift_left(unsigned(Data_In), amt));
            when "01" =>  -- Logical shift right
                temp := std_logic_vector(shift_right(unsigned(Data_In), amt));
            when "10" =>  -- Rotate left
                temp := std_logic_vector(rotate_left(unsigned(Data_In), amt));
            when "11" =>  -- Rotate right
                temp := std_logic_vector(rotate_right(unsigned(Data_In), amt));
            when others =>
                temp := Data_In;
        end case;
        Data_Out <= temp;
    end process;
end architecture behavioral;
