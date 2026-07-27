-- ============================================================================
-- GCD Calculator - FSM Controller
-- States: IDLE, COMPARE, SUBTRACT, SWAP, DONE
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity gcd_fsm is
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    start     : in  std_logic;
    a_ge_b    : in  std_logic;  -- from datapath: A >= B
    b_eq_zero : in  std_logic;  -- from datapath: B = 0
    load_en   : out std_logic;  -- to datapath: load operands
    swap_en   : out std_logic;  -- to datapath: swap A and B
    sub_en    : out std_logic;  -- to datapath: A <= A - B
    done      : out std_logic
  );
end entity gcd_fsm;

architecture rtl of gcd_fsm is
  -- FSM states for the subtraction-based GCD algorithm
  type state_type is (IDLE, COMPARE, SUBTRACT, SWAP, DONE);
  signal state : state_type := IDLE;
begin

  -- Clocked process: state machine transitions and control output generation
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        -- Synchronous reset: return to IDLE, clear all control signals
        state    <= IDLE;
        load_en  <= '0';
        swap_en  <= '0';
        sub_en   <= '0';
        done     <= '0';
      else
        -- Default values to avoid latches
        load_en <= '0';
        swap_en <= '0';
        sub_en  <= '0';
        done    <= '0';

        case state is

          -- IDLE: wait for start signal
          when IDLE =>
            if start = '1' then
              load_en <= '1';      -- load operands into datapath
              state   <= COMPARE;
            end if;

          -- COMPARE: check if B is zero (done) or if A >= B
          when COMPARE =>
            if b_eq_zero = '1' then
              state <= DONE;       -- GCD found in A
            elsif a_ge_b = '1' then
              state <= SUBTRACT;   -- A >= B, subtract B from A
            else
              state <= SWAP;       -- A < B, swap so A >= B
            end if;

          -- SUBTRACT: A <= A - B, then compare again
          when SUBTRACT =>
            sub_en <= '1';
            state  <= COMPARE;

          -- SWAP: exchange A and B so the larger value is in A
          when SWAP =>
            swap_en <= '1';
            state   <= COMPARE;

          -- DONE: assert done for one cycle, return to IDLE
          when DONE =>
            done  <= '1';
            state <= IDLE;

          when others =>
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
