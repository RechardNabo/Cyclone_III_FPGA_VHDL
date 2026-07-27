-- Testbench for decoder_2to4
-- Tests all 4 address combinations with enable=1, plus disabled state
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_decoder_2to4 is
end entity tb_decoder_2to4;

architecture behavior of tb_decoder_2to4 is
    -- DUT signals
    signal A : std_logic;   -- address bit 0 (LSB)
    signal B : std_logic;   -- address bit 1 (MSB)
    signal E : std_logic;   -- enable
    signal Y : std_logic_vector(3 downto 0);

    -- Component declaration
    component decoder_2to4 is
        port (
            A : in  std_logic;
            B : in  std_logic;
            E : in  std_logic;
            Y : out std_logic_vector(3 downto 0)
        );
    end component decoder_2to4;

begin
    -- Instantiate the DUT
    dut : decoder_2to4
        port map (
            A => A,
            B => B,
            E => E,
            Y => Y
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- Test case 1: E=1, A=0, B=0 -> Y=1110 (output 0 active-low)
        E <= '1'; A <= '0'; B <= '0';
        wait for 10 ns;
        assert Y = "1110"
            report "Test 1 FAILED: E=1 A=0 B=0, expected Y=1110, got Y=" & integer'image(to_integer(unsigned(Y)))
            severity error;

        -- Test case 2: E=1, A=1, B=0 -> Y=1101 (output 1 active-low)
        E <= '1'; A <= '1'; B <= '0';
        wait for 10 ns;
        assert Y = "1101"
            report "Test 2 FAILED: E=1 A=1 B=0, expected Y=1101"
            severity error;

        -- Test case 3: E=1, A=0, B=1 -> Y=1011 (output 2 active-low)
        E <= '1'; A <= '0'; B <= '1';
        wait for 10 ns;
        assert Y = "1011"
            report "Test 3 FAILED: E=1 A=0 B=1, expected Y=1011"
            severity error;

        -- Test case 4: E=1, A=1, B=1 -> Y=0111 (output 3 active-low)
        E <= '1'; A <= '1'; B <= '1';
        wait for 10 ns;
        assert Y = "0111"
            report "Test 4 FAILED: E=1 A=1 B=1, expected Y=0111"
            severity error;

        -- Test case 5: E=0, A=0, B=0 -> Y=1111 (disabled, all high)
        E <= '0'; A <= '0'; B <= '0';
        wait for 10 ns;
        assert Y = "1111"
            report "Test 5 FAILED: E=0 A=0 B=0, expected Y=1111"
            severity error;

        -- Test case 6: E=0, A=1, B=1 -> Y=1111 (disabled, all high)
        E <= '0'; A <= '1'; B <= '1';
        wait for 10 ns;
        assert Y = "1111"
            report "Test 6 FAILED: E=0 A=1 B=1, expected Y=1111"
            severity error;

        report "All decoder_2to4 tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;
