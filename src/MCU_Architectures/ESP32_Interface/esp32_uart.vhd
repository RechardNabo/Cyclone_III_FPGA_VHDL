-- ================================================================================
-- esp32_uart : ESP32-style UART interface model with full TX and RX
-- Educational bus interface model -- not a full ESP32 CPU core.  Target: Cyclone III.
--
-- Models a configurable UART with baud rate generator, parity (none/even/odd),
-- 5-8 data bits, 1-2 stop bits, FIFO flags, flow control, and error detection.
--
-- REGISTER MAP (4-bit addr):
-- 0x0 TXDATA  -- Write: TX data byte.  Read: echo of last TX byte.
-- 0x1 RXDATA  -- Read: RX data byte (reading clears RX_READY).
-- 0x2 STATUS  -- bit7=RX_OVERRUN, bit6=FRAMING_ERR, bit5=PARITY_ERR,
--               bit4=TX_BUSY, bit3=RX_READY, bit2=TX_EMPTY, bit1=RX_FULL, bit0=CTS_STATE
-- 0x3 CTRL    -- bit7=TX_EN, bit6=RX_EN, bit5=RTS_EN, bit4=PARITY_EN,
--               bit3=PARITY_EVEN(1)/ODD(0), bit2=STOP2(1=2stop,0=1stop),
--               bit1:0=DATABITS(00=5,01=6,10=7,11=8)
-- 0x4 BAUD_L  -- Baud rate divisor low byte
-- 0x5 BAUD_H  -- Baud rate divisor high byte (16-bit total)
-- 0x6 FIFO_CTRL-- bit7=RX_FIFO_FLUSH, bit6=TX_FIFO_FLUSH, bit3:0=RX_FIFO_THRESHOLD
-- 0x7 INT_EN  -- bit2=TX_INT_EN, bit1=RX_INT_EN, bit0=ERR_INT_EN
-- 0x8 INT_ST  -- bit2=TX_DONE, bit1=RX_READY, bit0=ERR (read to clear)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity esp32_uart is
    port (
        clk, reset  : in  std_logic;
        -- Memory-mapped register interface
        cs, we      : in  std_logic;
        addr        : in  std_logic_vector(3 downto 0);  -- 4-bit register select
        din         : in  std_logic_vector(7 downto 0);
        dout        : out std_logic_vector(7 downto 0);
        -- UART physical pins
        txd         : out std_logic;
        rxd         : in  std_logic;
        rts_n       : out std_logic;  -- flow control (active-low request to send)
        cts_n       : in  std_logic;  -- flow control (active-low clear to send)
        -- Interrupts
        tx_int      : out std_logic;  -- TX complete interrupt
        rx_int      : out std_logic;  -- RX ready interrupt
        err_int     : out std_logic   -- error interrupt (parity/framing/overrun)
    );
end entity esp32_uart;

