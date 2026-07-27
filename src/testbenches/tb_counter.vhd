library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_counter is
end entity tb_counter;

architecture sim of tb_counter is
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal enable : std_logic := '0';
    signal count  : std_logic_vector(3 downto 0);
begin
    clk <= not clk after 10 ns;

    dut : entity work.counter_4bit
        port map (
            clk => clk, reset => reset, enable => enable, count => count
        );

    stim : process
    begin
        -- Reset
        reset <= '1'; enable <= '0';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);
        assert count = "0000" report "FAIL: count not 0 after reset" severity error;

        -- Count up 3 cycles
        enable <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        assert count = "0001" report "FAIL: count=1" severity error;
        wait until rising_edge(clk); wait for 1 ns;
        assert count = "0010" report "FAIL: count=2" severity error;
        wait until rising_edge(clk); wait for 1 ns;
        assert count = "0011" report "FAIL: count=3" severity error;

        -- Disable: should hold
        enable <= '0';
        wait until rising_edge(clk); wait for 1 ns;
        assert count = "0011" report "FAIL: count held" severity error;

        -- Re-enable and count to overflow
        enable <= '1';
        for i in 0 to 11 loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;
        assert count = "1111" report "FAIL: count=15" severity error;

        -- Overflow wraps to 0
        wait until rising_edge(clk); wait for 1 ns;
        assert count = "0000" report "FAIL: count wraps to 0" severity error;

        -- Sync reset
        reset <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        assert count = "0000" report "FAIL: sync reset" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
