-- ================================================================================
-- sha256_accelerator : Hardware SHA-256 hash computation
-- ================================================================================
-- AHB-Lite register map:
--   0x00 : CTRL   - [0] start, [1] reset
--   0x04 : STAT   - [0] busy, [1] done
--   0x08 : LEN    - Message length in bytes (up to 2^32)
--   0x0C : DATA_IN - Write 32-bit words of message data
--   0x10 : HASH0   - Hash output [31:0]    (H0)
--   0x14 : HASH1   - Hash output [63:32]   (H1)
--   0x18 : HASH2   - Hash output [95:64]   (H2)
--   0x1C : HASH3   - Hash output [127:96]  (H3)
--   0x20 : HASH4   - Hash output [159:128] (H4)
--   0x24 : HASH5   - Hash output [191:160] (H5)
--   0x28 : HASH6   - Hash output [223:192] (H6)
--   0x2C : HASH7   - Hash output [255:224] (H7)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sha256_accelerator is
    port (
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
        sha_irq   : out std_logic
    );
end entity sha256_accelerator;

architecture rtl of sha256_accelerator is
    -- SHA-256 constants (first 32 of K)
    type k_array_t is array(0 to 63) of std_logic_vector(31 downto 0);
    constant K : k_array_t := (
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

    -- Initial hash values
    constant H0_INIT : std_logic_vector(31 downto 0) := x"6a09e667";
    constant H1_INIT : std_logic_vector(31 downto 0) := x"bb67ae85";
    constant H2_INIT : std_logic_vector(31 downto 0) := x"3c6ef372";
    constant H3_INIT : std_logic_vector(31 downto 0) := x"a54ff53a";
    constant H4_INIT : std_logic_vector(31 downto 0) := x"510e527f";
    constant H5_INIT : std_logic_vector(31 downto 0) := x"9b05688c";
    constant H6_INIT : std_logic_vector(31 downto 0) := x"1f83d9ab";
    constant H7_INIT : std_logic_vector(31 downto 0) := x"5be0cd19";

    signal h0, h1, h2, h3, h4, h5, h6, h7 : std_logic_vector(31 downto 0);
    signal msg_len : unsigned(31 downto 0) := (others => '0');
    signal word_cnt : unsigned(15 downto 0) := (others => '0');

    -- Message block buffer (16 words = 512 bits)
    type msg_buf_t is array(0 to 15) of std_logic_vector(31 downto 0);
    signal msg_buf : msg_buf_t := (others => (others => '0'));

    -- Extended message schedule (64 words)
    type w_array_t is array(0 to 63) of std_logic_vector(31 downto 0);
    signal W : w_array_t := (others => (others => '0'));

    signal stat_busy : std_logic := '0';
    signal stat_done : std_logic := '0';
    signal sha_fsm   : integer range 0 to 5 := 0;
    signal round_cnt : integer range 0 to 63 := 0;

    signal a_reg, b_reg, c_reg, d_reg : std_logic_vector(31 downto 0);
    signal e_reg, f_reg, g_reg, h_reg : std_logic_vector(31 downto 0);

    signal reg_offset : std_logic_vector(7 downto 0);
    signal write_en   : std_logic;

    -- SHA-256 helper functions
    function rotr(x : std_logic_vector(31 downto 0); n : integer) return std_logic_vector is
    begin
        return x(n-1 downto 0) & x(31 downto n);
    end function;

    function ch(x, y, z : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return (x and y) xor ((not x) and z);
    end function;

    function maj(x, y, z : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return (x and y) xor (x and z) xor (y and z);
    end function;

    function big_sigma0(x : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return rotr(x, 2) xor rotr(x, 13) xor rotr(x, 22);
    end function;

    function big_sigma1(x : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return rotr(x, 6) xor rotr(x, 11) xor rotr(x, 25);
    end function;

    function small_sigma0(x : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return rotr(x, 7) xor rotr(x, 18) xor (x(10 downto 0) & "00000000000000000000");
    end function;

    function small_sigma1(x : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return rotr(x, 17) xor rotr(x, 19) xor (x(2 downto 0) & "000000000000000000000000000");
    end function;

begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;

    ahb_write : process(HCLK, HRESETn)
        variable temp1, temp2 : std_logic_vector(31 downto 0);
    begin
        if HRESETn = '0' then
            h0 <= H0_INIT; h1 <= H1_INIT; h2 <= H2_INIT; h3 <= H3_INIT;
            h4 <= H4_INIT; h5 <= H5_INIT; h6 <= H6_INIT; h7 <= H7_INIT;
            msg_len <= (others => '0');
            word_cnt <= (others => '0');
            stat_busy <= '0';
            stat_done <= '0';
            sha_fsm <= 0;
            round_cnt <= 0;
        elsif rising_edge(HCLK) then
            stat_done <= '0';

            if write_en = '1' then
                case reg_offset is
                    when x"00" =>  -- CTRL
                        if HWDATA(1) = '1' then  -- reset
                            h0 <= H0_INIT; h1 <= H1_INIT; h2 <= H2_INIT; h3 <= H3_INIT;
                            h4 <= H4_INIT; h5 <= H5_INIT; h6 <= H6_INIT; h7 <= H7_INIT;
                            word_cnt <= (others => '0');
                        end if;
                        if HWDATA(0) = '1' then  -- start
                            sha_fsm <= 1;
                            stat_busy <= '1';
                            round_cnt <= 0;
                        end if;
                    when x"08" =>  -- LEN
                        msg_len <= unsigned(HWDATA);
                    when x"0C" =>  -- DATA_IN
                        msg_buf(to_integer(word_cnt(3 downto 0))) <= HWDATA;
                        word_cnt <= word_cnt + 1;
                    when others => null;
                end case;
            end if;

            -- SHA-256 FSM
            case sha_fsm is
                when 0 => null;  -- idle
                when 1 =>  -- Initialize message schedule and working variables
                    for i in 0 to 15 loop
                        W(i) <= msg_buf(i);
                    end loop;
                    -- Extend message schedule (simplified - done in next state)
                    a_reg <= h0; b_reg <= h1; c_reg <= h2; d_reg <= h3;
                    e_reg <= h4; f_reg <= h5; g_reg <= h6; h_reg <= h7;
                    round_cnt <= 0;
                    sha_fsm <= 2;

                when 2 =>  -- Extend W[16..63] and compression
                    if round_cnt < 64 then
                        if round_cnt >= 16 then
                            W(round_cnt) <= std_logic_vector(
                                unsigned(W(round_cnt-16)) +
                                unsigned(small_sigma0(W(round_cnt-15))) +
                                unsigned(W(round_cnt-7)) +
                                unsigned(small_sigma1(W(round_cnt-2))));
                        end if;
                        -- Compression
                        temp1 := std_logic_vector(unsigned(h_reg) +
                                   unsigned(big_sigma1(e_reg)) +
                                   unsigned(ch(e_reg, f_reg, g_reg)) +
                                   unsigned(K(round_cnt)) +
                                   unsigned(W(round_cnt)));
                        temp2 := std_logic_vector(unsigned(big_sigma0(a_reg)) +
                                   unsigned(maj(a_reg, b_reg, c_reg)));
                        h_reg <= g_reg;
                        g_reg <= f_reg;
                        f_reg <= e_reg;
                        e_reg <= std_logic_vector(unsigned(d_reg) + unsigned(temp1));
                        d_reg <= c_reg;
                        c_reg <= b_reg;
                        b_reg <= a_reg;
                        a_reg <= std_logic_vector(unsigned(temp1) + unsigned(temp2));
                        round_cnt <= round_cnt + 1;
                    else
                        sha_fsm <= 3;
                    end if;

                when 3 =>  -- Add working variables to hash
                    h0 <= std_logic_vector(unsigned(h0) + unsigned(a_reg));
                    h1 <= std_logic_vector(unsigned(h1) + unsigned(b_reg));
                    h2 <= std_logic_vector(unsigned(h2) + unsigned(c_reg));
                    h3 <= std_logic_vector(unsigned(h3) + unsigned(d_reg));
                    h4 <= std_logic_vector(unsigned(h4) + unsigned(e_reg));
                    h5 <= std_logic_vector(unsigned(h5) + unsigned(f_reg));
                    h6 <= std_logic_vector(unsigned(h6) + unsigned(g_reg));
                    h7 <= std_logic_vector(unsigned(h7) + unsigned(h_reg));
                    stat_busy <= '0';
                    stat_done <= '1';
                    sha_fsm <= 0;

                when others => sha_fsm <= 0;
            end case;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, HADDR, reg_offset, stat_busy, stat_done,
                       h0, h1, h2, h3, h4, h5, h6, h7)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"04" => rdata(0) := stat_busy; rdata(1) := stat_done;
                when x"10" => rdata := h0;
                when x"14" => rdata := h1;
                when x"18" => rdata := h2;
                when x"1C" => rdata := h3;
                when x"20" => rdata := h4;
                when x"24" => rdata := h5;
                when x"28" => rdata := h6;
                when x"2C" => rdata := h7;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    sha_irq   <= stat_done;

end architecture rtl;
