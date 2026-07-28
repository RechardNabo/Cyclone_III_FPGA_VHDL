-- ================================================================================
-- tb_riscv_csr : Testbench for RISC-V Control & Status Registers
-- ================================================================================
-- Tests CSR read/write for MSTATUS, MTVEC, MIE, MSCRATCH registers.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_riscv_csr is
end entity tb_riscv_csr;

architecture sim of tb_riscv_csr is
    signal HCLK        : std_logic := '0';
    signal HRESETn     : std_logic := '0';
    signal HSEL        : std_logic := '0';
    signal HWRITE      : std_logic := '0';
    signal HREADY      : std_logic := '1';
    signal HTRANS      : std_logic_vector(1 downto 0) := "00";
    signal HSIZE       : std_logic_vector(2 downto 0) := "010";
    signal HADDR       : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA      : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA      : std_logic_vector(31 downto 0);
    signal HRESP       : std_logic;
    signal HREADYOUT   : std_logic;
    signal hart_id     : std_logic_vector(3 downto 0) := x"3";
    signal exception_in: std_logic := '0';
    signal cause_in    : std_logic_vector(4 downto 0) := (others => '0');
    signal epc_in      : std_logic_vector(31 downto 0) := (others => '0');
    signal irq_timer   : std_logic := '0';
    signal irq_software: std_logic := '0';
    signal irq_external: std_logic := '0';

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.riscv_csr
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            hart_id => hart_id, exception_in => exception_in,
            cause_in => cause_in, epc_in => epc_in,
            irq_timer => irq_timer, irq_software => irq_software,
            irq_external => irq_external
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

        -- Test 1: Write and read MSTATUS
        report "Test 1: MSTATUS write/read";
        ahb_write(x"00000000", x"00001888");  -- MIE=1, MPIE=1
        ahb_read(x"00000000");
        if HRDATA = x"00001888" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Write and read MTVEC
        report "Test 2: MTVEC write/read";
        ahb_write(x"00000020", x"00000100");  -- vector base=0x100, direct mode
        ahb_read(x"00000020");
        if HRDATA = x"00000100" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Write and read MIE
        report "Test 3: MIE write/read";
        ahb_write(x"00000070", x"00000888");  -- MSIE, MTIE, MEIE
        ahb_read(x"00000070");
        if HRDATA = x"00000888" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Write and read MSCRATCH
        report "Test 4: MSCRATCH write/read";
        ahb_write(x"000000C0", x"DEADBEEF");
        ahb_read(x"000000C0");
        if HRDATA = x"DEADBEEF" then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Read MISA (default RV32IMAC)
        report "Test 5: MISA default read";
        ahb_read(x"00000004");
        if HRDATA = x"40001100" then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL RISCV_CSR TESTS PASSED ===" severity note;
        else
            report "=== RISCV_CSR TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;
