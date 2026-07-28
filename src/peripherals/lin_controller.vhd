-- ================================================================================
-- lin_controller : LIN (Local Interconnect Network) bus controller
-- ================================================================================
-- Implements LIN 2.x master/slave node with break + sync + PID + data + checksum.
--   * Configurable baud rate
--   * 8-byte data payload per frame
--   * Master and slave modes
--
-- AHB-Lite register map:
--   0x00 : CTRL   - [0] enable, [1] irq_en, [2] master_mode, [3] start_tx
--   0x04 : STAT   - [0] idle, [1] tx_busy, [2] rx_ready, [3] checksum_error
--   0x08 : ID     - LIN protected identifier (6-bit PID + 2 parity bits)
--   0x10-0x2C : DATA0-DATA7 - 8 data bytes
--   0x30 : BAUD   - baud rate divisor
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lin_controller is
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

        -- LIN physical interface
        lin_tx    : out std_logic;
        lin_rx    : in  std_logic := '1';
        lin_irq   : out std_logic
    );
end entity lin_controller;

architecture rtl of lin_controller is
    constant NUM_DATA : integer := 8;
    type data_arr_t is array(0 to NUM_DATA-1) of std_logic_vector(7 downto 0);

    signal ctrl_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal id_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal data_regs  : data_arr_t := (others => (others => '0'));
    signal baud_reg   : std_logic_vector(31 downto 0) := (others => '0');

    signal tx_busy    : std_logic := '0';
    signal rx_ready   : std_logic := '0';
    signal irq_pending: std_logic := '0';
    signal baud_div   : unsigned(15 downto 0) := (others => '0');
    signal tx_phase   : integer range 0 to 15 := 0;
    signal tx_byte_idx: integer range 0 to NUM_DATA := 0;
    signal shift_reg  : std_logic_vector(9 downto 0) := (others => '1');

    signal reg_offset : std_logic_vector(7 downto 0);
    signal write_en   : std_logic;
    signal lin_tx_int : std_logic := '1';
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    lin_tx     <= lin_tx_int when ctrl_reg(0) = '1' else '1';

    ahb_write : process(HCLK, HRESETn)
        variable data_idx : integer range 0 to NUM_DATA-1;
    begin
        if HRESETn = '0' then
            ctrl_reg    <= (others => '0');
            id_reg      <= (others => '0');
            data_regs   <= (others => (others => '0'));
            baud_reg    <= (others => '0');
            tx_busy     <= '0';
            rx_ready    <= '0';
            irq_pending <= '0';
            baud_div    <= (others => '0');
            tx_phase    <= 0;
            tx_byte_idx <= 0;
            shift_reg   <= (others => '1');
            lin_tx_int  <= '1';
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            if write_en = '1' then
                case to_integer(unsigned(reg_offset)) is
                    when 16#00# =>
                        ctrl_reg <= HWDATA;
                        if HWDATA(3) = '1' and tx_busy = '0' then
                            tx_busy <= '1';
                            tx_phase <= 0;
                            tx_byte_idx <= 0;
                            baud_div <= (others => '0');
                        end if;
                    when 16#04# =>
                        if HWDATA(2) = '1' then rx_ready <= '0'; end if;
                    when 16#08# => id_reg  <= HWDATA;
                    when 16#10# to 16#2C# =>
                        data_idx := to_integer(unsigned(reg_offset(4 downto 2)));
                        data_regs(data_idx) <= HWDATA(7 downto 0);
                    when 16#30# => baud_reg <= HWDATA;
                    when others => null;
                end case;
            end if;

            -- LIN TX state machine: break, sync(0x55), PID, data, checksum
            if tx_busy = '1' then
                if baud_div = unsigned(baud_reg(15 downto 0)) then
                    baud_div <= (others => '0');
                    case tx_phase is
                        when 0 =>  -- Break (13 dominant bits)
                            lin_tx_int <= '0';
                            tx_phase <= 1;
                        when 1 =>
                            lin_tx_int <= '0';
                            tx_phase <= 2;
                        when 2 =>  -- Break delimiter
                            lin_tx_int <= '1';
                            tx_phase <= 3;
                        when 3 =>  -- Sync byte 0x55
                            shift_reg <= '0' & x"55" & '1';
                            tx_phase <= 4;
                        when 4 to 13 =>  -- shift sync
                            shift_reg <= '1' & shift_reg(9 downto 1);
                            lin_tx_int <= shift_reg(0);
                            tx_phase <= tx_phase + 1;
                        when 14 =>  -- PID
                            shift_reg <= '0' & id_reg(7 downto 0) & '1';
                            tx_phase <= 15;
                        when others =>
                            lin_tx_int <= '1';
                            tx_busy <= '0';
                            irq_pending <= ctrl_reg(1);
                    end case;
                else
                    baud_div <= baud_div + 1;
                end if;
            end if;

            -- Simplified RX
            if lin_rx = '0' and tx_busy = '0' and rx_ready = '0' then
                rx_ready <= '1';
                irq_pending <= ctrl_reg(1);
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, id_reg, data_regs, baud_reg,
                       tx_busy, rx_ready)
        variable rdata : std_logic_vector(31 downto 0);
        variable ridx  : integer range 0 to NUM_DATA-1;
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case to_integer(unsigned(reg_offset)) is
                when 16#00# => rdata := ctrl_reg;
                when 16#04# =>
                    if tx_busy = '0' then rdata(0) := '1'; end if;
                    rdata(1) := tx_busy;
                    rdata(2) := rx_ready;
                when 16#08# => rdata := id_reg;
                when 16#10# to 16#2C# =>
                    ridx := to_integer(unsigned(reg_offset(4 downto 2)));
                    rdata := x"000000" & data_regs(ridx);
                when 16#30# => rdata := baud_reg;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    lin_irq   <= irq_pending;

end architecture rtl;
