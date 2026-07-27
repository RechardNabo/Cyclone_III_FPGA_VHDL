-- ============================================================================
-- 4-Digit Multiplexed Seven-Segment Display Driver
-- Target: Altera/Intel Cyclone III FPGA
-- Scans 4 digits at REFRESH_HZ per digit. Hex-to-segment decoder built in.
-- COMMON_ANODE=true inverts segment and digit-enable outputs.
-- Pin assignments go in .qsf only (no pin attributes in HDL).
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity seven_segment_4digit is
    generic (
        CLK_FREQ_HZ  : integer := 50_000_000;  -- Input clock frequency
        REFRESH_HZ   : integer := 1_000;       -- Per-digit refresh rate
        COMMON_ANODE : boolean := true         -- True = active-low outputs
    );
    port (
        clk     : in  std_logic;                       -- System clock
        reset_n : in  std_logic;                       -- Active-low reset
        digits  : in  std_logic_vector(15 downto 0);   -- Packed hex [D3..D0]
        dp_in   : in  std_logic_vector(3 downto 0);    -- Decimal point per digit
        seg     : out std_logic_vector(6 downto 0);    -- Segments {g,f,e,d,c,b,a}
        dp      : out std_logic;                       -- Decimal point output
        dig_en  : out std_logic_vector(3 downto 0)     -- Digit enable outputs
    );
end entity seven_segment_4digit;

architecture rtl of seven_segment_4digit is
    constant DIGIT_COUNT : integer := 4;

    -- Ticks per digit before switching (with safety floor)
    function calc_ticks(clk_hz, refresh_hz : integer) return integer is
        variable r : integer;
    begin
        if refresh_hz <= 0 then r := 1;
        else r := clk_hz / (refresh_hz * DIGIT_COUNT);
             if r < 1 then r := 1; end if;
        end if;
        return r;
    end function;

    constant TICKS_PER_DIGIT : integer :=
        calc_ticks(CLK_FREQ_HZ, REFRESH_HZ);

    signal refresh_counter : integer range 0 to TICKS_PER_DIGIT-1 := 0;
    signal digit_index     : integer range 0 to DIGIT_COUNT-1 := 0;
    signal current_nibble  : std_logic_vector(3 downto 0) := (others => '0');
    signal current_dp      : std_logic := '0';
    signal seg_reg         : std_logic_vector(6 downto 0) := (others => '0');
    signal dp_reg          : std_logic := '0';
    signal dig_en_reg      : std_logic_vector(3 downto 0) := (others => '0');
    signal blanking        : std_logic := '0';

    -- Hex digit to 7-segment pattern {g,f,e,d,c,b,a}
    function hex_to_segments(nibble : std_logic_vector(3 downto 0))
        return std_logic_vector is
        variable r : std_logic_vector(6 downto 0);
    begin
        case to_integer(unsigned(nibble)) is
            when 0  => r := "0111111"; -- 0
            when 1  => r := "0000110"; -- 1
            when 2  => r := "1011011"; -- 2
            when 3  => r := "1001111"; -- 3
            when 4  => r := "1100110"; -- 4
            when 5  => r := "1101101"; -- 5
            when 6  => r := "1111101"; -- 6
            when 7  => r := "0000111"; -- 7
            when 8  => r := "1111111"; -- 8
            when 9  => r := "1101111"; -- 9
            when 10 => r := "1110111"; -- A
            when 11 => r := "1111100"; -- b
            when 12 => r := "0111001"; -- C
            when 13 => r := "1011110"; -- d
            when 14 => r := "1111001"; -- E
            when 15 => r := "1110001"; -- F
            when others => r := "0000000"; -- Blank
        end case;
        return r;
    end function;
begin

    -- Refresh timer and digit scanner
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
                if digit_index = DIGIT_COUNT-1 then
                    digit_index <= 0;
                else
                    digit_index <= digit_index + 1;
                end if;
            elsif refresh_counter = TICKS_PER_DIGIT-1 then
                refresh_counter <= 0;
                blanking        <= '1';
            else
                refresh_counter <= refresh_counter + 1;
            end if;
        end if;
    end process refresh;

    -- Select current nibble and DP based on active digit
    with digit_index select current_nibble <=
        digits(3 downto 0)   when 0,
        digits(7 downto 4)   when 1,
        digits(11 downto 8)  when 2,
        digits(15 downto 12) when others;

    with digit_index select current_dp <=
        dp_in(0) when 0, dp_in(1) when 1,
        dp_in(2) when 2, dp_in(3) when others;

    -- Registered segment/digit outputs
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
                dig_en_reg <= (others => '0');  -- Blank during switch
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

    -- Apply polarity for common-anode or common-cathode
    seg    <= not seg_reg    when COMMON_ANODE else seg_reg;
    dp     <= not dp_reg     when COMMON_ANODE else dp_reg;
    dig_en <= not dig_en_reg when COMMON_ANODE else dig_en_reg;

end architecture rtl;
