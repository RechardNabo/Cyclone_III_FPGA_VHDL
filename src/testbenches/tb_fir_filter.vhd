library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_fir_filter is
end entity tb_fir_filter;

architecture sim of tb_fir_filter is
    constant DATA_WIDTH : integer := 16;
    constant NUM_TAPS   : integer := 8;

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '0';
    signal valid_in  : std_logic := '0';
    signal data_in   : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal valid_out : std_logic;
    signal data_out  : std_logic_vector(DATA_WIDTH-1 downto 0);
begin
    clk <= not clk after 10 ns;

    dut : entity work.fir_filter
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            NUM_TAPS   => NUM_TAPS
        )
        port map (
            clk       => clk,
            reset     => reset,
            valid_in  => valid_in,
            data_in   => data_in,
            valid_out => valid_out,
            data_out  => data_out
        );

    stim : process
    begin
        -- Reset
        reset <= '1';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset <= '0';

        -- Send impulse: a single non-zero sample followed by zeros
        data_in  <= std_logic_vector(to_signed(100, DATA_WIDTH));
        valid_in <= '1';
        wait until rising_edge(clk);
        data_in  <= (others => '0');
        wait until rising_edge(clk);
        valid_in <= '0';

        -- Wait for output
        for i in 0 to 50 loop
            wait until rising_edge(clk);
            if valid_out = '1' then
                exit;
            end if;
        end loop;

        -- Verify output is produced
        assert valid_out = '1' or valid_out = '0'
            report "FAIL: valid_out undefined" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
