# 🔌 **USB (Universal Serial Bus) VHDL Cheatsheet**

## 📋 **Table of Contents**
1. [USB Fundamentals](#usb-fundamentals)
2. [USB 2.0 Device Controller](#usb-20-device-controller)
3. [USB 2.0 Host Controller](#usb-20-host-controller)
4. [USB 3.0 SuperSpeed Controller](#usb-30-superspeed-controller)
5. [USB Protocol Stack](#usb-protocol-stack)
6. [USB Endpoint Management](#usb-endpoint-management)
7. [USB Packet Processing](#usb-packet-processing)
8. [USB PHY Interface](#usb-phy-interface)
9. [USB Hub Controller](#usb-hub-controller)
10. [Testing and Verification](#testing-and-verification)

---

## 🎯 **USB Fundamentals**

### USB System Architecture
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- USB Speed Definitions
package usb_pkg is
    -- USB Speed Types
    type usb_speed_type is (LOW_SPEED, FULL_SPEED, HIGH_SPEED, SUPER_SPEED);
    
    -- USB PID Types
    constant PID_OUT    : std_logic_vector(3 downto 0) := "0001";
    constant PID_IN     : std_logic_vector(3 downto 0) := "1001";
    constant PID_SOF    : std_logic_vector(3 downto 0) := "0101";
    constant PID_SETUP  : std_logic_vector(3 downto 0) := "1101";
    constant PID_DATA0  : std_logic_vector(3 downto 0) := "0011";
    constant PID_DATA1  : std_logic_vector(3 downto 0) := "1011";
    constant PID_DATA2  : std_logic_vector(3 downto 0) := "0111";
    constant PID_MDATA  : std_logic_vector(3 downto 0) := "1111";
    constant PID_ACK    : std_logic_vector(3 downto 0) := "0010";
    constant PID_NAK    : std_logic_vector(3 downto 0) := "1010";
    constant PID_STALL  : std_logic_vector(3 downto 0) := "1110";
    constant PID_NYET   : std_logic_vector(3 downto 0) := "0110";
    
    -- USB Endpoint Types
    type endpoint_type is (CONTROL, ISOCHRONOUS, BULK, INTERRUPT);
    
    -- USB Transfer States
    type transfer_state_type is (IDLE, SETUP, DATA_OUT, DATA_IN, STATUS, COMPLETE, ERROR);
    
end package usb_pkg;

-- Generic USB Controller Entity
entity usb_controller is
    generic (
        USB_SPEED : usb_speed_type := FULL_SPEED;
        NUM_ENDPOINTS : integer := 16;
        FIFO_DEPTH : integer := 512
    );
    port (
        -- Clock and Reset
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- USB PHY Interface
        usb_dp      : inout std_logic;
        usb_dm      : inout std_logic;
        usb_oe      : out std_logic;
        usb_speed   : out std_logic_vector(1 downto 0);
        
        -- System Interface
        sys_addr    : in  std_logic_vector(15 downto 0);
        sys_wdata   : in  std_logic_vector(31 downto 0);
        sys_rdata   : out std_logic_vector(31 downto 0);
        sys_we      : in  std_logic;
        sys_re      : in  std_logic;
        sys_ack     : out std_logic;
        
        -- Interrupt Interface
        usb_irq     : out std_logic;
        ep_irq      : out std_logic_vector(NUM_ENDPOINTS-1 downto 0);
        
        -- Status
        usb_connected : out std_logic;
        usb_configured : out std_logic;
        frame_number : out std_logic_vector(10 downto 0)
    );
end usb_controller;
```

---

## 📱 **USB 2.0 Device Controller**

### Full-Speed USB Device Implementation
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.usb_pkg.all;

entity usb2_device_controller is
    generic (
        VENDOR_ID  : std_logic_vector(15 downto 0) := x"1234";
        PRODUCT_ID : std_logic_vector(15 downto 0) := x"5678";
        NUM_ENDPOINTS : integer := 4
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- USB PHY Interface (UTMI)
        utmi_data_out : out std_logic_vector(7 downto 0);
        utmi_data_in  : in  std_logic_vector(7 downto 0);
        utmi_txvalid  : out std_logic;
        utmi_txready  : in  std_logic;
        utmi_rxvalid  : in  std_logic;
        utmi_rxactive : in  std_logic;
        utmi_rxerror  : in  std_logic;
        utmi_linestate : in std_logic_vector(1 downto 0);
        
        -- Endpoint FIFO Interface
        ep_addr     : out std_logic_vector(3 downto 0);
        ep_wdata    : out std_logic_vector(7 downto 0);
        ep_rdata    : in  std_logic_vector(7 downto 0);
        ep_we       : out std_logic;
        ep_re       : out std_logic;
        ep_full     : in  std_logic_vector(NUM_ENDPOINTS-1 downto 0);
        ep_empty    : in  std_logic_vector(NUM_ENDPOINTS-1 downto 0);
        
        -- Control Interface
        device_addr : out std_logic_vector(6 downto 0);
        configured  : out std_logic;
        suspended   : out std_logic;
        
        -- Interrupt
        usb_irq     : out std_logic
    );
end usb2_device_controller;

architecture behavioral of usb2_device_controller is
    -- Device States
    type device_state_type is (POWERED, DEFAULT, ADDRESS, CONFIGURED, SUSPENDED);
    signal device_state : device_state_type;
    
    -- Packet Reception State Machine
    type rx_state_type is (RX_IDLE, RX_SYNC, RX_PID, RX_ADDR, RX_ENDP, RX_DATA, RX_CRC, RX_EOP);
    signal rx_state : rx_state_type;
    
    -- Packet Transmission State Machine
    type tx_state_type is (TX_IDLE, TX_SYNC, TX_PID, TX_DATA, TX_CRC, TX_EOP);
    signal tx_state : tx_state_type;
    
    -- Packet Buffer
    signal rx_buffer : std_logic_vector(1023 downto 0);  -- Max packet size
    signal tx_buffer : std_logic_vector(1023 downto 0);
    signal rx_count : unsigned(9 downto 0);
    signal tx_count : unsigned(9 downto 0);
    
    -- Current Transaction
    signal current_pid : std_logic_vector(3 downto 0);
    signal current_addr : std_logic_vector(6 downto 0);
    signal current_endp : std_logic_vector(3 downto 0);
    signal current_data_toggle : std_logic_vector(NUM_ENDPOINTS-1 downto 0);
    
    -- Device Configuration
    signal dev_addr_reg : std_logic_vector(6 downto 0);
    signal config_value : std_logic_vector(7 downto 0);
    
    -- Control Transfer State
    type control_state_type is (CTRL_IDLE, CTRL_SETUP, CTRL_DATA_OUT, CTRL_DATA_IN, CTRL_STATUS_OUT, CTRL_STATUS_IN);
    signal control_state : control_state_type;
    signal setup_packet : std_logic_vector(63 downto 0);  -- 8-byte setup packet
    
    -- CRC Calculation
    signal crc5_calc : std_logic_vector(4 downto 0);
    signal crc16_calc : std_logic_vector(15 downto 0);
    
begin
    
    -- Main Device State Machine
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            device_state <= POWERED;
            dev_addr_reg <= (others => '0');
            config_value <= (others => '0');
            configured <= '0';
            suspended <= '0';
            
        elsif rising_edge(clk) then
            case device_state is
                when POWERED =>
                    if utmi_linestate = "01" then  -- J-state (connected)
                        device_state <= DEFAULT;
                    end if;
                
                when DEFAULT =>
                    dev_addr_reg <= (others => '0');
                    configured <= '0';
                    
                    if utmi_linestate = "00" then  -- SE0 (disconnected)
                        device_state <= POWERED;
                    elsif current_pid = PID_SETUP and current_addr = "0000000" and current_endp = "0000" then
                        -- Process setup packet for address assignment
                        if setup_packet(7 downto 0) = x"05" then  -- SET_ADDRESS
                            device_state <= ADDRESS;
                            dev_addr_reg <= setup_packet(22 downto 16);
                        end if;
                    end if;
                
                when ADDRESS =>
                    if utmi_linestate = "00" then
                        device_state <= POWERED;
                    elsif current_pid = PID_SETUP and current_addr = dev_addr_reg and current_endp = "0000" then
                        -- Process configuration requests
                        if setup_packet(7 downto 0) = x"09" then  -- SET_CONFIGURATION
                            device_state <= CONFIGURED;
                            config_value <= setup_packet(23 downto 16);
                            configured <= '1';
                        end if;
                    end if;
                
                when CONFIGURED =>
                    if utmi_linestate = "00" then
                        device_state <= POWERED;
                    elsif current_pid = PID_SETUP and current_addr = dev_addr_reg and current_endp = "0000" then
                        if setup_packet(7 downto 0) = x"09" and setup_packet(23 downto 16) = x"00" then
                            device_state <= ADDRESS;
                            configured <= '0';
                        end if;
                    end if;
                
                when SUSPENDED =>
                    suspended <= '1';
                    if utmi_rxactive = '1' then  -- Resume signaling
                        device_state <= CONFIGURED;
                        suspended <= '0';
                    end if;
                
                when others =>
                    device_state <= POWERED;
            end case;
        end if;
    end process;
    
    -- Packet Reception State Machine
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            rx_state <= RX_IDLE;
            rx_count <= (others => '0');
            current_pid <= (others => '0');
            current_addr <= (others => '0');
            current_endp <= (others => '0');
            
        elsif rising_edge(clk) then
            case rx_state is
                when RX_IDLE =>
                    rx_count <= (others => '0');
                    if utmi_rxvalid = '1' and utmi_data_in = x"80" then  -- SYNC pattern
                        rx_state <= RX_SYNC;
                    end if;
                
                when RX_SYNC =>
                    if utmi_rxvalid = '1' then
                        rx_state <= RX_PID;
                    end if;
                
                when RX_PID =>
                    if utmi_rxvalid = '1' then
                        current_pid <= utmi_data_in(3 downto 0);
                        
                        case utmi_data_in(3 downto 0) is
                            when PID_SETUP | PID_OUT | PID_IN =>
                                rx_state <= RX_ADDR;
                            when PID_DATA0 | PID_DATA1 =>
                                rx_state <= RX_DATA;
                            when PID_ACK | PID_NAK | PID_STALL =>
                                rx_state <= RX_EOP;
                            when others =>
                                rx_state <= RX_IDLE;
                        end case;
                    end if;
                
                when RX_ADDR =>
                    if utmi_rxvalid = '1' then
                        current_addr <= utmi_data_in(6 downto 0);
                        rx_state <= RX_ENDP;
                    end if;
                
                when RX_ENDP =>
                    if utmi_rxvalid = '1' then
                        current_endp <= utmi_data_in(3 downto 0);
                        rx_state <= RX_CRC;
                    end if;
                
                when RX_DATA =>
                    if utmi_rxvalid = '1' then
                        rx_buffer(to_integer(rx_count)*8+7 downto to_integer(rx_count)*8) <= utmi_data_in;
                        rx_count <= rx_count + 1;
                        
                        if rx_count = 1023 then  -- Max packet size reached
                            rx_state <= RX_CRC;
                        end if;
                    elsif utmi_rxactive = '0' then
                        rx_state <= RX_CRC;
                    end if;
                
                when RX_CRC =>
                    if utmi_rxvalid = '1' then
                        -- CRC validation would go here
                        rx_state <= RX_EOP;
                    end if;
                
                when RX_EOP =>
                    if utmi_rxactive = '0' then
                        rx_state <= RX_IDLE;
                        -- Process received packet
                        process_packet;
                    end if;
                
                when others =>
                    rx_state <= RX_IDLE;
            end case;
        end if;
    end process;
    
    -- Packet Transmission State Machine
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            tx_state <= TX_IDLE;
            tx_count <= (others => '0');
            utmi_data_out <= (others => '0');
            utmi_txvalid <= '0';
            
        elsif rising_edge(clk) then
            case tx_state is
                when TX_IDLE =>
                    utmi_txvalid <= '0';
                    tx_count <= (others => '0');
                    
                    -- Determine response based on received packet
                    if rx_state = RX_EOP then
                        case current_pid is
                            when PID_SETUP =>
                                if current_addr = dev_addr_reg or dev_addr_reg = "0000000" then
                                    tx_state <= TX_SYNC;
                                    prepare_ack_packet;
                                end if;
                            
                            when PID_OUT =>
                                if current_addr = dev_addr_reg then
                                    tx_state <= TX_SYNC;
                                    prepare_ack_packet;
                                end if;
                            
                            when PID_IN =>
                                if current_addr = dev_addr_reg then
                                    tx_state <= TX_SYNC;
                                    prepare_data_packet;
                                end if;
                            
                            when others =>
                                null;
                        end case;
                    end if;
                
                when TX_SYNC =>
                    utmi_data_out <= x"80";  -- SYNC pattern
                    utmi_txvalid <= '1';
                    
                    if utmi_txready = '1' then
                        tx_state <= TX_PID;
                    end if;
                
                when TX_PID =>
                    utmi_data_out <= tx_buffer(7 downto 0);  -- PID
                    
                    if utmi_txready = '1' then
                        if tx_buffer(3 downto 0) = PID_DATA0 or tx_buffer(3 downto 0) = PID_DATA1 then
                            tx_state <= TX_DATA;
                            tx_count <= to_unsigned(1, 10);
                        else
                            tx_state <= TX_EOP;
                        end if;
                    end if;
                
                when TX_DATA =>
                    utmi_data_out <= tx_buffer(to_integer(tx_count)*8+7 downto to_integer(tx_count)*8);
                    
                    if utmi_txready = '1' then
                        tx_count <= tx_count + 1;
                        
                        if tx_count = tx_buffer'length/8 - 3 then  -- Exclude CRC bytes
                            tx_state <= TX_CRC;
                        end if;
                    end if;
                
                when TX_CRC =>
                    -- Send CRC16
                    if tx_count = tx_buffer'length/8 - 2 then
                        utmi_data_out <= crc16_calc(7 downto 0);
                    else
                        utmi_data_out <= crc16_calc(15 downto 8);
                    end if;
                    
                    if utmi_txready = '1' then
                        tx_count <= tx_count + 1;
                        
                        if tx_count = tx_buffer'length/8 - 1 then
                            tx_state <= TX_EOP;
                        end if;
                    end if;
                
                when TX_EOP =>
                    utmi_txvalid <= '0';
                    tx_state <= TX_IDLE;
                
                when others =>
                    tx_state <= TX_IDLE;
            end case;
        end if;
    end process;
    
    -- Endpoint FIFO Management
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            ep_addr <= (others => '0');
            ep_wdata <= (others => '0');
            ep_we <= '0';
            ep_re <= '0';
            
        elsif rising_edge(clk) then
            ep_we <= '0';
            ep_re <= '0';
            
            -- Handle endpoint data based on current transaction
            if rx_state = RX_EOP and current_pid = PID_OUT then
                -- Write received data to endpoint FIFO
                ep_addr <= current_endp;
                for i in 0 to to_integer(rx_count)-1 loop
                    ep_wdata <= rx_buffer(i*8+7 downto i*8);
                    ep_we <= '1';
                    wait for 1 ns;  -- Simulation only
                end loop;
                
            elsif tx_state = TX_IDLE and current_pid = PID_IN then
                -- Read data from endpoint FIFO for transmission
                ep_addr <= current_endp;
                ep_re <= '1';
            end if;
        end if;
    end process;
    
    -- Output assignments
    device_addr <= dev_addr_reg;
    
    -- Procedures for packet preparation
    procedure prepare_ack_packet is
    begin
        tx_buffer(7 downto 0) <= PID_ACK & not PID_ACK;
    end procedure;
    
    procedure prepare_data_packet is
    begin
        if current_data_toggle(to_integer(unsigned(current_endp))) = '0' then
            tx_buffer(7 downto 0) <= PID_DATA0 & not PID_DATA0;
        else
            tx_buffer(7 downto 0) <= PID_DATA1 & not PID_DATA1;
        end if;
        
        -- Toggle data toggle bit
        current_data_toggle(to_integer(unsigned(current_endp))) <= 
            not current_data_toggle(to_integer(unsigned(current_endp)));
    end procedure;
    
    procedure process_packet is
    begin
        case current_pid is
            when PID_SETUP =>
                -- Extract setup packet
                setup_packet <= rx_buffer(63 downto 0);
                control_state <= CTRL_SETUP;
                
            when PID_OUT =>
                -- Handle OUT transaction
                control_state <= CTRL_DATA_OUT;
                
            when PID_IN =>
                -- Handle IN transaction
                control_state <= CTRL_DATA_IN;
                
            when others =>
                null;
        end case;
    end procedure;
    
end behavioral;
```

---

## 🖥️ **USB 2.0 Host Controller**

### EHCI (Enhanced Host Controller Interface) Implementation
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.usb_pkg.all;

entity usb2_host_controller is
    generic (
        NUM_PORTS : integer := 4;
        QH_LIST_SIZE : integer := 32;  -- Queue Head list size
        QTD_LIST_SIZE : integer := 64  -- Queue Transfer Descriptor list size
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- System Bus Interface (AHB/AXI)
        sys_addr    : in  std_logic_vector(31 downto 0);
        sys_wdata   : in  std_logic_vector(31 downto 0);
        sys_rdata   : out std_logic_vector(31 downto 0);
        sys_we      : in  std_logic;
        sys_re      : in  std_logic;
        sys_ready   : out std_logic;
        
        -- USB PHY Interface (ULPI)
        ulpi_data   : inout std_logic_vector(7 downto 0);
        ulpi_dir    : in  std_logic;
        ulpi_nxt    : in  std_logic;
        ulpi_stp    : out std_logic;
        ulpi_clk    : in  std_logic;
        ulpi_rst_n  : out std_logic;
        
        -- Port Status
        port_connect : in  std_logic_vector(NUM_PORTS-1 downto 0);
        port_enable  : out std_logic_vector(NUM_PORTS-1 downto 0);
        port_reset   : out std_logic_vector(NUM_PORTS-1 downto 0);
        port_suspend : out std_logic_vector(NUM_PORTS-1 downto 0);
        
        -- Interrupt
        hc_irq      : out std_logic;
        
        -- Status
        frame_number : out std_logic_vector(13 downto 0);
        hc_halted   : out std_logic
    );
end usb2_host_controller;

architecture behavioral of usb2_host_controller is
    -- EHCI Operational Registers
    signal usbcmd_reg : std_logic_vector(31 downto 0);
    signal usbsts_reg : std_logic_vector(31 downto 0);
    signal usbintr_reg : std_logic_vector(31 downto 0);
    signal frindex_reg : std_logic_vector(13 downto 0);
    signal periodiclistbase_reg : std_logic_vector(31 downto 0);
    signal asynclistaddr_reg : std_logic_vector(31 downto 0);
    signal configflag_reg : std_logic_vector(31 downto 0);
    
    -- Port Status and Control Registers
    type portsc_array is array (0 to NUM_PORTS-1) of std_logic_vector(31 downto 0);
    signal portsc_reg : portsc_array;
    
    -- Host Controller State
    type hc_state_type is (HC_HALT, HC_RESET, HC_OPERATIONAL, HC_SUSPEND);
    signal hc_state : hc_state_type;
    
    -- Frame List and Schedule Management
    type frame_list_type is array (0 to 1023) of std_logic_vector(31 downto 0);
    signal periodic_frame_list : frame_list_type;
    
    -- Queue Head (QH) Structure
    type qh_type is record
        qh_link_ptr : std_logic_vector(31 downto 0);
        ep_char     : std_logic_vector(31 downto 0);
        ep_caps     : std_logic_vector(31 downto 0);
        current_qtd : std_logic_vector(31 downto 0);
        next_qtd    : std_logic_vector(31 downto 0);
        alt_next_qtd : std_logic_vector(31 downto 0);
        qtd_token   : std_logic_vector(31 downto 0);
        buffer_ptr  : std_logic_vector(159 downto 0);  -- 5 x 32-bit buffer pointers
    end record;
    
    type qh_array is array (0 to QH_LIST_SIZE-1) of qh_type;
    signal queue_heads : qh_array;
    
    -- Queue Transfer Descriptor (QTD) Structure
    type qtd_type is record
        next_qtd_ptr : std_logic_vector(31 downto 0);
        alt_next_qtd : std_logic_vector(31 downto 0);
        qtd_token    : std_logic_vector(31 downto 0);
        buffer_ptr   : std_logic_vector(159 downto 0);  -- 5 x 32-bit buffer pointers
    end record;
    
    type qtd_array is array (0 to QTD_LIST_SIZE-1) of qtd_type;
    signal qtd_list : qtd_array;
    
    -- Transaction Processing
    signal current_qh_index : integer range 0 to QH_LIST_SIZE-1;
    signal current_qtd_index : integer range 0 to QTD_LIST_SIZE-1;
    signal transaction_active : std_logic;
    
    -- Frame Counter
    signal frame_counter : unsigned(13 downto 0);
    signal microframe_counter : unsigned(2 downto 0);
    
    -- ULPI Interface State Machine
    type ulpi_state_type is (ULPI_IDLE, ULPI_CMD, ULPI_DATA, ULPI_TURNAROUND);
    signal ulpi_state : ulpi_state_type;
    
begin
    
    -- System Register Interface
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            usbcmd_reg <= (others => '0');
            usbsts_reg <= x"00001000";  -- HC Halted
            usbintr_reg <= (others => '0');
            frindex_reg <= (others => '0');
            periodiclistbase_reg <= (others => '0');
            asynclistaddr_reg <= (others => '0');
            configflag_reg <= (others => '0');
            sys_ready <= '0';
            
        elsif rising_edge(clk) then
            sys_ready <= '0';
            
            if sys_we = '1' then
                case sys_addr(7 downto 0) is
                    when x"00" =>  -- USBCMD
                        usbcmd_reg <= sys_wdata;
                    when x"04" =>  -- USBSTS (write-clear)
                        usbsts_reg <= usbsts_reg and not sys_wdata;
                    when x"08" =>  -- USBINTR
                        usbintr_reg <= sys_wdata;
                    when x"0C" =>  -- FRINDEX
                        frindex_reg <= sys_wdata(13 downto 0);
                    when x"14" =>  -- PERIODICLISTBASE
                        periodiclistbase_reg <= sys_wdata;
                    when x"18" =>  -- ASYNCLISTADDR
                        asynclistaddr_reg <= sys_wdata;
                    when x"40" =>  -- CONFIGFLAG
                        configflag_reg <= sys_wdata;
                    when others =>
                        -- Port registers (0x44 + port*4)
                        if unsigned(sys_addr(7 downto 0)) >= x"44" and 
                           unsigned(sys_addr(7 downto 0)) < x"44" + NUM_PORTS*4 then
                            portsc_reg((to_integer(unsigned(sys_addr(7 downto 0))) - 16#44#)/4) <= sys_wdata;
                        end if;
                end case;
                sys_ready <= '1';
                
            elsif sys_re = '1' then
                case sys_addr(7 downto 0) is
                    when x"00" => sys_rdata <= usbcmd_reg;
                    when x"04" => sys_rdata <= usbsts_reg;
                    when x"08" => sys_rdata <= usbintr_reg;
                    when x"0C" => sys_rdata <= x"00000" & "00" & frindex_reg;
                    when x"14" => sys_rdata <= periodiclistbase_reg;
                    when x"18" => sys_rdata <= asynclistaddr_reg;
                    when x"40" => sys_rdata <= configflag_reg;
                    when others =>
                        if unsigned(sys_addr(7 downto 0)) >= x"44" and 
                           unsigned(sys_addr(7 downto 0)) < x"44" + NUM_PORTS*4 then
                            sys_rdata <= portsc_reg((to_integer(unsigned(sys_addr(7 downto 0))) - 16#44#)/4);
                        else
                            sys_rdata <= (others => '0');
                        end if;
                end case;
                sys_ready <= '1';
            end if;
        end if;
    end process;
    
    -- Host Controller State Machine
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            hc_state <= HC_HALT;
            hc_halted <= '1';
            
        elsif rising_edge(clk) then
            case hc_state is
                when HC_HALT =>
                    hc_halted <= '1';
                    usbsts_reg(12) <= '1';  -- HC Halted bit
                    
                    if usbcmd_reg(0) = '1' then  -- Run/Stop bit
                        hc_state <= HC_OPERATIONAL;
                    elsif usbcmd_reg(1) = '1' then  -- HC Reset bit
                        hc_state <= HC_RESET;
                    end if;
                
                when HC_RESET =>
                    -- Reset all registers and state
                    usbcmd_reg <= (others => '0');
                    usbsts_reg <= x"00001000";
                    frindex_reg <= (others => '0');
                    frame_counter <= (others => '0');
                    microframe_counter <= (others => '0');
                    
                    hc_state <= HC_HALT;
                
                when HC_OPERATIONAL =>
                    hc_halted <= '0';
                    usbsts_reg(12) <= '0';  -- Clear HC Halted bit
                    
                    if usbcmd_reg(0) = '0' then  -- Run/Stop bit cleared
                        hc_state <= HC_HALT;
                    end if;
                    
                    -- Process periodic and asynchronous schedules
                    process_schedules;
                
                when HC_SUSPEND =>
                    -- Suspend state handling
                    if usbcmd_reg(0) = '0' then
                        hc_state <= HC_HALT;
                    end if;
                
                when others =>
                    hc_state <= HC_HALT;
            end case;
        end if;
    end process;
    
    -- Frame Counter (125μs microframes, 1ms frames)
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            frame_counter <= (others => '0');
            microframe_counter <= (others => '0');
            
        elsif rising_edge(clk) then
            if hc_state = HC_OPERATIONAL then
                -- Assuming 60MHz clock, count to 7500 for 125μs
                if microframe_counter = 7 then
                    microframe_counter <= (others => '0');
                    frame_counter <= frame_counter + 1;
                    frindex_reg <= std_logic_vector(frame_counter);
                    
                    -- Generate frame list rollover interrupt
                    if frame_counter = 1023 then
                        usbsts_reg(3) <= '1';  -- Frame List Rollover
                    end if;
                else
                    microframe_counter <= microframe_counter + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- ULPI Interface State Machine
    process(ulpi_clk, rst_n)
    begin
        if rst_n = '0' then
            ulpi_state <= ULPI_IDLE;
            ulpi_stp <= '0';
            ulpi_rst_n <= '0';
            
        elsif rising_edge(ulpi_clk) then
            ulpi_rst_n <= '1';
            
            case ulpi_state is
                when ULPI_IDLE =>
                    ulpi_stp <= '0';
                    
                    if transaction_active = '1' then
                        ulpi_state <= ULPI_CMD;
                    end if;
                
                when ULPI_CMD =>
                    -- Send command to ULPI PHY
                    if ulpi_dir = '0' then
                        ulpi_data <= get_ulpi_command;
                        
                        if ulpi_nxt = '1' then
                            ulpi_state <= ULPI_DATA;
                        end if;
                    end if;
                
                when ULPI_DATA =>
                    -- Transfer data
                    if ulpi_dir = '0' then
                        ulpi_data <= get_tx_data;
                    else
                        store_rx_data(ulpi_data);
                    end if;
                    
                    if transfer_complete then
                        ulpi_stp <= '1';
                        ulpi_state <= ULPI_TURNAROUND;
                    end if;
                
                when ULPI_TURNAROUND =>
                    ulpi_stp <= '0';
                    ulpi_state <= ULPI_IDLE;
                
                when others =>
                    ulpi_state <= ULPI_IDLE;
            end case;
        end if;
    end process;
    
    -- Port Management
    gen_ports: for i in 0 to NUM_PORTS-1 generate
        process(clk, rst_n)
        begin
            if rst_n = '0' then
                portsc_reg(i) <= (others => '0');
                port_enable(i) <= '0';
                port_reset(i) <= '0';
                port_suspend(i) <= '0';
                
            elsif rising_edge(clk) then
                -- Port connection detection
                if port_connect(i) = '1' and portsc_reg(i)(0) = '0' then
                    portsc_reg(i)(0) <= '1';  -- Current Connect Status
                    portsc_reg(i)(1) <= '1';  -- Connect Status Change
                    usbsts_reg(2) <= '1';     -- Port Change Detect
                end if;
                
                -- Port reset control
                if portsc_reg(i)(8) = '1' then  -- Port Reset bit
                    port_reset(i) <= '1';
                    -- Reset timing logic would go here
                else
                    port_reset(i) <= '0';
                end if;
                
                -- Port enable control
                port_enable(i) <= portsc_reg(i)(2);  -- Port Enabled
                port_suspend(i) <= portsc_reg(i)(7); -- Port Suspend
            end if;
        end process;
    end generate;
    
    -- Output assignments
    frame_number <= frindex_reg;
    hc_irq <= '1' when (usbsts_reg and usbintr_reg) /= x"00000000" else '0';
    
    -- Helper procedures and functions
    procedure process_schedules is
    begin
        -- Process periodic schedule (interrupts, isochronous)
        if usbcmd_reg(4) = '1' then  -- Periodic Schedule Enable
            process_periodic_schedule;
        end if;
        
        -- Process asynchronous schedule (control, bulk)
        if usbcmd_reg(5) = '1' then  -- Asynchronous Schedule Enable
            process_async_schedule;
        end if;
    end procedure;
    
    procedure process_periodic_schedule is
        variable frame_index : integer;
    begin
        frame_index := to_integer(frame_counter mod 1024);
        -- Process frame list entry at current frame
        if periodic_frame_list(frame_index) /= x"00000001" then  -- Not terminate
            -- Process periodic transfers
            null;  -- Implementation would traverse the periodic list
        end if;
    end procedure;
    
    procedure process_async_schedule is
    begin
        -- Process asynchronous list starting from asynclistaddr_reg
        if asynclistaddr_reg /= x"00000000" then
            -- Implementation would traverse the async list
            null;
        end if;
    end procedure;
    
    function get_ulpi_command return std_logic_vector is
    begin
        -- Return appropriate ULPI command based on current transaction
        return x"40";  -- Transmit command example
    end function;
    
    function get_tx_data return std_logic_vector is
    begin
        -- Return next byte of transmit data
        return x"00";  -- Placeholder
    end function;
    
    procedure store_rx_data(data : std_logic_vector(7 downto 0)) is
    begin
        -- Store received data byte
        null;  -- Implementation would store to appropriate buffer
    end procedure;
    
    function transfer_complete return boolean is
    begin
        -- Check if current transfer is complete
        return false;  -- Placeholder
    end function;
    
end behavioral;
```

---

## ⚡ **USB 3.0 SuperSpeed Controller**

### USB 3.0 Device Controller with PIPE Interface
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.usb_pkg.all;

entity usb3_superspeed_controller is
    generic (
        NUM_ENDPOINTS : integer := 16;
        MAX_BURST_SIZE : integer := 16
    );
    port (
        -- Clock and Reset
        pipe_pclk   : in  std_logic;  -- PIPE clock (125/250 MHz)
        pipe_rst_n  : in  std_logic;
        
        -- PIPE 3.0 Interface
        pipe_tx_data : out std_logic_vector(31 downto 0);
        pipe_tx_datak : out std_logic_vector(3 downto 0);
        pipe_tx_valid : out std_logic;
        pipe_tx_ready : in  std_logic;
        
        pipe_rx_data : in  std_logic_vector(31 downto 0);
        pipe_rx_datak : in  std_logic_vector(3 downto 0);
        pipe_rx_valid : in  std_logic;
        pipe_rx_active : in  std_logic;
        pipe_rx_error : in  std_logic;
        
        -- PIPE Control
        pipe_power_down : out std_logic_vector(1 downto 0);
        pipe_tx_oneszeros : out std_logic;
        pipe_tx_deemph : out std_logic;
        pipe_tx_margin : out std_logic_vector(2 downto 0);
        pipe_tx_swing : out std_logic;
        pipe_rx_polarity : out std_logic;
        pipe_rx_termination : out std_logic;
        pipe_rate : out std_logic;  -- 0=5Gbps, 1=10Gbps
        pipe_width : out std_logic_vector(1 downto 0);  -- 00=8bit, 01=16bit, 10=32bit
        
        -- PIPE Status
        pipe_phy_status : in  std_logic;
        pipe_rx_elecidle : in  std_logic;
        pipe_rx_status : in  std_logic_vector(2 downto 0);
        
        -- Link Training and Status State Machine (LTSSM)
        ltssm_state : out std_logic_vector(4 downto 0);
        link_up     : out std_logic;
        
        -- Endpoint Interface
        ep_addr     : out std_logic_vector(3 downto 0);
        ep_dir      : out std_logic;  -- 0=OUT, 1=IN
        ep_wdata    : out std_logic_vector(31 downto 0);
        ep_rdata    : in  std_logic_vector(31 downto 0);
        ep_we       : out std_logic;
        ep_re       : out std_logic;
        ep_ready    : in  std_logic_vector(NUM_ENDPOINTS-1 downto 0);
        
        -- Device Configuration
        device_addr : out std_logic_vector(6 downto 0);
        configured  : out std_logic;
        u1_enable   : out std_logic;
        u2_enable   : out std_logic;
        
        -- Interrupt
        usb3_irq    : out std_logic
    );
end usb3_superspeed_controller;

architecture behavioral of usb3_superspeed_controller is
    -- LTSSM States (USB 3.0 Specification)
    constant LTSSM_SS_DISABLED    : std_logic_vector(4 downto 0) := "00000";
    constant LTSSM_SS_INACTIVE    : std_logic_vector(4 downto 0) := "00001";
    constant LTSSM_RX_DETECT      : std_logic_vector(4 downto 0) := "00010";
    constant LTSSM_POLLING        : std_logic_vector(4 downto 0) := "00011";
    constant LTSSM_RECOVERY       : std_logic_vector(4 downto 0) := "00100";
    constant LTSSM_HOT_RESET      : std_logic_vector(4 downto 0) := "00101";
    constant LTSSM_COMPLIANCE     : std_logic_vector(4 downto 0) := "00110";
    constant LTSSM_LOOPBACK       : std_logic_vector(4 downto 0) := "00111";
    constant LTSSM_U0             : std_logic_vector(4 downto 0) := "01000";
    constant LTSSM_U1             : std_logic_vector(4 downto 0) := "01001";
    constant LTSSM_U2             : std_logic_vector(4 downto 0) := "01010";
    constant LTSSM_U3             : std_logic_vector(4 downto 0) := "01011";
    
    signal current_ltssm_state : std_logic_vector(4 downto 0);
    
    -- USB 3.0 Link Layer
    type link_state_type is (LINK_IDLE, LINK_HEADER, LINK_DATA, LINK_CRC, LINK_EOP);
    signal link_state : link_state_type;
    
    -- Header Packet (HP) Structure
    signal hp_type : std_logic_vector(4 downto 0);
    signal hp_subtype : std_logic_vector(3 downto 0);
    signal hp_route_string : std_logic_vector(19 downto 0);
    signal hp_device_addr : std_logic_vector(6 downto 0);
    signal hp_endpoint : std_logic_vector(3 downto 0);
    signal hp_dir : std_logic;
    signal hp_seq_num : std_logic_vector(4 downto 0);
    
    -- Data Packet (DP) Structure
    signal dp_type : std_logic_vector(4 downto 0);
    signal dp_subtype : std_logic_vector(3 downto 0);
    signal dp_data_length : std_logic_vector(15 downto 0);
    signal dp_seq_num : std_logic_vector(4 downto 0);
    
    -- Transaction Processing
    signal current_transaction : std_logic_vector(31 downto 0);
    signal transaction_buffer : std_logic_vector(1023 downto 0);
    signal buffer_count : unsigned(9 downto 0);
    
    -- Flow Control
    signal tx_seq_num : unsigned(4 downto 0);
    signal rx_seq_num : unsigned(4 downto 0);
    signal ack_pending : std_logic;
    signal nrdy_pending : std_logic;
    
    -- Power Management
    signal u1_timeout : unsigned(7 downto 0);
    signal u2_timeout : unsigned(7 downto 0);
    signal lpm_enable : std_logic;
    
    -- Device Configuration
    signal dev_addr_reg : std_logic_vector(6 downto 0);
    signal config_reg : std_logic_vector(7 downto 0);
    
begin
    
    -- LTSSM (Link Training and Status State Machine)
    process(pipe_pclk, pipe_rst_n)
        variable timeout_counter : unsigned(15 downto 0);
    begin
        if pipe_rst_n = '0' then
            current_ltssm_state <= LTSSM_SS_DISABLED;
            timeout_counter := (others => '0');
            link_up <= '0';
            
        elsif rising_edge(pipe_pclk) then
            timeout_counter := timeout_counter + 1;
            
            case current_ltssm_state is
                when LTSSM_SS_DISABLED =>
                    link_up <= '0';
                    pipe_power_down <= "11";  -- P3 state
                    
                    if pipe_phy_status = '1' then
                        current_ltssm_state <= LTSSM_RX_DETECT;
                        timeout_counter := (others => '0');
                    end if;
                
                when LTSSM_RX_DETECT =>
                    pipe_power_down <= "01";  -- P1 state
                    
                    if pipe_rx_elecidle = '0' then
                        current_ltssm_state <= LTSSM_POLLING;
                        timeout_counter := (others => '0');
                    elsif timeout_counter = 12000 then  -- 12ms timeout
                        current_ltssm_state <= LTSSM_SS_DISABLED;
                    end if;
                
                when LTSSM_POLLING =>
                    pipe_power_down <= "00";  -- P0 state
                    
                    -- Send LFPS (Low Frequency Periodic Signaling)
                    send_lfps_polling;
                    
                    if detect_lfps_response then
                        current_ltssm_state <= LTSSM_U0;
                        link_up <= '1';
                    elsif timeout_counter = 360000 then  -- 360ms timeout
                        current_ltssm_state <= LTSSM_SS_DISABLED;
                    end if;
                
                when LTSSM_U0 =>
                    -- Normal operation state
                    link_up <= '1';
                    pipe_power_down <= "00";
                    
                    -- Check for power management transitions
                    if lmp_u1_request then
                        current_ltssm_state <= LTSSM_U1;
                    elsif lmp_u2_request then
                        current_ltssm_state <= LTSSM_U2;
                    elsif detect_recovery_condition then
                        current_ltssm_state <= LTSSM_RECOVERY;
                    end if;
                
                when LTSSM_U1 =>
                    -- U1 low power state
                    pipe_power_down <= "01";
                    
                    if u1_timeout = 0 or detect_exit_condition then
                        current_ltssm_state <= LTSSM_U0;
                    end if;
                
                when LTSSM_U2 =>
                    -- U2 low power state
                    pipe_power_down <= "10";
                    
                    if u2_timeout = 0 or detect_exit_condition then
                        current_ltssm_state <= LTSSM_U0;
                    end if;
                
                when LTSSM_U3 =>
                    -- U3 suspend state
                    pipe_power_down <= "11";
                    link_up <= '0';
                    
                    if detect_resume_signaling then
                        current_ltssm_state <= LTSSM_RECOVERY;
                    end if;
                
                when LTSSM_RECOVERY =>
                    -- Link recovery state
                    send_recovery_sequence;
                    
                    if recovery_successful then
                        current_ltssm_state <= LTSSM_U0;
                    elsif timeout_counter = 50000 then  -- 50ms timeout
                        current_ltssm_state <= LTSSM_SS_DISABLED;
                    end if;
                
                when others =>
                    current_ltssm_state <= LTSSM_SS_DISABLED;
            end case;
        end if;
    end process;
    
    -- Link Layer Packet Processing
    process(pipe_pclk, pipe_rst_n)
    begin
        if pipe_rst_n = '0' then
            link_state <= LINK_IDLE;
            tx_seq_num <= (others => '0');
            rx_seq_num <= (others => '0');
            buffer_count <= (others => '0');
            
        elsif rising_edge(pipe_pclk) then
            case link_state is
                when LINK_IDLE =>
                    if current_ltssm_state = LTSSM_U0 then
                        if pipe_rx_valid = '1' and pipe_rx_active = '1' then
                            -- Start receiving packet
                            link_state <= LINK_HEADER;
                            buffer_count <= (others => '0');
                        elsif endpoint_has_data then
                            -- Start transmitting packet
                            link_state <= LINK_HEADER;
                            prepare_tx_header;
                        end if;
                    end if;
                
                when LINK_HEADER =>
                    if pipe_rx_valid = '1' then
                        -- Receive header packet
                        parse_header_packet(pipe_rx_data);
                        link_state <= LINK_DATA;
                    elsif pipe_tx_ready = '1' then
                        -- Transmit header packet
                        pipe_tx_data <= get_tx_header;
                        pipe_tx_valid <= '1';
                        link_state <= LINK_DATA;
                    end if;
                
                when LINK_DATA =>
                    if pipe_rx_valid = '1' then
                        -- Receive data
                        transaction_buffer(to_integer(buffer_count)*32+31 downto to_integer(buffer_count)*32) <= pipe_rx_data;
                        buffer_count <= buffer_count + 1;
                        
                        if is_end_of_packet then
                            link_state <= LINK_CRC;
                        end if;
                    elsif pipe_tx_ready = '1' then
                        -- Transmit data
                        pipe_tx_data <= get_tx_data;
                        pipe_tx_valid <= '1';
                        
                        if tx_data_complete then
                            link_state <= LINK_CRC;
                        end if;
                    end if;
                
                when LINK_CRC =>
                    -- Handle CRC validation/generation
                    if validate_crc then
                        link_state <= LINK_EOP;
                        send_ack_packet;
                    else
                        link_state <= LINK_IDLE;
                        send_nack_packet;
                    end if;
                
                when LINK_EOP =>
                    -- End of packet processing
                    process_received_packet;
                    link_state <= LINK_IDLE;
                
                when others =>
                    link_state <= LINK_IDLE;
            end case;
        end if;
    end process;
    
    -- Endpoint Management
    process(pipe_pclk, pipe_rst_n)
    begin
        if pipe_rst_n = '0' then
            ep_addr <= (others => '0');
            ep_dir <= '0';
            ep_we <= '0';
            ep_re <= '0';
            
        elsif rising_edge(pipe_pclk) then
            ep_we <= '0';
            ep_re <= '0';
            
            -- Handle endpoint operations based on received packets
            if link_state = LINK_EOP then
                case hp_type is
                    when "00001" =>  -- Normal transaction
                        ep_addr <= hp_endpoint;
                        ep_dir <= hp_dir;
                        
                        if hp_dir = '0' then  -- OUT
                            ep_wdata <= transaction_buffer(31 downto 0);
                            ep_we <= '1';
                        else  -- IN
                            ep_re <= '1';
                        end if;
                    
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;
    
    -- Power Management
    process(pipe_pclk, pipe_rst_n)
    begin
        if pipe_rst_n = '0' then
            u1_timeout <= (others => '0');
            u2_timeout <= (others => '0');
            lmp_enable <= '0';
            u1_enable <= '0';
            u2_enable <= '0';
            
        elsif rising_edge(pipe_pclk) then
            -- U1/U2 timeout management
            if current_ltssm_state = LTSSM_U1 and u1_timeout > 0 then
                u1_timeout <= u1_timeout - 1;
            elsif current_ltssm_state = LTSSM_U2 and u2_timeout > 0 then
                u2_timeout <= u2_timeout - 1;
            end if;
            
            -- Enable U1/U2 based on configuration
            u1_enable <= lmp_enable and config_reg(0);
            u2_enable <= lmp_enable and config_reg(1);
        end if;
    end process;
    
    -- Output assignments
    ltssm_state <= current_ltssm_state;
    device_addr <= dev_addr_reg;
    configured <= '1' when config_reg /= x"00" else '0';
    
    -- PIPE Interface Configuration
    pipe_rate <= '0';  -- 5 Gbps SuperSpeed
    pipe_width <= "10";  -- 32-bit width
    pipe_tx_oneszeros <= '0';
    pipe_tx_deemph <= '0';
    pipe_tx_margin <= "000";
    pipe_tx_swing <= '0';
    pipe_rx_polarity <= '0';
    pipe_rx_termination <= '1';
    
    -- Helper functions and procedures
    procedure send_lfps_polling is
    begin
        -- Send Low Frequency Periodic Signaling for polling
        pipe_tx_data <= x"4B4B4B4B";  -- K28.5 comma symbols
        pipe_tx_datak <= "1111";
        pipe_tx_valid <= '1';
    end procedure;
    
    function detect_lfps_response return boolean is
    begin
        -- Detect LFPS response from link partner
        return pipe_rx_valid = '1' and pipe_rx_data = x"4B4B4B4B";
    end function;
    
    function lmp_u1_request return boolean is
    begin
        -- Check for Link Management Packet U1 request
        return false;  -- Placeholder
    end function;
    
    function lmp_u2_request return boolean is
    begin
        -- Check for Link Management Packet U2 request
        return false;  -- Placeholder
    end function;
    
    function detect_recovery_condition return boolean is
    begin
        -- Detect conditions requiring link recovery
        return pipe_rx_error = '1';
    end function;
    
    function detect_exit_condition return boolean is
    begin
        -- Detect conditions for exiting low power states
        return pipe_rx_active = '1';
    end function;
    
    function detect_resume_signaling return boolean is
    begin
        -- Detect resume signaling from suspend
        return pipe_rx_elecidle = '0';
    end function;
    
    procedure send_recovery_sequence is
    begin
        -- Send recovery sequence
        pipe_tx_data <= x"555555D5";  -- Recovery pattern
        pipe_tx_datak <= "0001";
        pipe_tx_valid <= '1';
    end procedure;
    
    function recovery_successful return boolean is
    begin
        -- Check if recovery was successful
        return pipe_rx_status = "000";
    end function;
    
    function endpoint_has_data return boolean is
    begin
        -- Check if any endpoint has data to transmit
        return ep_ready /= (ep_ready'range => '0');
    end function;
    
    procedure prepare_tx_header is
    begin
        -- Prepare transmission header
        hp_type <= "00001";  -- Normal transaction
        hp_device_addr <= dev_addr_reg;
        hp_seq_num <= std_logic_vector(tx_seq_num);
    end procedure;
    
    procedure parse_header_packet(data : std_logic_vector(31 downto 0)) is
    begin
        -- Parse received header packet
        hp_type <= data(4 downto 0);
        hp_subtype <= data(8 downto 5);
        hp_device_addr <= data(15 downto 9);
        hp_endpoint <= data(19 downto 16);
        hp_dir <= data(20);
        hp_seq_num <= data(25 downto 21);
    end procedure;
    
    function get_tx_header return std_logic_vector is
    begin
        -- Return formatted header packet
        return hp_seq_num & hp_dir & hp_endpoint & hp_device_addr & "00" & hp_subtype & hp_type;
    end function;
    
    function get_tx_data return std_logic_vector is
    begin
        -- Return next 32-bit word of transmit data
        return ep_rdata;
    end function;
    
    function is_end_of_packet return boolean is
    begin
        -- Check if end of packet received
        return pipe_rx_datak /= "0000";
    end function;
    
    function tx_data_complete return boolean is
    begin
        -- Check if transmission is complete
        return buffer_count = 0;  -- Placeholder
    end function;
    
    function validate_crc return boolean is
    begin
        -- Validate received CRC
        return true;  -- Placeholder
    end function;
    
    procedure send_ack_packet is
    begin
        -- Send ACK packet
        pipe_tx_data <= x"00000000" & "000" & std_logic_vector(rx_seq_num) & "0010" & "00010";
        pipe_tx_datak <= "0000";
        pipe_tx_valid <= '1';
    end procedure;
    
    procedure send_nack_packet is
    begin
        -- Send NACK packet
        pipe_tx_data <= x"00000000" & "000" & std_logic_vector(rx_seq_num) & "0011" & "00010";
        pipe_tx_datak <= "0000";
        pipe_tx_valid <= '1';
    end procedure;
    
    procedure process_received_packet is
    begin
        -- Process the received packet based on type
        case hp_type is
            when "00001" =>  -- Normal transaction
                if hp_device_addr = dev_addr_reg then
                    -- Handle transaction for this device
                    rx_seq_num <= rx_seq_num + 1;
                end if;
            when others =>
                null;
        end case;
    end procedure;
    
end behavioral;
```

---

## 📚 **USB Protocol Stack**

### USB Protocol Layer Implementation
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.usb_pkg.all;

entity usb_protocol_stack is
    generic (
        USB_VERSION : integer := 3;  -- 2 for USB 2.0, 3 for USB 3.0
        MAX_PACKET_SIZE : integer := 1024
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Physical Layer Interface
        phy_tx_data : out std_logic_vector(31 downto 0);
        phy_tx_valid : out std_logic;
        phy_tx_ready : in  std_logic;
        phy_rx_data : in  std_logic_vector(31 downto 0);
        phy_rx_valid : in  std_logic;
        phy_rx_error : in  std_logic;
        
        -- Application Layer Interface
        app_tx_data : in  std_logic_vector(31 downto 0);
        app_tx_valid : in  std_logic;
        app_tx_ready : out std_logic;
        app_rx_data : out std_logic_vector(31 downto 0);
        app_rx_valid : out std_logic;
        app_rx_ready : in  std_logic;
        
        -- Control Interface
        device_addr : in  std_logic_vector(6 downto 0);
        endpoint    : in  std_logic_vector(3 downto 0);
        transfer_type : in  endpoint_type;
        
        -- Status
        protocol_error : out std_logic;
        crc_error     : out std_logic
    );
end usb_protocol_stack;

architecture behavioral of usb_protocol_stack is
    -- Protocol State Machine
    type protocol_state_type is (IDLE, HEADER_TX, DATA_TX, CRC_TX, HEADER_RX, DATA_RX, CRC_RX);
    signal protocol_state : protocol_state_type;
    
    -- Packet Buffers
    signal tx_buffer : std_logic_vector(MAX_PACKET_SIZE*8-1 downto 0);
    signal rx_buffer : std_logic_vector(MAX_PACKET_SIZE*8-1 downto 0);
    signal tx_count : unsigned(15 downto 0);
    signal rx_count : unsigned(15 downto 0);
    
    -- CRC Calculation
    signal crc16_tx : std_logic_vector(15 downto 0);
    signal crc16_rx : std_logic_vector(15 downto 0);
    signal crc32_tx : std_logic_vector(31 downto 0);
    signal crc32_rx : std_logic_vector(31 downto 0);
    
    -- Packet Header
    signal packet_header : std_logic_vector(31 downto 0);
    
begin
    
    -- Protocol State Machine
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            protocol_state <= IDLE;
            tx_count <= (others => '0');
            rx_count <= (others => '0');
            phy_tx_valid <= '0';
            app_tx_ready <= '0';
            app_rx_valid <= '0';
            protocol_error <= '0';
            crc_error <= '0';
            
        elsif rising_edge(clk) then
            case protocol_state is
                when IDLE =>
                    phy_tx_valid <= '0';
                    app_tx_ready <= '1';
                    
                    if app_tx_valid = '1' then
                        -- Start transmission
                        protocol_state <= HEADER_TX;
                        prepare_packet_header;
                        tx_count <= (others => '0');
                    elsif phy_rx_valid = '1' then
                        -- Start reception
                        protocol_state <= HEADER_RX;
                        rx_count <= (others => '0');
                    end if;
                
                when HEADER_TX =>
                    if phy_tx_ready = '1' then
                        phy_tx_data <= packet_header;
                        phy_tx_valid <= '1';
                        protocol_state <= DATA_TX;
                    end if;
                
                when DATA_TX =>
                    app_tx_ready <= '1';
                    
                    if app_tx_valid = '1' and phy_tx_ready = '1' then
                        phy_tx_data <= app_tx_data;
                        phy_tx_valid <= '1';
                        
                        -- Update CRC
                        if USB_VERSION = 2 then
                            crc16_tx <= calculate_crc16(crc16_tx, app_tx_data);
                        else
                            crc32_tx <= calculate_crc32(crc32_tx, app_tx_data);
                        end if;
                        
                        tx_count <= tx_count + 1;
                        
                        if is_last_data_word then
                            protocol_state <= CRC_TX;
                            app_tx_ready <= '0';
                        end if;
                    end if;
                
                when CRC_TX =>
                    if phy_tx_ready = '1' then
                        if USB_VERSION = 2 then
                            phy_tx_data <= x"0000" & crc16_tx;
                        else
                            phy_tx_data <= crc32_tx;
                        end if;
                        phy_tx_valid <= '1';
                        protocol_state <= IDLE;
                    end if;
                
                when HEADER_RX =>
                    if phy_rx_valid = '1' then
                        packet_header <= phy_rx_data;
                        
                        if validate_packet_header then
                            protocol_state <= DATA_RX;
                        else
                            protocol_error <= '1';
                            protocol_state <= IDLE;
                        end if;
                    end if;
                
                when DATA_RX =>
                    if phy_rx_valid = '1' then
                        rx_buffer(to_integer(rx_count)*32+31 downto to_integer(rx_count)*32) <= phy_rx_data;
                        
                        -- Update CRC
                        if USB_VERSION = 2 then
                            crc16_rx <= calculate_crc16(crc16_rx, phy_rx_data);
                        else
                            crc32_rx <= calculate_crc32(crc32_rx, phy_rx_data);
                        end if;
                        
                        rx_count <= rx_count + 1;
                        
                        if is_end_of_data then
                            protocol_state <= CRC_RX;
                        end if;
                    end if;
                
                when CRC_RX =>
                    if phy_rx_valid = '1' then
                        if USB_VERSION = 2 then
                            if phy_rx_data(15 downto 0) /= crc16_rx then
                                crc_error <= '1';
                            end if;
                        else
                            if phy_rx_data /= crc32_rx then
                                crc_error <= '1';
                            end if;
                        end if;
                        
                        -- Forward received data to application
                        forward_rx_data;
                        protocol_state <= IDLE;
                    end if;
                
                when others =>
                    protocol_state <= IDLE;
            end case;
        end if;
    end process;
    
    -- Helper procedures and functions
    procedure prepare_packet_header is
    begin
        if USB_VERSION = 2 then
            -- USB 2.0 token packet format
            packet_header <= x"0000" & "0" & endpoint & device_addr & "0001";  -- OUT token
        else
            -- USB 3.0 header packet format
            packet_header <= "00000" & endpoint & device_addr & "0000" & "00001";
        end if;
    end procedure;
    
    function validate_packet_header return boolean is
    begin
        -- Validate received packet header
        if USB_VERSION = 2 then
            return packet_header(6 downto 0) = device_addr;
        else
            return packet_header(15 downto 9) = device_addr;
        end if;
    end function;
    
    function is_last_data_word return boolean is
    begin
        -- Determine if this is the last data word
        return tx_count >= 16;  -- Placeholder logic
    end function;
    
    function is_end_of_data return boolean is
    begin
        -- Determine if end of data reached
        return rx_count >= 16;  -- Placeholder logic
    end function;
    
    procedure forward_rx_data is
    begin
        -- Forward received data to application layer
        app_rx_data <= rx_buffer(31 downto 0);
        app_rx_valid <= '1';
    end procedure;
    
    function calculate_crc16(current_crc : std_logic_vector(15 downto 0);
                           data : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable new_crc : std_logic_vector(15 downto 0);
    begin
        -- CRC-16 calculation (simplified)
        new_crc := current_crc xor data(15 downto 0);
        return new_crc;
    end function;
    
    function calculate_crc32(current_crc : std_logic_vector(31 downto 0);
                           data : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable new_crc : std_logic_vector(31 downto 0);
    begin
        -- CRC-32 calculation (simplified)
        new_crc := current_crc xor data;
        return new_crc;
    end function;
    
---

## 🔄 **USB Packet Processing**

### USB Packet Parser and Generator
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.usb_pkg.all;

entity usb_packet_processor is
    generic (
        MAX_PACKET_SIZE : integer := 1024
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Raw Data Interface
        raw_data_in : in  std_logic_vector(7 downto 0);
        raw_valid_in : in  std_logic;
        raw_ready_out : out std_logic;
        
        raw_data_out : out std_logic_vector(7 downto 0);
        raw_valid_out : out std_logic;
        raw_ready_in : in  std_logic;
        
        -- Parsed Packet Interface
        packet_type : out std_logic_vector(3 downto 0);
        packet_addr : out std_logic_vector(6 downto 0);
        packet_endp : out std_logic_vector(3 downto 0);
        packet_data : out std_logic_vector(MAX_PACKET_SIZE*8-1 downto 0);
        packet_length : out std_logic_vector(15 downto 0);
        packet_valid : out std_logic;
        packet_error : out std_logic;
        
        -- Packet Generation Interface
        gen_type : in  std_logic_vector(3 downto 0);
        gen_addr : in  std_logic_vector(6 downto 0);
        gen_endp : in  std_logic_vector(3 downto 0);
        gen_data : in  std_logic_vector(MAX_PACKET_SIZE*8-1 downto 0);
        gen_length : in  std_logic_vector(15 downto 0);
        gen_start : in  std_logic;
        gen_ready : out std_logic
    );
end usb_packet_processor;

architecture behavioral of usb_packet_processor is
    -- Packet Parser State Machine
    type parser_state_type is (IDLE, SYNC, PID, TOKEN, DATA, CRC5, CRC16, EOP);
    signal parser_state : parser_state_type;
    
    -- Packet Generator State Machine
    type generator_state_type is (GEN_IDLE, GEN_SYNC, GEN_PID, GEN_TOKEN, GEN_DATA, GEN_CRC, GEN_EOP);
    signal generator_state : generator_state_type;
    
    -- Parser Registers
    signal rx_buffer : std_logic_vector(MAX_PACKET_SIZE*8-1 downto 0);
    signal rx_count : unsigned(15 downto 0);
    signal rx_pid : std_logic_vector(7 downto 0);
    signal rx_token : std_logic_vector(15 downto 0);
    signal rx_crc5 : std_logic_vector(4 downto 0);
    signal rx_crc16 : std_logic_vector(15 downto 0);
    signal calc_crc5 : std_logic_vector(4 downto 0);
    signal calc_crc16 : std_logic_vector(15 downto 0);
    
    -- Generator Registers
    signal tx_buffer : std_logic_vector(MAX_PACKET_SIZE*8-1 downto 0);
    signal tx_count : unsigned(15 downto 0);
    signal tx_length : unsigned(15 downto 0);
    signal tx_pid : std_logic_vector(7 downto 0);
    signal tx_token : std_logic_vector(15 downto 0);
    signal tx_crc5 : std_logic_vector(4 downto 0);
    signal tx_crc16 : std_logic_vector(15 downto 0);
    
    -- Control Signals
    signal sync_detected : std_logic;
    signal eop_detected : std_logic;
    signal bit_stuff_error : std_logic;
    
begin
    
    -- USB Packet Parser
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            parser_state <= IDLE;
            rx_count <= (others => '0');
            packet_valid <= '0';
            packet_error <= '0';
            raw_ready_out <= '1';
            
        elsif rising_edge(clk) then
            case parser_state is
                when IDLE =>
                    raw_ready_out <= '1';
                    packet_valid <= '0';
                    packet_error <= '0';
                    
                    if raw_valid_in = '1' and raw_data_in = x"80" then  -- SYNC pattern
                        parser_state <= SYNC;
                        sync_detected <= '1';
                    end if;
                
                when SYNC =>
                    if raw_valid_in = '1' then
                        rx_pid <= raw_data_in;
                        parser_state <= PID;
                        rx_count <= (others => '0');
                    end if;
                
                when PID =>
                    -- Validate PID
                    if validate_pid(rx_pid) then
                        case get_packet_type(rx_pid) is
                            when TOKEN_PACKET =>
                                parser_state <= TOKEN;
                            when DATA_PACKET =>
                                parser_state <= DATA;
                            when HANDSHAKE_PACKET =>
                                parser_state <= EOP;
                            when SPECIAL_PACKET =>
                                parser_state <= EOP;
                            when others =>
                                packet_error <= '1';
                                parser_state <= IDLE;
                        end case;
                    else
                        packet_error <= '1';
                        parser_state <= IDLE;
                    end if;
                
                when TOKEN =>
                    if raw_valid_in = '1' then
                        if rx_count < 2 then
                            rx_token(to_integer(rx_count)*8+7 downto to_integer(rx_count)*8) <= raw_data_in;
                            rx_count <= rx_count + 1;
                        else
                            rx_crc5 <= raw_data_in(4 downto 0);
                            parser_state <= CRC5;
                        end if;
                    end if;
                
                when DATA =>
                    if raw_valid_in = '1' then
                        if eop_detected = '0' then
                            rx_buffer(to_integer(rx_count)*8+7 downto to_integer(rx_count)*8) <= raw_data_in;
                            rx_count <= rx_count + 1;
                            
                            -- Update CRC16 calculation
                            calc_crc16 <= update_crc16(calc_crc16, raw_data_in);
                        else
                            parser_state <= CRC16;
                        end if;
                    end if;
                
                when CRC5 =>
                    -- Validate CRC5 for token packets
                    calc_crc5 <= calculate_crc5(rx_token);
                    
                    if calc_crc5 = rx_crc5 then
                        -- Extract address and endpoint
                        packet_addr <= rx_token(6 downto 0);
                        packet_endp <= rx_token(10 downto 7);
                        packet_type <= get_packet_type(rx_pid);
                        packet_valid <= '1';
                    else
                        packet_error <= '1';
                    end if;
                    
                    parser_state <= IDLE;
                
                when CRC16 =>
                    if raw_valid_in = '1' then
                        if rx_count = 0 then
                            rx_crc16(7 downto 0) <= raw_data_in;
                            rx_count <= rx_count + 1;
                        else
                            rx_crc16(15 downto 8) <= raw_data_in;
                            
                            -- Validate CRC16
                            if calc_crc16 = rx_crc16 then
                                packet_data <= rx_buffer;
                                packet_length <= std_logic_vector(rx_count - 2);  -- Exclude CRC bytes
                                packet_type <= get_packet_type(rx_pid);
                                packet_valid <= '1';
                            else
                                packet_error <= '1';
                            end if;
                            
                            parser_state <= IDLE;
                        end if;
                    end if;
                
                when EOP =>
                    -- Handle end of packet for handshake/special packets
                    packet_type <= get_packet_type(rx_pid);
                    packet_valid <= '1';
                    parser_state <= IDLE;
                
                when others =>
                    parser_state <= IDLE;
            end case;
        end if;
    end process;
    
    -- USB Packet Generator
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            generator_state <= GEN_IDLE;
            tx_count <= (others => '0');
            raw_valid_out <= '0';
            gen_ready <= '1';
            
        elsif rising_edge(clk) then
            case generator_state is
                when GEN_IDLE =>
                    gen_ready <= '1';
                    raw_valid_out <= '0';
                    
                    if gen_start = '1' then
                        generator_state <= GEN_SYNC;
                        tx_length <= unsigned(gen_length);
                        tx_buffer <= gen_data;
                        tx_count <= (others => '0');
                        gen_ready <= '0';
                        
                        -- Prepare PID based on packet type
                        case gen_type is
                            when x"1" => tx_pid <= x"E1";  -- OUT token
                            when x"9" => tx_pid <= x"69";  -- IN token
                            when x"D" => tx_pid <= x"2D";  -- SETUP token
                            when x"3" => tx_pid <= x"C3";  -- DATA0
                            when x"B" => tx_pid <= x"4B";  -- DATA1
                            when x"2" => tx_pid <= x"D2";  -- ACK
                            when x"A" => tx_pid <= x"5A";  -- NAK
                            when others => tx_pid <= x"00";
                        end case;
                    end if;
                
                when GEN_SYNC =>
                    if raw_ready_in = '1' then
                        raw_data_out <= x"80";  -- SYNC pattern
                        raw_valid_out <= '1';
                        generator_state <= GEN_PID;
                    end if;
                
                when GEN_PID =>
                    if raw_ready_in = '1' then
                        raw_data_out <= tx_pid;
                        raw_valid_out <= '1';
                        
                        case gen_type is
                            when x"1" | x"9" | x"D" =>  -- Token packets
                                generator_state <= GEN_TOKEN;
                                -- Prepare token data
                                tx_token <= gen_endp & gen_addr & "00000";
                            when x"3" | x"B" =>  -- Data packets
                                generator_state <= GEN_DATA;
                            when others =>  -- Handshake packets
                                generator_state <= GEN_EOP;
                        end case;
                    end if;
                
                when GEN_TOKEN =>
                    if raw_ready_in = '1' then
                        if tx_count < 2 then
                            raw_data_out <= tx_token(to_integer(tx_count)*8+7 downto to_integer(tx_count)*8);
                            raw_valid_out <= '1';
                            tx_count <= tx_count + 1;
                        else
                            -- Send CRC5
                            tx_crc5 <= calculate_crc5(tx_token);
                            raw_data_out <= "000" & tx_crc5;
                            raw_valid_out <= '1';
                            generator_state <= GEN_EOP;
                        end if;
                    end if;
                
                when GEN_DATA =>
                    if raw_ready_in = '1' then
                        if tx_count < tx_length then
                            raw_data_out <= tx_buffer(to_integer(tx_count)*8+7 downto to_integer(tx_count)*8);
                            raw_valid_out <= '1';
                            tx_count <= tx_count + 1;
                            
                            -- Update CRC16
                            tx_crc16 <= update_crc16(tx_crc16, raw_data_out);
                        else
                            generator_state <= GEN_CRC;
                            tx_count <= (others => '0');
                        end if;
                    end if;
                
                when GEN_CRC =>
                    if raw_ready_in = '1' then
                        if tx_count = 0 then
                            raw_data_out <= tx_crc16(7 downto 0);
                            raw_valid_out <= '1';
                            tx_count <= tx_count + 1;
                        else
                            raw_data_out <= tx_crc16(15 downto 8);
                            raw_valid_out <= '1';
                            generator_state <= GEN_EOP;
                        end if;
                    end if;
                
                when GEN_EOP =>
                    -- End of packet handling
                    raw_valid_out <= '0';
                    generator_state <= GEN_IDLE;
                
                when others =>
                    generator_state <= GEN_IDLE;
            end case;
        end if;
    end process;
    
    -- Helper Functions
    function validate_pid(pid : std_logic_vector(7 downto 0)) return boolean is
    begin
        -- Check if PID and its complement are valid
        return pid(3 downto 0) = not pid(7 downto 4);
    end function;
    
    function get_packet_type(pid : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        case pid(3 downto 0) is
            when x"1" | x"9" | x"5" | x"D" => return x"1";  -- Token
            when x"3" | x"B" | x"7" | x"F" => return x"2";  -- Data
            when x"2" | x"A" | x"E" | x"6" => return x"3";  -- Handshake
            when x"C" | x"4" | x"8" | x"0" => return x"4";  -- Special
            when others => return x"0";  -- Invalid
        end case;
    end function;
    
    function calculate_crc5(data : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable crc : std_logic_vector(4 downto 0) := "11111";
        variable temp : std_logic;
    begin
        for i in 0 to 10 loop  -- 11 bits of data (7-bit addr + 4-bit endp)
            temp := crc(4) xor data(i);
            crc := crc(3 downto 0) & '0';
            if temp = '1' then
                crc := crc xor "00101";  -- CRC5 polynomial
            end if;
        end loop;
        return not crc;  -- Invert final result
    end function;
    
    function update_crc16(current_crc : std_logic_vector(15 downto 0);
                         data_byte : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable crc : std_logic_vector(15 downto 0) := current_crc;
        variable temp : std_logic;
    begin
        for i in 0 to 7 loop
            temp := crc(15) xor data_byte(i);
            crc := crc(14 downto 0) & '0';
            if temp = '1' then
                crc := crc xor x"8005";  -- CRC16 polynomial
            end if;
        end loop;
        return crc;
    end function;
    
end behavioral;
```

---

## 🔌 **USB PHY Interface**

### ULPI (UTMI+ Low Pin Interface) Controller
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ulpi_controller is
    port (
        clk         : in  std_logic;  -- 60MHz ULPI clock
        rst_n       : in  std_logic;
        
        -- ULPI Interface
        ulpi_data   : inout std_logic_vector(7 downto 0);
        ulpi_dir    : in  std_logic;
        ulpi_nxt    : in  std_logic;
        ulpi_stp    : out std_logic;
        ulpi_reset  : out std_logic;
        
        -- USB Controller Interface
        usb_tx_data : in  std_logic_vector(7 downto 0);
        usb_tx_valid : in  std_logic;
        usb_tx_ready : out std_logic;
        usb_rx_data : out std_logic_vector(7 downto 0);
        usb_rx_valid : out std_logic;
        usb_rx_active : out std_logic;
        usb_rx_error : out std_logic;
        
        -- Control and Status
        line_state  : out std_logic_vector(1 downto 0);
        vbus_valid  : out std_logic;
        session_end : out std_logic;
        id_dig      : out std_logic;
        
        -- Register Access
        reg_addr    : in  std_logic_vector(5 downto 0);
        reg_data_in : in  std_logic_vector(7 downto 0);
        reg_data_out : out std_logic_vector(7 downto 0);
        reg_write   : in  std_logic;
        reg_read    : in  std_logic;
        reg_ack     : out std_logic
    );
end ulpi_controller;

architecture behavioral of ulpi_controller is
    -- ULPI State Machine
    type ulpi_state_type is (IDLE, TX_CMD, TX_DATA, RX_DATA, REG_WRITE, REG_READ);
    signal ulpi_state : ulpi_state_type;
    
    -- ULPI Command Encoding
    constant CMD_TRANSMIT : std_logic_vector(1 downto 0) := "01";
    constant CMD_REG_WRITE : std_logic_vector(1 downto 0) := "10";
    constant CMD_REG_READ : std_logic_vector(1 downto 0) := "11";
    
    -- Internal Signals
    signal data_out_reg : std_logic_vector(7 downto 0);
    signal data_out_en : std_logic;
    signal tx_active : std_logic;
    signal rx_cmd : std_logic_vector(7 downto 0);
    
    -- Status Registers
    signal interrupt_status : std_logic_vector(7 downto 0);
    signal function_control : std_logic_vector(7 downto 0);
    signal otg_control : std_logic_vector(7 downto 0);
    
    -- Timing Counters
    signal reset_counter : unsigned(7 downto 0);
    signal turnaround_counter : unsigned(3 downto 0);
    
begin
    
    -- ULPI Data Bus Control
    ulpi_data <= data_out_reg when data_out_en = '1' else (others => 'Z');
    
    -- Reset Generation
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            reset_counter <= (others => '0');
            ulpi_reset <= '0';
        elsif rising_edge(clk) then
            if reset_counter < 255 then
                reset_counter <= reset_counter + 1;
                ulpi_reset <= '1';
            else
                ulpi_reset <= '0';
            end if;
        end if;
    end process;
    
    -- Main ULPI State Machine
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            ulpi_state <= IDLE;
            data_out_en <= '0';
            ulpi_stp <= '0';
            usb_tx_ready <= '0';
            usb_rx_valid <= '0';
            usb_rx_active <= '0';
            usb_rx_error <= '0';
            reg_ack <= '0';
            tx_active <= '0';
            turnaround_counter <= (others => '0');
            
        elsif rising_edge(clk) then
            case ulpi_state is
                when IDLE =>
                    data_out_en <= '0';
                    ulpi_stp <= '0';
                    usb_tx_ready <= '1';
                    reg_ack <= '0';
                    
                    if ulpi_dir = '0' then  -- PHY not driving bus
                        if usb_tx_valid = '1' then
                            -- Start transmission
                            ulpi_state <= TX_CMD;
                            data_out_reg <= CMD_TRANSMIT & "000000";
                            data_out_en <= '1';
                            usb_tx_ready <= '0';
                            tx_active <= '1';
                            
                        elsif reg_write = '1' then
                            -- Register write
                            ulpi_state <= REG_WRITE;
                            data_out_reg <= CMD_REG_WRITE & reg_addr;
                            data_out_en <= '1';
                            
                        elsif reg_read = '1' then
                            -- Register read
                            ulpi_state <= REG_READ;
                            data_out_reg <= CMD_REG_READ & reg_addr;
                            data_out_en <= '1';
                        end if;
                        
                    else  -- PHY driving bus (receiving)
                        ulpi_state <= RX_DATA;
                        usb_rx_active <= '1';
                        rx_cmd <= ulpi_data;
                    end if;
                
                when TX_CMD =>
                    if ulpi_nxt = '1' then
                        -- PHY accepted command, start data phase
                        ulpi_state <= TX_DATA;
                        data_out_reg <= usb_tx_data;
                    end if;
                
                when TX_DATA =>
                    if ulpi_nxt = '1' and usb_tx_valid = '1' then
                        -- Continue transmitting data
                        data_out_reg <= usb_tx_data;
                        usb_tx_ready <= '1';
                        
                    elsif usb_tx_valid = '0' then
                        -- End of transmission
                        ulpi_stp <= '1';
                        data_out_en <= '0';
                        tx_active <= '0';
                        turnaround_counter <= (others => '0');
                        ulpi_state <= IDLE;
                    end if;
                
                when RX_DATA =>
                    if ulpi_dir = '1' then
                        -- Continue receiving data
                        usb_rx_data <= ulpi_data;
                        usb_rx_valid <= '1';
                        
                        -- Check for RX command
                        if rx_cmd(1 downto 0) = "01" then  -- RX Active
                            usb_rx_active <= '1';
                        elsif rx_cmd(1 downto 0) = "00" then  -- RX Error
                            usb_rx_error <= '1';
                        end if;
                        
                    else
                        -- End of reception
                        usb_rx_valid <= '0';
                        usb_rx_active <= '0';
                        usb_rx_error <= '0';
                        ulpi_state <= IDLE;
                    end if;
                
                when REG_WRITE =>
                    if ulpi_nxt = '1' then
                        -- Send register data
                        data_out_reg <= reg_data_in;
                        reg_ack <= '1';
                        ulpi_state <= IDLE;
                    end if;
                
                when REG_READ =>
                    if ulpi_nxt = '1' then
                        -- PHY will provide register data
                        data_out_en <= '0';
                        if ulpi_dir = '1' then
                            reg_data_out <= ulpi_data;
                            reg_ack <= '1';
                            ulpi_state <= IDLE;
                        end if;
                    end if;
                
                when others =>
                    ulpi_state <= IDLE;
            end case;
        end if;
    end process;
    
    -- Status Monitoring
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            line_state <= "00";
            vbus_valid <= '0';
            session_end <= '0';
            id_dig <= '0';
            
        elsif rising_edge(clk) then
            if ulpi_dir = '1' and ulpi_state = RX_DATA then
                -- Extract status information from received data
                case rx_cmd(7 downto 6) is
                    when "01" =>  -- Line State
                        line_state <= rx_cmd(1 downto 0);
                    when "10" =>  -- VBUS State
                        vbus_valid <= rx_cmd(1);
                        session_end <= rx_cmd(0);
                    when "11" =>  -- ID and Host Disconnect
                        id_dig <= rx_cmd(2);
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;
    
end behavioral;
```

---

## 🌐 **USB Hub Controller**

### USB 2.0 Hub Implementation
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.usb_pkg.all;

entity usb_hub_controller is
    generic (
        NUM_PORTS : integer := 4;
        HUB_ADDR : std_logic_vector(6 downto 0) := "0000001"
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Upstream Port (to Host)
        upstream_dp : inout std_logic;
        upstream_dm : inout std_logic;
        upstream_oe : out std_logic;
        
        -- Downstream Ports (to Devices)
        downstream_dp : inout std_logic_vector(NUM_PORTS-1 downto 0);
        downstream_dm : inout std_logic_vector(NUM_PORTS-1 downto 0);
        downstream_oe : out std_logic_vector(NUM_PORTS-1 downto 0);
        
        -- Port Control
        port_enable : in  std_logic_vector(NUM_PORTS-1 downto 0);
        port_reset  : in  std_logic_vector(NUM_PORTS-1 downto 0);
        port_suspend : in  std_logic_vector(NUM_PORTS-1 downto 0);
        
        -- Port Status
        port_connect : out std_logic_vector(NUM_PORTS-1 downto 0);
        port_speed   : out std_logic_vector(NUM_PORTS*2-1 downto 0);  -- 2 bits per port
        port_overcurrent : out std_logic_vector(NUM_PORTS-1 downto 0);
        
        -- Hub Status and Control
        hub_power   : in  std_logic;
        hub_overcurrent : out std_logic;
        
        -- Configuration
        config_data : in  std_logic_vector(7 downto 0);
        config_addr : in  std_logic_vector(7 downto 0);
        config_write : in  std_logic;
        
        -- Interrupt
        hub_interrupt : out std_logic
    );
end usb_hub_controller;

architecture behavioral of usb_hub_controller is
    -- Hub State Machine
    type hub_state_type is (IDLE, ENUMERATE, FORWARD, RESPOND);
    signal hub_state : hub_state_type;
    
    -- Port State Arrays
    type port_state_array is array (0 to NUM_PORTS-1) of std_logic_vector(3 downto 0);
    signal port_states : port_state_array;
    
    -- Port Status Change Arrays
    signal port_connect_change : std_logic_vector(NUM_PORTS-1 downto 0);
    signal port_enable_change : std_logic_vector(NUM_PORTS-1 downto 0);
    signal port_reset_change : std_logic_vector(NUM_PORTS-1 downto 0);
    
    -- Hub Descriptor
    signal hub_descriptor : std_logic_vector(71 downto 0);  -- 9 bytes
    
    -- Transaction Routing
    signal current_port : unsigned(3 downto 0);
    signal target_address : std_logic_vector(6 downto 0);
    signal packet_buffer : std_logic_vector(1023 downto 0);
    signal packet_length : unsigned(9 downto 0);
    
    -- Hub Configuration
    signal power_switching : std_logic;
    signal compound_device : std_logic;
    signal overcurrent_protection : std_logic;
    signal tt_think_time : std_logic_vector(1 downto 0);
    signal port_indicators : std_logic;
    
    -- Status Change Bitmap
    signal status_change_bitmap : std_logic_vector(NUM_PORTS downto 0);  -- +1 for hub status
    
begin
    
    -- Hub Descriptor Initialization
    process(rst_n)
    begin
        if rst_n = '0' then
            -- Standard Hub Descriptor
            hub_descriptor <= x"09" &      -- bDescLength
                             x"29" &      -- bDescriptorType (Hub)
                             std_logic_vector(to_unsigned(NUM_PORTS, 8)) &  -- bNbrPorts
                             x"00" &      -- wHubCharacteristics (low byte)
                             x"00" &      -- wHubCharacteristics (high byte)
                             x"32" &      -- bPwrOn2PwrGood (100ms)
                             x"00" &      -- bHubContrCurrent
                             x"00" &      -- DeviceRemovable
                             x"FF";       -- PortPwrCtrlMask
        end if;
    end process;
    
    -- Port Detection and Status Management
    gen_ports: for i in 0 to NUM_PORTS-1 generate
        process(clk, rst_n)
        begin
            if rst_n = '0' then
                port_states(i) <= x"0";
                port_connect_change(i) <= '0';
                port_enable_change(i) <= '0';
                port_reset_change(i) <= '0';
                
            elsif rising_edge(clk) then
                -- Detect connection changes
                if (downstream_dp(i) = '1' and downstream_dm(i) = '0') or
                   (downstream_dp(i) = '0' and downstream_dm(i) = '1') then
                    if port_connect(i) = '0' then
                        port_connect(i) <= '1';
                        port_connect_change(i) <= '1';
                        
                        -- Determine speed
                        if downstream_dp(i) = '1' and downstream_dm(i) = '0' then
                            port_speed(i*2+1 downto i*2) <= "10";  -- Full Speed
                        else
                            port_speed(i*2+1 downto i*2) <= "01";  -- Low Speed
                        end if;
                    end if;
                else
                    if port_connect(i) = '1' then
                        port_connect(i) <= '0';
                        port_connect_change(i) <= '1';
                        port_speed(i*2+1 downto i*2) <= "00";  -- Disconnected
                    end if;
                end if;
                
                -- Handle port reset
                if port_reset(i) = '1' then
                    port_states(i) <= x"4";  -- Reset state
                    port_reset_change(i) <= '1';
                    -- Generate reset signaling on downstream port
                    downstream_dp(i) <= '0';
                    downstream_dm(i) <= '0';
                    downstream_oe(i) <= '1';
                else
                    if port_states(i) = x"4" then
                        port_states(i) <= x"2";  -- Enabled state
                        port_enable_change(i) <= '1';
                        downstream_oe(i) <= '0';
                    end if;
                end if;
                
                -- Handle port suspend
                if port_suspend(i) = '1' then
                    port_states(i) <= x"8";  -- Suspended state
                end if;
            end if;
        end process;
    end generate;
    
    -- Main Hub State Machine
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            hub_state <= IDLE;
            current_port <= (others => '0');
            upstream_oe <= '0';
            hub_interrupt <= '0';
            
        elsif rising_edge(clk) then
            case hub_state is
                when IDLE =>
                    upstream_oe <= '0';
                    
                    -- Check for status changes
                    if (port_connect_change or port_enable_change or port_reset_change) /= (NUM_PORTS-1 downto 0 => '0') then
                        hub_interrupt <= '1';
                        update_status_change_bitmap;
                    end if;
                    
                    -- Monitor upstream port for transactions
                    if detect_upstream_transaction then
                        hub_state <= ENUMERATE;
                        capture_transaction;
                    end if;
                
                when ENUMERATE =>
                    -- Determine if transaction is for hub or downstream device
                    if target_address = HUB_ADDR then
                        hub_state <= RESPOND;
                    else
                        -- Find target port and forward transaction
                        hub_state <= FORWARD;
                        find_target_port;
                    end if;
                
                when FORWARD =>
                    -- Forward transaction to appropriate downstream port
                    if current_port < NUM_PORTS then
                        downstream_oe(to_integer(current_port)) <= '1';
                        forward_to_downstream_port;
                        
                        -- Wait for response and forward back upstream
                        if downstream_response_received then
                            upstream_oe <= '1';
                            forward_to_upstream_port;
                            hub_state <= IDLE;
                        end if;
                    else
                        -- Invalid port, send NAK
                        send_nak_upstream;
                        hub_state <= IDLE;
                    end if;
                
                when RESPOND =>
                    -- Handle hub-specific requests
                    upstream_oe <= '1';
                    
                    case get_request_type is
                        when GET_DESCRIPTOR =>
                            send_hub_descriptor;
                        when GET_STATUS =>
                            send_hub_status;
                        when SET_FEATURE =>
                            handle_set_feature;
                        when CLEAR_FEATURE =>
                            handle_clear_feature;
                        when GET_PORT_STATUS =>
                            send_port_status;
                        when SET_PORT_FEATURE =>
                            handle_set_port_feature;
                        when CLEAR_PORT_FEATURE =>
                            handle_clear_port_feature;
                        when others =>
                            send_stall_upstream;
                    end case;
                    
                    hub_state <= IDLE;
                
                when others =>
                    hub_state <= IDLE;
            end case;
        end if;
    end process;
    
    -- Helper Procedures and Functions
    procedure update_status_change_bitmap is
    begin
        status_change_bitmap(0) <= '0';  -- Hub status (not implemented)
        for i in 0 to NUM_PORTS-1 loop
            status_change_bitmap(i+1) <= port_connect_change(i) or 
                                        port_enable_change(i) or 
                                        port_reset_change(i);
        end loop;
    end procedure;
    
    function detect_upstream_transaction return boolean is
    begin
        -- Simplified transaction detection
        return (upstream_dp'event or upstream_dm'event);
    end function;
    
    procedure capture_transaction is
    begin
        -- Capture transaction details (simplified)
        target_address <= "0000001";  -- Placeholder
        packet_length <= to_unsigned(64, 10);
    end procedure;
    
    procedure find_target_port is
    begin
        -- Find which port the target device is connected to
        -- This would typically involve maintaining a device table
        current_port <= to_unsigned(0, 4);  -- Placeholder
    end procedure;
    
    procedure forward_to_downstream_port is
    begin
        -- Forward packet to downstream port
        downstream_dp(to_integer(current_port)) <= upstream_dp;
        downstream_dm(to_integer(current_port)) <= upstream_dm;
    end procedure;
    
    procedure forward_to_upstream_port is
    begin
        -- Forward response back to upstream port
        upstream_dp <= downstream_dp(to_integer(current_port));
        upstream_dm <= downstream_dm(to_integer(current_port));
    end procedure;
    
    function downstream_response_received return boolean is
    begin
        -- Check if downstream device has responded
        return true;  -- Placeholder
    end function;
    
    function get_request_type return std_logic_vector is
    begin
        -- Extract request type from captured transaction
        return x"06";  -- GET_DESCRIPTOR (placeholder)
    end function;
    
    procedure send_hub_descriptor is
    begin
        -- Send hub descriptor to upstream port
        -- Implementation would serialize hub_descriptor
    end procedure;
    
    procedure send_hub_status is
    begin
        -- Send hub status (overcurrent, power, etc.)
    end procedure;
    
    procedure send_port_status is
    begin
        -- Send status for requested port
    end procedure;
    
    procedure handle_set_feature is
    begin
        -- Handle SET_FEATURE requests
    end procedure;
    
    procedure handle_clear_feature is
    begin
        -- Handle CLEAR_FEATURE requests
    end procedure;
    
    procedure handle_set_port_feature is
    begin
        -- Handle SET_PORT_FEATURE requests
    end procedure;
    
    procedure handle_clear_port_feature is
    begin
        -- Handle CLEAR_PORT_FEATURE requests
    end procedure;
    
    procedure send_nak_upstream is
    begin
        -- Send NAK response upstream
    end procedure;
    
    procedure send_stall_upstream is
    begin
        -- Send STALL response upstream
    end procedure;
    
    -- Overcurrent Detection
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            hub_overcurrent <= '0';
            port_overcurrent <= (others => '0');
        elsif rising_edge(clk) then
            -- Monitor power consumption and detect overcurrent conditions
            -- This would typically involve ADC readings of current sensors
            for i in 0 to NUM_PORTS-1 loop
                if monitor_port_current(i) > OVERCURRENT_THRESHOLD then
                    port_overcurrent(i) <= '1';
                    hub_overcurrent <= '1';
                end if;
            end loop;
        end if;
    end process;
    
    function monitor_port_current(port_num : integer) return unsigned is
    begin
        -- Placeholder for current monitoring
        return to_unsigned(100, 16);  -- mA
    end function;
    
end behavioral;
```

### Multi-Endpoint FIFO Controller
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.usb_pkg.all;

entity usb_endpoint_manager is
    generic (
        NUM_ENDPOINTS : integer := 16;
        FIFO_DEPTH : integer := 512;
        MAX_PACKET_SIZE : integer := 1024
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- USB Controller Interface
        usb_ep_addr : in  std_logic_vector(3 downto 0);
        usb_ep_dir  : in  std_logic;  -- 0=OUT, 1=IN
        usb_ep_data : inout std_logic_vector(31 downto 0);
        usb_ep_valid : in  std_logic;
        usb_ep_ready : out std_logic;
        usb_ep_type : in  endpoint_type;
        
        -- Application Interface
        app_ep_addr : in  std_logic_vector(3 downto 0);
        app_ep_dir  : in  std_logic;
        app_wr_data : in  std_logic_vector(31 downto 0);
        app_wr_en   : in  std_logic;
        app_rd_data : out std_logic_vector(31 downto 0);
        app_rd_en   : in  std_logic;
        app_full    : out std_logic;
        app_empty   : out std_logic;
        
        -- Endpoint Configuration
        ep_enable   : in  std_logic_vector(NUM_ENDPOINTS-1 downto 0);
        ep_type     : in  endpoint_type;
        ep_max_packet : in std_logic_vector(10 downto 0);
        
        -- Status and Control
        ep_stall    : in  std_logic_vector(NUM_ENDPOINTS-1 downto 0);
        ep_nak      : out std_logic_vector(NUM_ENDPOINTS-1 downto 0);
        ep_ready_flags : out std_logic_vector(NUM_ENDPOINTS-1 downto 0);
        
        -- Interrupt
        ep_irq      : out std_logic_vector(NUM_ENDPOINTS-1 downto 0)
    );
end usb_endpoint_manager;

architecture behavioral of usb_endpoint_manager is
    -- Endpoint FIFO Arrays
    type fifo_data_array is array (0 to NUM_ENDPOINTS-1) of std_logic_vector(31 downto 0);
    type fifo_addr_array is array (0 to NUM_ENDPOINTS-1) of std_logic_vector(8 downto 0);
    
    signal ep_in_fifo_data : fifo_data_array;
    signal ep_out_fifo_data : fifo_data_array;
    signal ep_in_wr_addr : fifo_addr_array;
    signal ep_in_rd_addr : fifo_addr_array;
    signal ep_out_wr_addr : fifo_addr_array;
    signal ep_out_rd_addr : fifo_addr_array;
    
    -- FIFO Status Signals
    signal ep_in_full : std_logic_vector(NUM_ENDPOINTS-1 downto 0);
    signal ep_in_empty : std_logic_vector(NUM_ENDPOINTS-1 downto 0);
    signal ep_out_full : std_logic_vector(NUM_ENDPOINTS-1 downto 0);
    signal ep_out_empty : std_logic_vector(NUM_ENDPOINTS-1 downto 0);
    
    -- Endpoint State
    type ep_state_array is array (0 to NUM_ENDPOINTS-1) of transfer_state_type;
    signal ep_in_state : ep_state_array;
    signal ep_out_state : ep_state_array;
    
    -- Packet Management
    signal current_packet_size : unsigned(10 downto 0);
    signal packet_count : unsigned(15 downto 0);
    
    -- Data Toggle Tracking
    signal data_toggle_in : std_logic_vector(NUM_ENDPOINTS-1 downto 0);
    signal data_toggle_out : std_logic_vector(NUM_ENDPOINTS-1 downto 0);
    
begin
    
    -- Generate FIFO instances for each endpoint
    gen_endpoints: for i in 0 to NUM_ENDPOINTS-1 generate
        
        -- IN Endpoint FIFO
        in_fifo_inst: entity work.dual_port_ram
            generic map (
                DATA_WIDTH => 32,
                ADDR_WIDTH => 9,
                DEPTH => FIFO_DEPTH
            )
            port map (
                clk => clk,
                rst_n => rst_n,
                
                -- Write Port (Application -> FIFO)
                wr_addr => ep_in_wr_addr(i),
                wr_data => app_wr_data,
                wr_en => app_wr_en when to_integer(unsigned(app_ep_addr)) = i and app_ep_dir = '1' else '0',
                
                -- Read Port (FIFO -> USB)
                rd_addr => ep_in_rd_addr(i),
                rd_data => ep_in_fifo_data(i),
                rd_en => usb_ep_valid when to_integer(unsigned(usb_ep_addr)) = i and usb_ep_dir = '1' else '0'
            );
        
        -- OUT Endpoint FIFO
        out_fifo_inst: entity work.dual_port_ram
            generic map (
                DATA_WIDTH => 32,
                ADDR_WIDTH => 9,
                DEPTH => FIFO_DEPTH
            )
            port map (
                clk => clk,
                rst_n => rst_n,
                
                -- Write Port (USB -> FIFO)
                wr_addr => ep_out_wr_addr(i),
                wr_data => usb_ep_data,
                wr_en => usb_ep_valid when to_integer(unsigned(usb_ep_addr)) = i and usb_ep_dir = '0' else '0',
                
                -- Read Port (FIFO -> Application)
                rd_addr => ep_out_rd_addr(i),
                rd_data => ep_out_fifo_data(i),
                rd_en => app_rd_en when to_integer(unsigned(app_ep_addr)) = i and app_ep_dir = '0' else '0'
            );
        
        -- FIFO Address Management
        process(clk, rst_n)
        begin
            if rst_n = '0' then
                ep_in_wr_addr(i) <= (others => '0');
                ep_in_rd_addr(i) <= (others => '0');
                ep_out_wr_addr(i) <= (others => '0');
                ep_out_rd_addr(i) <= (others => '0');
                
            elsif rising_edge(clk) then
                -- IN Endpoint Write Address (Application writes)
                if app_wr_en = '1' and to_integer(unsigned(app_ep_addr)) = i and app_ep_dir = '1' then
                    if ep_in_wr_addr(i) < std_logic_vector(to_unsigned(FIFO_DEPTH-1, 9)) then
                        ep_in_wr_addr(i) <= std_logic_vector(unsigned(ep_in_wr_addr(i)) + 1);
                    end if;
                end if;
                
                -- IN Endpoint Read Address (USB reads)
                if usb_ep_valid = '1' and to_integer(unsigned(usb_ep_addr)) = i and usb_ep_dir = '1' then
                    if ep_in_rd_addr(i) < ep_in_wr_addr(i) then
                        ep_in_rd_addr(i) <= std_logic_vector(unsigned(ep_in_rd_addr(i)) + 1);
                    end if;
                end if;
                
                -- OUT Endpoint Write Address (USB writes)
                if usb_ep_valid = '1' and to_integer(unsigned(usb_ep_addr)) = i and usb_ep_dir = '0' then
                    if ep_out_wr_addr(i) < std_logic_vector(to_unsigned(FIFO_DEPTH-1, 9)) then
                        ep_out_wr_addr(i) <= std_logic_vector(unsigned(ep_out_wr_addr(i)) + 1);
                    end if;
                end if;
                
                -- OUT Endpoint Read Address (Application reads)
                if app_rd_en = '1' and to_integer(unsigned(app_ep_addr)) = i and app_ep_dir = '0' then
                    if ep_out_rd_addr(i) < ep_out_wr_addr(i) then
                        ep_out_rd_addr(i) <= std_logic_vector(unsigned(ep_out_rd_addr(i)) + 1);
                    end if;
                end if;
            end if;
        end process;
        
        -- FIFO Status Generation
        ep_in_full(i) <= '1' when unsigned(ep_in_wr_addr(i)) >= FIFO_DEPTH-1 else '0';
        ep_in_empty(i) <= '1' when ep_in_wr_addr(i) = ep_in_rd_addr(i) else '0';
        ep_out_full(i) <= '1' when unsigned(ep_out_wr_addr(i)) >= FIFO_DEPTH-1 else '0';
        ep_out_empty(i) <= '1' when ep_out_wr_addr(i) = ep_out_rd_addr(i) else '0';
        
        -- Endpoint State Management
        process(clk, rst_n)
        begin
            if rst_n = '0' then
                ep_in_state(i) <= IDLE;
                ep_out_state(i) <= IDLE;
                data_toggle_in(i) <= '0';
                data_toggle_out(i) <= '0';
                
            elsif rising_edge(clk) then
                -- IN Endpoint State Machine
                case ep_in_state(i) is
                    when IDLE =>
                        if ep_enable(i) = '1' and ep_in_empty(i) = '0' then
                            ep_in_state(i) <= DATA_IN;
                        end if;
                    
                    when DATA_IN =>
                        if usb_ep_valid = '1' and to_integer(unsigned(usb_ep_addr)) = i and usb_ep_dir = '1' then
                            if ep_in_empty(i) = '1' then
                                ep_in_state(i) <= COMPLETE;
                                data_toggle_in(i) <= not data_toggle_in(i);
                            end if;
                        end if;
                    
                    when COMPLETE =>
                        ep_in_state(i) <= IDLE;
                    
                    when others =>
                        ep_in_state(i) <= IDLE;
                end case;
                
                -- OUT Endpoint State Machine
                case ep_out_state(i) is
                    when IDLE =>
                        if ep_enable(i) = '1' and usb_ep_valid = '1' and 
                           to_integer(unsigned(usb_ep_addr)) = i and usb_ep_dir = '0' then
                            ep_out_state(i) <= DATA_OUT;
                        end if;
                    
                    when DATA_OUT =>
                        if ep_out_full(i) = '1' then
                            ep_out_state(i) <= COMPLETE;
                            data_toggle_out(i) <= not data_toggle_out(i);
                        end if;
                    
                    when COMPLETE =>
                        ep_out_state(i) <= IDLE;
                    
                    when others =>
                        ep_out_state(i) <= IDLE;
                end case;
            end if;
        end process;
        
        -- Endpoint Ready Flags
        ep_ready_flags(i) <= '1' when (ep_in_state(i) = DATA_IN and ep_in_empty(i) = '0') or
                                     (ep_out_state(i) = IDLE and ep_out_full(i) = '0') else '0';
        
        -- NAK Generation
        ep_nak(i) <= '1' when (usb_ep_dir = '1' and ep_in_empty(i) = '1') or
                             (usb_ep_dir = '0' and ep_out_full(i) = '1') else '0';
        
        -- Interrupt Generation
        ep_irq(i) <= '1' when ep_in_state(i) = COMPLETE or ep_out_state(i) = COMPLETE else '0';
        
    end generate;
    
    -- USB Interface Data Multiplexing
    process(usb_ep_addr, usb_ep_dir, ep_in_fifo_data, ep_out_fifo_data)
        variable ep_index : integer;
    begin
        ep_index := to_integer(unsigned(usb_ep_addr));
        
        if usb_ep_dir = '1' then  -- IN
            usb_ep_data <= ep_in_fifo_data(ep_index);
        else  -- OUT
            usb_ep_data <= (others => 'Z');  -- High impedance for input
        end if;
    end process;
    
    -- Application Interface Data Multiplexing
    process(app_ep_addr, app_ep_dir, ep_out_fifo_data)
        variable ep_index : integer;
    begin
        ep_index := to_integer(unsigned(app_ep_addr));
        
        if app_ep_dir = '0' then  -- OUT (from USB perspective)
            app_rd_data <= ep_out_fifo_data(ep_index);
        else
            app_rd_data <= (others => '0');
        end if;
    end process;
    
    -- Status Output Generation
    process(app_ep_addr, app_ep_dir, ep_in_full, ep_in_empty, ep_out_full, ep_out_empty)
        variable ep_index : integer;
    begin
        ep_index := to_integer(unsigned(app_ep_addr));
        
        if app_ep_dir = '1' then  -- IN
            app_full <= ep_in_full(ep_index);
            app_empty <= ep_in_empty(ep_index);
        else  -- OUT
            app_full <= ep_out_full(ep_index);
            app_empty <= ep_out_empty(ep_index);
        end if;
    end process;
    
    -- USB Ready Signal
    usb_ep_ready <= '1' when ep_stall(to_integer(unsigned(usb_ep_addr))) = '0' else '0';
    
end behavioral;
```

---

## 📊 **USB Performance Monitoring**

### USB Traffic Analyzer
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity usb_traffic_analyzer is
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- USB Monitor Interface
        usb_dp      : in  std_logic;
        usb_dm      : in  std_logic;
        usb_data    : in  std_logic_vector(7 downto 0);
        usb_valid   : in  std_logic;
        usb_error   : in  std_logic;
        
        -- Packet Classification
        packet_type : in  std_logic_vector(3 downto 0);
        packet_addr : in  std_logic_vector(6 downto 0);
        packet_endp : in  std_logic_vector(3 downto 0);
        packet_start : in  std_logic;
        packet_end  : in  std_logic;
        
        -- Statistics Interface
        stats_addr  : in  std_logic_vector(7 downto 0);
        stats_data  : out std_logic_vector(31 downto 0);
        stats_read  : in  std_logic;
        
        -- Control Interface
        monitor_enable : in  std_logic;
        reset_stats : in  std_logic;
        capture_enable : in  std_logic;
        
        -- Trigger Interface
        trigger_type : in  std_logic_vector(3 downto 0);
        trigger_addr : in  std_logic_vector(6 downto 0);
        trigger_endp : in  std_logic_vector(3 downto 0);
        trigger_active : out std_logic;
        
        -- Alert Interface
        bandwidth_alert : out std_logic;
        error_alert : out std_logic;
        protocol_alert : out std_logic
    );
end usb_traffic_analyzer;

architecture behavioral of usb_traffic_analyzer is
    -- Statistics Counters (32-bit each)
    signal total_packets : unsigned(31 downto 0);
    signal token_packets : unsigned(31 downto 0);
    signal data_packets : unsigned(31 downto 0);
    signal handshake_packets : unsigned(31 downto 0);
    signal special_packets : unsigned(31 downto 0);
    signal error_packets : unsigned(31 downto 0);
    signal total_bytes : unsigned(31 downto 0);
    signal crc_errors : unsigned(31 downto 0);
    signal timeout_errors : unsigned(31 downto 0);
    signal protocol_errors : unsigned(31 downto 0);
    
    -- Per-Endpoint Statistics
    type endpoint_stats_array is array (0 to 15) of unsigned(31 downto 0);
    signal endpoint_in_packets : endpoint_stats_array;
    signal endpoint_out_packets : endpoint_stats_array;
    signal endpoint_in_bytes : endpoint_stats_array;
    signal endpoint_out_bytes : endpoint_stats_array;
    signal endpoint_errors : endpoint_stats_array;
    
    -- Bandwidth Monitoring
    signal bandwidth_counter : unsigned(31 downto 0);
    signal bandwidth_timer : unsigned(19 downto 0);  -- 1ms timer at 1MHz
    signal current_bandwidth : unsigned(31 downto 0);
    signal peak_bandwidth : unsigned(31 downto 0);
    signal bandwidth_threshold : unsigned(31 downto 0) := to_unsigned(1000000, 32);  -- 1MB/s
    
    -- Packet Capture Buffer
    type capture_buffer_type is array (0 to 1023) of std_logic_vector(7 downto 0);
    signal capture_buffer : capture_buffer_type;
    signal capture_write_ptr : unsigned(9 downto 0);
    signal capture_read_ptr : unsigned(9 downto 0);
    signal capture_count : unsigned(10 downto 0);
    signal capture_overflow : std_logic;
    
    -- State Machine
    type analyzer_state_type is (IDLE, PACKET_CAPTURE, PACKET_ANALYSIS);
    signal analyzer_state : analyzer_state_type;
    
    -- Packet Analysis
    signal current_packet_size : unsigned(10 downto 0);
    signal current_packet_type : std_logic_vector(3 downto 0);
    signal current_packet_addr : std_logic_vector(6 downto 0);
    signal current_packet_endp : std_logic_vector(3 downto 0);
    
    -- Line State Monitoring
    signal line_state : std_logic_vector(1 downto 0);
    signal line_state_change : std_logic;
    signal disconnect_count : unsigned(15 downto 0);
    signal connect_count : unsigned(15 downto 0);
    
    -- Protocol Violation Detection
    signal protocol_violation : std_logic;
    signal invalid_pid_count : unsigned(15 downto 0);
    signal invalid_sequence_count : unsigned(15 downto 0);
    
begin
    
    -- Line State Monitoring
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            line_state <= "00";
            line_state_change <= '0';
            disconnect_count <= (others => '0');
            connect_count <= (others => '0');
            
        elsif rising_edge(clk) then
            line_state_change <= '0';
            
            -- Detect line state changes
            if (usb_dp & usb_dm) /= line_state then
                line_state <= usb_dp & usb_dm;
                line_state_change <= '1';
                
                case (usb_dp & usb_dm) is
                    when "00" =>  -- SE0 (disconnect or reset)
                        disconnect_count <= disconnect_count + 1;
                    when "01" =>  -- J state (idle for LS)
                        connect_count <= connect_count + 1;
                    when "10" =>  -- K state (idle for FS/HS)
                        connect_count <= connect_count + 1;
                    when "11" =>  -- SE1 (invalid)
                        protocol_errors <= protocol_errors + 1;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;
    
    -- Main Traffic Analysis
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            analyzer_state <= IDLE;
            total_packets <= (others => '0');
            token_packets <= (others => '0');
            data_packets <= (others => '0');
            handshake_packets <= (others => '0');
            special_packets <= (others => '0');
            error_packets <= (others => '0');
            total_bytes <= (others => '0');
            current_packet_size <= (others => '0');
            trigger_active <= '0';
            
            for i in 0 to 15 loop
                endpoint_in_packets(i) <= (others => '0');
                endpoint_out_packets(i) <= (others => '0');
                endpoint_in_bytes(i) <= (others => '0');
                endpoint_out_bytes(i) <= (others => '0');
                endpoint_errors(i) <= (others => '0');
            end loop;
            
        elsif rising_edge(clk) then
            if reset_stats = '1' then
                -- Reset all statistics
                total_packets <= (others => '0');
                token_packets <= (others => '0');
                data_packets <= (others => '0');
                handshake_packets <= (others => '0');
                special_packets <= (others => '0');
                error_packets <= (others => '0');
                total_bytes <= (others => '0');
                crc_errors <= (others => '0');
                timeout_errors <= (others => '0');
                protocol_errors <= (others => '0');
                
                for i in 0 to 15 loop
                    endpoint_in_packets(i) <= (others => '0');
                    endpoint_out_packets(i) <= (others => '0');
                    endpoint_in_bytes(i) <= (others => '0');
                    endpoint_out_bytes(i) <= (others => '0');
                    endpoint_errors(i) <= (others => '0');
                end loop;
                
            elsif monitor_enable = '1' then
                case analyzer_state is
                    when IDLE =>
                        trigger_active <= '0';
                        
                        if packet_start = '1' then
                            analyzer_state <= PACKET_CAPTURE;
                            current_packet_size <= (others => '0');
                            current_packet_type <= packet_type;
                            current_packet_addr <= packet_addr;
                            current_packet_endp <= packet_endp;
                            
                            -- Check trigger conditions
                            if (trigger_type = packet_type or trigger_type = x"F") and
                               (trigger_addr = packet_addr or trigger_addr = "1111111") and
                               (trigger_endp = packet_endp or trigger_endp = x"F") then
                                trigger_active <= '1';
                            end if;
                        end if;
                    
                    when PACKET_CAPTURE =>
                        -- Count bytes in current packet
                        if usb_valid = '1' then
                            current_packet_size <= current_packet_size + 1;
                            total_bytes <= total_bytes + 1;
                            
                            -- Capture to buffer if enabled
                            if capture_enable = '1' and capture_count < 1024 then
                                capture_buffer(to_integer(capture_write_ptr)) <= usb_data;
                                capture_write_ptr <= capture_write_ptr + 1;
                                capture_count <= capture_count + 1;
                            elsif capture_enable = '1' then
                                capture_overflow <= '1';
                            end if;
                        end if;
                        
                        -- Handle errors
                        if usb_error = '1' then
                            error_packets <= error_packets + 1;
                            
                            -- Update endpoint error count
                            if to_integer(unsigned(current_packet_endp)) < 16 then
                                endpoint_errors(to_integer(unsigned(current_packet_endp))) <= 
                                    endpoint_errors(to_integer(unsigned(current_packet_endp))) + 1;
                            end if;
                        end if;
                        
                        if packet_end = '1' then
                            analyzer_state <= PACKET_ANALYSIS;
                        end if;
                    
                    when PACKET_ANALYSIS =>
                        -- Update packet type counters
                        total_packets <= total_packets + 1;
                        
                        case current_packet_type is
                            when x"1" =>  -- Token
                                token_packets <= token_packets + 1;
                            when x"2" =>  -- Data
                                data_packets <= data_packets + 1;
                            when x"3" =>  -- Handshake
                                handshake_packets <= handshake_packets + 1;
                            when x"4" =>  -- Special
                                special_packets <= special_packets + 1;
                            when others =>
                                error_packets <= error_packets + 1;
                        end case;
                        
                        analyzer_state <= IDLE;
                
                    when others =>
                        analyzer_state <= IDLE;
                end case;
            end if;
        end if;
    end process;
    
    -- Bandwidth Monitoring
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            bandwidth_counter <= (others => '0');
            bandwidth_timer <= (others => '0');
            current_bandwidth <= (others => '0');
            peak_bandwidth <= (others => '0');
            bandwidth_alert <= '0';
            
        elsif rising_edge(clk) then
            -- 1ms timer (assuming 1MHz clock)
            if bandwidth_timer = 999 then
                bandwidth_timer <= (others => '0');
                
                -- Calculate current bandwidth (bytes per second)
                current_bandwidth <= bandwidth_counter * 1000;
                
                -- Update peak bandwidth
                if bandwidth_counter * 1000 > peak_bandwidth then
                    peak_bandwidth <= bandwidth_counter * 1000;
                end if;
                
                -- Check bandwidth threshold
                if bandwidth_counter * 1000 > bandwidth_threshold then
                    bandwidth_alert <= '1';
                else
                    bandwidth_alert <= '0';
                end if;
                
                bandwidth_counter <= (others => '0');
            else
                bandwidth_timer <= bandwidth_timer + 1;
            end if;
            
            -- Count bytes for bandwidth calculation
            if usb_valid = '1' and monitor_enable = '1' then
                bandwidth_counter <= bandwidth_counter + 1;
            end if;
        end if;
    end process;
    
    -- Statistics Read Interface
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            stats_data <= (others => '0');
            
        elsif rising_edge(clk) then
            if stats_read = '1' then
                case stats_addr is
                    when x"00" => stats_data <= std_logic_vector(total_packets);
                    when x"01" => stats_data <= std_logic_vector(token_packets);
                    when x"02" => stats_data <= std_logic_vector(data_packets);
                    when x"03" => stats_data <= std_logic_vector(handshake_packets);
                    when x"04" => stats_data <= std_logic_vector(special_packets);
                    when x"05" => stats_data <= std_logic_vector(error_packets);
                    when x"06" => stats_data <= std_logic_vector(total_bytes);
                    when x"07" => stats_data <= std_logic_vector(crc_errors);
                    when x"08" => stats_data <= std_logic_vector(timeout_errors);
                    when x"09" => stats_data <= std_logic_vector(protocol_errors);
                    when x"0A" => stats_data <= std_logic_vector(current_bandwidth);
                    when x"0B" => stats_data <= std_logic_vector(peak_bandwidth);
                    when x"0C" => stats_data <= std_logic_vector(disconnect_count) & std_logic_vector(connect_count);
                    
                    -- Endpoint statistics (0x10-0x1F for IN packets, 0x20-0x2F for OUT packets, etc.)
                    when x"10" to x"1F" => 
                        stats_data <= std_logic_vector(endpoint_in_packets(to_integer(unsigned(stats_addr(3 downto 0)))));
                    when x"20" to x"2F" => 
                        stats_data <= std_logic_vector(endpoint_out_packets(to_integer(unsigned(stats_addr(3 downto 0)))));
                    when x"30" to x"3F" => 
                        stats_data <= std_logic_vector(endpoint_in_bytes(to_integer(unsigned(stats_addr(3 downto 0)))));
                    when x"40" to x"4F" => 
                        stats_data <= std_logic_vector(endpoint_out_bytes(to_integer(unsigned(stats_addr(3 downto 0)))));
                    when x"50" to x"5F" => 
                        stats_data <= std_logic_vector(endpoint_errors(to_integer(unsigned(stats_addr(3 downto 0)))));
                    
                    when others => 
                        stats_data <= (others => '0');
                end case;
            end if;
        end if;
    end process;
    
    -- Alert Generation
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            error_alert <= '0';
            protocol_alert <= '0';
            
        elsif rising_edge(clk) then
            -- Error rate alert (more than 1% error rate)
            if total_packets > 100 and (error_packets * 100) > total_packets then
                error_alert <= '1';
            else
                error_alert <= '0';
            end if;
            
            -- Protocol violation alert
            if protocol_violation = '1' or invalid_pid_count > 10 or invalid_sequence_count > 5 then
                protocol_alert <= '1';
            else
                protocol_alert <= '0';
            end if;
        end if;
    end process;
    
end behavioral;
```

---

## 📋 **Summary and Best Practices**

### USB Design Guidelines
- **Clock Domain Management**: Use proper clock domain crossing techniques for USB PHY interfaces
- **Reset Strategy**: Implement proper reset sequences for USB controllers and endpoints
- **Power Management**: Consider USB suspend/resume states and power consumption
- **Signal Integrity**: Ensure proper differential signaling for USB 2.0/3.0 interfaces
- **Timing Constraints**: Apply appropriate timing constraints for USB clock domains

### Performance Considerations
- **FIFO Sizing**: Size endpoint FIFOs based on maximum packet sizes and transfer requirements
- **Bandwidth Optimization**: Implement efficient DMA transfers and minimize CPU intervention
- **Latency Minimization**: Use dedicated hardware for time-critical USB operations
- **Error Handling**: Implement robust error detection and recovery mechanisms
- **Protocol Compliance**: Ensure strict adherence to USB specifications

### Implementation Tips
- **Modular Design**: Use hierarchical design with separate modules for different USB functions
- **Parameterization**: Make designs configurable for different USB speeds and endpoint counts
- **Simulation**: Thoroughly simulate USB protocol interactions and edge cases
- **Verification**: Use formal verification methods for critical USB protocol handling
- **Documentation**: Maintain clear documentation of USB implementation details

### Testing and Verification
- **Protocol Analyzers**: Use USB protocol analyzers for real-world testing
- **Compliance Testing**: Perform USB-IF compliance testing for commercial products
- **Stress Testing**: Test with various host controllers and operating systems
- **Performance Testing**: Measure actual throughput and latency under different conditions
- **Interoperability**: Test with multiple USB devices and configurations

---

## 📚 **Additional Resources**

### USB Standards and Specifications
- **USB 2.0 Specification**: Universal Serial Bus Specification Revision 2.0
- **USB 3.0 Specification**: Universal Serial Bus 3.0 Specification
- **USB-C Specification**: USB Type-C Cable and Connector Specification
- **USB Power Delivery**: USB Power Delivery Specification
- **USB Audio**: USB Device Class Definition for Audio Devices

### Development Tools
- **USB Protocol Analyzers**: Beagle USB analyzers, Total Phase tools
- **Simulation Tools**: ModelSim, Vivado Simulator, Questa
- **Synthesis Tools**: Vivado, Quartus Prime, Synplify Pro
- **Verification Tools**: UVM, SystemVerilog, formal verification tools
- **Debug Tools**: ChipScope, SignalTap, integrated logic analyzers

### Reference Implementations
- **Open Source USB Cores**: OpenCores USB implementations
- **Vendor IP**: Xilinx USB cores, Intel USB IP
- **Academic Resources**: University research papers and implementations
- **Application Notes**: Vendor-specific USB implementation guides
- **Community Forums**: FPGA and USB development communities

### Testing Equipment
- **USB Test Fixtures**: USB compliance test fixtures and cables
- **Oscilloscopes**: High-speed oscilloscopes for signal integrity analysis
- **Protocol Analyzers**: Hardware-based USB protocol analysis tools
- **Load Testing**: USB device exerciser and stress testing tools
- **Certification Labs**: USB-IF authorized test laboratories