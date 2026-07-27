-- ============================================================================
-- Synchronous FIFO (First-In, First-Out) Buffer
-- ============================================================================
-- A FIFO is a memory buffer where the first data written in is the first
-- data read out (like a queue at a ticket counter). This is a synchronous
-- FIFO, meaning all operations happen on the rising edge of a single clock.
--
-- Key concepts:
--   * write_en  : When high, data on 'din' is stored at the write pointer.
--   * read_en   : When high, data at the read pointer is sent to 'dout'.
--   * full      : High when the buffer cannot accept more data.
--   * empty     : High when the buffer has no data to read.
--   * Pointers  : Two counters track where to write next and where to read next.
--
-- Generics let you change the data WIDTH (bits) and DEPTH (number of slots).
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fifo is
    generic (
        WIDTH : integer := 8;   -- bits per data word
        DEPTH : integer := 16   -- number of words stored
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;                      -- active-high synchronous reset
        write_en: in  std_logic;                      -- write enable
        read_en : in  std_logic;                      -- read enable
        din     : in  std_logic_vector(WIDTH-1 downto 0);
        dout    : out std_logic_vector(WIDTH-1 downto 0);
        full    : out std_logic;
        empty   : out std_logic
    );
end entity fifo;

architecture rtl of fifo is

    -- Memory storage: an array of DEPTH words, each WIDTH bits wide
    type mem_array is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
    signal memory : mem_array;

    -- Pointer width must be big enough to count 0..DEPTH (so we use DEPTH bits)
    constant PTR_W : integer := 5; -- enough for default DEPTH=16 (0..31)

    signal wr_ptr : integer range 0 to DEPTH-1 := 0;  -- next write location
    signal rd_ptr : integer range 0 to DEPTH-1 := 0;  -- next read location
    signal count  : integer range 0 to DEPTH := 0;    -- how many words stored

    signal full_i  : std_logic := '0';
    signal empty_i : std_logic := '1';

begin

    -- Drive the output flags
    full  <= full_i;
    empty <= empty_i;

    -- Combinational flag values based on the current count
    full_i  <= '1' when count = DEPTH else '0';
    empty_i <= '1' when count = 0     else '0';

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset everything to a clean empty state
                wr_ptr <= 0;
                rd_ptr <= 0;
                count  <= 0;
            else
                -- WRITE: only when enabled and space is available
                if (write_en = '1') and (full_i = '0') then
                    memory(wr_ptr) <= din;
                    -- Advance write pointer, wrap around at DEPTH
                    if wr_ptr = DEPTH-1 then
                        wr_ptr <= 0;
                    else
                        wr_ptr <= wr_ptr + 1;
                    end if;
                end if;

                -- READ: only when enabled and data is available
                if (read_en = '1') and (empty_i = '0') then
                    dout <= memory(rd_ptr);
                    -- Advance read pointer, wrap around at DEPTH
                    if rd_ptr = DEPTH-1 then
                        rd_ptr <= 0;
                    else
                        rd_ptr <= rd_ptr + 1;
                    end if;
                end if;

                -- Update the count of stored words
                -- Simultaneous read+write keeps count the same
                if (write_en = '1') and (full_i = '0') and
                   (read_en = '0' or empty_i = '1') then
                    count <= count + 1;
                elsif (read_en = '1') and (empty_i = '0') and
                      (write_en = '0' or full_i = '1') then
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
