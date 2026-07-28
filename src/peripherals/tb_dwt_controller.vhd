-- ================================================================================
-- tb_dwt_controller : Testbench for DWT cycle counter and watchpoint unit
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_dwt_controller is
end entity tb_dwt_controller;

architecture sim of tb_dwt_controller is
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

    signal cpu_daddr  : std_logic_vector(31 downto 0) := (others => '0');
    signal cpu_dwrite : std_logic := '0';
    signal dwt_cmp    : std_logic_vector(3 downto 0);
    signal dwt_irq    : std_logic;

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
        hsel   <= '1';
        hwrite <= '1';
        htrans <= "10";
        haddr  <= addr;
        hwdata <= data;
        wait until rising_edge(clk);
        hsel   <= '0';
        hwrite <= '0';
        htrans <= "00";
    end procedure;

    procedure ahb_read(
        signal clk    : in std_logic;
        signal hsel   : out std_logic;
        signal hwrite : out std_logic;
        signal htrans : out std_logic_vector(1 downto 0);
        signal haddr  : out std_logic_vector(31 downto 0);
        signal hrdata : in std_logic_vector(31 downto 0);
        variable rdata: out std_logic_vector(31 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        hsel   <= '1';
        hwrite <= '0';
        htrans <= "10";
        haddr  <= (others => '0');
        wait until rising_edge(clk);
        rdata  := hrdata;
        hsel   <= '0';
        htrans <= "00";
    end procedure;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.dwt_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            cpu_daddr => cpu_daddr, cpu_dwrite => cpu_dwrite,
            dwt_cmp => dwt_cmp, dwt_irq => dwt_irq
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        -- Reset
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write CTRL to enable CYCCNT (bit0=1)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000000", x"00000001");
        wait for 200 ns;

        -- Test 2: Read CYCCNT, should be > 0
        ahb_read(clk, hsel, hwrite, htrans, haddr, hrdata, rdata);
        assert rdata /= x"00000000"
            report "FAIL: CYCCNT not counting after CTRL enable"
            severity error;
        if rdata /= x"00000000" then
            report "PASS: DWT CYCCNT counting" severity note;
        end if;

        -- Test 3: Write COMP0 address
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000020", x"DEADBEEF");
        wait until rising_edge(clk);

        -- Test 4: Read COMP0 back
        ahb_read(clk, hsel, hwrite, htrans, haddr, hrdata, rdata);
        assert rdata = x"DEADBEEF"
            report "FAIL: COMP0 readback mismatch"
            severity error;
        if rdata = x"DEADBEEF" then
            report "PASS: DWT COMP0 readback" severity note;
        end if;

        -- Test 5: Write FUNCTION0 to enable comparator
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000028", x"00000001");
        wait until rising_edge(clk);

        -- Drive matching CPU data address
        cpu_daddr <= x"DEADBEEF";
        wait for 100 ns;
        assert dwt_cmp(0) = '1'
            report "FAIL: DWT comparator 0 did not match"
            severity error;
        if dwt_cmp(0) = '1' then
            report "PASS: DWT watchpoint match" severity note;
        end if;

        report "tb_dwt_controller DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
