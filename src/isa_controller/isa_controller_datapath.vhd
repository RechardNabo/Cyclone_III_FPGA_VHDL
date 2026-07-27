-- ============================================================================
-- ISA Controller - Datapath
-- 16-bit address register, 8-bit data register, control signal outputs
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity isa_controller_datapath is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    addr_in    : in  std_logic_vector(15 downto 0);
    data_in    : in  std_logic_vector(7 downto 0);
    load_addr  : in  std_logic;  -- load address register
    load_data  : in  std_logic;  -- load data register (write path)
    read_en    : in  std_logic;  -- capture read data into data register
    isa_addr   : out std_logic_vector(15 downto 0); -- bus address
    isa_data_o : out std_logic_vector(7 downto 0);  -- data to bus (write)
    data_out   : out std_logic_vector(7 downto 0)   -- captured read data
  );
end entity isa_controller_datapath;

architecture rtl of isa_controller_datapath is
  -- 16-bit address register drives the ISA address bus
  signal addr_reg : std_logic_vector(15 downto 0) := (others => '0');
  -- 8-bit data register holds write data or captured read data
  signal data_reg : std_logic_vector(7 downto 0) := (others => '0');
begin

  -- Clocked process: register updates for address and data
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        -- Synchronous reset clears both registers
        addr_reg <= (others => '0');
        data_reg <= (others => '0');
      else
        -- Address register: load when load_addr asserted
        if load_addr = '1' then
          addr_reg <= addr_in;
        end if;

        -- Data register: load write data or capture read data
        if load_data = '1' then
          data_reg <= data_in;     -- store data to be written
        elsif read_en = '1' then
          data_reg <= data_in;     -- capture data read from bus
        end if;
      end if;
    end if;
  end process;

  -- Drive ISA bus address from address register
  isa_addr   <= addr_reg;
  -- Drive write data onto ISA data bus
  isa_data_o <= data_reg;
  -- Provide captured read data to the controller output
  data_out   <= data_reg;

end architecture rtl;
