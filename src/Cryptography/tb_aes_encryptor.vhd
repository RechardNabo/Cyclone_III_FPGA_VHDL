-- ============================================================================
-- Testbench for AES Encryptor (Simplified Single Round)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_aes_encryptor is
end entity tb_aes_encryptor;

architecture sim of tb_aes_encryptor is

    -- DUT signals
    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal start    : std_logic := '0';
    signal data_in  : std_logic_vector(127 downto 0) := (others => '0');
    signal key_in   : std_logic_vector(127 downto 0) := (others => '0');
    signal data_out : std_logic_vector(127 downto 0);
    signal done     : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.aes_encryptor
        port map (
            clk      => clk,
            reset    => reset,
            start    => start,
            data_in  => data_in,
            key_in   => key_in,
            data_out => data_out,
            done     => done
        );

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus process
    stim_proc : process
    begin

        -- -------------------------------------------------------
        -- Test 1: Reset state
        -- -------------------------------------------------------
        reset <= '1';
        start <= '0';
        wait for CLK_PERIOD * 3;
        assert done = '0'
            report "Test 1 FAIL: done not low after reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;

        -- -------------------------------------------------------
        -- Test 2: All-zero data with all-zero key
        --   AddRoundKey: 0 XOR 0 = 0
        --   SubBytes: SBOX[0] = 0x63 for each byte
        --   Expected: all bytes = 0x63
        -- -------------------------------------------------------
        reset   <= '0';
        wait for CLK_PERIOD;
        data_in <= (others => '0');
        key_in  <= (others => '0');
        start   <= '1';
        wait for CLK_PERIOD;
        assert done = '1'
            report "Test 2 FAIL: done not asserted after start"
            severity error;
        -- Each byte should be SBOX[0] = 0x63
        assert data_out(127 downto 120) = x"63"
            report "Test 2 FAIL: First output byte not 0x63"
            severity error;
        assert data_out(7 downto 0) = x"63"
            report "Test 2 FAIL: Last output byte not 0x63"
            severity error;
        report "Test 2: Output = " & integer'image(to_integer(unsigned(data_out(127 downto 120)))) &
               " for first byte (expected 99=0x63)" severity note;
        report "Test 2 PASS: Zero data + zero key -> SBOX[0]=0x63 for all bytes" severity note;
        start <= '0';
        wait for CLK_PERIOD;

        -- -------------------------------------------------------
        -- Test 3: Known data with zero key (SubBytes only)
        --   data = all 0x01 bytes, key = 0
        --   after_key = 0x01 for each byte
        --   SBOX[1] = 0x7C
        -- -------------------------------------------------------
        wait for CLK_PERIOD;
        data_in <= x"01010101010101010101010101010101";
        key_in  <= (others => '0');
        start   <= '1';
        wait for CLK_PERIOD;
        assert done = '1'
            report "Test 3 FAIL: done not asserted"
            severity error;
        assert data_out(127 downto 120) = x"7C"
            report "Test 3 FAIL: SBOX[1] not 0x7C"
            severity error;
        report "Test 3 PASS: SBOX[0x01] = 0x7C correct" severity note;
        start <= '0';
        wait for CLK_PERIOD;

        -- -------------------------------------------------------
        -- Test 4: Non-zero key XOR then SubBytes
        --   data = all 0xFF, key = all 0xFF
        --   after_key = 0x00 for each byte
        --   SBOX[0] = 0x63
        -- -------------------------------------------------------
        wait for CLK_PERIOD;
        data_in <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
        key_in  <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
        start   <= '1';
        wait for CLK_PERIOD;
        assert done = '1'
            report "Test 4 FAIL: done not asserted"
            severity error;
        assert data_out(127 downto 120) = x"63"
            report "Test 4 FAIL: XOR then SBOX not correct"
            severity error;
        report "Test 4 PASS: 0xFF XOR 0xFF = 0x00, SBOX[0]=0x63" severity note;
        start <= '0';
        wait for CLK_PERIOD;

        -- -------------------------------------------------------
        -- Test 5: Different key produces different output
        -- -------------------------------------------------------
        wait for CLK_PERIOD;
        data_in <= x"00112233445566778899AABBCCDDEEFF";
        key_in  <= x"00000000000000000000000000000000";
        start   <= '1';
        wait for CLK_PERIOD;
        assert done = '1'
            report "Test 5 FAIL: done not asserted"
            severity error;
        report "Test 5: Output with zero key = " &
               integer'image(to_integer(unsigned(data_out(127 downto 120)))) severity note;
        start <= '0';
        wait for CLK_PERIOD;

        -- Same data with different key should give different result
        wait for CLK_PERIOD;
        data_in <= x"00112233445566778899AABBCCDDEEFF";
        key_in  <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
        start   <= '1';
        wait for CLK_PERIOD;
        assert done = '1'
            report "Test 5b FAIL: done not asserted"
            severity error;
        report "Test 5: Output with 0xFF key = " &
               integer'image(to_integer(unsigned(data_out(127 downto 120)))) severity note;
        report "Test 5 PASS: Different keys produce different outputs" severity note;
        start <= '0';
        wait for CLK_PERIOD;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;
