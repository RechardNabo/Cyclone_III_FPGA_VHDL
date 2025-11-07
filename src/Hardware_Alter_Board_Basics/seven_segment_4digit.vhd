-- ============================================================================
-- Peripheral: 4-Digit Seven-Segment Display (Multiplexed) — Documentation-Only
-- Target: Altera/Intel Cyclone III FPGA
-- Purpose:
--   This file documents how to drive a multiplexed 4-digit seven-segment
--   display. No VHDL code is implemented here by request.
--
-- Overview:
-- - Verify display type: common-anode (segments active-low) or common-cathode
--   (segments active-high). Digit enable polarity also depends on type.
-- - Multiplexing: scan digits rapidly to leverage persistence of vision.
--   Typical per-digit refresh >1 kHz (overall ~4 kHz for 4 digits).
-- - Provide optional decimal point (DP) control as needed.
--
-- Pin Assignments (example; adjust to your board):
--   set_location_assignment PIN_<N> -to seg[0]  -- a
--   set_location_assignment PIN_<N> -to seg[1]  -- b
--   set_location_assignment PIN_<N> -to seg[2]  -- c
--   set_location_assignment PIN_<N> -to seg[3]  -- d
--   set_location_assignment PIN_<N> -to seg[4]  -- e
--   set_location_assignment PIN_<N> -to seg[5]  -- f
--   set_location_assignment PIN_<N> -to seg[6]  -- g
--   set_location_assignment PIN_<N> -to dp      -- decimal point
--   set_location_assignment PIN_<N> -to dig_en[0..3] -- digit enables
--
-- Recommended HDL Structure (not implemented):
-- - Generics: CLK_FREQ_HZ, REFRESH_HZ, COMMON_ANODE
-- - Ports:    clk, reset_n, digits(15..0), seg(6..0), dp, dig_en(3..0)
-- - Blocks:   refresh timer, digit scan, hex-to-seg decoder, polarity handler
--
-- Decoder Notes (hex-to-seg):
-- - Map 0..9, A..F to segment patterns. Adapt for your font preference.
-- - For COMMON_ANODE, invert segment outputs.
--
-- Usage Notes:
-- - Pack 4 nibbles into a 16-bit vector: [D3][D2][D1][D0].
-- - Choose REFRESH_HZ to avoid flicker; ensure timing fits CLK_FREQ_HZ.
-- - Confirm digit enable polarity for your display type.
--
-- Bring-Up Checklist:
-- □ Pins assigned for segments, DP, and digit enables
-- □ Display type verified (COMMON_ANODE vs common-cathode)
-- □ Refresh timing computed from CLK_FREQ_HZ and REFRESH_HZ
-- □ Hex-to-seg mapping validated
--
-- TODOs:
-- - Create your own seven-segment driver entity/architecture.
-- - Finalize decoder patterns and DP behavior.
-- - Validate brightness/uniformity and adjust duty cycle if needed.
-- ============================================================================


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seven_segment_4digit is
    generic (
        CLK_FREQ_HZ  : integer := 50_000_000;  -- Input clock frequency in Hz
        REFRESH_HZ   : integer := 1_000;       -- Per-digit refresh rate in Hz
        COMMON_ANODE : boolean := true         -- True for common-anode (active-low)
    );
    port (
        clk     : in  std_logic;                          -- System clock
        reset_n : in  std_logic;                          -- Active-low reset
        digits  : in  std_logic_vector(15 downto 0);      -- Packed hex digits [D3..D0]
        dp_in   : in  std_logic_vector(3 downto 0);       -- Decimal point enable per digit
        seg     : out std_logic_vector(6 downto 0);       -- Segment outputs {g,f,e,d,c,b,a}
        dp      : out std_logic;                          -- Decimal point output
        dig_en  : out std_logic_vector(3 downto 0)        -- Digit enable outputs
    );
end entity seven_segment_4digit;

