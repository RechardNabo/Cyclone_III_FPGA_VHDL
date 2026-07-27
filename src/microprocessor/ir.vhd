library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Instruction Register (IR)
-- ============================================================================
-- The Instruction Register latches the instruction fetched from memory so it
-- stays stable while the control unit decodes and executes it. The value is
-- captured on the rising clock edge when load = '1'.
-- ============================================================================
entity ir is
  port(
    clk  : in  std_logic;
    rst  : in  std_logic;
    load : in  std_logic;                     -- latch enable
    d    : in  std_logic_vector(7 downto 0);  -- instruction from memory
    q    : out std_logic_vector(7 downto 0)   -- held instruction
  );
end ir;

architecture rtl of ir is
  signal data : std_logic_vector(7 downto 0) := (others => '0');
begin
  process(clk, rst)
  begin
    if rst = '1' then
      data <= (others => '0');
    elsif rising_edge(clk) then
      if load = '1' then
        data <= d;
      end if;
    end if;
  end process;
  q <= data;
end rtl;
