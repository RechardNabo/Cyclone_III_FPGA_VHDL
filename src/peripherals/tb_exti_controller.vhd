-- ================================================================================
-- tb_exti_controller : Testbench for External Interrupt Controller
-- ================================================================================
-- Verifies external interrupt triggering via AHB-Lite interface.
--
-- Tests:
--   1. Configure interrupt mask and rising trigger
--   2. Trigger interrupt via external line edge
--   3. Verify pending register is set
--   4. Clear pending and verify
--   5. Software-triggered interrupt
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_exti_controller is
end entity tb_exti_controller;

architecture sim of tb_exti_controller is
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

    signal exti_lines : std_logic_vector(31 downto 0) := (others => '0');
    signal exti_irq   : std_logic_vector(31 downto 0);

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.exti_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            exti_lines => exti_lines, exti_irq => exti_irq
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

        -- Test 1: Configure mask and rising trigger for line 0
        report "Test 1: Configure EXTI line 0";
        ahb_write(x"00000000", x"00000001");  -- IMR: enable line 0
        ahb_write(x"00000008", x"00000001");  -- RTSR: rising trigger line 0
        ahb_read(x"00000000", rdata);
        assert rdata(0) = '1'
            report "Test 1 FAILED: IMR not set" severity error;
        if rdata(0) = '1' then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 2: Trigger rising edge on line 0
        report "Test 2: Trigger rising edge";
        exti_lines(0) <= '1';
        wait until rising_edge(HCLK);
        wait until rising_edge(HCLK);
        ahb_read(x"00000010", rdata);  -- PR
        assert rdata(0) = '1'
            report "Test 2 FAILED: pending not set" severity error;
        if rdata(0) = '1' then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 3: Clear pending
        report "Test 3: Clear pending register";
        ahb_write(x"00000010", x"00000001");  -- Clear line 0
        ahb_read(x"00000010", rdata);
        assert rdata(0) = '0'
            report "Test 3 FAILED: pending not cleared" severity error;
        if rdata(0) = '0' then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 4: Software interrupt
        report "Test 4: Software-triggered interrupt";
        ahb_write(x"00000014", x"00000001");  -- SWIER: trigger line 0
        wait until rising_edge(HCLK);
        ahb_read(x"00000010", rdata);  -- PR
        assert rdata(0) = '1'
            report "Test 4 FAILED: SWI pending not set" severity error;
        if rdata(0) = '1' then
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
