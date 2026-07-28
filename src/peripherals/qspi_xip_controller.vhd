-- ================================================================================
-- qspi_xip_controller : RP2040-style QSPI flash with Execute-In-Place (XIP)
-- ================================================================================
-- Implements a QSPI flash controller with XIP cache:
--   * 4-wire SPI/QSPI interface to external flash
--   * 16-byte (4-word) cache line for XIP
--   * Configurable clock divider
--   * Supports standard SPI, dual, and quad I/O modes
--   * AHB-Lite slave for register access + memory-mapped flash
--
-- AHB-Lite register map:
--   0x00 : CTRL     - Control register (enable, mode, clkdiv)
--   0x04 : STAT     - Status register (busy, cache hit/miss)
--   0x08 : FLASH_CMD - Direct flash command register
--   0x0C : FLASH_ADDR- Direct flash address register
--   0x10 : FLASH_DATA- Direct flash data register
--   0x14 : CACHE_CTRL- Cache control (enable, flush)
--   0x18 : CACHE_STAT- Cache status (hit count, miss count)
--
-- Memory-mapped region: HADDR[31:28] = 0x1 (XIP region 0x10000000)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity qspi_xip_controller is
    port (
        -- AHB-Lite slave interface (registers + XIP)
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;
        HSEL      : in  std_logic;
        HWRITE    : in  std_logic;
        HREADY    : in  std_logic;
        HTRANS    : in  std_logic_vector(1 downto 0);
        HSIZE     : in  std_logic_vector(2 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;
        HREADYOUT : out std_logic;

        -- QSPI flash interface
        qspi_clk   : out std_logic;
        qspi_cs_n  : out std_logic;
        qspi_dq    : inout std_logic_vector(3 downto 0);  -- 4 data lines (IO0-IO3)

        -- Interrupt
        qspi_int   : out std_logic
    );
end entity qspi_xip_controller;

architecture rtl of qspi_xip_controller is

    -- Control register bits
    signal ctrl_enable   : std_logic := '0';
    signal ctrl_mode     : std_logic_vector(1 downto 0) := "00";  -- 00=SPI, 01=Dual, 10=Quad
    signal ctrl_clkdiv   : unsigned(7 downto 0) := to_unsigned(2, 8);

    -- Status
    signal stat_busy     : std_logic := '0';
    signal stat_cache_hit  : std_logic := '0';
    signal stat_cache_miss : std_logic := '0';

    -- Direct command interface
    signal flash_cmd     : std_logic_vector(7 downto 0) := x"00";
    signal flash_addr    : std_logic_vector(23 downto 0) := (others => '0');
    signal flash_data_reg: std_logic_vector(31 downto 0) := (others => '0');
    signal flash_data_in : std_logic_vector(31 downto 0) := (others => '0');

    -- Cache (4-entry, 32-bit per line = 16 bytes total)
    constant CACHE_DEPTH : integer := 4;
    type cache_tag_t  is array(0 to CACHE_DEPTH-1) of std_logic_vector(23 downto 0);
    type cache_data_t is array(0 to CACHE_DEPTH-1) of std_logic_vector(31 downto 0);
    signal cache_tags    : cache_tag_t  := (others => (others => '1'));  -- invalid
    signal cache_data    : cache_data_t := (others => (others => '0'));
    signal cache_valid   : std_logic_vector(CACHE_DEPTH-1 downto 0) := (others => '0');
    signal cache_lru_ptr : integer range 0 to CACHE_DEPTH-1 := 0;

    -- QSPI state machine
    type qspi_state_t is (IDLE, SEND_CMD, SEND_ADDR, READ_DUMMY, READ_DATA,
                          WRITE_DATA, WAIT_CYCLES, DONE);
    signal qspi_state : qspi_state_t := IDLE;
    signal qspi_clk_reg : std_logic := '0';
    signal qspi_cs_reg  : std_logic := '1';
    signal qspi_clk_cnt : integer range 0 to 255 := 0;
    signal qspi_bit_cnt : integer range 0 to 31 := 0;
    signal qspi_byte_cnt: integer range 0 to 7 := 0;
    signal qspi_shift_out : std_logic_vector(31 downto 0) := (others => '0');
    signal qspi_shift_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal qspi_target_addr : std_logic_vector(23 downto 0) := (others => '0');
    signal qspi_read_data  : std_logic_vector(31 downto 0) := (others => '0');

    -- Address decode
    signal reg_offset : std_logic_vector(7 downto 0);
    signal is_xip_access : std_logic;
    signal write_en : std_logic;
    signal cache_hit : std_logic;
    signal cache_idx : integer range 0 to CACHE_DEPTH-1;

    -- Hit/miss counters
    signal hit_count  : unsigned(15 downto 0) := (others => '0');
    signal miss_count : unsigned(15 downto 0) := (others => '0');

    -- Cache flush trigger (set by ahb_write, consumed by qspi_fsm)
    signal cache_flush : std_logic := '0';

begin

    reg_offset <= HADDR(9 downto 2);
    is_xip_access <= '1' when HADDR(31 downto 28) = x"1" else '0';
    write_en <= HSEL and HREADY and HWRITE;

    -- Cache lookup (combinational)
    cache_lookup : process(HADDR, cache_tags, cache_valid)
        variable found : boolean;
        variable idx : integer;
    begin
        found := false;
        idx := 0;
        for i in 0 to CACHE_DEPTH-1 loop
            if cache_valid(i) = '1' and cache_tags(i) = HADDR(25 downto 2) then
                found := true;
                idx := i;
                exit;
            end if;
        end loop;
        if found then
            cache_hit <= '1';
            cache_idx <= idx;
        else
            cache_hit <= '0';
            cache_idx <= 0;
        end if;
    end process;

    -- ========================================================================
    -- AHB-Lite register write
    -- ========================================================================
    ahb_write : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            ctrl_enable <= '0';
            ctrl_mode   <= "00";
            ctrl_clkdiv <= to_unsigned(2, 8);
            flash_cmd   <= x"00";
            flash_addr  <= (others => '0');
            flash_data_reg <= (others => '0');
            hit_count  <= (others => '0');
            miss_count <= (others => '0');
            cache_flush <= '0';
        elsif rising_edge(HCLK) then
            cache_flush <= '0';  -- default
            if write_en = '1' and is_xip_access = '0' then
                case reg_offset is
                    when x"00" =>  -- CTRL
                        ctrl_enable <= HWDATA(0);
                        ctrl_mode   <= HWDATA(2 downto 1);
                        ctrl_clkdiv <= unsigned(HWDATA(15 downto 8));
                    when x"08" =>  -- FLASH_CMD
                        flash_cmd <= HWDATA(7 downto 0);
                    when x"0C" =>  -- FLASH_ADDR
                        flash_addr <= HWDATA(23 downto 0);
                    when x"10" =>  -- FLASH_DATA (write)
                        flash_data_reg <= HWDATA;
                    when x"14" =>  -- CACHE_CTRL
                        if HWDATA(0) = '1' then  -- flush
                            cache_flush <= '1';
                        end if;
                    when others => null;
                end case;
            end if;

            -- Update cache statistics
            if HSEL = '1' and is_xip_access = '1' and HREADY = '1' then
                if cache_hit = '1' then
                    hit_count <= hit_count + 1;
                else
                    miss_count <= miss_count + 1;
                end if;
            end if;
        end if;
    end process ahb_write;

    -- ========================================================================
    -- AHB-Lite register read + XIP read
    -- ========================================================================
    ahb_read : process(HSEL, HADDR, reg_offset, is_xip_access, ctrl_enable, ctrl_mode,
                        ctrl_clkdiv, stat_busy, flash_data_in, flash_cmd, flash_addr,
                        flash_data_reg, hit_count, miss_count, cache_data, cache_hit,
                        cache_idx, qspi_read_data)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            if is_xip_access = '1' then
                -- XIP memory-mapped read
                if cache_hit = '1' then
                    rdata := cache_data(cache_idx);
                else
                    -- Return data from QSPI read (if available)
                    rdata := qspi_read_data;
                end if;
            else
                case reg_offset is
                    when x"00" =>  -- CTRL
                        rdata(0) := ctrl_enable;
                        rdata(2 downto 1) := ctrl_mode;
                        rdata(15 downto 8) := std_logic_vector(ctrl_clkdiv);
                    when x"04" =>  -- STAT
                        rdata(0) := stat_busy;
                        rdata(1) := stat_cache_hit;
                        rdata(2) := stat_cache_miss;
                    when x"08" =>  -- FLASH_CMD
                        rdata(7 downto 0) := flash_cmd;
                    when x"0C" =>  -- FLASH_ADDR
                        rdata(23 downto 0) := flash_addr;
                    when x"10" =>  -- FLASH_DATA (read)
                        rdata := flash_data_in;
                    when x"18" =>  -- CACHE_STAT
                        rdata(15 downto 0)  := std_logic_vector(hit_count);
                        rdata(31 downto 16) := std_logic_vector(miss_count);
                    when others => null;
                end case;
            end if;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    -- ========================================================================
    -- QSPI state machine
    -- ========================================================================
    qspi_fsm : process(HCLK, HRESETn)
        variable clk_div_cnt : integer;
    begin
        if HRESETn = '0' then
            qspi_state    <= IDLE;
            qspi_clk_reg  <= '0';
            qspi_cs_reg   <= '1';
            qspi_clk_cnt  <= 0;
            qspi_bit_cnt  <= 0;
            qspi_byte_cnt <= 0;
            qspi_shift_out <= (others => '0');
            qspi_shift_in  <= (others => '0');
            qspi_read_data <= (others => '0');
            stat_busy     <= '0';
            stat_cache_hit  <= '0';
            stat_cache_miss <= '0';
            cache_valid   <= (others => '0');
            cache_lru_ptr <= 0;
        elsif rising_edge(HCLK) then
            stat_cache_hit  <= cache_hit;
            stat_cache_miss <= not cache_hit;

            -- Handle cache flush from ahb_write
            if cache_flush = '1' then
                cache_valid <= (others => '0');
            end if;

            case qspi_state is
                when IDLE =>
                    qspi_cs_reg  <= '1';
                    qspi_clk_reg <= '0';
                    stat_busy    <= '0';
                    -- Start XIP read on cache miss
                    if HSEL = '1' and is_xip_access = '1' and cache_hit = '0' and ctrl_enable = '1' then
                        qspi_state      <= SEND_CMD;
                        qspi_cs_reg     <= '0';
                        qspi_clk_cnt    <= 0;
                        qspi_bit_cnt    <= 7;
                        qspi_shift_out  <= x"000000" & x"6B";  -- Quad Output Fast Read
                        qspi_target_addr <= HADDR(25 downto 2) & "00";
                        stat_busy       <= '1';
                    elsif write_en = '1' and reg_offset = x"08" then
                        -- Direct command
                        qspi_state     <= SEND_CMD;
                        qspi_cs_reg    <= '0';
                        qspi_clk_cnt   <= 0;
                        qspi_bit_cnt   <= 7;
                        qspi_shift_out <= x"000000" & flash_cmd;
                        qspi_target_addr <= flash_addr;
                        stat_busy      <= '1';
                    end if;

                when SEND_CMD =>
                    -- Send 8-bit command on IO0
                    qspi_clk_reg <= not qspi_clk_reg;
                    if qspi_clk_reg = '1' then  -- on falling edge, shift
                        if qspi_bit_cnt = 0 then
                            qspi_state   <= SEND_ADDR;
                            qspi_bit_cnt <= 23;
                            qspi_shift_out <= x"00" & qspi_target_addr;
                        else
                            qspi_bit_cnt <= qspi_bit_cnt - 1;
                            qspi_shift_out <= '0' & qspi_shift_out(31 downto 1);
                        end if;
                    end if;

                when SEND_ADDR =>
                    -- Send 24-bit address (in quad mode, 4 bits per clock)
                    qspi_clk_reg <= not qspi_clk_reg;
                    if qspi_clk_reg = '1' then
                        if ctrl_mode = "10" then  -- Quad: 6 clocks for 24 bits
                            if qspi_bit_cnt <= 3 then
                                qspi_state   <= READ_DUMMY;
                                qspi_bit_cnt <= 7;  -- 8 dummy cycles
                            else
                                qspi_bit_cnt <= qspi_bit_cnt - 4;
                                qspi_shift_out <= x"0000000" & qspi_shift_out(27 downto 0);
                            end if;
                        else  -- SPI: 24 clocks
                            if qspi_bit_cnt = 0 then
                                qspi_state   <= READ_DUMMY;
                                qspi_bit_cnt <= 7;
                            else
                                qspi_bit_cnt <= qspi_bit_cnt - 1;
                                qspi_shift_out <= '0' & qspi_shift_out(31 downto 1);
                            end if;
                        end if;
                    end if;

                when READ_DUMMY =>
                    -- Wait for dummy cycles
                    qspi_clk_reg <= not qspi_clk_reg;
                    if qspi_clk_reg = '1' then
                        if qspi_bit_cnt = 0 then
                            qspi_state   <= READ_DATA;
                            qspi_bit_cnt <= 31;
                            qspi_byte_cnt <= 3;
                        else
                            qspi_bit_cnt <= qspi_bit_cnt - 1;
                        end if;
                    end if;

                when READ_DATA =>
                    -- Read 32-bit data from flash
                    qspi_clk_reg <= not qspi_clk_reg;
                    if qspi_clk_reg = '0' then  -- sample on rising edge
                        if ctrl_mode = "10" then  -- Quad: 4 bits per clock
                            qspi_shift_in <= qspi_shift_in(27 downto 0) & qspi_dq;
                            if qspi_bit_cnt <= 3 then
                                qspi_read_data <= qspi_shift_in(27 downto 0) & qspi_dq;
                                qspi_state  <= DONE;
                            else
                                qspi_bit_cnt <= qspi_bit_cnt - 4;
                            end if;
                        else  -- SPI: 1 bit per clock
                            qspi_shift_in <= qspi_shift_in(30 downto 0) & qspi_dq(0);
                            if qspi_bit_cnt = 0 then
                                qspi_read_data <= qspi_shift_in(30 downto 0) & qspi_dq(0);
                                qspi_state  <= DONE;
                            else
                                qspi_bit_cnt <= qspi_bit_cnt - 1;
                            end if;
                        end if;
                    end if;

                when WRITE_DATA =>
                    -- Write data to flash (for direct command writes)
                    qspi_clk_reg <= not qspi_clk_reg;
                    if qspi_clk_reg = '1' then
                        if qspi_bit_cnt = 0 then
                            qspi_state <= DONE;
                        else
                            qspi_bit_cnt <= qspi_bit_cnt - 1;
                            qspi_shift_out <= '0' & qspi_shift_out(31 downto 1);
                        end if;
                    end if;

                when DONE =>
                    qspi_cs_reg  <= '1';
                    qspi_clk_reg <= '0';
                    stat_busy    <= '0';
                    -- Update cache on XIP read
                    if is_xip_access = '1' then
                        cache_data(cache_lru_ptr) <= qspi_read_data;
                        cache_tags(cache_lru_ptr) <= qspi_target_addr;
                        cache_valid(cache_lru_ptr) <= '1';
                        if cache_lru_ptr = CACHE_DEPTH-1 then
                            cache_lru_ptr <= 0;
                        else
                            cache_lru_ptr <= cache_lru_ptr + 1;
                        end if;
                    end if;
                    -- Store read data for direct command
                    flash_data_in <= qspi_read_data;
                    qspi_state    <= IDLE;

                when others =>
                    qspi_state <= IDLE;
            end case;
        end if;
    end process qspi_fsm;

    -- QSPI output signals
    qspi_clk  <= qspi_clk_reg;
    qspi_cs_n <= qspi_cs_reg;

    -- QSPI data lines (bidirectional)
    -- In SPI mode: IO0 = MOSI (out), IO1 = MISO (in)
    -- In Quad mode: all 4 lines bidirectional
    qspi_dq(0) <= qspi_shift_out(0) when qspi_cs_reg = '0' and
                                       (qspi_state = SEND_CMD or qspi_state = SEND_ADDR)
                              else 'Z';
    qspi_dq(1) <= 'Z';  -- MISO in SPI mode
    qspi_dq(2) <= qspi_shift_out(2) when qspi_cs_reg = '0' and ctrl_mode = "10" and
                                        (qspi_state = SEND_ADDR)
                              else 'Z';
    qspi_dq(3) <= qspi_shift_out(3) when qspi_cs_reg = '0' and ctrl_mode = "10" and
                                        (qspi_state = SEND_ADDR)
                              else 'Z';

    -- HREADYOUT: stall during cache miss QSPI read
    HREADYOUT <= '0' when (qspi_state /= IDLE and is_xip_access = '1') else '1';
    HRESP     <= '0';

    -- Interrupt (not used in basic mode)
    qspi_int <= '0';

end architecture rtl;
