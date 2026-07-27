-- ============================================================================
-- Read-Only Memory (ROM)
-- ============================================================================
-- A ROM stores fixed data that cannot be changed after the FPGA is
-- configured. It is commonly used for lookup tables, constants, and
-- instruction code. You give it an address, and it returns the value
-- stored at that address.
--
-- Key concepts:
--   * address : Selects which stored word to read.
--   * data    : The fixed value stored at that address.
--   * Clocked : The output updates on the rising edge of clk.
--
-- The contents are defined by a constant array, so they are baked into
-- the hardware at synthesis time. Generics let you change the data WIDTH
-- (bits) and DEPTH (number of words).
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rom is
    generic (
        WIDTH : integer := 8;   -- bits per data word
        DEPTH : integer := 16   -- number of words stored
    );
    port (
        clk     : in  std_logic;
        addr    : in  std_logic_vector(3 downto 0);   -- address to read
        dout    : out std_logic_vector(WIDTH-1 downto 0)  -- data output
    );
end entity rom;

architecture rtl of rom is

    -- Memory storage type: an array of DEPTH words, each WIDTH bits wide
    type mem_array is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);

    -- Constant array holds the fixed ROM contents (initialized at synthesis)
    constant rom_data : mem_array := (
        0  => x"00",
        1  => x"01",
        2  => x"02",
        3  => x"03",
        4  => x"04",
        5  => x"05",
        6  => x"06",
        7  => x"07",
        8  => x"08",
        9  => x"09",
        10 => x"0A",
        11 => x"0B",
        12 => x"0C",
        13 => x"0D",
        14 => x"0E",
        15 => x"0F"
    );

begin

    process (clk)
        variable idx : integer;
    begin
        if rising_edge(clk) then
            -- Convert the address vector into an integer index
            idx := to_integer(unsigned(addr));

            if idx >= 0 and idx < DEPTH then
                -- Output the fixed value stored at this address
                dout <= rom_data(idx);
            else
                dout <= (others => '0');
            end if;
        end if;
    end process;

end architecture rtl;
