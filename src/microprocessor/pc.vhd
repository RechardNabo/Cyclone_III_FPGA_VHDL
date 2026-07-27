library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Program Counter (PC)
-- ============================================================================
-- The Program Counter holds the address of the next instruction to fetch.
--   * On each clock edge, if en = '1' it increments by 1 (normal execution).
--   * If load = '1' it instead loads the value on d (used for jumps).
--   * rst asynchronously resets the counter to 0.
-- The PC is 8 bits, so it can address 256 memory locations.
-- ============================================================================
entity pc is
  port(
    clk  : in  std_logic;
    rst  : in  std_logic;
    en   : in  std_logic;                       -- increment enable
    load : in  std_logic;                       -- load jump target
    d    : in  std_logic_vector(7 downto 0);    -- jump target address
    q    : out std_logic_vector(7 downto 0)     -- current PC value
  );
end pc;

architecture rtl of pc is
  signal count : unsigned(7 downto 0) := (others => '0');
begin
  process(clk, rst)
  begin
    if rst = '1' then
      count <= (others => '0');
    elsif rising_edge(clk) then
      if load = '1' then
        count <= unsigned(d);      -- jump to new address
      elsif en = '1' then
        count <= count + 1;        -- next sequential instruction
      end if;
    end if;
  end process;
  q <= std_logic_vector(count);
end rtl;
