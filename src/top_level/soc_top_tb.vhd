-- ================================================================================
-- soc_top_tb : Testbench for unified multi-core SoC top-level
-- ================================================================================
-- Tests basic AHB read/write via master 0 (Cortex-M4) to shared peripherals.
-- 50 MHz clock, active-low reset, ext_sram and bootloader register tests.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity soc_top_tb is
end entity soc_top_tb;

architecture sim of soc_top_tb is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal HCLK, HRESETn : std_logic := '0';
    signal m_HSEL, m_HWRITE, m_HREADY, m_HMASTLOCK : std_logic_vector(3 downto 0) := "0000";
    signal m_HTRANS : std_logic_vector(7 downto 0) := (others => '0');
    signal m_HSIZE  : std_logic_vector(11 downto 0) := (others => '0');
    signal m_HPROT  : std_logic_vector(15 downto 0) := (others => '0');
    signal m_HADDR  : std_logic_vector(127 downto 0) := (others => '0');
    signal m_HWDATA : std_logic_vector(127 downto 0) := (others => '0');
    signal m_HRDATA : std_logic_vector(127 downto 0);
    signal m_HRESP  : std_logic_vector(3 downto 0);
    signal m_HREADYOUT : std_logic_vector(3 downto 0);

    signal rv_clk, rv_reset : std_logic := '0';
    signal rp_clk, rp_nRESET : std_logic := '0';
    signal rp_irq_out, global_irq : std_logic;

    signal sram_data : std_logic_vector(31 downto 0) := (others => 'Z');
    signal test_pass : boolean := true;
begin

    -- Clock generation: 50 MHz, 20 ns period
    HCLK  <= not HCLK  after CLK_PERIOD / 2;
    rv_clk <= not rv_clk after CLK_PERIOD / 2;
    rp_clk <= not rp_clk after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.soc_top
        generic map ( CLK_FREQ => 50000000 )
        port map (
            HCLK => HCLK, HRESETn => HRESETn,
            m_HSEL => m_HSEL, m_HWRITE => m_HWRITE, m_HREADY => m_HREADY,
            m_HMASTLOCK => m_HMASTLOCK, m_HTRANS => m_HTRANS, m_HSIZE => m_HSIZE,
            m_HPROT => m_HPROT, m_HADDR => m_HADDR, m_HWDATA => m_HWDATA,
            m_HRDATA => m_HRDATA, m_HRESP => m_HRESP, m_HREADYOUT => m_HREADYOUT,
            rv_clk => rv_clk, rv_reset => rv_reset,
            sram_addr => open, sram_data => sram_data, sram_oe_n => open,
            sram_we_n => open, sram_cs_n => open, sram_bls_n => open,
            rp_clk => rp_clk, rp_nRESET => rp_nRESET,
            rp_irq_out => rp_irq_out, global_irq => global_irq
        );

    -- Stimulus process (uses master 0 = Cortex-M4)
    stim : process
        variable read_data : std_logic_vector(31 downto 0);
    begin
        -- Reset
        HRESETn <= '0'; rv_reset <= '1'; rp_nRESET <= '0';
        m_HSEL <= "0000"; m_HWRITE <= "0000"; m_HREADY <= "1111";
        m_HMASTLOCK <= "0000"; m_HTRANS <= (others => '0');
        m_HSIZE <= (others => '0'); m_HPROT <= (others => '0');
        m_HADDR <= (others => '0'); m_HWDATA <= (others => '0');
        wait for CLK_PERIOD * 4;
        HRESETn <= '1'; rv_reset <= '0'; rp_nRESET <= '1';
        wait for CLK_PERIOD * 2;

        -- Test 1: Write to ext_sram CTRL register (0x0000_0000)
        report "Test 1: Writing 0x00000003 to ext_sram CTRL at 0x0000_0000";
        m_HSEL(0) <= '1'; m_HWRITE(0) <= '1'; m_HTRANS(1 downto 0) <= "10";
        m_HSIZE(2 downto 0) <= "010"; m_HPROT(3 downto 0) <= "0011";
        m_HADDR(31 downto 0) <= x"0000_0000";
        m_HWDATA(31 downto 0) <= x"00000003";
        wait until rising_edge(HCLK);
        while m_HREADYOUT(0) /= '1' loop
            wait until rising_edge(HCLK);
        end loop;
        m_HSEL(0) <= '0'; m_HWRITE(0) <= '0'; m_HTRANS(1 downto 0) <= "00";
        wait for CLK_PERIOD * 2;

        -- Test 2: Read back ext_sram CTRL register
        report "Test 2: Reading ext_sram CTRL at 0x0000_0000";
        m_HSEL(0) <= '1'; m_HWRITE(0) <= '0'; m_HTRANS(1 downto 0) <= "10";
        m_HADDR(31 downto 0) <= x"0000_0000";
        wait until rising_edge(HCLK);
        while m_HREADYOUT(0) /= '1' loop
            wait until rising_edge(HCLK);
        end loop;
        read_data := m_HRDATA(31 downto 0);
        m_HSEL(0) <= '0'; m_HTRANS(1 downto 0) <= "00";
        wait for CLK_PERIOD * 2;

        -- Verify read-back
        if read_data = x"00000003" then
            report "PASS: ext_sram CTRL read-back matches (0x" &
                   to_hstring(read_data) & ")" severity note;
        else
            report "FAIL: ext_sram CTRL read-back mismatch, expected 0x00000003, got 0x" &
                   to_hstring(read_data) severity error;
            test_pass <= false;
        end if;

        -- Test 3: Read bootloader STAT register (0x1000_0004)
        report "Test 3: Reading bootloader STAT at 0x1000_0004";
        m_HSEL(0) <= '1'; m_HWRITE(0) <= '0'; m_HTRANS(1 downto 0) <= "10";
        m_HADDR(31 downto 0) <= x"1000_0004";
        wait until rising_edge(HCLK);
        while m_HREADYOUT(0) /= '1' loop
            wait until rising_edge(HCLK);
        end loop;
        read_data := m_HRDATA(31 downto 0);
        m_HSEL(0) <= '0'; m_HTRANS(1 downto 0) <= "00";
        wait for CLK_PERIOD * 2;

        report "PASS: bootloader STAT read = 0x" & to_hstring(read_data) severity note;

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
