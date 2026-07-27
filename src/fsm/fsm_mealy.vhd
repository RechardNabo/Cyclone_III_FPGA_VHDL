-- ============================================================================
-- Mealy FSM: Detects pattern "101" in a serial bit stream
-- ============================================================================
-- Output is '1' immediately when the last three bits are "101".
-- In a Mealy machine the output depends on both state and input.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fsm_mealy is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;          -- active-high synchronous reset
        din      : in  std_logic;          -- serial bit stream input
        detected : out std_logic           -- '1' when "101" pattern found
    );
end entity fsm_mealy;

architecture rtl of fsm_mealy is

    -- State definitions for "101" detection
    -- S0 : start / no match (last bit seen was '0' or reset)
    -- S1 : seen "1"
    -- S2 : seen "10"
    type state_type is (S0, S1, S2);
    signal current_state : state_type;
    signal next_state    : state_type;

begin

    -- -----------------------------------------------------------------------
    -- State register: synchronous reset and state update on rising edge
    -- -----------------------------------------------------------------------
    state_reg : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= S0;
            else
                current_state <= next_state;
            end if;
        end if;
    end process state_reg;

    -- -----------------------------------------------------------------------
    -- Next-state and output logic (combinational, Mealy)
    -- -----------------------------------------------------------------------
    next_state_logic : process(current_state, din)
    begin
        -- default assignments
        next_state <= S0;
        detected   <= '0';

        case current_state is

            when S0 =>
                -- waiting for first '1' of the pattern
                if din = '1' then
                    next_state <= S1;
                else
                    next_state <= S0;
                end if;
                detected <= '0';

            when S1 =>
                -- seen "1", need "0" next
                if din = '0' then
                    next_state <= S2;
                else
                    next_state <= S1;   -- still have "1"
                end if;
                detected <= '0';

            when S2 =>
                -- seen "10", a '1' here completes "101"
                if din = '1' then
                    next_state <= S1;   -- overlapping: last '1' starts new pattern
                    detected   <= '1';  -- Mealy output asserted immediately
                else
                    next_state <= S0;   -- "100" -> back to start
                    detected   <= '0';
                end if;

            when others =>
                next_state <= S0;
                detected   <= '0';

        end case;
    end process next_state_logic;

end architecture rtl;
