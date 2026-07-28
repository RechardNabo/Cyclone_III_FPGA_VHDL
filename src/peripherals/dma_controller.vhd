-- ================================================================================
-- dma_controller : Multi-channel DMA controller with AHB-Lite slave interface
-- ================================================================================
-- Educational DMA controller for Cyclone III FPGA implementation.
--
-- Features:
--   * 4-channel DMA engine (configurable via NUM_CHANNELS generic)
--   * AHB-Lite slave register interface for configuration
--   * DMA bus master interface (m_req/m_ack handshake) for memory transfers
--   * Per-channel interrupt output with enable/disable
--   * External DMA request input per channel (peripheral-triggered transfers)
--   * Auto-reload mode for continuous circular transfers
--   * Word-aligned transfers (32-bit data width default)
--
-- Register Map (per channel, 16 bytes per channel):
--   Base + 0x00: DMA_CTRL
--       bit0 = enable         (RW)  - channel enable
--       bit1 = irq_en         (RW)  - interrupt enable
--       bit2 = auto_reload    (RW)  - automatic restart on completion
--       bit3 = start          (WO)  - write 1 to start transfer (command pulse)
--       bit4 = done           (RO)  - set when transfer complete
--       bit5 = busy           (RO)  - set while transfer in progress
--   Base + 0x04: DMA_SRC_ADDR - source start address (32-bit)
--   Base + 0x08: DMA_DST_ADDR - destination start address (32-bit)
--   Base + 0x0C: DMA_COUNT    - transfer count in words (32-bit)
--
-- Global Registers:
--   Base + 0x40: DMA_STATUS
--       bit0..3 = channel done flags
--       bit4..7 = channel busy flags
--   Base + 0x44: DMA_IRQ_STATUS
--       bit0..3 = channel IRQ pending flags
--   Base + 0x48: DMA_IRQ_CLEAR
--       bit0..3 = write 1 to clear corresponding IRQ (write-only)
--
-- DMA Master Interface Protocol:
--   1. DMA asserts m_req with m_addr, m_we, m_wdata
--   2. Memory asserts m_ack when transfer is complete (m_rdata valid on read)
--   3. DMA deasserts m_req and advances to next transfer
--
-- Channel FSM States:
--   IDLE        - waiting for start command or external DMA request
--   REQ_READ    - assert read request, transition to WAIT_READ
--   WAIT_READ   - wait for m_ack, capture read data into buffer
--   REQ_WRITE   - assert write request, transition to WAIT_WRITE
--   WAIT_WRITE  - wait for m_ack, increment addresses, check count
--   DONE        - set done flag, assert IRQ if enabled, check auto-reload
--
-- Bus Arbitration:
--   A priority encoder grants the shared DMA master bus to the lowest-indexed
--   channel that is actively requesting (in REQ_READ, WAIT_READ, REQ_WRITE,
--   or WAIT_WRITE state).
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dma_controller is
    generic (
        NUM_CHANNELS : integer := 4;
        DATA_WIDTH   : integer := 32;
        ADDR_WIDTH   : integer := 32
    );
    port (
        -- AHB-Lite slave interface
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;
        HSEL      : in  std_logic;
        HWRITE    : in  std_logic;
        HREADY    : in  std_logic;
        HTRANS    : in  std_logic_vector(1 downto 0);
        HSIZE     : in  std_logic_vector(2 downto 0);
        HADDR     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        HWDATA    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        HRDATA    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        HRESP     : out std_logic;            -- 0=OKAY, 1=ERROR
        HREADYOUT : out std_logic;

        -- DMA bus master interface (memory transfers)
        m_addr  : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        m_rdata : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        m_wdata : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_we    : out std_logic;
        m_req   : out std_logic;
        m_ack   : in  std_logic;

        -- Per-channel interrupt outputs
        dma_int : out std_logic_vector(NUM_CHANNELS-1 downto 0);

        -- External DMA request inputs (peripheral-triggered)
        dma_req_in : in std_logic_vector(NUM_CHANNELS-1 downto 0)
    );
end entity dma_controller;

