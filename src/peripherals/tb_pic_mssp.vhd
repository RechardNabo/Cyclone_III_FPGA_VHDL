--------------------------------------------------------------------------------
-- tb_pic_mssp : Testbench for PIC MSSP SPI mode via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_pic_mssp is
end entity tb_pic_mssp;

architecture sim of tb_pic_mssp is
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
    signal sck       : std_logic;
    signal sdi       : std_logic := '1';
    signal sdo       : std_logic;
    signal sda       : std_logic;
    signal scl       : std_logic;
    signal mssp_irq  : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.pic_mssp
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            sck => sck, sdi => sdi, sdo => sdo,
            sda => sda, scl => scl, mssp_irq => mssp_irq
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

        -- Configure SSPCON1 (0x00) for SPI master mode
        -- bit5=SSPEN=1, bits3:0=SSPM=0000 (SPI master, Fosc/4)
        ahb_write(x"00000000", x"00000020");

        -- Read back SSPCON1
        ahb_read(x"00000000");
        assert HRDATA(5) = '1'
            report "FAIL: SSPEN not set"
            severity error;
        assert HRDATA(5) = '1'
            report "PASS: SSPEN enabled"
            severity note;

        -- Configure SSPSTAT (0x08): CKE=1 (bit6), SMP=1 (bit7)
        ahb_write(x"00000008", x"000000C0");

        -- Read back SSPSTAT
        ahb_read(x"00000008");
        assert HRDATA(7 downto 6) = "11"
            report "FAIL: SSPSTAT readback mismatch"
            severity error;
        assert HRDATA(7 downto 6) = "11"
            report "PASS: SSPSTAT readback verified"
            severity note;

        -- Write SSPBUF (0x0C) with test data 0x55
        ahb_write(x"0000000C", x"00000055");

        -- Wait for SPI shift to complete (8 bits at baud rate /4 = ~32 cycles)
        wait for 2 us;

        -- Read SSPBUF (0x0C) - should contain received data
        ahb_read(x"0000000C");

        -- Read SSPSTAT to check BF flag (bit0)
        ahb_read(x"00000008");
        assert HRDATA(0) = '1'
            report "FAIL: BF flag not set after SPI transfer"
            severity error;
        assert HRDATA(0) = '1'
            report "PASS: BF flag set after SPI transfer"
            severity note;

        -- Test SSPADD (0x10) write/read
        ahb_write(x"00000010", x"0000001F");
        ahb_read(x"00000010");
        assert HRDATA(7 downto 0) = x"1F"
            report "FAIL: SSPADD readback mismatch"
            severity error;
        assert HRDATA(7 downto 0) = x"1F"
            report "PASS: SSPADD readback verified"
            severity note;

        report "PIC MSSP testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;
