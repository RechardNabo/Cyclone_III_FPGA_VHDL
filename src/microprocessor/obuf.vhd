library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Output Buffer
-- ============================================================================
-- The output buffer is an 8-bit register that holds the value produced by an
-- OUT instruction and drives the external output_port pins. It latches its
-- input on the rising clock edge when load = '1'.
-- ============================================================================
entity obuf is
  port(
    clk  : in  std_logic;
    rst  : in  std_logic;
    load : in  std_logic;                     -- latch enable
    d    : in  std_logic_vector(7 downto 0);  -- data to capture
    q    : out std_logic_vector(7 downto 0)   -- buffered output
  );
end obuf;

architecture rtl of obuf is
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
