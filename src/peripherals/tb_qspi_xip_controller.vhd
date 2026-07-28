-- ================================================================================
-- tb_qspi_xip_controller : Testbench for QSPI XIP cache config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_qspi_xip_controller is
end entity tb_qspi_xip_controller;

architecture sim of tb_qspi_xip_controller is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal clk       : std_logic := '0';
    signal resetn    : std_logic := '0';
    signal hsel      : std_logic := '0';
    signal hwrite    : std_logic := '0';
    signal hready    : std_logic := '1';
    signal htrans    : std_logic_vector(1 downto 0) := "00";
    signal hsize     : std_logic_vector(2 downto 0) := "010";
    signal haddr     : std_logic_vector(31 downto 0) := (others => '0');
    signal hwdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal hrdata    : std_logic_vector(31 downto 0);
    signal hresp     : std_logic;
    signal hreadyout : std_logic;
    signal qspi_clk  : std_logic;
    signal qspi_cs_n : std_logic;
    signal qspi_dq   : std_logic_vector(3 downto 0) := (others => 'Z');
    signal qspi_int  : std_logic;

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

    dut : entity work.qspi_xip_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HSIZE => hsize, HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            qspi_clk => qspi_clk, qspi_cs_n => qspi_cs_n,
            qspi_dq => qspi_dq, qspi_int => qspi_int
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write CTRL (enable=1, mode=quad, clkdiv=4)
        -- bit0=enable, bits[2:1]=mode, bits[15:8]=clkdiv
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000000", x"00000501");
        wait until rising_edge(clk);

        -- Test 2: Read CTRL back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000000", hrdata, rdata);
        assert rdata(0) = '1'
            report "FAIL: QSPI CTRL enable not set"
            severity error;
        if rdata(0) = '1' then
            report "PASS: QSPI CTRL enable" severity note;
        end if;

        -- Test 3: Read STAT
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000004", hrdata, rdata);
        assert rdata(0) = '0'
            report "FAIL: QSPI STAT busy should be 0 when idle"
            severity error;
        if rdata(0) = '0' then
            report "PASS: QSPI STAT idle" severity note;
        end if;

        -- Test 4: Write CACHE_CTRL (enable + flush)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000014", x"00000003");
        wait until rising_edge(clk);

        -- Test 5: Read CACHE_CTRL back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000014", hrdata, rdata);
        assert rdata(0) = '1'
            report "FAIL: QSPI CACHE_CTRL enable not set"
            severity error;
        if rdata(0) = '1' then
            report "PASS: QSPI cache config" severity note;
        end if;

        report "tb_qspi_xip_controller DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
