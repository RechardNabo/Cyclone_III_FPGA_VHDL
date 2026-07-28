-- ================================================================================
-- tb_nvic_tailchain : Testbench for NVIC interrupt enable/pending
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_nvic_tailchain is
end entity tb_nvic_tailchain;

architecture sim of tb_nvic_tailchain is
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
    signal irq_in    : std_logic_vector(31 downto 0) := (others => '0');
    signal exc_return: std_logic := '0';
    signal cpu_pri   : std_logic_vector(2 downto 0) := "111";
    signal irq_out   : std_logic;
    signal irq_num   : std_logic_vector(5 downto 0);
    signal exc_active: std_logic;

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

    dut : entity work.nvic_tailchain
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            irq_in => irq_in, exception_return => exc_return,
            cpu_pri => cpu_pri, irq_out => irq_out,
            irq_num => irq_num, exception_active => exc_active
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write ISER to enable IRQ 0
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000004", x"00000001");
        wait until rising_edge(clk);

        -- Test 2: Write ISPR to set pending for IRQ 0
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"0000000C", x"00000001");
        wait for 100 ns;

        -- Test 3: Read IABR - IRQ 0 should be active
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000014", hrdata, rdata);
        assert rdata(0) = '1'
            report "FAIL: NVIC IRQ 0 not active after enable+pending"
            severity error;
        if rdata(0) = '1' then
            report "PASS: NVIC interrupt enable/pending/active" severity note;
        end if;

        -- Test 4: Write IPR0 to set priority for IRQ 0
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000018", x"00000020");
        wait until rising_edge(clk);

        -- Test 5: Read IPR0 back
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000018", hrdata, rdata);
        assert rdata(7 downto 5) = "001"
            report "FAIL: NVIC IPR0 priority mismatch"
            severity error;
        if rdata(7 downto 5) = "001" then
            report "PASS: NVIC priority register" severity note;
        end if;

        report "tb_nvic_tailchain DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
