-- ============================================================================
-- Serial Adder - FSMD Top-Level
-- Integrates serial_adder_fsm + serial_adder_datapath
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity serial_adder_fsmd is
  port (
    clk   : in  std_logic;
    reset : in  std_logic;
    start : in  std_logic;
    a     : in  std_logic_vector(7 downto 0);
    b     : in  std_logic_vector(7 downto 0);
    sum   : out std_logic_vector(7 downto 0);
    done  : out std_logic
  );
end entity serial_adder_fsmd;

architecture rtl of serial_adder_fsmd is
  -- Control signals from FSM to datapath
  signal load_en  : std_logic;
  signal shift_en : std_logic;
begin

  -- FSM controller instance
  u_fsm : entity work.serial_adder_fsm
    port map (
      clk      => clk,
      reset    => reset,
      start    => start,
      load_en  => load_en,
      shift_en => shift_en,
      done     => done
    );

  -- Datapath instance
  u_datapath : entity work.serial_adder_datapath
    port map (
      clk      => clk,
      reset    => reset,
      a_in     => a,
      b_in     => b,
      load_en  => load_en,
      shift_en => shift_en,
      sum_out  => sum
    );

end architecture rtl;
