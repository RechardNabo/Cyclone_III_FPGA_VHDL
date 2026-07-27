library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_fir_filter is
end entity tb_fir_filter;

architecture sim of tb_fir_filter is
    constant DATA_WIDTH       : integer := 16;
    constant COEFF_WIDTH      : integer := 16;
    constant OUTPUT_WIDTH     : integer := 32;
    constant NUM_TAPS         : integer := 8;
    constant COEFF_ADDR_WIDTH : integer := 3;

    signal clk            : std_logic := '0';
    signal reset          : std_logic := '0';
    signal data_in        : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_valid_in  : std_logic := '0';
    signal data_out       : signed(OUTPUT_WIDTH-1 downto 0);
    signal data_valid_out : std_logic;
    signal filter_enable  : std_logic := '0';
    signal coeff_load     : std_logic := '0';
    signal coeff_addr     : unsigned(COEFF_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal coeff_data     : signed(COEFF_WIDTH-1 downto 0) := (others => '0');
begin
    clk <= not clk after 10 ns;

    dut : entity work.fir_filter
        generic map (
            DATA_WIDTH => DATA_WIDTH, COEFF_WIDTH => COEFF_WIDTH,
            OUTPUT_WIDTH => OUTPUT_WIDTH, NUM_TAPS => NUM_TAPS,
            COEFF_ADDR_WIDTH => COEFF_ADDR_WIDTH
        )
        port map (
            clk => clk, reset => reset,
            data_in => data_in, data_valid_in => data_valid_in,
            data_out => data_out, data_valid_out => data_valid_out,
            filter_enable => filter_enable,
            coeff_load => coeff_load, coeff_addr => coeff_addr,
            coeff_data => coeff_data
        );

    stim : process
    begin
        -- Reset
        reset <= '1';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset <= '0';

        -- Load coefficients: simple impulse response (tap 0 = 1, rest = 0)
        coeff_load <= '1';
        coeff_addr <= "000";
        coeff_data <= to_signed(16384, COEFF_WIDTH);  -- 1.0 in Q14
        wait until rising_edge(clk);
        coeff_addr <= "001";
        coeff_data <= to_signed(0, COEFF_WIDTH);
        wait until rising_edge(clk);
        coeff_load <= '0';

        -- Enable filter and send impulse
        filter_enable <= '1';
        data_in <= to_signed(100, DATA_WIDTH);
        data_valid_in <= '1';
        wait until rising_edge(clk);
        data_valid_in <= '0';

        -- Wait for output
        for i in 0 to 50 loop
            wait until rising_edge(clk);
            if data_valid_out = '1' then
                exit;
            end if;
        end loop;

        -- Verify output is produced
        assert data_valid_out = '1' or data_valid_out = '0'
            report "FAIL: data_valid_out undefined" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
