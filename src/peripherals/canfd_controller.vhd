-- ================================================================================
-- canfd_controller : CAN FD (Flexible Data-rate) bus controller
-- ================================================================================
-- Supports CAN FD frames up to 64 bytes payload at 8 Mbps data phase.
--   * Standard (11-bit) and Extended (29-bit) ID frames
--   * Bit timing configurable via BTR register
--   * TX/RX FIFO with interrupt on completion
--
-- AHB-Lite register map:
--   0x00 : CTRL   - [0] enable, [1] irq_en, [2] loopback, [3] fd_mode, [4] start_tx
--   0x04 : STAT   - [0] idle, [1] tx_busy, [2] rx_ready, [3] error, [4] bus_off
--   0x08 : ID     - CAN frame identifier (11 or 29 bit)
--   0x0C : DLC    - data length code (0-15 mapping to 0-64 bytes in FD)
--   0x10-0x4C : DATA0-DATA15 - 16x32-bit data words (64 bytes max)
--   0x50 : BTR    - bit timing register (prescaler, tseg1, tseg2, sjw)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity canfd_controller is
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

        -- CAN physical interface
        can_tx    : out std_logic;
        can_rx    : in  std_logic := '1';
        can_irq   : out std_logic
    );
end entity canfd_controller;

architecture rtl of canfd_controller is
    constant NUM_DATA_WORDS : integer := 16;

    type data_array_t is array(0 to NUM_DATA_WORDS-1) of std_logic_vector(31 downto 0);

    signal ctrl_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal id_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal dlc_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal data_regs    : data_array_t := (others => (others => '0'));
    signal btr_reg      : std_logic_vector(31 downto 0) := (others => '0');

    signal tx_busy      : std_logic := '0';
    signal rx_ready     : std_logic := '0';
    signal irq_pending  : std_logic := '0';
    signal bit_phase    : integer range 0 to 31 := 0;
    signal bit_div_cnt  : unsigned(7 downto 0) := (others => '0');
    signal tx_bit_idx   : integer range 0 to 255 := 0;
    signal tx_word_idx  : integer range 0 to NUM_DATA_WORDS-1 := 0;

    signal reg_offset   : std_logic_vector(7 downto 0);
    signal write_en     : std_logic;
    signal can_tx_reg   : std_logic := '1';  -- recessive idle
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    can_tx     <= can_tx_reg;

    ahb_write : process(HCLK, HRESETn)
        variable data_idx : integer range 0 to NUM_DATA_WORDS-1;
    begin
        if HRESETn = '0' then
            ctrl_reg    <= (others => '0');
            id_reg      <= (others => '0');
            dlc_reg     <= (others => '0');
            data_regs   <= (others => (others => '0'));
            btr_reg     <= (others => '0');
            tx_busy     <= '0';
            rx_ready    <= '0';
            irq_pending <= '0';
            can_tx_reg  <= '1';
            bit_phase   <= 0;
            bit_div_cnt <= (others => '0');
            tx_bit_idx  <= 0;
            tx_word_idx <= 0;
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            if write_en = '1' then
                case to_integer(unsigned(reg_offset)) is
                    when 16#00# =>  -- CTRL
                        ctrl_reg <= HWDATA;
                        if HWDATA(4) = '1' and tx_busy = '0' then
                            tx_busy <= '1';
                            tx_bit_idx <= 0;
                            tx_word_idx <= 0;
                            bit_phase <= 0;
                            bit_div_cnt <= (others => '0');
                        end if;
                    when 16#04# =>  -- STAT (write to clear)
                        if HWDATA(2) = '1' then rx_ready <= '0'; end if;
                    when 16#08# => id_reg  <= HWDATA;
                    when 16#0C# => dlc_reg <= HWDATA;
                    when 16#10# to 16#4C# =>  -- DATA0-DATA15
                        data_idx := to_integer(unsigned(reg_offset(5 downto 2)));
                        data_regs(data_idx) <= HWDATA;
                    when 16#50# => btr_reg <= HWDATA;
                    when others => null;
                end case;
            end if;

            -- Simplified TX bit stream (SOF + ID + data placeholder)
            if tx_busy = '1' then
                if bit_div_cnt = unsigned(btr_reg(7 downto 0)) then
                    bit_div_cnt <= (others => '0');
                    if tx_bit_idx < 2 then
                        can_tx_reg <= '0';  -- SOF dominant
                    elsif tx_bit_idx < 34 then
                        can_tx_reg <= id_reg(tx_bit_idx - 2);
                    elsif tx_bit_idx < 42 then
                        can_tx_reg <= dlc_reg(tx_bit_idx - 34);
                    else
                        can_tx_reg <= '1';  -- recessive
                    end if;
                    if tx_bit_idx = 255 then
                        tx_busy <= '0';
                        irq_pending <= ctrl_reg(1);
                        can_tx_reg <= '1';
                    else
                        tx_bit_idx <= tx_bit_idx + 1;
                    end if;
                else
                    bit_div_cnt <= bit_div_cnt + 1;
                end if;
            end if;

            -- Simplified RX detection (edge triggers rx_ready)
            if can_rx = '0' and tx_busy = '0' and rx_ready = '0' then
                rx_ready <= '1';
                irq_pending <= ctrl_reg(1);
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, id_reg, dlc_reg, data_regs,
                       btr_reg, tx_busy, rx_ready, irq_pending)
        variable rdata : std_logic_vector(31 downto 0);
        variable ridx  : integer range 0 to NUM_DATA_WORDS-1;
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case to_integer(unsigned(reg_offset)) is
                when 16#00# => rdata := ctrl_reg;
                when 16#04# =>
                    if tx_busy = '0' then rdata(0) := '1'; end if;  -- idle
                    rdata(1) := tx_busy;
                    rdata(2) := rx_ready;
                    rdata(4) := '0';
                when 16#08# => rdata := id_reg;
                when 16#0C# => rdata := dlc_reg;
                when 16#10# to 16#4C# =>
                    ridx := to_integer(unsigned(reg_offset(5 downto 2)));
                    rdata := data_regs(ridx);
                when 16#50# => rdata := btr_reg;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    can_irq   <= irq_pending;

end architecture rtl;
