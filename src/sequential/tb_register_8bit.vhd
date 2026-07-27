-- Testbench for register_8bit (8-bit register with load enable and async reset)
-- Tests async reset, load, hold, and multiple data patterns
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_register_8bit is
end entity tb_register_8bit;

architecture behavior of tb_register_8bit is
    -- DUT signals
    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';
    signal load  : std_logic := '0';
    signal d_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal d_out : std_logic_vector(7 downto 0);

    -- Component declaration
    component register_8bit is
        port (
            clk   : in  std_logic;
            reset : in  std_logic;
            load  : in  std_logic;
            d_in  : in  std_logic_vector(7 downto 0);
            d_out : out std_logic_vector(7 downto 0)
        );
    end component register_8bit;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate the DUT
    dut : register_8bit
        port map (
            clk   => clk,
            reset => reset,
            load  => load,
            d_in  => d_in,
            d_out => d_out
        );

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process clk_proc;

    -- Stimulus process
    stim_proc : process
    begin
        -- Test case 1: Async reset -> d_out = 0x00
        reset <= '1';
        load <= '1'; d_in <= "11111111";
        wait for 5 ns;
        assert d_out = "00000000"
            report "Test 1 FAILED: reset=1, expected d_out=00000000"
            severity error;

        -- Test case 2: Release reset, load 0xAA (10101010)
        reset <= '0';
        load <= '1'; d_in <= "10101010";
        wait until rising_edge(clk);
        wait for 5 ns;
        assert d_out = "10101010"
            report "Test 2 FAILED: load 10101010, expected d_out=10101010"
            severity error;

        -- Test case 3: Hold (load=0), d_in changes -> d_out unchanged
        load <= '0'; d_in <= "11110000";
        wait until rising_edge(clk);
        wait for 5 ns;
        assert d_out = "10101010"
            report "Test 3 FAILED: hold, expected d_out=10101010 (unchanged)"
            severity error;

        -- Test case 4: Load 0x55 (01010101)
        load <= '1'; d_in <= "01010101";
        wait until rising_edge(clk);
        wait for 5 ns;
        assert d_out = "01010101"
            report "Test 4 FAILED: load 01010101, expected d_out=01010101"
            severity error;

        -- Test case 5: Async reset during operation -> d_out = 0x00
        reset <= '1';
        wait for 5 ns;
        assert d_out = "00000000"
            report "Test 5 FAILED: async reset, expected d_out=00000000"
            severity error;

        -- Test case 6: Release reset, load 0xF0 (11110000)
        reset <= '0';
        load <= '1'; d_in <= "11110000";
        wait until rising_edge(clk);
        wait for 5 ns;
        assert d_out = "11110000"
            report "Test 6 FAILED: load 11110000, expected d_out=11110000"
            severity error;

        report "All register_8bit tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;
