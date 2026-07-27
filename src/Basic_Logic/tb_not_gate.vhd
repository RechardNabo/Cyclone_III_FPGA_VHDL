-- Testbench for not_gate
-- Tests all input combinations for a single-input NOT gate
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_not_gate is
end entity tb_not_gate;

architecture behavior of tb_not_gate is
    -- DUT signals
    signal A : std_logic;
    signal Y : std_logic;

    -- Component declaration
    component not_gate is
        port (
            A : in  std_logic;
            Y : out std_logic
        );
    end component not_gate;

begin
    -- Instantiate the DUT
    dut : not_gate
        port map (
            A => A,
            Y => Y
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- Test case 1: A = '0' -> Y should be '1'
        A <= '0';
        wait for 10 ns;
        assert Y = '1'
            report "Test 1 FAILED: A=0, expected Y=1, got Y=" & std_logic'image(Y)
            severity error;

        -- Test case 2: A = '1' -> Y should be '0'
        A <= '1';
        wait for 10 ns;
        assert Y = '0'
            report "Test 2 FAILED: A=1, expected Y=0, got Y=" & std_logic'image(Y)
            severity error;

        -- Test case 3: A = '0' -> Y should be '1'
        A <= '0';
        wait for 10 ns;
        assert Y = '1'
            report "Test 3 FAILED: A=0, expected Y=1, got Y=" & std_logic'image(Y)
            severity error;

        -- Test case 4: A = '1' -> Y should be '0'
        A <= '1';
        wait for 10 ns;
        assert Y = '0'
            report "Test 4 FAILED: A=1, expected Y=0, got Y=" & std_logic'image(Y)
            severity error;

        -- Test case 5: A = '0' -> Y should be '1'
        A <= '0';
        wait for 10 ns;
        assert Y = '1'
            report "Test 5 FAILED: A=0, expected Y=1, got Y=" & std_logic'image(Y)
            severity error;

        report "All not_gate tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;
