-- ================================================================================
-- onewire_controller : Dallas/Maxim 1-Wire bus controller
-- ================================================================================
-- AHB-Lite register map:
--   0x00 : CTRL   - [0] enable, [1] reset_pulse, [2] search_rom
--   0x04 : STAT   - [0] busy, [1] presence_detect, [2] short_circuit
--   0x08 : TXDATA - Byte to transmit
--   0x0C : RXDATA - Byte received
--   0x10 : BITCTRL- [0] send_bit, [1] bit_value, [2] read_bit
--   0x14 : BITSTAT- [0] bit_value_read
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity onewire_controller is
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
        ow_dq     : inout std_logic;  -- 1-Wire data line
        ow_irq    : out std_logic
    );
end entity onewire_controller;

architecture rtl of onewire_controller is
    signal enabled : std_logic := '0';
    signal stat_busy : std_logic := '0';
    signal presence : std_logic := '0';
    signal rx_data : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_data : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_read_val : std_logic := '0';

    signal ow_fsm : integer range 0 to 25 := 0;
    signal bit_cnt : integer range 0 to 7 := 0;
    signal timer_cnt : unsigned(19 downto 0) := (others => '0');
    signal ow_dq_out : std_logic := '1';
    signal ow_dq_oe : std_logic := '0';

    -- 1-Wire timing (at 1 MHz = 1us per tick)
    constant T_RESET_LOW   : integer := 480;  -- 480 us
    constant T_RESET_WAIT  : integer := 70;   -- 70 us
    constant T_RESET_READ  : integer := 410;  -- 410 us
    constant T_WRITE1_LOW  : integer := 6;    -- 6 us
    constant T_WRITE1_REL  : integer := 64;   -- 64 us
    constant T_WRITE0_LOW  : integer := 60;   -- 60 us
    constant T_WRITE0_REL  : integer := 10;   -- 10 us
    constant T_READ_LOW    : integer := 6;    -- 6 us
    constant T_READ_WAIT   : integer := 9;    -- 9 us
    constant T_READ_REL    : integer := 55;   -- 55 us

    signal reg_offset : std_logic_vector(7 downto 0);
    signal write_en   : std_logic;
    signal tick_cnt   : unsigned(7 downto 0) := (others => '0');

begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;

    -- 1 us tick generator (assuming 50 MHz = 20ns, so 50 ticks = 1us)
    tick_gen : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            tick_cnt <= (others => '0');
        elsif rising_edge(HCLK) then
            if tick_cnt = 49 then
                tick_cnt <= (others => '0');
            else
                tick_cnt <= tick_cnt + 1;
            end if;
        end if;
    end process;

    -- 1-Wire FSM
    ow_proc : process(HCLK, HRESETn)
        variable tick : boolean;
    begin
        if HRESETn = '0' then
            ow_fsm <= 0; stat_busy <= '0'; presence <= '0';
            timer_cnt <= (others => '0'); bit_cnt <= 0;
            ow_dq_out <= '1'; ow_dq_oe <= '0';
            rx_data <= (others => '0');
        elsif rising_edge(HCLK) then
            tick := (tick_cnt = 49);

            if write_en = '1' then
                case reg_offset is
                    when x"00" =>
                        enabled <= HWDATA(0);
                        if HWDATA(1) = '1' then  -- reset pulse
                            ow_fsm <= 1; stat_busy <= '1'; timer_cnt <= (others => '0');
                        end if;
                    when x"08" =>  -- TX byte
                        tx_data <= HWDATA(7 downto 0);
                        ow_fsm <= 10; stat_busy <= '1'; bit_cnt <= 0; timer_cnt <= (others => '0');
                    when x"10" =>  -- Bit control
                        if HWDATA(2) = '1' then  -- read bit
                            ow_fsm <= 20; stat_busy <= '1'; timer_cnt <= (others => '0');
                        elsif HWDATA(0) = '1' then  -- send bit
                            ow_dq_out <= HWDATA(1);
                            ow_fsm <= 15; stat_busy <= '1'; timer_cnt <= (others => '0');
                        end if;
                    when others => null;
                end case;
            end if;

            if tick then
                case ow_fsm is
                    -- Reset pulse
                    when 1 => ow_dq_out <= '0'; ow_dq_oe <= '1';
                              if timer_cnt >= T_RESET_LOW then ow_fsm <= 2; timer_cnt <= (others => '0'); end if;
                    when 2 => ow_dq_oe <= '0';  -- release
                              if timer_cnt >= T_RESET_WAIT then ow_fsm <= 3; timer_cnt <= (others => '0'); end if;
                    when 3 => presence <= not ow_dq;  -- sample presence
                              if timer_cnt >= T_RESET_READ then ow_fsm <= 0; stat_busy <= '0'; end if;
                    -- Write bit (0 or 1)
                    when 15 => ow_dq_out <= '0'; ow_dq_oe <= '1';
                               if timer_cnt >= T_WRITE0_LOW then ow_fsm <= 16; timer_cnt <= (others => '0'); end if;
                    when 16 => ow_dq_oe <= '0';
                               if timer_cnt >= T_WRITE0_REL then ow_fsm <= 0; stat_busy <= '0'; end if;
                    -- Write byte
                    when 10 => ow_dq_out <= tx_data(bit_cnt); ow_dq_oe <= '1';
                               if timer_cnt >= T_WRITE0_LOW then ow_fsm <= 11; timer_cnt <= (others => '0'); end if;
                    when 11 => ow_dq_oe <= '0';
                               if timer_cnt >= T_WRITE0_REL then
                                   if bit_cnt = 7 then ow_fsm <= 0; stat_busy <= '0';
                                   else bit_cnt <= bit_cnt + 1; ow_fsm <= 10; end if;
                                   timer_cnt <= (others => '0');
                               end if;
                    -- Read bit
                    when 20 => ow_dq_out <= '0'; ow_dq_oe <= '1';
                               if timer_cnt >= T_READ_LOW then ow_fsm <= 21; timer_cnt <= (others => '0'); end if;
                    when 21 => ow_dq_oe <= '0';
                               if timer_cnt >= T_READ_WAIT then ow_fsm <= 22; timer_cnt <= (others => '0'); end if;
                    when 22 => bit_read_val <= ow_dq;
                               if timer_cnt >= T_READ_REL then ow_fsm <= 0; stat_busy <= '0'; end if;
                    when others => null;
                end case;
                if ow_fsm /= 0 then
                    timer_cnt <= timer_cnt + 1;
                end if;
            end if;
        end if;
    end process ow_proc;

    -- 1-Wire bus driver
    ow_dq <= '0' when ow_dq_oe = '1' and ow_dq_out = '0' else 'Z';

    ahb_read : process(HSEL, HADDR, reg_offset, stat_busy, presence, rx_data, bit_read_val)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"04" => rdata(0) := stat_busy; rdata(1) := presence;
                when x"0C" => rdata := x"000000" & rx_data;
                when x"14" => rdata(0) := bit_read_val;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process;

    HRESP <= '0'; HREADYOUT <= '0' when stat_busy = '1' else '1';
    ow_irq <= '1' when (stat_busy = '0' and ow_fsm = 0 and presence = '1') else '0';

end architecture rtl;
