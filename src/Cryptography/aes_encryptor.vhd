-- ============================================================================
-- AES Encryptor - Simplified Single Round (Educational)
-- ============================================================================
-- AES (Advanced Encryption Standard) is a symmetric block cipher operating on
-- 128-bit data blocks. A full AES-128 encryption has 10 rounds, each with
-- SubBytes, ShiftRows, MixColumns, and AddRoundKey steps.
--
-- This simplified educational version performs a SINGLE round containing:
--   1. AddRoundKey  - XOR the data with the 128-bit round key
--   2. SubBytes     - Replace each byte using the AES S-Box lookup table
--
-- LEARNING CONCEPTS:
-- 1. Symmetric key encryption (same key for encrypt/decrypt)
-- 2. Substitution-permutation network structure
-- 3. The S-Box: a nonlinear byte substitution table
-- 4. Key mixing via XOR
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity aes_encryptor is
    port (
        clk          : in  std_logic;                       -- Clock
        reset        : in  std_logic;                       -- Async reset (active high)
        start        : in  std_logic;                       -- Start a single round
        data_in      : in  std_logic_vector(127 downto 0);  -- 128-bit plaintext block
        key_in       : in  std_logic_vector(127 downto 0);  -- 128-bit round key
        data_out     : out std_logic_vector(127 downto 0);  -- 128-bit encrypted block
        done         : out std_logic                        -- High when round complete
    );
end entity aes_encryptor;

architecture rtl of aes_encryptor is

    -- The AES S-Box: a 256-entry lookup table mapping each byte value (0-255)
    -- to its substitution. This is the standard FIPS-197 S-Box.
    type sbox_array is array (0 to 255) of std_logic_vector(7 downto 0);
    constant SBOX : sbox_array := (
        x"63", x"7c", x"77", x"7b", x"f2", x"6b", x"6f", x"c5",
        x"30", x"01", x"67", x"2b", x"fe", x"d7", x"ab", x"76",
        x"ca", x"82", x"c9", x"7d", x"fa", x"59", x"47", x"f0",
        x"ad", x"d4", x"a2", x"af", x"9c", x"a4", x"72", x"c0",
        x"b7", x"fd", x"93", x"26", x"36", x"3f", x"f7", x"cc",
        x"34", x"a5", x"e5", x"f1", x"71", x"d8", x"31", x"15",
        x"04", x"c7", x"23", x"c3", x"18", x"96", x"05", x"9a",
        x"07", x"12", x"80", x"e2", x"eb", x"27", x"b2", x"75",
        x"09", x"83", x"2c", x"1a", x"1b", x"6e", x"5a", x"a0",
        x"52", x"3b", x"d6", x"b3", x"29", x"e3", x"2f", x"84",
        x"53", x"d1", x"00", x"ed", x"20", x"fc", x"b1", x"5b",
        x"6a", x"cb", x"be", x"39", x"4a", x"4c", x"58", x"cf",
        x"d0", x"ef", x"aa", x"fb", x"43", x"4d", x"33", x"85",
        x"45", x"f9", x"02", x"7f", x"50", x"3c", x"9f", x"a8",
        x"51", x"a3", x"40", x"8f", x"92", x"9d", x"38", x"f5",
        x"bc", x"b6", x"da", x"21", x"10", x"ff", x"f3", x"d2",
        x"cd", x"0c", x"13", x"ec", x"5f", x"97", x"44", x"17",
        x"c4", x"a7", x"7e", x"3d", x"64", x"5d", x"19", x"73",
        x"60", x"81", x"4f", x"dc", x"22", x"2a", x"90", x"88",
        x"46", x"ee", x"b8", x"14", x"de", x"5e", x"0b", x"db",
        x"e0", x"32", x"3a", x"0a", x"49", x"06", x"24", x"5c",
        x"c2", x"d3", x"ac", x"62", x"91", x"95", x"e4", x"79",
        x"e7", x"c8", x"37", x"6d", x"8d", x"d5", x"4e", x"a9",
        x"6c", x"56", x"f4", x"ea", x"65", x"7a", x"ae", x"08",
        x"ba", x"78", x"25", x"2e", x"1c", x"a6", x"b4", x"c6",
        x"e8", x"dd", x"74", x"1f", x"4b", x"bd", x"8b", x"8a",
        x"70", x"3e", x"b5", x"66", x"48", x"03", x"f6", x"0e",
        x"61", x"35", x"57", x"b9", x"86", x"c1", x"1d", x"9e",
        x"e1", x"f8", x"98", x"11", x"69", x"d9", x"8e", x"94",
        x"9b", x"1e", x"87", x"e9", x"ce", x"55", x"28", x"df",
        x"8c", x"a1", x"89", x"0d", x"bf", x"e6", x"42", x"68",
        x"41", x"99", x"2d", x"0f", x"b0", x"54", x"bb", x"16"
    );

    -- Internal state register holding the 128-bit block being processed.
    signal state_reg : std_logic_vector(127 downto 0);
    signal done_reg  : std_logic;

begin

    ----------------------------------------------------------------------------
    -- Main process: perform AddRoundKey then SubBytes in one clock cycle.
    ----------------------------------------------------------------------------
    process(clk, reset)
        variable after_key : std_logic_vector(127 downto 0);
        variable sub_byte  : std_logic_vector(7 downto 0);
        variable idx       : integer;
    begin
        if reset = '1' then
            state_reg <= (others => '0');
            done_reg  <= '0';
        elsif rising_edge(clk) then
            done_reg <= '0';  -- default: not done
            if start = '1' then
                -- STEP 1: AddRoundKey - XOR each bit of data with the key.
                -- This mixes the key into the data so encryption depends on the key.
                after_key := data_in xor key_in;

                -- STEP 2: SubBytes - replace each of the 16 bytes using S-Box.
                -- We process the 16 bytes from most-significant to least.
                for i in 0 to 15 loop
                    idx := to_integer(unsigned(after_key((15-i)*8+7 downto (15-i)*8)));
                    sub_byte := SBOX(idx);
                    state_reg((15-i)*8+7 downto (15-i)*8) <= sub_byte;
                end loop;

                done_reg <= '1';  -- signal that the round is complete
            end if;
        end if;
    end process;

    data_out <= state_reg;
    done     <= done_reg;

end architecture rtl;
