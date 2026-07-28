-- ================================================================================
-- tb_mmu_controller : Testbench for MMU Controller
-- ================================================================================
-- Verifies TLB translation and fault detection via AHB-Lite interface.
--
-- Tests:
--   1. Enable MMU and configure TLB entry
--   2. Verify TLB entry readback
--   3. Test translation hit (vaddr matches TLB entry)
--   4. Test translation miss (fault on unmapped address)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_mmu_controller is
end entity tb_mmu_controller;

architecture sim of tb_mmu_controller is
    signal HCLK    : std_logic := '0';
    signal HRESETn : std_logic := '0';

    signal HSEL      : std_logic                    := '0';
    signal HWRITE    : std_logic                    := '0';
    signal HREADY    : std_logic                    := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;

    signal vaddr   : std_logic_vector(31 downto 0) := (others => '0');
    signal paddr   : std_logic_vector(31 downto 0);
    signal fault   : std_logic;
    signal mmu_irq : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.mmu_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            vaddr => vaddr, paddr => paddr, fault => fault, mmu_irq => mmu_irq
        );

    stim : process
        procedure ahb_write(addr : in std_logic_vector(31 downto 0);
                            data : in std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
            HADDR <= addr; HWDATA <= data;
            wait until rising_edge(HCLK);
            HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
        end procedure;

        procedure ahb_read(addr : in std_logic_vector(31 downto 0);
                           data : out std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
            HADDR <= addr;
            wait until rising_edge(HCLK);
            data := HRDATA;
            HSEL <= '0'; HTRANS <= "00";
        end procedure;

        variable rdata     : std_logic_vector(31 downto 0);
        variable test_pass : boolean := true;
    begin
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait until rising_edge(HCLK);

        -- Test 1: Configure TLB entry 0
        report "Test 1: Configure TLB entry";
        ahb_write(x"00000008", x"00000000");  -- TLB_INDEX = 0
        -- TLB_ENTRY: VPN[31:20]=0x001, PFN[19:8]=0x002, flags=0x7
        ahb_write(x"00000004", x"00100207");
        ahb_read(x"00000004", rdata);  -- Read back TLB_ENTRY
        assert rdata(31 downto 20) = x"001"
            report "Test 1 FAILED: VPN mismatch" severity error;
        if rdata(31 downto 20) = x"001" then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 2: Enable MMU
        report "Test 2: Enable MMU";
        ahb_write(x"00000000", x"00000001");  -- CTRL: enable=1
        ahb_read(x"00000000", rdata);
        assert rdata(0) = '1'
            report "Test 2 FAILED: MMU not enabled" severity error;
        if rdata(0) = '1' then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 3: Translation hit (vaddr VPN=0x001)
        report "Test 3: TLB translation hit";
        vaddr <= x"00100000";  -- VPN = 0x001
        wait for 20 ns;
        assert fault = '0'
            report "Test 3 FAILED: fault on hit" severity error;
        assert paddr(31 downto 20) = x"002"
            report "Test 3 FAILED: paddr PFN mismatch" severity error;
        if fault = '0' and paddr(31 downto 20) = x"002" then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 4: Translation miss (unmapped VPN)
        report "Test 4: TLB translation miss";
        vaddr <= x"FFF00000";  -- VPN = 0xFFF (not in TLB)
        wait for 20 ns;
        assert fault = '1'
            report "Test 4 FAILED: no fault on miss" severity error;
        if fault = '1' then
            report "Test 4 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 5: Verify fault address latched
        report "Test 5: Verify fault address";
        wait until rising_edge(HCLK);
        ahb_read(x"0000000C", rdata);  -- FAULT_ADDR
        assert rdata = x"FFF00000"
            report "Test 5 FAILED: fault addr mismatch" severity error;
        if rdata = x"FFF00000" then
            report "Test 5 PASSED" severity note;
        else
            test_pass := false;
        end if;

        if test_pass then
            report "PASS" severity note;
        else
            report "FAIL" severity error;
        end if;
        finish;
    end process;
end architecture sim;
