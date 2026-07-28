-- ================================================================================
-- tb_dma_controller : Testbench for DMA controller
-- ================================================================================
-- Verifies basic register read/write functionality and DMA transfer operation.
--
-- Tests:
--   1. Write control register (enable DMA channel 0)
--   2. Configure channel 0 (src_addr, dst_addr, count)
--   3. Start transfer and verify status (done/busy flags)
--   4. Read global channel status register
--   5. Verify destination memory matches source memory
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_dma_controller is
end entity tb_dma_controller;

architecture sim of tb_dma_controller is

    -- Clock and reset
    signal HCLK    : std_logic := '0';
    signal HRESETn : std_logic := '0';

    -- AHB-Lite slave signals
    signal HSEL      : std_logic                    := '0';
    signal HWRITE    : std_logic                    := '0';
    signal HREADY    : std_logic                    := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;

    -- DMA master interface
    signal m_addr  : std_logic_vector(31 downto 0);
    signal m_rdata : std_logic_vector(31 downto 0);
    signal m_wdata : std_logic_vector(31 downto 0);
    signal m_we    : std_logic;
    signal m_req   : std_logic;
    signal m_ack   : std_logic := '0';

    -- Interrupts
    signal dma_int    : std_logic_vector(3 downto 0);
    signal dma_req_in : std_logic_vector(3 downto 0) := "0000";

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

    -- Simple memory model (4K words = 16 KB)
    type mem_array is array(0 to 4095) of std_logic_vector(31 downto 0);

    -- Initialize memory with test data at source addresses
    -- Source: 0x1000 = word index 1024
    function init_mem return mem_array is
        variable m : mem_array := (others => (others => '0'));
    begin
        m(1024) := x"DEADBEEF";
        m(1025) := x"CAFEBABE";
        m(1026) := x"12345678";
        m(1027) := x"AABBCCDD";
        return m;
    end function;

    signal mem : mem_array := init_mem;

