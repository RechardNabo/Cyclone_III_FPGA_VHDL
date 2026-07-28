-- ================================================================================
-- tb_mpu_controller : Testbench for MPU Controller
-- ================================================================================
-- Verifies MPU region configuration and fault detection via AHB-Lite interface.
--
-- Tests:
--   1. Enable MPU and configure region 0
--   2. Verify region base address and size register readback
--   3. Trigger fault by accessing protected region with wrong privileges
--   4. Verify fault output assertion
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_mpu_controller is
end entity tb_mpu_controller;

architecture sim of tb_mpu_controller is
    signal HCLK    : std_logic := '0';
    signal HRESETn : std_logic := '0';

    signal HSEL      : std_logic                    := '0';
    signal HWRITE    : std_logic                    := '0';
    signal HREADY    : std_logic                    := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;

    signal cpu_addr     : std_logic_vector(31 downto 0) := (others => '0');
    signal cpu_priv     : std_logic := '0';
    signal cpu_write    : std_logic := '0';
    signal region_fault : std_logic;
    signal mpu_irq      : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.mpu_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HADDR => HADDR,
            HWDATA => HWDATA, HRDATA => HRDATA, HRESP => HRESP,
            HREADYOUT => HREADYOUT, cpu_addr => cpu_addr, cpu_priv => cpu_priv,
            cpu_write => cpu_write, region_fault => region_fault, mpu_irq => mpu_irq
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

        -- Test 1: Configure region 0
        report "Test 1: Configure MPU region 0";
        ahb_write(x"00000004", x"00000000");  -- RNR: region 0
        ahb_write(x"00000008", x"20000000");  -- RBAR: base = 0x20000000
        -- RASR: size=10 (1KB), enable=1, perm=011 (priv RO)
        ahb_write(x"0000000C", x"60000015");
        ahb_read(x"00000008", rdata);
        assert rdata = x"20000000"
            report "Test 1 FAILED: RBAR mismatch" severity error;
        if rdata = x"20000000" then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 2: Enable MPU
        report "Test 2: Enable MPU";
        ahb_write(x"00000000", x"00000001");  -- CTRL: enable=1
        ahb_read(x"00000000", rdata);
        assert rdata(0) = '1'
            report "Test 2 FAILED: MPU not enabled" severity error;
        if rdata(0) = '1' then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 3: Trigger fault (unprivileged write to RO region)
        report "Test 3: Trigger region fault";
        cpu_addr <= x"20000000";
        cpu_priv <= '0';  -- unprivileged
        cpu_write <= '1';  -- write access
        wait until rising_edge(HCLK);
        wait until rising_edge(HCLK);
        assert region_fault = '1'
            report "Test 3 FAILED: fault not detected" severity error;
        if region_fault = '1' then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 4: No fault for privileged read
        report "Test 4: Privileged read no fault";
        cpu_priv <= '1';
        cpu_write <= '0';
        wait until rising_edge(HCLK);
        wait until rising_edge(HCLK);
        assert region_fault = '0'
            report "Test 4 FAILED: false fault" severity error;
        if region_fault = '0' then
            report "Test 4 PASSED" severity note;
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
