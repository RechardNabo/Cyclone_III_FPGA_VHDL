-- ============================================================================
-- SHA-256 Hasher - Simplified Single Block (Educational)
-- ============================================================================
-- SHA-256 produces a 256-bit hash from input data. It processes data in
-- 512-bit blocks through a compression function of 64 rounds.
--
-- This simplified version processes ONE 512-bit block (no padding logic).
-- It implements the full compression function with the round function,
-- the 64 round constants K, and the 8 initial hash values H.
--
-- LEARNING CONCEPTS:
-- 1. Cryptographic hashing (one-way, fixed output size)
-- 2. The compression function: message schedule + round function
-- 3. Working with 32-bit words and modular addition (mod 2^32)
-- 4. Rotations and logical functions (Ch, Maj, Sigma0, Sigma1)
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sha256_hasher is
    port (
        clk       : in  std_logic;                       -- Clock
        reset     : in  std_logic;                       -- Async reset (active high)
        start     : in  std_logic;                       -- Start hashing a block
        msg_block : in  std_logic_vector(511 downto 0);  -- One 512-bit block
        hash_out  : out std_logic_vector(255 downto 0);  -- 256-bit hash result
        done      : out std_logic                        -- High when done
    );
end entity sha256_hasher;

architecture rtl of sha256_hasher is

    -- SHA-256 round constants K (64 values, first 32 bits of fractional parts
    -- of the cube roots of the first 64 prime numbers).
    type k_array is array (0 to 63) of unsigned(31 downto 0);
    constant K : k_array := (
        x"428a2f98", x"71374491", x"b5c0fbcf", x"e9b5dba5",
        x"3956c25b", x"59f111f1", x"923f82a4", x"ab1c5ed5",
        x"d807aa98", x"12835b01", x"243185be", x"550c7dc3",
        x"72be5d74", x"80deb1fe", x"9bdc06a7", x"c19bf174",
        x"e49b69c1", x"efbe4786", x"0fc19dc6", x"240ca1cc",
        x"2de92c6f", x"4a7484aa", x"5cb0a9dc", x"76f988da",
        x"983e5152", x"a831c66d", x"b00327c8", x"bf597fc7",
        x"c6e00bf3", x"d5a79147", x"06ca6351", x"14292967",
        x"27b70a85", x"2e1b2138", x"4d2c6dfc", x"53380d13",
        x"650a7354", x"766a0abb", x"81c2c92e", x"92722c85",
        x"a2bfe8a1", x"a81a664b", x"c24b8b70", x"c76c51a3",
        x"d192e819", x"d6990624", x"f40e3585", x"106aa070",
        x"19a4c116", x"1e376c08", x"2748774c", x"34b0bcb5",
        x"391c0cb3", x"4ed8aa4a", x"5b9cca4f", x"682e6ff3",
        x"748f82ee", x"78a5636f", x"84c87814", x"8cc70208",
        x"90befffa", x"a4506ceb", x"bef9a3f7", x"c67178f2"
    );

    -- Initial hash values H0..H7 (first 32 bits of fractional parts of the
    -- square roots of the first 8 prime numbers).
    type h_array is array (0 to 7) of unsigned(31 downto 0);
    constant H_INIT : h_array := (
        x"6a09e667", x"bb67ae85", x"3c6ef372", x"a54ff53a",
        x"510e527f", x"9b05688c", x"1f83d9ab", x"5be0cd19"
    );

    -- FSM states
    type state_type is (IDLE, EXPAND, COMPRESS, FINISH);
    signal state : state_type := IDLE;

    -- Message schedule W (64 words of 32 bits)
    type w_array is array (0 to 63) of unsigned(31 downto 0);
    signal w : w_array;

    -- Working hash variables a,b,c,d,e,f,g,h
    signal a, b, c, d, e, f, g, h : unsigned(31 downto 0);
    signal round_idx : integer range 0 to 64 := 0;
    signal done_reg  : std_logic := '0';

    -- Helper: rotate right by N bits (circular shift)
    function rotr(x : unsigned(31 downto 0); n : integer) return unsigned is
    begin
        return shift_right(x, n) or shift_left(x, 32 - n);
    end function;

