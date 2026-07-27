-- Testbench for shift_register (8-bit shift register with 4 modes)
-- Tests SISO, SIPO, PISO, PIPO modes and async reset
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_shift_register is
end entity tb_shift_register;

architecture behavior of tb_shift_register is
    -- DUT signals
    signal clk     : std_logic := '0';
    signal reset   : std_logic := '0';
    signal mode    : std_logic_vector(1 downto 0) := "00";
    signal ser_in  : std_logic := '0';
    signal par_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal ser_out : std_logic;
    signal par_out : std_logic_vector(7 downto 0);

    -- Component declaration
    component shift_register is
        port (
            clk     : in  std_logic;
            reset   : in  std_logic;
            mode    : in  std_logic_vector(1 downto 0);
            ser_in  : in  std_logic;
            par_in  : in  std_logic_vector(7 downto 0);
            ser_out : out std_logic;
            par_out : out std_logic_vector(7 downto 0)
        );
    end component shift_register;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin
    -- Instantiate the DUT
    dut : shift_register
        port map (
            clk     => clk,
            reset   => reset,
            mode    => mode,
            ser_in  => ser_in,
            par_in  => par_in,
            ser_out => ser_out,
            par_out => par_out
        );

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process clk_proc;

    -- Stimulus process
    stim_proc : process
    begin
        -- Test case 1: Async reset -> par_out = 0x00, ser_out = 0
        reset <= '1';
        mode <= "00"; ser_in <= '1'; par_in <= "11111111";
        wait for 5 ns;
        assert par_out = "00000000"
            report "Test 1 FAILED: reset, expected par_out=00000000"
            severity error;
        assert ser_out = '0'
            report "Test 1 FAILED: reset, expected ser_out=0"
            severity error;

        -- Test case 2: PIPO mode (mode=11) - load parallel data 0xA5
        reset <= '0';
        mode <= "11"; ser_in <= '0'; par_in <= "10100101";
        wait until rising_edge(clk);
        wait for 5 ns;
        assert par_out = "10100101"
            report "Test 2 FAILED: PIPO load 10100101, expected par_out=10100101"
            severity error;

        -- Test case 3: SIPO mode (mode=01) - shift in serial bits
        -- After PIPO load, reg=10100101. Shift right with ser_in=0
        -- After 1 shift: reg=01010010, ser_out(reg(0))=0
        mode <= "01"; ser_in <= '0';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert par_out = "01010010"
            report "Test 3 FAILED: SIPO shift 1, expected par_out=01010010"
            severity error;
        assert ser_out = '0'
            report "Test 3 FAILED: SIPO shift 1, expected ser_out=0"
            severity error;

        -- Test case 4: SIPO mode - shift in ser_in=1
        -- reg=01010010 -> shift right with 1: reg=10101001, ser_out=1
        mode <= "01"; ser_in <= '1';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert par_out = "10101001"
            report "Test 4 FAILED: SIPO shift 2, expected par_out=10101001"
            severity error;
        assert ser_out = '1'
            report "Test 4 FAILED: SIPO shift 2, expected ser_out=1"
            severity error;

        -- Test case 5: SISO mode (mode=00) - shift right with ser_in=0
        -- reg=10101001 -> shift right with 0: reg=01010100, ser_out=0
        mode <= "00"; ser_in <= '0';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert par_out = "01010100"
            report "Test 5 FAILED: SISO shift, expected par_out=01010100"
            severity error;
        assert ser_out = '0'
            report "Test 5 FAILED: SISO shift, expected ser_out=0"
            severity error;

        -- Test case 6: PISO mode (mode=10) - shift right (same as SISO/SIPO)
        -- reg=01010100 -> shift right with ser_in=1: reg=10101010, ser_out=0
        mode <= "10"; ser_in <= '1';
        wait until rising_edge(clk);
        wait for 5 ns;
        assert par_out = "10101010"
            report "Test 6 FAILED: PISO shift, expected par_out=10101010"
            severity error;
        assert ser_out = '0'
            report "Test 6 FAILED: PISO shift, expected ser_out=0"
            severity error;

        -- Test case 7: Async reset during operation
        reset <= '1';
        mode <= "11"; par_in <= "11111111";
        wait for 5 ns;
        assert par_out = "00000000"
            report "Test 7 FAILED: async reset, expected par_out=00000000"
            severity error;

        report "All shift_register tests passed." severity note;
        assert false report "Testbench complete" severity failure;
    end process stim_proc;

end architecture behavior;
