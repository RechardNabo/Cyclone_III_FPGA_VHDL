-- ============================================================================
-- Testbench for Wishbone Classic Slave Interface
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_wishbone_interface is
end entity tb_wishbone_interface;

architecture sim of tb_wishbone_interface is

    -- DUT generics
    constant DATA_WIDTH : integer := 32;
    constant ADDR_WIDTH : integer := 32;

    -- DUT signals
    signal clk_i : std_logic := '0';
    signal rst_i : std_logic := '1';
    signal cyc_i : std_logic := '0';
    signal stb_i : std_logic := '0';
    signal we_i  : std_logic := '0';
    signal adr_i : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal dat_i : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal dat_o : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ack_o : std_logic;
    signal err_o : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate DUT
    dut : entity work.wishbone_interface
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            clk_i => clk_i,
            rst_i => rst_i,
            cyc_i => cyc_i,
            stb_i => stb_i,
            we_i  => we_i,
            adr_i => adr_i,
            dat_i => dat_i,
            dat_o => dat_o,
            ack_o => ack_o,
            err_o => err_o
        );

    -- Clock generation
    clk_proc : process
    begin
        clk_i <= '0';
        wait for CLK_PERIOD / 2;
        clk_i <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus process
    stim_proc : process
    begin

        -- -------------------------------------------------------
        -- Test 1: Reset state
        -- -------------------------------------------------------
        rst_i <= '1';
        cyc_i <= '0';
        stb_i <= '0';
        wait for CLK_PERIOD * 3;
        assert ack_o = '0'
            report "Test 1 FAIL: ack_o not low after reset"
            severity error;
        assert err_o = '0'
            report "Test 1 FAIL: err_o not low after reset"
            severity error;
        assert dat_o = (DATA_WIDTH-1 downto 0 => '0')
            report "Test 1 FAIL: dat_o not zero after reset"
            severity error;
        report "Test 1 PASS: Reset state correct" severity note;

        -- -------------------------------------------------------
        -- Test 2: Write 0xDEADBEEF to internal register
        -- -------------------------------------------------------
        rst_i <= '0';
        wait for CLK_PERIOD;
        cyc_i <= '1';
        stb_i <= '1';
        we_i  <= '1';
        dat_i <= x"DEADBEEF";
        adr_i <= (others => '0');
        wait for CLK_PERIOD;
        assert ack_o = '1'
            report "Test 2 FAIL: ack_o not high during write"
            severity error;
        report "Test 2 PASS: Write acknowledged" severity note;

        -- Deassert bus
        cyc_i <= '0';
        stb_i <= '0';
        we_i  <= '0';
        wait for CLK_PERIOD;
        assert ack_o = '0'
            report "Test 2b FAIL: ack_o not low after deassert"
            severity error;

        -- -------------------------------------------------------
        -- Test 3: Read back the written value
        -- -------------------------------------------------------
        cyc_i <= '1';
        stb_i <= '1';
        we_i  <= '0';  -- read
        adr_i <= (others => '0');
        wait for CLK_PERIOD;
        assert ack_o = '1'
            report "Test 3 FAIL: ack_o not high during read"
            severity error;
        assert dat_o = x"DEADBEEF"
            report "Test 3 FAIL: Read back value not 0xDEADBEEF"
            severity error;
        report "Test 3: Read back = 0x" severity note;
        report "Test 3 PASS: Read back 0xDEADBEEF correctly" severity note;

        -- Deassert
        cyc_i <= '0';
        stb_i <= '0';
        wait for CLK_PERIOD;

        -- -------------------------------------------------------
        -- Test 4: Write different value and read back
        -- -------------------------------------------------------
        cyc_i <= '1';
        stb_i <= '1';
        we_i  <= '1';
        dat_i <= x"12345678";
        wait for CLK_PERIOD;
        assert ack_o = '1'
            report "Test 4 FAIL: ack_o not high during second write"
            severity error;
        cyc_i <= '0';
        stb_i <= '0';
        wait for CLK_PERIOD;

        -- Read back
        cyc_i <= '1';
        stb_i <= '1';
        we_i  <= '0';
        wait for CLK_PERIOD;
        assert ack_o = '1'
            report "Test 4b FAIL: ack_o not high during second read"
            severity error;
        assert dat_o = x"12345678"
            report "Test 4b FAIL: Read back value not 0x12345678"
            severity error;
        report "Test 4 PASS: Second write/read cycle correct" severity note;

        -- -------------------------------------------------------
        -- Test 5: No ack when cyc_i=0
        -- -------------------------------------------------------
        cyc_i <= '0';
        stb_i <= '1';
        we_i  <= '0';
        wait for CLK_PERIOD;
        assert ack_o = '0'
            report "Test 5 FAIL: ack_o high when cyc_i=0"
            severity error;
        report "Test 5 PASS: No ack when cyc_i=0" severity note;

        -- End simulation
        assert false report "Testbench complete" severity failure;

    end process;

end architecture sim;
