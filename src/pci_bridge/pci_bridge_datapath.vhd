-- ============================================================================
-- PCI Bridge - Datapath
-- 32-bit address register, 32-bit data buffer, parity checker
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pci_bridge_datapath is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    addr_in    : in  std_logic_vector(31 downto 0);
    data_in    : in  std_logic_vector(31 downto 0);
    load_addr  : in  std_logic;  -- load address register
    load_data  : in  std_logic;  -- load write data buffer
    read_en    : in  std_logic;  -- capture read data into buffer
    pci_addr   : out std_logic_vector(31 downto 0); -- PCI address bus
    pci_data_o : out std_logic_vector(31 downto 0); -- PCI data out (write)
    data_out   : out std_logic_vector(31 downto 0); -- captured read data
    parity_err : out std_logic   -- parity error flag
  );
end entity pci_bridge_datapath;

architecture rtl of pci_bridge_datapath is
  -- 32-bit address register drives the PCI address bus
  signal addr_reg : std_logic_vector(31 downto 0) := (others => '0');
  -- 32-bit data buffer holds write data or captured read data
  signal data_reg : std_logic_vector(31 downto 0) := (others => '0');

  -- XOR-reduction parity of the data register (even parity check)
  signal parity_calc : std_logic;
begin

  -- Parity checker: XOR all bits of data register (even parity = 0 expected)
  parity_calc <= data_reg(31) xor data_reg(30) xor data_reg(29) xor
                 data_reg(28) xor data_reg(27) xor data_reg(26) xor
                 data_reg(25) xor data_reg(24) xor data_reg(23) xor
                 data_reg(22) xor data_reg(21) xor data_reg(20) xor
                 data_reg(19) xor data_reg(18) xor data_reg(17) xor
                 data_reg(16) xor data_reg(15) xor data_reg(14) xor
                 data_reg(13) xor data_reg(12) xor data_reg(11) xor
                 data_reg(10) xor data_reg(9)  xor data_reg(8)  xor
                 data_reg(7)  xor data_reg(6)  xor data_reg(5)  xor
                 data_reg(4)  xor data_reg(3)  xor data_reg(2)  xor
                 data_reg(1)  xor data_reg(0);

  -- Clocked process: register updates for address and data buffer
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        -- Synchronous reset clears registers and parity error
        addr_reg <= (others => '0');
        data_reg <= (others => '0');
      else
        -- Address register: load when load_addr asserted
        if load_addr = '1' then
          addr_reg <= addr_in;
        end if;

        -- Data buffer: load write data or capture read data
        if load_data = '1' then
          data_reg <= data_in;     -- store data to be written
        elsif read_en = '1' then
          data_reg <= data_in;     -- capture data read from PCI bus
        end if;
      end if;
    end if;
  end process;

  -- Drive PCI address bus from address register
  pci_addr   <= addr_reg;
  -- Drive write data onto PCI data bus
  pci_data_o <= data_reg;
  -- Provide captured read data to the bridge output
  data_out   <= data_reg;
  -- Parity error: asserted when parity is odd (simple even-parity check)
  parity_err <= parity_calc;

end architecture rtl;
