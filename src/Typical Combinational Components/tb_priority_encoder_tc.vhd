-- ============================================================================
-- Testbench for 8-to-3 Priority Encoder (Typical Combinational Components)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_priority_encoder_tc is
end entity tb_priority_encoder_tc;

architecture behavioral of tb_priority_encoder_tc is
    signal Requests : std_logic_vector(7 downto 0);
    signal Code     : std_logic_vector(2 downto 0);
    signal Valid    : std_logic;
begin
    -- Instantiate the DUT
    DUT : entity work.priority_encoder
        port map (
            Requests => Requests,
            Code     => Code,
            Valid    => Valid
        );

    -- Stimulus process
    process
    begin
        -- Test 1: No requests -> Valid=0, Code=000
        Requests <= "00000000";
        wait for 10 ns;
        assert Code = "000"
            report "Test 1 FAILED: no requests should give Code=000"
            severity error;
        assert Valid = '0'
            report "Test 1 FAILED: no requests should give Valid=0"
            severity error;

        -- Test 2: Only bit 0 active -> Code=000, Valid=1
        Requests <= "00000001";
        wait for 10 ns;
        assert Code = "000"
            report "Test 2 FAILED: bit 0 should give Code=000"
            severity error;
        assert Valid = '1'
            report "Test 2 FAILED: bit 0 should give Valid=1"
            severity error;

        -- Test 3: Only bit 7 active -> Code=111, Valid=1
        Requests <= "10000000";
        wait for 10 ns;
        assert Code = "111"
            report "Test 3 FAILED: bit 7 should give Code=111"
            severity error;
        assert Valid = '1'
            report "Test 3 FAILED: bit 7 should give Valid=1"
            severity error;

        -- Test 4: Multiple requests, bits 1 and 6 -> Code=110 (priority 6)
        Requests <= "01000010";
        wait for 10 ns;
        assert Code = "110"
            report "Test 4 FAILED: bits 1,6 should give Code=110"
            severity error;
        assert Valid = '1'
            report "Test 4 FAILED: bits 1,6 should give Valid=1"
            severity error;

        -- Test 5: All requests active -> Code=111 (highest priority)
        Requests <= "11111111";
        wait for 10 ns;
        assert Code = "111"
            report "Test 5 FAILED: all active should give Code=111"
            severity error;
        assert Valid = '1'
            report "Test 5 FAILED: all active should give Valid=1"
            severity error;

        -- Test 6: Only bit 3 active -> Code=011, Valid=1
        Requests <= "00001000";
        wait for 10 ns;
        assert Code = "011"
            report "Test 6 FAILED: bit 3 should give Code=011"
            severity error;
        assert Valid = '1'
            report "Test 6 FAILED: bit 3 should give Valid=1"
            severity error;

        report "All priority_encoder_tc tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;
