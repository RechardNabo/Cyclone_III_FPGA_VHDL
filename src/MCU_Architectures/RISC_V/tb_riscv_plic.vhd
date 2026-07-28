-- ================================================================================
-- tb_riscv_plic : Testbench for RISC-V Platform-Level Interrupt Controller
-- ================================================================================
-- Tests PLIC priority, enable, threshold, and claim/complete operations.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_riscv_plic is
end entity tb_riscv_plic;

architecture sim of tb_riscv_plic is
    signal HCLK      : std_logic := '0';
    signal HRESETn   : std_logic := '0';
    signal HSEL      : std_logic := '0';
    signal HWRITE    : std_logic := '0';
    signal HREADY    : std_logic := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;
    signal ext_irq_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal ext_irq_out : std_logic;
    signal ext_irq_id  : std_logic_vector(5 downto 0);

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.riscv_plic
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            ext_irq_in => ext_irq_in, ext_irq_out => ext_irq_out,
            ext_irq_id => ext_irq_id
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
            wait for 1 ns;
            HSEL <= '0'; HTRANS <= "00";
        end procedure;

        variable test_pass : boolean := true;
    begin
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait until rising_edge(HCLK);

        -- Test 1: Write priority for source 1
        report "Test 1: PRIORITY[1] write/read";
        ahb_write(x"00000004", x"00000003");  -- priority=3
        ahb_read(x"00000004");
        if HRDATA(2 downto 0) = "011" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Write ENABLE register (enable source 1)
        report "Test 2: ENABLE write/read";
        ahb_write(x"00002000", x"00000002");  -- enable source 1
        ahb_read(x"00002000");
        if HRDATA(1) = '1' then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Write THRESHOLD
        report "Test 3: THRESHOLD write/read";
        ahb_write(x"00003000", x"00000001");  -- threshold=1
        ahb_read(x"00003000");
        if HRDATA(2 downto 0) = "001" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Assert external IRQ source 1, check ext_irq_out
        report "Test 4: External IRQ routing";
        ext_irq_in <= (1 => '1', others => '0');
        wait for CLK_PERIOD * 3;
        if ext_irq_out = '1' then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Read CLAIM to get interrupt ID
        report "Test 5: CLAIM read";
        ahb_read(x"00003004");
        if HRDATA(5 downto 0) = "000001" then  -- source 1
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL RISCV_PLIC TESTS PASSED ===" severity note;
        else
            report "=== RISCV_PLIC TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;
