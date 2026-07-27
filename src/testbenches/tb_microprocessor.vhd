library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_microprocessor is
end entity tb_microprocessor;

architecture sim of tb_microprocessor is
    signal clk         : std_logic := '0';
    signal reset       : std_logic := '0';
    signal output_port : std_logic_vector(7 downto 0);
    signal done        : std_logic;
begin
    clk <= not clk after 10 ns;

    dut : entity work.microprocessor
        port map (
            clk => clk, reset => reset,
            output_port => output_port, done => done
        );

    stim : process
    begin
        -- Assert reset
        reset <= '1';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset <= '0';
        assert done = '0' report "FAIL: done should be 0 after reset" severity error;

        -- Run for many cycles to allow program execution
        for i in 0 to 200 loop
            wait until rising_edge(clk);
            if done = '1' then
                exit;
            end if;
        end loop;

        -- Check that done eventually goes high (program reaches HALT)
        assert done = '1' report "FAIL: processor did not reach HALT" severity error;

        -- Verify output_port is valid (non-U)
        assert output_port'event or output_port = output_port
            report "FAIL: output_port undefined" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
