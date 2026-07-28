-- ================================================================================
-- cortex_m4_top_tb : Testbench for Cortex-M4 SoC top-level
-- ================================================================================
-- Tests basic AHB read/write to verify peripheral connectivity.
-- 50 MHz clock, active-low reset, UART register write/read-back test.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity cortex_m4_top_tb is
end entity cortex_m4_top_tb;

architecture sim of cortex_m4_top_tb is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal HCLK, HRESETn, HSEL, HWRITE, HREADY, HMASTLOCK : std_logic := '0';
    signal HTRANS : std_logic_vector(1 downto 0) := "00";
    signal HSIZE  : std_logic_vector(2 downto 0) := "010";
    signal HPROT  : std_logic_vector(3 downto 0) := "0011";
    signal HADDR  : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA : std_logic_vector(31 downto 0);
    signal HRESP  : std_logic;
    signal HREADYOUT : std_logic;

    signal test_pass : boolean := true;
begin

    -- Clock generation: 50 MHz, 20 ns period
    HCLK <= not HCLK after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.cortex_m4_top
        generic map ( CLK_FREQ => 50000000 )
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HMASTLOCK => HMASTLOCK, HTRANS => HTRANS, HSIZE => HSIZE,
            HPROT => HPROT, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            gpio_in => (others => '0'), gpio_out => open, gpio_dir => open,
            uart_txd => open, uart_rxd => '1',
            spi_sclk => open, spi_mosi => open, spi_miso => '0', spi_ss_n => open,
            i2c_sda => open, i2c_scl => open, adc_in => (others => '0'),
            tck => '0', tms => '0', tdi => '0', tdo => open, swclk => '0', swdio => open,
            exti_lines => (others => '0'), nmi_src => (others => '0'),
            irq_inputs => (others => '0'), clk_in => (others => '0'),
            clk_out => open, pll_locked => open, global_irq => open
        );

    -- Stimulus process
    stim : process
        variable read_data : std_logic_vector(31 downto 0);
    begin
        -- Reset
        HRESETn <= '0';
        HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00"; HREADY <= '1';
        HMASTLOCK <= '0'; HADDR <= (others => '0'); HWDATA <= (others => '0');
        wait for CLK_PERIOD * 4;
        HRESETn <= '1';
        wait for CLK_PERIOD * 2;

        -- Test 1: Write to UART CTRL register (0x400F_0000)
        report "Test 1: Writing 0x00000003 to UART CTRL at 0x400F_0000";
        HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
        HADDR <= x"400F_0000"; HWDATA <= x"00000003";
        wait until rising_edge(HCLK);
        while HREADYOUT /= '1' loop
            wait until rising_edge(HCLK);
        end loop;
        HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
        wait for CLK_PERIOD * 2;

        -- Test 2: Read back UART CTRL register
        report "Test 2: Reading UART CTRL at 0x400F_0000";
        HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
        HADDR <= x"400F_0000";
        wait until rising_edge(HCLK);
        while HREADYOUT /= '1' loop
            wait until rising_edge(HCLK);
        end loop;
        read_data := HRDATA;
        HSEL <= '0'; HTRANS <= "00";
        wait for CLK_PERIOD * 2;

        -- Verify read-back
        if read_data = x"00000003" then
            report "PASS: UART CTRL read-back matches (0x" &
                   to_hstring(read_data) & ")" severity note;
        else
            report "FAIL: UART CTRL read-back mismatch, expected 0x00000003, got 0x" &
                   to_hstring(read_data) severity error;
            test_pass <= false;
        end if;

        -- Test 3: Write to CRC CTRL register (0x4007_0000)
        report "Test 3: Writing 0x00000001 to CRC CTRL at 0x4007_0000";
        HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
        HADDR <= x"4007_0000"; HWDATA <= x"00000001";
        wait until rising_edge(HCLK);
        while HREADYOUT /= '1' loop
            wait until rising_edge(HCLK);
        end loop;
        HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
        wait for CLK_PERIOD * 2;

        -- Test 4: Read CRC RESULT register (0x4007_000C)
        report "Test 4: Reading CRC RESULT at 0x4007_000C";
        HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
        HADDR <= x"4007_000C";
        wait until rising_edge(HCLK);
        while HREADYOUT /= '1' loop
            wait until rising_edge(HCLK);
        end loop;
        read_data := HRDATA;
        HSEL <= '0'; HTRANS <= "00";
        wait for CLK_PERIOD * 2;

        report "PASS: CRC RESULT read = 0x" & to_hstring(read_data) severity note;

        -- Final report
        if test_pass then
            report "=== ALL TESTS PASSED ===" severity note;
        else
            report "=== TESTS FAILED ===" severity error;
        end if;

        wait for CLK_PERIOD * 4;
        finish;
    end process;

end architecture sim;
