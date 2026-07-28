-- ================================================================================
-- spi_master_ahb : SPI Master Controller with AHB-Lite slave interface
-- ================================================================================
-- Educational SPI master controller for Cyclone III FPGA.
--
-- Features:
--   * SPI master mode (Mode 0-3, CPOL/CPHA configurable)
--   * 8/16/32-bit transfer size
--   * Configurable clock divider
--   * Up to 4 slave select outputs
--   * MSB/LSB first selectable
--   * Interrupt on transfer complete
--
-- Register Map (HADDR[7:2] selects register):
--   0x00: SPI_CTRL
--       bit0    = enable       (RW) - SPI enable
--       bit1    = irq_en       (RW) - interrupt enable
--       bit2    = cpol         (RW) - clock polarity
--       bit3    = cpha         (RW) - clock phase
--       bit4    = msb_first    (RW) - 1=MSB first, 0=LSB first
--       bit5..6 = slave_sel    (RW) - slave select (0-3)
--   0x04: SPI_CLKDIV - clock divider (RW), SCLK = HCLK / (2 * CLKDIV)
--   0x08: SPI_STATUS
--       bit0 = busy            (RO) - transfer in progress
--       bit1 = done            (RO) - transfer complete
--   0x0C: SPI_DATA - data to send (WO) / data received (RO)
--   0x10: SPI_SIZE - transfer size in bits (RW, 8/16/32)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_master_ahb is
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

        -- SPI physical interface
        sclk      : out std_logic;
        mosi      : out std_logic;
        miso      : in  std_logic;
        ss_n      : out std_logic_vector(3 downto 0);

        -- Interrupt
        spi_int   : out std_logic
    );
end entity spi_master_ahb;

architecture rtl of spi_master_ahb is
    constant REG_CTRL    : integer := 0;
    constant REG_CLKDIV  : integer := 1;
    constant REG_STATUS  : integer := 2;
    constant REG_DATA    : integer := 3;
    constant REG_SIZE    : integer := 4;

    signal ctrl_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal clkdiv_reg : unsigned(15 downto 0) := to_unsigned(4, 16);
    signal size_reg   : integer range 8 to 32 := 8;
    signal rx_data    : std_logic_vector(31 downto 0) := (others => '0');
    signal busy       : std_logic := '0';
    signal done_flag  : std_logic := '0';

    type spi_state is (IDLE, SETUP, CLOCK_LOW, CLOCK_HIGH, SAMPLE, DONE_ST);
    signal state      : spi_state := IDLE;
    signal bit_cnt    : integer range 0 to 32 := 0;
    signal clk_cnt    : unsigned(15 downto 0) := (others => '0');
    signal shift_tx   : std_logic_vector(31 downto 0) := (others => '0');
    signal shift_rx   : std_logic_vector(31 downto 0) := (others => '0');
    signal sclk_reg   : std_logic := '0';
    signal mosi_reg   : std_logic := '0';
    signal ss_reg     : std_logic_vector(3 downto 0) := (others => '1');
    signal start_xfer : std_logic := '0';

    signal write_en   : std_logic;
    signal reg_idx    : integer range 0 to 63;

