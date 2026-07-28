-- ================================================================================
-- i2s_tdm_controller : I2S with TDM (Time Division Multiplexing) controller
-- ================================================================================
-- Supports I2S audio and TDM mode for 8 or 16 channels of digital audio.
--   * Configurable slot count (8 or 16) and slot size (16/24/32 bit)
--   * Independent TX and RX data registers
--   * Frame sync and bit clock generation
--
-- AHB-Lite register map:
--   0x00 : CTRL       - [0] enable, [1] irq_en, [2] tdm_mode, [3] master_clk
--   0x04 : STAT       - [0] tx_ready, [1] rx_ready, [2] busy
--   0x08 : TDM_SLOTS  - number of TDM slots (8 or 16)
--   0x0C : SLOT_SIZE  - slot width in bits (16, 24, or 32)
--   0x10 : TX_DATA    - transmit data (write triggers TX slot)
--   0x14 : RX_DATA    - received data (read-only, current slot)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity i2s_tdm_controller is
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

        -- I2S/TDM interface
        i2s_sck   : out std_logic;   -- serial bit clock (BCLK)
        i2s_ws    : out std_logic;   -- word select / frame sync (FS)
        i2s_sd_tx : out std_logic;   -- serial data out
        i2s_sd_rx : in  std_logic := '0';  -- serial data in
        i2s_fs    : out std_logic;   -- frame sync (for TDM)
        i2s_irq   : out std_logic
    );
end entity i2s_tdm_controller;

architecture rtl of i2s_tdm_controller is
    signal ctrl_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal tdm_slots_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal slot_size_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal tx_data_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_data_reg   : std_logic_vector(31 downto 0) := (others => '0');

    signal tx_ready      : std_logic := '0';
    signal rx_ready      : std_logic := '0';
    signal irq_pending   : std_logic := '0';

    signal sck_int       : std_logic := '0';
    signal ws_int        : std_logic := '0';
    signal sd_tx_int     : std_logic := '0';
    signal fs_int        : std_logic := '0';

    signal bit_clk_div   : unsigned(7 downto 0) := (others => '0');
    signal bit_idx       : integer range 0 to 31 := 0;
    signal slot_idx      : integer range 0 to 15 := 0;
    signal tx_shift      : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_shift      : std_logic_vector(31 downto 0) := (others => '0');
    signal num_slots     : integer range 8 to 16 := 8;
    signal cur_slot_size : integer range 16 to 32 := 32;

    signal reg_offset    : std_logic_vector(7 downto 0);
    signal write_en      : std_logic;
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    i2s_sck    <= sck_int when ctrl_reg(0) = '1' else '0';
    i2s_ws     <= ws_int  when ctrl_reg(0) = '1' else '0';
    i2s_sd_tx  <= sd_tx_int when ctrl_reg(0) = '1' else '0';
    i2s_fs     <= fs_int  when ctrl_reg(0) = '1' else '0';

    num_slots     <= 16 when tdm_slots_reg(0) = '1' else 8;
    cur_slot_size <= 16 when slot_size_reg(3 downto 0) = x"0" else
                     24 when slot_size_reg(3 downto 0) = x"1" else 32;

    ahb_write : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            ctrl_reg      <= (others => '0');
            tdm_slots_reg <= (others => '0');
            slot_size_reg <= (others => '0');
            tx_data_reg   <= (others => '0');
            rx_data_reg   <= (others => '0');
            tx_ready      <= '1';
            rx_ready      <= '0';
            irq_pending   <= '0';
            sck_int       <= '0';
            ws_int        <= '0';
            sd_tx_int     <= '0';
            fs_int        <= '0';
            bit_clk_div   <= (others => '0');
            bit_idx       <= 0;
            slot_idx      <= 0;
            tx_shift      <= (others => '0');
            rx_shift      <= (others => '0');
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            if write_en = '1' then
                case reg_offset is
                    when x"00" => ctrl_reg      <= HWDATA;
                    when x"08" => tdm_slots_reg <= HWDATA;
                    when x"0C" => slot_size_reg <= HWDATA;
                    when x"10" =>
                        tx_data_reg <= HWDATA;
                        tx_shift    <= HWDATA;
                        tx_ready    <= '0';
                    when others => null;
                end case;
            end if;

            -- Bit clock generation
            if ctrl_reg(0) = '1' then
                if bit_clk_div = 9 then  -- divider for BCLK
                    bit_clk_div <= (others => '0');
                    sck_int <= not sck_int;

                    -- On falling edge of SCK, shift data
                    if sck_int = '1' then
                        sd_tx_int <= tx_shift(31);
                        tx_shift  <= tx_shift(30 downto 0) & '0';
                        rx_shift  <= rx_shift(30 downto 0) & i2s_sd_rx;

                        if bit_idx = cur_slot_size - 1 then
                            bit_idx <= 0;
                            -- Slot complete
                            if slot_idx = num_slots - 1 then
                                slot_idx <= 0;
                                ws_int <= '1';  -- WS toggle for new frame
                                fs_int <= '1';
                                rx_data_reg <= rx_shift;
                                rx_ready <= '1';
                                tx_ready <= '1';
                                irq_pending <= ctrl_reg(1);
                            else
                                slot_idx <= slot_idx + 1;
                                ws_int <= '0';
                                fs_int <= '0';
                            end if;
                        else
                            bit_idx <= bit_idx + 1;
                        end if;
                    end if;
                else
                    bit_clk_div <= bit_clk_div + 1;
                end if;
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, tdm_slots_reg,
                       slot_size_reg, rx_data_reg, tx_ready, rx_ready)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"00" => rdata := ctrl_reg;
                when x"04" =>
                    rdata(0) := tx_ready;
                    rdata(1) := rx_ready;
                when x"08" => rdata := tdm_slots_reg;
                when x"0C" => rdata := slot_size_reg;
                when x"14" => rdata := rx_data_reg;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    i2s_irq   <= irq_pending;

end architecture rtl;
