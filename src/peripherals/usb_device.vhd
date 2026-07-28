-- ================================================================================
-- usb_device : USB 2.0 Full-Speed Device Controller (educational model)
-- ================================================================================
-- Implements a simplified USB 2.0 Full-Speed device controller with AHB-Lite
-- slave register interface. Supports up to NUM_ENDPOINTS endpoints with
-- independent TX/RX FIFOs, SETUP/IN/OUT token handling, and basic USB
-- device state machine (POWERED -> DEFAULT -> ADDRESS -> CONFIGURED).
--
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- Register Map (word-aligned, offset from base, HADDR[7:2] selects register):
--   0x00: USB_CTRL      - bit0=enable, bit1=reset, bit2=suspend, bit3=resume,
--                         bit4=address_valid
--   0x04: USB_ADDR      - USB device address (7-bit)
--   0x08: USB_STATUS    - bit0=setup_pkt, bit1=rx_ready, bit2=tx_ready,
--                         bit3=suspended, bit4=reset_detected, bit5=sof_received
--   0x0C: USB_IRQ_STATUS- bit0=setup_irq, bit1=rx_irq, bit2=tx_done_irq,
--                         bit3=reset_irq, bit4=sof_irq, bit5=suspend_irq
--   0x10: USB_IRQ_ENABLE- same bit mapping as IRQ_STATUS
--   0x14: USB_IRQ_CLEAR - write 1 to clear IRQ bits
--   0x18: USB_FRAME_NUM - Current USB frame number (11-bit)
--   0x1C: USB_EP_CTRL   - bit0..3=ep_index, bit4=enable, bit5=stall,
--                         bit6=dir(0=OUT,1=IN), bit7=type(0=ctrl,1=bulk,2=int,3=iso)
--   0x20: USB_EP_STATUS - bit0=rx_ready, bit1=tx_ready, bit2=stalled,
--                         bit3=nak, bit4=timeout, bit5=setup
--   0x24: USB_EP_DATA   - Read/write FIFO data port (auto-increments FIFO pointer)
--   0x28: USB_EP_COUNT  - Number of bytes in endpoint FIFO
--   0x2C: USB_EP_ADDR   - Endpoint address (4-bit EP number + 1-bit direction)
--   0x30: USB_EP_MAX_PKT- Maximum packet size for selected endpoint
--   0x34: USB_EP_FIFO_CTRL - bit0=flush_rx, bit1=flush_tx, bit2=reset_rx_ptr,
--                             bit3=reset_tx_ptr
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity usb_device is
    generic (
        NUM_ENDPOINTS : integer := 4;   -- Number of USB endpoints
        FIFO_DEPTH    : integer := 64   -- FIFO depth in bytes per endpoint
    );
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

        -- USB physical interface (D+ / D- differential pair)
        usb_dp    : inout std_logic;
        usb_dm    : inout std_logic;

        -- USB clock (48 MHz for Full-Speed)
        usb_clk   : in  std_logic;

        -- Interrupt
        usb_int   : out std_logic
    );
end entity usb_device;

