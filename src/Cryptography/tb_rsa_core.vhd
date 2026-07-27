-- ============================================================================
-- Testbench for RSA Core (Simplified Modular Exponentiation)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rsa_core is
end entity tb_rsa_core;

architecture sim of tb_rsa_core is

    -- DUT signals
    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal start    : std_logic := '0';
    signal base     : std_logic_vector(15 downto 0) := (others => '0');
    signal exponent : std_logic_vector(15 downto 0) := (others => '0');
    signal modulus  : std_logic_vector(15 downto 0) := (others => '0');
    signal result   : std_logic_vector(15 downto 0);
    signal done     : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.rsa_core
        port map (
            clk      => clk,
            reset    => reset,
            start    => start,
            base     => base,
            exponent => exponent,
            modulus  => modulus,
            result   => result,
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
        -- Test 2: 3^5 mod 7 = 243 mod 7 = 5
        -- -------------------------------------------------------
        reset <= '0';
        wait for CLK_PERIOD;
        base     <= std_logic_vector(to_unsigned(3, 16));
        exponent <= std_logic_vector(to_unsigned(5, 16));
        modulus  <= std_logic_vector(to_unsigned(7, 16));
        start    <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        -- Wait for done (16 bit iterations + finish)
        wait until done = '1' for CLK_PERIOD * 30;
        assert done = '1'
            report "Test 2 FAIL: done not asserted"
            severity error;
        report "Test 2: 3^5 mod 7 = " & integer'image(to_integer(unsigned(result))) &
               " (expected 5)" severity note;
        assert to_integer(unsigned(result)) = 5
            report "Test 2 FAIL: 3^5 mod 7 != 5"
            severity error;
        report "Test 2 PASS: 3^5 mod 7 = 5" severity note;

        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 3: 2^10 mod 1000 = 1024 mod 1000 = 24
        -- -------------------------------------------------------
        base     <= std_logic_vector(to_unsigned(2, 16));
        exponent <= std_logic_vector(to_unsigned(10, 16));
        modulus  <= std_logic_vector(to_unsigned(1000, 16));
        start    <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 30;
        assert done = '1'
            report "Test 3 FAIL: done not asserted"
            severity error;
        report "Test 3: 2^10 mod 1000 = " & integer'image(to_integer(unsigned(result))) &
               " (expected 24)" severity note;
        assert to_integer(unsigned(result)) = 24
            report "Test 3 FAIL: 2^10 mod 1000 != 24"
            severity error;
        report "Test 3 PASS: 2^10 mod 1000 = 24" severity note;

        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 4: 7^3 mod 11 = 343 mod 11 = 2
        -- -------------------------------------------------------
        base     <= std_logic_vector(to_unsigned(7, 16));
        exponent <= std_logic_vector(to_unsigned(3, 16));
        modulus  <= std_logic_vector(to_unsigned(11, 16));
        start    <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        wait until done = '1' for CLK_PERIOD * 30;
        assert done = '1'
            report "Test 4 FAIL: done not asserted"
            severity error;
        report "Test 4: 7^3 mod 11 = " & integer'image(to_integer(unsigned(result))) &
               " (expected 2)" severity note;
        assert to_integer(unsigned(result)) = 2
            report "Test 4 FAIL: 7^3 mod 11 != 2"
            severity error;
        report "Test 4 PASS: 7^3 mod 11 = 2" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;
