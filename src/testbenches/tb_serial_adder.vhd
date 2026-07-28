library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_serial_adder is
end entity tb_serial_adder;

architecture sim of tb_serial_adder is
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal start  : std_logic := '0';
    signal a      : std_logic_vector(7 downto 0) := (others => '0');
    signal b      : std_logic_vector(7 downto 0) := (others => '0');
    signal sum    : std_logic_vector(7 downto 0);
    signal done   : std_logic;
begin
    clk <= not clk after 10 ns;

    dut : entity work.serial_adder_fsmd
        port map (
            clk   => clk,
            reset => reset,
            start => start,
            a     => a,
            b     => b,
            sum   => sum,
            done  => done
        );

    stim : process
    begin
        -- Reset
        reset <= '1';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        -- Test 1: 0x0F + 0x01 = 0x10
        a <= x"0F";
        b <= x"01";
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        -- Wait for done
        for i in 0 to 13 loop
            wait until rising_edge(clk);
            if done = '1' then
                exit;
            end if;
        end loop;

        assert done = '1' report "FAIL: add 0F+01 did not complete" severity error;
        if done = '1' then
            assert sum = x"10"
                report "FAIL: 0F+01 should be 10" severity error;
        end if;

        -- Test 2: 0xFF + 0x01 = 0x00 with carry
        wait until rising_edge(clk);
        a <= x"FF";
        b <= x"01";
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        for i in 0 to 13 loop
            wait until rising_edge(clk);
            if done = '1' then
                exit;
            end if;
        end loop;

        assert done = '1' report "FAIL: add FF+01 did not complete" severity error;
        if done = '1' then
            assert sum = x"00"
                report "FAIL: FF+01 should be 00" severity error;
        end if;

        -- Test 3: 0x55 + 0xAA = 0xFF
        wait until rising_edge(clk);
        a <= x"55";
        b <= x"AA";
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        for i in 0 to 13 loop
            wait until rising_edge(clk);
            if done = '1' then
                exit;
            end if;
        end loop;

        assert done = '1' report "FAIL: add 55+AA did not complete" severity error;
        if done = '1' then
            assert sum = x"FF"
                report "FAIL: 55+AA should be FF" severity error;
        end if;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