architecture rtl of dma_controller is

    -- ---- Sub-register select constants (HADDR[3:2]) ----
    constant REG_CTRL       : std_logic_vector(1 downto 0) := "00"; -- offset 0x00
    constant REG_SRC_ADDR   : std_logic_vector(1 downto 0) := "01"; -- offset 0x04
    constant REG_DST_ADDR   : std_logic_vector(1 downto 0) := "10"; -- offset 0x08
    constant REG_COUNT      : std_logic_vector(1 downto 0) := "11"; -- offset 0x0C

    -- ---- Global register select (HADDR[7:4] = 0x4) ----
    constant REG_STATUS     : std_logic_vector(1 downto 0) := "00"; -- offset 0x40
    constant REG_IRQ_STATUS : std_logic_vector(1 downto 0) := "01"; -- offset 0x44
    constant REG_IRQ_CLEAR  : std_logic_vector(1 downto 0) := "10"; -- offset 0x48

    -- ---- DMA_CTRL bit positions ----
    constant CTRL_ENABLE_BIT      : integer := 0;
    constant CTRL_IRQ_EN_BIT      : integer := 1;
    constant CTRL_AUTO_RELOAD_BIT : integer := 2;
    constant CTRL_START_BIT       : integer := 3;
    constant CTRL_DONE_BIT        : integer := 4;
    constant CTRL_BUSY_BIT        : integer := 5;

    -- ---- Channel FSM state type ----
    type state_type is (IDLE, REQ_READ, WAIT_READ, REQ_WRITE, WAIT_WRITE, DONE);

    -- ---- Array type definitions ----
    type slv_array    is array (0 to NUM_CHANNELS-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    type unsigned_arr is array (0 to NUM_CHANNELS-1) of unsigned(DATA_WIDTH-1 downto 0);
    type state_array  is array (0 to NUM_CHANNELS-1) of state_type;

    -- ---- Per-channel control bit registers ----
    signal ctrl_en          : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');
    signal ctrl_irq_en      : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');
    signal ctrl_auto_reload : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');
    signal ctrl_done        : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');
    signal ctrl_busy        : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');
    signal start_req        : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');

    -- ---- Per-channel address / count configuration registers ----
    signal src_addr_reg : slv_array := (others => (others => '0'));
    signal dst_addr_reg : slv_array := (others => (others => '0'));
    signal count_reg    : slv_array := (others => (others => '0'));

    -- ---- Per-channel runtime state ----
    signal cur_src   : slv_array    := (others => (others => '0'));
    signal cur_dst   : slv_array    := (others => (others => '0'));
    signal cur_count : unsigned_arr := (others => (others => '0'));
    signal data_buf  : slv_array    := (others => (others => '0'));
    signal state_reg : state_array  := (others => IDLE);

    -- ---- Global IRQ pending register ----
    signal irq_pending : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');

    -- ---- Address decode helpers ----
    signal chan_idx   : integer range 0 to 15;
    signal reg_sel    : std_logic_vector(1 downto 0);
    signal is_global  : std_logic;
    signal write_en   : std_logic;
    signal read_en    : std_logic;
    signal valid_addr : std_logic;

    -- ---- Bus arbiter ----
    signal grant_idx   : integer range 0 to NUM_CHANNELS-1 := 0;
    signal grant_valid : std_logic := '0';

begin

    -- ------------------------------------------------------------------------
    -- Address decode
    --   HADDR[7:4] = channel index (0..NUM_CHANNELS-1) or 0x4 for global regs
    --   HADDR[3:2] = sub-register select
    -- ------------------------------------------------------------------------
    chan_idx   <= to_integer(unsigned(HADDR(7 downto 4)));
    reg_sel    <= HADDR(3 downto 2);
    is_global  <= '1' when HADDR(7 downto 4) = x"4" else '0';
    valid_addr <= '1' when (HSEL = '1' and (is_global = '1' or chan_idx < NUM_CHANNELS))
                         else '0';
    write_en   <= HSEL and HREADY and HWRITE;
    read_en    <= HSEL and HREADY and (not HWRITE);

    -- ------------------------------------------------------------------------
    -- Main register write + channel FSM process
    -- ------------------------------------------------------------------------
    dma_proc : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            ctrl_en          <= (others => '0');
            ctrl_irq_en      <= (others => '0');
            ctrl_auto_reload <= (others => '0');
            ctrl_done        <= (others => '0');
            ctrl_busy        <= (others => '0');
            start_req        <= (others => '0');
            src_addr_reg     <= (others => (others => '0'));
            dst_addr_reg     <= (others => (others => '0'));
            count_reg        <= (others => (others => '0'));
            cur_src          <= (others => (others => '0'));
            cur_dst          <= (others => (others => '0'));
            cur_count        <= (others => (others => '0'));
            data_buf         <= (others => (others => '0'));
            state_reg        <= (others => IDLE);
            irq_pending      <= (others => '0');
        elsif rising_edge(HCLK) then

            -- ---- AHB-Lite register write access ----
            if write_en = '1' and valid_addr = '1' then
                if is_global = '1' then
                    -- Global registers
                    case reg_sel is
                        when REG_IRQ_CLEAR =>
                            irq_pending <= irq_pending
                                and not HWDATA(NUM_CHANNELS-1 downto 0);
                        when others =>
                            null;
                    end case;
                elsif chan_idx < NUM_CHANNELS then
                    -- Per-channel registers
                    case reg_sel is
                        when REG_CTRL =>
                            ctrl_en(chan_idx)          <= HWDATA(CTRL_ENABLE_BIT);
                            ctrl_irq_en(chan_idx)      <= HWDATA(CTRL_IRQ_EN_BIT);
                            ctrl_auto_reload(chan_idx) <= HWDATA(CTRL_AUTO_RELOAD_BIT);
                            if HWDATA(CTRL_START_BIT) = '1' then
                                start_req(chan_idx) <= '1';
                            end if;
                        when REG_SRC_ADDR =>
                            src_addr_reg(chan_idx) <= HWDATA;
                        when REG_DST_ADDR =>
                            dst_addr_reg(chan_idx) <= HWDATA;
                        when REG_COUNT =>
                            count_reg(chan_idx) <= HWDATA;
                        when others =>
                            null;
                    end case;
                end if;
            end if;

            -- ---- Per-channel DMA state machines ----
            for i in 0 to NUM_CHANNELS-1 loop
                case state_reg(i) is

                    when IDLE =>
                        if (start_req(i) = '1' or dma_req_in(i) = '1')
                           and ctrl_en(i) = '1'
                           and unsigned(count_reg(i)) /= 0 then
                            cur_src(i)   <= src_addr_reg(i);
                            cur_dst(i)   <= dst_addr_reg(i);
                            cur_count(i) <= unsigned(count_reg(i));
                            ctrl_busy(i) <= '1';
                            ctrl_done(i) <= '0';
                            state_reg(i) <= REQ_READ;
                            start_req(i) <= '0';
                        end if;

                    when REQ_READ =>
                        -- Read request now visible on master bus; advance
                        state_reg(i) <= WAIT_READ;

                    when WAIT_READ =>
                        if grant_valid = '1' and grant_idx = i and m_ack = '1' then
                            data_buf(i) <= m_rdata;
                            state_reg(i) <= REQ_WRITE;
                        end if;

                    when REQ_WRITE =>
                        -- Write request now visible on master bus; advance
                        state_reg(i) <= WAIT_WRITE;

                    when WAIT_WRITE =>
                        if grant_valid = '1' and grant_idx = i and m_ack = '1' then
                            cur_src(i) <= std_logic_vector(
                                unsigned(cur_src(i)) + (DATA_WIDTH / 8));
                            cur_dst(i) <= std_logic_vector(
                                unsigned(cur_dst(i)) + (DATA_WIDTH / 8));
                            if cur_count(i) <= 1 then
                                state_reg(i) <= DONE;
                            else
                                cur_count(i) <= cur_count(i) - 1;
                                state_reg(i) <= REQ_READ;
                            end if;
                        end if;

                    when DONE =>
                        ctrl_busy(i) <= '0';
                        ctrl_done(i) <= '1';
                        if ctrl_irq_en(i) = '1' then
                            irq_pending(i) <= '1';
                        end if;
                        if ctrl_auto_reload(i) = '1' and ctrl_en(i) = '1'
                           and unsigned(count_reg(i)) /= 0 then
                            cur_src(i)   <= src_addr_reg(i);
                            cur_dst(i)   <= dst_addr_reg(i);
                            cur_count(i) <= unsigned(count_reg(i));
                            ctrl_busy(i) <= '1';
                            ctrl_done(i) <= '0';
                            state_reg(i) <= REQ_READ;
                        else
                            state_reg(i) <= IDLE;
                        end if;

                    when others =>
                        state_reg(i) <= IDLE;

                end case;
            end loop;
        end if;
    end process dma_proc;

    -- ------------------------------------------------------------------------
    -- Bus arbiter: priority encode (lowest channel index first)
    --   Grants the shared DMA master bus to the first channel that is
    --   actively requesting a read or write transfer.
    -- ------------------------------------------------------------------------
    arbiter_proc : process(state_reg)
        variable found : boolean;
    begin
        found := false;
        grant_idx   <= 0;
        grant_valid <= '0';
        for i in 0 to NUM_CHANNELS-1 loop
            if not found then
                if state_reg(i) = REQ_READ  or state_reg(i) = WAIT_READ or
                   state_reg(i) = REQ_WRITE or state_reg(i) = WAIT_WRITE then
                    grant_idx   <= i;
                    grant_valid <= '1';
                    found := true;
                end if;
            end if;
        end loop;
    end process arbiter_proc;

    -- ------------------------------------------------------------------------
    -- DMA master interface outputs
    --   Driven by the granted channel; m_we selects read vs write phase.
    -- ------------------------------------------------------------------------
    m_req   <= grant_valid;
    m_we    <= '1' when (state_reg(grant_idx) = REQ_WRITE  or
                         state_reg(grant_idx) = WAIT_WRITE) else '0';
    m_addr  <= cur_dst(grant_idx) when (state_reg(grant_idx) = REQ_WRITE  or
                                        state_reg(grant_idx) = WAIT_WRITE)
               else cur_src(grant_idx);
    m_wdata <= data_buf(grant_idx);

    -- ------------------------------------------------------------------------
    -- AHB-Lite read mux
    -- ------------------------------------------------------------------------
    ahb_read : process(all)
        variable rdata   : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable ctrl_val: std_logic_vector(DATA_WIDTH-1 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' and valid_addr = '1' then
            if is_global = '1' then
                -- Global registers
                case reg_sel is
                    when REG_STATUS =>
                        -- bit0..N-1 = done, bitN..2N-1 = busy
                        for i in 0 to NUM_CHANNELS-1 loop
                            rdata(i)                  := ctrl_done(i);
                            rdata(i + NUM_CHANNELS)   := ctrl_busy(i);
                        end loop;
                    when REG_IRQ_STATUS =>
                        for i in 0 to NUM_CHANNELS-1 loop
                            rdata(i) := irq_pending(i);
                        end loop;
                    when others =>
                        rdata := (others => '0');
                end case;
            elsif chan_idx < NUM_CHANNELS then
                -- Per-channel registers
                case reg_sel is
                    when REG_CTRL =>
                        ctrl_val := (others => '0');
                        ctrl_val(CTRL_ENABLE_BIT)      := ctrl_en(chan_idx);
                        ctrl_val(CTRL_IRQ_EN_BIT)      := ctrl_irq_en(chan_idx);
                        ctrl_val(CTRL_AUTO_RELOAD_BIT) := ctrl_auto_reload(chan_idx);
                        ctrl_val(CTRL_DONE_BIT)        := ctrl_done(chan_idx);
                        ctrl_val(CTRL_BUSY_BIT)        := ctrl_busy(chan_idx);
                        rdata := ctrl_val;
                    when REG_SRC_ADDR =>
                        rdata := src_addr_reg(chan_idx);
                    when REG_DST_ADDR =>
                        rdata := dst_addr_reg(chan_idx);
                    when REG_COUNT =>
                        rdata := count_reg(chan_idx);
                    when others =>
                        rdata := (others => '0');
                end case;
            end if;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    -- HRESP: error for invalid address, OKAY otherwise
    HRESP     <= '1' when (HSEL = '1' and valid_addr = '0') else '0';
    HREADYOUT <= '1';  -- always one-cycle response

    -- ------------------------------------------------------------------------
    -- Per-channel interrupt outputs
    --   Interrupt fires when IRQ is pending and interrupt enable is set.
    -- ------------------------------------------------------------------------
    dma_int <= irq_pending and ctrl_irq_en;

end architecture rtl;
