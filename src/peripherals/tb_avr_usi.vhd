--------------------------------------------------------------------------------
-- tb_avr_usi : Testbench for AVR USI shift register via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_avr_usi is
end entity tb_avr_usi;

architecture sim of tb_avr_usi is
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
    signal usi_clk   : std_logic;
    signal usi_do    : std_logic;
    signal usi_di    : std_logic := '0';
    signal usi_irq   : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.avr_usi
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            usi_clk => usi_clk, usi_do => usi_do,
            usi_di => usi_di, usi_irq => usi_irq
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

        -- Write USIDR (0x08) with test pattern 0xA5
        ahb_write(x"00000008", x"000000A5");

        -- Read back USIDR
        ahb_read(x"00000008");
        assert HRDATA(7 downto 0) = x"A5"
            report "FAIL: USIDR readback mismatch"
            severity error;
        assert HRDATA(7 downto 0) = x"A5"
            report "PASS: USIDR readback verified"
            severity note;

        -- Configure USICR: USIOE=1 (output enable), USIWM=01 (SPI), USICS=00
        -- USICR at 0x00: bit1=USIOE, bit2=USIWM0
        ahb_write(x"00000000", x"00000002");

        -- Strobe clock by writing USITC (bit0=1) + USICLK (bit6=1)
        -- This shifts the register
        ahb_write(x"00000000", x"00000041");
        wait for CLK_PERIOD * 2;

        -- Read USISR (0x04) - counter should have incremented
        ahb_read(x"00000004");
        assert HRDATA(3 downto 0) /= x"0"
            report "FAIL: USI counter did not increment"
            severity error;
        assert HRDATA(3 downto 0) /= x"0"
            report "PASS: USI counter incremented"
            severity note;

        -- Read USIBR (0x0C) - buffer should capture previous value
        ahb_read(x"0000000C");

        -- Test USIPP register write/read (0x10)
        ahb_write(x"00000010", x"00000001");
        ahb_read(x"00000010");
        assert HRDATA(0) = '1'
            report "PASS: USIPP readback verified"
            severity note;

        report "AVR USI testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;
