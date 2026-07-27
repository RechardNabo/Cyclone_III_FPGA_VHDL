-- ============================================================================
-- Testbench for Dual-Port RAM
-- ============================================================================
-- Tests write-then-read at multiple addresses using Port A (write) and
-- Port B (read). Verifies data integrity across several locations and
-- confirms that writes on Port A are visible to Port B on subsequent clocks.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_ram_dual_port is
end entity tb_ram_dual_port;

architecture sim of tb_ram_dual_port is

    -- DUT generics
    constant WIDTH : integer := 8;
    constant DEPTH : integer := 256;

    -- DUT signals
    signal clk    : std_logic := '0';
    signal we_a   : std_logic := '0';
    signal addr_a : std_logic_vector(7 downto 0) := (others => '0');
    signal din_a  : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal addr_b : std_logic_vector(7 downto 0) := (others => '0');
    signal dout_b : std_logic_vector(WIDTH-1 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.ram_dual_port
        generic map (
            WIDTH => WIDTH,
            DEPTH => DEPTH
        )
        port map (
            clk    => clk,
            we_a   => we_a,
            addr_a => addr_a,
            din_a  => din_a,
            addr_b => addr_b,
            dout_b => dout_b
        );

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus process
    stim_proc : process
    begin
        -- -------------------------------------------------------
        -- Test 1: Write 0x55 to address 0, read it back
        -- -------------------------------------------------------
        we_a   <= '1';
        addr_a <= x"00";
        din_a  <= x"55";
        addr_b <= x"00";
        wait for CLK_PERIOD;   -- write happens on this rising edge
        we_a   <= '0';
        addr_b <= x"00";
        wait for CLK_PERIOD;   -- read happens on this rising edge
        assert dout_b = x"55"
            report "Test 1 FAIL: Expected 0x55 at address 0, got " &
                   integer'image(to_integer(unsigned(dout_b)))
            severity error;
        report "Test 1 PASS: Wrote and read 0x55 at address 0" severity note;

        -- -------------------------------------------------------
        -- Test 2: Write 0xAA to address 16, read it back
        -- -------------------------------------------------------
        we_a   <= '1';
        addr_a <= x"10";
        din_a  <= x"AA";
        wait for CLK_PERIOD;
        we_a   <= '0';
        addr_b <= x"10";
        wait for CLK_PERIOD;
        assert dout_b = x"AA"
            report "Test 2 FAIL: Expected 0xAA at address 16"
            severity error;
        report "Test 2 PASS: Wrote and read 0xAA at address 16" severity note;

        -- -------------------------------------------------------
        -- Test 3: Write 0xFF to address 255, read it back
        -- -------------------------------------------------------
        we_a   <= '1';
        addr_a <= x"FF";
        din_a  <= x"FF";
        wait for CLK_PERIOD;
        we_a   <= '0';
        addr_b <= x"FF";
        wait for CLK_PERIOD;
        assert dout_b = x"FF"
            report "Test 3 FAIL: Expected 0xFF at address 255"
            severity error;
        report "Test 3 PASS: Wrote and read 0xFF at address 255" severity note;

        -- -------------------------------------------------------
        -- Test 4: Verify address 0 still holds 0x55 (no corruption)
        -- -------------------------------------------------------
        addr_b <= x"00";
        wait for CLK_PERIOD;
        assert dout_b = x"55"
            report "Test 4 FAIL: Address 0 corrupted, expected 0x55"
            severity error;
        report "Test 4 PASS: Address 0 retains 0x55" severity note;

        -- -------------------------------------------------------
        -- Test 5: Write multiple addresses in a loop, read back all
        -- -------------------------------------------------------
        we_a <= '1';
        for i in 0 to 7 loop
            addr_a <= std_logic_vector(to_unsigned(i, 8));
            din_a  <= std_logic_vector(to_unsigned(i * 2 + 1, 8));
            wait for CLK_PERIOD;
        end loop;
        we_a <= '0';
        for i in 0 to 7 loop
            addr_b <= std_logic_vector(to_unsigned(i, 8));
            wait for CLK_PERIOD;
            assert dout_b = std_logic_vector(to_unsigned(i * 2 + 1, 8))
                report "Test 5 FAIL: Mismatch at address " & integer'image(i)
                severity error;
        end loop;
        report "Test 5 PASS: Loop write/read of 8 addresses correct" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;
