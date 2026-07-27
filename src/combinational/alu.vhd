-- ============================================================================
-- 4-Bit Arithmetic Logic Unit (ALU)
-- ============================================================================
-- Performs 8 operations selected by a 3-bit op code:
--   000 = ADD, 001 = SUB, 010 = AND, 011 = OR,
--   100 = XOR, 101 = NOT A, 110 = SHL, 111 = SHR
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity alu is
    port (
        A      : in  std_logic_vector(3 downto 0);  -- First operand
        B      : in  std_logic_vector(3 downto 0);  -- Second operand
        Op     : in  std_logic_vector(2 downto 0);  -- Operation select
        Result : out std_logic_vector(3 downto 0);  -- ALU result
        Zero   : out std_logic                      -- '1' when result is zero
    );
end entity alu;

architecture behavioral of alu is
    -- 5-bit temp for add/sub carry out
    signal temp : std_logic_vector(4 downto 0);
    signal res  : std_logic_vector(3 downto 0);
begin
    process(A, B, Op)
    begin
        case Op is
            when "000" =>  -- ADD: A + B
                temp <= std_logic_vector(('0' & unsigned(A)) + ('0' & unsigned(B)));
                res  <= temp(3 downto 0);
            when "001" =>  -- SUB: A - B
                temp <= std_logic_vector(('0' & unsigned(A)) - ('0' & unsigned(B)));
                res  <= temp(3 downto 0);
            when "010" =>  -- AND
                res <= A and B;
            when "011" =>  -- OR
                res <= A or B;
            when "100" =>  -- XOR
                res <= A xor B;
            when "101" =>  -- NOT A
                res <= not A;
            when "110" =>  -- Shift left by 1
                res <= std_logic_vector(shift_left(unsigned(A), 1));
            when "111" =>  -- Shift right by 1
                res <= std_logic_vector(shift_right(unsigned(A), 1));
            when others =>
                res <= (others => '0');
        end case;
    end process;

    Result <= res;
    Zero   <= '1' when res = "0000" else '0';
end architecture behavioral;
