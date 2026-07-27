-- ================================================================================
-- esp32_spi : ESP32-style SPI Master interface model
-- Educational bus interface model -- not a full ESP32 CPU core.  Target: Cyclone III.
--
-- Models a configurable SPI master with 4 slave selects, CPOL/CPHA modes,
-- MSB/LSB bit order, clock divider, command/address phases, and DMA request.
--
-- REGISTER MAP (4-bit addr):
-- 0x0 CTRL   -- Control: bit7=SPE(enable), bit6=CPOL, bit5=CPHA, bit4=MSB(1)/LSB(0),
--              bit3=CMD_EN, bit2=ADDR_EN, bit1:0=SLAVE_SEL(0-3)
-- 0x1 STATUS -- Status: bit7=SPIF(done), bit6=BUSY, bit5=TX_EMPTY, bit4=RX_FULL,
--              bit3=WCOL, bit2=DMA_REQ
-- 0x2 CLKDIV -- Clock divider (prescaler for SCLK generation)
-- 0x3 TXDATA -- TX data register (write starts transfer if enabled)
-- 0x4 RXDATA -- RX data register (read returns received byte)
-- 0x5 CMD    -- Command byte (8-bit, sent before data if CMD_EN=1)
-- 0x6 ADDR_L -- Address low byte (sent if ADDR_EN=1)
-- 0x7 ADDR_H -- Address high byte
-- 0x8 SLAVE  -- Slave select mask (direct override, active-low)
-- 0x9 DMA_CTRL-- DMA control: bit0=DMA_EN
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity esp32_spi is
    port (
        clk, reset  : in  std_logic;
        -- Memory-mapped register interface
        cs, we      : in  std_logic;
        addr        : in  std_logic_vector(3 downto 0);  -- 4-bit register select
        din         : in  std_logic_vector(7 downto 0);
        dout        : out std_logic_vector(7 downto 0);
        -- SPI physical pins
        sclk        : out std_logic;
        mosi        : out std_logic;
        miso        : in  std_logic;
        spi_cs_n    : out std_logic_vector(3 downto 0);  -- 4 slave selects
        -- Interrupt
        spi_int     : out std_logic;  -- transfer complete interrupt
        -- DMA interface (simplified)
        dma_req     : out std_logic;
        dma_ack     : in  std_logic
    );
end entity esp32_spi;

architecture rtl of esp32_spi is
    -- Register address constants
    constant R_CTRL    : std_logic_vector(3 downto 0) := "0000"; -- 0x0
    constant R_STATUS  : std_logic_vector(3 downto 0) := "0001"; -- 0x1
    constant R_CLKDIV  : std_logic_vector(3 downto 0) := "0010"; -- 0x2
    constant R_TXDATA  : std_logic_vector(3 downto 0) := "0011"; -- 0x3
    constant R_RXDATA  : std_logic_vector(3 downto 0) := "0100"; -- 0x4
    constant R_CMD     : std_logic_vector(3 downto 0) := "0101"; -- 0x5
    constant R_ADDR_L  : std_logic_vector(3 downto 0) := "0110"; -- 0x6
    constant R_ADDR_H  : std_logic_vector(3 downto 0) := "0111"; -- 0x7
    constant R_SLAVE   : std_logic_vector(3 downto 0) := "1000"; -- 0x8
    constant R_DMA_CTRL: std_logic_vector(3 downto 0) := "1001"; -- 0x9

    -- Control register bits
    signal ctrl_reg   : std_logic_vector(7 downto 0) := (others => '0');
    -- Status register (read-only mostly; bits set/cleared by hardware)
    signal status_reg : std_logic_vector(7 downto 0) := "00100000"; -- TX_EMPTY=1
    -- Clock divider (prescaler value)
    signal clkdiv_reg : std_logic_vector(7 downto 0) := (others => '0');
    -- TX/RX data registers
    signal txdata_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal rxdata_reg : std_logic_vector(7 downto 0) := (others => '0');
    -- Command and address phase registers
    signal cmd_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal addr_l_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal addr_h_reg : std_logic_vector(7 downto 0) := (others => '0');
    -- Slave select override mask
    signal slave_reg  : std_logic_vector(7 downto 0) := (others => '1');
    -- DMA control
    signal dma_ctrl_reg : std_logic_vector(7 downto 0) := (others => '0');

    -- Transfer state machine signals
    signal spi_busy     : std_logic := '0';
    signal bit_cnt      : integer range 0 to 7 := 0;       -- bit position in current byte
    signal clk_div_cnt  : integer range 0 to 255 := 0;     -- prescaler counter
    signal sclk_internal: std_logic := '0';                 -- internal SCLK toggle
    -- Phase tracking: 0=cmd, 1=addr_l, 2=addr_h, 3=data
    signal phase        : integer range 0 to 3 := 0;
    -- Current shift register (holds byte being transmitted)
    signal shift_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_shift     : std_logic_vector(7 downto 0) := (others => '0');

