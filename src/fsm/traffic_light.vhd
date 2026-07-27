-- ============================================================================
-- Traffic Light Controller FSM with timer-based transitions
-- ============================================================================
-- States: GREEN -> YELLOW -> RED -> (repeat)
-- Each state stays active for a configurable number of clock cycles.
-- The generic CLK_FREQ lets the user set the system clock frequency in Hz;
-- default timers are 5 s green, 2 s yellow, 5 s red.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity traffic_light is
    generic (
        CLK_FREQ : integer := 50_000_000   -- 50 MHz default Cyclone III clock
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;            -- active-high synchronous reset
        red   : out std_logic;
        green : out std_logic;
        yellow: out std_logic
    );
end entity traffic_light;

architecture rtl of traffic_light is

    -- Timer constants (seconds * clock frequency)
    constant GREEN_TIME  : integer := 5 * CLK_FREQ;
    constant YELLOW_TIME : integer := 2 * CLK_FREQ;
    constant RED_TIME    : integer := 5 * CLK_FREQ;

    -- FSM states
    type state_type is (S_GREEN, S_YELLOW, S_RED);
    signal current_state : state_type;
    signal next_state    : state_type;

    -- Timer counter
    signal timer : integer range 0 to RED_TIME;

begin

    -- -----------------------------------------------------------------------
    -- State register and timer (clocked)
    -- -----------------------------------------------------------------------
    state_reg : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= S_GREEN;
                timer         <= 0;
            else
                current_state <= next_state;
                if next_state /= current_state then
                    timer <= 0;           -- reset timer on state change
                else
                    timer <= timer + 1;   -- count time in current state
                end if;
            end if;
        end if;
    end process state_reg;

    -- -----------------------------------------------------------------------
    -- Next-state logic (combinational, timer-based transitions)
    -- -----------------------------------------------------------------------
    next_state_logic : process(current_state, timer)
    begin
        case current_state is

            when S_GREEN =>
                if timer >= GREEN_TIME - 1 then
                    next_state <= S_YELLOW;
                else
                    next_state <= S_GREEN;
                end if;

            when S_YELLOW =>
                if timer >= YELLOW_TIME - 1 then
                    next_state <= S_RED;
                else
                    next_state <= S_YELLOW;
                end if;

            when S_RED =>
                if timer >= RED_TIME - 1 then
                    next_state <= S_GREEN;
                else
                    next_state <= S_RED;
                end if;

            when others =>
                next_state <= S_GREEN;

        end case;
    end process next_state_logic;

    -- -----------------------------------------------------------------------
    -- Output logic (Moore: one light active per state)
    -- -----------------------------------------------------------------------
    output_logic : process(current_state)
    begin
        red    <= '0';
        green  <= '0';
        yellow <= '0';
        case current_state is
            when S_GREEN  => green  <= '1';
            when S_YELLOW => yellow <= '1';
            when S_RED    => red    <= '1';
            when others   => green  <= '1';
        end case;
    end process output_logic;

end architecture rtl;