architecture rtl of usb_device is

    -- Register offsets
    constant REG_CTRL        : integer := 0;  -- 0x00
    constant REG_ADDR        : integer := 1;  -- 0x04
    constant REG_STATUS      : integer := 2;  -- 0x08
    constant REG_IRQ_STATUS  : integer := 3;  -- 0x0C
    constant REG_IRQ_ENABLE  : integer := 4;  -- 0x10
    constant REG_IRQ_CLEAR   : integer := 5;  -- 0x14
    constant REG_FRAME_NUM   : integer := 6;  -- 0x18
    constant REG_EP_CTRL     : integer := 7;  -- 0x1C
    constant REG_EP_STATUS   : integer := 8;  -- 0x20
    constant REG_EP_DATA     : integer := 9;  -- 0x24
    constant REG_EP_COUNT    : integer := 10; -- 0x28
    constant REG_EP_ADDR     : integer := 11; -- 0x2C
    constant REG_EP_MAX_PKT  : integer := 12; -- 0x30
    constant REG_EP_FIFO_CTRL: integer := 13; -- 0x34

    -- Control register bits
    constant CTRL_ENABLE        : integer := 0;
    constant CTRL_RESET         : integer := 1;
    constant CTRL_SUSPEND       : integer := 2;
    constant CTRL_RESUME        : integer := 3;
    constant CTRL_ADDR_VALID    : integer := 4;

    -- Status register bits
    constant STATUS_SETUP_PKT   : integer := 0;
    constant STATUS_RX_READY    : integer := 1;
    constant STATUS_TX_READY    : integer := 2;
    constant STATUS_SUSPENDED   : integer := 3;
    constant STATUS_RESET_DET   : integer := 4;
    constant STATUS_SOF_RECV    : integer := 5;

    -- IRQ bits
    constant IRQ_SETUP    : integer := 0;
    constant IRQ_RX       : integer := 1;
    constant IRQ_TX_DONE  : integer := 2;
    constant IRQ_RESET    : integer := 3;
    constant IRQ_SOF      : integer := 4;
    constant IRQ_SUSPEND  : integer := 5;

    -- Endpoint control bits
    constant EPCTRL_EP_INDEX : integer := 0;  -- 4 bits [3:0]
    constant EPCTRL_ENABLE   : integer := 4;
    constant EPCTRL_STALL    : integer := 5;
    constant EPCTRL_DIR      : integer := 6;  -- 0=OUT, 1=IN
    constant EPCTRL_TYPE     : integer := 7;  -- 2 bits [8:7]

    -- Endpoint status bits
    constant EPSTAT_RX_READY : integer := 0;
    constant EPSTAT_TX_READY : integer := 1;
    constant EPSTAT_STALLED  : integer := 2;
    constant EPSTAT_NAK      : integer := 3;
    constant EPSTAT_TIMEOUT  : integer := 4;
    constant EPSTAT_SETUP    : integer := 5;

    -- Endpoint FIFO control bits
    constant FIFO_FLUSH_RX   : integer := 0;
    constant FIFO_FLUSH_TX   : integer := 1;
    constant FIFO_RESET_RX   : integer := 2;
    constant FIFO_RESET_TX   : integer := 3;

    -- USB PID (Packet Identifier) values
    constant PID_OUT    : std_logic_vector(3 downto 0) := "0001";
    constant PID_IN     : std_logic_vector(3 downto 0) := "1001";
    constant PID_SOF    : std_logic_vector(3 downto 0) := "0101";
    constant PID_SETUP  : std_logic_vector(3 downto 0) := "1101";
    constant PID_DATA0  : std_logic_vector(3 downto 0) := "0011";
    constant PID_DATA1  : std_logic_vector(3 downto 0) := "1011";
    constant PID_ACK    : std_logic_vector(3 downto 0) := "0010";
    constant PID_NAK    : std_logic_vector(3 downto 0) := "1010";
    constant PID_STALL  : std_logic_vector(3 downto 0) := "1110";

    -- USB device states
    type usb_state_t is (DEV_POWERED, DEV_DEFAULT, DEV_ADDRESS, DEV_CONFIGURED, DEV_SUSPENDED);
    signal usb_state : usb_state_t := DEV_POWERED;

    -- USB SIE (Serial Interface Engine) FSM states
    type sie_state_t is (SIE_IDLE, SIE_RX_SYNC, SIE_RX_PID, SIE_RX_ADDR, SIE_RX_EP,
                         SIE_RX_DATA, SIE_RX_CRC16, SIE_RX_EOP,
                         SIE_TX_SYNC, SIE_TX_PID, SIE_TX_DATA, SIE_TX_CRC16, SIE_TX_EOP,
                         SIE_TX_HANDSHAKE);
    signal sie_state : sie_state_t := SIE_IDLE;

    -- Registers
    signal usb_ctrl_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal usb_addr_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal usb_irq_status     : std_logic_vector(31 downto 0) := (others => '0');
    signal usb_irq_set        : std_logic_vector(31 downto 0) := (others => '0');  -- set by SIE FSM
    signal usb_irq_enable     : std_logic_vector(31 downto 0) := (others => '0');
    signal usb_frame_num      : unsigned(10 downto 0) := (others => '0');
    signal usb_ep_ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal usb_ep_max_pkt_reg : std_logic_vector(31 downto 0) := (others => '0');

    -- Endpoint configuration arrays
    type ep_enable_arr  is array(0 to NUM_ENDPOINTS-1) of std_logic;
    type ep_stall_arr   is array(0 to NUM_ENDPOINTS-1) of std_logic;
    type ep_dir_arr     is array(0 to NUM_ENDPOINTS-1) of std_logic;
    type ep_type_arr    is array(0 to NUM_ENDPOINTS-1) of std_logic_vector(1 downto 0);
    type ep_maxpkt_arr  is array(0 to NUM_ENDPOINTS-1) of integer;
    type ep_count_arr   is array(0 to NUM_ENDPOINTS-1) of integer;
    type ep_fifo_arr    is array(0 to NUM_ENDPOINTS-1) of std_logic_vector(7 downto 0);

    signal ep_enable  : ep_enable_arr  := (others => '0');
    signal ep_stall   : ep_stall_arr   := (others => '0');
    signal ep_dir     : ep_dir_arr     := (others => '0');
    signal ep_type    : ep_type_arr    := (others => (others => '0'));
    signal ep_maxpkt  : ep_maxpkt_arr  := (others => 64);
    signal ep_rx_count: ep_count_arr   := (others => 0);
    signal ep_tx_count: ep_count_arr   := (others => 0);
    signal ep_rx_rd_ptr: ep_count_arr  := (others => 0);
    signal ep_rx_wr_ptr: ep_count_arr  := (others => 0);
    signal ep_tx_rd_ptr: ep_count_arr  := (others => 0);
    signal ep_tx_wr_ptr: ep_count_arr  := (others => 0);

    -- FIFO storage (simplified: single shared array per endpoint)
    type fifo_mem_t is array(0 to FIFO_DEPTH-1) of std_logic_vector(7 downto 0);
    type ep_fifo_mem_arr is array(0 to NUM_ENDPOINTS-1) of fifo_mem_t;
    signal ep_rx_fifo : ep_fifo_mem_arr := (others => (others => (others => '0')));
    signal ep_tx_fifo : ep_fifo_mem_arr := (others => (others => (others => '0')));

    -- SIE-to-write-process handshake for TX FIFO clear
    signal tx_clear_ep    : integer range 0 to NUM_ENDPOINTS-1 := 0;
    signal tx_clear_req   : std_logic := '0';

    -- SIE signals
    signal rx_pid       : std_logic_vector(3 downto 0) := (others => '0');
    signal rx_addr      : std_logic_vector(6 downto 0) := (others => '0');
    signal rx_ep_num    : std_logic_vector(3 downto 0) := (others => '0');
    signal rx_data_byte : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_byte_cnt  : integer := 0;
    signal tx_byte_cnt  : integer := 0;
    signal crc16_reg    : std_logic_vector(15 downto 0) := (others => '0');

    -- Status signals
    signal setup_pkt    : std_logic := '0';
    signal rx_ready_sig : std_logic := '0';
    signal tx_ready_sig : std_logic := '1';
    signal reset_detect : std_logic := '0';
    signal sof_received : std_logic := '0';

    -- NRZI encode/decode signals
    signal nrzi_last    : std_logic := '1';

    -- Address decode
    signal reg_sel : integer range 0 to 63;
    signal selected_ep : integer range 0 to NUM_ENDPOINTS-1 := 0;

