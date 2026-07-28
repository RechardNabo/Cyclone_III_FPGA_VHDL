-- ============================================================================
-- GCD Calculator - FSM Controller
-- States: IDLE, LOAD, COMPARE, SUBTRACT, WAIT_SUB, SWAP, WAIT_SWAP, DONE
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
  type state_type is (IDLE, LOAD, COMPARE, SUBTRACT, SWAP, ST_DONE);
  signal state : state_type := IDLE;
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state    <= IDLE;
        load_en  <= '0';
        swap_en  <= '0';
        sub_en   <= '0';
        done     <= '0';
      else
        load_en <= '0';
        swap_en <= '0';
        sub_en  <= '0';
        done    <= '0';

        case state is

          when IDLE =>
            if start = '1' then
              load_en <= '1';
              state   <= LOAD;
            end if;

          -- LOAD: wait one cycle for datapath to load operands
          when LOAD =>
            state <= COMPARE;

          -- COMPARE: a_ge_b and b_eq_zero now reflect loaded/updated registers
          when COMPARE =>
            if b_eq_zero = '1' then
              state <= ST_DONE;
            elsif a_ge_b = '1' then
              sub_en <= '1';   -- assert sub_en NOW, datapath subtracts this edge
              state  <= SUBTRACT;
            else
              swap_en <= '1';  -- assert swap_en NOW, datapath swaps this edge
              state   <= SWAP;
            end if;

          -- SUBTRACT: datapath has already subtracted (sub_en was set in COMPARE).
          -- Go back to COMPARE to check updated values.
          when SUBTRACT =>
            state <= COMPARE;

          -- SWAP: datapath has already swapped (swap_en was set in COMPARE).
          -- Go back to COMPARE to check updated values.
          when SWAP =>
            state <= COMPARE;

          when ST_DONE =>
            done  <= '1';
            state <= IDLE;

          when others =>
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
