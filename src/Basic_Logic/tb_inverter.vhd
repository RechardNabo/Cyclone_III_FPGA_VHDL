-- Testbench for Inverter (generic-width bus inverter)
-- Tests multiple bus patterns including all-zeros, all-ones, and mixed values
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_inverter is
end entity tb_inverter;

architecture behavior of tb_inverter is
    constant WIDTH : integer := 8;

    -- DUT signals
    signal A : std_logic_vector(WIDTH-1 downto 0);
    signal Y : std_logic_vector(WIDTH-1 downto 0);

    -- Component declaration
    component Inverter is
        generic (
            WIDTH : integer := 8
        );
        port (
            A : in  std_logic_vector(WIDTH-1 downto 0);
            Y : out std_logic_vector(WIDTH-1 downto 0)
        );
    end component Inverter;

begin
    -- Instantiate the DUT with generic
    dut : Inverter
        generic map (
            WIDTH => WIDTH
        )
        port map (
            A => A,
            Y => Y
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- Test case 1: All zeros -> all ones
        A <= (others => '0');
        wait for 10 ns;
        assert Y = "11111111"
            report "Test 1 FAILED: A=all-zeros, expected Y=all-ones"
            severity error;

        -- Test case 2: All ones -> all zeros
        A <= (others => '1');
        wait for 10 ns;
        assert Y = "00000000"
            report "Test 2 FAILED: A=all-ones, expected Y=all-zeros"
            severity error;

        -- Test case 3: Alternating pattern 10101010 -> 01010101
        A <= "10101010";
        wait for 10 ns;
        assert Y = "01010101"
            report "Test 3 FAILED: A=10101010, expected Y=01010101"
            severity error;

        -- Test case 4: Alternating pattern 01010101 -> 10101010
        A <= "01010101";
        wait for 10 ns;
        assert Y = "10101010"
            report "Test 4 FAILED: A=01010101, expected Y=10101010"
            severity error;

        -- Test case 5: Single bit set 00000001 -> 11111110
        A <= "00000001";
        wait for 10 ns;
        assert Y = "11111110"
            report "Test 5 FAILED: A=00000001, expected Y=11111110"
            severity error;

        -- Test case 6: Mixed value 11001100 -> 00110011
        A <= "11001100";
        wait for 10 ns;
        assert Y = "00110011"
            report "Test 6 FAILED: A=11001100, expected Y=00110011"
            severity error;

        report "All Inverter tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;
