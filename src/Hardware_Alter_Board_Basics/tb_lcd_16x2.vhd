-- Testbench for LCD 16x2 driver
-- Tests initialization sequence and character write operations
-- Uses small CLK_FREQ_HZ for fast simulation
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_lcd_16x2 is
end entity tb_lcd_16x2;

architecture test of tb_lcd_16x2 is

    signal clk       : std_logic := '0';
    signal reset_n   : std_logic := '0';  -- active-low
    signal char_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal is_cmd    : std_logic := '0';
    signal write_stb : std_logic := '0';
    signal busy      : std_logic;
    signal lcd_rs    : std_logic;
    signal lcd_rw    : std_logic;
    signal lcd_en    : std_logic;
    signal lcd_data  : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 10 ns;

    -- Small clock frequency for fast simulation
    -- INIT_WAIT: CLK_FREQ_HZ/1000 * 15 = 1000/1000 * 15 = 15 cycles
    -- Each init step: 100 cycles
    -- Total init: 15 + 4*100 = 415 cycles
    constant CLK_FREQ_TB : integer := 1000;

begin

    dut : entity work.lcd_16x2
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_TB
        )
        port map (
            clk       => clk,
            reset_n   => reset_n,
            char_in   => char_in,
            is_cmd    => is_cmd,
            write_stb => write_stb,
            busy      => busy,
            lcd_rs    => lcd_rs,
            lcd_rw    => lcd_rw,
            lcd_en    => lcd_en,
            lcd_data  => lcd_data
        );

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process clk_proc;

    -- Stimulus process
    stim_proc : process
    begin

        ----------------------------------------------------------------
        -- Test 1: Reset (active-low) -> busy=1, lcd_rw=0
        ----------------------------------------------------------------
        reset_n   <= '0';
        char_in   <= x"00";
        is_cmd    <= '0';
        write_stb <= '0';
        wait for CLK_PERIOD * 2;
        assert busy = '1'
            report "Test 1a failed: busy should be 1 during reset" severity error;
        assert lcd_rw = '0'
            report "Test 1b failed: lcd_rw should always be 0" severity error;

        ----------------------------------------------------------------
        -- Test 2: Release reset, should be busy during init
        ----------------------------------------------------------------
        reset_n <= '1';
        wait for CLK_PERIOD;
        assert busy = '1'
            report "Test 2 failed: busy should be 1 during init" severity error;

        ----------------------------------------------------------------
        -- Test 3: Wait for initialization to complete
        --         INIT_WAIT = 15 cycles, INIT_FUNC = 101 cycles,
        --         INIT_DISP = 101, INIT_CLEAR = 101, INIT_ENTRY = 101
        --         Total ~ 419 cycles, wait a bit more
        ----------------------------------------------------------------
        wait for CLK_PERIOD * 450;
        assert busy = '0'
            report "Test 3 failed: busy should be 0 after init completes" severity error;

        ----------------------------------------------------------------
        -- Test 4: Write a character 'A' (0x41) as data
        ----------------------------------------------------------------
        char_in   <= x"41";  -- 'A'
        is_cmd    <= '0';    -- data
        write_stb <= '1';
        wait for CLK_PERIOD;
        write_stb <= '0';
        -- Should be busy now
        wait for CLK_PERIOD;
        assert busy = '1'
            report "Test 4a failed: busy should be 1 during write" severity error;
        -- WRITE_PULSE = 101 cycles, WRITE_HOLD = 201 cycles
        -- Total ~302 cycles
        wait for CLK_PERIOD * 310;
        assert busy = '0'
            report "Test 4b failed: busy should be 0 after write completes" severity error;

        ----------------------------------------------------------------
        -- Test 5: Write a command (0x01 = clear display)
        ----------------------------------------------------------------
        char_in   <= x"01";
        is_cmd    <= '1';    -- command
        write_stb <= '1';
        wait for CLK_PERIOD;
        write_stb <= '0';
        wait for CLK_PERIOD;
        assert busy = '1'
            report "Test 5a failed: busy should be 1 during command write" severity error;
        wait for CLK_PERIOD * 310;
        assert busy = '0'
            report "Test 5b failed: busy should be 0 after command write" severity error;

        ----------------------------------------------------------------
        -- Test 6: Write another character 'H' (0x48)
        ----------------------------------------------------------------
        char_in   <= x"48";
        is_cmd    <= '0';
        write_stb <= '1';
        wait for CLK_PERIOD;
        write_stb <= '0';
        wait for CLK_PERIOD * 310;
        assert busy = '0'
            report "Test 6 failed: busy should be 0 after write" severity error;

        ----------------------------------------------------------------
        -- Test 7: Verify lcd_rw is always 0 (write-only mode)
        ----------------------------------------------------------------
        assert lcd_rw = '0'
            report "Test 7 failed: lcd_rw should always be 0" severity error;

        ----------------------------------------------------------------
        -- Test 8: Reset during idle returns to init
        ----------------------------------------------------------------
        assert busy = '0'
            report "Test 8a failed: should be idle before reset" severity error;
        reset_n <= '0';
        wait for CLK_PERIOD * 2;
        assert busy = '1'
            report "Test 8b failed: busy should be 1 after reset" severity error;
        reset_n <= '1';
        -- Wait for re-initialization
        wait for CLK_PERIOD * 450;
        assert busy = '0'
            report "Test 8c failed: busy should be 0 after re-init" severity error;

        ----------------------------------------------------------------
        -- Test 9: Back-to-back writes
        ----------------------------------------------------------------
        -- Write 'I' (0x49)
        char_in   <= x"49";
        is_cmd    <= '0';
        write_stb <= '1';
        wait for CLK_PERIOD;
        write_stb <= '0';
        wait for CLK_PERIOD * 310;
        assert busy = '0'
            report "Test 9a failed: busy should be 0 after first write" severity error;
        -- Write 'D' (0x44)
        char_in   <= x"44";
        write_stb <= '1';
        wait for CLK_PERIOD;
        write_stb <= '0';
        wait for CLK_PERIOD * 310;
        assert busy = '0'
            report "Test 9b failed: busy should be 0 after second write" severity error;

        report "All lcd_16x2 tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim_proc;

end architecture test;