begin

    ----------------------------------------------------------------------------
    -- Main process: message schedule expansion + compression rounds.
    ----------------------------------------------------------------------------
    process(clk, reset)
        variable s0, s1, ch, maj, temp1, temp2 : unsigned(31 downto 0);
        variable w0, w1, w2, w3 : unsigned(31 downto 0);
    begin
        if reset = '1' then
            state     <= IDLE;
            done_reg  <= '0';
            round_idx <= 0;
        elsif rising_edge(clk) then
            done_reg <= '0';
            case state is

                when IDLE =>
                    if start = '1' then
                        -- Load the first 16 words of W directly from the
                        -- 512-bit message block (each word is 32 bits).
                        for i in 0 to 15 loop
                            w(i) <= unsigned(msg_block((15-i)*32+31 downto (15-i)*32));
                        end loop;
                        -- Initialize working hash from H_INIT.
                        a <= H_INIT(0); b <= H_INIT(1);
                        c <= H_INIT(2); d <= H_INIT(3);
                        e <= H_INIT(4); f <= H_INIT(5);
                        g <= H_INIT(6); h <= H_INIT(7);
                        round_idx <= 0;
                        state     <= EXPAND;
                    end if;

                when EXPAND =>
                    -- Expand W(16..63) using the message schedule formula:
                    --   W[t] = W[t-16] + sigma0(W[t-15]) + W[t-7] + sigma1(W[t-2])
                    -- where sigma0(x)=rotr(x,7)^rotr(x,18)^shift_right(x,3)
                    --       sigma1(x)=rotr(x,17)^rotr(x,19)^shift_right(x,10)
                    -- We compute one word per cycle for simplicity.
                    if round_idx >= 16 and round_idx <= 63 then
                        w0 := rotr(w(round_idx-15), 7) xor rotr(w(round_idx-15), 18)
                              xor shift_right(w(round_idx-15), 3);
                        w1 := rotr(w(round_idx-2), 17) xor rotr(w(round_idx-2), 19)
                              xor shift_right(w(round_idx-2), 10);
                        w(round_idx) <= w(round_idx-16) + w0 + w(round_idx-7) + w1;
                    end if;
                    if round_idx = 63 then
                        round_idx <= 0;
                        state     <= COMPRESS;
                    else
                        round_idx <= round_idx + 1;
                    end if;

                when COMPRESS =>
                    -- One compression round per cycle (64 rounds total).
                    -- Sigma1, Ch, Temp1, Sigma0, Maj, Temp2
                    s1 := rotr(e, 6) xor rotr(e, 11) xor rotr(e, 25);
                    ch := (e and f) xor ((not e) and g);
                    temp1 := h + s1 + ch + K(round_idx) + w(round_idx);
                    s0 := rotr(a, 2) xor rotr(a, 13) xor rotr(a, 22);
                    maj := (a and b) xor (a and c) xor (b and c);
                    temp2 := s0 + maj;
                    -- Shift the working variables for the next round.
                    h <= g;
                    g <= f;
                    f <= e;
                    e <= d + temp1;
                    d <= c;
                    c <= b;
                    b <= a;
                    a <= temp1 + temp2;

                    if round_idx = 63 then
                        state <= FINISH;
                    else
                        round_idx <= round_idx + 1;
                    end if;

                when FINISH =>
                    -- Add the working hash to the initial hash values to get
                    -- the final hash for this block.
                    a <= a + H_INIT(0);
                    b <= b + H_INIT(1);
                    c <= c + H_INIT(2);
                    d <= d + H_INIT(3);
                    e <= e + H_INIT(4);
                    f <= f + H_INIT(5);
                    g <= g + H_INIT(6);
                    h <= h + H_INIT(7);
                    done_reg <= '1';
                    state    <= IDLE;

            end case;
        end if;
    end process;

    -- Concatenate the 8 hash words (a..h) into the 256-bit output.
    hash_out <= std_logic_vector(a & b & c & d & e & f & g & h);
    done     <= done_reg;

end architecture rtl;
