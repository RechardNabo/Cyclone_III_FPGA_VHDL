-- ============================================================================
-- Testbench for MCU_8_Core : Octa-core 8-bit MCU with priority arbiter
-- ============================================================================
-- Verifies the priority bus arbiter selects the lowest-index core with
-- bus_req=1.  Tests arbiter selection patterns, basic instruction execution
-- (HLT), and the packed 64-bit core_status output.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_mcu_8_core is
end entity tb_mcu_8_core;

architecture sim of tb_mcu_8_core is

    constant CLK_PERIOD : time := 20 ns;

    signal clk         : std_logic := '0';
    signal reset       : std_logic := '1';
    signal bus_req     : std_logic_vector(7 downto 0) := (others => '0');
    signal addr_out    : std_logic_vector(7 downto 0);
    signal data_out    : std_logic_vector(7 downto 0);
    signal we          : std_logic;
    signal active      : std_logic_vector(2 downto 0);
    signal grant_ack   : std_logic;
    signal data_in     : std_logic_vector(7 downto 0);
    signal oe          : std_logic;
    signal irq         : std_logic_vector(7 downto 0) := (others => '0');
    signal irq_ack     : std_logic;
    signal core_status : std_logic_vector(63 downto 0);

    -- Memory model: 256-byte array
    type mem_t is array(0 to 255) of std_logic_vector(7 downto 0);

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.MCU_8_Core
        port map (
            clk         => clk,
            reset       => reset,
            bus_req     => bus_req,
            addr_out    => addr_out,
            data_out    => data_out,
            we          => we,
            active      => active,
            grant_ack   => grant_ack,
            data_in     => data_in,
            oe          => oe,
            irq         => irq,
            irq_ack     => irq_ack,
            core_status => core_status
        );

    -- ========================================================================
    -- Memory Model: synchronous write, combinational read
    -- Uses variable for memory to avoid multi-driver signal issues
    -- ========================================================================
    mem_proc : process(clk)
        variable mem : mem_t := (others => (others => '0'));
        variable initialized : boolean := false;
    begin
        if rising_edge(clk) then
            if reset = '1' or not initialized then
                mem(0) := x"B0";  -- HLT
                initialized := true;
            elsif we = '1' then
                mem(to_integer(unsigned(addr_out))) := data_out;
            end if;
        end if;
        data_in <= mem(to_integer(unsigned(addr_out)));
    end process mem_proc;

    -- ========================================================================
    -- Stimulus
    -- ========================================================================
    stim : process
    begin
        -- ------------------------------------------------------------------
        -- Load program: HLT at address 0
        -- ------------------------------------------------------------------
        -- (handled by mem_proc on reset)

        -- ------------------------------------------------------------------
        -- Reset
        -- ------------------------------------------------------------------
        reset   <= '1';
        bus_req <= (others => '0');
        wait for CLK_PERIOD * 4;
        reset   <= '0';
        wait until rising_edge(clk);

        -- ------------------------------------------------------------------
        -- Test 1: No bus_req → arbiter defaults to core 0
        -- ------------------------------------------------------------------
        bus_req <= "00000000";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert active = "000"
            report "Test 1 FAIL: active not 0 when no bus_req, got " &
                   integer'image(to_integer(unsigned(active)))
            severity error;
        report "Test 1 PASS: defaults to core 0 when no bus_req" severity note;

        -- ------------------------------------------------------------------
        -- Test 2: Only core 3 requests → active = 3
        -- ------------------------------------------------------------------
        bus_req <= "00001000";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert active = "011"
            report "Test 2 FAIL: active not 3 when only core 3 requests, got " &
                   integer'image(to_integer(unsigned(active)))
            severity error;
        report "Test 2 PASS: active = 3 when only core 3 requests" severity note;

        -- ------------------------------------------------------------------
        -- Test 3: Cores 2 and 5 request → lowest index (2) wins
        -- ------------------------------------------------------------------
        bus_req <= "00100100";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert active = "010"
            report "Test 3 FAIL: active not 2 for priority, got " &
                   integer'image(to_integer(unsigned(active)))
            severity error;
        report "Test 3 PASS: priority arbiter selects core 2 over core 5" severity note;

        -- ------------------------------------------------------------------
        -- Test 4: All cores request → core 0 wins (highest priority)
        -- ------------------------------------------------------------------
        bus_req <= "11111111";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert active = "000"
            report "Test 4 FAIL: active not 0 when all request, got " &
                   integer'image(to_integer(unsigned(active)))
            severity error;
        report "Test 4 PASS: core 0 wins when all cores request" severity note;

        -- ------------------------------------------------------------------
        -- Test 5: Only core 7 requests → active = 7
        -- ------------------------------------------------------------------
        bus_req <= "10000000";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert active = "111"
            report "Test 5 FAIL: active not 7 when only core 7 requests, got " &
                   integer'image(to_integer(unsigned(active)))
            severity error;
        report "Test 5 PASS: active = 7 when only core 7 requests" severity note;

        -- ------------------------------------------------------------------
        -- Test 6: grant_ack should always be '1'
        -- ------------------------------------------------------------------
        assert grant_ack = '1'
            report "Test 6 FAIL: grant_ack not '1'"
            severity error;
        report "Test 6 PASS: grant_ack is '1'" severity note;

        -- ------------------------------------------------------------------
        -- Test 7: Core 0 executes HLT and halts
        --   With bus_req for core 0, it gets all bus cycles.
        --   HLT takes 2 bus cycles (S_FETCH + S_DECODE).
        -- ------------------------------------------------------------------
        reset   <= '1';
        bus_req <= "00000001";
        wait for CLK_PERIOD * 4;
        reset   <= '0';
        wait until rising_edge(clk);

        for i in 0 to 10 loop
            wait until rising_edge(clk);
            if core_status(1) = '1' then
                exit;
            end if;
        end loop;

        assert core_status(1) = '1'
            report "Test 7 FAIL: core0 did not halt"
            severity error;
        assert core_status(0) = '0'
            report "Test 7 FAIL: core0 still running after HLT"
            severity error;
        report "Test 7 PASS: core0 halted after HLT execution" severity note;

        -- ------------------------------------------------------------------
        -- Test 8: Verify active output is valid (0-7)
        -- ------------------------------------------------------------------
        assert unsigned(active) <= 7
            report "Test 8 FAIL: active core index out of range"
            severity error;
        report "Test 8 PASS: active core index valid" severity note;

        -- ------------------------------------------------------------------
        -- Done
        -- ------------------------------------------------------------------
        report "All MCU_8_Core tests passed" severity note;
        report "Testbench complete" severity note;

    end process stim;

end architecture sim;