architecture rtl of esp32_uart is
    -- Register address constants
    constant R_TXDATA   : std_logic_vector(3 downto 0) := "0000"; -- 0x0
    constant R_RXDATA   : std_logic_vector(3 downto 0) := "0001"; -- 0x1
    constant R_STATUS   : std_logic_vector(3 downto 0) := "0010"; -- 0x2
    constant R_CTRL     : std_logic_vector(3 downto 0) := "0011"; -- 0x3
    constant R_BAUD_L   : std_logic_vector(3 downto 0) := "0100"; -- 0x4
    constant R_BAUD_H   : std_logic_vector(3 downto 0) := "0101"; -- 0x5
    constant R_FIFO_CTRL: std_logic_vector(3 downto 0) := "0110"; -- 0x6
    constant R_INT_EN   : std_logic_vector(3 downto 0) := "0111"; -- 0x7
    constant R_INT_ST   : std_logic_vector(3 downto 0) := "1000"; -- 0x8

    -- Control register: TX/RX enable, parity, stop bits, data bits
    signal ctrl_reg     : std_logic_vector(7 downto 0) := (others => '0');
    -- Baud rate divisor (16-bit)
    signal baud_l_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal baud_h_reg   : std_logic_vector(7 downto 0) := (others => '0');
    -- Interrupt enable and status
    signal int_en_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal int_st_reg   : std_logic_vector(7 downto 0) := (others => '0');

    -- TX state: data register, shift register, busy, bit counter, baud counter
    signal tx_data      : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_shift     : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_busy      : std_logic := '0';
    signal tx_bit_idx   : integer range 0 to 11 := 0;  -- start+data+parity+stop+stop2
    signal tx_baud_cnt  : integer range 0 to 65535 := 0;
    signal tx_parity_calc : std_logic := '0';  -- running parity for TX

    -- RX state: data register, shift register, busy, bit counter, baud counter
    signal rx_data      : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_shift     : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_busy      : std_logic := '0';
    signal rx_bit_idx   : integer range 0 to 11 := 0;
    signal rx_baud_cnt  : integer range 0 to 65535 := 0;
    signal rx_parity_calc : std_logic := '0';  -- running parity for RX
    signal rxd_prev     : std_logic := '1';    -- for start bit detection

    -- Status register (assembled from individual flags)
    signal rx_overrun   : std_logic := '0';
    signal framing_err  : std_logic := '0';
    signal parity_err   : std_logic := '0';
    signal rx_ready     : std_logic := '0';  -- RX data available
    signal tx_empty     : std_logic := '1';  -- TX buffer empty

    -- Helper: 16-bit baud divisor
    signal baud_divisor : unsigned(15 downto 0);

