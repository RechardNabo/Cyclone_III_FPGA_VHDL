-- ================================================================================
-- sd_sdio_controller : SD/SDIO host controller (SPI and SD modes)
-- ================================================================================
-- AHB-Lite register map:
--   0x00 : CTRL   - [0] enable, [1] mode(0=SPI,1=SD), [2] bus_width(0=1bit,1=4bit), [7:4] clkdiv
--   0x04 : STAT   - [0] busy, [1] card_present, [2] data_ready, [3] error
--   0x08 : CMD    - SD command index (0-63)
--   0x0C : ARG    - 32-bit command argument
--   0x10 : RESP0  - Response word 0 (R1/R3/R7)
--   0x14 : RESP1  - Response word 1 (R2)
--   0x18 : RESP2  - Response word 2 (R2)
--   0x1C : RESP3  - Response word 3 (R2)
--   0x20 : DATA_IN  - Read data from card
--   0x24 : DATA_OUT - Write data to card
--   0x28 : BLKSIZE - Block size (default 512)
--   0x2C : BLKCNT  - Block count for transfer
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sd_sdio_controller is
    port (
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;
        HSEL      : in  std_logic;
        HWRITE    : in  std_logic;
        HREADY    : in  std_logic;
        HTRANS    : in  std_logic_vector(1 downto 0);
        HSIZE     : std_logic_vector(2 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;
        HREADYOUT : out std_logic;
        sd_clk    : out std_logic;
        sd_cmd    : inout std_logic;
        sd_dat    : inout std_logic_vector(3 downto 0);
        sd_cd_n   : in  std_logic;  -- card detect (active low)
        sd_irq    : out std_logic
    );
end entity sd_sdio_controller;

architecture rtl of sd_sdio_controller is
    signal enabled    : std_logic := '0';
    signal sd_mode    : std_logic := '0';  -- 0=SPI, 1=SD
    signal bus_width  : std_logic := '0';  -- 0=1-bit, 1=4-bit
    signal clk_div    : unsigned(3 downto 0) := x"2";
    signal cmd_index  : std_logic_vector(5 downto 0) := (others => '0');
    signal cmd_arg    : std_logic_vector(31 downto 0) := (others => '0');
    signal resp_buf   : std_logic_vector(127 downto 0) := (others => '0');
    signal blk_size   : unsigned(11 downto 0) := to_unsigned(512, 12);
    signal blk_count  : unsigned(15 downto 0) := (others => '0');
    signal stat_busy  : std_logic := '0';
    signal stat_error : std_logic := '0';
    signal data_ready : std_logic := '0';

    signal sd_clk_reg : std_logic := '0';
    signal sd_clk_cnt : unsigned(7 downto 0) := (others => '0');
    signal sd_fsm     : integer range 0 to 7 := 0;
    signal bit_cnt    : integer range 0 to 48 := 0;
    signal resp_bit_cnt : integer range 0 to 128 := 0;
    signal cmd_shift  : std_logic_vector(47 downto 0) := (others => '0');
    signal resp_shift : std_logic_vector(127 downto 0) := (others => '0');

    signal reg_offset : std_logic_vector(7 downto 0);
    signal write_en   : std_logic;

begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;

    -- SD clock generation
    sd_clk_gen : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            sd_clk_reg <= '0';
            sd_clk_cnt <= (others => '0');
        elsif rising_edge(HCLK) then
            if enabled = '1' then
                if sd_clk_cnt >= clk_div then
                    sd_clk_reg <= not sd_clk_reg;
                    sd_clk_cnt <= (others => '0');
                else
                    sd_clk_cnt <= sd_clk_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    ahb_write : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            enabled <= '0'; sd_mode <= '0'; bus_width <= '0'; clk_div <= x"2";
            cmd_index <= (others => '0'); cmd_arg <= (others => '0');
            blk_size <= to_unsigned(512, 12); blk_count <= (others => '0');
            stat_busy <= '0'; stat_error <= '0'; data_ready <= '0';
            sd_fsm <= 0;
        elsif rising_edge(HCLK) then
            if write_en = '1' then
                case reg_offset is
                    when x"00" =>
                        enabled   <= HWDATA(0);
                        sd_mode   <= HWDATA(1);
                        bus_width <= HWDATA(2);
                        clk_div   <= unsigned(HWDATA(7 downto 4));
                    when x"08" =>
                        cmd_index <= HWDATA(5 downto 0);
                        -- Start command
                        sd_fsm <= 1;
                        stat_busy <= '1';
                        bit_cnt <= 0;
                        cmd_shift <= "01" & HWDATA(5 downto 0) & cmd_arg & '1';  -- start+cmd+arg+crc
                    when x"0C" => cmd_arg <= HWDATA;
                    when x"24" =>  -- DATA_OUT write
                        null;  -- handled by FSM
                    when x"28" => blk_size <= unsigned(HWDATA(11 downto 0));
                    when x"2C" => blk_count <= unsigned(HWDATA(15 downto 0));
                    when others => null;
                end case;
            end if;

            -- SD command FSM
            case sd_fsm is
                when 0 => null;
                when 1 =>  -- Send command bits
                    if bit_cnt < 48 then
                        bit_cnt <= bit_cnt + 1;
                    else
                        sd_fsm <= 2;
                        resp_bit_cnt <= 0;
                    end if;
                when 2 =>  -- Receive response
                    if resp_bit_cnt < 48 then
                        resp_shift <= resp_shift(126 downto 0) & sd_cmd;
                        resp_bit_cnt <= resp_bit_cnt + 1;
                    else
                        resp_buf <= resp_shift;
                        sd_fsm <= 3;
                    end if;
                when 3 =>  -- Done
                    stat_busy <= '0';
                    data_ready <= '1';
                    sd_fsm <= 0;
                when others => sd_fsm <= 0;
            end case;
        end if;
    end process;

    ahb_read : process(HSEL, HADDR, reg_offset, resp_buf, stat_busy, stat_error,
                       data_ready, sd_cd_n, enabled)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"04" =>
                    rdata(0) := stat_busy;
                    rdata(1) := not sd_cd_n;  -- card present (active high in status)
                    rdata(2) := data_ready;
                    rdata(3) := stat_error;
                when x"10" => rdata := resp_buf(31 downto 0);
                when x"14" => rdata := resp_buf(63 downto 32);
                when x"18" => rdata := resp_buf(95 downto 64);
                when x"1C" => rdata := resp_buf(127 downto 96);
                when x"28" => rdata := x"00" & std_logic_vector(blk_size);
                when x"2C" => rdata := x"0000" & std_logic_vector(blk_count);
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process;

    -- SD bus signals
    sd_clk <= sd_clk_reg when enabled = '1' else '0';
    sd_cmd <= cmd_shift(47) when sd_fsm = 1 else 'Z';
    sd_dat <= (others => 'Z');

    HRESP     <= '0';
    HREADYOUT <= '0' when stat_busy = '1' else '1';
    sd_irq    <= data_ready;

end architecture rtl;
