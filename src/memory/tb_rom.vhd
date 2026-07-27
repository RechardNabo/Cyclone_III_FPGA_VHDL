-- ============================================================================
-- Testbench for ROM
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rom is
end entity tb_rom;

architecture behavioral of tb_rom is
    signal clk  : std_logic := '0';
    signal addr : std_logic_vector(3 downto 0);
    signal dout : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 10 ns;
begin
    -- Instantiate the DUT with default generics (WIDTH=8, DEPTH=16)
    DUT : entity work.rom
        generic map (
            WIDTH => 8,
            DEPTH => 16
        )
        port map (
            clk  => clk,
            addr => addr,
            dout => dout
        );

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- Stimulus process
    process
    begin
        -- Test 1: Read address 0 -> should be 0x00
        addr <= "0000";
        wait for CLK_PERIOD;
        assert dout = x"00"
            report "Test 1 FAILED: addr 0 should be 0x00"
            severity error;

        -- Test 2: Read address 1 -> should be 0x01
        addr <= "0001";
        wait for CLK_PERIOD;
        assert dout = x"01"
            report "Test 2 FAILED: addr 1 should be 0x01"
            severity error;

        -- Test 3: Read address 5 -> should be 0x05
        addr <= "0101";
        wait for CLK_PERIOD;
        assert dout = x"05"
            report "Test 3 FAILED: addr 5 should be 0x05"
            severity error;

        -- Test 4: Read address 10 -> should be 0x0A
        addr <= "1010";
        wait for CLK_PERIOD;
        assert dout = x"0A"
            report "Test 4 FAILED: addr 10 should be 0x0A"
            severity error;

        -- Test 5: Read address 15 -> should be 0x0F
        addr <= "1111";
        wait for CLK_PERIOD;
        assert dout = x"0F"
            report "Test 5 FAILED: addr 15 should be 0x0F"
            severity error;

        -- Test 6: Read address 7 -> should be 0x07
        addr <= "0111";
        wait for CLK_PERIOD;
        assert dout = x"07"
            report "Test 6 FAILED: addr 7 should be 0x07"
            severity error;

        report "All rom tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;
