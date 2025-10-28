-- ============================================================================
-- Peripheral: Push Button (Board Basics) — Documentation-Only
-- Target: Altera/Intel Cyclone III FPGA
-- Purpose:
--   This file documents how to debounce and synchronize a mechanical
--   push button. No VHDL code is implemented here by request.
--
-- Overview:
-- - Mechanical bounce causes rapid transitions for several milliseconds.
-- - Debounce typically uses a counter or digital low-pass filter.
-- - Synchronize signals to clock domain to avoid metastability.
-- - Polarity depends on wiring (active-high vs active-low).
--
-- Pin Assignment (example; adjust to your board):
--   set_location_assignment PIN_<N> -to btn_in
--
-- Recommended HDL Structure (not implemented):
-- - Generics: ACTIVE_HIGH, DEBOUNCE_CYCLES (e.g., ~50k for 1 ms @ 50 MHz)
-- - Ports:    clk, reset_n, btn_in, btn_level, btn_tick
-- - Logic:    two-flop synchronizer; counter-based debounce; rising-edge tick
--
-- Usage Notes:
-- - Use 'btn_level' for level-sensitive logic; 'btn_tick' for one-shot events.
-- - Tune DEBOUNCE_CYCLES for your system clock and acceptable latency.
-- - If reading long-press vs short-press, add a duration counter in your design.
--
-- Bring-Up Checklist:
-- □ Pin mapped in .qsf/Pin Planner
-- □ Polarity verified (ACTIVE_HIGH vs active-low wiring)
-- □ Synchronizer included to system clock domain
-- □ Debounce window chosen for your clock frequency
--
-- TODOs:
-- - Create your own button interface entity/architecture.
-- - Validate debounce duration with real hardware presses.
-- - Consider ESD protection or pull-ups/downs per board schematic.
-- ============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity push_button is
    Port ( 
        -- Push button input (active low)
        BUTTON : in STD_LOGIC_VECTOR(2 downto 0);
        
        -- LED outputs (active high)
        LEDG : out STD_LOGIC_VECTOR(9 downto 0)
    );
end push_button;

architecture Behavioral of push_button is
begin
    -- When BUTTON0 is pressed (goes LOW), turn on LEDG0
    LEDG(0) <= NOT BUTTON(0);
    
    -- When BUTTON1 is pressed (goes LOW), turn on LEDG1
    LEDG(1) <= NOT BUTTON(1);
    
    -- When BUTTON2 is pressed (goes LOW), turn on LEDG2
    LEDG(2) <= NOT BUTTON(2);
    
    -- Turn off remaining LEDs
    LEDG(9 downto 3) <= (others => '0');

end Behavioral;