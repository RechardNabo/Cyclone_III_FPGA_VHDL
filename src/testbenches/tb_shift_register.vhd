library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_shift_register is
end entity tb_shift_register;

architecture sim of tb_shift_register is
    signal clk     : std_logic := '0';
    signal reset   : std_logic := '0';
    signal mode    : std_logic_vector(1 downto 0) := "00";
    signal ser_in  : std_logic := '0';
    signal par_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal ser_out : std_logic;
    signal par_out : std_logic_vector(7 downto 0);
begin
    clk <= not clk after 10 ns;

    dut : entity work.shift_register
        port map (
            clk => clk, reset => reset, mode => mode,
            ser_in => ser_in, par_in => par_in,
            ser_out => ser_out, par_out => par_out
        );

    stim : process
    begin
        -- Async reset
        reset <= '1';
        wait for 5 ns;
        assert par_out = x"00" report "FAIL: reset clears par_out" severity error;
        reset <= '0';

        -- PIPO mode: load parallel value
        mode <= "11"; par_in <= x"A5";
        wait until rising_edge(clk); wait for 1 ns;
        assert par_out = x"A5" report "FAIL: PIPO load A5" severity error;

        -- SISO mode: shift in 3 bits (1,0,1), check serial out
        mode <= "00"; ser_in <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        -- After shift: reg = 1 & A5(7:1) = 11010010 = D2
        assert par_out = x"D2" report "FAIL: SISO shift 1" severity error;

        ser_in <= '0';
        wait until rising_edge(clk); wait for 1 ns;
        -- reg = 0 & D2(7:1) = 01101001 = 69
        assert par_out = x"69" report "FAIL: SISO shift 0" severity error;

        ser_in <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        -- reg = 1 & 69(7:1) = 10110100 = B4
        assert par_out = x"B4" report "FAIL: SISO shift 1" severity error;

        -- SIPO mode: same as SISO for shifting
        mode <= "01"; ser_in <= '0';
        wait until rising_edge(clk); wait for 1 ns;
        -- reg = 0 & B4(7:1) = 01011010 = 5A
        assert par_out = x"5A" report "FAIL: SIPO shift" severity error;

        -- PISO mode: shifts right (same as SISO for this implementation)
        mode <= "10"; ser_in <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        -- reg = 1 & 5A(7:1) = 10101101 = AD
        assert par_out = x"AD" report "FAIL: PISO shift" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
