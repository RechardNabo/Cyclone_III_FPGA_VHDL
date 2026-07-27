library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_gcd is
end entity tb_gcd;

architecture sim of tb_gcd is
    constant DATA_WIDTH : integer := 16;

    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal enable : std_logic := '0';
    signal start  : std_logic := '0';
    signal a_in   : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
    signal b_in   : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
    signal gcd_out: unsigned(DATA_WIDTH-1 downto 0);
    signal done   : std_logic;
    signal valid  : std_logic;
    signal busy   : std_logic;
    signal error  : std_logic;
begin
    clk <= not clk after 10 ns;

    dut : entity work.gcd_rtl
        generic map (DATA_WIDTH => DATA_WIDTH)
        port map (
            clk => clk, reset => reset, enable => enable, start => start,
            a_in => a_in, b_in => b_in,
            gcd_out => gcd_out, done => done, valid => valid,
            busy => busy, error => error
        );

    stim : process
    begin
        -- Reset
        reset <= '1'; enable <= '0'; start <= '0';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset <= '0';

        -- Enable module
        enable <= '1';
        wait until rising_edge(clk);

        -- Test GCD(12, 8) = 4
        a_in <= to_unsigned(12, DATA_WIDTH);
        b_in <= to_unsigned(8, DATA_WIDTH);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        -- Wait for done
        for i in 0 to 200 loop
            wait until rising_edge(clk);
            if done = '1' then
                exit;
            end if;
        end loop;

        assert done = '1' report "FAIL: GCD(12,8) did not complete" severity error;
        if done = '1' then
            assert gcd_out = to_unsigned(4, DATA_WIDTH)
                report "FAIL: GCD(12,8) should be 4" severity error;
        end if;

        -- Test GCD(48, 36) = 12
        wait until rising_edge(clk);
        a_in <= to_unsigned(48, DATA_WIDTH);
        b_in <= to_unsigned(36, DATA_WIDTH);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        for i in 0 to 200 loop
            wait until rising_edge(clk);
            if done = '1' then
                exit;
            end if;
        end loop;

        assert done = '1' report "FAIL: GCD(48,36) did not complete" severity error;
        if done = '1' then
            assert gcd_out = to_unsigned(12, DATA_WIDTH)
                report "FAIL: GCD(48,36) should be 12" severity error;
        end if;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