begin

    -- Clock generation (50 MHz, 20 ns period)
    HCLK <= not HCLK after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.dma_controller
        generic map (
            NUM_CHANNELS => 4,
            DATA_WIDTH   => 32,
            ADDR_WIDTH   => 32
        )
        port map (
            HCLK       => HCLK,
            HRESETn    => HRESETn,
            HSEL       => HSEL,
            HWRITE     => HWRITE,
            HREADY     => HREADY,
            HTRANS     => HTRANS,
            HSIZE      => HSIZE,
            HADDR      => HADDR,
            HWDATA     => HWDATA,
            HRDATA     => HRDATA,
            HRESP      => HRESP,
            HREADYOUT  => HREADYOUT,
            m_addr     => m_addr,
            m_rdata    => m_rdata,
            m_wdata    => m_wdata,
            m_we       => m_we,
            m_req      => m_req,
            m_ack      => m_ack,
            dma_int    => dma_int,
            dma_req_in => dma_req_in
        );

    -- Memory model: combinational read + ack, clocked write
    m_ack   <= m_req;
    m_rdata <= mem(to_integer(unsigned(m_addr(13 downto 2))))
               when m_req = '1' and m_we = '0'
               else (others => '0');

    mem_write_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if m_req = '1' and m_we = '1' then
                mem(to_integer(unsigned(m_addr(13 downto 2)))) <= m_wdata;
            end if;
        end if;
    end process;

    -- Stimulus process
    stim : process
        -- AHB write procedure
        procedure ahb_write(addr : in std_logic_vector(31 downto 0);
                            data : in std_logic_vector(31 downto 0)) is
        begin
            HSEL   <= '1';
            HWRITE <= '1';
            HTRANS <= "10";
            HADDR  <= addr;
            HWDATA <= data;
            wait until rising_edge(HCLK);
            HSEL   <= '0';
            HWRITE <= '0';
            HTRANS <= "00";
        end procedure;

        -- AHB read procedure
        procedure ahb_read(addr : in std_logic_vector(31 downto 0);
                           data : out std_logic_vector(31 downto 0)) is
        begin
            HSEL   <= '1';
            HWRITE <= '0';
            HTRANS <= "10";
            HADDR  <= addr;
            wait until rising_edge(HCLK);
            data := HRDATA;
            HSEL   <= '0';
            HTRANS <= "00";
        end procedure;

        variable rdata     : std_logic_vector(31 downto 0);
        variable test_pass : boolean := true;
    begin
        -- Reset sequence
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait until rising_edge(HCLK);

        -- ==================================================================
        -- Test 1: Write control register (enable DMA channel 0)
        -- ==================================================================
        report "Test 1: Write control register (enable DMA channel 0)";
        ahb_write(x"00000000", x"00000001");  -- ch0 CTRL: enable=1
        ahb_read(x"00000000", rdata);
        assert rdata(0) = '1'
            report "Test 1 FAILED: CTRL enable bit not set" severity error;
        if rdata(0) = '1' then
            report "Test 1 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 2: Configure channel 0 (src_addr, dst_addr, count)
        -- ==================================================================
        report "Test 2: Configure channel 0 (src_addr, dst_addr, count)";
        ahb_write(x"00000004", x"00001000");  -- ch0 SRC_ADDR = 0x1000
        ahb_write(x"00000008", x"00002000");  -- ch0 DST_ADDR = 0x2000
        ahb_write(x"0000000C", x"00000004");  -- ch0 COUNT = 4 words

        -- Verify configuration by reading back
        ahb_read(x"00000004", rdata);
        assert rdata = x"00001000"
            report "Test 2 FAILED: SRC_ADDR mismatch" severity error;
        if rdata /= x"00001000" then test_pass := false; end if;

        ahb_read(x"00000008", rdata);
        assert rdata = x"00002000"
            report "Test 2 FAILED: DST_ADDR mismatch" severity error;
        if rdata /= x"00002000" then test_pass := false; end if;

        ahb_read(x"0000000C", rdata);
        assert rdata = x"00000004"
            report "Test 2 FAILED: COUNT mismatch" severity error;
        if rdata = x"00000004" then
            report "Test 2 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 3: Start transfer and verify status
        -- ==================================================================
        report "Test 3: Start transfer and verify status";
        -- Write CTRL with enable + start (bit0 + bit3 = 0x09)
        ahb_write(x"00000000", x"00000009");

        -- Wait for transfer to complete (4 words, ~20 cycles)
        wait for 2 us;

        -- Read channel 0 CTRL to check done/busy flags
        ahb_read(x"00000000", rdata);
        assert rdata(4) = '1'
            report "Test 3 FAILED: DONE bit not set" severity error;
        assert rdata(5) = '0'
            report "Test 3 FAILED: BUSY bit still set" severity error;
        if rdata(4) = '1' and rdata(5) = '0' then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Test 4: Read global channel status register
        -- ==================================================================
        report "Test 4: Read global channel status register";
        ahb_read(x"00000040", rdata);
        -- bit0 = ch0 done, bit4 = ch0 busy
        assert rdata(0) = '1'
            report "Test 4 FAILED: status done flag not set for ch0" severity error;
        assert rdata(4) = '0'
            report "Test 4 FAILED: status busy flag still set for ch0" severity error;
        if rdata(0) = '1' and rdata(4) = '0' then
            report "Test 4 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Verify destination memory matches source memory
        -- ==================================================================
        assert mem(2048) = x"DEADBEEF"
            report "Verify FAILED: dst[0] mismatch" severity error;
        assert mem(2049) = x"CAFEBABE"
            report "Verify FAILED: dst[1] mismatch" severity error;
        assert mem(2050) = x"12345678"
            report "Verify FAILED: dst[2] mismatch" severity error;
        assert mem(2051) = x"AABBCCDD"
            report "Verify FAILED: dst[3] mismatch" severity error;
        if mem(2048) = x"DEADBEEF" and mem(2049) = x"CAFEBABE" and
           mem(2050) = x"12345678" and mem(2051) = x"AABBCCDD" then
            report "Memory verification PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- ==================================================================
        -- Final report
        -- ==================================================================
        if test_pass then
            report "=== ALL DMA CONTROLLER TESTS PASSED ===" severity note;
        else
            report "=== DMA CONTROLLER TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;

end architecture sim;
