-- ================================================================================
-- tb_riscv_pmp : Testbench for RISC-V Physical Memory Protection
-- ================================================================================
-- Tests PMP region configuration and fault detection.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_riscv_pmp is
end entity tb_riscv_pmp;

architecture sim of tb_riscv_pmp is
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
    signal vaddr       : std_logic_vector(31 downto 0) := x"00000000";
    signal access_type : std_logic_vector(1 downto 0) := "00";
    signal pmp_fault   : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.riscv_pmp
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            vaddr => vaddr, access_type => access_type,
            pmp_fault => pmp_fault
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

        -- Test 1: Write PMPCFG0 (configure region 0: L=1, A=TOR, R=1, W=1, X=0)
        report "Test 1: PMPCFG0 write/read";
        ahb_write(x"00000000", x"0000001B");  -- L=0,A=01(TOR),X=0,W=1,R=1 -> 0x1B
        ahb_read(x"00000000");
        if HRDATA(7 downto 0) = x"1B" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Write PMPADDR0 (region 0 end address)
        report "Test 2: PMPADDR0 write/read";
        ahb_write(x"00000080", x"00001000");  -- end = 0x4000 (addr << 2)
        ahb_read(x"00000080");
        if HRDATA = x"00001000" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Check no fault for read within region
        -- Need L=1 for PMP to be active. Let me set L=1.
        report "Test 3: Set L bit and check fault";
        ahb_write(x"00000000", x"0000009B");  -- L=1, A=01(TOR), W=1, R=1
        vaddr <= x"00002000";  -- within region [0, 0x4000)
        access_type <= "00";  -- read
        wait for CLK_PERIOD * 2;
        if pmp_fault = '0' then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Check fault for write when W not set
        report "Test 4: Write fault on read-only region";
        ahb_write(x"00000000", x"0000008F");  -- L=1, A=01(TOR), X=1, W=0, R=1
        vaddr <= x"00002000";
        access_type <= "01";  -- write
        wait for CLK_PERIOD * 2;
        if pmp_fault = '1' then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Check fault for access outside all regions
        report "Test 5: Fault for unmapped access";
        vaddr <= x"80000000";  -- outside any region
        access_type <= "00";  -- read
        wait for CLK_PERIOD * 2;
        if pmp_fault = '1' then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL RISCV_PMP TESTS PASSED ===" severity note;
        else
            report "=== RISCV_PMP TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;
