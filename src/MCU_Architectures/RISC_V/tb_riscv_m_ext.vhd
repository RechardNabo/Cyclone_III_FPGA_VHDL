-- ================================================================================
-- tb_riscv_m_ext : Testbench for RISC-V M Extension (Multiply/Divide)
-- ================================================================================
-- Tests MUL and DIV operations via AHB-Lite register interface.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_riscv_m_ext is
end entity tb_riscv_m_ext;

architecture sim of tb_riscv_m_ext is
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
    signal mul_irq   : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.riscv_m_ext
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            mul_irq => mul_irq
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

        -- Test 1: MUL operation (6 * 7 = 42)
        report "Test 1: MUL 6*7=42";
        ahb_write(x"00000004", x"00000006");  -- OP_A = 6
        ahb_write(x"00000008", x"00000007");  -- OP_B = 7
        ahb_write(x"00000000", x"00000000");  -- CTRL = MUL (000)
        ahb_read(x"0000000C");  -- RESULT_LO
        if HRDATA = std_logic_vector(to_unsigned(42, 32)) then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: MULH operation (signed high bits of -1 * -1 = 0)
        report "Test 2: MULH (-1)*(-1)";
        ahb_write(x"00000004", x"FFFFFFFF");  -- OP_A = -1
        ahb_write(x"00000008", x"FFFFFFFF");  -- OP_B = -1
        ahb_write(x"00000000", x"00000001");  -- CTRL = MULH (001)
        ahb_read(x"00000010");  -- RESULT_HI
        if HRDATA = x"00000000" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: DIV operation (100 / 7 = 14)
        report "Test 3: DIV 100/7=14";
        ahb_write(x"00000004", x"00000064");  -- OP_A = 100
        ahb_write(x"00000008", x"00000007");  -- OP_B = 7
        ahb_write(x"00000000", x"00000004");  -- CTRL = DIV (100)
        ahb_read(x"0000000C");  -- RESULT_LO
        if HRDATA = std_logic_vector(to_unsigned(14, 32)) then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: REM operation (100 % 7 = 2)
        report "Test 4: REM 100%7=2";
        ahb_write(x"00000000", x"00000006");  -- CTRL = REM (110)
        ahb_read(x"0000000C");  -- RESULT_LO
        if HRDATA = std_logic_vector(to_unsigned(2, 32)) then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: DIV by zero (should return 0xFFFFFFFF)
        report "Test 5: DIV by zero";
        ahb_write(x"00000004", x"00000064");  -- OP_A = 100
        ahb_write(x"00000008", x"00000000");  -- OP_B = 0
        ahb_write(x"00000000", x"00000100");  -- CTRL = DIVU (101)
        ahb_read(x"0000000C");  -- RESULT_LO
        ahb_read(x"00000014");  -- STAT
        if HRDATA(1) = '1' then  -- div_by_zero flag
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL RISCV_M_EXT TESTS PASSED ===" severity note;
        else
            report "=== RISCV_M_EXT TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;
