-- ================================================================================
-- tb_rp2040_pio_sideset : Testbench for PIO side-set config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rp2040_pio_sideset is
end entity tb_rp2040_pio_sideset;

architecture sim of tb_rp2040_pio_sideset is
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
    signal sideset_out : std_logic_vector(7 downto 0);
    signal sideset_oe  : std_logic_vector(7 downto 0);
    signal sideset_clk : std_logic := '0';

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
    sideset_clk <= clk;

    dut : entity work.rp2040_pio_sideset
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            sideset_out => sideset_out, sideset_oe => sideset_oe,
            sideset_clk => sideset_clk
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write SIDESET_CTRL (enable=1, auto_dir=1)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000000", x"00000003");
        wait until rising_edge(clk);

        -- Test 2: Read SIDESET_CTRL back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000000", hrdata, rdata);
        assert rdata = x"00000003"
            report "FAIL: SIDESET_CTRL readback mismatch"
            severity error;
        if rdata = x"00000003" then
            report "PASS: SIDESET_CTRL readback" severity note;
        end if;

        -- Test 3: Write SIDESET_COUNT (3 pins)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000004", x"00000003");
        wait until rising_edge(clk);

        -- Test 4: Read SIDESET_COUNT back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000004", hrdata, rdata);
        assert rdata = x"00000003"
            report "FAIL: SIDESET_COUNT readback mismatch"
            severity error;
        if rdata = x"00000003" then
            report "PASS: SIDESET_COUNT readback" severity note;
        end if;

        -- Test 5: Write SIDESET_BASE (pin 4)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000008", x"00000004");
        wait until rising_edge(clk);

        -- Test 6: Read SIDESET_BASE back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000008", hrdata, rdata);
        assert rdata = x"00000004"
            report "FAIL: SIDESET_BASE readback mismatch"
            severity error;
        if rdata = x"00000004" then
            report "PASS: SIDESET_BASE readback" severity note;
        end if;

        -- Test 7: Write SIDESET_PINDIR (all output)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"0000000C", x"000000FF");
        wait until rising_edge(clk);

        report "tb_rp2040_pio_sideset DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
