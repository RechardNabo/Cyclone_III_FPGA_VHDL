-- ============================================================================
-- GCD Calculator - Datapath
-- Registers for A and B, subtractor, comparator, muxes for swap/subtract
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity gcd_datapath is
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    a_in        : in  std_logic_vector(7 downto 0);
    b_in        : in  std_logic_vector(7 downto 0);
    load_en     : in  std_logic;  -- load operands into A and B
    swap_en     : in  std_logic;  -- swap A and B
    sub_en      : in  std_logic;  -- A <= A - B
    a_out       : out std_logic_vector(7 downto 0);
    b_out       : out std_logic_vector(7 downto 0);
    a_ge_b      : out std_logic;  -- '1' when A >= B
    b_eq_zero   : out std_logic   -- '1' when B = 0
  );
end entity gcd_datapath;

architecture rtl of gcd_datapath is
  signal a_reg : unsigned(7 downto 0) := (others => '0');
  signal b_reg : unsigned(7 downto 0) := (others => '0');

  -- Subtractor result: A - B (used when A >= B)
  signal sub_result : unsigned(7 downto 0);

  -- Mux outputs: select next value for A and B
  signal a_next : unsigned(7 downto 0);
  signal b_next : unsigned(7 downto 0);
begin

  -- Subtractor computes A - B
  sub_result <= a_reg - b_reg;

  -- Comparator: A >= B and B = 0
  a_ge_b    <= '1' when a_reg >= b_reg else '0';
  b_eq_zero <= '1' when b_reg = to_unsigned(0, 8) else '0';

  -- Mux for A register next value
  --   load_en  : load external a_in
  --   swap_en  : take current B value
  --   sub_en   : take subtraction result (A - B)
  --   default  : hold current A
  a_next <= unsigned(a_in) when load_en = '1' else
            b_reg          when swap_en = '1' else
            sub_result     when sub_en  = '1' else
            a_reg;

  -- Mux for B register next value
  --   load_en  : load external b_in
  --   swap_en  : take current A value
  --   default  : hold current B
  b_next <= unsigned(b_in) when load_en = '1' else
            a_reg          when swap_en = '1' else
            b_reg;

  -- Clocked register updates
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        a_reg <= (others => '0');
        b_reg <= (others => '0');
      else
        a_reg <= a_next;
        b_reg <= b_next;
      end if;
    end if;
  end process;

  -- Drive outputs from the registers
  a_out <= std_logic_vector(a_reg);
  b_out <= std_logic_vector(b_reg);

end architecture rtl;