begin

    reg_idx  <= to_integer(unsigned(HADDR(7 downto 2)));
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    sclk <= sclk_reg;
    mosi <= mosi_reg;
    ss_n <= ss_reg;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg   <= (others => '0');
                clkdiv_reg <= to_unsigned(4, 16);
                size_reg   <= 8;
                done_flag  <= '0';
                start_xfer <= '0';
            elsif write_en = '1' then
                done_flag <= '0';
                start_xfer <= '0';
                case reg_idx is
                    when REG_CTRL =>
                        ctrl_reg <= HWDATA;
                    when REG_CLKDIV =>
                        clkdiv_reg <= unsigned(HWDATA(15 downto 0));
                    when REG_DATA =>
                        if busy = '0' then
                            shift_tx <= HWDATA;
                            start_xfer <= '1';
                        end if;
                    when REG_SIZE =>
                        if unsigned(HWDATA(5 downto 0)) = 8 or unsigned(HWDATA(5 downto 0)) = 16 or unsigned(HWDATA(5 downto 0)) = 32 then
                            size_reg <= to_integer(unsigned(HWDATA(5 downto 0)));
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- SPI state machine
    spi_fsm : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                state    <= IDLE;
                busy     <= '0';
                sclk_reg <= '0';
                mosi_reg <= '0';
                ss_reg   <= (others => '1');
                shift_rx <= (others => '0');
                rx_data  <= (others => '0');
                bit_cnt  <= 0;
                clk_cnt  <= (others => '0');
            elsif ctrl_reg(0) = '1' then  -- enabled
                case state is
                    when IDLE =>
                        sclk_reg <= ctrl_reg(2);  -- idle CPOL
                        ss_reg   <= (others => '1');
                        if start_xfer = '1' then
                            busy    <= '1';
                            state   <= SETUP;
                            bit_cnt <= 0;
                            clk_cnt <= (others => '0');
                            -- Assert slave select
                            case ctrl_reg(5 downto 4) is
                                when "00" => ss_reg <= "1110";
                                when "01" => ss_reg <= "1101";
                                when "10" => ss_reg <= "1011";
                                when "11" => ss_reg <= "0111";
                                when others => ss_reg <= "1111";
                            end case;
                        end if;

                    when SETUP =>
                        -- Prepare first bit
                        if ctrl_reg(4) = '1' then  -- MSB first
                            mosi_reg <= shift_tx(size_reg - 1);
                        else
                            mosi_reg <= shift_tx(0);
                        end if;
                        sclk_reg <= ctrl_reg(2);
                        state <= CLOCK_LOW;
                        clk_cnt <= (others => '0');

                    when CLOCK_LOW =>
                        -- SCL low phase
                        sclk_reg <= ctrl_reg(2) xor ctrl_reg(3);  -- CPHA adjustment
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            state <= CLOCK_HIGH;
                            -- Set MOSI for next bit
                            if ctrl_reg(4) = '1' then  -- MSB first
                                if bit_cnt < size_reg - 1 then
                                    mosi_reg <= shift_tx(size_reg - 2 - bit_cnt);
                                end if;
                            else
                                if bit_cnt < size_reg - 1 then
                                    mosi_reg <= shift_tx(bit_cnt + 1);
                                end if;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when CLOCK_HIGH =>
                        -- SCL high phase
                        sclk_reg <= not (ctrl_reg(2) xor ctrl_reg(3));
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            state <= SAMPLE;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when SAMPLE =>
                        -- Sample MISO
                        if ctrl_reg(4) = '1' then  -- MSB first
                            shift_rx <= shift_rx(30 downto 0) & miso;
                        else
                            shift_rx <= miso & shift_rx(31 downto 1);
                        end if;
                        if bit_cnt = size_reg - 1 then
                            state <= DONE_ST;
                        else
                            bit_cnt <= bit_cnt + 1;
                            state <= CLOCK_LOW;
                        end if;

                    when DONE_ST =>
                        -- Transfer complete
                        rx_data <= shift_rx;
                        done_flag <= '1';
                        busy <= '0';
                        ss_reg <= (others => '1');
                        sclk_reg <= ctrl_reg(2);  -- idle
                        state <= IDLE;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process spi_fsm;

    -- Register read mux
    reg_read : process(reg_idx, ctrl_reg, clkdiv_reg, rx_data, busy, done_flag, size_reg)
    begin
        case reg_idx is
            when REG_CTRL =>
                HRDATA <= ctrl_reg;
            when REG_CLKDIV =>
                HRDATA <= x"0000" & std_logic_vector(clkdiv_reg);
            when REG_STATUS =>
                HRDATA <= (0 => busy, 1 => done_flag, others => '0');
            when REG_DATA =>
                HRDATA <= rx_data;
            when REG_SIZE =>
                HRDATA <= std_logic_vector(to_unsigned(size_reg, 32));
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    spi_int <= done_flag and ctrl_reg(1);

end architecture rtl;
