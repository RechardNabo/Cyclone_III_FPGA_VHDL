-- ============================================================================
-- Single-Port RAM
-- ============================================================================
-- A single-port RAM has one access port used for both reading and writing.
-- You cannot read and write at the same time; the 'we' (write-enable) signal
-- decides which operation happens on each clock edge.
--
-- Key concepts:
--   * address : Selects which memory slot (word) to access.
--   * data    : The value stored at an address.
--   * we      : Write-enable. When high, 'din' is stored at 'addr'.
--               When low, the value at 'addr' is sent to 'dout'.
--   * Clocked : All reads and writes happen on the rising edge of clk.
--
-- Generics let you change the data WIDTH (bits) and DEPTH (number of words).
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ram_single_port is
    generic (
        WIDTH : integer := 8;    -- bits per data word
        DEPTH : integer := 256   -- number of words stored
    );
    port (
        clk     : in  std_logic;
        we      : in  std_logic;                      -- write enable (1=write, 0=read)
        addr    : in  std_logic_vector(7 downto 0);   -- address to access
        din     : in  std_logic_vector(WIDTH-1 downto 0);  -- data to write
        dout    : out std_logic_vector(WIDTH-1 downto 0)   -- data read out
    );
end entity ram_single_port;

architecture rtl of ram_single_port is

    -- Memory storage: an array of DEPTH words, each WIDTH bits wide
    type mem_array is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
    signal memory : mem_array;

begin

    process (clk)
        variable idx : integer;
    begin
        if rising_edge(clk) then
            -- Convert the address vector into an integer index
            idx := to_integer(unsigned(addr));

            if idx >= 0 and idx < DEPTH then
                if we = '1' then
                    -- WRITE: store input data at the addressed location
                    memory(idx) <= din;
                else
                    -- READ: output the value stored at the addressed location
                    dout <= memory(idx);
                end if;
            else
                dout <= (others => '0');
            end if;
        end if;
    end process;

end architecture rtl;
