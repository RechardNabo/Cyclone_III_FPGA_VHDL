library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_gcd is
end entity tb_gcd;

architecture sim of tb_gcd is
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal start  : std_logic := '0';
    signal a      : std_logic_vector(7 downto 0) := (others => '0');
    signal b      : std_logic_vector(7 downto 0) := (others => '0');
    signal gcd_out: std_logic_vector(7 downto 0);
    signal done   : std_logic;
begin
    clk <= not clk after 10 ns;

    dut : entity work.gcd_rtl
        port map (
            clk     => clk,
            reset   => reset,
            start   => start,
            a       => a,
            b       => b,
            gcd_out => gcd_out,
            done    => done
        );

    stim : process
    begin
        -- Reset
        reset <= '1'; start <= '0';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        -- Test GCD(12, 8) = 4
        a <= std_logic_vector(to_unsigned(12, 8));
        b <= std_logic_vector(to_unsigned(8, 8));
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        -- Wait for done
        for i in 0 to 200 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            if done = '1' then
                exit;
            end if;
        end loop;

        assert done = '1' report "FAIL: GCD(12,8) did not complete" severity error;
        if done = '1' then
            assert gcd_out = std_logic_vector(to_unsigned(4, 8))
                report "FAIL: GCD(12,8) should be 4" severity error;
        end if;

        -- Test GCD(48, 36) = 12
        wait until rising_edge(clk);
        a <= std_logic_vector(to_unsigned(48, 8));
        b <= std_logic_vector(to_unsigned(36, 8));
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        for i in 0 to 200 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            if done = '1' then
                exit;
            end if;
        end loop;

        assert done = '1' report "FAIL: GCD(48,36) did not complete" severity error;
        if done = '1' then
            assert gcd_out = std_logic_vector(to_unsigned(12, 8))
                report "FAIL: GCD(48,36) should be 12" severity error;
        end if;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
