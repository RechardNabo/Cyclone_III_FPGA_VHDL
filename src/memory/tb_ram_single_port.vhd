-- ============================================================================
-- Testbench for Single-Port RAM
-- ============================================================================
-- Tests write-then-read at multiple addresses on a single-port RAM where
-- the same port is used for both reading and writing (controlled by 'we').
-- Verifies data integrity across several locations.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_ram_single_port is
end entity tb_ram_single_port;

architecture sim of tb_ram_single_port is

    -- DUT generics
    constant WIDTH : integer := 8;
    constant DEPTH : integer := 256;

    -- DUT signals
    signal clk  : std_logic := '0';
    signal we   : std_logic := '0';
    signal addr : std_logic_vector(7 downto 0) := (others => '0');
    signal din  : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal dout : std_logic_vector(WIDTH-1 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.ram_single_port
        generic map (
            WIDTH => WIDTH,
            DEPTH => DEPTH
        )
        port map (
            clk  => clk,
            we   => we,
            addr => addr,
            din  => din,
            dout => dout
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
        -- Test 1: Write 0x42 to address 0, read it back
        -- -------------------------------------------------------
        we  <= '1';
        addr <= x"00";
        din  <= x"42";
        wait for CLK_PERIOD;
        we  <= '0';
        addr <= x"00";
        wait for CLK_PERIOD;
        assert dout = x"42"
            report "Test 1 FAIL: Expected 0x42 at address 0"
            severity error;
        report "Test 1 PASS: Wrote and read 0x42 at address 0" severity note;

        -- -------------------------------------------------------
        -- Test 2: Write 0x7E to address 128, read it back
        -- -------------------------------------------------------
        we  <= '1';
        addr <= x"80";
        din  <= x"7E";
        wait for CLK_PERIOD;
        we  <= '0';
        addr <= x"80";
        wait for CLK_PERIOD;
        assert dout = x"7E"
            report "Test 2 FAIL: Expected 0x7E at address 128"
            severity error;
        report "Test 2 PASS: Wrote and read 0x7E at address 128" severity note;

        -- -------------------------------------------------------
        -- Test 3: Write 0xC3 to address 255, read it back
        -- -------------------------------------------------------
        we  <= '1';
        addr <= x"FF";
        din  <= x"C3";
        wait for CLK_PERIOD;
        we  <= '0';
        addr <= x"FF";
        wait for CLK_PERIOD;
        assert dout = x"C3"
            report "Test 3 FAIL: Expected 0xC3 at address 255"
            severity error;
        report "Test 3 PASS: Wrote and read 0xC3 at address 255" severity note;

        -- -------------------------------------------------------
        -- Test 4: Verify address 0 still holds 0x42 (no corruption)
        -- -------------------------------------------------------
        addr <= x"00";
        wait for CLK_PERIOD;
        assert dout = x"42"
            report "Test 4 FAIL: Address 0 corrupted, expected 0x42"
            severity error;
        report "Test 4 PASS: Address 0 retains 0x42" severity note;

        -- -------------------------------------------------------
        -- Test 5: Loop write/read of 8 addresses
        -- -------------------------------------------------------
        we <= '1';
        for i in 0 to 7 loop
            addr <= std_logic_vector(to_unsigned(i + 32, 8));
            din  <= std_logic_vector(to_unsigned(i * 3 + 5, 8));
            wait for CLK_PERIOD;
        end loop;
        we <= '0';
        for i in 0 to 7 loop
            addr <= std_logic_vector(to_unsigned(i + 32, 8));
            wait for CLK_PERIOD;
            assert dout = std_logic_vector(to_unsigned(i * 3 + 5, 8))
                report "Test 5 FAIL: Mismatch at address " & integer'image(i + 32)
                severity error;
        end loop;
        report "Test 5 PASS: Loop write/read of 8 addresses correct" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;
