library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_flipflop is
end entity tb_flipflop;

architecture sim of tb_flipflop is
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal enable : std_logic := '0';
    signal d      : std_logic := '0';
    signal q      : std_logic;
begin
    clk <= not clk after 10 ns;

    dut : entity work.d_flipflop
        port map (
            clk => clk, reset => reset, enable => enable, d => d, q => q
        );

    stim : process
    begin
        -- Async reset
        reset <= '1'; enable <= '0'; d <= '1';
        wait for 5 ns;
        assert q = '0' report "FAIL: async reset" severity error;

        -- Release reset, enable, load D=1
        reset <= '0'; enable <= '1'; d <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        assert q = '1' report "FAIL: load D=1" severity error;

        -- Load D=0
        d <= '0';
        wait until rising_edge(clk); wait for 1 ns;
        assert q = '0' report "FAIL: load D=0" severity error;

        -- Disable: should hold Q=0
        enable <= '0'; d <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        assert q = '0' report "FAIL: hold when disabled" severity error;

        -- Re-enable, load D=1
        enable <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        assert q = '1' report "FAIL: load D=1 after re-enable" severity error;

        -- Async reset while enabled
        reset <= '1';
        wait for 5 ns;
        assert q = '0' report "FAIL: async reset overrides enable" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
