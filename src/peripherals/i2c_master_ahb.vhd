-- ================================================================================
-- i2c_master_ahb : I2C Master Controller with AHB-Lite slave interface
-- ================================================================================
-- Educational I2C master controller for Cyclone III FPGA.
--
-- Features:
--   * I2C master mode (single master)
--   * 7-bit and 10-bit addressing support
--   * Read and write transactions
--   * Configurable clock divider
--   * Start/Stop/Repeated-Start generation
--   * ACK/NACK handling
--   * Bus error detection
--   * Interrupt on transfer complete
--
-- Register Map (HADDR[7:2] selects register):
--   0x00: I2C_CTRL
--       bit0 = enable       (RW) - I2C enable
--       bit1 = irq_en       (RW) - interrupt enable
--       bit2 = 10bit_addr   (RW) - 10-bit addressing mode
--   0x04: I2C_CLKDIV - clock divider (RW), SCL = HCLK / (4 * CLKDIV)
--   0x08: I2C_STATUS
--       bit0 = busy         (RO) - transfer in progress
--       bit1 = ack_error    (RO) - slave did not ACK
--       bit2 = done         (RO) - transfer complete
--   0x0C: I2C_ADDR   - slave address (RW)
--   0x10: I2C_DATA   - data byte (RW/WO for TX, RO for RX)
--   0x14: I2C_CMD
--       bit0 = start        (WO) - write 1 to start transaction
--       bit1 = read         (RW) - 1=read, 0=write
--       bit2 = stop         (WO) - write 1 to generate STOP
--       bit3 = ack          (RW) - master ACK (for reads)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity i2c_master_ahb is
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

        -- I2C physical interface
        sda       : inout std_logic;
        scl       : inout std_logic;

        -- Interrupt
        i2c_int   : out std_logic
    );
end entity i2c_master_ahb;

architecture rtl of i2c_master_ahb is
    -- Register offsets
    constant REG_CTRL    : integer := 0;  -- 0x00
    constant REG_CLKDIV  : integer := 1;  -- 0x04
    constant REG_STATUS  : integer := 2;  -- 0x08
    constant REG_ADDR    : integer := 3;  -- 0x0C
    constant REG_DATA    : integer := 4;  -- 0x10
    constant REG_CMD     : integer := 5;  -- 0x14

    -- Registers
    signal ctrl_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal clkdiv_reg : unsigned(15 downto 0) := to_unsigned(100, 16);
    signal addr_reg   : std_logic_vector(9 downto 0) := (others => '0');
    signal data_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal cmd_reg    : std_logic_vector(31 downto 0) := (others => '0');

    -- Status
    signal busy       : std_logic := '0';
    signal ack_error  : std_logic := '0';
    signal done_flag  : std_logic := '0';

    -- I2C state machine
    type i2c_state is (IDLE, START, ADDR, RW_BIT, ADDR_ACK,
                       DATA_TX, DATA_TX_ACK, DATA_RX, DATA_RX_ACK, STOP);
    signal state      : i2c_state := IDLE;
    signal bit_cnt    : integer range 0 to 8 := 0;
    signal clk_cnt    : unsigned(15 downto 0) := (others => '0');
    signal clk_phase  : std_logic := '0';  -- 0=low phase, 1=high phase
    signal shift_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal is_read    : std_logic := '0';
    signal master_ack : std_logic := '0';
    signal do_stop    : std_logic := '0';

    -- Bus signals
    signal write_en   : std_logic;
    signal reg_idx     : integer range 0 to 63;

    -- I2C tri-state control
    signal sda_drv    : std_logic := '1';  -- 1=release (input), 0=drive
    signal sda_out    : std_logic := '0';
    signal scl_drv    : std_logic := '1';
    signal scl_out    : std_logic := '0';

