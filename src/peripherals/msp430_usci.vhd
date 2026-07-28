-- ================================================================================
-- msp430_usci : MSP430 USCI (Universal Serial Communication Interface)
-- ================================================================================
-- Combined SPI/I2C (UCB) and UART (UCA) with AHB-Lite slave interface.
-- Registers: UCAxCTL0/1, UCAxBR0/1, UCAxSTAT, UCAxRXBUF, UCAxTXBUF,
--            UCBxCTL0/1, UCBxBR0/1, UCBxSTAT, UCBxRXBUF, UCBxTXBUF.
--
-- Register Map (HADDR[6:2]):
--   0x00: UCAxCTL0  0x04: UCAxCTL1  0x08: UCAxBR0   0x0C: UCAxBR1
--   0x10: UCAxSTAT  0x14: UCAxRXBUF 0x18: UCAxTXBUF
--   0x1C: UCBxCTL0  0x20: UCBxCTL1  0x24: UCBxBR0   0x28: UCBxBR1
--   0x2C: UCBxSTAT  0x30: UCBxRXBUF 0x34: UCBxTXBUF
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity msp430_usci is
    port (
        -- AHB-Lite slave interface
        HCLK      : in  std_logic;  HRESETn   : in  std_logic;
        HSEL      : in  std_logic;  HWRITE    : in  std_logic;
        HREADY    : in  std_logic;  HTRANS    : in  std_logic_vector(1 downto 0);
        HSIZE     : in  std_logic_vector(2 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;  HREADYOUT : out std_logic;
        -- UART pins (UCA)
        uca_tx   : out std_logic;   uca_rx   : in  std_logic;
        -- I2C/SPI pins (UCB)
        ucb_scl  : out std_logic;   ucb_sda  : inout std_logic;
        ucb_somi : in  std_logic;   ucb_simo : out std_logic;
        ucb_clk  : out std_logic;   usci_irq : out std_logic
    );
end entity msp430_usci;

architecture rtl of msp430_usci is
    constant REG_UCA_CTL0  : std_logic_vector(4 downto 0) := "00000";
    constant REG_UCA_CTL1  : std_logic_vector(4 downto 0) := "00001";
    constant REG_UCA_BR0   : std_logic_vector(4 downto 0) := "00010";
    constant REG_UCA_BR1   : std_logic_vector(4 downto 0) := "00011";
    constant REG_UCA_STAT  : std_logic_vector(4 downto 0) := "00100";
    constant REG_UCA_RXBUF : std_logic_vector(4 downto 0) := "00101";
    constant REG_UCA_TXBUF : std_logic_vector(4 downto 0) := "00110";
    constant REG_UCB_CTL0  : std_logic_vector(4 downto 0) := "00111";
    constant REG_UCB_CTL1  : std_logic_vector(4 downto 0) := "01000";
    constant REG_UCB_BR0   : std_logic_vector(4 downto 0) := "01001";
    constant REG_UCB_BR1   : std_logic_vector(4 downto 0) := "01010";
    constant REG_UCB_STAT  : std_logic_vector(4 downto 0) := "01011";
    constant REG_UCB_RXBUF : std_logic_vector(4 downto 0) := "01100";
    constant REG_UCB_TXBUF : std_logic_vector(4 downto 0) := "01101";

    signal uca_ctl0, uca_ctl1, uca_br0, uca_br1 : std_logic_vector(7 downto 0) := (others => '0');
    signal uca_stat, uca_rxbuf : std_logic_vector(7 downto 0) := (others => '0');
    signal ucb_ctl0, ucb_ctl1, ucb_br0, ucb_br1 : std_logic_vector(7 downto 0) := (others => '0');
    signal ucb_stat, ucb_rxbuf : std_logic_vector(7 downto 0) := (others => '0');

    type uart_tx_state_t is (IDLE, START, DATA, STOP);
    signal uart_tx_state : uart_tx_state_t := IDLE;
    signal uart_tx_cnt   : integer range 0 to 7 := 0;
    signal uart_tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_baud_cnt : unsigned(15 downto 0) := (others => '0');
    signal uart_baud_tick: std_logic := '0';

    signal ucb_shift     : std_logic_vector(7 downto 0) := (others => '0');
    signal ucb_bit_cnt   : integer range 0 to 7 := 0;
    signal ucb_clk_out   : std_logic := '0';
    signal ucb_simo_out  : std_logic := '0';
    signal uca_rx_irq    : std_logic := '0';
    signal ucb_rx_irq    : std_logic := '0';

    signal reg_sel  : std_logic_vector(4 downto 0);
    signal write_en : std_logic;
begin
    reg_sel  <= HADDR(6 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    HREADYOUT <= '1';  HRESP <= '0';

    -- UART baud rate generator
    baud_proc : process(HCLK)
        variable baud_div : unsigned(15 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                uart_baud_cnt <= (others => '0');  uart_baud_tick <= '0';
            else
                baud_div := unsigned(uca_br1) & unsigned(uca_br0);
                if baud_div = 0 then baud_div := to_unsigned(1, 16); end if;
                if uart_baud_cnt = baud_div - 1 then
                    uart_baud_cnt <= (others => '0');  uart_baud_tick <= '1';
                else
                    uart_baud_cnt <= uart_baud_cnt + 1;  uart_baud_tick <= '0';
                end if;
            end if;
        end if;
    end process baud_proc;

    -- UART TX + RX + UCB shift + register writes (combined)
    main_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                uart_tx_state <= IDLE;  uart_tx_cnt <= 0;
                uca_ctl0 <= (others => '0'); uca_ctl1 <= (others => '0');
                uca_br0  <= (others => '0'); uca_br1  <= (others => '0');
                ucb_ctl0 <= (others => '0'); ucb_ctl1 <= (others => '0');
                ucb_br0  <= (others => '0'); ucb_br1  <= (others => '0');
                uca_stat <= (others => '0'); ucb_stat <= (others => '0');
                uca_rxbuf <= (others => '0'); ucb_rxbuf <= (others => '0');
                uca_rx_irq <= '0';  ucb_rx_irq <= '0';
                ucb_shift <= (others => '0');  ucb_bit_cnt <= 0;
                ucb_clk_out <= '0';  ucb_simo_out <= '0';
            else
                -- Register writes
                if write_en = '1' then
                    case reg_sel is
                        when REG_UCA_CTL0 => uca_ctl0 <= HWDATA(7 downto 0);
                        when REG_UCA_CTL1 => uca_ctl1 <= HWDATA(7 downto 0);
                        when REG_UCA_BR0  => uca_br0  <= HWDATA(7 downto 0);
                        when REG_UCA_BR1  => uca_br1  <= HWDATA(7 downto 0);
                        when REG_UCA_TXBUF =>
                            uart_tx_data <= HWDATA(7 downto 0);
                            if uart_tx_state = IDLE then uart_tx_state <= START; uca_stat(1) <= '1'; end if;
                        when REG_UCB_CTL0 => ucb_ctl0 <= HWDATA(7 downto 0);
                        when REG_UCB_CTL1 =>
                            ucb_ctl1 <= HWDATA(7 downto 0);
                            if HWDATA(0) = '1' then ucb_rx_irq <= '0'; end if;
                        when REG_UCB_BR0  => ucb_br0  <= HWDATA(7 downto 0);
                        when REG_UCB_BR1  => ucb_br1  <= HWDATA(7 downto 0);
                        when REG_UCB_TXBUF =>
                            ucb_shift <= HWDATA(7 downto 0);  ucb_bit_cnt <= 0;
                            ucb_stat(1) <= '1';
                        when others => null;
                    end case;
                    -- Clear UCA RX IRQ on CTL1 write
                    if reg_sel = REG_UCA_CTL1 and HWDATA(0) = '1' then
                        uca_rx_irq <= '0';  uca_stat(0) <= '0';
                    end if;
                end if;

                -- UART TX state machine
                case uart_tx_state is
                    when IDLE => null;
                    when START =>
                        if uart_baud_tick = '1' then
                            uart_tx_state <= DATA;  uart_tx_cnt <= 0;
                        end if;
                    when DATA =>
                        if uart_baud_tick = '1' then
                            if uart_tx_cnt = 7 then uart_tx_state <= STOP;
                            else uart_tx_cnt <= uart_tx_cnt + 1; end if;
                        end if;
                    when STOP =>
                        if uart_baud_tick = '1' then
                            uart_tx_state <= IDLE;  uca_stat(1) <= '0';
                        end if;
                end case;

                -- UART RX (simplified: detect start bit)
                if uca_rx = '0' and uca_stat(0) = '0' then
                    uca_rx_irq <= '1';  uca_stat(0) <= '1';
                end if;

                -- UCB SPI/I2C shift
                if uart_baud_tick = '1' and ucb_stat(1) = '1' then
                    ucb_simo_out <= ucb_shift(7);
                    ucb_shift <= ucb_shift(6 downto 0) & ucb_somi;
                    ucb_clk_out <= not ucb_clk_out;
                    if ucb_bit_cnt = 7 then
                        ucb_bit_cnt <= 0;  ucb_rxbuf <= ucb_shift(6 downto 0) & ucb_somi;
                        ucb_stat(1) <= '0';  ucb_rx_irq <= '1';
                    else
                        ucb_bit_cnt <= ucb_bit_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process main_proc;

    -- UART TX output mux
    uca_tx <= '1' when uart_tx_state = IDLE or uart_tx_state = STOP else
              '0' when uart_tx_state = START else
              uart_tx_data(uart_tx_cnt);

    -- Register read mux
    reg_read : process(reg_sel, uca_ctl0, uca_ctl1, uca_br0, uca_br1, uca_stat,
                       uca_rxbuf, ucb_ctl0, ucb_ctl1, ucb_br0, ucb_br1, ucb_stat, ucb_rxbuf)
    begin
        case reg_sel is
            when REG_UCA_CTL0  => HRDATA <= x"000000" & uca_ctl0;
            when REG_UCA_CTL1  => HRDATA <= x"000000" & uca_ctl1;
            when REG_UCA_BR0   => HRDATA <= x"000000" & uca_br0;
            when REG_UCA_BR1   => HRDATA <= x"000000" & uca_br1;
            when REG_UCA_STAT  => HRDATA <= x"000000" & uca_stat;
            when REG_UCA_RXBUF => HRDATA <= x"000000" & uca_rxbuf;
            when REG_UCA_TXBUF => HRDATA <= (others => '0');
            when REG_UCB_CTL0  => HRDATA <= x"000000" & ucb_ctl0;
            when REG_UCB_CTL1  => HRDATA <= x"000000" & ucb_ctl1;
            when REG_UCB_BR0   => HRDATA <= x"000000" & ucb_br0;
            when REG_UCB_BR1   => HRDATA <= x"000000" & ucb_br1;
            when REG_UCB_STAT  => HRDATA <= x"000000" & ucb_stat;
            when REG_UCB_RXBUF => HRDATA <= x"000000" & ucb_rxbuf;
            when REG_UCB_TXBUF => HRDATA <= (others => '0');
            when others        => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    ucb_clk  <= ucb_clk_out;
    ucb_simo <= ucb_simo_out;
    ucb_scl  <= ucb_clk_out when ucb_ctl0(3) = '0' else '1';
    ucb_sda  <= 'Z';
    usci_irq <= uca_rx_irq or ucb_rx_irq;

end architecture rtl;
