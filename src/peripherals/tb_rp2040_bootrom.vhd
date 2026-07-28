-- ================================================================================
-- tb_rp2040_bootrom : Testbench for boot ROM sequence
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rp2040_bootrom is
end entity tb_rp2040_bootrom;

architecture sim of tb_rp2040_bootrom is
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
    signal boot_irq      : std_logic;
    signal boot_addr_out : std_logic_vector(31 downto 0);
    signal boot_en       : std_logic;

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

    dut : entity work.rp2040_bootrom
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            boot_irq => boot_irq, boot_addr_out => boot_addr_out,
            boot_en => boot_en
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Read default BOOT_ADDR (should be 0x10000000)
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000008", hrdata, rdata);
        assert rdata = x"10000000"
            report "FAIL: BOOT_ADDR default mismatch"
            severity error;
        if rdata = x"10000000" then
            report "PASS: BOOT_ADDR default" severity note;
        end if;

        -- Test 2: Write CTRL to enable boot (bit0=boot_en, bit1=irq_en)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000000", x"00000003");
        wait until rising_edge(clk);

        -- Test 3: Read CTRL back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000000", hrdata, rdata);
        assert rdata(0) = '1'
            report "FAIL: BOOT CTRL enable not set"
            severity error;
        if rdata(0) = '1' then
            report "PASS: BOOT CTRL enable" severity note;
        end if;

        -- Test 4: Wait for boot sequence and read STAT
        wait for 500 ns;
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000004", hrdata, rdata);
        -- boot_done or boot_stage should have progressed
        assert rdata /= x"00000000"
            report "FAIL: BOOT STAT not progressing after boot_en"
            severity error;
        if rdata /= x"00000000" then
            report "PASS: BOOT STAT progressing" severity note;
        end if;

        -- Test 5: Read BOOT_STAGE
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000010", hrdata, rdata);
        assert rdata /= x"00000000"
            report "FAIL: BOOT_STAGE not advancing"
            severity error;
        if rdata /= x"00000000" then
            report "PASS: BOOT_STAGE advancing" severity note;
        end if;

        report "tb_rp2040_bootrom DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
