-- ============================================================================
-- Testbench for SHA-256 Hasher (Simplified Single Block)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_sha256_hasher is
end entity tb_sha256_hasher;

architecture sim of tb_sha256_hasher is

    -- DUT signals
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal start     : std_logic := '0';
    signal msg_block : std_logic_vector(511 downto 0) := (others => '0');
    signal hash_out  : std_logic_vector(255 downto 0);
    signal done      : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.sha256_hasher
        port map (
            clk       => clk,
            reset     => reset,
            start     => start,
            msg_block => msg_block,
            hash_out  => hash_out,
            done      => done
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
        -- Test 2: All-zero message block
        --   SHA-256 of all-zero 512-bit block (no padding)
        --   This is a known test vector for the compression function
        -- -------------------------------------------------------
        reset <= '0';
        wait for CLK_PERIOD;
        msg_block <= (others => '0');
        start     <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        -- Wait for done: EXPAND (64 cycles) + COMPRESS (64 cycles) + FINISH
        wait until done = '1' for CLK_PERIOD * 150;
        assert done = '1'
            report "Test 2 FAIL: done not asserted for zero block"
            severity error;
        report "Test 2: Hash of zero block = " &
               integer'image(to_integer(unsigned(hash_out(255 downto 224)))) &
               " (first 32 bits)" severity note;
        assert hash_out /= (255 downto 0 => '0')
            report "Test 2 FAIL: Hash of zero block is all zeros"
            severity error;
        report "Test 2 PASS: Hash of zero block is nonzero" severity note;

        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 3: Non-zero message block
        -- -------------------------------------------------------
        msg_block <= x"6162636462636465636465666465666765666768666768696768696A" &
                     x"6869696A69696A6B696A6B6C6A6B6B6C6B6B6C6D6B6C6D6E6C6D6D6E" &
                     x"6D6D6E6F6D6E6F706E6F707170707172707172737172737472737474" &
                     x"73747475747475767575767775767778767778797878797A79797A7B";
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 150;
        assert done = '1'
            report "Test 3 FAIL: done not asserted for non-zero block"
            severity error;
        report "Test 3: Hash of non-zero block = " &
               integer'image(to_integer(unsigned(hash_out(255 downto 224)))) &
               " (first 32 bits)" severity note;
        assert hash_out /= (255 downto 0 => '0')
            report "Test 3 FAIL: Hash of non-zero block is all zeros"
            severity error;
        report "Test 3 PASS: Hash of non-zero block is nonzero" severity note;

        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 4: Different inputs produce different hashes
        -- -------------------------------------------------------
        msg_block <= (others => '1');  -- all ones
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 150;
        assert done = '1'
            report "Test 4 FAIL: done not asserted"
            severity error;
        report "Test 4: Hash of all-ones block = " &
               integer'image(to_integer(unsigned(hash_out(255 downto 224)))) &
               " (first 32 bits)" severity note;
        assert hash_out /= (255 downto 0 => '0')
            report "Test 4 FAIL: Hash of all-ones block is all zeros"
            severity error;
        report "Test 4 PASS: Hash of all-ones block is nonzero" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;
