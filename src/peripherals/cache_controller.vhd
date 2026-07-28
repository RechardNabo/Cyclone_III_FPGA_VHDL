-- ================================================================================
-- cache_controller : Direct-Mapped I-Cache/D-Cache with AHB-Lite slave interface
-- ================================================================================
-- Direct-mapped cache, 4KB default (128 lines x 32 bytes). Write-through policy.
-- Generics: CACHE_LINES=128, LINE_SIZE=32
-- Register Map:
--   0x00 CTRL  - bit0=enable, bit1=write_thru
--   0x04 STAT  - bit0=hit, bit1=miss, bit2=flushing (RO)
--   0x08 HIT_COUNT  - hit counter (RO, write to clear)
--   0x0C MISS_COUNT - miss counter (RO, write to clear)
--   0x10 FLUSH - write any value to flush (WO)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cache_controller is
    generic (
        CACHE_LINES : integer := 128;
        LINE_SIZE   : integer := 32
    );
    port (
        -- AHB-Lite slave interface (CPU side)
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

        -- Memory-side interface (backing store)
        cpu_addr  : out std_logic_vector(31 downto 0);
        cpu_wdata : out std_logic_vector(31 downto 0);
        cpu_rdata : in  std_logic_vector(31 downto 0);
        cpu_req   : out std_logic;
        cpu_we    : out std_logic;
        cpu_ack   : in  std_logic
    );
end entity cache_controller;

