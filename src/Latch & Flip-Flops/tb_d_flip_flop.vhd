-- Testbench for d_flip_flop
-- Tests async reset, rising-edge capture, and hold behavior
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_d_flip_flop is
end entity tb_d_flip_flop;

architecture behavior of tb_d_flip_flop is
    -- DUT signals
    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';
    signal d     : std_logic := '0';
    signal q     : std_logic;

    -- Component declaration
    component d_flip_flop is
        port (
            clk   : in  std_logic;
            reset : in  std_logic;
            d     : in  std_logic;
            q     : out std_logic
        );
    end component d_flip_flop;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate the DUT
    dut : d_flip_flop
        port map (
            clk   => clk,
            reset => reset,
            d     => d,
            q     => q
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
        -- Test case 1: Async reset -> Q should be 0
        reset <= '1';
        d <= '1';
        wait for 5 ns;
        assert q = '0'
            report "Test 1 FAILED: reset=1, expected q=0, got q=" & std_logic'image(q)
            severity error;

        -- Test case 2: Release reset, D=1, wait for rising edge -> Q=1
        reset <= '0';
        d <= '1';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert q = '1'
            report "Test 2 FAILED: D=1 after rising edge, expected q=1, got q=" & std_logic'image(q)
            severity error;

        -- Test case 3: D=0, wait for rising edge -> Q=0
        d <= '0';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert q = '0'
            report "Test 3 FAILED: D=0 after rising edge, expected q=0, got q=" & std_logic'image(q)
            severity error;

        -- Test case 4: D=1, wait for rising edge -> Q=1
        d <= '1';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert q = '1'
            report "Test 4 FAILED: D=1 after rising edge, expected q=1, got q=" & std_logic'image(q)
            severity error;

        -- Test case 5: Hold value - D changes but no rising edge yet
        d <= '0';
        wait for 5 ns;  -- still high phase, no edge
        assert q = '1'
            report "Test 5 FAILED: D changed mid-cycle, expected q=1 (hold), got q=" & std_logic'image(q)
            severity error;

        -- Test case 6: Async reset while clock running -> Q=0 immediately
        reset <= '1';
        wait for 5 ns;
        assert q = '0'
            report "Test 6 FAILED: async reset during operation, expected q=0, got q=" & std_logic'image(q)
            severity error;

        report "All d_flip_flop tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;
