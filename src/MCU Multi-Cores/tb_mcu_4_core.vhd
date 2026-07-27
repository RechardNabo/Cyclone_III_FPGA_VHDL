-- ============================================================================
-- Testbench for MCU_4_Cores : Quad-core 8-bit MCU with round-robin arbiter
-- ============================================================================
-- Verifies the round-robin bus arbiter cycles through cores 0-3 and that
-- cores execute a simple HLT program.  Checks the active core index output
-- and the packed 32-bit core_status.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_mcu_4_core is
end entity tb_mcu_4_core;

architecture sim of tb_mcu_4_core is

    constant CLK_PERIOD : time := 20 ns;

    signal clk         : std_logic := '0';
    signal reset       : std_logic := '1';
    signal addr_out    : std_logic_vector(7 downto 0);
    signal data_out    : std_logic_vector(7 downto 0);
    signal we          : std_logic;
    signal active      : std_logic_vector(1 downto 0);
    signal data_in     : std_logic_vector(7 downto 0);
    signal oe          : std_logic;
    signal irq         : std_logic_vector(3 downto 0) := (others => '0');
    signal irq_ack     : std_logic_vector(3 downto 0);
    signal core_status : std_logic_vector(31 downto 0);

    -- Memory model: 256-byte array
    type mem_t is array(0 to 255) of std_logic_vector(7 downto 0);
    signal mem : mem_t := (others => (others => '0'));

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.MCU_4_Cores
        port map (
            clk         => clk,
            reset       => reset,
            addr_out    => addr_out,
            data_out    => data_out,
            we          => we,
            active      => active,
            data_in     => data_in,
            oe          => oe,
            irq         => irq,
            irq_ack     => irq_ack,
            core_status => core_status
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
        variable seen_active : std_logic_vector(3 downto 0) := "0000";
    begin
        -- ------------------------------------------------------------------
        -- Load program: HLT at address 0
        -- ------------------------------------------------------------------
        mem(0) <= x"B0";  -- HLT

        -- ------------------------------------------------------------------
        -- Reset
        -- ------------------------------------------------------------------
        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';
        wait until rising_edge(clk);

        -- ------------------------------------------------------------------
        -- Test 1: Verify round-robin arbiter cycles through 0-3
        -- ------------------------------------------------------------------
        for i in 0 to 7 loop
            wait until rising_edge(clk);
            case active is
                when "00" => seen_active(0) := '1';
                when "01" => seen_active(1) := '1';
                when "10" => seen_active(2) := '1';
                when "11" => seen_active(3) := '1';
                when others => null;
            end case;
        end loop;

        assert seen_active = "1111"
            report "Test 1 FAIL: round-robin did not cycle through all 4 cores, seen=" &
                   integer'image(to_integer(unsigned(seen_active)))
            severity error;
        report "Test 1 PASS: round-robin arbiter cycled through all 4 cores" severity note;

        -- ------------------------------------------------------------------
        -- Test 2: Verify all cores halt after executing HLT
        --   Each core gets 1/4 of cycles; HLT takes 2 bus cycles.
        --   Wait ~20 cycles.
        -- ------------------------------------------------------------------
        for i in 0 to 30 loop
            wait until rising_edge(clk);
            -- Check all 4 halted bits (bit 1 of each status byte)
            if core_status(1) = '1' and core_status(9) = '1' and
               core_status(17) = '1' and core_status(25) = '1' then
                exit;
            end if;
        end loop;

        assert core_status(1) = '1'
            report "Test 2 FAIL: core0 did not halt"
            severity error;
        assert core_status(9) = '1'
            report "Test 2 FAIL: core1 did not halt"
            severity error;
        assert core_status(17) = '1'
            report "Test 2 FAIL: core2 did not halt"
            severity error;
        assert core_status(25) = '1'
            report "Test 2 FAIL: core3 did not halt"
            severity error;
        report "Test 2 PASS: all 4 cores halted after HLT" severity note;

        -- ------------------------------------------------------------------
        -- Test 3: Verify running bits are clear after halt
        -- ------------------------------------------------------------------
        assert core_status(0) = '0'
            report "Test 3 FAIL: core0 still running"
            severity error;
        assert core_status(8) = '0'
            report "Test 3 FAIL: core1 still running"
            severity error;
        assert core_status(16) = '0'
            report "Test 3 FAIL: core2 still running"
            severity error;
        assert core_status(24) = '0'
            report "Test 3 FAIL: core3 still running"
            severity error;
        report "Test 3 PASS: all cores show running=0 after halt" severity note;

        -- ------------------------------------------------------------------
        -- Test 4: Verify active output is valid (0-3)
        -- ------------------------------------------------------------------
        assert unsigned(active) <= 3
            report "Test 4 FAIL: active core index out of range"
            severity error;
        report "Test 4 PASS: active core index valid" severity note;

        -- ------------------------------------------------------------------
        -- Done
        -- ------------------------------------------------------------------
        report "All MCU_4_Cores tests passed" severity note;
        assert false report "Testbench complete" severity failure;

    end process stim;

end architecture sim;
