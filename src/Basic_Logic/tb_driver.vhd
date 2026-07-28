-- Testbench for Driver (tri-state buffer with enable, generic width)
-- Tests enable=1 (output follows input) and enable=0 (high-impedance)
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_driver is
end entity tb_driver;

architecture behavior of tb_driver is
    constant WIDTH : integer := 8;

    -- DUT signals
    signal D : std_logic_vector(WIDTH-1 downto 0);
    signal E : std_logic;
    signal Y : std_logic_vector(WIDTH-1 downto 0);

    -- Component declaration
    component Driver is
        generic (
            WIDTH : integer := 8
        );
        port (
            D : in  std_logic_vector(WIDTH-1 downto 0);
            E : in  std_logic;
            Y : out std_logic_vector(WIDTH-1 downto 0)
        );
    end component Driver;

begin
    -- Instantiate the DUT with generic
    dut : Driver
        generic map (
            WIDTH => WIDTH
        )
        port map (
            D => D,
            E => E,
            Y => Y
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- Test case 1: E=1, D=all-zeros -> Y=all-zeros
        E <= '1'; D <= (others => '0');
        wait for 10 ns;
        assert Y = "00000000"
            report "Test 1 FAILED: E=1 D=all-zeros, expected Y=all-zeros"
            severity error;

        -- Test case 2: E=1, D=all-ones -> Y=all-ones
        E <= '1'; D <= (others => '1');
        wait for 10 ns;
        assert Y = "11111111"
            report "Test 2 FAILED: E=1 D=all-ones, expected Y=all-ones"
            severity error;

        -- Test case 3: E=1, D=10101010 -> Y=10101010
        E <= '1'; D <= "10101010";
        wait for 10 ns;
        assert Y = "10101010"
            report "Test 3 FAILED: E=1 D=10101010, expected Y=10101010"
            severity error;

        -- Test case 4: E=0, D=10101010 -> Y=all-Z (high-impedance)
        E <= '0'; D <= "10101010";
        wait for 10 ns;
        assert Y = "ZZZZZZZZ"
            report "Test 4 FAILED: E=0 D=10101010, expected Y=all-Z"
            severity error;

        -- Test case 5: E=0, D=all-ones -> Y=all-Z (high-impedance)
        E <= '0'; D <= (others => '1');
        wait for 10 ns;
        assert Y = "ZZZZZZZZ"
            report "Test 5 FAILED: E=0 D=all-ones, expected Y=all-Z"
            severity error;

        -- Test case 6: E=1, D=11001100 -> Y=11001100 (re-enable)
        E <= '1'; D <= "11001100";
        wait for 10 ns;
        assert Y = "11001100"
            report "Test 6 FAILED: E=1 D=11001100, expected Y=11001100"
            severity error;

        report "All Driver tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;