begin

    -- ==================================================================
    -- PROCESS: register_write + SPI transfer state machine
    -- Handles CPU writes to registers and drives the SPI master FSM.
    -- ==================================================================
    process(clk, reset)
    begin
        if reset = '1' then
            -- Active-high reset: clear all registers
            ctrl_reg     <= (others => '0');
            status_reg   <= "00100000";  -- TX_EMPTY=1, all else 0
            clkdiv_reg   <= (others => '0');
            txdata_reg   <= (others => '0');
            rxdata_reg   <= (others => '0');
            cmd_reg      <= (others => '0');
            addr_l_reg   <= (others => '0');
            addr_h_reg   <= (others => '0');
            slave_reg    <= (others => '1');
            dma_ctrl_reg <= (others => '0');
            spi_busy     <= '0';
            bit_cnt      <= 0;
            clk_div_cnt  <= 0;
            sclk_internal<= '0';
            phase        <= 0;
            shift_reg    <= (others => '0');
            rx_shift     <= (others => '0');
        elsif rising_edge(clk) then
            -- ---- CPU register writes ----
            if cs = '1' and we = '1' then
                case addr is
                    when R_CTRL     => ctrl_reg     <= din;
                    when R_CLKDIV   => clkdiv_reg   <= din;
                    when R_CMD      => cmd_reg      <= din;
                    when R_ADDR_L   => addr_l_reg   <= din;
                    when R_ADDR_H   => addr_h_reg   <= din;
                    when R_SLAVE    => slave_reg    <= din;
                    when R_DMA_CTRL => dma_ctrl_reg <= din;
                    -- TXDATA write: start transfer if SPI enabled and not busy
                    when R_TXDATA   =>
                        if ctrl_reg(7) = '1' and spi_busy = '0' then
                            txdata_reg <= din;
                            spi_busy   <= '1';
                            status_reg(6) <= '1';  -- BUSY
                            status_reg(7) <= '0';  -- clear DONE
                            status_reg(5) <= '0';  -- clear TX_EMPTY
                            status_reg(4) <= '0';  -- clear RX_FULL
                            bit_cnt     <= 0;
                            clk_div_cnt <= 0;
                            sclk_internal <= '0';
                            -- Determine starting phase based on CMD_EN / ADDR_EN
                            if ctrl_reg(3) = '1' then
                                phase <= 0;  -- start with command phase
                                shift_reg <= cmd_reg;
                            elsif ctrl_reg(2) = '1' then
                                phase <= 1;  -- start with address phase
                                shift_reg <= addr_l_reg;
                            else
                                phase <= 3;  -- data only
                                shift_reg <= din;
                            end if;
                        end if;
                    -- STATUS: writing '1' to SPIF (bit7) clears it
                    when R_STATUS =>
                        if din(7) = '1' then status_reg(7) <= '0'; end if;
                    when others => null;
                end case;
            end if;

            -- ---- SPI master transfer state machine ----
            if spi_busy = '1' then
                -- Prescaler: generate SCLK edges at clkdiv_reg rate
                if clk_div_cnt >= to_integer(unsigned(clkdiv_reg)) then
                    clk_div_cnt <= 0;
                    sclk_internal <= not sclk_internal;  -- toggle SCLK
                    -- Sample MISO on rising edge, shift out MOSI on falling
                    if sclk_internal = '0' then  -- about to go high: sample
                        rx_shift <= rx_shift(6 downto 0) & miso;
                        if bit_cnt = 7 then
                            -- Byte complete: advance to next phase or finish
                            bit_cnt <= 0;
                            case phase is
                                when 0 =>  -- command done, go to addr or data
                                    if ctrl_reg(2) = '1' then
                                        phase <= 1; shift_reg <= addr_l_reg;
                                    else
                                        phase <= 3; shift_reg <= txdata_reg;
                                    end if;
                                when 1 =>  -- addr low done, go to addr high or data
                                    phase <= 2; shift_reg <= addr_h_reg;
                                when 2 =>  -- addr high done, go to data
                                    phase <= 3; shift_reg <= txdata_reg;
                                when 3 =>  -- data phase complete
                                    spi_busy <= '0';
                                    status_reg(6) <= '0';  -- clear BUSY
                                    status_reg(7) <= '1';  -- set DONE/SPIF
                                    status_reg(5) <= '1';  -- set TX_EMPTY
                                    status_reg(4) <= '1';  -- set RX_FULL
                                    rxdata_reg <= rx_shift(6 downto 0) & miso;
                                when others => null;
                            end case;
                        else
                            bit_cnt <= bit_cnt + 1;
                        end if;
                    end if;
                else
                    clk_div_cnt <= clk_div_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- ==================================================================
    -- PROCESS: register_read -- combinational read mux
    -- ==================================================================
    process(cs, addr, ctrl_reg, status_reg, clkdiv_reg, txdata_reg, rxdata_reg,
            cmd_reg, addr_l_reg, addr_h_reg, slave_reg, dma_ctrl_reg)
    begin
        if cs = '1' then
            case addr is
                when R_CTRL     => dout <= ctrl_reg;
                when R_STATUS   => dout <= status_reg;
                when R_CLKDIV   => dout <= clkdiv_reg;
                when R_TXDATA   => dout <= txdata_reg;
                when R_RXDATA   => dout <= rxdata_reg;  -- read received data
                when R_CMD      => dout <= cmd_reg;
                when R_ADDR_L   => dout <= addr_l_reg;
                when R_ADDR_H   => dout <= addr_h_reg;
                when R_SLAVE    => dout <= slave_reg;
                when R_DMA_CTRL => dout <= dma_ctrl_reg;
                when others     => dout <= (others => '0');
            end case;
        else
            dout <= (others => '0');
        end if;
    end process;

    -- ==================================================================
    -- OUTPUT ASSIGNMENTS
    -- ==================================================================

    -- SCLK: output internal clock during transfer, idle based on CPOL
    sclk <= sclk_internal when spi_busy = '1' else ctrl_reg(6);

    -- MOSI: shift MSB or LSB first depending on ctrl_reg(4)
    -- MSB first (bit4=1): send bit (7 - bit_cnt); LSB first (bit4=0): send bit_cnt
    mosi <= shift_reg(7 - bit_cnt) when (spi_busy='1' and ctrl_reg(4)='1')
      else shift_reg(bit_cnt)       when (spi_busy='1' and ctrl_reg(4)='0')
      else '0';

    -- Slave select: use ctrl_reg(1:0) to select one of 4 slaves (active-low)
    -- Or use slave_reg override if non-default
    spi_cs_n(0) <= '0' when (spi_busy='1' and ctrl_reg(1 downto 0)="00") else '1';
    spi_cs_n(1) <= '0' when (spi_busy='1' and ctrl_reg(1 downto 0)="01") else '1';
    spi_cs_n(2) <= '0' when (spi_busy='1' and ctrl_reg(1 downto 0)="10") else '1';
    spi_cs_n(3) <= '0' when (spi_busy='1' and ctrl_reg(1 downto 0)="11") else '1';

    -- Transfer complete interrupt (when DONE flag set)
    spi_int <= status_reg(7);

    -- DMA request: assert when TX_EMPTY and DMA enabled, deassert on ack
    dma_req <= status_reg(5) when dma_ctrl_reg(0) = '1' else '0';

end architecture rtl;
