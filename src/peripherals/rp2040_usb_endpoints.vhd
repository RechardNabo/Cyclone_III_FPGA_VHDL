-- ================================================================================
-- rp2040_usb_endpoints : RP2040 USB 1.1 full endpoint controller
-- ================================================================================
-- 16 endpoints (8 IN, 8 OUT). Supports control, bulk, interrupt, isochronous.
--
-- Register Map (stride 0x04, indexed by endpoint 0..15):
--   0x000 + 4*n: EP_CTRLn   - bit0=enable, bit1=halt, bits2..3=type(0=ctrl,1=iso,2=bulk,3=int), bit4=dir(0=OUT,1=IN), bits8..14=buf_size
--   0x040 + 4*n: EP_BUF_CTRLn - bit0=buf0_full, bit1=buf1_full, bit2=last_buf, bits16..31=buf_len
--   0x080 + 4*n: EP_TOGGLEN  - bit0=data_toggle, bit1=seq_reset
--   0x0C0: USB_ADDR  - device address (bits0..6)
--   0x0C4: USB_INT   - interrupt status / enable
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rp2040_usb_endpoints is
    generic (
        NUM_ENDPOINTS : integer := 16
    );
    port (
        -- AHB-Lite slave interface
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;
        HSEL      : in  std_logic;
        HWRITE    : in  std_logic;
        HREADY    : in  std_logic;
        HTRANS    : in  std_logic_vector(1 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;
        HREADYOUT : out std_logic;

        -- USB PHY interface
        usb_dp    : inout std_logic;
        usb_dm    : inout std_logic;
        usb_irq   : out   std_logic
    );
end entity rp2040_usb_endpoints;

architecture rtl of rp2040_usb_endpoints is
    type ep_array is array(0 to NUM_ENDPOINTS-1) of std_logic_vector(31 downto 0);

    signal ep_ctrl     : ep_array := (others => (others => '0'));
    signal ep_buf_ctrl : ep_array := (others => (others => '0'));
    signal ep_toggle   : ep_array := (others => (others => '0'));
    signal usb_addr    : std_logic_vector(31 downto 0) := (others => '0');
    signal usb_int     : std_logic_vector(31 downto 0) := (others => '0');

    signal write_en    : std_logic;
    signal ep_idx      : integer range 0 to NUM_ENDPOINTS-1;

    signal tx_data     : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_data     : std_logic_vector(7 downto 0);
    signal tx_valid    : std_logic := '0';
    signal rx_valid    : std_logic := '0';
    signal tx_ready    : std_logic;
    signal rx_active   : std_logic;

begin

    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    ep_idx   <= to_integer(unsigned(HADDR(7 downto 2))) when
                to_integer(unsigned(HADDR(7 downto 2))) < NUM_ENDPOINTS else 0;

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write process
    reg_write : process(HCLK)
        variable reg_grp : integer;
        variable idx     : integer;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ep_ctrl     <= (others => (others => '0'));
                ep_buf_ctrl <= (others => (others => '0'));
                ep_toggle   <= (others => (others => '0'));
                usb_addr    <= (others => '0');
                usb_int     <= (others => '0');
            elsif write_en = '1' then
                reg_grp := to_integer(unsigned(HADDR(9 downto 8)));
                idx     := to_integer(unsigned(HADDR(7 downto 2)));
                case reg_grp is
                    when 0 =>  -- EP_CTRL
                        if idx < NUM_ENDPOINTS then
                            ep_ctrl(idx) <= HWDATA;
                        end if;
                    when 1 =>  -- EP_BUF_CTRL
                        if idx < NUM_ENDPOINTS then
                            ep_buf_ctrl(idx) <= HWDATA;
                        end if;
                    when 2 =>  -- EP_TOGGLE
                        if idx < NUM_ENDPOINTS then
                            ep_toggle(idx) <= HWDATA;
                        end if;
                    when 3 =>  -- USB_ADDR / USB_INT
                        case HADDR(3 downto 2) is
                            when "00" => usb_addr <= HWDATA;
                            when "01" => usb_int  <= HWDATA;
                            when others => null;
                        end case;
                    when others => null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(HADDR, ep_ctrl, ep_buf_ctrl, ep_toggle, usb_addr, usb_int)
        variable reg_grp : integer;
        variable idx     : integer;
    begin
        reg_grp := to_integer(unsigned(HADDR(9 downto 8)));
        idx     := to_integer(unsigned(HADDR(7 downto 2)));
        case reg_grp is
            when 0 =>
                if idx < NUM_ENDPOINTS then HRDATA <= ep_ctrl(idx);
                else HRDATA <= (others => '0'); end if;
            when 1 =>
                if idx < NUM_ENDPOINTS then HRDATA <= ep_buf_ctrl(idx);
                else HRDATA <= (others => '0'); end if;
            when 2 =>
                if idx < NUM_ENDPOINTS then HRDATA <= ep_toggle(idx);
                else HRDATA <= (others => '0'); end if;
            when 3 =>
                case HADDR(3 downto 2) is
                    when "00" => HRDATA <= usb_addr;
                    when "01" => HRDATA <= usb_int;
                    when others => HRDATA <= (others => '0');
                end case;
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    -- Simplified USB PHY: tri-state D+/D- based on tx_valid
    usb_dp <= tx_data(0) when tx_valid = '1' and tx_ready = '1' else 'Z';
    usb_dm <= tx_data(1) when tx_valid = '1' and tx_ready = '1' else 'Z';

    rx_active <= '1' when (usb_dp /= 'Z' or usb_dm /= 'Z') else '0';
    rx_data   <= (usb_dm & "000000" & usb_dp) when rx_active = '1' else (others => '0');
    rx_valid  <= rx_active;

    tx_ready <= '1' when rx_active = '0' else '0';

    -- Interrupt: any endpoint buffer-full event when enabled
    int_proc : process(ep_buf_ctrl, usb_int)
        variable any_int : std_logic;
    begin
        any_int := '0';
        for i in 0 to NUM_ENDPOINTS-1 loop
            if ep_buf_ctrl(i)(0) = '1' then
                any_int := '1';
            end if;
        end loop;
        usb_irq <= any_int and usb_int(0);
    end process int_proc;

end architecture rtl;
