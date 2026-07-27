library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_serial_adder is
end entity tb_serial_adder;

architecture sim of tb_serial_adder is
    constant G_WIDTH : integer := 8;

    signal clk         : std_logic := '0';
    signal rst_n       : std_logic := '0';
    signal start_i     : std_logic := '0';
    signal a_in_i      : std_logic_vector(G_WIDTH-1 downto 0) := (others => '0');
    signal b_in_i      : std_logic_vector(G_WIDTH-1 downto 0) := (others => '0');
    signal sum_out_o   : std_logic_vector(G_WIDTH-1 downto 0);
    signal carry_out_o : std_logic;
    signal busy_o      : std_logic;
    signal done_o      : std_logic;
begin
    clk <= not clk after 10 ns;

    dut : entity work.serial_adder_fsmd
        generic map (G_WIDTH => G_WIDTH)
        port map (
            clk => clk, rst_n => rst_n, start_i => start_i,
            a_in_i => a_in_i, b_in_i => b_in_i,
            sum_out_o => sum_out_o, carry_out_o => carry_out_o,
            busy_o => busy_o, done_o => done_o
        );

    stim : process
    begin
        -- Reset (active low)
        rst_n <= '0';
        wait for 25 ns;
        wait until rising_edge(clk);
        rst_n <= '1';
        wait until rising_edge(clk);

        -- Test 1: 0x0F + 0x01 = 0x10
        a_in_i <= x"0F";
        b_in_i <= x"01";
        start_i <= '1';
        wait until rising_edge(clk);
        start_i <= '0';

        -- Wait for done
        for i in 0 to G_WIDTH + 5 loop
            wait until rising_edge(clk);
            if done_o = '1' then
                exit;
            end if;
        end loop;

        assert done_o = '1' report "FAIL: add 0F+01 did not complete" severity error;
        if done_o = '1' then
            assert sum_out_o = x"10"
                report "FAIL: 0F+01 should be 10" severity error;
        end if;

        -- Test 2: 0xFF + 0x01 = 0x00 with carry
        wait until rising_edge(clk);
        a_in_i <= x"FF";
        b_in_i <= x"01";
        start_i <= '1';
        wait until rising_edge(clk);
        start_i <= '0';

        for i in 0 to G_WIDTH + 5 loop
            wait until rising_edge(clk);
            if done_o = '1' then
                exit;
            end if;
        end loop;

        assert done_o = '1' report "FAIL: add FF+01 did not complete" severity error;
        if done_o = '1' then
            assert sum_out_o = x"00"
                report "FAIL: FF+01 should be 00" severity error;
            assert carry_out_o = '1'
                report "FAIL: FF+01 should have carry" severity error;
        end if;

        -- Test 3: 0x55 + 0xAA = 0xFF
        wait until rising_edge(clk);
        a_in_i <= x"55";
        b_in_i <= x"AA";
        start_i <= '1';
        wait until rising_edge(clk);
        start_i <= '0';

        for i in 0 to G_WIDTH + 5 loop
            wait until rising_edge(clk);
            if done_o = '1' then
                exit;
            end if;
        end loop;

        assert done_o = '1' report "FAIL: add 55+AA did not complete" severity error;
        if done_o = '1' then
            assert sum_out_o = x"FF"
                report "FAIL: 55+AA should be FF" severity error;
        end if;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
