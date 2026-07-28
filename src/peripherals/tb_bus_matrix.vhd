-- ================================================================================
-- tb_bus_matrix : Testbench for AHB bus matrix arbitration
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_bus_matrix is
end entity tb_bus_matrix;

architecture sim of tb_bus_matrix is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz
    constant NM : integer := 4;
    constant NUM_SLAVES : integer := 8;

    signal clk       : std_logic := '0';
    signal resetn    : std_logic := '0';

    signal m_hsel    : std_logic_vector(NM-1 downto 0) := (others => '0');
    signal m_hwrite  : std_logic_vector(NM-1 downto 0) := (others => '0');
    signal m_htrans  : std_logic_vector(NM*2-1 downto 0) := (others => '0');
    signal m_hsize   : std_logic_vector(NM*3-1 downto 0) := (others => '0');
    signal m_haddr   : std_logic_vector(NM*32-1 downto 0) := (others => '0');
    signal m_hwdata  : std_logic_vector(NM*32-1 downto 0) := (others => '0');
    signal m_hready  : std_logic_vector(NM-1 downto 0);
    signal m_hrdata  : std_logic_vector(NM*32-1 downto 0);
    signal m_hresp   : std_logic_vector(NM-1 downto 0);

    signal s_hsel    : std_logic_vector(NUM_SLAVES-1 downto 0);
    signal s_hwrite  : std_logic_vector(NUM_SLAVES-1 downto 0);
    signal s_htrans  : std_logic_vector(NUM_SLAVES*2-1 downto 0);
    signal s_hsize   : std_logic_vector(NUM_SLAVES*3-1 downto 0);
    signal s_haddr   : std_logic_vector(NUM_SLAVES*32-1 downto 0);
    signal s_hwdata  : std_logic_vector(NUM_SLAVES*32-1 downto 0);
    signal s_hready  : std_logic_vector(NUM_SLAVES-1 downto 0) := (others => '1');
    signal s_hrdata  : std_logic_vector(NUM_SLAVES*32-1 downto 0) := (others => '0');
    signal s_hresp   : std_logic_vector(NUM_SLAVES-1 downto 0) := (others => '0');

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.bus_matrix
        generic map (NUM_MASTERS => NM, NUM_SLAVES => NUM_SLAVES,
                     ADDR_WIDTH => 32, DATA_WIDTH => 32)
        port map (
            HCLK => clk, HRESETn => resetn,
            m_HSEL => m_hsel, m_HWRITE => m_hwrite,
            m_HTRANS => m_htrans, m_HSIZE => m_hsize,
            m_HADDR => m_haddr, m_HWDATA => m_hwdata,
            m_HREADY => m_hready, m_HRDATA => m_hrdata, m_HRESP => m_hresp,
            s_HSEL => s_hsel, s_HWRITE => s_hwrite,
            s_HTRANS => s_htrans, s_HSIZE => s_hsize,
            s_HADDR => s_haddr, s_HWDATA => s_hwdata,
            s_HREADY => s_hready, s_HRDATA => s_hrdata, s_HRESP => s_hresp
        );

    stim : process
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: Master 0 accesses slave 0 (addr 0x00000000)
        m_hsel(0)   <= '1';
        m_hwrite(0) <= '1';
        m_htrans(1 downto 0) <= "10";
        m_haddr(31 downto 0) <= x"00000000";
        m_hwdata(31 downto 0) <= x"DEADBEEF";
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- Slave 0 should be selected
        assert s_hsel(0) = '1'
            report "FAIL: Bus matrix did not select slave 0 for master 0"
            severity error;
        if s_hsel(0) = '1' then
            report "PASS: Bus matrix slave 0 select" severity note;
        end if;

        m_hsel(0) <= '0';
        m_htrans(1 downto 0) <= "00";
        wait until rising_edge(clk);

        -- Test 2: Master 1 accesses slave 1 (addr 0x00100000)
        m_hsel(1)   <= '1';
        m_hwrite(1) <= '1';
        m_htrans(3 downto 2) <= "10";
        m_haddr(63 downto 32) <= x"00100000";
        m_hwdata(63 downto 32) <= x"CAFEBABE";
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        assert s_hsel(1) = '1'
            report "FAIL: Bus matrix did not select slave 1 for master 1"
            severity error;
        if s_hsel(1) = '1' then
            report "PASS: Bus matrix slave 1 select" severity note;
        end if;

        m_hsel(1) <= '0';
        m_htrans(3 downto 2) <= "00";
        wait until rising_edge(clk);

        -- Test 3: Verify master ready response
        assert m_hready(0) = '1'
            report "FAIL: Master 0 HREADY not high when idle"
            severity error;
        if m_hready(0) = '1' then
            report "PASS: Bus matrix master ready" severity note;
        end if;

        report "tb_bus_matrix DONE" severity note;
        std.env.finish;
    end process;

end architecture sim;
