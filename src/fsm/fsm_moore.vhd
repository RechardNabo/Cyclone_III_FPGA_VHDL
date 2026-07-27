-- ============================================================================
-- Moore FSM: Detects pattern "101" in a serial bit stream
-- ============================================================================
-- Output is '1' for one clock cycle after the pattern "101" is seen.
-- In a Moore machine the output depends only on the current state.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fsm_moore is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;          -- active-high synchronous reset
        din      : in  std_logic;          -- serial bit stream input
        detected : out std_logic           -- '1' when "101" pattern found
    );
end entity fsm_moore;

architecture rtl of fsm_moore is

    -- State definitions for "101" detection (Moore needs a dedicated
    -- "found" state because the output depends only on the state)
    -- S0 : start / no match
    -- S1 : seen "1"
    -- S2 : seen "10"
    -- S3 : seen "101" -> output = '1'
    type state_type is (S0, S1, S2, S3);
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
    -- Next-state logic (combinational)
    -- -----------------------------------------------------------------------
    next_state_logic : process(current_state, din)
    begin
        case current_state is

            when S0 =>
                if din = '1' then
                    next_state <= S1;
                else
                    next_state <= S0;
                end if;

            when S1 =>
                if din = '0' then
                    next_state <= S2;
                else
                    next_state <= S1;
                end if;

            when S2 =>
                if din = '1' then
                    next_state <= S3;     -- "101" complete
                else
                    next_state <= S0;     -- "100"
                end if;

            when S3 =>
                -- after detection, the last '1' can start a new pattern
                if din = '1' then
                    next_state <= S1;
                else
                    next_state <= S2;     -- "1010" -> seen "10"
                end if;

            when others =>
                next_state <= S0;

        end case;
    end process next_state_logic;

    -- -----------------------------------------------------------------------
    -- Output logic (Moore: depends only on state)
    -- -----------------------------------------------------------------------
    output_logic : process(current_state)
    begin
        if current_state = S3 then
            detected <= '1';
        else
            detected <= '0';
        end if;
    end process output_logic;

end architecture rtl;
