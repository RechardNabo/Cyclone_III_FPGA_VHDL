-- ================================================================================
-- tb_riscv_clint : Testbench for RISC-V Core Local Interruptor
-- ================================================================================
-- Tests CLINT register read/write and timer interrupt behavior.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_riscv_clint is
end entity tb_riscv_clint;

architecture sim of tb_riscv_clint is
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
    signal timer_irq : std_logic;
    signal sw_irq    : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.riscv_clint
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            timer_irq => timer_irq, sw_irq => sw_irq
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

        -- Test 1: Write and read MSIP (software interrupt)
        report "Test 1: MSIP write/read";
        ahb_write(x"00000000", x"00000001");  -- set MSIP bit0
        ahb_read(x"00000000");
        if HRDATA = x"00000001" then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: Verify sw_irq asserted
        report "Test 2: sw_irq assertion";
        if sw_irq = '1' then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: Write MTIMECMP to small value to trigger timer IRQ
        report "Test 3: MTIMECMP write";
        ahb_write(x"00000010", x"00000010");  -- mtimecmp_lo = 16
        ahb_write(x"00000014", x"00000000");  -- mtimecmp_hi = 0
        ahb_read(x"00000010");
        if HRDATA = x"00000010" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Wait for mtime to exceed mtimecmp, check timer_irq
        report "Test 4: timer_irq assertion";
        wait for CLK_PERIOD * 20;  -- let mtime increment past 16
        if timer_irq = '1' then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Read MTIME (should be non-zero and incrementing)
        report "Test 5: MTIME read";
        ahb_read(x"00000020");
        if HRDATA /= x"00000000" then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL RISCV_CLINT TESTS PASSED ===" severity note;
        else
            report "=== RISCV_CLINT TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;