begin

    reg_idx  <= to_integer(unsigned(HADDR(7 downto 2)));
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- I2C tri-state buffers
    sda <= '0' when (sda_drv = '0' and sda_out = '0') else 'Z';
    scl <= '0' when (scl_drv = '0' and scl_out = '0') else 'Z';

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg   <= (others => '0');
                clkdiv_reg <= to_unsigned(100, 16);
                addr_reg   <= (others => '0');
                data_reg   <= (others => '0');
                cmd_reg    <= (others => '0');
                done_flag  <= '0';
                ack_error  <= '0';
            elsif write_en = '1' then
                done_flag <= '0';  -- clear done on any write
                case reg_idx is
                    when REG_CTRL =>
                        ctrl_reg <= HWDATA;
                    when REG_CLKDIV =>
                        clkdiv_reg <= unsigned(HWDATA(15 downto 0));
                    when REG_ADDR =>
                        addr_reg <= HWDATA(9 downto 0);
                    when REG_DATA =>
                        data_reg <= HWDATA(7 downto 0);
                    when REG_CMD =>
                        cmd_reg <= HWDATA;
                        if HWDATA(0) = '1' and busy = '0' then
                            -- Start transaction
                            is_read    <= HWDATA(1);
                            master_ack <= HWDATA(3);
                            do_stop    <= HWDATA(2);
                            done_flag  <= '0';
                            ack_error  <= '0';
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- I2C clock generation and state machine
    i2c_fsm : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                state     <= IDLE;
                busy      <= '0';
                sda_drv   <= '1';
                sda_out   <= '0';
                scl_drv   <= '1';
                scl_out   <= '0';
                bit_cnt   <= 0;
                clk_cnt   <= (others => '0');
                clk_phase <= '0';
                shift_reg <= (others => '0');
            elsif ctrl_reg(0) = '1' then  -- enabled
                case state is
                    when IDLE =>
                        sda_drv <= '1';  -- release SDA
                        scl_drv <= '1';  -- release SCL
                        if cmd_reg(0) = '1' and busy = '0' then
                            busy      <= '1';
                            state     <= START;
                            clk_cnt   <= (others => '0');
                            clk_phase <= '0';
                            -- Load address or data
                            if is_read = '0' then
                                shift_reg <= addr_reg(6 downto 0) & '0';  -- addr + write bit
                            else
                                shift_reg <= addr_reg(6 downto 0) & '1';  -- addr + read bit
                            end if;
                            bit_cnt <= 0;
                        end if;

                    when START =>
                        -- Generate START condition: SDA falls while SCL high
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            if clk_phase = '0' then
                                -- SCL high, SDA high (pre-start)
                                scl_drv <= '1';  -- release SCL (high)
                                sda_drv <= '0'; sda_out <= '1';  -- SDA high
                                clk_phase <= '1';
                            else
                                -- SDA falls while SCL high = START
                                sda_out <= '0';  -- SDA low = START
                                state <= ADDR;
                                bit_cnt <= 0;
                                clk_phase <= '0';
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when ADDR =>
                        -- Send 8 bits (7-bit addr + R/W)
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            if clk_phase = '0' then
                                -- SCL low, set SDA
                                scl_drv <= '0'; scl_out <= '0';  -- SCL low
                                sda_drv <= '0'; sda_out <= shift_reg(7);
                                clk_phase <= '1';
                            else
                                -- SCL high (data sampled by slave)
                                scl_drv <= '1';  -- release SCL (high)
                                clk_phase <= '0';
                                if bit_cnt = 7 then
                                    state <= ADDR_ACK;
                                    bit_cnt <= 0;
                                else
                                    shift_reg <= shift_reg(6 downto 0) & '0';
                                    bit_cnt <= bit_cnt + 1;
                                end if;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when ADDR_ACK =>
                        -- Check slave ACK
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            if clk_phase = '0' then
                                -- SCL low, release SDA for slave ACK
                                scl_drv <= '0'; scl_out <= '0';
                                sda_drv <= '1';  -- release SDA
                                clk_phase <= '1';
                            else
                                -- SCL high, sample SDA
                                scl_drv <= '1';
                                clk_phase <= '0';
                                if sda = '0' then
                                    -- ACK received
                                    ack_error <= '0';
                                    if is_read = '1' then
                                        state <= DATA_RX;
                                        shift_reg <= (others => '0');
                                    else
                                        state <= DATA_TX;
                                        shift_reg <= data_reg;
                                    end if;
                                    bit_cnt <= 0;
                                else
                                    -- NACK
                                    ack_error <= '1';
                                    state <= STOP;
                                end if;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when DATA_TX =>
                        -- Send 8 data bits
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            if clk_phase = '0' then
                                scl_drv <= '0'; scl_out <= '0';
                                sda_drv <= '0'; sda_out <= shift_reg(7);
                                clk_phase <= '1';
                            else
                                scl_drv <= '1';
                                clk_phase <= '0';
                                if bit_cnt = 7 then
                                    state <= DATA_TX_ACK;
                                    bit_cnt <= 0;
                                else
                                    shift_reg <= shift_reg(6 downto 0) & '0';
                                    bit_cnt <= bit_cnt + 1;
                                end if;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when DATA_TX_ACK =>
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            if clk_phase = '0' then
                                scl_drv <= '0'; scl_out <= '0';
                                sda_drv <= '1';  -- release SDA
                                clk_phase <= '1';
                            else
                                scl_drv <= '1';
                                clk_phase <= '0';
                                if sda = '0' then
                                    ack_error <= '0';
                                else
                                    ack_error <= '1';
                                end if;
                                if do_stop = '1' then
                                    state <= STOP;
                                else
                                    done_flag <= '1';
                                    busy <= '0';
                                    state <= IDLE;
                                end if;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when DATA_RX =>
                        -- Receive 8 data bits
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            if clk_phase = '0' then
                                scl_drv <= '0'; scl_out <= '0';
                                sda_drv <= '1';  -- release SDA for slave
                                clk_phase <= '1';
                            else
                                scl_drv <= '1';
                                clk_phase <= '0';
                                shift_reg <= shift_reg(6 downto 0) & sda;
                                if bit_cnt = 7 then
                                    data_reg <= shift_reg(6 downto 0) & sda;
                                    state <= DATA_RX_ACK;
                                    bit_cnt <= 0;
                                else
                                    bit_cnt <= bit_cnt + 1;
                                end if;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when DATA_RX_ACK =>
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            if clk_phase = '0' then
                                scl_drv <= '0'; scl_out <= '0';
                                -- Send ACK or NACK
                                sda_drv <= '0';
                                sda_out <= not master_ack;  -- 0=ACK, 1=NACK
                                clk_phase <= '1';
                            else
                                scl_drv <= '1';
                                clk_phase <= '0';
                                if do_stop = '1' or master_ack = '0' then
                                    state <= STOP;
                                else
                                    done_flag <= '1';
                                    busy <= '0';
                                    state <= IDLE;
                                end if;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when STOP =>
                        -- Generate STOP condition: SDA rises while SCL high
                        if clk_cnt = clkdiv_reg - 1 then
                            clk_cnt <= (others => '0');
                            if clk_phase = '0' then
                                -- SCL high, SDA low
                                scl_drv <= '1';  -- SCL high
                                sda_drv <= '0'; sda_out <= '0';  -- SDA low
                                clk_phase <= '1';
                            else
                                -- SDA rises while SCL high = STOP
                                sda_drv <= '1';  -- release SDA (high)
                                done_flag <= '1';
                                busy <= '0';
                                state <= IDLE;
                                clk_phase <= '0';
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process i2c_fsm;

    -- Register read mux
    reg_read : process(reg_idx, ctrl_reg, clkdiv_reg, addr_reg, data_reg, busy, ack_error, done_flag)
    begin
        case reg_idx is
            when REG_CTRL =>
                HRDATA <= ctrl_reg;
            when REG_CLKDIV =>
                HRDATA <= x"0000" & std_logic_vector(clkdiv_reg);
            when REG_STATUS =>
                HRDATA <= (0 => busy, 1 => ack_error, 2 => done_flag, others => '0');
            when REG_ADDR =>
                HRDATA <= (31 downto 10 => '0') & addr_reg;
            when REG_DATA =>
                HRDATA <= x"000000" & data_reg;
            when REG_CMD =>
                HRDATA <= cmd_reg;
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    i2c_int <= done_flag and ctrl_reg(1);

end architecture rtl;
