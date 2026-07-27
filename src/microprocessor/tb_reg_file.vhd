-- ============================================================================
-- Testbench for Register File (8 x 8-bit)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_reg_file is
end entity tb_reg_file;

architecture behavioral of tb_reg_file is
    signal clk      : std_logic := '0';
    signal rst      : std_logic;
    signal wr_en    : std_logic;
    signal rd_addr1 : std_logic_vector(2 downto 0);
    signal rd_addr2 : std_logic_vector(2 downto 0);
    signal wr_addr  : std_logic_vector(2 downto 0);
    signal wr_data  : std_logic_vector(7 downto 0);
    signal rd_data1 : std_logic_vector(7 downto 0);
    signal rd_data2 : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 10 ns;
begin
    -- Instantiate the DUT
    DUT : entity work.reg_file
        port map (
            clk      => clk,
            rst      => rst,
            wr_en    => wr_en,
            rd_addr1 => rd_addr1,
            rd_addr2 => rd_addr2,
            wr_addr  => wr_addr,
            wr_data  => wr_data,
            rd_data1 => rd_data1,
            rd_data2 => rd_data2
        );

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- Stimulus process
    process
    begin
        -- Test 1: Reset all registers to 0
        rst <= '1'; wr_en <= '0';
        rd_addr1 <= "000"; rd_addr2 <= "001";
        wait for CLK_PERIOD;
        assert rd_data1 = "00000000"
            report "Test 1 FAILED: R0 should be 0 after reset"
            severity error;
        assert rd_data2 = "00000000"
            report "Test 1 FAILED: R1 should be 0 after reset"
            severity error;

        -- Test 2: Write 0x55 to R0, read it back
        rst <= '0'; wr_en <= '1'; wr_addr <= "000"; wr_data <= "01010101";
        wait for CLK_PERIOD;
        wr_en <= '0';
        rd_addr1 <= "000";
        wait for 5 ns;
        assert rd_data1 = "01010101"
            report "Test 2 FAILED: R0 should be 0x55 after write"
            severity error;

        -- Test 3: Write 0xAA to R3, read it back
        wr_en <= '1'; wr_addr <= "011"; wr_data <= "10101010";
        wait for CLK_PERIOD;
        wr_en <= '0';
        rd_addr1 <= "011";
        wait for 5 ns;
        assert rd_data1 = "10101010"
            report "Test 3 FAILED: R3 should be 0xAA after write"
            severity error;

        -- Test 4: Read two registers simultaneously
        rd_addr1 <= "000"; rd_addr2 <= "011";
        wait for 5 ns;
        assert rd_data1 = "01010101"
            report "Test 4 FAILED: R0 should still be 0x55"
            severity error;
        assert rd_data2 = "10101010"
            report "Test 4 FAILED: R3 should still be 0xAA"
            severity error;

        -- Test 5: Write to R7 and read back
        wr_en <= '1'; wr_addr <= "111"; wr_data <= "11111111";
        wait for CLK_PERIOD;
        wr_en <= '0';
        rd_addr1 <= "111";
        wait for 5 ns;
        assert rd_data1 = "11111111"
            report "Test 5 FAILED: R7 should be 0xFF after write"
            severity error;

        -- Test 6: Reset clears all, verify R7 is 0
        rst <= '1';
        wait for CLK_PERIOD;
        rst <= '0';
        rd_addr1 <= "111"; rd_addr2 <= "000";
        wait for 5 ns;
        assert rd_data1 = "00000000"
            report "Test 6 FAILED: R7 should be 0 after reset"
            severity error;
        assert rd_data2 = "00000000"
            report "Test 6 FAILED: R0 should be 0 after reset"
            severity error;

        report "All reg_file tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;