begin

    -- Combine baud high and low into 16-bit divisor
    baud_divisor <= unsigned(baud_h_reg) & unsigned(baud_l_reg);

    -- ==================================================================
    -- PROCESS: tx_rx_engine -- UART TX and RX state machines + register writes
    -- ==================================================================
    process(clk, reset)
        -- Local variables for computing parity and frame length
        variable parity_temp  : std_logic;
        variable parity_offset: integer;  -- 1 if parity enabled, 0 otherwise
        variable stop_bits    : integer;  -- 1 or 2 stop bits
    begin
        if reset = '1' then
            -- Active-high reset: clear all registers and state
            ctrl_reg   <= (others => '0');
            baud_l_reg <= (others => '0');
            baud_h_reg <= (others => '0');
            int_en_reg <= (others => '0');
            int_st_reg <= (others => '0');
            tx_data    <= (others => '0');
            tx_shift   <= (others => '0');
            tx_busy    <= '0';
            tx_bit_idx <= 0;
            tx_baud_cnt<= 0;
            rx_data    <= (others => '0');
            rx_shift   <= (others => '0');
            rx_busy    <= '0';
            rx_bit_idx <= 0;
            rx_baud_cnt<= 0;
            rxd_prev   <= '1';
            rx_overrun <= '0';
            framing_err<= '0';
            parity_err <= '0';
            rx_ready   <= '0';
            tx_empty   <= '1';
        elsif rising_edge(clk) then
            -- ---- CPU register writes ----
            if cs = '1' and we = '1' then
                case addr is
                    when R_CTRL      => ctrl_reg <= din;
                    when R_BAUD_L    => baud_l_reg <= din;
                    when R_BAUD_H    => baud_h_reg <= din;
                    when R_INT_EN    => int_en_reg <= din;
                    -- TXDATA write: load data and start TX if enabled and idle
                    when R_TXDATA    =>
                        if ctrl_reg(7) = '1' and tx_busy = '0' then
                            tx_data  <= din;
                            tx_shift <= din;
                            tx_busy  <= '1';
                            tx_empty <= '0';
                            tx_bit_idx <= 0;
                            tx_baud_cnt <= 0;
                            -- Compute initial parity (XOR all data bits)
                            parity_temp := '0';
                            for i in 0 to 7 loop
                                parity_temp := parity_temp xor din(i);
                            end loop;
                            tx_parity_calc <= parity_temp;
                        end if;
                    -- RXDATA read clears RX_READY (handled in read process via we=0)
                    -- FIFO_CTRL: flush bits (simplified -- just clear flags)
                    when R_FIFO_CTRL =>
                        if din(7) = '1' then rx_ready <= '0'; rx_overrun <= '0'; end if;
                        if din(6) = '1' then tx_empty <= '1'; end if;
                    -- INT_ST: writing '1' to a bit clears it
                    when R_INT_ST =>
                        if din(2)='1' then int_st_reg(2)<='0'; end if;
                        if din(1)='1' then int_st_reg(1)<='0'; end if;
                        if din(0)='1' then int_st_reg(0)<='0'; end if;
                    when others => null;
                end case;
            end if;

            -- Clear RX_READY when CPU reads RXDATA
            if cs = '1' and we = '0' and addr = R_RXDATA then
                rx_ready <= '0';
            end if;

            -- ---- UART TX state machine ----
            -- Frame: start(0) + data(5-8 bits) + parity(optional) + stop(1-2)
            -- Compute parity offset and stop bits from control register
            if ctrl_reg(4) = '1' then parity_offset := 1; else parity_offset := 0; end if;
            if ctrl_reg(2) = '1' then stop_bits := 2; else stop_bits := 1; end if;
            if tx_busy = '1' then
                if tx_baud_cnt >= to_integer(baud_divisor) then
                    tx_baud_cnt <= 0;
                    -- tx_bit_idx: 0=start, 1..N=data, N+1=parity, then stop(s)
                    -- Total = 1 + (5+ctrl) + parity_offset + stop_bits
                    if tx_bit_idx = 0 then
                        tx_bit_idx <= tx_bit_idx + 1;  -- start bit done
                    elsif tx_bit_idx <= to_integer(unsigned(ctrl_reg(1 downto 0))) + 5 then
                        tx_bit_idx <= tx_bit_idx + 1;  -- data bits
                    elsif ctrl_reg(4) = '1' and
                          tx_bit_idx = to_integer(unsigned(ctrl_reg(1 downto 0))) + 6 then
                        tx_bit_idx <= tx_bit_idx + 1;  -- parity bit done
                    elsif tx_bit_idx = to_integer(unsigned(ctrl_reg(1 downto 0))) + 6 +
                                       parity_offset + stop_bits then
                        -- All stop bits sent: transmission complete
                        tx_busy <= '0'; tx_empty <= '1';
                        int_st_reg(2) <= '1';  -- TX done interrupt flag
                    else
                        tx_bit_idx <= tx_bit_idx + 1;  -- stop bit(s)
                    end if;
                else
                    tx_baud_cnt <= tx_baud_cnt + 1;
                end if;
            end if;

            -- ---- UART RX state machine ----
            -- Detect start bit (falling edge on rxd), sample data at baud rate
            if rx_busy = '0' then
                -- Start bit detection: rxd goes low
                if rxd_prev = '1' and rxd = '0' and ctrl_reg(6) = '1' then
                    rx_busy <= '1';
                    rx_bit_idx <= 0;
                    rx_baud_cnt <= 0;
                    rx_parity_calc <= '0';
                    rx_shift <= (others => '0');
                end if;
            else
                -- Receiving: sample at baud intervals
                if rx_baud_cnt >= to_integer(baud_divisor) then
                    rx_baud_cnt <= 0;
                    if rx_bit_idx = 0 then
                        -- Verify start bit is still low
                        if rxd = '0' then
                            rx_bit_idx <= rx_bit_idx + 1;
                        else
                            rx_busy <= '0';  -- false start, abort
                        end if;
                    elsif rx_bit_idx <= to_integer(unsigned(ctrl_reg(1 downto 0))) + 5 then
                        -- Data bits: shift in from rxd (LSB first)
                        rx_shift <= rxd & rx_shift(7 downto 1);
                        rx_parity_calc <= rx_parity_calc xor rxd;
                        rx_bit_idx <= rx_bit_idx + 1;
                    elsif ctrl_reg(4) = '1' and
                          rx_bit_idx = to_integer(unsigned(ctrl_reg(1 downto 0))) + 6 then
                        -- Parity bit: check against calculated
                        if ctrl_reg(3) = '1' then  -- even parity
                            if rxd /= rx_parity_calc then parity_err <= '1'; int_st_reg(0)<='1'; end if;
                        else  -- odd parity
                            if rxd = rx_parity_calc then parity_err <= '1'; int_st_reg(0)<='1'; end if;
                        end if;
                        rx_bit_idx <= rx_bit_idx + 1;
                    elsif rx_bit_idx = to_integer(unsigned(ctrl_reg(1 downto 0))) + 6 +
                                       parity_offset then
                        -- Stop bit: should be high
                        if rxd = '1' then
                            -- Valid frame: latch data
                            if rx_ready = '1' then
                                rx_overrun <= '1';  -- previous data not read
                                int_st_reg(0) <= '1';
                            end if;
                            rx_data <= rx_shift;
                            rx_ready <= '1';
                            int_st_reg(1) <= '1';  -- RX ready interrupt
                        else
                            framing_err <= '1';  -- stop bit not high
                            int_st_reg(0) <= '1';
                        end if;
                        rx_busy <= '0';
                    else
                        -- Second stop bit (if configured) -- just advance
                        rx_bit_idx <= rx_bit_idx + 1;
                    end if;
                else
                    rx_baud_cnt <= rx_baud_cnt + 1;
                end if;
            end if;
            rxd_prev <= rxd;
        end if;
    end process;

    -- ==================================================================
    -- PROCESS: register_read -- combinational read mux
    -- ==================================================================
    process(cs, addr, tx_data, rx_data, ctrl_reg, baud_l_reg, baud_h_reg,
            int_en_reg, int_st_reg, tx_busy, rx_ready, tx_empty, rx_overrun,
            framing_err, parity_err, cts_n)
        -- Assemble status register from individual flags
        variable status_val : std_logic_vector(7 downto 0);
    begin
        -- Build status register: [overrun, framing, parity, tx_busy,
        --   rx_ready, tx_empty, rx_full(=rx_ready), cts_state]
        status_val := rx_overrun & framing_err & parity_err & tx_busy &
                      rx_ready & tx_empty & rx_ready & (not cts_n);
        if cs = '1' then
            case addr is
                when R_TXDATA   => dout <= tx_data;       -- echo last TX byte
                when R_RXDATA   => dout <= rx_data;       -- received data
                when R_STATUS   => dout <= status_val;    -- assembled status
                when R_CTRL     => dout <= ctrl_reg;
                when R_BAUD_L   => dout <= baud_l_reg;
                when R_BAUD_H   => dout <= baud_h_reg;
                when R_FIFO_CTRL=> dout <= (others => '0'); -- write-only
                when R_INT_EN   => dout <= int_en_reg;
                when R_INT_ST   => dout <= int_st_reg;
                when others     => dout <= (others => '0');
            end case;
        else
            dout <= (others => '0');
        end if;
    end process;

    -- ==================================================================
    -- OUTPUT ASSIGNMENTS
    -- ==================================================================

    -- TXD line: start bit(0), data bits, parity, stop bit(s), idle high
    -- tx_bit_idx: 0=start, 1..N=data, N+1=parity, then stop
    txd <= '0' when (tx_busy='1' and tx_bit_idx=0)
      -- Data bits: output tx_shift(bit_idx-1) for LSB-first
      else tx_shift(tx_bit_idx - 1)
           when (tx_busy='1' and tx_bit_idx>=1 and
                 tx_bit_idx <= to_integer(unsigned(ctrl_reg(1 downto 0))) + 5)
      -- Parity bit
      else tx_parity_calc
           when (tx_busy='1' and ctrl_reg(4)='1' and
                 tx_bit_idx = to_integer(unsigned(ctrl_reg(1 downto 0))) + 6)
      -- Stop bit(s) and idle: high
      else '1';

    -- RTS: active-low, assert (low) when RX is enabled and not overrun
    rts_n <= '0' when (ctrl_reg(5)='1' and rx_overrun='0') else '1';

    -- Interrupt outputs (flag AND enable)
    tx_int  <= int_st_reg(2) and int_en_reg(2);
    rx_int  <= int_st_reg(1) and int_en_reg(1);
    err_int <= int_st_reg(0) and int_en_reg(0);

end architecture rtl;