architecture rtl of cache_controller is
    constant CACHE_CTRL   : std_logic_vector(3 downto 0) := "0000";
    constant CACHE_STAT   : std_logic_vector(3 downto 0) := "0001";
    constant CACHE_HIT    : std_logic_vector(3 downto 0) := "0010";
    constant CACHE_MISS   : std_logic_vector(3 downto 0) := "0011";
    constant CACHE_FLUSH  : std_logic_vector(3 downto 0) := "0100";

    constant LINE_BITS  : integer := 5;  -- log2(32)
    constant INDEX_BITS : integer := 7;  -- log2(128)
    constant TAG_BITS   : integer := 32 - LINE_BITS - INDEX_BITS;

    signal ctrl_reg     : std_logic_vector(31 downto 0) := (0 => '1', others => '0');
    signal hit_count    : unsigned(31 downto 0) := (others => '0');
    signal miss_count   : unsigned(31 downto 0) := (others => '0');
    signal last_hit     : std_logic := '0';
    signal last_miss    : std_logic := '0';
    signal flushing     : std_logic := '0';
    signal flush_idx    : integer range 0 to CACHE_LINES-1 := 0;

    type tag_array_t is array (0 to CACHE_LINES-1) of
        std_logic_vector(TAG_BITS-1 downto 0);
    type valid_array_t is array (0 to CACHE_LINES-1) of std_logic;
    type data_array_t is array (0 to CACHE_LINES-1) of std_logic_vector(31 downto 0);

    signal tag_arr   : tag_array_t := (others => (others => '0'));
    signal valid_arr : valid_array_t := (others => '0');
    signal data_arr  : data_array_t := (others => (others => '0'));

    signal reg_sel    : std_logic_vector(3 downto 0);
    signal write_en   : std_logic;
    signal read_en    : std_logic;

    type state_t is (IDLE, MISS_FETCH, MISS_WAIT, FLUSH_STATE);
    signal state : state_t := IDLE;

    signal req_addr    : std_logic_vector(31 downto 0) := (others => '0');
    signal req_wdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal req_we      : std_logic := '0';

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HRESP <= '0';

    -- req_addr[4:0]=word offset, [11:5]=index, [31:12]=tag
    cpu_addr  <= req_addr;
    cpu_wdata <= req_wdata;
    cpu_we    <= req_we;

    -- Cache FSM
    cache_fsm : process(HCLK)
        variable idx : integer range 0 to CACHE_LINES-1;
        variable tag : std_logic_vector(TAG_BITS-1 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                state       <= IDLE;
                flushing    <= '0';
                flush_idx   <= 0;
                HREADYOUT   <= '1';
                cpu_req     <= '0';
                req_we      <= '0';
                for i in 0 to CACHE_LINES-1 loop
                    valid_arr(i) <= '0';
                end loop;
            elsif ctrl_reg(0) = '1' then
                case state is
                    when IDLE =>
                        HREADYOUT <= '1';
                        if flushing = '1' then
                            state <= FLUSH_STATE;
                            HREADYOUT <= '0';
                        elsif read_en = '1' then
                            idx := to_integer(unsigned(HADDR(11 downto 5)));
                            tag := HADDR(31 downto 12);
                            if valid_arr(idx) = '1' and tag_arr(idx) = tag then
                                -- Cache hit
                                last_hit  <= '1';
                                last_miss <= '0';
                                hit_count <= hit_count + 1;
                            else
                                -- Cache miss: fetch from backing store
                                last_hit  <= '0';
                                last_miss <= '1';
                                miss_count <= miss_count + 1;
                                req_addr  <= HADDR;
                                req_we    <= '0';
                                cpu_req   <= '1';
                                state     <= MISS_FETCH;
                                HREADYOUT <= '0';
                            end if;
                        elsif write_en = '1' then
                            idx := to_integer(unsigned(HADDR(11 downto 5)));
                            tag := HADDR(31 downto 12);
                            -- Write-through: always write to backing store
                            req_addr  <= HADDR;
                            req_wdata <= HWDATA;
                            req_we    <= '1';
                            cpu_req   <= '1';
                            state     <= MISS_WAIT;
                            HREADYOUT <= '0';
                            -- Update cache if hit
                            if valid_arr(idx) = '1' and tag_arr(idx) = tag then
                                data_arr(idx) <= HWDATA;
                            end if;
                        end if;

                    when MISS_FETCH =>
                        cpu_req <= '0';
                        if cpu_ack = '1' then
                            idx := to_integer(unsigned(req_addr(11 downto 5)));
                            tag_arr(idx)   <= req_addr(31 downto 12);
                            valid_arr(idx) <= '1';
                            data_arr(idx)  <= cpu_rdata;
                            last_hit       <= '1';
                            last_miss      <= '0';
                            state          <= IDLE;
                            HREADYOUT      <= '1';
                        end if;

                    when MISS_WAIT =>
                        cpu_req <= '0';
                        if cpu_ack = '1' then
                            state     <= IDLE;
                            HREADYOUT <= '1';
                        end if;

                    when FLUSH_STATE =>
                        valid_arr(flush_idx) <= '0';
                        if flush_idx = CACHE_LINES-1 then
                            flushing  <= '0';
                            flush_idx <= 0;
                            state     <= IDLE;
                            HREADYOUT <= '1';
                        else
                            flush_idx <= flush_idx + 1;
                        end if;
                end case;
            else
                HREADYOUT <= '1';
                state     <= IDLE;
            end if;
        end if;
    end process cache_fsm;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg <= (0 => '1', others => '0');
            elsif write_en = '1' and state = IDLE then
                case reg_sel is
                    when CACHE_CTRL =>
                        ctrl_reg <= HWDATA;
                    when CACHE_HIT =>
                        if HWDATA(0) = '1' then
                            hit_count <= (others => '0');
                        end if;
                    when CACHE_MISS =>
                        if HWDATA(0) = '1' then
                            miss_count <= (others => '0');
                        end if;
                    when CACHE_FLUSH =>
                        flushing  <= '1';
                        flush_idx <= 0;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, last_hit, last_miss, flushing,
                       hit_count, miss_count, data_arr, HADDR, state)
        variable idx : integer range 0 to CACHE_LINES-1;
    begin
        case reg_sel is
            when CACHE_CTRL =>
                HRDATA <= ctrl_reg;
            when CACHE_STAT =>
                HRDATA <= (0 => last_hit, 1 => last_miss,
                           2 => flushing, others => '0');
            when CACHE_HIT =>
                HRDATA <= std_logic_vector(hit_count);
            when CACHE_MISS =>
                HRDATA <= std_logic_vector(miss_count);
            when others =>
                -- Direct cache data read
                idx := to_integer(unsigned(HADDR(11 downto 5)));
                HRDATA <= data_arr(idx);
        end case;
    end process reg_read;

end architecture rtl;
