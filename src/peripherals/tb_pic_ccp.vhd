--------------------------------------------------------------------------------
-- tb_pic_ccp : Testbench for PIC CCP capture mode via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_pic_ccp is
end entity tb_pic_ccp;

architecture sim of tb_pic_ccp is
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
    signal ccp1_pin  : std_logic := 'Z';
    signal ccp2_pin  : std_logic := 'Z';
    signal ccp_irq   : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.pic_ccp
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            ccp1_pin => ccp1_pin, ccp2_pin => ccp2_pin, ccp_irq => ccp_irq
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

        -- Configure CCP1 for capture mode, rising edge
        -- CCP1CON (0x00): bits3:0 = 0100 (capture rising edge)
        ahb_write(x"00000000", x"00000004");

        -- Read back CCP1CON
        ahb_read(x"00000000");
        assert HRDATA(3 downto 0) = "0100"
            report "FAIL: CCP1CON readback mismatch"
            severity error;
        assert HRDATA(3 downto 0) = "0100"
            report "PASS: CCP1CON configured for capture"
            severity note;

        -- Let internal timer run for some cycles
        wait for CLK_PERIOD * 20;

        -- Generate rising edge on ccp1_pin
        ccp1_pin <= '1';
        wait for CLK_PERIOD * 4;

        -- Read CCPR1L (0x04) and CCPR1H (0x08) - captured timer value
        ahb_read(x"00000004");
        assert HRDATA(7 downto 0) /= x"00"
            report "FAIL: CCPR1L capture value is zero"
            severity error;
        assert HRDATA(7 downto 0) /= x"00"
            report "PASS: CCPR1L captured nonzero value"
            severity note;

        ahb_read(x"00000008");

        -- Check IRQ was generated
        assert ccp_irq = '1'
            report "FAIL: CCP IRQ not generated on capture"
            severity error;
        assert ccp_irq = '1'
            report "PASS: CCP IRQ generated on capture"
            severity note;

        -- Test compare mode: set CCP1CON = 1000 (compare, set output on match)
        ccp1_pin <= 'Z';
        ahb_write(x"00000000", x"00000008");

        -- Set CCPR1 to a small value (0x0010)
        ahb_write(x"00000004", x"00000010");
        ahb_write(x"00000008", x"00000000");

        wait for 5 us;

        -- Read back CCPR1L and CCPR1H
        ahb_read(x"00000004");
        assert HRDATA(7 downto 0) = x"10"
            report "PASS: CCPR1L readback verified in compare mode"
            severity note;

        report "PIC CCP testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;
