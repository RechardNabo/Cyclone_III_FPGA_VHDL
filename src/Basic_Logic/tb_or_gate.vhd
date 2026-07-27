-- Testbench for OR_Gate
-- Tests all 4 input combinations for a 2-input OR gate
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_or_gate is
end entity tb_or_gate;

architecture behavior of tb_or_gate is
    -- DUT signals
    signal A : std_logic;
    signal B : std_logic;
    signal Y : std_logic;

    -- Component declaration
    component OR_Gate is
        port (
            A : in  std_logic;
            B : in  std_logic;
            Y : out std_logic
        );
    end component OR_Gate;

begin
    -- Instantiate the DUT
    dut : OR_Gate
        port map (
            A => A,
            B => B,
            Y => Y
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- Test case 1: A=0, B=0 -> Y=0
        A <= '0'; B <= '0';
        wait for 10 ns;
        assert Y = '0'
            report "Test 1 FAILED: A=0 B=0, expected Y=0, got Y=" & std_logic'image(Y)
            severity error;

        -- Test case 2: A=0, B=1 -> Y=1
        A <= '0'; B <= '1';
        wait for 10 ns;
        assert Y = '1'
            report "Test 2 FAILED: A=0 B=1, expected Y=1, got Y=" & std_logic'image(Y)
            severity error;

        -- Test case 3: A=1, B=0 -> Y=1
        A <= '1'; B <= '0';
        wait for 10 ns;
        assert Y = '1'
            report "Test 3 FAILED: A=1 B=0, expected Y=1, got Y=" & std_logic'image(Y)
            severity error;

        -- Test case 4: A=1, B=1 -> Y=1
        A <= '1'; B <= '1';
        wait for 10 ns;
        assert Y = '1'
            report "Test 4 FAILED: A=1 B=1, expected Y=1, got Y=" & std_logic'image(Y)
            severity error;

        -- Test case 5: A=0, B=0 -> Y=0 (re-check)
        A <= '0'; B <= '0';
        wait for 10 ns;
        assert Y = '0'
            report "Test 5 FAILED: A=0 B=0, expected Y=0, got Y=" & std_logic'image(Y)
            severity error;

        report "All OR_Gate tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;
