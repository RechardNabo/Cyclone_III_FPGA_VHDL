-- Testbench for jk_flip_flop
-- Tests all JK modes: hold, reset, set, toggle, and async reset
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_jk_flip_flop is
end entity tb_jk_flip_flop;

architecture behavior of tb_jk_flip_flop is
    -- DUT signals
    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';
    signal j     : std_logic := '0';
    signal k     : std_logic := '0';
    signal q     : std_logic;

    -- Component declaration
    component jk_flip_flop is
        port (
            clk   : in  std_logic;
            reset : in  std_logic;
            j     : in  std_logic;
            k     : in  std_logic;
            q     : out std_logic
        );
    end component jk_flip_flop;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate the DUT
    dut : jk_flip_flop
        port map (
            clk   => clk,
            reset => reset,
            j     => j,
            k     => k,
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
        -- Test case 1: Async reset -> Q=0
        reset <= '1';
        j <= '0'; k <= '0';
        wait for 5 ns;
        assert q = '0'
            report "Test 1 FAILED: reset=1, expected q=0, got q=" & std_logic'image(q)
            severity error;

        -- Test case 2: J=1, K=0 (set) -> Q=1 after rising edge
        reset <= '0';
        j <= '1'; k <= '0';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert q = '1'
            report "Test 2 FAILED: J=1 K=0 (set), expected q=1, got q=" & std_logic'image(q)
            severity error;

        -- Test case 3: J=0, K=0 (hold) -> Q should remain 1
        j <= '0'; k <= '0';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert q = '1'
            report "Test 3 FAILED: J=0 K=0 (hold), expected q=1, got q=" & std_logic'image(q)
            severity error;

        -- Test case 4: J=0, K=1 (reset) -> Q=0
        j <= '0'; k <= '1';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert q = '0'
            report "Test 4 FAILED: J=0 K=1 (reset), expected q=0, got q=" & std_logic'image(q)
            severity error;

        -- Test case 5: J=1, K=1 (toggle) -> Q=1 (toggles from 0)
        j <= '1'; k <= '1';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert q = '1'
            report "Test 5 FAILED: J=1 K=1 (toggle from 0), expected q=1, got q=" & std_logic'image(q)
            severity error;

        -- Test case 6: J=1, K=1 (toggle again) -> Q=0 (toggles from 1)
        j <= '1'; k <= '1';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert q = '0'
            report "Test 6 FAILED: J=1 K=1 (toggle from 1), expected q=0, got q=" & std_logic'image(q)
            severity error;

        -- Test case 7: Async reset during operation -> Q=0
        reset <= '1';
        j <= '1'; k <= '0';
        wait for 5 ns;
        assert q = '0'
            report "Test 7 FAILED: async reset, expected q=0, got q=" & std_logic'image(q)
            severity error;

        report "All jk_flip_flop tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;
