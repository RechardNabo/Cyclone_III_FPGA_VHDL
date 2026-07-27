-- ============================================================================
-- Testbench for Synchronous FIFO
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_fifo is
end entity tb_fifo;

architecture behavioral of tb_fifo is
    signal clk      : std_logic := '0';
    signal rst      : std_logic;
    signal write_en : std_logic;
    signal read_en  : std_logic;
    signal din      : std_logic_vector(7 downto 0);
    signal dout     : std_logic_vector(7 downto 0);
    signal full     : std_logic;
    signal empty    : std_logic;

    constant CLK_PERIOD : time := 10 ns;
begin
    -- Instantiate the DUT with default generics (WIDTH=8, DEPTH=16)
    DUT : entity work.fifo
        generic map (
            WIDTH => 8,
            DEPTH => 16
        )
        port map (
            clk      => clk,
            rst      => rst,
            write_en => write_en,
            read_en  => read_en,
            din      => din,
            dout     => dout,
            full     => full,
            empty    => empty
        );

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- Stimulus process
    process
    begin
        -- Test 1: After reset, FIFO should be empty
        rst <= '1'; write_en <= '0'; read_en <= '0'; din <= x"00";
        wait for CLK_PERIOD;
        rst <= '0';
        wait for 1 ns;
        assert empty = '1'
            report "Test 1 FAILED: FIFO should be empty after reset"
            severity error;
        assert full = '0'
            report "Test 1 FAILED: FIFO should not be full after reset"
            severity error;

        -- Test 2: Write one value, FIFO should not be empty
        write_en <= '1'; din <= x"AA";
        wait for CLK_PERIOD;
        write_en <= '0';
        wait for 1 ns;
        assert empty = '0'
            report "Test 2 FAILED: FIFO should not be empty after write"
            severity error;

        -- Test 3: Read the value back, should be 0xAA
        read_en <= '1';
        wait for CLK_PERIOD;
        read_en <= '0';
        wait for 1 ns;
        assert dout = x"AA"
            report "Test 3 FAILED: read value should be 0xAA"
            severity error;
        assert empty = '1'
            report "Test 3 FAILED: FIFO should be empty after reading the one value"
            severity error;

        -- Test 4: Write 3 values and read them back in order (FIFO order)
        write_en <= '1'; din <= x"11";
        wait for CLK_PERIOD;
        din <= x"22";
        wait for CLK_PERIOD;
        din <= x"33";
        wait for CLK_PERIOD;
        write_en <= '0';
        wait for 1 ns;
        assert empty = '0'
            report "Test 4 FAILED: FIFO should not be empty after 3 writes"
            severity error;

        -- Read first value
        read_en <= '1';
        wait for CLK_PERIOD;
        read_en <= '0';
        wait for 1 ns;
        assert dout = x"11"
            report "Test 4a FAILED: first read should be 0x11"
            severity error;

        -- Read second value
        read_en <= '1';
        wait for CLK_PERIOD;
        read_en <= '0';
        wait for 1 ns;
        assert dout = x"22"
            report "Test 4b FAILED: second read should be 0x22"
            severity error;

        -- Read third value
        read_en <= '1';
        wait for CLK_PERIOD;
        read_en <= '0';
        wait for 1 ns;
        assert dout = x"33"
            report "Test 4c FAILED: third read should be 0x33"
            severity error;
        assert empty = '1'
            report "Test 4d FAILED: FIFO should be empty after reading all"
            severity error;

        -- Test 5: Fill FIFO completely (16 writes), check full flag
        write_en <= '1';
        for i in 0 to 15 loop
            din <= std_logic_vector(to_unsigned(i, 8));
            wait for CLK_PERIOD;
        end loop;
        write_en <= '0';
        wait for 1 ns;
        assert full = '1'
            report "Test 5 FAILED: FIFO should be full after 16 writes"
            severity error;

        -- Test 6: Read all 16 values and verify order
        read_en <= '1';
        for i in 0 to 15 loop
            wait for CLK_PERIOD;
            assert dout = std_logic_vector(to_unsigned(i, 8))
                report "Test 6 FAILED: FIFO read order mismatch at index " & integer'image(i)
                severity error;
        end loop;
        read_en <= '0';
        wait for 1 ns;
        assert empty = '1'
            report "Test 6 FAILED: FIFO should be empty after reading all 16"
            severity error;

        report "All fifo tests passed" severity note;
        assert false report "Testbench complete" severity failure;
    end process;
end architecture behavioral;
