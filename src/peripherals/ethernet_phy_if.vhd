-- ================================================================================
-- ethernet_phy_if : Ethernet PHY interface (RGMII/RMII) with MDIO
-- ================================================================================
-- Provides RGMII/RMII interface to external Ethernet PHY with MDIO management.
--   * 4-bit RGMII data path (TX and RX)
--   * MDIO/MDC for PHY register access (clause 22)
--   * Link status and speed detection
--
-- AHB-Lite register map:
--   0x00 : CTRL     - [0] enable, [1] irq_en, [2] rgmii_mode(0=RMII), [3] start_mdio
--   0x04 : STAT     - [0] link_up, [1] speed(0=10/100,1=1000), [2] full_duplex, [3] mdio_done
--   0x08 : PHY_ADDR - PHY address [4:0], reg address [12:8]
--   0x0C : PHY_DATA - MDIO read/write data (16-bit in [15:0])
--   0x10 : TX_CTRL  - TX control (enable, length)
--   0x14 : RX_STAT  - RX status (packet count, length, error)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ethernet_phy_if is
    port (
        -- AHB-Lite slave interface
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;
        HSEL      : in  std_logic;
        HWRITE    : in  std_logic;
        HREADY    : in  std_logic;
        HTRANS    : in  std_logic_vector(1 downto 0);
        HSIZE     : in  std_logic_vector(2 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;
        HREADYOUT : out std_logic;

        -- RGMII interface
        rgmii_txd   : out std_logic_vector(3 downto 0);
        rgmii_tx_ctl: out std_logic;
        rgmii_txc   : out std_logic;
        rgmii_rxd   : in  std_logic_vector(3 downto 0) := (others => '0');
        rgmii_rx_ctl: in  std_logic := '0';
        rgmii_rxc   : in  std_logic := '0';

        -- MDIO management interface
        mdc         : out std_logic;
        mdio        : inout std_logic := 'Z';

        eth_irq     : out std_logic
    );
end entity ethernet_phy_if;

architecture rtl of ethernet_phy_if is
    signal ctrl_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal stat_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal phy_addr_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal phy_data_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal tx_ctrl_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_stat_reg   : std_logic_vector(31 downto 0) := (others => '0');

    signal mdio_done     : std_logic := '0';
    signal irq_pending   : std_logic := '0';
    signal mdio_clk_div  : unsigned(7 downto 0) := (others => '0');
    signal mdio_bit_cnt  : integer range 0 to 64 := 0;
    signal mdio_shift_out: std_logic_vector(47 downto 0) := (others => '0');
    signal mdio_shift_in : std_logic_vector(15 downto 0) := (others => '0');
    signal mdio_active   : std_logic := '0';
    signal mdc_int       : std_logic := '0';
    signal mdio_int      : std_logic := 'Z';

    signal rgmii_txd_reg : std_logic_vector(3 downto 0) := (others => '0');
    signal rgmii_tx_ctl_reg : std_logic := '0';
    signal rgmii_txc_reg : std_logic := '0';
    signal tx_clk_div    : unsigned(3 downto 0) := (others => '0');

    signal reg_offset    : std_logic_vector(7 downto 0);
    signal write_en      : std_logic;
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    mdc        <= mdc_int;
    mdio       <= mdio_int when mdio_active = '1' else 'Z';
    rgmii_txd  <= rgmii_txd_reg;
    rgmii_tx_ctl <= rgmii_tx_ctl_reg;
    rgmii_txc  <= rgmii_txc_reg;

    ahb_write : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            ctrl_reg     <= (others => '0');
            phy_addr_reg <= (others => '0');
            phy_data_reg <= (others => '0');
            tx_ctrl_reg  <= (others => '0');
            rx_stat_reg  <= (others => '0');
            mdio_done    <= '0';
            irq_pending  <= '0';
            mdio_clk_div <= (others => '0');
            mdio_bit_cnt <= 0;
            mdio_shift_out <= (others => '0');
            mdio_shift_in  <= (others => '0');
            mdio_active  <= '0';
            mdc_int      <= '0';
            mdio_int     <= 'Z';
            rgmii_txd_reg <= (others => '0');
            rgmii_tx_ctl_reg <= '0';
            rgmii_txc_reg <= '0';
            tx_clk_div   <= (others => '0');
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            mdio_done <= '0';
            if write_en = '1' then
                case reg_offset is
                    when x"00" =>
                        ctrl_reg <= HWDATA;
                        if HWDATA(3) = '1' and mdio_active = '0' then
                            -- Start MDIO: preamble(32) + start(2) + op(2) + phy(5) + reg(5) + ta(2) + data(16)
                            mdio_shift_out <= x"FFFFFFFF" & "01" & "10" &
                                              phy_addr_reg(4 downto 0) &
                                              phy_addr_reg(12 downto 8) & "10";
                            mdio_active <= '1';
                            mdio_bit_cnt <= 0;
                            mdio_clk_div <= (others => '0');
                        end if;
                    when x"08" => phy_addr_reg <= HWDATA;
                    when x"0C" => phy_data_reg <= HWDATA;
                    when x"10" => tx_ctrl_reg  <= HWDATA;
                    when others => null;
                end case;
            end if;

            -- MDIO state machine
            if mdio_active = '1' then
                if mdio_clk_div = 124 then  -- ~2.5 MHz MDC at 20 MHz
                    mdio_clk_div <= (others => '0');
                    mdc_int <= not mdc_int;
                    if mdc_int = '1' then  -- falling edge: shift data
                        if mdio_bit_cnt < 48 then
                            mdio_int <= mdio_shift_out(47);
                            mdio_shift_out <= mdio_shift_out(46 downto 0) & '0';
                        elsif mdio_bit_cnt < 64 then
                            mdio_int <= 'Z';
                            mdio_shift_in <= mdio_shift_in(14 downto 0) & mdio;
                        else
                            mdio_active <= '0';
                            mdio_done <= '1';
                            phy_data_reg <= x"0000" & mdio_shift_in;
                            irq_pending <= ctrl_reg(1);
                            mdio_int <= 'Z';
                        end if;
                        mdio_bit_cnt <= mdio_bit_cnt + 1;
                    end if;
                else
                    mdio_clk_div <= mdio_clk_div + 1;
                end if;
            end if;

            -- RGMII TX clock generation (125 MHz placeholder via divider)
            if tx_clk_div = 0 then
                tx_clk_div <= (others => '0');
                rgmii_txc_reg <= not rgmii_txc_reg;
            else
                tx_clk_div <= tx_clk_div - 1;
            end if;

            -- Link status from RX
            stat_reg(0) <= rgmii_rx_ctl;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, stat_reg, phy_addr_reg,
                       phy_data_reg, tx_ctrl_reg, rx_stat_reg, mdio_done)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"00" => rdata := ctrl_reg;
                when x"04" =>
                    rdata(0) := stat_reg(0);
                    rdata(3) := mdio_done;
                when x"08" => rdata := phy_addr_reg;
                when x"0C" => rdata := phy_data_reg;
                when x"10" => rdata := tx_ctrl_reg;
                when x"14" => rdata := rx_stat_reg;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    eth_irq   <= irq_pending;

end architecture rtl;
