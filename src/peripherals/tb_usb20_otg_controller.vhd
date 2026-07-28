--------------------------------------------------------------------------------
-- tb_usb20_otg_controller : Testbench for USB 2.0 OTG controller
-- Tests AHB-Lite register read/write for CTRL, DEV_ADDR, HOST_ADDR registers
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_usb20_otg_controller is
end entity tb_usb20_otg_controller;

architecture sim of tb_usb20_otg_controller is
    signal HCLK      : std_logic := '0';
    signal HRESETn   : std_logic := '0';
    signal HSEL      : std_logic := '0';
    signal HWRITE    : std_logic := '0';
    signal HREADY    : std_logic := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;
    signal usb_dp    : std_logic;
    signal usb_dm    : std_logic;
    signal usb_id    : std_logic := '1';
    signal usb_vbus  : std_logic := '0';
    signal usb_irq   : std_logic;
    signal pass : boolean := true;
begin
    HCLK    <= not HCLK after 10 ns;
    HRESETn <= '0', '1' after 100 ns;

    DUT : entity work.usb20_otg_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            usb_dp => usb_dp, usb_dm => usb_dm, usb_id => usb_id,
            usb_vbus => usb_vbus, usb_irq => usb_irq
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);

        procedure wr(a : std_logic_vector(31 downto 0);
                     d : std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '1'; HADDR <= a; HWDATA <= d;
            HTRANS <= "10"; HSIZE <= "010";
            wait until rising_edge(HCLK);
            HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
            wait until rising_edge(HCLK);
        end procedure;

        procedure rd(a : std_logic_vector(31 downto 0);
                     variable rv : out std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '0'; HADDR <= a;
            HTRANS <= "10"; HSIZE <= "010";
            wait until rising_edge(HCLK);
            wait for 1 ns;
            rv := HRDATA;
            HSEL <= '0'; HTRANS <= "00";
            wait until rising_edge(HCLK);
        end procedure;
    begin
        wait until HRESETn = '1';
        wait for 40 ns;

        -- Test 1: Write and readback CTRL (0x00)
        -- Bits: enable=1, host_mode=1 => 0x05
        wr(x"00000000", x"00000005");
        rd(x"00000000", rdata);
        if rdata = x"00000005" then
            report "CTRL PASS" severity note;
        else
            report "CTRL FAIL" severity error;
            pass <= false;
        end if;

        -- Test 2: Write and readback DEV_ADDR (0x08)
        -- Device address=5, enable=1 => 0x85
        wr(x"00000008", x"00000085");
        rd(x"00000008", rdata);
        if rdata = x"00000085" then
            report "DEV_ADDR PASS" severity note;
        else
            report "DEV_ADDR FAIL" severity error;
            pass <= false;
        end if;

        -- Test 3: Write and readback HOST_ADDR (0x18)
        wr(x"00000018", x"00000003");
        rd(x"00000018", rdata);
        if rdata = x"00000003" then
            report "HOST_ADDR PASS" severity note;
        else
            report "HOST_ADDR FAIL" severity error;
            pass <= false;
        end if;

        -- Test 4: Write and readback EP_CFG (0x0C)
        wr(x"0000000C", x"00020040");
        rd(x"0000000C", rdata);
        if rdata = x"00020040" then
            report "EP_CFG PASS" severity note;
        else
            report "EP_CFG FAIL" severity error;
            pass <= false;
        end if;

        if pass then
            report "PASS" severity note;
        else
            report "FAIL" severity error;
        end if;
        std.env.finish;
    end process;
end architecture sim;
