-- ================================================================================
-- bitband_controller : Bit-banding region controller with AHB-Lite slave interface
-- ================================================================================
-- ARM Cortex-M bit-banding support. Maps a 32MB alias region to a 1MB bit-band
-- region, allowing single-bit atomic access via the alias.
--
-- Address transformation:
--   alias_addr[31:0] -> bit_word_offset = alias_addr[22:2] (5 bits -> 32MB/4)
--   byte_addr = bit_band_base + (bit_word_offset / 32) * 4
--   bit_pos   = (bit_word_offset mod 32)
--   write: bb_wdata = 0x00000001 << bit_pos  (or 0 if writing 0)
--   read:   bb_rdata = (byte_value >> bit_pos) & 1 ? 1 : 0
--
-- Register Map:
--   0x00: CTRL  - bit0=enable, bit[31:12]=bit_band_base[31:12]
--   0x04: STAT  - bit0=busy, bit1=error
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity bitband_controller is
    port (
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;
        HSEL      : in  std_logic;
        HWRITE    : in  std_logic;
        HREADY    : in  std_logic;
        HTRANS    : in  std_logic_vector(1 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;
        HREADYOUT : out std_logic;

        -- Bit-band memory interface (to underlying SRAM/peripheral)
        bb_addr   : out std_logic_vector(31 downto 0);
        bb_rdata  : in  std_logic_vector(31 downto 0);
        bb_wdata  : out std_logic_vector(31 downto 0);
        bb_we     : out std_logic;
        bb_strobe : out std_logic
    );
end entity bitband_controller;

architecture rtl of bitband_controller is
    signal ctrl_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal stat_busy  : std_logic := '0';

    -- Alias address latched from AHB
    signal alias_addr : std_logic_vector(31 downto 0) := (others => '0');
    signal alias_wdata: std_logic_vector(31 downto 0) := (others => '0');
    signal alias_write: std_logic := '0';

    -- Computed transform
    signal bit_word_offset : unsigned(20 downto 0);  -- 21 bits
    signal byte_addr       : unsigned(31 downto 0);
    signal bit_pos         : integer range 0 to 31;

    -- State machine
    type state_t is (IDLE, READ_WAIT, WRITE_WAIT, DONE);
    signal state : state_t := IDLE;

    signal reg_sel     : std_logic_vector(2 downto 0);
    signal write_en    : std_logic;

begin
    reg_sel  <= HADDR(4 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    HREADYOUT <= '1' when state = IDLE else '0';
    HRESP     <= '0';

    -- Address transformation
    -- alias_addr[22:2] = bit_word_offset (21 bits)
    bit_word_offset <= unsigned(alias_addr(22 downto 2));
    -- byte_addr = bit_band_base + (offset / 32) * 4
    -- base = ctrl_reg(31:12) & 12 zeros (32 bits), offset part = offset[20:5] & "00" (18 bits)
    byte_addr <= (unsigned(ctrl_reg(31 downto 12)) & "000000000000") +
                 resize(unsigned(bit_word_offset(20 downto 5)) & "00", 32);
    -- bit_pos = offset mod 32 = offset[4:0]
    bit_pos <= to_integer(bit_word_offset(4 downto 0));

    -- Main state machine
    bb_proc : process(HCLK)
        variable mask : unsigned(31 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                state      <= IDLE;
                ctrl_reg   <= (others => '0');
                stat_busy  <= '0';
                alias_addr <= (others => '0');
                alias_wdata<= (others => '0');
                alias_write<= '0';
                bb_we      <= '0';
                bb_strobe  <= '0';
                bb_wdata   <= (others => '0');
                bb_addr    <= (others => '0');
            else
                bb_we     <= '0';
                bb_strobe <= '0';

                case state is
                    when IDLE =>
                        if write_en = '1' then
                            case reg_sel is
                                when "000" => ctrl_reg <= HWDATA;
                                when "001" => stat_busy <= '0';  -- write clears
                                when others => null;
                            end case;
                        end if;

                        if ctrl_reg(0) = '1' and HSEL = '1' and
                           (HTRANS(0) or HTRANS(1)) = '1' and HREADY = '1' and
                           unsigned(reg_sel) >= 2 then
                            -- Alias region access (reg_sel >= 2 means addr >= 0x08)
                            alias_addr  <= HADDR;
                            alias_wdata <= HWDATA;
                            alias_write <= HWRITE;
                            if HWRITE = '1' then
                                state <= WRITE_WAIT;
                            else
                                state <= READ_WAIT;
                            end if;
                        end if;

                    when READ_WAIT =>
                        bb_addr   <= std_logic_vector(byte_addr);
                        bb_strobe <= '1';
                        state     <= DONE;

                    when WRITE_WAIT =>
                        -- For write: value 0 -> clear bit, nonzero -> set bit
                        bb_addr   <= std_logic_vector(byte_addr);
                        bb_strobe <= '1';
                        -- Read-modify-write: first read
                        state <= DONE;

                    when DONE =>
                        if alias_write = '1' then
                            -- Modify bit and write back
                            mask := (others => '0');
                            mask(bit_pos) := '1';
                            if alias_wdata(0) = '1' then
                                bb_wdata <= std_logic_vector(unsigned(bb_rdata) or mask);
                            else
                                bb_wdata <= std_logic_vector(unsigned(bb_rdata) and not mask);
                            end if;
                            bb_we <= '1';
                        end if;
                        state <= IDLE;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process bb_proc;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, stat_busy, bb_rdata, bit_pos, state)
        variable bit_val : std_logic;
    begin
        case reg_sel is
            when "000" => HRDATA <= ctrl_reg;
            when "001" => HRDATA <= (0 => stat_busy, others => '0');
            when others =>
                -- Alias read returns 0x00000001 or 0x00000000
                if state = DONE and alias_write = '0' then
                    bit_val := bb_rdata(bit_pos);
                    HRDATA <= (0 => bit_val, others => '0');
                else
                    HRDATA <= (others => '0');
                end if;
        end case;
    end process reg_read;

    stat_busy <= '0' when state = IDLE else '1';

end architecture rtl;
