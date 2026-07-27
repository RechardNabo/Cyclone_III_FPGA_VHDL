-- Testbench for sr_latch
-- Tests set, reset, hold, and invalid (both high) states
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_sr_latch is
end entity tb_sr_latch;

architecture behavior of tb_sr_latch is
    -- DUT signals
    signal s   : std_logic := '0';
    signal r   : std_logic := '0';
    signal q   : std_logic;
    signal q_n : std_logic;

    -- Component declaration
    component sr_latch is
        port (
            s   : in  std_logic;
            r   : in  std_logic;
            q   : out std_logic;
            q_n : out std_logic
        );
    end component sr_latch;

begin
    -- Instantiate the DUT
    dut : sr_latch
        port map (
            s   => s,
            r   => r,
            q   => q,
            q_n => q_n
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- Test case 1: Set (S=1, R=0) -> Q=1, Q_n=0
        s <= '1'; r <= '0';
        wait for 10 ns;
        assert q = '1'
            report "Test 1 FAILED: S=1 R=0, expected q=1, got q=" & std_logic'image(q)
            severity error;
        assert q_n = '0'
            report "Test 1 FAILED: S=1 R=0, expected q_n=0, got q_n=" & std_logic'image(q_n)
            severity error;

        -- Test case 2: Hold (S=0, R=0) -> Q should remain 1
        s <= '0'; r <= '0';
        wait for 10 ns;
        assert q = '1'
            report "Test 2 FAILED: S=0 R=0 (hold after set), expected q=1, got q=" & std_logic'image(q)
            severity error;

        -- Test case 3: Reset (S=0, R=1) -> Q=0, Q_n=1
        s <= '0'; r <= '1';
        wait for 10 ns;
        assert q = '0'
            report "Test 3 FAILED: S=0 R=1, expected q=0, got q=" & std_logic'image(q)
            severity error;
        assert q_n = '1'
            report "Test 3 FAILED: S=0 R=1, expected q_n=1, got q_n=" & std_logic'image(q_n)
            severity error;

        -- Test case 4: Hold (S=0, R=0) -> Q should remain 0
        s <= '0'; r <= '0';
        wait for 10 ns;
        assert q = '0'
            report "Test 4 FAILED: S=0 R=0 (hold after reset), expected q=0, got q=" & std_logic'image(q)
            severity error;

        -- Test case 5: Invalid (S=1, R=1) -> Q=0 (forced to 0 per design)
        s <= '1'; r <= '1';
        wait for 10 ns;
        assert q = '0'
            report "Test 5 FAILED: S=1 R=1 (invalid), expected q=0, got q=" & std_logic'image(q)
            severity error;

        -- Test case 6: Set again (S=1, R=0) -> Q=1
        s <= '1'; r <= '0';
        wait for 10 ns;
        assert q = '1'
            report "Test 6 FAILED: S=1 R=0 (set again), expected q=1, got q=" & std_logic'image(q)
            severity error;

        report "All sr_latch tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;
