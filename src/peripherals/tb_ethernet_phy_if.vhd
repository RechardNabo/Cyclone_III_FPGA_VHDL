--------------------------------------------------------------------------------
-- tb_ethernet_phy_if : Testbench for Ethernet PHY interface with MDIO
-- Tests AHB-Lite register read/write for CTRL, PHY_ADDR, PHY_DATA registers
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_ethernet_phy_if is
end entity tb_ethernet_phy_if;

architecture sim of tb_ethernet_phy_if is
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
    signal rgmii_txd    : std_logic_vector(3 downto 0);
    signal rgmii_tx_ctl : std_logic;
    signal rgmii_txc    : std_logic;
    signal rgmii_rxd    : std_logic_vector(3 downto 0) := (others => '0');
    signal rgmii_rx_ctl : std_logic := '0';
    signal rgmii_rxc    : std_logic := '0';
    signal mdc          : std_logic;
    signal mdio         : std_logic;
    signal eth_irq      : std_logic;
    signal pass : boolean := true;
begin
    HCLK    <= not HCLK after 10 ns;
    HRESETn <= '0', '1' after 100 ns;

    DUT : entity work.ethernet_phy_if
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            rgmii_txd => rgmii_txd, rgmii_tx_ctl => rgmii_tx_ctl,
            rgmii_txc => rgmii_txc, rgmii_rxd => rgmii_rxd,
            rgmii_rx_ctl => rgmii_rx_ctl, rgmii_rxc => rgmii_rxc,
            mdc => mdc, mdio => mdio, eth_irq => eth_irq
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
        -- Bits: enable=1, rgmii_mode=1 => 0x05
        wr(x"00000000", x"00000005");
        rd(x"00000000", rdata);
        if rdata = x"00000005" then
            report "CTRL PASS" severity note;
        else
            report "CTRL FAIL" severity error;
            pass <= false;
        end if;

        -- Test 2: Write and readback PHY_ADDR (0x08)
        -- PHY address=1 (bits 4:0), reg address=0 (bits 12:8) => 0x01
        wr(x"00000008", x"00000001");
        rd(x"00000008", rdata);
        if rdata = x"00000001" then
            report "PHY_ADDR PASS" severity note;
        else
            report "PHY_ADDR FAIL" severity error;
            pass <= false;
        end if;

        -- Test 3: Write and readback PHY_DATA (0x0C)
        -- MDIO write data = 0xABCD in bits [15:0]
        wr(x"0000000C", x"0000ABCD");
        rd(x"0000000C", rdata);
        if rdata = x"0000ABCD" then
            report "PHY_DATA PASS" severity note;
        else
            report "PHY_DATA FAIL" severity error;
            pass <= false;
        end if;

        -- Test 4: Write and readback TX_CTRL (0x10)
        wr(x"00000010", x"00001001");
        rd(x"00000010", rdata);
        if rdata = x"00001001" then
            report "TX_CTRL PASS" severity note;
        else
            report "TX_CTRL FAIL" severity error;
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
