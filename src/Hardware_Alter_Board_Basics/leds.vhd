-- ============================================================================
-- LED Blinker — 1 Hz from 50 MHz Clock
-- Target: Altera/Intel Cyclone III FPGA
-- Toggles a single LED every 1 second using a counter.
-- At 50 MHz, 1 second = 50,000,000 cycles; toggle at half = 25,000,000.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity leds is
    generic (
        CLK_FREQ_HZ : integer := 50_000_000  -- System clock frequency
    );
    port (
        clk     : in  std_logic;  -- System clock (50 MHz on DE0)
        reset   : in  std_logic;  -- Active-low reset
        led_out : out std_logic   -- LED output (blinks at 1 Hz)
    );
end entity leds;

architecture behavioral of leds is
    -- Count to half a second, then toggle LED
    constant COUNT_MAX : integer := CLK_FREQ_HZ / 2 - 1;
    signal counter     : integer range 0 to COUNT_MAX := 0;
    signal led_state   : std_logic := '0';
begin

    blink_proc : process(clk, reset)
    begin
        if reset = '0' then
            -- Active-low reset: button pressed = reset
            counter   <= 0;
            led_state <= '0';
        elsif rising_edge(clk) then
            if counter = COUNT_MAX then
                counter   <= 0;
                led_state <= not led_state;  -- Toggle every half second
            else
                counter <= counter + 1;
            end if;
        end if;
    end process blink_proc;

    led_out <= led_state;

end architecture behavioral;
