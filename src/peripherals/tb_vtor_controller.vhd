-- ================================================================================
-- tb_vtor_controller : Testbench for Vector Table Remap Controller
-- ================================================================================
-- Verifies vector table remap via AHB-Lite interface.
--
-- Tests:
--   1. Enable VTOR and set vector table base address
--   2. Verify base address readback (512-byte aligned)
--   3. Lock VTOR address and verify write is blocked
--   4. Verify vector_addr output for given irq_num
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_vtor_controller is
end entity tb_vtor_controller;

architecture sim of tb_vtor_controller is
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

    signal irq_num     : std_logic_vector(5 downto 0) := (others => '0');
    signal vector_addr : std_logic_vector(31 downto 0);

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.vtor_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            irq_num => irq_num, vector_addr => vector_addr
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

        -- Test 1: Enable VTOR and set base address
        report "Test 1: Enable VTOR and set base address";
        ahb_write(x"00000000", x"00000001");  -- CTRL: enable=1
        ahb_write(x"00000004", x"00008000");  -- VTOR_ADDR = 0x8000
        ahb_read(x"00000004", rdata);
        assert rdata = x"00008000"
            report "Test 1 FAILED: VTOR_ADDR mismatch" severity error;
        if rdata = x"00008000" then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 2: Verify 512-byte alignment
        report "Test 2: Verify 512-byte alignment";
        ahb_write(x"00000004", x"00008001");  -- unaligned
        ahb_read(x"00000004", rdata);
        assert rdata(8 downto 0) = "000000000"
            report "Test 2 FAILED: not aligned" severity error;
        if rdata(8 downto 0) = "000000000" then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 3: Lock VTOR address
        report "Test 3: Lock VTOR address";
        ahb_write(x"00000000", x"00000003");  -- CTRL: enable=1, lock_en=1
        ahb_write(x"00000008", x"0000564C");  -- VTOR_LOCK: magic
        ahb_read(x"00000000", rdata);
        assert rdata(2) = '1'
            report "Test 3 FAILED: lock not set" severity error;
        if rdata(2) = '1' then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 4: Verify locked address cannot change
        report "Test 4: Verify locked address blocked";
        ahb_write(x"00000004", x"00010000");  -- try to change
        ahb_read(x"00000004", rdata);
        assert rdata = x"00008000"
            report "Test 4 FAILED: address changed while locked" severity error;
        if rdata = x"00008000" then
            report "Test 4 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 5: Verify vector_addr output
        report "Test 5: Verify vector_addr output";
        irq_num <= "000001";  -- IRQ 1
        wait until rising_edge(HCLK);
        assert vector_addr = x"00008004"
            report "Test 5 FAILED: vector_addr wrong" severity error;
        if vector_addr = x"00008004" then
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
