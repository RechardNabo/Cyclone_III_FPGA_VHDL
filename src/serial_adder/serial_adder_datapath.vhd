-- ============================================================================
-- Serial Adder - Datapath
-- Two 8-bit shift registers (A, B), full adder, carry flip-flop, 8-bit result
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity serial_adder_datapath is
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    a_in      : in  std_logic_vector(7 downto 0);
    b_in      : in  std_logic_vector(7 downto 0);
    load_en   : in  std_logic;  -- load operands into shift registers
    shift_en  : in  std_logic;  -- shift A, B right and shift sum left
    sum_out   : out std_logic_vector(7 downto 0)
  );
end entity serial_adder_datapath;

architecture rtl of serial_adder_datapath is
  signal a_reg     : std_logic_vector(7 downto 0) := (others => '0');
  signal b_reg     : std_logic_vector(7 downto 0) := (others => '0');
  signal sum_reg   : std_logic_vector(7 downto 0) := (others => '0');
  signal carry_reg : std_logic := '0';

  -- Full adder combinational signals (uses LSB of A and B)
  signal a_bit     : std_logic;
  signal b_bit     : std_logic;
  signal sum_bit   : std_logic;
  signal carry_next: std_logic;
begin

  -- Extract the least-significant bits currently at the adder input
  a_bit <= a_reg(0);
  b_bit <= b_reg(0);

  -- Full adder logic: sum = a XOR b XOR carry
  sum_bit    <= a_bit xor b_bit xor carry_reg;
  -- Full adder carry: majority of a, b, carry
  carry_next <= (a_bit and b_bit) or (a_bit and carry_reg) or
                (b_bit and carry_reg);

  -- Clocked process: load or shift the registers
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        a_reg     <= (others => '0');
        b_reg     <= (others => '0');
        sum_reg   <= (others => '0');
        carry_reg <= '0';
      else
        if load_en = '1' then
          -- Load operands and clear sum and carry
          a_reg     <= a_in;
          b_reg     <= b_in;
          sum_reg   <= (others => '0');
          carry_reg <= '0';
        elsif shift_en = '1' then
          -- Shift A and B right (LSB consumed by adder)
          a_reg <= '0' & a_reg(7 downto 1);
          b_reg <= '0' & b_reg(7 downto 1);
          -- Shift sum right, inserting new sum bit at MSB
          sum_reg <= sum_bit & sum_reg(7 downto 1);
          -- Update carry flip-flop
          carry_reg <= carry_next;
        end if;
      end if;
    end if;
  end process;

  sum_out <= sum_reg;

end architecture rtl;
