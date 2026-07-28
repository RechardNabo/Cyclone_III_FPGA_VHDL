-- ================================================================================
-- tb_itm_controller : Testbench for ITM stimulus port write
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_itm_controller is
end entity tb_itm_controller;

architecture sim of tb_itm_controller is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal clk       : std_logic := '0';
    signal resetn    : std_logic := '0';
    signal hsel      : std_logic := '0';
    signal hwrite    : std_logic := '0';
    signal hready    : std_logic := '1';
    signal htrans    : std_logic_vector(1 downto 0) := "00";
    signal haddr     : std_logic_vector(31 downto 0) := (others => '0');
    signal hwdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal hrdata    : std_logic_vector(31 downto 0);
    signal hresp     : std_logic;
    signal hreadyout : std_logic;
    signal itm_swv   : std_logic;
    signal itm_irq   : std_logic;

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

    dut : entity work.itm_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            itm_swv => itm_swv, itm_irq => itm_irq
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write ITM_CTRL to enable ITM + SWO (bit0=1, bit3=1)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000088", x"00000009");
        wait until rising_edge(clk);

        -- Test 2: Read ITM_CTRL back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000088", hrdata, rdata);
        assert rdata = x"00000009"
            report "FAIL: ITM_CTRL readback mismatch"
            severity error;
        if rdata = x"00000009" then
            report "PASS: ITM_CTRL readback" severity note;
        end if;

        -- Test 3: Write TER to enable port 0
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000080", x"00000001");
        wait until rising_edge(clk);

        -- Test 4: Read TER back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000080", hrdata, rdata);
        assert rdata = x"00000001"
            report "FAIL: TER readback mismatch"
            severity error;
        if rdata = x"00000001" then
            report "PASS: TER readback" severity note;
        end if;

        -- Test 5: Write STIM0 (port 0)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000000", x"CAFEBABE");
        wait for 200 ns;

        -- Test 6: Check IRQ asserted (stimulus valid)
        assert itm_irq = '1'
            report "FAIL: ITM IRQ not asserted after stimulus write"
            severity error;
        if itm_irq = '1' then
            report "PASS: ITM stimulus port write triggered IRQ" severity note;
        end if;

        report "tb_itm_controller DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
