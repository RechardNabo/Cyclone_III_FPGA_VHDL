library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- ALU (Arithmetic Logic Unit)
-- ============================================================================
-- The ALU is the "math brain" of the CPU. It takes two 8-bit operands (a, b)
-- and a 3-bit operation code (op), then produces an 8-bit result plus status
-- flags (zero, carry). This is combinational logic -- no clock needed.
--
-- op encoding:
--   000 ADD : a + b            (carry out on overflow)
--   001 SUB : a - b            (carry = borrow)
--   010 AND : bitwise a AND b
--   011 OR  : bitwise a OR  b
--   100 XOR : bitwise a XOR b
--   101 NOT : bitwise NOT a    (b ignored)
--   110 LSL : shift a left  by 1
--   111 LSR : shift a right by 1
-- ============================================================================
entity alu is
  port(
    a      : in  std_logic_vector(7 downto 0);  -- operand A
    b      : in  std_logic_vector(7 downto 0);  -- operand B
    op     : in  std_logic_vector(2 downto 0);  -- operation select
    result : out std_logic_vector(7 downto 0);  -- 8-bit result
    zero   : out std_logic;                     -- '1' when result is 0
    carry  : out std_logic                      -- carry/borrow flag
  );
end alu;

architecture rtl of alu is
begin
  process(a, b, op)
    -- 9-bit temporary holds the carry bit for add/sub
    variable tmp : unsigned(8 downto 0);
    variable res : std_logic_vector(7 downto 0);
    variable c   : std_logic;
  begin
    c   := '0';
    res := (others => '0');
    case op is
      when "000" =>  -- ADD
        tmp := ('0' & unsigned(a)) + ('0' & unsigned(b));
        res := std_logic_vector(tmp(7 downto 0));
        c   := tmp(8);
      when "001" =>  -- SUB
        tmp := ('0' & unsigned(a)) - ('0' & unsigned(b));
        res := std_logic_vector(tmp(7 downto 0));
        c   := tmp(8);
      when "010" =>  -- AND
        res := a and b;
      when "011" =>  -- OR
        res := a or b;
      when "100" =>  -- XOR
        res := a xor b;
      when "101" =>  -- NOT a
        res := not a;
      when "110" =>  -- LSL a by 1
        res := std_logic_vector(shift_left(unsigned(a), 1));
      when "111" =>  -- LSR a by 1
        res := std_logic_vector(shift_right(unsigned(a), 1));
      when others =>
        res := (others => '0');
    end case;
    result <= res;
    if res = "00000000" then
      zero <= '1';
    else
      zero <= '0';
    end if;
    carry  <= c;
  end process;
end rtl;
