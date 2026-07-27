-- ================================================================================
-- msp_testbench : Testbench for msp_interface (MSP430-style 16-bit peripheral bus)
-- VHDL-93 compliant.  10 ns clock, active-high reset.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity msp_tb is
end entity msp_tb;

architecture sim of msp_tb is

    component msp_interface is
        port (
            clk, reset  : in  std_logic;
            addr        : in  std_logic_vector(8 downto 0);
            din         : in  std_logic_vector(15 downto 0);
            dout        : out std_logic_vector(15 downto 0);
            we, re      : in  std_logic;
            p1out       : out std_logic_vector(7 downto 0);
            p1dir       : out std_logic_vector(7 downto 0);
            p1ren       : out std_logic_vector(7 downto 0);
            p1sel       : out std_logic_vector(7 downto 0);
            p1in        : in  std_logic_vector(7 downto 0);
            p1int       : out std_logic;
            p2out       : out std_logic_vector(7 downto 0);
            p2dir       : out std_logic_vector(7 downto 0);
            p2ren       : out std_logic_vector(7 downto 0);
            p2sel       : out std_logic_vector(7 downto 0);
            p2in        : in  std_logic_vector(7 downto 0);
            p2int       : out std_logic;
            ta_out      : out std_logic;
            ta_int      : out std_logic;
            adc_in      : in  std_logic_vector(11 downto 0);
            adc_int     : out std_logic;
            wdt_int     : out std_logic;
            lpm_out     : out std_logic_vector(2 downto 0)
        );
    end component;

    -- Clock and reset
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '1';
    signal test_done : boolean := false;

    -- Bus signals
    signal addr : std_logic_vector(8 downto 0) := (others => '0');
    signal din  : std_logic_vector(15 downto 0) := (others => '0');
    signal dout : std_logic_vector(15 downto 0);
    signal we   : std_logic := '0';
    signal re   : std_logic := '0';

    -- Port 1
    signal p1out : std_logic_vector(7 downto 0);
    signal p1dir : std_logic_vector(7 downto 0);
    signal p1ren : std_logic_vector(7 downto 0);
    signal p1sel : std_logic_vector(7 downto 0);
    signal p1in  : std_logic_vector(7 downto 0) := (others => '0');
    signal p1int : std_logic;

    -- Port 2
    signal p2out : std_logic_vector(7 downto 0);
    signal p2dir : std_logic_vector(7 downto 0);
    signal p2ren : std_logic_vector(7 downto 0);
    signal p2sel : std_logic_vector(7 downto 0);
    signal p2in  : std_logic_vector(7 downto 0) := (others => '0');
    signal p2int : std_logic;

    -- Timer_A
    signal ta_out : std_logic;
    signal ta_int : std_logic;

    -- ADC12
    signal adc_in  : std_logic_vector(11 downto 0) := (others => '0');
    signal adc_int : std_logic;

    -- Watchdog
    signal wdt_int : std_logic;

    -- LPM
    signal lpm_out : std_logic_vector(2 downto 0);

    -- Register address constants (9-bit)
    constant A_P1IN   : std_logic_vector(8 downto 0) := "000100000"; -- 0x020
    constant A_P1OUT  : std_logic_vector(8 downto 0) := "000100001"; -- 0x021
    constant A_P1DIR  : std_logic_vector(8 downto 0) := "000100010"; -- 0x022
    constant A_P1IFG  : std_logic_vector(8 downto 0) := "000100011"; -- 0x023
    constant A_P1IES  : std_logic_vector(8 downto 0) := "000100100"; -- 0x024
    constant A_P1IE   : std_logic_vector(8 downto 0) := "000100101"; -- 0x025
    constant A_P1SEL  : std_logic_vector(8 downto 0) := "000100110"; -- 0x026
    constant A_P1REN  : std_logic_vector(8 downto 0) := "000100111"; -- 0x027
    constant A_P2IN   : std_logic_vector(8 downto 0) := "000101000"; -- 0x028
    constant A_P2OUT  : std_logic_vector(8 downto 0) := "000101001"; -- 0x029
    constant A_P2DIR  : std_logic_vector(8 downto 0) := "000101010"; -- 0x02A
    constant A_P2IFG  : std_logic_vector(8 downto 0) := "000101011"; -- 0x02B
    constant A_P2IES  : std_logic_vector(8 downto 0) := "000101100"; -- 0x02C
    constant A_P2IE   : std_logic_vector(8 downto 0) := "000101101"; -- 0x02D
    constant A_TACTL  : std_logic_vector(8 downto 0) := "000110000"; -- 0x060
    constant A_TAR    : std_logic_vector(8 downto 0) := "000110010"; -- 0x062
    constant A_TACCR0 : std_logic_vector(8 downto 0) := "000110100"; -- 0x064
    constant A_TACCR1 : std_logic_vector(8 downto 0) := "000110110"; -- 0x066
    constant A_ADC12CTL0: std_logic_vector(8 downto 0) := "001000000"; -- 0x080
    constant A_ADC12CTL1: std_logic_vector(8 downto 0) := "001000010"; -- 0x082
    constant A_ADC12MEM0: std_logic_vector(8 downto 0) := "001010000"; -- 0x090
    constant A_ADC12IFG: std_logic_vector(8 downto 0) := "001010010"; -- 0x092
    constant A_WDTCTL : std_logic_vector(8 downto 0) := "010010000"; -- 0x120
    constant A_SR     : std_logic_vector(8 downto 0) := "000000010"; -- 0x002

