library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_ram is
end entity tb_ram;

architecture sim of tb_ram is
    signal clk  : std_logic := '0';
    signal we   : std_logic := '0';
    signal addr : std_logic_vector(7 downto 0) := (others => '0');
    signal din  : std_logic_vector(7 downto 0) := (others => '0');
    signal dout : std_logic_vector(7 downto 0);
begin
    clk <= not clk after 10 ns;

    dut : entity work.ram_single_port
        generic map (WIDTH => 8, DEPTH => 256)
        port map (clk => clk, we => we, addr => addr, din => din, dout => dout);

    stim : process
    begin
        -- Write 0x42 to address 5
        we <= '1'; addr <= x"05"; din <= x"42";
        wait until rising_edge(clk); wait for 1 ns;

        -- Write 0xFF to address 10
        addr <= x"0A"; din <= x"FF";
        wait until rising_edge(clk); wait for 1 ns;

        -- Read address 5
        we <= '0'; addr <= x"05";
        wait until rising_edge(clk); wait for 1 ns;
        assert dout = x"42" report "FAIL: read addr 5 = 0x42" severity error;

        -- Read address 10
        addr <= x"0A";
        wait until rising_edge(clk); wait for 1 ns;
        assert dout = x"FF" report "FAIL: read addr 10 = 0xFF" severity error;

        -- Read unwritten address 0 (should be 'U' or 0, just check no crash)
        addr <= x"00";
        wait until rising_edge(clk); wait for 1 ns;

        -- Write and read address 255 (boundary)
        we <= '1'; addr <= x"FF"; din <= x"80";
        wait until rising_edge(clk); wait for 1 ns;
        we <= '0';
        wait until rising_edge(clk); wait for 1 ns;
        assert dout = x"80" report "FAIL: read addr 255 = 0x80" severity error;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