architecture rtl of seven_segment_4digit is
    attribute chip_pin : string;
    attribute chip_pin of clk     : signal is "G2";
    attribute chip_pin of reset_n : signal is "G1";
    attribute chip_pin of digits  : signal is "V9 T11 W8 T10 AB9 Y10 AA10 U11 V8 W6 AB8 AA9 AA8 AA14 W10 V11";
    attribute chip_pin of dp_in   : signal is "AB5 AA5 W7 AB7";
    attribute chip_pin of seg     : signal is "AB3 V10 AB4 AB10 U10 U9 Y7";
    attribute chip_pin of dp      : signal is "Y6";
    attribute chip_pin of dig_en  : signal is "V7 AA7 AA4 Y8";
    constant DIGIT_COUNT : integer := 4;

    function calc_ticks_per_digit(clk_hz : integer; refresh_hz : integer) return integer is
        variable result : integer;
    begin
        if refresh_hz <= 0 then
            result := 1;
        else
            result := clk_hz / (refresh_hz * DIGIT_COUNT);
            if result < 1 then
                result := 1;
            end if;
        end if;
        return result;
    end function;

    constant TICKS_PER_DIGIT : integer := calc_ticks_per_digit(CLK_FREQ_HZ, REFRESH_HZ);

    subtype tick_range is integer range 0 to TICKS_PER_DIGIT - 1;

    signal refresh_counter : tick_range := 0;
    signal digit_index     : integer range 0 to DIGIT_COUNT - 1 := 0;

    signal current_nibble  : std_logic_vector(3 downto 0);
    signal current_dp      : std_logic;

    signal seg_reg    : std_logic_vector(6 downto 0) := (others => '0');
    signal dp_reg     : std_logic := '0';
    signal dig_en_reg : std_logic_vector(3 downto 0) := (others => '0');
    signal blanking   : std_logic := '0';

    function hex_to_segments(nibble : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable result : std_logic_vector(6 downto 0);
        variable value  : integer := to_integer(unsigned(nibble));
    begin
        case value is
            when 0  => result := "0111111"; -- 0
            when 1  => result := "0000110"; -- 1
            when 2  => result := "1011011"; -- 2
            when 3  => result := "1001111"; -- 3
            when 4  => result := "1100110"; -- 4
            when 5  => result := "1101101"; -- 5
            when 6  => result := "1111101"; -- 6
            when 7  => result := "0000111"; -- 7
            when 8  => result := "1111111"; -- 8
            when 9  => result := "1101111"; -- 9
            when 10 => result := "1110111"; -- A
            when 11 => result := "1111100"; -- b
            when 12 => result := "0111001"; -- C
            when 13 => result := "1011110"; -- d
            when 14 => result := "1111001"; -- E
            when 15 => result := "1110001"; -- F
            when others => result := "0000000"; -- Blank/off
        end case;
        return result;
    end function;

begin
    refresh : process(clk, reset_n)
    begin
        if reset_n = '0' then
            refresh_counter <= 0;
            digit_index     <= 0;
            blanking        <= '0';
        elsif rising_edge(clk) then
            if blanking = '1' then
                blanking        <= '0';
                refresh_counter <= 0;
                if digit_index = DIGIT_COUNT - 1 then
                    digit_index <= 0;
                else
                    digit_index <= digit_index + 1;
                end if;
            elsif refresh_counter = TICKS_PER_DIGIT - 1 then
                refresh_counter <= 0;
                blanking        <= '1';
            else
                refresh_counter <= refresh_counter + 1;
            end if;
        end if;
    end process refresh;

    with digit_index select current_nibble <=
        digits(3 downto 0)    when 0,
        digits(7 downto 4)    when 1,
        digits(11 downto 8)   when 2,
        digits(15 downto 12)  when others;

    with digit_index select current_dp <=
        dp_in(0) when 0,
        dp_in(1) when 1,
        dp_in(2) when 2,
        dp_in(3) when others;

    outputs : process(clk, reset_n)
    begin
        if reset_n = '0' then
            seg_reg    <= (others => '0');
            dp_reg     <= '0';
            dig_en_reg <= (others => '0');
        elsif rising_edge(clk) then
            seg_reg <= hex_to_segments(current_nibble);
            dp_reg  <= current_dp;

            if blanking = '1' then
                dig_en_reg <= (others => '0');
            else
                case digit_index is
                    when 0 => dig_en_reg <= "0001";
                    when 1 => dig_en_reg <= "0010";
                    when 2 => dig_en_reg <= "0100";
                    when others => dig_en_reg <= "1000";
                end case;
            end if;
        end if;
    end process outputs;

    seg    <= not seg_reg    when COMMON_ANODE else seg_reg;
    dp     <= not dp_reg     when COMMON_ANODE else dp_reg;
    dig_en <= not dig_en_reg when COMMON_ANODE else dig_en_reg;

end architecture rtl;