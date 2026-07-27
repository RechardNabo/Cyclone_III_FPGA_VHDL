-- ============================================================================
-- Testbench for 3-to-8 Decoder with Enable
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_decoder_3to8 is
end entity tb_decoder_3to8;

architecture behavioral of tb_decoder_3to8 is
    signal Address : std_logic_vector(2 downto 0);
    signal Enable  : std_logic;
    signal Outputs : std_logic_vector(7 downto 0);
begin
    -- Instantiate the DUT
    DUT : entity work.decoder_3to8
        port map (
            Address => Address,
            Enable  => Enable,
            Outputs => Outputs
        );

    -- Stimulus process
    process
    begin
        -- Test 1: Enable=0, all outputs should be 0
        Address <= "000";
        Enable  <= '0';
        wait for 10 ns;
        assert Outputs = "00000000"
            report "Test 1 FAILED: Enable=0 should give all zeros"
            severity error;

        -- Test 2: Enable=1, Address=0 -> bit 0 high
        Address <= "000";
        Enable  <= '1';
        wait for 10 ns;
        assert Outputs = "00000001"
            report "Test 2 FAILED: Address=0 should give bit 0 high"
            severity error;

        -- Test 3: Enable=1, Address=3 -> bit 3 high
        Address <= "011";
        Enable  <= '1';
        wait for 10 ns;
        assert Outputs = "00001000"
            report "Test 3 FAILED: Address=3 should give bit 3 high"
            severity error;

        -- Test 4: Enable=1, Address=7 -> bit 7 high
        Address <= "111";
        Enable  <= '1';
        wait for 10 ns;
        assert Outputs = "10000000"
            report "Test 4 FAILED: Address=7 should give bit 7 high"
            severity error;

        -- Test 5: Enable=1, Address=5 -> bit 5 high
        Address <= "101";
        Enable  <= '1';
        wait for 10 ns;
        assert Outputs = "00100000"
            report "Test 5 FAILED: Address=5 should give bit 5 high"
            severity error;

        -- Test 6: Disable again to verify
        Address <= "100";
        Enable  <= '0';
        wait for 10 ns;
        assert Outputs = "00000000"
            report "Test 6 FAILED: Enable=0 should give all zeros regardless of address"
            severity error;

        report "All decoder_3to8 tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;
