--------------------------------------------------------------------------------
-- tb_msp430_lpm : Testbench for MSP430 LPM mode entry via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_msp430_lpm is
end entity tb_msp430_lpm;

architecture sim of tb_msp430_lpm is
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
    signal cpu_clk_en : std_logic;
    signal mclk_en    : std_logic;
    signal smclk_en   : std_logic;
    signal aclk_en    : std_logic;
    signal lpm_irq    : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.msp430_lpm
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            cpu_clk_en => cpu_clk_en, mclk_en => mclk_en,
            smclk_en => smclk_en, aclk_en => aclk_en, lpm_irq => lpm_irq
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

        -- Enter LPM0: CPUOFF=1 (bit7), mode=0
        -- LPM_CTRL at 0x00
        ahb_write(x"00000000", x"00000080");
        wait for CLK_PERIOD * 2;

        -- Check LPM_STAT (0x04): bit0=in_lpm, bit1=cpu_off
        ahb_read(x"00000004");
        assert HRDATA(0) = '1'
            report "FAIL: Not in LPM after CPUOFF set"
            severity error;
        assert HRDATA(0) = '1'
            report "PASS: Entered LPM mode"
            severity note;

        -- CPU clock should be disabled
        assert cpu_clk_en = '0'
            report "FAIL: CPU clock not gated in LPM"
            severity error;
        assert cpu_clk_en = '0'
            report "PASS: CPU clock gated"
            severity note;

        -- Enter LPM4: CPUOFF=1, OSCOFF=1, SCG0=1, SCG1=1
        -- bit7=CPUOFF, bit6=OSCOFF, bit5=SCG1, bit4=SCG0 => 0xF0
        ahb_write(x"00000000", x"000000F0");
        wait for CLK_PERIOD * 2;

        ahb_read(x"00000004");
        assert HRDATA(4) = '1'
            report "FAIL: ACLK not off in LPM4"
            severity error;
        assert HRDATA(4) = '1'
            report "PASS: ACLK off in LPM4"
            severity note;

        -- Exit LPM: write CPUOFF=0
        ahb_write(x"00000000", x"00000000");
        wait for CLK_PERIOD * 2;

        ahb_read(x"00000004");
        assert HRDATA(0) = '0'
            report "FAIL: Still in LPM after exit"
            severity error;
        assert HRDATA(0) = '0'
            report "PASS: Exited LPM mode"
            severity note;

        report "MSP430 LPM testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;
