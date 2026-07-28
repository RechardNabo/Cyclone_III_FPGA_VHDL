-- ================================================================================
-- pic_mssp : PIC Master Synchronous Serial Port (SPI + I2C) with AHB-Lite slave
-- ================================================================================
-- Combined SPI and I2C master mode serial port.
-- Registers: SSPCON1, SSPCON2, SSPSTAT, SSPBUF, SSPADD, SSPMSK.
--
-- Register Map (HADDR[5:2]):
--   0x00: SSPCON1 - Sync Serial Port Control 1
--   0x04: SSPCON2 - Sync Serial Port Control 2 (I2C)
--   0x08: SSPSTAT - Sync Serial Port Status
--   0x0C: SSPBUF  - Serial receive/transmit buffer
--   0x10: SSPADD  - Address/baud rate register
--   0x14: SSPMSK  - Address mask register (I2C)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pic_mssp is
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

        -- SPI pins
        sck  : out std_logic;
        sdi  : in  std_logic;
        sdo  : out std_logic;
        -- I2C pins
        sda  : inout std_logic;
        scl  : out std_logic;
        -- Interrupt
        mssp_irq : out std_logic
    );
end entity pic_mssp;

architecture rtl of pic_mssp is

    constant REG_SSPCON1 : std_logic_vector(3 downto 0) := "0000";
    constant REG_SSPCON2 : std_logic_vector(3 downto 0) := "0001";
    constant REG_SSPSTAT : std_logic_vector(3 downto 0) := "0010";
    constant REG_SSPBUF  : std_logic_vector(3 downto 0) := "0011";
    constant REG_SSPADD  : std_logic_vector(3 downto 0) := "0100";
    constant REG_SSPMSK  : std_logic_vector(3 downto 0) := "0101";

    signal sspcon1_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal sspcon2_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal sspstat_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal sspbuf_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal sspadd_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal sspmsk_reg  : std_logic_vector(7 downto 0) := (others => '0');

    -- Shift register and bit counter
    signal shift_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_cnt     : integer range 0 to 7 := 0;
    signal sck_out     : std_logic := '0';
    signal sdo_out     : std_logic := '0';
    signal scl_out     : std_logic := '1';
    signal sda_out     : std_logic := '1';
    signal busy        : std_logic := '0';
    signal irq_pending : std_logic := '0';
    signal baud_cnt    : unsigned(7 downto 0) := (others => '0');
    signal baud_tick   : std_logic := '0';

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Baud rate generator (uses SSPADD as divider in I2C, fixed in SPI)
    baud_proc : process(HCLK)
        variable baud_div : unsigned(7 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                baud_cnt <= (others => '0');
                baud_tick <= '0';
            else
                -- SPI mode: use simpler divider; I2C: use SSPADD
                if sspcon1_reg(3 downto 0) = "0011" or sspcon1_reg(3 downto 0) = "1011" then
                    baud_div := unsigned(sspadd_reg);
                else
                    baud_div := x"04"; -- SPI default
                end if;
                if baud_div = 0 then baud_div := x"01"; end if;
                if baud_cnt = baud_div - 1 then
                    baud_cnt <= (others => '0');
                    baud_tick <= '1';
                else
                    baud_cnt <= baud_cnt + 1;
                    baud_tick <= '0';
                end if;
            end if;
        end if;
    end process baud_proc;

    -- Main SPI/I2C shift process
    mssp_proc : process(HCLK)
        variable sspen : std_logic;
        variable is_i2c : std_logic;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                sspcon1_reg <= (others => '0');
                sspcon2_reg <= (others => '0');
                sspstat_reg <= (others => '0');
                sspbuf_reg  <= (others => '0');
                sspadd_reg  <= (others => '0');
                sspmsk_reg  <= (others => '0');
                shift_reg   <= (others => '0');
                bit_cnt     <= 0;
                sck_out     <= '0';
                sdo_out     <= '0';
                scl_out     <= '1';
                sda_out     <= '1';
                busy        <= '0';
                irq_pending <= '0';
            else
                sspen := sspcon1_reg(5); -- SSPEN: enable
                -- I2C modes: SSPM = 1000, 1011, 1110, 1111
                is_i2c := sspcon1_reg(3) and not sspcon1_reg(2);

                -- Register writes
                if write_en = '1' then
                    case reg_sel is
                        when REG_SSPCON1 => sspcon1_reg <= HWDATA(7 downto 0);
                        when REG_SSPCON2 => sspcon2_reg <= HWDATA(7 downto 0);
                        when REG_SSPSTAT => sspstat_reg <= HWDATA(7 downto 0);
                        when REG_SSPADD => sspadd_reg <= HWDATA(7 downto 0);
                        when REG_SSPMSK => sspmsk_reg <= HWDATA(7 downto 0);
                        when REG_SSPBUF =>
                            sspbuf_reg <= HWDATA(7 downto 0);
                            shift_reg  <= HWDATA(7 downto 0);
                            bit_cnt    <= 0;
                            busy       <= '1';
                            sspstat_reg(0) <= '0'; -- BF clear
                        when others => null;
                    end case;
                    -- Clear IRQ on SSPCON1 write with SSPOV=1
                    if reg_sel = REG_SSPCON1 and HWDATA(7) = '1' then
                        irq_pending <= '0';
                    end if;
                end if;

                -- Shift register operation
                if busy = '1' and baud_tick = '1' then
                    -- SPI: shift MSB out, LSB in from SDI
                    if is_i2c = '0' then
                        sdo_out <= shift_reg(7);
                        shift_reg <= shift_reg(6 downto 0) & sdi;
                        sck_out <= not sck_out;
                    else
                        -- I2C: simplified shift
                        sda_out <= shift_reg(7);
                        shift_reg <= shift_reg(6 downto 0) & sda;
                        scl_out <= not scl_out;
                    end if;

                    if bit_cnt = 7 then
                        bit_cnt <= 0;
                        busy <= '0';
                        if is_i2c = '0' then
                            sspbuf_reg <= shift_reg(6 downto 0) & sdi;
                        else
                            sspbuf_reg <= shift_reg(6 downto 0) & sda;
                        end if;
                        sspstat_reg(0) <= '1'; -- BF set
                        irq_pending <= '1';
                    else
                        bit_cnt <= bit_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process mssp_proc;

    -- Register read mux
    reg_read : process(reg_sel, sspcon1_reg, sspcon2_reg, sspstat_reg,
                       sspbuf_reg, sspadd_reg, sspmsk_reg)
    begin
        case reg_sel is
            when REG_SSPCON1 => HRDATA <= x"000000" & sspcon1_reg;
            when REG_SSPCON2 => HRDATA <= x"000000" & sspcon2_reg;
            when REG_SSPSTAT => HRDATA <= x"000000" & sspstat_reg;
            when REG_SSPBUF  => HRDATA <= x"000000" & sspbuf_reg;
            when REG_SSPADD  => HRDATA <= x"000000" & sspadd_reg;
            when REG_SSPMSK  => HRDATA <= x"000000" & sspmsk_reg;
            when others      => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    -- Pin outputs (SPI vs I2C based on mode)
    sck <= sck_out when (sspcon1_reg(5) = '1' and sspcon1_reg(3 downto 0) /= "1000") else 'Z';
    sdo <= sdo_out when (sspcon1_reg(5) = '1' and sspcon1_reg(3 downto 0) /= "1000") else 'Z';
    scl <= scl_out when (sspcon1_reg(5) = '1' and sspcon1_reg(3) = '1') else 'Z';
    sda <= sda_out when (sspcon1_reg(5) = '1' and sspcon1_reg(3) = '1' and busy = '1') else 'Z';

    mssp_irq <= irq_pending and sspcon1_reg(3);

end architecture rtl;
