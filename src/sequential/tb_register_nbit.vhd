-- Testbench for register_nbit (generic N-bit register with load enable)
-- Tests load, hold, and multiple data patterns
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_register_nbit is
end entity tb_register_nbit;

architecture behavior of tb_register_nbit is
    constant N : integer := 8;

    -- DUT signals
    signal clk   : std_logic := '0';
    signal load  : std_logic := '0';
    signal d_in  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal d_out : std_logic_vector(N-1 downto 0);

    -- Component declaration
    component register_nbit is
        generic (
            N : integer := 8
        );
        port (
            clk   : in  std_logic;
            load  : in  std_logic;
            d_in  : in  std_logic_vector(N-1 downto 0);
            d_out : out std_logic_vector(N-1 downto 0)
        );
    end component register_nbit;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate the DUT with generic
    dut : register_nbit
        generic map (
            N => N
        )
        port map (
            clk   => clk,
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
        -- Test case 1: Load value 0xAA (10101010)
        load <= '1'; d_in <= "10101010";
        wait until rising_edge(clk);
        wait for 5 ns;
        assert d_out = "10101010"
            report "Test 1 FAILED: load 10101010, expected d_out=10101010"
            severity error;

        -- Test case 2: Hold (load=0), change d_in -> d_out should remain
        load <= '0'; d_in <= "11110000";
        wait until rising_edge(clk);
        wait for 5 ns;
        assert d_out = "10101010"
            report "Test 2 FAILED: hold, expected d_out=10101010 (unchanged)"
            severity error;

        -- Test case 3: Load value 0xFF (all ones)
        load <= '1'; d_in <= "11111111";
        wait until rising_edge(clk);
        wait for 5 ns;
        assert d_out = "11111111"
            report "Test 3 FAILED: load 11111111, expected d_out=11111111"
            severity error;

        -- Test case 4: Load value 0x00 (all zeros)
        load <= '1'; d_in <= "00000000";
        wait until rising_edge(clk);
        wait for 5 ns;
        assert d_out = "00000000"
            report "Test 4 FAILED: load 00000000, expected d_out=00000000"
            severity error;

        -- Test case 5: Load value 0x55 (01010101)
        load <= '1'; d_in <= "01010101";
        wait until rising_edge(clk);
        wait for 5 ns;
        assert d_out = "01010101"
            report "Test 5 FAILED: load 01010101, expected d_out=01010101"
            severity error;

        -- Test case 6: Hold with load=0, d_in changes -> d_out unchanged
        load <= '0'; d_in <= "11001100";
        wait until rising_edge(clk);
        wait for 5 ns;
        assert d_out = "01010101"
            report "Test 6 FAILED: hold, expected d_out=01010101 (unchanged)"
            severity error;

        report "All register_nbit tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;
