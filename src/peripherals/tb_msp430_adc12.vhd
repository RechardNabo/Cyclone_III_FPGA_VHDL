--------------------------------------------------------------------------------
-- tb_msp430_adc12 : Testbench for MSP430 ADC12 config via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_msp430_adc12 is
end entity tb_msp430_adc12;

architecture sim of tb_msp430_adc12 is
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
    signal adc12_in  : std_logic_vector(7 downto 0) := (others => '1');
    signal adc12_irq : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.msp430_adc12
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            adc12_in => adc12_in, adc12_irq => adc12_irq
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

        -- Configure ADC12CTL0 (0x00): ENC=1 (bit0), SHT=4 (bits11:8=0100)
        -- bit0=ENC, bits11:8=0100 => 0x0401
        ahb_write(x"00000000", x"00000401");

        -- Read back ADC12CTL0
        ahb_read(x"00000000");
        assert HRDATA(0) = '1'
            report "FAIL: ENC bit not set"
            severity error;
        assert HRDATA(0) = '1'
            report "PASS: ENC bit set"
            severity note;

        -- Configure ADC12CTL1 (0x04): SHP=1 (bit3)
        ahb_write(x"00000004", x"00000008");

        -- Read back ADC12CTL1
        ahb_read(x"00000004");
        assert HRDATA(3) = '1'
            report "FAIL: SHP bit not set"
            severity error;
        assert HRDATA(3) = '1'
            report "PASS: SHP bit set"
            severity note;

        -- Set ADC12IE (0x48): enable interrupt for channel 0
        ahb_write(x"00000048", x"00000001");

        -- Start conversion: write ADC12SC=1 (bit1) with ENC=1
        ahb_write(x"00000000", x"00000403");

        -- Wait for conversion to complete
        wait for 2 us;

        -- Read ADC12MEM0 (0x08)
        ahb_read(x"00000008");
        -- With adc12_in(0)=1, result should be 0x0FFF
        assert HRDATA(15 downto 0) = x"0FFF"
            report "FAIL: ADC12MEM0 conversion result mismatch"
            severity error;
        assert HRDATA(15 downto 0) = x"0FFF"
            report "PASS: ADC12 conversion result correct"
            severity note;

        -- Read ADC12IFG (0x4C)
        ahb_read(x"0000004C");
        assert HRDATA(0) = '1'
            report "FAIL: ADC12IFG flag not set"
            severity error;
        assert HRDATA(0) = '1'
            report "PASS: ADC12IFG flag set"
            severity note;

        report "MSP430 ADC12 testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;
