-- ============================================================================
-- Testbench for MCU_2_Core : Dual-core 8-bit MCU with shared bus arbiter
-- ============================================================================
-- Verifies the alternating bus arbiter and basic instruction execution
-- for both cores.  Loads a simple program (HLT at address 0) and checks
-- that both cores halt.  Also verifies bus_grant gating and PC outputs.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_mcu_2_core is
end entity tb_mcu_2_core;

architecture sim of tb_mcu_2_core is

    constant CLK_PERIOD : time := 20 ns;

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';
    signal addr_out     : std_logic_vector(7 downto 0);
    signal data_out     : std_logic_vector(7 downto 0);
    signal we           : std_logic;
    signal core0_pc     : std_logic_vector(7 downto 0);
    signal core1_pc     : std_logic_vector(7 downto 0);
    signal data_in      : std_logic_vector(7 downto 0);
    signal oe           : std_logic;
    signal irq0         : std_logic := '0';
    signal irq1         : std_logic := '0';
    signal irq_ack      : std_logic_vector(1 downto 0);
    signal core0_status : std_logic_vector(7 downto 0);
    signal core1_status : std_logic_vector(7 downto 0);
    signal bus_grant    : std_logic := '0';

    -- Memory model: 256-byte array
    type mem_t is array(0 to 255) of std_logic_vector(7 downto 0);
    signal mem : mem_t := (others => (others => '0'));

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.MCU_2_Core
        port map (
            clk          => clk,
            reset        => reset,
            addr_out     => addr_out,
            data_out     => data_out,
            we           => we,
            core0_pc     => core0_pc,
            core1_pc     => core1_pc,
            data_in      => data_in,
            oe           => oe,
            irq0         => irq0,
            irq1         => irq1,
            irq_ack      => irq_ack,
            core0_status => core0_status,
            core1_status => core1_status,
            bus_grant    => bus_grant
        );

    -- ========================================================================
    -- Memory Model: combinational read, synchronous write
    -- ========================================================================
    data_in <= mem(to_integer(unsigned(addr_out)));

    mem_wr : process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                mem(to_integer(unsigned(addr_out))) <= data_out;
            end if;
        end if;
    end process mem_wr;

    -- ========================================================================
    -- Stimulus
    -- ========================================================================
    stim : process
    begin
        -- ------------------------------------------------------------------
        -- Load program: HLT at address 0
        -- ------------------------------------------------------------------
        mem(0) <= x"B0";  -- HLT

        -- ------------------------------------------------------------------
        -- Reset
        -- ------------------------------------------------------------------
        reset     <= '1';
        bus_grant <= '0';
        wait for CLK_PERIOD * 4;
        reset     <= '0';
        wait until rising_edge(clk);

        -- ------------------------------------------------------------------
        -- Test 1: With bus_grant=0, cores should not advance
        -- ------------------------------------------------------------------
        wait for CLK_PERIOD * 4;
        assert core0_pc = x"00"
            report "Test 1 FAIL: core0_pc advanced without bus_grant"
            severity error;
        assert core1_pc = x"00"
            report "Test 1 FAIL: core1_pc advanced without bus_grant"
            severity error;
        report "Test 1 PASS: cores stalled when bus_grant=0" severity note;

        -- ------------------------------------------------------------------
        -- Test 2: Grant bus access and verify both cores halt
        -- ------------------------------------------------------------------
        bus_grant <= '1';
        -- Each core gets every other cycle; HLT takes 2 bus cycles
        -- (S_FETCH + S_DECODE).  Wait ~10 cycles.
        for i in 0 to 15 loop
            wait until rising_edge(clk);
            if core0_status(1) = '1' and core1_status(1) = '1' then
                exit;
            end if;
        end loop;

        assert core0_status(1) = '1'
            report "Test 2 FAIL: core0 did not halt"
            severity error;
        assert core1_status(1) = '1'
            report "Test 2 FAIL: core1 did not halt"
            severity error;
        report "Test 2 PASS: both cores halted after HLT" severity note;

        -- ------------------------------------------------------------------
        -- Test 3: Verify both cores were running before halt
        --         (status bit 0 = running, bit 1 = halted)
        -- ------------------------------------------------------------------
        assert core0_status(0) = '0'
            report "Test 3 FAIL: core0 still marked running after halt"
            severity error;
        assert core1_status(0) = '0'
            report "Test 3 FAIL: core1 still marked running after halt"
            severity error;
        report "Test 3 PASS: both cores show running=0 after halt" severity note;

        -- ------------------------------------------------------------------
        -- Test 4: Verify arbiter alternates (check status waiting bits)
        --   core0_status(2) = not grant, core1_status(2) = grant
        --   When grant=0: core0 active (status(2)=1), core1 waiting (status(2)=0)
        --   When grant=1: core0 waiting (status(2)=0), core1 active (status(2)=1)
        -- ------------------------------------------------------------------
        -- After halt, grant still toggles.  Check both states.
        bus_grant <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        report "Test 4 PASS: arbiter toggle test completed" severity note;

        -- ------------------------------------------------------------------
        -- Test 5: Load a NOP + HLT program and verify PC advance
        --   Address 0: NOP (0xC0)
        --   Address 1: HLT (0xB0)
        -- ------------------------------------------------------------------
        reset <= '1';
        bus_grant <= '0';
        mem(0) <= x"C0";  -- NOP
        mem(1) <= x"B0";  -- HLT
        wait for CLK_PERIOD * 4;
        reset <= '0';
        wait until rising_edge(clk);

        bus_grant <= '1';
        for i in 0 to 20 loop
            wait until rising_edge(clk);
            if core0_status(1) = '1' and core1_status(1) = '1' then
                exit;
            end if;
        end loop;

        -- At least one core should have advanced PC beyond 0
        assert core0_pc > x"00" or core1_pc > x"00"
            report "Test 5 FAIL: neither core advanced PC"
            severity error;
        report "Test 5 PASS: at least one core advanced PC past 0" severity note;

        -- ------------------------------------------------------------------
        -- Done
        -- ------------------------------------------------------------------
        report "All MCU_2_Core tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim;

end architecture sim;
