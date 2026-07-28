-- ================================================================================
-- tb_rp2040_sio_full : Testbench for full interpolator
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rp2040_sio_full is
end entity tb_rp2040_sio_full;

architecture sim of tb_rp2040_sio_full is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal clk       : std_logic := '0';
    signal resetn    : std_logic := '0';
    signal hsel      : std_logic := '0';
    signal hwrite    : std_logic := '0';
    signal hready    : std_logic := '1';
    signal htrans    : std_logic_vector(1 downto 0) := "00";
    signal haddr     : std_logic_vector(31 downto 0) := (others => '0');
    signal hwdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal hrdata    : std_logic_vector(31 downto 0);
    signal hresp     : std_logic;
    signal hreadyout : std_logic;
    signal interp_irq: std_logic;

    procedure ahb_write(
        signal clk    : in std_logic;
        signal hsel   : out std_logic;
        signal hwrite : out std_logic;
        signal htrans : out std_logic_vector(1 downto 0);
        signal haddr  : out std_logic_vector(31 downto 0);
        signal hwdata : out std_logic_vector(31 downto 0);
        constant addr : in std_logic_vector(31 downto 0);
        constant data : in std_logic_vector(31 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        hsel <= '1'; hwrite <= '1'; htrans <= "10";
        haddr <= addr; hwdata <= data;
        wait until rising_edge(clk);
        hsel <= '0'; hwrite <= '0'; htrans <= "00";
    end procedure;

    procedure ahb_read(
        signal clk    : in std_logic;
        signal hsel   : out std_logic;
        signal hwrite : out std_logic;
        signal htrans : out std_logic_vector(1 downto 0);
        signal haddr  : out std_logic_vector(31 downto 0);
        constant addr : in std_logic_vector(31 downto 0);
        signal hrdata : in std_logic_vector(31 downto 0);
        variable rdata: out std_logic_vector(31 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        hsel <= '1'; hwrite <= '0'; htrans <= "10";
        haddr <= addr;
        wait until rising_edge(clk);
        rdata := hrdata;
        hsel <= '0'; htrans <= "00";
    end procedure;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.rp2040_sio_full
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            interp_irq => interp_irq
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write INTERP0_ACCUM0
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000000", x"00000100");
        wait until rising_edge(clk);

        -- Test 2: Read INTERP0_ACCUM0 back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000000", hrdata, rdata);
        assert rdata = x"00000100"
            report "FAIL: INTERP0 ACCUM0 readback mismatch"
            severity error;
        if rdata = x"00000100" then
            report "PASS: INTERP0 ACCUM0 readback" severity note;
        end if;

        -- Test 3: Write INTERP0_BASE0
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000008", x"00000010");
        wait until rising_edge(clk);

        -- Test 4: Read INTERP0_BASE0 back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000008", hrdata, rdata);
        assert rdata = x"00000010"
            report "FAIL: INTERP0 BASE0 readback mismatch"
            severity error;
        if rdata = x"00000010" then
            report "PASS: INTERP0 BASE0 readback" severity note;
        end if;

        -- Test 5: Write CTRL_LANE0 (shift=0, mask=0xFF)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"0000002C", x"00000100");
        wait until rising_edge(clk);

        -- Test 6: Read PEEK_LANE0 (should reflect accum0 + base0)
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000020", hrdata, rdata);
        assert rdata /= x"00000000"
            report "FAIL: INTERP0 PEEK_LANE0 zero result"
            severity error;
        if rdata /= x"00000000" then
            report "PASS: INTERP0 full interpolator result" severity note;
        end if;

        report "tb_rp2040_sio_full DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
