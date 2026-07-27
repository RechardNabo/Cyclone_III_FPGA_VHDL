-- ============================================================================
-- GCD Calculator - RTL Top-Level
-- Integrates gcd_fsm (controller) + gcd_datapath (datapath)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity gcd_rtl is
  port (
    clk     : in  std_logic;
    reset   : in  std_logic;
    start   : in  std_logic;
    a       : in  std_logic_vector(7 downto 0);
    b       : in  std_logic_vector(7 downto 0);
    gcd_out : out std_logic_vector(7 downto 0);
    done    : out std_logic
  );
end entity gcd_rtl;

architecture rtl of gcd_rtl is
  -- Control signals from FSM to datapath
  signal load_en   : std_logic;
  signal swap_en   : std_logic;
  signal sub_en    : std_logic;

  -- Status signals from datapath to FSM
  signal a_ge_b    : std_logic;
  signal b_eq_zero : std_logic;

  -- Datapath register outputs
  signal a_out     : std_logic_vector(7 downto 0);
  signal b_out     : std_logic_vector(7 downto 0);
begin

  -- FSM controller instance
  u_fsm : entity work.gcd_fsm
    port map (
      clk       => clk,
      reset     => reset,
      start     => start,
      a_ge_b    => a_ge_b,
      b_eq_zero => b_eq_zero,
      load_en   => load_en,
      swap_en   => swap_en,
      sub_en    => sub_en,
      done      => done
    );

  -- Datapath instance
  u_datapath : entity work.gcd_datapath
    port map (
      clk       => clk,
      reset     => reset,
      a_in      => a,
      b_in      => b,
      load_en   => load_en,
      swap_en   => swap_en,
      sub_en    => sub_en,
      a_out     => a_out,
      b_out     => b_out,
      a_ge_b    => a_ge_b,
      b_eq_zero => b_eq_zero
    );

  -- GCD result is the value in A when B reaches zero
  gcd_out <= a_out;

end architecture rtl;
