-- ================================================================================
-- tb_rp2040_sram_bank : Testbench for SRAM bank config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rp2040_sram_bank is
end entity tb_rp2040_sram_bank;

architecture sim of tb_rp2040_sram_bank is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz
    constant NUM_BANKS : integer := 6;

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
    signal bank_clk  : std_logic_vector(NUM_BANKS-1 downto 0);
    signal bank_cs   : std_logic_vector(NUM_BANKS-1 downto 0);
    signal sram_irq  : std_logic;

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

    dut : entity work.rp2040_sram_bank
        generic map (NUM_BANKS => NUM_BANKS, BANK_BYTES => 4096)
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            bank_clk => bank_clk, bank_cs => bank_cs, sram_irq => sram_irq
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write CTRL (enable + stripe_en)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000000", x"00000003");
        wait until rising_edge(clk);

        -- Test 2: Read CTRL back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000000", hrdata, rdata);
        assert rdata = x"00000003"
            report "FAIL: SRAM CTRL readback mismatch"
            severity error;
        if rdata = x"00000003" then
            report "PASS: SRAM CTRL readback" severity note;
        end if;

        -- Test 3: Write STRIPE_EN (enable banks 0-2)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000008", x"00000007");
        wait until rising_edge(clk);

        -- Test 4: Read STRIPE_EN back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000008", hrdata, rdata);
        assert rdata(2 downto 0) = "111"
            report "FAIL: SRAM STRIPE_EN readback mismatch"
            severity error;
        if rdata(2 downto 0) = "111" then
            report "PASS: SRAM STRIPE_EN readback" severity note;
        end if;

        -- Test 5: Write BANK_GATE (gate banks 0-5)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"0000000C", x"0000003F");
        wait until rising_edge(clk);

        -- Test 6: Read STAT
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000004", hrdata, rdata);
        assert rdata(0) = '1'
            report "FAIL: SRAM STAT ready not set"
            severity error;
        if rdata(0) = '1' then
            report "PASS: SRAM STAT ready" severity note;
        end if;

        report "tb_rp2040_sram_bank DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
