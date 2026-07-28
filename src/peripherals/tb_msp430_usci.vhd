--------------------------------------------------------------------------------
-- tb_msp430_usci : Testbench for MSP430 USCI UART config via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_msp430_usci is
end entity tb_msp430_usci;

architecture sim of tb_msp430_usci is
    constant CLK_PERIOD : time := 20 ns;

    signal HCLK      : std_logic := '0';
    signal HRESETn   : std_logic := '0';
    signal HSEL      : std_logic := '0';
    signal HWRITE    : std_logic := '0';
    signal HREADY    : std_logic := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "000";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;
    signal uca_tx    : std_logic;
    signal uca_rx    : std_logic := '1';
    signal ucb_scl   : std_logic;
    signal ucb_sda   : std_logic;
    signal ucb_somi  : std_logic := '0';
    signal ucb_simo  : std_logic;
    signal ucb_clk   : std_logic;
    signal usci_irq  : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.msp430_usci
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            uca_tx => uca_tx, uca_rx => uca_rx,
            ucb_scl => ucb_scl, ucb_sda => ucb_sda,
            ucb_somi => ucb_somi, ucb_simo => ucb_simo,
            ucb_clk => ucb_clk, usci_irq => usci_irq
        );

    stim : process
        procedure ahb_write(addr : in std_logic_vector(31 downto 0);
                            data : in std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
            HADDR <= addr; HWDATA <= data;
            wait for CLK_PERIOD;
            HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
            wait for CLK_PERIOD;
        end procedure;

        procedure ahb_read(addr : in std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
            HADDR <= addr;
            wait for CLK_PERIOD;
            HSEL <= '0'; HTRANS <= "00";
            wait for CLK_PERIOD;
        end procedure;
    begin
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait for CLK_PERIOD * 2;

        -- Configure UCA CTL0 (0x00): UART mode, 8N1
        -- UCMSB=0, UC7BIT=0, UCPEN=0, UCPAR=0
        ahb_write(x"00000000", x"00000000");

        -- Configure UCA CTL1 (0x04): UCSWRST=1 (reset), SMCLK
        -- bit0=UCSWRST, bit6:5=UCSSEL=10 (SMCLK)
        ahb_write(x"00000004", x"00000061");

        -- Set baud rate: UCA_BR0=0x08 (0x08), UCA_BR1=0x00 (0x0C)
        ahb_write(x"00000008", x"00000008");
        ahb_write(x"0000000C", x"00000000");

        -- Read back baud rate registers
        ahb_read(x"00000008");
        assert HRDATA(7 downto 0) = x"08"
            report "FAIL: UCA_BR0 readback mismatch"
            severity error;
        assert HRDATA(7 downto 0) = x"08"
            report "PASS: UCA_BR0 readback verified"
            severity note;

        -- Read back CTL1
        ahb_read(x"00000004");
        assert HRDATA(0) = '1'
            report "FAIL: UCSWRST not set"
            severity error;
        assert HRDATA(0) = '1'
            report "PASS: UCSWRST set"
            severity note;

        -- Release from reset: UCSWRST=0, SMCLK
        ahb_write(x"00000004", x"00000060");

        -- Write to TXBUF (0x18) to start UART transmission
        ahb_write(x"00000018", x"00000041");  -- 'A'

        -- Wait for UART TX to complete
        wait for 5 us;

        -- Read UCA_STAT (0x10)
        ahb_read(x"00000010");

        report "MSP430 USCI testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;
