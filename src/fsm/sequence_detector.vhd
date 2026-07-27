-- ============================================================================
-- Moore FSM: Detects overlapping sequence "1101" in a serial bit stream
-- ============================================================================
-- Output is '1' for one clock cycle after "1101" is seen.
-- Overlapping matches are allowed (e.g. "1101101" matches twice).
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sequence_detector is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;          -- active-high synchronous reset
        din      : in  std_logic;          -- serial bit stream input
        detected : out std_logic           -- '1' when "1101" pattern found
    );
end entity sequence_detector;

architecture rtl of sequence_detector is

    -- State definitions for "1101" detection (Moore)
    -- S0 : start / no progress
    -- S1 : seen "1"
    -- S2 : seen "11"
    -- S3 : seen "110"
    -- S4 : seen "1101" -> output = '1'
    type state_type is (S0, S1, S2, S3, S4);
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
                    next_state <= S1;     -- got first '1'
                else
                    next_state <= S0;
                end if;

            when S1 =>
                if din = '1' then
                    next_state <= S2;     -- "11"
                else
                    next_state <= S0;     -- "10" -> restart
                end if;

            when S2 =>
                if din = '0' then
                    next_state <= S3;     -- "110"
                else
                    next_state <= S2;     -- "111" -> still have "11"
                end if;

            when S3 =>
                if din = '1' then
                    next_state <= S4;     -- "1101" complete
                else
                    next_state <= S0;     -- "1100" -> restart
                end if;

            when S4 =>
                -- overlapping: last '1' of "1101" is first '1' of next pattern
                if din = '1' then
                    next_state <= S2;     -- seen "11" (from the trailing '1')
                else
                    next_state <= S0;     -- trailing '1' followed by '0'
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
        if current_state = S4 then
            detected <= '1';
        else
            detected <= '0';
        end if;
    end process output_logic;

end architecture rtl;
