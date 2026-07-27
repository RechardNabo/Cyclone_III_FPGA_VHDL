library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Register File (8 x 8-bit)
-- ============================================================================
-- A register file is a small, fast storage bank inside the CPU. This one has
-- eight 8-bit registers (R0..R7) addressed with 3-bit addresses.
--   * Two read ports (rd_addr1/rd_data1, rd_addr2/rd_data2) are combinational,
--     so the data appears as soon as the address is presented.
--   * One write port (wr_addr/wr_data) updates a register on the rising clock
--     edge when wr_en = '1'.
--   * rst asynchronously clears all registers to 0.
-- ============================================================================
entity reg_file is
  port(
    clk      : in  std_logic;
    rst      : in  std_logic;
    wr_en    : in  std_logic;
    rd_addr1 : in  std_logic_vector(2 downto 0);  -- read port 1 address
    rd_addr2 : in  std_logic_vector(2 downto 0);  -- read port 2 address
    wr_addr  : in  std_logic_vector(2 downto 0);  -- write port address
    wr_data  : in  std_logic_vector(7 downto 0);  -- write port data
    rd_data1 : out std_logic_vector(7 downto 0);  -- read port 1 data
    rd_data2 : out std_logic_vector(7 downto 0)   -- read port 2 data
  );
end reg_file;

architecture rtl of reg_file is
  -- an array type holding 8 registers of 8 bits each
  type reg_array is array(0 to 7) of std_logic_vector(7 downto 0);
  signal regs : reg_array := (others => (others => '0'));
begin
  -- Synchronous write with asynchronous reset
  process(clk, rst)
  begin
    if rst = '1' then
      regs <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if wr_en = '1' then
        regs(to_integer(unsigned(wr_addr))) <= wr_data;
      end if;
    end if;
  end process;

  -- Combinational (asynchronous) reads
  rd_data1 <= regs(to_integer(unsigned(rd_addr1)));
  rd_data2 <= regs(to_integer(unsigned(rd_addr2)));
end rtl;
