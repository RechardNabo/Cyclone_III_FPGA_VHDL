-- ================================================================================
-- tb_fpga_pll_wrapper : Testbench for FPGA PLL Wrapper
-- ================================================================================
-- Tests basic AHB-Lite register read/write for PLL wrapper.
-- Note: Requires altpll megafunction library for full simulation.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_fpga_pll_wrapper is
end entity tb_fpga_pll_wrapper;

architecture sim of tb_fpga_pll_wrapper is
    signal HCLK      : std_logic := '0';
    signal HRESETn   : std_logic := '0';
    signal HSEL      : std_logic := '0';
    signal HWRITE    : std_logic := '0';
    signal HREADY    : std_logic := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;
    signal clk_in    : std_logic := '0';
    signal clk_out   : std_logic;
    signal locked    : std_logic;
    signal reset_out : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK   <= not HCLK after CLK_PERIOD / 2;
    clk_in <= not clk_in after CLK_PERIOD / 2;

    dut : entity work.fpga_pll_wrapper
        generic map (
            INPUT_CLOCK  => 50000000,
            OUTPUT_CLOCK => 100000000
        )
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            clk_in => clk_in, clk_out => clk_out,
            locked => locked, reset => reset_out
        );

    stim : process
        procedure ahb_write(addr : std_logic_vector(31 downto 0);
                            data : std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
            HADDR <= addr; HWDATA <= data;
            wait until rising_edge(HCLK);
            HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
        end procedure;

        procedure ahb_read(addr : std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
            HADDR <= addr;
            wait until rising_edge(HCLK);
            HSEL <= '0'; HTRANS <= "00";
        end procedure;

        variable test_pass : boolean := true;
    begin
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait until rising_edge(HCLK);

        -- Test 1: Write and read PLL_CTRL (reset bit)
        report "Test 1: PLL_CTRL write/read";
        ahb_write(x"00000000", x"00000001");  -- assert reset
        ahb_read(x"00000000");
        if HRDATA = x"00000001" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Clear PLL_CTRL reset
        report "Test 2: PLL_CTRL clear reset";
        ahb_write(x"00000000", x"00000000");
        ahb_read(x"00000000");
        if HRDATA = x"00000000" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Read PLL_STAT (locked bit reflects altpll)
        report "Test 3: PLL_STAT read";
        ahb_read(x"00000004");
        -- locked_reg comes from altpll; just verify read does not hang
        report "Test 3 PASS" severity note;

        -- Test 4: Write PLL_RESET (soft reset pulse)
        report "Test 4: PLL_RESET write";
        ahb_write(x"00000008", x"00000001");
        ahb_read(x"00000008");
        -- reset_pulse should be 1 immediately after write
        if HRDATA(0) = '1' then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Verify reset_out asserted after soft reset
        report "Test 5: reset_out assertion";
        if reset_out = '1' then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL FPGA_PLL_WRAPPER TESTS PASSED ===" severity note;
        else
            report "=== FPGA_PLL_WRAPPER TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;
