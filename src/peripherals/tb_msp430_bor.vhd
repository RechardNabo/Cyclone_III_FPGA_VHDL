--------------------------------------------------------------------------------
-- tb_msp430_bor : Testbench for MSP430 BOR threshold via AHB-Lite
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_msp430_bor is
end entity tb_msp430_bor;

architecture sim of tb_msp430_bor is
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
    signal bor_out   : std_logic;
    signal bor_irq   : std_logic;

begin

    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.msp430_bor
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL,
            HWRITE => HWRITE, HREADY => HREADY, HTRANS => HTRANS,
            HSIZE => HSIZE, HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            bor_out => bor_out, bor_irq => bor_irq
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

        -- Read default BOR_THR (0x08) - should be 0x80
        ahb_read(x"00000008");
        assert HRDATA(7 downto 0) = x"80"
            report "FAIL: Default BOR threshold mismatch"
            severity error;
        assert HRDATA(7 downto 0) = x"80"
            report "PASS: Default BOR threshold is 0x80"
            severity note;

        -- Set threshold above vcc_level (0xC0): set BOR_THR = 0xD0
        ahb_write(x"00000008", x"000000D0");

        -- Enable BOR with interrupt: BOR_CTRL (0x00) bit0=BOREN, bit1=BORIE
        -- Also enable fast sampling: bit3=BORFS
        ahb_write(x"00000000", x"0000000B");

        -- Read back BOR_CTRL
        ahb_read(x"00000000");
        assert HRDATA(7 downto 0) = x"0B"
            report "FAIL: BOR_CTRL readback mismatch"
            severity error;
        assert HRDATA(7 downto 0) = x"0B"
            report "PASS: BOR_CTRL readback verified"
            severity note;

        -- Wait for fast sampling to detect brown-out (threshold > vcc)
        -- Fast mode samples every 16 cycles
        wait for 1 us;

        -- Read BOR_STAT (0x04): bit0=bor_active
        ahb_read(x"00000004");
        assert HRDATA(0) = '1'
            report "FAIL: BOR not active when vcc < threshold"
            severity error;
        assert HRDATA(0) = '1'
            report "PASS: BOR active detected"
            severity note;

        -- Check IRQ is pending (bit1)
        assert HRDATA(1) = '1'
            report "FAIL: BOR IRQ not pending"
            severity error;
        assert HRDATA(1) = '1'
            report "PASS: BOR IRQ pending"
            severity note;

        -- Lower threshold below vcc (0xC0): set BOR_THR = 0x80
        ahb_write(x"00000008", x"00000080");
        wait for 1 us;

        -- BOR should clear
        ahb_read(x"00000004");
        assert HRDATA(0) = '0'
            report "FAIL: BOR still active after threshold lowered"
            severity error;
        assert HRDATA(0) = '0'
            report "PASS: BOR cleared after threshold lowered"
            severity note;

        report "MSP430 BOR testbench complete" severity note;
        std.env.finish;
    end process stim;

end architecture sim;