begin

    -- Address decoder: HADDR[7:2] selects register
    reg_sel <= to_integer(unsigned(HADDR(7 downto 2)));

    -- Selected endpoint from EP_CTRL register
    selected_ep <= to_integer(unsigned(usb_ep_ctrl_reg(3 downto 0)))
                   when to_integer(unsigned(usb_ep_ctrl_reg(3 downto 0))) < NUM_ENDPOINTS
                   else 0;

    -- =========================================================================
    -- AHB-LITE WRITE PROCESS
    -- =========================================================================
    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            usb_ctrl_reg       <= (others => '0');
            usb_addr_reg       <= (others => '0');
            usb_irq_status     <= (others => '0');
            usb_irq_enable     <= (others => '0');
            usb_ep_ctrl_reg    <= (others => '0');
            usb_ep_max_pkt_reg <= (others => '0');
            ep_enable  <= (others => '0');
            ep_stall   <= (others => '0');
            ep_dir     <= (others => '0');
            ep_type    <= (others => (others => '0'));
            ep_maxpkt  <= (others => 64);
            ep_rx_count <= (others => 0);
            ep_tx_count <= (others => 0);
            ep_rx_rd_ptr <= (others => 0);
            ep_rx_wr_ptr <= (others => 0);
            ep_tx_rd_ptr <= (others => 0);
            ep_tx_wr_ptr <= (others => 0);
            usb_state <= DEV_POWERED;
        elsif rising_edge(HCLK) then
            if HSEL = '1' and HREADY = '1' and HWRITE = '1' then
                case reg_sel is
                    when REG_CTRL =>
                        usb_ctrl_reg <= HWDATA;
                        if HWDATA(CTRL_RESET) = '1' then
                            usb_state <= DEV_DEFAULT;
                            usb_addr_reg <= (others => '0');
                            reset_detect <= '1';
                            usb_irq_status(IRQ_RESET) <= '1';
                        elsif HWDATA(CTRL_ENABLE) = '1' then
                            usb_state <= DEV_DEFAULT;
                        end if;

                    when REG_ADDR =>
                        usb_addr_reg <= HWDATA;
                        if usb_ctrl_reg(CTRL_ADDR_VALID) = '1' then
                            usb_state <= DEV_ADDRESS;
                        end if;

                    when REG_IRQ_ENABLE =>
                        usb_irq_enable <= HWDATA;

                    when REG_IRQ_CLEAR =>
                        -- Clear IRQ bits by writing 1
                        for i in 0 to 31 loop
                            if HWDATA(i) = '1' then
                                usb_irq_status(i) <= '0';
                            end if;
                        end loop;

                    when REG_EP_CTRL =>
                        usb_ep_ctrl_reg <= HWDATA;
                        -- Apply to selected endpoint
                        if to_integer(unsigned(HWDATA(3 downto 0))) < NUM_ENDPOINTS then
                            ep_enable(to_integer(unsigned(HWDATA(3 downto 0)))) <= HWDATA(EPCTRL_ENABLE);
                            ep_stall(to_integer(unsigned(HWDATA(3 downto 0))))  <= HWDATA(EPCTRL_STALL);
                            ep_dir(to_integer(unsigned(HWDATA(3 downto 0))))    <= HWDATA(EPCTRL_DIR);
                            ep_type(to_integer(unsigned(HWDATA(3 downto 0))))   <= HWDATA(8 downto 7);
                        end if;

                    when REG_EP_DATA =>
                        -- Write to TX FIFO of selected endpoint
                        if ep_tx_wr_ptr(selected_ep) < FIFO_DEPTH then
                            ep_tx_fifo(selected_ep)(ep_tx_wr_ptr(selected_ep)) <= HWDATA(7 downto 0);
                            ep_tx_wr_ptr(selected_ep) <= ep_tx_wr_ptr(selected_ep) + 1;
                            ep_tx_count(selected_ep) <= ep_tx_count(selected_ep) + 1;
                        end if;

                    when REG_EP_ADDR =>
                        -- Endpoint address configuration
                        null;  -- handled via EP_CTRL

                    when REG_EP_MAX_PKT =>
                        usb_ep_max_pkt_reg <= HWDATA;
                        ep_maxpkt(selected_ep) <= to_integer(unsigned(HWDATA(10 downto 0)));

                    when REG_EP_FIFO_CTRL =>
                        -- FIFO control
                        if HWDATA(FIFO_FLUSH_RX) = '1' then
                            ep_rx_count(selected_ep) <= 0;
                            ep_rx_rd_ptr(selected_ep) <= 0;
                            ep_rx_wr_ptr(selected_ep) <= 0;
                        end if;
                        if HWDATA(FIFO_FLUSH_TX) = '1' then
                            ep_tx_count(selected_ep) <= 0;
                            ep_tx_rd_ptr(selected_ep) <= 0;
                            ep_tx_wr_ptr(selected_ep) <= 0;
                        end if;

                    when others => null;
                end case;
            end if;

            -- RX FIFO read pointer auto-increment on data read
            if HSEL = '1' and HREADY = '1' and HWRITE = '0' and reg_sel = REG_EP_DATA then
                if ep_rx_count(selected_ep) > 0 then
                    ep_rx_rd_ptr(selected_ep) <= ep_rx_rd_ptr(selected_ep) + 1;
                    ep_rx_count(selected_ep) <= ep_rx_count(selected_ep) - 1;
                end if;
            end if;

            -- Handle SIE FSM TX FIFO clear request
            if tx_clear_req = '1' then
                ep_tx_count(tx_clear_ep) <= 0;
                ep_tx_rd_ptr(tx_clear_ep) <= 0;
                ep_tx_wr_ptr(tx_clear_ep) <= 0;
            end if;

            -- OR in IRQ set bits from SIE FSM (unless being cleared this cycle)
            for i in 0 to 31 loop
                if usb_irq_set(i) = '1' and not (HSEL = '1' and HREADY = '1' and HWRITE = '1'
                                                  and reg_sel = REG_IRQ_CLEAR and HWDATA(i) = '1') then
                    usb_irq_status(i) <= '1';
                end if;
            end loop;

            -- Clear reset detect flag
            if reset_detect = '1' and usb_ctrl_reg(CTRL_ENABLE) = '1' then
                reset_detect <= '0';
            end if;
        end if;
    end process;

    -- =========================================================================
    -- AHB-LITE READ MULTIPLEXER
    -- =========================================================================
    process(all)
        variable status_reg : std_logic_vector(31 downto 0);
        variable ep_status  : std_logic_vector(31 downto 0);
        variable ep_count   : std_logic_vector(31 downto 0);
    begin
        status_reg := (others => '0');
        status_reg(STATUS_SETUP_PKT) := setup_pkt;
        status_reg(STATUS_RX_READY)  := rx_ready_sig;
        status_reg(STATUS_TX_READY)  := tx_ready_sig;
        status_reg(STATUS_SUSPENDED) := '1' when usb_state = DEV_SUSPENDED else '0';
        status_reg(STATUS_RESET_DET) := reset_detect;
        status_reg(STATUS_SOF_RECV)  := sof_received;

        ep_status := (others => '0');
        if ep_rx_count(selected_ep) > 0 then
            ep_status(EPSTAT_RX_READY) := '1';
        end if;
        if ep_tx_count(selected_ep) = 0 then
            ep_status(EPSTAT_TX_READY) := '1';
        end if;
        ep_status(EPSTAT_STALLED) := ep_stall(selected_ep);

        -- Return TX count for IN endpoints, RX count for OUT endpoints
        if ep_dir(selected_ep) = '1' then
            ep_count := std_logic_vector(to_unsigned(ep_tx_count(selected_ep), 32));
        else
            ep_count := std_logic_vector(to_unsigned(ep_rx_count(selected_ep), 32));
        end if;

        if HSEL = '1' then
            case reg_sel is
                when REG_CTRL =>
                    HRDATA <= usb_ctrl_reg;
                when REG_ADDR =>
                    HRDATA <= usb_addr_reg;
                when REG_STATUS =>
                    HRDATA <= status_reg;
                when REG_IRQ_STATUS =>
                    HRDATA <= usb_irq_status;
                when REG_IRQ_ENABLE =>
                    HRDATA <= usb_irq_enable;
                when REG_FRAME_NUM =>
                    HRDATA <= x"00000" & "0" & std_logic_vector(usb_frame_num);
                when REG_EP_CTRL =>
                    HRDATA <= usb_ep_ctrl_reg;
                when REG_EP_STATUS =>
                    HRDATA <= ep_status;
                when REG_EP_DATA =>
                    -- Read from RX FIFO of selected endpoint
                    if ep_rx_count(selected_ep) > 0 then
                        HRDATA <= x"000000" & ep_rx_fifo(selected_ep)(ep_rx_rd_ptr(selected_ep));
                    else
                        HRDATA <= (others => '0');
                    end if;
                when REG_EP_COUNT =>
                    HRDATA <= ep_count;
                when REG_EP_ADDR =>
                    HRDATA <= usb_ep_ctrl_reg;
                when REG_EP_MAX_PKT =>
                    HRDATA <= usb_ep_max_pkt_reg;
                when others =>
                    HRDATA <= (others => '0');
            end case;
        else
            HRDATA <= (others => '0');
        end if;
    end process;

    -- RX read pointer auto-increment is handled in the main write process above
    -- (merged to avoid multi-driver on ep_rx_rd_ptr / ep_rx_count)

    HRESP <= '0';
    HREADYOUT <= '1';

    -- =========================================================================
    -- USB SIE (Serial Interface Engine) - Simplified
    -- Handles USB packet detection and generation
    -- In this educational model, the USB PHY (NRZI, bit stuffing) is simplified
    -- to byte-level operations for simulation feasibility.
    -- =========================================================================
    process(usb_clk, HRESETn)
    begin
        if HRESETn = '0' then
            sie_state <= SIE_IDLE;
            rx_pid <= (others => '0');
            rx_addr <= (others => '0');
            rx_ep_num <= (others => '0');
            rx_byte_cnt <= 0;
            tx_byte_cnt <= 0;
            crc16_reg <= (others => '0');
            usb_frame_num <= (others => '0');
            setup_pkt <= '0';
            sof_received <= '0';
            nrzi_last <= '1';
            usb_dp <= 'Z';
            usb_dm <= 'Z';
            usb_irq_set <= (others => '0');
            tx_clear_req <= '0';
        elsif rising_edge(usb_clk) then
            if usb_ctrl_reg(CTRL_ENABLE) = '0' then
                sie_state <= SIE_IDLE;
                usb_dp <= 'Z';
                usb_dm <= 'Z';
                tx_clear_req <= '0';
                usb_irq_set <= (others => '0');
            else
                -- Default: clear one-cycle pulse signals
                tx_clear_req <= '0';
                usb_irq_set <= (others => '0');

                case sie_state is
                    when SIE_IDLE =>
                        -- Monitor USB bus for incoming packets
                        -- (Simplified: detect bus activity via D+ high for FS)
                        if usb_dp = '1' and usb_dm = '0' then
                            -- J state (idle) - wait for SYNC (KJKJKJKK pattern)
                            sie_state <= SIE_RX_SYNC;
                        end if;

                    when SIE_RX_SYNC =>
                        -- Simplified: assume SYNC detected, receive PID
                        sie_state <= SIE_RX_PID;
                        rx_byte_cnt <= 0;

                    when SIE_RX_PID =>
                        -- Receive PID byte (simplified: from external stimulus)
                        -- In real hardware, this would decode NRZI from D+/D-
                        -- For this model, PID is set via register interface
                        sie_state <= SIE_RX_ADDR;

                    when SIE_RX_ADDR =>
                        -- Check if address matches
                        if rx_addr = usb_addr_reg(6 downto 0) or
                           (usb_state = DEV_DEFAULT and rx_addr = "0000000") then
                            sie_state <= SIE_RX_EP;
                        else
                            -- Not for us
                            sie_state <= SIE_IDLE;
                        end if;

                    when SIE_RX_EP =>
                        -- Select endpoint
                        if to_integer(unsigned(rx_ep_num)) < NUM_ENDPOINTS then
                            if rx_pid = PID_SETUP then
                                setup_pkt <= '1';
                                usb_irq_set(IRQ_SETUP) <= '1';
                                sie_state <= SIE_RX_DATA;
                            elsif rx_pid = PID_OUT then
                                sie_state <= SIE_RX_DATA;
                            elsif rx_pid = PID_IN then
                                -- Host wants data from us (IN token)
                                if ep_tx_count(to_integer(unsigned(rx_ep_num))) > 0 then
                                    sie_state <= SIE_TX_SYNC;
                                else
                                    -- NAK: no data to send
                                    sie_state <= SIE_TX_HANDSHAKE;
                                end if;
                            elsif rx_pid = PID_SOF then
                                sof_received <= '1';
                                usb_irq_set(IRQ_SOF) <= '1';
                                usb_frame_num <= usb_frame_num + 1;
                                sie_state <= SIE_IDLE;
                            else
                                sie_state <= SIE_IDLE;
                            end if;
                        else
                            sie_state <= SIE_IDLE;
                        end if;

                    when SIE_RX_DATA =>
                        -- Receive data bytes into RX FIFO
                        -- (Simplified: data comes from external stimulus)
                        sie_state <= SIE_RX_CRC16;

                    when SIE_RX_CRC16 =>
                        -- Check CRC-16 (simplified: assume valid)
                        sie_state <= SIE_RX_EOP;

                    when SIE_RX_EOP =>
                        -- End of packet: send ACK
                        sie_state <= SIE_TX_HANDSHAKE;
                        usb_irq_set(IRQ_RX) <= '1';

                    when SIE_TX_SYNC =>
                        -- Generate SYNC pattern (KJKJKJKK)
                        sie_state <= SIE_TX_PID;
                        tx_byte_cnt <= 0;

                    when SIE_TX_PID =>
                        -- Send DATA1 PID (alternating DATA0/DATA1 in real HW)
                        sie_state <= SIE_TX_DATA;

                    when SIE_TX_DATA =>
                        -- Send data from TX FIFO
                        if tx_byte_cnt < ep_tx_count(to_integer(unsigned(rx_ep_num))) then
                            tx_byte_cnt <= tx_byte_cnt + 1;
                        else
                            sie_state <= SIE_TX_CRC16;
                        end if;

                    when SIE_TX_CRC16 =>
                        -- Send CRC-16
                        sie_state <= SIE_TX_EOP;

                    when SIE_TX_EOP =>
                        -- End of packet
                        -- Request TX FIFO clear for this endpoint (handled by write process)
                        tx_clear_ep <= to_integer(unsigned(rx_ep_num));
                        tx_clear_req <= '1';
                        usb_irq_set(IRQ_TX_DONE) <= '1';
                        sie_state <= SIE_IDLE;

                    when SIE_TX_HANDSHAKE =>
                        -- Send ACK/NAK/STALL
                        if ep_stall(to_integer(unsigned(rx_ep_num))) = '1' then
                            -- Send STALL
                            null;
                        elsif rx_pid = PID_IN and ep_tx_count(to_integer(unsigned(rx_ep_num))) = 0 then
                            -- Send NAK
                            null;
                        else
                            -- Send ACK
                            null;
                        end if;
                        sie_state <= SIE_IDLE;

                    when others =>
                        sie_state <= SIE_IDLE;
                end case;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Interrupt output
    -- =========================================================================
    usb_int <= '1' when (usb_irq_status and usb_irq_enable) /= x"00000000"
                     and usb_ctrl_reg(CTRL_ENABLE) = '1'
               else '0';

end architecture rtl;
