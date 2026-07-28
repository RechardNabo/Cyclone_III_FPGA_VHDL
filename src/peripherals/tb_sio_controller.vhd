-- ================================================================================
-- tb_sio_controller : Testbench for SIO inter-core FIFO
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_sio_controller is
end entity tb_sio_controller;

architecture sim of tb_sio_controller is
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
    signal core_id   : std_logic := '0';
    signal gpio_out  : std_logic_vector(31 downto 0);
    signal gpio_in   : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_oe   : std_logic_vector(31 downto 0);
    signal fifo_irq  : std_logic;

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

    dut : entity work.sio_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HSIZE => hsize, HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            core_id => core_id, gpio_out => gpio_out,
            gpio_in => gpio_in, gpio_oe => gpio_oe, fifo_irq => fifo_irq
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Write GPIO_OUT_SET
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000014", x"000000FF");
        wait until rising_edge(clk);

        -- Test 2: Read GPIO_OUT
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000010", hrdata, rdata);
        assert rdata(7 downto 0) = x"FF"
            report "FAIL: SIO GPIO_OUT set mismatch"
            severity error;
        if rdata(7 downto 0) = x"FF" then
            report "PASS: SIO GPIO_OUT set" severity note;
        end if;

        -- Test 3: Write FIFO_WR (core 0 writes to core 1)
        ahb_write(clk, hsel, hwrite, htrans, haddr, hwdata,
                  x"00000054", x"DEADBEEF");
        wait until rising_edge(clk);

        -- Test 4: Read FIFO_ST
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000050", hrdata, rdata);
        assert rdata(0) = '1'
            report "FAIL: SIO FIFO not showing data after write"
            severity error;
        if rdata(0) = '1' then
            report "PASS: SIO inter-core FIFO write" severity note;
        end if;

        -- Test 5: Read FIFO_RD
        ahb_read(clk, hsel, hwrite, htrans, haddr, x"00000058", hrdata, rdata);
        assert rdata = x"DEADBEEF"
            report "FAIL: SIO FIFO_RD data mismatch"
            severity error;
        if rdata = x"DEADBEEF" then
            report "PASS: SIO inter-core FIFO read" severity note;
        end if;

        report "tb_sio_controller DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
