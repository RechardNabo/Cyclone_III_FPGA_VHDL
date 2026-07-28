-- ================================================================================
-- tb_pio_controller : Testbench for PIO instruction load
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_pio_controller is
end entity tb_pio_controller;

architecture sim of tb_pio_controller is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal clk       : std_logic := '0';
    signal resetn    : std_logic := '0';
    signal hsel      : std_logic := '0';
    signal hwrite    : std_logic := '0';
    signal hready    : std_logic := '1';
    signal htrans    : std_logic_vector(1 downto 0) := "00";
    signal hsize     : std_logic_vector(2 downto 0) := "010";
    signal haddr     : std_logic_vector(31 downto 0) := (others => '0');
    signal hwdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal hrdata    : std_logic_vector(31 downto 0);
    signal hresp     : std_logic;
    signal hreadyout : std_logic;
    signal pio_pins_out : std_logic_vector(31 downto 0);
    signal pio_pins_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal pio_pins_oe  : std_logic_vector(31 downto 0);
    signal pio_irq_out  : std_logic;

    procedure ahb_write(
        signal clk    : in std_logic;
        signal hsel   : out std_logic;
        signal hwrite : out std_logic;
        signal htrans : out std_logic_vector(1 downto 0);
        signal haddr  : out std_logic_vector(31 downto 0);
        signal hwdata : out std_logic_vector(31 downto 0);
        constant addr : in std_logic_vector(31 downto 0);
        constant data : in std_logic_vector(31 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        hsel <= '1'; hwrite <= '1'; htrans <= "10";
        haddr <= addr; hwdata <= data;
        wait until rising_edge(clk);
        hsel <= '0'; hwrite <= '0'; htrans <= "00";
    end procedure;

    procedure ahb_read(
        signal clk    : in std_logic;
        signal hsel   : out std_logic;
        signal hwrite : out std_logic;
        signal htrans : out std_logic_vector(1 downto 0);
        signal haddr  : out std_logic_vector(31 downto 0);
        constant addr : in std_logic_vector(31 downto 0);
        signal hrdata : in std_logic_vector(31 downto 0);
        variable rdata: out std_logic_vector(31 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        hsel <= '1'; hwrite <= '0'; htrans <= "10";
        haddr <= addr;
        wait until rising_edge(clk);
        rdata := hrdata;
        hsel <= '0'; htrans <= "00";
    end procedure;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.pio_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HSIZE => hsize, HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            pio_pins_out => pio_pins_out, pio_pins_in => pio_pins_in,
            pio_pins_oe => pio_pins_oe, pio_irq_out => pio_irq_out
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write PINCTRL config
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000024", x"00050A14");
        wait until rising_edge(clk);

        -- Test 2: Read PINCTRL back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000024", hrdata, rdata);
        assert rdata = x"00050A14"
            report "FAIL: PIO PINCTRL readback mismatch"
            severity error;
        if rdata = x"00050A14" then
            report "PASS: PIO PINCTRL readback" severity note;
        end if;

        -- Test 3: Write SHIFTREG config
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000028", x"00100020");
        wait until rising_edge(clk);

        -- Test 4: Read SHIFTREG back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000028", hrdata, rdata);
        assert rdata = x"00100020"
            report "FAIL: PIO SHIFTREG readback mismatch"
            severity error;
        if rdata = x"00100020" then
            report "PASS: PIO SHIFTREG readback" severity note;
        end if;

        -- Test 5: Write INSTR_MEM (instruction load)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000020", x"0000E02A");
        wait until rising_edge(clk);

        report "PASS: PIO instruction load complete" severity note;
        report "tb_pio_controller DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
