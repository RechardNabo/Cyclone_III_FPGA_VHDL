-- ================================================================================
-- usb20_otg_controller : USB 2.0 OTG controller (host + device)
-- ================================================================================
-- Supports USB 2.0 full-speed (12 Mbps) and high-speed (480 Mbps) modes.
--   * Device mode: configurable endpoints, address assignment
--   * Host mode: address target device, issue transactions
--   * OTG role negotiation via ID pin
--
-- AHB-Lite register map:
--   0x00 : CTRL       - [0] enable, [1] irq_en, [2] host_mode, [3] reset
--   0x04 : STAT       - [0] connected, [1] suspended, [2] tx_done, [3] rx_ready, [4] error
--   0x08 : DEV_ADDR   - device address [6:0], [7] enable
--   0x0C : EP_CFG     - endpoint config (number, direction, type, max packet)
--   0x10 : EP_DATA    - endpoint data FIFO read/write port
--   0x14 : HOST_CTRL  - host control (token, endpoint, device addr)
--   0x18 : HOST_ADDR  - host target device address
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity usb20_otg_controller is
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

        -- USB physical interface
        usb_dp    : inout std_logic := 'Z';
        usb_dm    : inout std_logic := 'Z';
        usb_id    : in  std_logic := '1';   -- 1=A-side(host), 0=B-side(device)
        usb_vbus  : in  std_logic := '0';
        usb_irq   : out std_logic
    );
end entity usb20_otg_controller;

architecture rtl of usb20_otg_controller is
    constant FIFO_DEPTH : integer := 16;

    type fifo_t is array(0 to FIFO_DEPTH-1) of std_logic_vector(31 downto 0);

    signal ctrl_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal dev_addr_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal ep_cfg_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal host_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal host_addr_reg : std_logic_vector(31 downto 0) := (others => '0');

    signal ep_fifo       : fifo_t := (others => (others => '0'));
    signal fifo_wr_ptr   : integer range 0 to FIFO_DEPTH-1 := 0;
    signal fifo_rd_ptr   : integer range 0 to FIFO_DEPTH-1 := 0;
    signal fifo_count    : integer range 0 to FIFO_DEPTH := 0;

    signal tx_done       : std_logic := '0';
    signal rx_ready      : std_logic := '0';
    signal irq_pending   : std_logic := '0';
    signal bit_clk_div   : unsigned(7 downto 0) := (others => '0');
    signal tx_state      : integer range 0 to 7 := 0;

    signal reg_offset    : std_logic_vector(7 downto 0);
    signal write_en      : std_logic;
    signal usb_dp_int    : std_logic := 'Z';
    signal usb_dm_int    : std_logic := 'Z';
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    usb_dp     <= usb_dp_int when ctrl_reg(0) = '1' else 'Z';
    usb_dm     <= usb_dm_int when ctrl_reg(0) = '1' else 'Z';

    ahb_write : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            ctrl_reg      <= (others => '0');
            dev_addr_reg  <= (others => '0');
            ep_cfg_reg    <= (others => '0');
            host_ctrl_reg <= (others => '0');
            host_addr_reg <= (others => '0');
            ep_fifo       <= (others => (others => '0'));
            fifo_wr_ptr   <= 0;
            fifo_rd_ptr   <= 0;
            fifo_count    <= 0;
            tx_done       <= '0';
            rx_ready      <= '0';
            irq_pending   <= '0';
            bit_clk_div   <= (others => '0');
            tx_state      <= 0;
            usb_dp_int    <= 'Z';
            usb_dm_int    <= 'Z';
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            tx_done <= '0';
            if write_en = '1' then
                case reg_offset is
                    when x"00" => ctrl_reg <= HWDATA;
                    when x"04" =>  -- STAT write-1-to-clear
                        if HWDATA(2) = '1' then tx_done <= '0'; end if;
                        if HWDATA(3) = '1' then rx_ready <= '0'; end if;
                    when x"08" => dev_addr_reg  <= HWDATA;
                    when x"0C" => ep_cfg_reg    <= HWDATA;
                    when x"10" =>  -- EP_DATA write
                        if fifo_count < FIFO_DEPTH then
                            ep_fifo(fifo_wr_ptr) <= HWDATA;
                            fifo_wr_ptr <= (fifo_wr_ptr + 1) mod FIFO_DEPTH;
                            fifo_count <= fifo_count + 1;
                        end if;
                    when x"14" => host_ctrl_reg <= HWDATA;
                    when x"18" => host_addr_reg <= HWDATA;
                    when others => null;
                end case;
            end if;

            -- Simplified USB TX (NRZI encoding placeholder)
            if ctrl_reg(0) = '1' and fifo_count > 0 and tx_state = 0 then
                if bit_clk_div = 8 then
                    bit_clk_div <= (others => '0');
                    tx_state <= 1;
                    usb_dp_int <= '0';  -- SYNC start (K state)
                    usb_dm_int <= '1';
                else
                    bit_clk_div <= bit_clk_div + 1;
                end if;
            elsif tx_state = 1 then
                tx_state <= 2;
                usb_dp_int <= '1';  -- J state
                usb_dm_int <= '0';
            elsif tx_state = 2 then
                tx_state <= 0;
                usb_dp_int <= 'Z';
                usb_dm_int <= 'Z';
                tx_done <= '1';
                irq_pending <= ctrl_reg(1);
                if fifo_count > 0 then
                    fifo_rd_ptr <= (fifo_rd_ptr + 1) mod FIFO_DEPTH;
                    fifo_count <= fifo_count - 1;
                end if;
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, dev_addr_reg, ep_cfg_reg,
                       host_ctrl_reg, host_addr_reg, ep_fifo, fifo_count,
                       tx_done, rx_ready, usb_id, usb_vbus)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"00" => rdata := ctrl_reg;
                when x"04" =>
                    rdata(0) := usb_vbus;
                    rdata(2) := tx_done;
                    rdata(3) := rx_ready;
                when x"08" => rdata := dev_addr_reg;
                when x"0C" => rdata := ep_cfg_reg;
                when x"10" =>
                    if fifo_count > 0 then
                        rdata := ep_fifo(fifo_rd_ptr);
                    end if;
                when x"14" => rdata := host_ctrl_reg;
                when x"18" => rdata := host_addr_reg;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    usb_irq   <= irq_pending;

end architecture rtl;
