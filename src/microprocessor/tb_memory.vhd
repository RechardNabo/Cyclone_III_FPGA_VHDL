-- ============================================================================
-- Testbench for Memory (256 x 8-bit single-port RAM)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_memory is
end entity tb_memory;

architecture behavioral of tb_memory is
    signal clk     : std_logic := '0';
    signal addr    : std_logic_vector(7 downto 0);
    signal wr_en   : std_logic;
    signal wr_data : std_logic_vector(7 downto 0);
    signal rd_data : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 10 ns;
begin
    -- Instantiate the DUT
    DUT : entity work.memory
        port map (
            clk     => clk,
            addr    => addr,
            wr_en   => wr_en,
            wr_data => wr_data,
            rd_data => rd_data
        );

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- Stimulus process
    process
    begin
        -- Test 1: Read pre-loaded address 0 (should be 0x25 = 00100101)
        wr_en <= '0'; addr <= "00000000"; wr_data <= "00000000";
        wait for 5 ns;  -- combinational read
        assert rd_data = "00100101"
            report "Test 1 FAILED: addr 0 should be 0x25"
            severity error;

        -- Test 2: Read pre-loaded address 1 (should be 0x2B = 00101011)
        addr <= "00000001";
        wait for 5 ns;
        assert rd_data = "00101011"
            report "Test 2 FAILED: addr 1 should be 0x2B"
            severity error;

        -- Test 3: Write to address 10, then read it back
        addr <= "00001010"; wr_data <= "10101010"; wr_en <= '1';
        wait for CLK_PERIOD;
        wr_en <= '0';
        wait for 5 ns;
        assert rd_data = "10101010"
            report "Test 3 FAILED: written addr 10 should read back 10101010"
            severity error;

        -- Test 4: Write to address 255, then read it back
        addr <= "11111111"; wr_data <= "11110000"; wr_en <= '1';
        wait for CLK_PERIOD;
        wr_en <= '0';
        wait for 5 ns;
        assert rd_data = "11110000"
            report "Test 4 FAILED: written addr 255 should read back 11110000"
            severity error;

        -- Test 5: Read pre-loaded address 4 (should be 0xE0 = 11100000)
        addr <= "00000100";
        wait for 5 ns;
        assert rd_data = "11100000"
            report "Test 5 FAILED: addr 4 should be 0xE0"
            severity error;

        -- Test 6: Write to address 0, overwriting pre-loaded value, then read back
        addr <= "00000000"; wr_data <= "00000000"; wr_en <= '1';
        wait for CLK_PERIOD;
        wr_en <= '0';
        wait for 5 ns;
        assert rd_data = "00000000"
            report "Test 6 FAILED: overwritten addr 0 should read back 00000000"
            severity error;

        report "All memory tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;
