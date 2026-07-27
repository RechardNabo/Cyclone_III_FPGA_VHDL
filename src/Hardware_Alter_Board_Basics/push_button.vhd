-- ============================================================================
-- Push Button with Debounce and Synchronizer
-- Target: Altera/Intel Cyclone III FPGA
-- 2-FF synchronizer to prevent metastability, then counter-based debounce.
-- Outputs a clean level signal and a one-cycle rising-edge tick.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity push_button is
    generic (
        CLK_FREQ_HZ     : integer := 50_000_000;  -- System clock
        DEBOUNCE_TIME_MS : integer := 10           -- Debounce window
    );
    port (
        clk       : in  std_logic;   -- System clock
        reset     : in  std_logic;   -- Active-low reset
        btn_in    : in  std_logic;   -- Raw button (active-high)
        btn_level : out std_logic;   -- Debounced level
        btn_tick  : out std_logic    -- One-cycle pulse on press
    );
end entity push_button;

architecture rtl of push_button is
    -- Debounce counter threshold (cycles for DEBOUNCE_TIME_MS)
    constant DEBOUNCE_COUNT : integer :=
        (CLK_FREQ_HZ / 1000) * DEBOUNCE_TIME_MS;

    -- 2-FF synchronizer signals
    signal sync_ff1 : std_logic := '0';
    signal sync_ff2 : std_logic := '0';

    -- Debounce counter and stable signal
    signal counter   : integer range 0 to DEBOUNCE_COUNT := 0;
    signal btn_stable : std_logic := '0';
    signal btn_prev   : std_logic := '0';
begin

    -- 2-FF synchronizer: align async button to clock domain
    sync_proc : process(clk, reset)
    begin
        if reset = '0' then
            sync_ff1 <= '0';
            sync_ff2 <= '0';
        elsif rising_edge(clk) then
            sync_ff1 <= btn_in;
            sync_ff2 <= sync_ff1;
        end if;
    end process sync_proc;

    -- Counter-based debounce: only accept change after stable period
    debounce_proc : process(clk, reset)
    begin
        if reset = '0' then
            counter    <= 0;
            btn_stable <= '0';
            btn_prev   <= '0';
            btn_tick   <= '0';
        elsif rising_edge(clk) then
            btn_tick <= '0';  -- Default: no tick

            if sync_ff2 /= btn_stable then
                -- Input changed from stable value; count up
                if counter = DEBOUNCE_COUNT - 1 then
                    -- Stable long enough: accept new value
                    btn_stable <= sync_ff2;
                    counter    <= 0;
                    -- Generate tick on rising edge (press)
                    if sync_ff2 = '1' and btn_prev = '0' then
                        btn_tick <= '1';
                    end if;
                    btn_prev <= sync_ff2;
                else
                    counter <= counter + 1;
                end if;
            else
                -- Input matches stable value; reset counter
                counter <= 0;
            end if;
        end if;
    end process debounce_proc;

    btn_level <= btn_stable;

end architecture rtl;
