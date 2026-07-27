-- ============================================================================
-- Dual-Port RAM
-- ============================================================================
-- A dual-port RAM has two independent access ports that share the same
-- memory storage. Port A can write data at one address while Port B reads
-- data from a different address at the same time. This is useful when two
-- circuits need to share memory without waiting on each other.
--
-- Key concepts:
--   * address : Selects which memory slot (word) to access.
--   * data    : The value stored at an address.
--   * we      : Write-enable. When high, the port stores data; when low, it reads.
--   * Clocked : All reads and writes happen on the rising edge of clk.
--
-- Generics let you change the data WIDTH (bits) and DEPTH (number of words).
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ram_dual_port is
    generic (
        WIDTH : integer := 8;    -- bits per data word
        DEPTH : integer := 256   -- number of words stored
    );
    port (
        clk     : in  std_logic;

        -- Port A (write port)
        we_a    : in  std_logic;                      -- write enable for port A
        addr_a  : in  std_logic_vector(7 downto 0);   -- address for port A
        din_a   : in  std_logic_vector(WIDTH-1 downto 0);  -- data to write

        -- Port B (read port)
        addr_b  : in  std_logic_vector(7 downto 0);   -- address for port B
        dout_b  : out std_logic_vector(WIDTH-1 downto 0)   -- data read from port B
    );
end entity ram_dual_port;

architecture rtl of ram_dual_port is

    -- Memory storage: an array of DEPTH words, each WIDTH bits wide
    type mem_array is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
    signal memory : mem_array;

begin

    process (clk)
        variable a_idx : integer;
        variable b_idx : integer;
    begin
        if rising_edge(clk) then
            -- Convert address vectors into integer indices
            a_idx := to_integer(unsigned(addr_a));
            b_idx := to_integer(unsigned(addr_b));

            -- Port A: write when enabled (guard against out-of-range)
            if we_a = '1' then
                if a_idx >= 0 and a_idx < DEPTH then
                    memory(a_idx) <= din_a;
                end if;
            end if;

            -- Port B: always reads the value at addr_b on this clock edge
            if b_idx >= 0 and b_idx < DEPTH then
                dout_b <= memory(b_idx);
            else
                dout_b <= (others => '0');
            end if;
        end if;
    end process;

end architecture rtl;
