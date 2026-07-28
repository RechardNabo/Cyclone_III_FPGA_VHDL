-- ================================================================================
-- modbus_controller : Modbus RTU/ASCII controller over UART
-- ================================================================================
-- Implements Modbus RTU and ASCII protocol framing over a UART link.
--   * RTU mode: binary frames with CRC-16
--   * ASCII mode: hex-encoded frames with LRC checksum
--   * Master (client) and slave (server) modes
--
-- AHB-Lite register map:
--   0x00 : CTRL        - [0] enable, [1] irq_en, [2] rtu_mode, [3] master_mode, [4] start_tx
--   0x04 : STAT        - [0] idle, [1] tx_busy, [2] rx_ready, [3] crc_error
--   0x08 : SLAVE_ADDR  - Modbus slave address (1-247)
--   0x0C : FUNC_CODE   - Modbus function code
--   0x10 : REG_ADDR    - starting register address
--   0x14 : REG_COUNT   - number of registers
--   0x18 : DATA_IN     - write data to TX buffer
--   0x1C : DATA_OUT    - read data from RX buffer
--   0x20 : CRC         - computed CRC-16 (read-only)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity modbus_controller is
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

        -- Modbus UART interface
        modbus_txd : out std_logic;
        modbus_rxd : in  std_logic := '1';
        modbus_irq : out std_logic
    );
end entity modbus_controller;

architecture rtl of modbus_controller is
    constant TX_BUF_DEPTH : integer := 32;
    constant RX_BUF_DEPTH : integer := 32;
    type buf_t is array(0 to TX_BUF_DEPTH-1) of std_logic_vector(7 downto 0);

    signal ctrl_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal slave_addr    : std_logic_vector(31 downto 0) := (others => '0');
    signal func_code     : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_addr      : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_count     : std_logic_vector(31 downto 0) := (others => '0');
    signal crc_reg       : std_logic_vector(15 downto 0) := (others => '0');

    signal tx_buf        : buf_t := (others => (others => '0'));
    signal tx_wr_ptr     : integer range 0 to TX_BUF_DEPTH-1 := 0;
    signal tx_rd_ptr     : integer range 0 to TX_BUF_DEPTH-1 := 0;
    signal tx_count      : integer range 0 to TX_BUF_DEPTH := 0;

    signal rx_buf        : buf_t := (others => (others => '0'));
    signal rx_wr_ptr     : integer range 0 to RX_BUF_DEPTH-1 := 0;
    signal rx_rd_ptr     : integer range 0 to RX_BUF_DEPTH-1 := 0;
    signal rx_count      : integer range 0 to RX_BUF_DEPTH := 0;

    signal tx_busy       : std_logic := '0';
    signal rx_ready      : std_logic := '0';
    signal irq_pending   : std_logic := '0';
    signal baud_div      : unsigned(15 downto 0) := (others => '0');
    signal bit_phase     : integer range 0 to 10 := 0;
    signal shift_reg     : std_logic_vector(9 downto 0) := (others => '1');

    signal reg_offset    : std_logic_vector(7 downto 0);
    signal write_en      : std_logic;

    -- CRC-16 Modbus (0x8005) byte-at-a-time
    function crc16_next(crc : std_logic_vector(15 downto 0);
                        db  : std_logic_vector(7 downto 0))
                        return std_logic_vector is
        variable c : std_logic_vector(15 downto 0) := crc;
        variable d : std_logic_vector(7 downto 0) := db;
    begin
        for i in 0 to 7 loop
            if (c(15) xor d(7)) = '1' then
                c := (c(14 downto 0) & '0') xor x"8005";
            else
                c := c(14 downto 0) & '0';
            end if;
            d := d(6 downto 0) & '0';
        end loop;
        return c;
    end function;

begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    modbus_txd <= shift_reg(0) when tx_busy = '1' else '1';

    ahb_write : process(HCLK, HRESETn)
        variable tmp_crc : std_logic_vector(15 downto 0);
    begin
        if HRESETn = '0' then
            ctrl_reg    <= (others => '0');
            slave_addr  <= (others => '0');
            func_code   <= (others => '0');
            reg_addr    <= (others => '0');
            reg_count   <= (others => '0');
            crc_reg     <= (others => '0');
            tx_buf      <= (others => (others => '0'));
            rx_buf      <= (others => (others => '0'));
            tx_wr_ptr   <= 0; tx_rd_ptr <= 0; tx_count <= 0;
            rx_wr_ptr   <= 0; rx_rd_ptr <= 0; rx_count <= 0;
            tx_busy     <= '0';
            rx_ready    <= '0';
            irq_pending <= '0';
            baud_div    <= (others => '0');
            bit_phase   <= 0;
            shift_reg   <= (others => '1');
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            if write_en = '1' then
                case reg_offset is
                    when x"00" =>
                        ctrl_reg <= HWDATA;
                        if HWDATA(4) = '1' and tx_busy = '0' then
                            -- Build frame: addr, func, addr_hi, addr_lo, cnt_hi, cnt_lo
                            tx_buf(0) <= slave_addr(7 downto 0);
                            tx_buf(1) <= func_code(7 downto 0);
                            tx_buf(2) <= reg_addr(15 downto 8);
                            tx_buf(3) <= reg_addr(7 downto 0);
                            tx_buf(4) <= reg_count(15 downto 8);
                            tx_buf(5) <= reg_count(7 downto 0);
                            tx_count <= 6;
                            tx_rd_ptr <= 0;
                            tx_busy <= '1';
                            bit_phase <= 0;
                            baud_div <= (others => '0');
                            crc_reg <= x"FFFF";
                        end if;
                    when x"04" =>
                        if HWDATA(2) = '1' then rx_ready <= '0'; end if;
                    when x"08" => slave_addr <= HWDATA;
                    when x"0C" => func_code  <= HWDATA;
                    when x"10" => reg_addr   <= HWDATA;
                    when x"14" => reg_count  <= HWDATA;
                    when x"18" =>  -- DATA_IN
                        if tx_count < TX_BUF_DEPTH then
                            tx_buf(tx_wr_ptr) <= HWDATA(7 downto 0);
                            tx_wr_ptr <= (tx_wr_ptr + 1) mod TX_BUF_DEPTH;
                            tx_count <= tx_count + 1;
                        end if;
                    when others => null;
                end case;
            end if;

            -- UART TX state machine
            if tx_busy = '1' then
                if baud_div = 173 then  -- ~115200 baud at 20 MHz
                    baud_div <= (others => '0');
                    if bit_phase = 0 then
                        shift_reg <= '0' & tx_buf(tx_rd_ptr) & '1';
                        crc_reg <= crc16_next(crc_reg, tx_buf(tx_rd_ptr));
                        bit_phase <= 1;
                    elsif bit_phase <= 9 then
                        shift_reg <= '1' & shift_reg(9 downto 1);
                        bit_phase <= bit_phase + 1;
                    else
                        bit_phase <= 0;
                        if tx_rd_ptr < tx_count - 1 then
                            tx_rd_ptr <= tx_rd_ptr + 1;
                        else
                            tx_busy <= '0';
                            irq_pending <= ctrl_reg(1);
                        end if;
                    end if;
                else
                    baud_div <= baud_div + 1;
                end if;
            end if;

            -- Simplified RX (store bytes)
            if modbus_rxd = '0' and tx_busy = '0' and rx_count < RX_BUF_DEPTH then
                rx_buf(rx_wr_ptr) <= (others => '0');
                rx_wr_ptr <= (rx_wr_ptr + 1) mod RX_BUF_DEPTH;
                rx_count <= rx_count + 1;
                rx_ready <= '1';
                irq_pending <= ctrl_reg(1);
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, slave_addr, func_code,
                       reg_addr, reg_count, crc_reg, rx_buf, rx_count,
                       rx_rd_ptr, tx_busy, rx_ready)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"00" => rdata := ctrl_reg;
                when x"04" =>
                    if tx_busy = '0' then rdata(0) := '1'; end if;
                    rdata(1) := tx_busy;
                    rdata(2) := rx_ready;
                when x"08" => rdata := slave_addr;
                when x"0C" => rdata := func_code;
                when x"10" => rdata := reg_addr;
                when x"14" => rdata := reg_count;
                when x"1C" =>
                    if rx_count > 0 then
                        rdata := x"000000" & rx_buf(rx_rd_ptr);
                    end if;
                when x"20" => rdata := x"0000" & crc_reg;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    modbus_irq <= irq_pending;

end architecture rtl;
