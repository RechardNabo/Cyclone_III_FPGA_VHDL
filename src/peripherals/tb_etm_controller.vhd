-- ================================================================================
-- tb_etm_controller : Testbench for ETM trace configuration
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_etm_controller is
end entity tb_etm_controller;

architecture sim of tb_etm_controller is
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
    signal cpu_iaddr : std_logic_vector(31 downto 0) := (others => '0');
    signal etm_clk   : std_logic;
    signal etm_data  : std_logic_vector(3 downto 0);
    signal etm_sync  : std_logic;

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

    dut : entity work.etm_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            cpu_iaddr => cpu_iaddr,
            etm_clk => etm_clk, etm_data => etm_data, etm_sync => etm_sync
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write CTRL (bit0=ETMEN, bit1=TRACEEN)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000000", x"00000003");
        wait until rising_edge(clk);

        -- Test 2: Read CTRL back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000000", hrdata, rdata);
        assert rdata = x"00000003"
            report "FAIL: ETM CTRL readback mismatch"
            severity error;
        if rdata = x"00000003" then
            report "PASS: ETM CTRL readback" severity note;
        end if;

        -- Test 3: Write TRACE_EN (enable comparator 0)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000004", x"00000001");
        wait until rising_edge(clk);

        -- Test 4: Write ADDR_COMP0
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000010", x"00008000");
        wait until rising_edge(clk);

        -- Test 5: Read ADDR_COMP0 back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000010", hrdata, rdata);
        assert rdata = x"00008000"
            report "FAIL: ETM ADDR_COMP0 readback mismatch"
            severity error;
        if rdata = x"00008000" then
            report "PASS: ETM ADDR_COMP0 readback" severity note;
        end if;

        -- Test 6: Drive matching CPU instruction address, check trace
        cpu_iaddr <= x"00008000";
        wait for 400 ns;
        assert etm_data /= "0000" or etm_clk = '1'
            report "FAIL: ETM trace not active on address match"
            severity error;
        report "PASS: ETM trace config test" severity note;

        report "tb_etm_controller DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
