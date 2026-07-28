-- ================================================================================
-- tb_fpga_dsp_block : Testbench for FPGA DSP Multiply-Accumulate Block
-- ================================================================================
-- Tests basic AHB-Lite register read/write and MAC operation.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_fpga_dsp_block is
end entity tb_fpga_dsp_block;

architecture sim of tb_fpga_dsp_block is
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
    signal dsp_irq   : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.fpga_dsp_block
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            dsp_irq => dsp_irq
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

        -- Test 1: Write OP_A and read back
        report "Test 1: OP_A write/read";
        ahb_write(x"00000000", x"00000005");  -- 5
        ahb_read(x"00000000");
        if HRDATA = x"00000005" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Write OP_B and read back
        report "Test 2: OP_B write/read";
        ahb_write(x"00000004", x"00000007");  -- 7
        ahb_read(x"00000004");
        if HRDATA = x"00000007" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Start multiply-only (CTRL bit0=1)
        report "Test 3: Multiply 5*7=35";
        ahb_write(x"00000014", x"00000001");  -- start, no accumulate
        ahb_read(x"0000000C");  -- ACC_LO
        if HRDATA = std_logic_vector(to_unsigned(35, 32)) then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Accumulate mode (CTRL bit0=1, bit1=1)
        report "Test 4: Accumulate 35 + 5*7=70";
        ahb_write(x"00000014", x"00000003");  -- start + accumulate
        ahb_read(x"0000000C");  -- ACC_LO
        if HRDATA = std_logic_vector(to_unsigned(70, 32)) then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Clear accumulator (CTRL bit2=1)
        report "Test 5: Clear accumulator";
        ahb_write(x"00000014", x"00000004");  -- clear
        ahb_read(x"0000000C");  -- ACC_LO
        if HRDATA = x"00000000" then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL FPGA_DSP_BLOCK TESTS PASSED ===" severity note;
        else
            report "=== FPGA_DSP_BLOCK TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;
