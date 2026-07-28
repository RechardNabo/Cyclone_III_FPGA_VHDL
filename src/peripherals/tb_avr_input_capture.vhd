--------------------------------------------------------------------------------
-- tb_avr_input_capture : Testbench for AVR Input Capture via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_avr_input_capture is
end entity tb_avr_input_capture;

architecture sim of tb_avr_input_capture is
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
    signal icp_pin   : std_logic := '0';
    signal ic_irq    : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.avr_input_capture
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            icp_pin => icp_pin, ic_irq => ic_irq
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

        -- Enable capture, rising edge, IRQ enable
        -- ICR_CTRL (0x00): bit0=capture_en, bit2=irq_en
        ahb_write(x"00000000", x"00000005");

        -- ICR_EDGE (0x0C): 0 = rising edge
        ahb_write(x"0000000C", x"00000000");

        -- Let timer run for some cycles
        wait for CLK_PERIOD * 20;

        -- Generate rising edge on icp_pin
        icp_pin <= '1';
        wait for CLK_PERIOD * 4;

        -- Read ICR_STAT (0x04): bit0 = capture_flag
        ahb_read(x"00000004");
        assert HRDATA(0) = '1'
            report "FAIL: Capture flag not set after rising edge"
            severity error;
        assert HRDATA(0) = '1'
            report "PASS: Capture flag set on rising edge"
            severity note;

        -- Read ICR_VALUE (0x08): captured timer value
        ahb_read(x"00000008");
        assert HRDATA(15 downto 0) /= x"0000"
            report "FAIL: Captured value is zero"
            severity error;
        assert HRDATA(15 downto 0) /= x"0000"
            report "PASS: Captured nonzero timer value"
            severity note;

        -- Clear capture flag by writing 1 to STAT bit0
        ahb_write(x"00000004", x"00000001");
        ahb_read(x"00000004");
        assert HRDATA(0) = '0'
            report "PASS: Capture flag cleared"
            severity note;

        report "AVR Input Capture testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;
