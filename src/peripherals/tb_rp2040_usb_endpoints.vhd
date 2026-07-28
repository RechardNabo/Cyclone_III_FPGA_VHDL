-- ================================================================================
-- tb_rp2040_usb_endpoints : Testbench for USB endpoint config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rp2040_usb_endpoints is
end entity tb_rp2040_usb_endpoints;

architecture sim of tb_rp2040_usb_endpoints is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz
    constant NUM_EP : integer := 16;

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
    signal usb_dp    : std_logic := 'Z';
    signal usb_dm    : std_logic := 'Z';
    signal usb_irq   : std_logic;

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

    dut : entity work.rp2040_usb_endpoints
        generic map (NUM_ENDPOINTS => NUM_EP)
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            usb_dp => usb_dp, usb_dm => usb_dm, usb_irq => usb_irq
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write EP_CTRL0 (enable=1, type=bulk=2, dir=IN=1, buf_size=64)
        -- bit0=enable, bits[3:2]=type, bit4=dir, bits[14:8]=buf_size
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000000", x"00004819");
        wait until rising_edge(clk);

        -- Test 2: Read EP_CTRL0 back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000000", hrdata, rdata);
        assert rdata(0) = '1'
            report "FAIL: USB EP_CTRL0 enable not set"
            severity error;
        if rdata(0) = '1' then
            report "PASS: USB EP_CTRL0 enable" severity note;
        end if;

        -- Test 3: Write USB_ADDR (device address = 5)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"000000C0", x"00000005");
        wait until rising_edge(clk);

        -- Test 4: Read USB_ADDR back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"000000C0", hrdata, rdata);
        assert rdata(6 downto 0) = "0000101"
            report "FAIL: USB_ADDR readback mismatch"
            severity error;
        if rdata(6 downto 0) = "0000101" then
            report "PASS: USB_ADDR readback" severity note;
        end if;

        -- Test 5: Write EP_BUF_CTRL0
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000040", x"00010001");
        wait until rising_edge(clk);

        -- Test 6: Read EP_BUF_CTRL0 back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000040", hrdata, rdata);
        assert rdata(0) = '1'
            report "FAIL: USB EP_BUF_CTRL0 buf0_full not set"
            severity error;
        if rdata(0) = '1' then
            report "PASS: USB EP_BUF_CTRL0 config" severity note;
        end if;

        report "tb_rp2040_usb_endpoints DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
