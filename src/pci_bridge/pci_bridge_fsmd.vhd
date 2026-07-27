-- ============================================================================
-- PCI Bridge - FSMD Top-Level
-- Integrates pci_bridge_fsm + pci_bridge_datapath
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pci_bridge_fsmd is
  port (
    clk      : in  std_logic;
    reset    : in  std_logic;
    start    : in  std_logic;
    addr     : in  std_logic_vector(31 downto 0);
    data_in  : in  std_logic_vector(31 downto 0);
    rw       : in  std_logic;   -- '1' = read, '0' = write
    data_out : out std_logic_vector(31 downto 0);
    done     : out std_logic
  );
end entity pci_bridge_fsmd;

architecture rtl of pci_bridge_fsmd is
  -- Control signals from FSM to datapath
  signal load_addr : std_logic;
  signal load_data : std_logic;
  signal read_en   : std_logic;

  -- PCI bus signals (internal, could be exported for real bus)
  signal pci_addr   : std_logic_vector(31 downto 0);
  signal pci_data_o : std_logic_vector(31 downto 0);
  signal parity_err : std_logic;
begin

  -- FSM controller instance
  u_fsm : entity work.pci_bridge_fsm
    port map (
      clk       => clk,
      reset     => reset,
      start     => start,
      rw        => rw,
      load_addr => load_addr,
      load_data => load_data,
      read_en   => read_en,
      req_n     => open,        -- bus request not exported at top level
      done      => done
    );

  -- Datapath instance
  u_datapath : entity work.pci_bridge_datapath
    port map (
      clk        => clk,
      reset      => reset,
      addr_in    => addr,
      data_in    => data_in,
      load_addr  => load_addr,
      load_data  => load_data,
      read_en    => read_en,
      pci_addr   => pci_addr,
      pci_data_o => pci_data_o,
      data_out   => data_out,
      parity_err => parity_err
    );

end architecture rtl;
