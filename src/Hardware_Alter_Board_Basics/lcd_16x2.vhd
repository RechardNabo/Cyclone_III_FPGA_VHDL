-- ============================================================================
-- LCD 16x2 Character Display Driver (HD44780-compatible, 8-bit mode)
-- Target: Altera/Intel Cyclone III FPGA
-- Initializes the display, then writes characters from an input interface.
-- Uses RS (register select), RW (read/write), EN (enable), data[7:0].
-- Pin assignments go in .qsf only.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lcd_16x2 is
    generic (
        CLK_FREQ_HZ : integer := 50_000_000
    );
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;            -- Active-low reset
        char_in   : in  std_logic_vector(7 downto 0);  -- Character/command
        is_cmd    : in  std_logic;            -- 1=command, 0=data
        write_stb : in  std_logic;            -- Pulse to write
        busy      : out std_logic;            -- 1=controller busy
        lcd_rs    : out std_logic;            -- 0=cmd, 1=data
        lcd_rw    : out std_logic;            -- 0=write (always)
        lcd_en    : out std_logic;            -- Enable strobe
        lcd_data  : out std_logic_vector(7 downto 0)
    );
end entity lcd_16x2;

architecture rtl of lcd_16x2 is
    type state_t is (INIT_WAIT, INIT_FUNC, INIT_DISP, INIT_CLEAR,
                     INIT_ENTRY, IDLE, WRITE_SETUP, WRITE_PULSE, WRITE_HOLD);
    signal state       : state_t := INIT_WAIT;
    signal timer       : integer range 0 to CLK_FREQ_HZ := 0;
    signal data_latch  : std_logic_vector(7 downto 0) := (others => '0');
    signal rs_latch    : std_logic := '0';
begin

    lcd_rw <= '0';  -- Always write mode

    lcd_fsm : process(clk, reset_n)
        variable us_cycles : integer;
    begin
        if reset_n = '0' then
            state <= INIT_WAIT; timer <= 0;
            lcd_rs <= '0'; lcd_en <= '0';
            lcd_data <= (others => '0'); busy <= '1';
            data_latch <= (others => '0'); rs_latch <= '0';
        elsif rising_edge(clk) then
            busy   <= '1';  -- Default: busy
            lcd_en <= '0';  -- Default: EN low
            case state is
                when INIT_WAIT =>       -- Power-on wait ~15 ms
                    us_cycles := CLK_FREQ_HZ / 1000 * 15;
                    if timer = us_cycles - 1 then
                        timer <= 0; state <= INIT_FUNC;
                    else timer <= timer + 1; end if;
                when INIT_FUNC =>       -- Function set: 8-bit, 2 lines
                    lcd_rs <= '0'; lcd_data <= x"38"; lcd_en <= '1';
                    if timer = 100 then
                        timer <= 0; lcd_en <= '0'; state <= INIT_DISP;
                    else timer <= timer + 1; end if;
                when INIT_DISP =>       -- Display ON, cursor ON
                    lcd_data <= x"0E"; lcd_en <= '1';
                    if timer = 100 then
                        timer <= 0; lcd_en <= '0'; state <= INIT_CLEAR;
                    else timer <= timer + 1; end if;
                when INIT_CLEAR =>      -- Clear display
                    lcd_data <= x"01"; lcd_en <= '1';
                    if timer = 100 then
                        timer <= 0; lcd_en <= '0'; state <= INIT_ENTRY;
                    else timer <= timer + 1; end if;
                when INIT_ENTRY =>      -- Entry mode: increment, no shift
                    lcd_data <= x"06"; lcd_en <= '1';
                    if timer = 100 then
                        timer <= 0; lcd_en <= '0'; state <= IDLE;
                    else timer <= timer + 1; end if;
                when IDLE =>            -- Ready for user writes
                    busy <= '0';
                    if write_stb = '1' then
                        data_latch <= char_in;
                        rs_latch   <= is_cmd;
                        state      <= WRITE_SETUP;
                    end if;
                when WRITE_SETUP =>     -- Setup data and RS
                    lcd_rs <= rs_latch; lcd_data <= data_latch;
                    timer <= 0; state <= WRITE_PULSE;
                when WRITE_PULSE =>     -- Enable high pulse
                    lcd_en <= '1';
                    if timer = 100 then
                        timer <= 0; lcd_en <= '0'; state <= WRITE_HOLD;
                    else timer <= timer + 1; end if;
                when WRITE_HOLD =>      -- Hold after pulse
                    if timer = 200 then
                        timer <= 0; state <= IDLE;
                    else timer <= timer + 1; end if;
            end case;
        end if;
    end process lcd_fsm;

end architecture rtl;
