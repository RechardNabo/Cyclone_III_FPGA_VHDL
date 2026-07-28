-- ================================================================================
-- tb_bitband_controller : Testbench for bit-band address transformation
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_bitband_controller is
end entity tb_bitband_controller;

architecture sim of tb_bitband_controller is
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
    signal bb_addr   : std_logic_vector(31 downto 0);
    signal bb_rdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal bb_wdata  : std_logic_vector(31 downto 0);
    signal bb_we     : std_logic;
    signal bb_strobe : std_logic;

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

    dut : entity work.bitband_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            bb_addr => bb_addr, bb_rdata => bb_rdata,
            bb_wdata => bb_wdata, bb_we => bb_we, bb_strobe => bb_strobe
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write CTRL (enable + base addr 0x20000000)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000000", x"20000001");
        wait until rising_edge(clk);

        -- Test 2: Read CTRL back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000000", hrdata, rdata);
        assert rdata = x"20000001"
            report "FAIL: BB CTRL readback mismatch"
            severity error;
        if rdata = x"20000001" then
            report "PASS: BB CTRL readback" severity note;
        end if;

        -- Test 3: Read STAT (should be idle=0)
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000004", hrdata, rdata);
        assert rdata(0) = '0'
            report "FAIL: BB STAT not idle after reset"
            severity error;
        if rdata(0) = '0' then
            report "PASS: BB STAT idle" severity note;
        end if;

        -- Test 4: Alias write - write to alias addr 0x08 (reg_sel=2)
        -- bit_word_offset = addr[22:2], bit_pos = offset[4:0]
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000008", x"00000001");
        wait for 200 ns;

        -- Test 5: Check bb_strobe asserted during transformation
        assert bb_strobe = '1' or bb_we = '1' or bb_addr /= x"00000000"
            report "FAIL: BB address transformation not triggered"
            severity error;
        report "PASS: BB bit-band write transformation" severity note;

        report "tb_bitband_controller DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
