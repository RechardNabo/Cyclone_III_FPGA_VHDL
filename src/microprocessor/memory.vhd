library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Memory (256 x 8-bit single-port RAM)
-- ============================================================================
-- This is the CPU's combined instruction/data memory. It holds 256 bytes of
-- 8 bits each. Reads are combinational (the data appears as soon as addr is
-- presented); writes happen on the rising clock edge when wr_en = '1'.
--
-- The memory is pre-loaded with a small test program:
--   addr 0: LOAD R0,5   -> 001_00_101 = 0x25  (R0 = 5)
--   addr 1: LOAD R1,3   -> 001_01_011 = 0x2B  (R1 = 3)
--   addr 2: ADD  R0,R1  -> 010_00_010 = 0x42  (R0 = R0 + R1 = 8)
--   addr 3: OUT  R0     -> 110_00_000 = 0xC0  (output R0)
--   addr 4: HALT        -> 111_00_000 = 0xE0  (stop)
-- ============================================================================
entity memory is
  port(
    clk     : in  std_logic;
    addr    : in  std_logic_vector(7 downto 0);   -- address (shared R/W)
    wr_en   : in  std_logic;                      -- write enable
    wr_data : in  std_logic_vector(7 downto 0);   -- data to write
    rd_data : out std_logic_vector(7 downto 0)    -- data read out
  );
end memory;

architecture rtl of memory is
  type mem_array is array(0 to 255) of std_logic_vector(7 downto 0);
  signal ram : mem_array := (
    0 => "00100101",  -- LOAD R0,5
    1 => "00101011",  -- LOAD R1,3
    2 => "01000010",  -- ADD  R0,R1
    3 => "11000000",  -- OUT  R0
    4 => "11100000",  -- HALT
    others => "00000000"
  );
begin
  -- Synchronous write
  process(clk)
  begin
    if rising_edge(clk) then
      if wr_en = '1' then
        ram(to_integer(unsigned(addr))) <= wr_data;
      end if;
    end if;
  end process;

  -- Combinational read
  rd_data <= ram(to_integer(unsigned(addr)));
end rtl;
