-- ============================================================================
-- Testbench for AXI4-Lite Slave Interface (Simplified)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_axi_interface is
end entity tb_axi_interface;

architecture sim of tb_axi_interface is

    -- DUT generics
    constant C_AXI_DATA_WIDTH : integer := 32;
    constant C_AXI_ADDR_WIDTH : integer := 4;

    -- DUT signals
    signal ACLK    : std_logic := '0';
    signal ARESETn : std_logic := '0';

    -- Write Address Channel
    signal AWADDR  : std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal AWVALID : std_logic := '0';
    signal AWREADY : std_logic;

    -- Write Data Channel
    signal WDATA   : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
    signal WVALID  : std_logic := '0';
    signal WREADY  : std_logic;

    -- Write Response Channel
    signal BRESP   : std_logic_vector(1 downto 0);
    signal BVALID  : std_logic;
    signal BREADY  : std_logic := '0';

    -- Read Address Channel
    signal ARADDR  : std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal ARVALID : std_logic := '0';
    signal ARREADY : std_logic;

    -- Read Data Channel
    signal RDATA   : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
    signal RRESP   : std_logic_vector(1 downto 0);
    signal RVALID  : std_logic;
    signal RREADY  : std_logic := '0';

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.axi_interface
        generic map (
            C_AXI_DATA_WIDTH => C_AXI_DATA_WIDTH,
            C_AXI_ADDR_WIDTH => C_AXI_ADDR_WIDTH
        )
        port map (
            ACLK    => ACLK,
            ARESETn => ARESETn,
            AWADDR  => AWADDR,
            AWVALID => AWVALID,
            AWREADY => AWREADY,
            WDATA   => WDATA,
            WVALID  => WVALID,
            WREADY  => WREADY,
            BRESP   => BRESP,
            BVALID  => BVALID,
            BREADY  => BREADY,
            ARADDR  => ARADDR,
            ARVALID => ARVALID,
            ARREADY => ARREADY,
            RDATA   => RDATA,
            RRESP   => RRESP,
            RVALID  => RVALID,
            RREADY  => RREADY
        );

    -- Clock generation
    clk_proc : process
    begin
        ACLK <= '0';
        wait for CLK_PERIOD / 2;
        ACLK <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus process
    stim_proc : process
    begin

        -- -------------------------------------------------------
        -- Test 1: Reset state (ARESETn=0)
        -- -------------------------------------------------------
        ARESETn <= '0';
        AWVALID <= '0';
        WVALID  <= '0';
        BREADY  <= '0';
        ARVALID <= '0';
        RREADY  <= '0';
        wait for CLK_PERIOD * 3;
        assert AWREADY = '0'
            report "Test 1 FAIL: AWREADY not low during reset"
            severity error;
        assert BVALID = '0'
            report "Test 1 FAIL: BVALID not low during reset"
            severity error;
        assert ARREADY = '0'
            report "Test 1 FAIL: ARREADY not low during reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;

        -- Release reset
        ARESETn <= '1';
        wait for CLK_PERIOD;

        -- -------------------------------------------------------
        -- Test 2: Write transaction - write 0xCAFEF00D
        -- -------------------------------------------------------
        -- Phase 1: AW handshake
        AWADDR  <= "0000";
        AWVALID <= '1';
        wait until AWREADY = '1' for CLK_PERIOD * 10;
        wait for CLK_PERIOD;
        AWVALID <= '0';

        -- Phase 2: W handshake
        WDATA  <= x"CAFEF00D";
        WVALID <= '1';
        wait until WREADY = '1' for CLK_PERIOD * 10;
        wait for CLK_PERIOD;
        WVALID <= '0';

        -- Phase 3: B handshake
        BREADY <= '1';
        wait until BVALID = '1' for CLK_PERIOD * 10;
        assert BRESP = "00"
            report "Test 2 FAIL: BRESP not OKAY"
            severity error;
        wait for CLK_PERIOD;
        BREADY <= '0';
        report "Test 2 PASS: Write transaction completed with OKAY" severity note;

        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 3: Read transaction - should read back 0xCAFEF00D
        -- -------------------------------------------------------
        ARADDR  <= "0000";
        ARVALID <= '1';
        wait until ARREADY = '1' for CLK_PERIOD * 10;
        wait for CLK_PERIOD;
        ARVALID <= '0';

        RREADY <= '1';
        wait until RVALID = '1' for CLK_PERIOD * 10;
        assert RRESP = "00"
            report "Test 3 FAIL: RRESP not OKAY"
            severity error;
        assert RDATA = x"CAFEF00D"
            report "Test 3 FAIL: RDATA not 0xCAFEF00D"
            severity error;
        report "Test 3: Read back = 0x" & to_hstring(unsigned(RDATA)) severity note;
        wait for CLK_PERIOD;
        RREADY <= '0';
        report "Test 3 PASS: Read back 0xCAFEF00D correctly" severity note;

        wait for CLK_PERIOD * 2;

        -- -------------------------------------------------------
        -- Test 4: Write another value and read back
        -- -------------------------------------------------------
        -- Write
        AWADDR  <= "0000";
        AWVALID <= '1';
        wait until AWREADY = '1' for CLK_PERIOD * 10;
        wait for CLK_PERIOD;
        AWVALID <= '0';

        WDATA  <= x"AAAAAAAA";
        WVALID <= '1';
        wait until WREADY = '1' for CLK_PERIOD * 10;
        wait for CLK_PERIOD;
        WVALID <= '0';

        BREADY <= '1';
        wait until BVALID = '1' for CLK_PERIOD * 10;
        wait for CLK_PERIOD;
        BREADY <= '0';

        -- Read
        ARADDR  <= "0000";
        ARVALID <= '1';
        wait until ARREADY = '1' for CLK_PERIOD * 10;
        wait for CLK_PERIOD;
        ARVALID <= '0';

        RREADY <= '1';
        wait until RVALID = '1' for CLK_PERIOD * 10;
        assert RDATA = x"AAAAAAAA"
            report "Test 4 FAIL: RDATA not 0xAAAAAAAA"
            severity error;
        wait for CLK_PERIOD;
        RREADY <= '0';
        report "Test 4 PASS: Second write/read cycle correct" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;
