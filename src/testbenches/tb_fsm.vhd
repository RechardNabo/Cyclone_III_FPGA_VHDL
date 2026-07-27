library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_fsm is
end entity tb_fsm;

architecture sim of tb_fsm is
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';
    signal din      : std_logic := '0';
    signal detected : std_logic;
begin
    clk <= not clk after 10 ns;

    dut : entity work.fsm_moore
        port map (
            clk => clk, rst => rst, din => din, detected => detected
        );

    stim : process
    begin
        -- Reset
        rst <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        rst <= '0';
        assert detected = '0' report "FAIL: detected after reset" severity error;

        -- Send "101" pattern: 1, 0, 1
        din <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        assert detected = '0' report "FAIL: no detect on 1" severity error;

        din <= '0';
        wait until rising_edge(clk); wait for 1 ns;
        assert detected = '0' report "FAIL: no detect on 10" severity error;

        din <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        assert detected = '1' report "FAIL: should detect 101" severity error;

        -- After detection, output goes low next cycle
        din <= '0';
        wait until rising_edge(clk); wait for 1 ns;
        assert detected = '0' report "FAIL: detected clears" severity error;

        -- Send "1101" to test overlapping
        din <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        din <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        din <= '0';
        wait until rising_edge(clk); wait for 1 ns;
        din <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        assert detected = '1' report "FAIL: should detect 1101" severity error;

        -- No detection for "100"
        din <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        din <= '0';
        wait until rising_edge(clk); wait for 1 ns;
        din <= '0';
        wait until rising_edge(clk); wait for 1 ns;
        assert detected = '0' report "FAIL: no detect for 100" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
