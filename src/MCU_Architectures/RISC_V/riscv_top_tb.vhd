-- ================================================================================
-- riscv_top_tb : Testbench for RISC-V SoC top-level
-- ================================================================================
-- Tests basic AHB read/write to verify peripheral connectivity.
-- 50 MHz clock, active-low AHB reset, active-high core reset.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity riscv_top_tb is
end entity riscv_top_tb;

architecture sim of riscv_top_tb is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal HCLK, HRESETn, HSEL, HWRITE, HREADY : std_logic := '0';
    signal HTRANS : std_logic_vector(1 downto 0) := "00";
    signal HSIZE  : std_logic_vector(2 downto 0) := "010";
    signal HADDR  : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA : std_logic_vector(31 downto 0);
    signal HRESP  : std_logic;
    signal HREADYOUT : std_logic;

    signal clk, reset : std_logic := '0';
    signal test_pass : boolean := true;
begin

    -- Clock generation: 50 MHz, 20 ns period
    HCLK <= not HCLK after CLK_PERIOD / 2;
    clk  <= not clk  after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.riscv_top
        generic map ( CLK_FREQ => 50000000 )
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            clk => clk, reset => reset,
            core_uart_txd => open, core_uart_rxd => '1',
            core_spi_sclk => open, core_spi_mosi => open, core_spi_miso => '0',
            core_i2c_sda => open, core_i2c_scl => open,
            core_adc_in => (others => '0'),
            uart_txd => open, uart_rxd => '1',
            spi_sclk => open, spi_mosi => open, spi_miso => '0', spi_ss_n => open,
            i2c_sda => open, i2c_scl => open,
            ext_irq_src => (others => '0'), global_irq => open
        );

    -- Stimulus process
    stim : process
        variable read_data : std_logic_vector(31 downto 0);
    begin
        -- Reset both AHB and core
        HRESETn <= '0'; reset <= '1';
        HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00"; HREADY <= '1';
        HADDR <= (others => '0'); HWDATA <= (others => '0');
        wait for CLK_PERIOD * 4;
        HRESETn <= '1'; reset <= '0';
        wait for CLK_PERIOD * 2;

        -- Test 1: Write to UART CTRL register (0x4009_0000)
        report "Test 1: Writing 0x00000003 to UART CTRL at 0x4009_0000";
        HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
        HADDR <= x"4009_0000"; HWDATA <= x"00000003";
        wait until rising_edge(HCLK);
        while HREADYOUT /= '1' loop
            wait until rising_edge(HCLK);
        end loop;
        HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
        wait for CLK_PERIOD * 2;

        -- Test 2: Read back UART CTRL register
        report "Test 2: Reading UART CTRL at 0x4009_0000";
        HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
        HADDR <= x"4009_0000";
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
        report "Test 3: Writing 0x00000008 to CRC CTRL at 0x4007_0000";
        HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
        HADDR <= x"4007_0000"; HWDATA <= x"00000008";
        wait until rising_edge(HCLK);
        while HREADYOUT /= '1' loop
            wait until rising_edge(HCLK);
        end loop;
        HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
        wait for CLK_PERIOD * 2;

        -- Test 4: Read TRNG STAT register (0x4008_0004)
        report "Test 4: Reading TRNG STAT at 0x4008_0004";
        HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
        HADDR <= x"4008_0004";
        wait until rising_edge(HCLK);
        while HREADYOUT /= '1' loop
            wait until rising_edge(HCLK);
        end loop;
        read_data := HRDATA;
        HSEL <= '0'; HTRANS <= "00";
        wait for CLK_PERIOD * 2;

        report "PASS: TRNG STAT read = 0x" & to_hstring(read_data) severity note;

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
