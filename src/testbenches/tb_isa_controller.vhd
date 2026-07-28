library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_isa_controller is
end entity tb_isa_controller;

architecture sim of tb_isa_controller is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '0';
    signal start     : std_logic := '0';
    signal addr      : std_logic_vector(15 downto 0) := (others => '0');
    signal data_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal rw        : std_logic := '0';  -- '1' = read, '0' = write
    signal data_out  : std_logic_vector(7 downto 0);
    signal done      : std_logic;
begin
    clk <= not clk after 10 ns;

    dut : entity work.isa_controller_fsmd
        port map (
            clk      => clk,
            reset    => reset,
            start    => start,
            addr     => addr,
            data_in  => data_in,
            rw       => rw,
            data_out => data_out,
            done     => done
        );

    stim : process
    begin
        -- Reset
        reset <= '1';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        -- Write transaction: addr=0x0080, data=0xAB
        addr    <= x"0080";
        data_in <= x"AB";
        rw      <= '0';  -- write
        start   <= '1';
        wait until rising_edge(clk);
        start   <= '0';

        -- Wait for done
        for i in 0 to 20 loop
            wait until rising_edge(clk);
            if done = '1' then
                exit;
            end if;
        end loop;
        assert done = '1' report "FAIL: write transaction did not complete" severity error;
        wait until rising_edge(clk);

        -- Read transaction: addr=0x1000
        addr    <= x"1000";
        rw      <= '1';  -- read
        start   <= '1';
        wait until rising_edge(clk);
        start   <= '0';

        -- Wait for done
        for i in 0 to 20 loop
            wait until rising_edge(clk);
            if done = '1' then
                exit;
            end if;
        end loop;
        assert done = '1' report "FAIL: read transaction did not complete" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