begin

    -- ==================================================================
    -- DUT instantiation
    -- ==================================================================
    dut : msp_interface
        port map (
            clk => clk, reset => reset,
            addr => addr, din => din, dout => dout,
            we => we, re => re,
            p1out => p1out, p1dir => p1dir, p1ren => p1ren, p1sel => p1sel,
            p1in => p1in, p1int => p1int,
            p2out => p2out, p2dir => p2dir, p2ren => p2ren, p2sel => p2sel,
            p2in => p2in, p2int => p2int,
            ta_out => ta_out, ta_int => ta_int,
            adc_in => adc_in, adc_int => adc_int,
            wdt_int => wdt_int,
            lpm_out => lpm_out
        );

    -- ==================================================================
    -- Clock generation: 10 ns period
    -- ==================================================================
    clk_proc : process
    begin
        while not test_done loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
        wait;
    end process;

    -- ==================================================================
    -- Stimulus process
    -- ==================================================================
    stim_proc : process
        -- Register write helper (synchronous, one clock)
        procedure reg_write(a : in std_logic_vector(8 downto 0);
                            d : in std_logic_vector(15 downto 0)) is
        begin
            wait until rising_edge(clk);
            we   <= '1';
            addr <= a;
            din  <= d;
            wait until rising_edge(clk);
            we   <= '0';
            addr <= (others => '0');
            din  <= (others => '0');
        end procedure;

        -- Register read helper (combinational, sample mid-cycle)
        procedure reg_read(a : in std_logic_vector(8 downto 0);
                           d : out std_logic_vector(15 downto 0)) is
        begin
            re   <= '1';
            addr <= a;
            wait for 2 ns;
            d := dout;
            re   <= '0';
            addr <= (others => '0');
            wait for 2 ns;
        end procedure;

        variable rdata : std_logic_vector(15 downto 0);
    begin
        -- ----------------------------------------------------------------
        -- Reset (active-high)
        -- ----------------------------------------------------------------
        reset <= '1';
        wait for 20 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        -- ----------------------------------------------------------------
        -- Register WRITE transactions (at least 3)
        -- ----------------------------------------------------------------

        -- Write 1: P1DIR = 0xFF (all outputs)
        reg_write(A_P1DIR, x"00FF");
        assert p1dir = x"FF"
            report "MSP TB: P1DIR output mismatch after write 1"
            severity error;

        -- Write 2: P1OUT = 0xA5
        reg_write(A_P1OUT, x"00A5");
        assert p1out = x"A5"
            report "MSP TB: P1OUT output mismatch after write 2"
            severity error;

        -- Write 3: P2DIR = 0x0F, P2OUT = 0xF0
        reg_write(A_P2DIR, x"000F");
        assert p2dir = x"0F"
            report "MSP TB: P2DIR output mismatch after write 3"
            severity error;

        reg_write(A_P2OUT, x"00F0");
        assert p2out = x"F0"
            report "MSP TB: P2OUT output mismatch after write 3b"
            severity error;

        -- Write 4: P1REN = 0xAA (pull resistors)
        reg_write(A_P1REN, x"00AA");
        assert p1ren = x"AA"
            report "MSP TB: P1REN output mismatch after write 4"
            severity error;

        -- Write 5: SR with GIE (bit 3) set
        reg_write(A_SR, x"0008");

        -- ----------------------------------------------------------------
        -- Register READ transactions (at least 3) and check data
        -- ----------------------------------------------------------------

        -- Read 1: P1DIR should be 0x00FF
        reg_read(A_P1DIR, rdata);
        assert rdata = x"00FF"
            report "MSP TB: Read P1DIR expected 0x00FF"
            severity error;

        -- Read 2: P1OUT should be 0x00A5
        reg_read(A_P1OUT, rdata);
        assert rdata = x"00A5"
            report "MSP TB: Read P1OUT expected 0x00A5"
            severity error;

        -- Read 3: P2DIR should be 0x000F
        reg_read(A_P2DIR, rdata);
        assert rdata = x"000F"
            report "MSP TB: Read P2DIR expected 0x000F"
            severity error;

        -- Read 4: P1REN should be 0x00AA
        reg_read(A_P1REN, rdata);
        assert rdata = x"00AA"
            report "MSP TB: Read P1REN expected 0x00AA"
            severity error;

        -- ----------------------------------------------------------------
        -- GPIO input stimulation and output checking
        -- ----------------------------------------------------------------
        -- Drive p1in and read P1IN
        p1in <= x"3C";
        wait for 10 ns;
        reg_read(A_P1IN, rdata);
        assert rdata = x"003C"
            report "MSP TB: Read P1IN expected 0x003C"
            severity error;

        -- Change p1in and re-read
        p1in <= x"81";
        wait for 10 ns;
        reg_read(A_P1IN, rdata);
        assert rdata = x"0081"
            report "MSP TB: Read P1IN expected 0x0081"
            severity error;

        -- Check GPIO outputs reflect written values
        assert p1out = x"A5"
            report "MSP TB: p1out not 0xA5"
            severity error;
        assert p2out = x"F0"
            report "MSP TB: p2out not 0xF0"
            severity error;

        -- ----------------------------------------------------------------
        -- Interrupt input stimulation and output checking
        -- ----------------------------------------------------------------
        -- Configure P1 interrupt: P1IES=0 (rising edge), P1IE=0x01 (bit0)
        reg_write(A_P1IES, x"0000");
        reg_write(A_P1IE, x"0001");

        -- Stimulate p1in bit0 with rising edge
        p1in <= x"00";
        wait for 20 ns;
        wait until rising_edge(clk);
        p1in <= x"01";
        wait for 20 ns;
        wait until rising_edge(clk);

        -- Check P1IFG was set
        reg_read(A_P1IFG, rdata);
        assert rdata(0) = '1'
            report "MSP TB: P1IFG bit0 not set after rising edge"
            severity error;

        -- Check p1int output (P1IFG AND P1IE AND GIE)
        assert p1int = '1'
            report "MSP TB: p1int not asserted after interrupt"
            severity error;

        -- Clear P1IFG by writing 1 to bit0
        reg_write(A_P1IFG, x"0001");
        reg_read(A_P1IFG, rdata);
        assert rdata(0) = '0'
            report "MSP TB: P1IFG bit0 not cleared after write"
            severity error;

        -- ----------------------------------------------------------------
        -- Timer_A interrupt test: configure up mode, small TACCR0
        -- ----------------------------------------------------------------
        reg_write(A_TACCR0, x"0005");
        reg_write(A_TACTL, x"0010");  -- MC0=1 (up mode)
        -- Wait for timer to count to TACCR0 and set interrupt
        wait for 200 ns;
        assert ta_int = '1'
            report "MSP TB: ta_int not asserted after timer overflow"
            severity error;

        -- ----------------------------------------------------------------
        -- Done
        -- ----------------------------------------------------------------
        wait for 50 ns;
        test_done <= true;
        assert false report "Testbench complete" severity failure;
        wait;
    end process;

end architecture sim;
