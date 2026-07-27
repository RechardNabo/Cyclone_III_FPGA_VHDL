-- ============================================================================
-- ISA Controller - FSMD Top-Level
-- Integrates isa_controller_fsm + isa_controller_datapath
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity isa_controller_fsmd is
  port (
    clk      : in  std_logic;
    reset    : in  std_logic;
    start    : in  std_logic;
    addr     : in  std_logic_vector(15 downto 0);
    data_in  : in  std_logic_vector(7 downto 0);
    rw       : in  std_logic;   -- '1' = read, '0' = write
    data_out : out std_logic_vector(7 downto 0);
    done     : out std_logic
  );
end entity isa_controller_fsmd;

architecture rtl of isa_controller_fsmd is
  -- Control signals from FSM to datapath
  signal load_addr : std_logic;
  signal load_data : std_logic;
  signal read_en   : std_logic;

  -- ISA bus signals (internal, could be exported for real bus)
  signal isa_addr   : std_logic_vector(15 downto 0);
  signal isa_data_o : std_logic_vector(7 downto 0);
begin

  -- FSM controller instance
  u_fsm : entity work.isa_controller_fsm
    port map (
      clk       => clk,
      reset     => reset,
      start     => start,
      rw        => rw,
      load_addr => load_addr,
      load_data => load_data,
      read_en   => read_en,
      done      => done
    );

  -- Datapath instance
  u_datapath : entity work.isa_controller_datapath
    port map (
      clk        => clk,
      reset      => reset,
      addr_in    => addr,
      data_in    => data_in,
      load_addr  => load_addr,
      load_data  => load_data,
      read_en    => read_en,
      isa_addr   => isa_addr,
      isa_data_o => isa_data_o,
      data_out   => data_out
    );

end architecture rtl;
