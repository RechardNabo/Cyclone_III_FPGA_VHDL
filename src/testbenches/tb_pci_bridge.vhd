library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_pci_bridge is
end entity tb_pci_bridge;

architecture sim of tb_pci_bridge is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '0';
    signal start     : std_logic := '0';
    signal addr      : std_logic_vector(31 downto 0) := (others => '0');
    signal data_in   : std_logic_vector(31 downto 0) := (others => '0');
    signal rw        : std_logic := '0';  -- '1' = read, '0' = write
    signal data_out  : std_logic_vector(31 downto 0);
    signal done      : std_logic;
begin
    clk <= not clk after 10 ns;

    dut : entity work.pci_bridge_fsmd
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

        -- Write transaction: addr=0x00001234, data=0xDEADBEEF
        addr    <= x"00001234";
        data_in <= x"DEADBEEF";
        rw      <= '0';  -- write
        start   <= '1';
        wait until rising_edge(clk);
        start   <= '0';

        -- Wait for done
        for i in 0 to 30 loop
            wait until rising_edge(clk);
            if done = '1' then
                exit;
            end if;
        end loop;
        assert done = '1' report "FAIL: write transaction did not complete" severity error;
        wait until rising_edge(clk);

        -- Read transaction: addr=0x00005678
        addr    <= x"00005678";
        rw      <= '1';  -- read
        start   <= '1';
        wait until rising_edge(clk);
        start   <= '0';

        -- Wait for done
        for i in 0 to 30 loop
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
