-- ============================================================================
-- Peripheral: LEDs (Board Basics) — Documentation-Only
-- Target: Altera/Intel Cyclone III FPGA
-- Purpose:
--   This file documents how to interface on-board LEDs. No VHDL code is
--   implemented here by request; use this as guidance when creating your
--   own entity/architecture.
--
-- Overview:
-- - LEDs visualize internal states, counters, and status flags.
-- - Polarity depends on board wiring: active-high vs active-low.
-- - Drive strength/current is set in constraints, not in HDL.
--
-- Pin Assignments (example; adjust to your board):
--   set_location_assignment PIN_<N> -to leds[0]
--   set_location_assignment PIN_<N> -to leds[1]
--   set_location_assignment PIN_<N> -to leds[2]
--   ...
--   set_instance_assignment -name CURRENT_STRENGTH_NEW <mA> -to leds[*]
--
-- Recommended HDL Structure (not implemented):
-- - Generic: LED_COUNT, ACTIVE_HIGH
-- - Ports:  led_in (design output), leds (board pins)
-- - Logic:  leds <= led_in when ACTIVE_HIGH else not led_in;
--
-- Usage Notes:
-- - Map meaningful signals (FSM state, error flags) to LED bits.
-- - Confirm polarity via schematic or quick probe.
-- - Avoid toggling too fast for human perception; add dividers if needed.
--
-- Bring-Up Checklist:
-- □ Pins assigned in .qsf or Pin Planner
-- □ Polarity verified (ACTIVE_HIGH vs active-low wiring)
-- □ LED count matches board
-- □ Optional: current strength set per board specs
--
-- TODOs:
-- - Create your own LED driver entity/architecture when ready.
-- - Update constraints to match exact board pinout.
-- - If desired, add a test pattern/blinker for validation.
-- ============================================================================
-- IEEE Libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity Declaration
entity leds is
    generic (
        CLK_FREQ_HZ : integer := 50_000_000  -- 50 MHz clock frequency
    );
    port (
        clk     : in  std_logic;             -- System clock (50 MHz on DE0)
        reset   : in  std_logic;             -- Active LOW reset (button press)
        led_out : out std_logic              -- LED output (blinks every 1 second)
    );
end entity leds;

-- Architecture Implementation
architecture behavioral of leds is
    -- Constants
    constant COUNT_MAX : integer := CLK_FREQ_HZ - 1;  -- Count for 1 second (49,999,999)
    
    -- Signals
    signal counter   : unsigned(25 downto 0) := (others => '0');  -- 26 bits for 50M count
    signal led_state : std_logic := '0';
    
begin
    -- Counter process for 1-second timing
    counter_process : process(clk, reset)
    begin
        if reset = '0' then  -- Active LOW reset (button pressed)
            counter   <= (others => '0');
            led_state <= '0';
        elsif rising_edge(clk) then
            if counter = COUNT_MAX then
                counter   <= (others => '0');
                led_state <= not led_state;  -- Toggle LED every second
            else
                counter <= counter + 1;
            end if;
        end if;
    end process counter_process;
    
    -- Output assignment
    led_out <= led_state;
    
end architecture behavioral;