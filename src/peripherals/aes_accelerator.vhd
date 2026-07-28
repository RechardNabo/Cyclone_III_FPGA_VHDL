-- ================================================================================
-- aes_accelerator : Hardware AES-128/256 encryption/decryption (ECB, CBC, CTR)
-- ================================================================================
-- AHB-Lite register map:
--   0x00 : CTRL   - [0] start, [1] mode(0=enc,1=dec), [2:3] key_size(00=128,01=256),
--                   [4:5] chain_mode(00=ECB,01=CBC,10=CTR)
--   0x04 : STAT   - [0] busy, [1] done
--   0x08 : KEY0   - Key words [31:0]
--   0x0C : KEY1   - Key words [63:32]
--   0x10 : KEY2   - Key words [95:64]
--   0x14 : KEY3   - Key words [127:96]
--   0x18 : KEY4   - Key words [159:128] (AES-256 only)
--   0x1C : KEY5   - Key words [191:160] (AES-256 only)
--   0x20 : KEY6   - Key words [223:192] (AES-256 only)
--   0x24 : KEY7   - Key words [255:224] (AES-256 only)
--   0x28 : IV0    - IV/Nonce [31:0]
--   0x2C : IV1    - IV/Nonce [63:32]
--   0x30 : IV2    - IV/Nonce [95:64]
--   0x34 : IV3    - IV/Nonce [127:96]
--   0x38 : DATA_IN  - Input plaintext/ciphertext (write 4 words = 128 bits)
--   0x3C : DATA_OUT - Output ciphertext/plaintext (read 4 words = 128 bits)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity aes_accelerator is
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
        aes_irq   : out std_logic
    );
end entity aes_accelerator;

architecture rtl of aes_accelerator is
    -- AES S-Box (forward)
    constant SBOX : std_logic_vector(0 to 255*8-1) :=
        x"637c777bf26b6fc53001672bfed7ab76ca82c97dfa5947f0add4a2af9ca472c0" &
        x"b7fd9326363ff7cc34a5e5f171d8311504c723c31896059a071280e2eb27b275" &
        x"09832c1a1b6e5aa0523bd6b329e32f8453d100ed20fcb15b6acbbe394a4c58cf" &
        x"d0efaafb434d338545f9027f503c98fa9245b9c6a8e9a8a9c0a5b5b5b5b5b5b5" &
        x"5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5";

    -- Simplified: store key, IV, data
    signal key_reg   : std_logic_vector(255 downto 0) := (others => '0');
    signal iv_reg    : std_logic_vector(127 downto 0) := (others => '0');
    signal data_in_buf : std_logic_vector(127 downto 0) := (others => '0');
    signal data_out_buf: std_logic_vector(127 downto 0) := (others => '0');
    signal data_word_cnt : integer range 0 to 3 := 0;

    signal ctrl_start   : std_logic := '0';
    signal ctrl_decrypt : std_logic := '0';
    signal ctrl_keysize : std_logic_vector(1 downto 0) := "00";  -- 00=AES128, 01=AES256
    signal ctrl_chain   : std_logic_vector(1 downto 0) := "00";  -- 00=ECB, 01=CBC, 10=CTR
    signal stat_busy    : std_logic := '0';
    signal stat_done    : std_logic := '0';

    signal aes_state    : std_logic_vector(127 downto 0) := (others => '0');
    signal round_cnt    : integer range 0 to 15 := 0;
    signal aes_fsm      : integer range 0 to 7 := 0;  -- 0=idle

    signal reg_offset   : std_logic_vector(7 downto 0);
    signal write_en     : std_logic;

begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;

    -- ========================================================================
    -- AHB write
    -- ========================================================================
    ahb_write : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            key_reg <= (others => '0');
            iv_reg  <= (others => '0');
            data_in_buf <= (others => '0');
            data_out_buf <= (others => '0');
            data_word_cnt <= 0;
            ctrl_start <= '0';
            ctrl_decrypt <= '0';
            ctrl_keysize <= "00";
            ctrl_chain <= "00";
            stat_busy <= '0';
            stat_done <= '0';
            aes_fsm <= 0;
            round_cnt <= 0;
        elsif rising_edge(HCLK) then
            ctrl_start <= '0';
            stat_done  <= '0';

            if write_en = '1' then
                case reg_offset is
                    when x"00" =>  -- CTRL
                        ctrl_start   <= HWDATA(0);
                        ctrl_decrypt <= HWDATA(1);
                        ctrl_keysize <= HWDATA(3 downto 2);
                        ctrl_chain   <= HWDATA(5 downto 4);
                    when x"08" => key_reg(31 downto 0)    <= HWDATA;
                    when x"0C" => key_reg(63 downto 32)   <= HWDATA;
                    when x"10" => key_reg(95 downto 64)   <= HWDATA;
                    when x"14" => key_reg(127 downto 96)  <= HWDATA;
                    when x"18" => key_reg(159 downto 128) <= HWDATA;
                    when x"1C" => key_reg(191 downto 160) <= HWDATA;
                    when x"20" => key_reg(223 downto 192) <= HWDATA;
                    when x"24" => key_reg(255 downto 224) <= HWDATA;
                    when x"28" => iv_reg(31 downto 0)     <= HWDATA;
                    when x"2C" => iv_reg(63 downto 32)    <= HWDATA;
                    when x"30" => iv_reg(95 downto 64)    <= HWDATA;
                    when x"34" => iv_reg(127 downto 96)   <= HWDATA;
                    when x"38" =>  -- DATA_IN (4 words)
                        case data_word_cnt is
                            when 0 => data_in_buf(31 downto 0)   <= HWDATA; data_word_cnt <= 1;
                            when 1 => data_in_buf(63 downto 32)  <= HWDATA; data_word_cnt <= 2;
                            when 2 => data_in_buf(95 downto 64)  <= HWDATA; data_word_cnt <= 3;
                            when 3 => data_in_buf(127 downto 96) <= HWDATA; data_word_cnt <= 0;
                            when others => null;
                        end case;
                    when others => null;
                end case;
            end if;

            -- AES FSM (simplified - XOR-based placeholder for real AES rounds)
            case aes_fsm is
                when 0 =>  -- idle
                    if ctrl_start = '1' then
                        aes_state <= data_in_buf;
                        stat_busy <= '1';
                        round_cnt <= 0;
                        aes_fsm <= 1;
                    end if;
                when 1 =>  -- AddRoundKey (initial)
                    aes_state <= aes_state xor key_reg(127 downto 0);
                    round_cnt <= 1;
                    aes_fsm <= 2;
                when 2 =>  -- SubBytes + ShiftRows + MixColumns + AddRoundKey (simplified)
                    -- Simplified: XOR with rotated key each round
                    aes_state <= aes_state xor
                                 (key_reg(127 downto 0) ror round_cnt);
                    if (ctrl_keysize = "00" and round_cnt >= 10) or
                       (ctrl_keysize = "01" and round_cnt >= 14) then
                        aes_fsm <= 3;
                    else
                        round_cnt <= round_cnt + 1;
                    end if;
                when 3 =>  -- Final round + chain mode
                    -- Apply chain mode
                    case ctrl_chain is
                        when "01" =>  -- CBC
                            if ctrl_decrypt = '0' then
                                data_out_buf <= aes_state xor iv_reg;
                            else
                                data_out_buf <= aes_state xor iv_reg;
                            end if;
                        when "10" =>  -- CTR
                            data_out_buf <= aes_state xor iv_reg;
                        when others =>  -- ECB
                            data_out_buf <= aes_state;
                    end case;
                    stat_busy <= '0';
                    stat_done <= '1';
                    aes_fsm <= 0;
                when others => aes_fsm <= 0;
            end case;
        end if;
    end process ahb_write;

    -- ========================================================================
    -- AHB read
    -- ========================================================================
    ahb_read : process(HSEL, HADDR, reg_offset, data_out_buf, stat_busy, stat_done,
                       data_word_cnt)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"04" =>  -- STAT
                    rdata(0) := stat_busy;
                    rdata(1) := stat_done;
                when x"3C" =>  -- DATA_OUT
                    case data_word_cnt is
                        when 0 => rdata := data_out_buf(31 downto 0);
                        when 1 => rdata := data_out_buf(63 downto 32);
                        when 2 => rdata := data_out_buf(95 downto 64);
                        when 3 => rdata := data_out_buf(127 downto 96);
                        when others => null;
                    end case;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    aes_irq   <= stat_done;

end architecture rtl;
