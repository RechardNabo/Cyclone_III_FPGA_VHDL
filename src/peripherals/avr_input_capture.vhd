-- ================================================================================
-- avr_input_capture : AVR Input Capture Unit (Timer1) with AHB-Lite slave
-- ================================================================================
-- Captures the 16-bit Timer1 value on an external event (rising/falling edge).
-- Registers: ICR_CTRL, ICR_STAT, ICR_VALUE, ICR_EDGE.
--
-- Register Map:
--   0x00: ICR_CTRL  - Control register
--       bit0 = capture_enable (RW)
--       bit1 = noise_canceler (RW)
--       bit2 = irq_enable (RW)
--   0x04: ICR_STAT  - Status register (RO)
--       bit0 = capture_flag
--       bit1 = overflow_flag
--   0x08: ICR_VALUE - Captured 16-bit timer value (RO)
--   0x0C: ICR_EDGE  - Edge select: 0=rising, 1=falling (RW)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity avr_input_capture is
    port (
        -- AHB-Lite slave interface
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

        -- Input capture pin and interrupt
        icp_pin   : in  std_logic;
        ic_irq    : out std_logic
    );
end entity avr_input_capture;

architecture rtl of avr_input_capture is

    constant REG_CTRL  : std_logic_vector(3 downto 0) := "0000";
    constant REG_STAT  : std_logic_vector(3 downto 0) := "0001";
    constant REG_VALUE : std_logic_vector(3 downto 0) := "0010";
    constant REG_EDGE  : std_logic_vector(3 downto 0) := "0011";

    signal ctrl_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal value_reg   : unsigned(15 downto 0) := (others => '0');
    signal edge_reg    : std_logic := '0'; -- 0=rising, 1=falling
    signal capture_flag: std_logic := '0';
    signal overflow_flag: std_logic := '0';

    -- Internal free-running timer (simulates Timer1)
    signal timer1_cnt  : unsigned(15 downto 0) := (others => '0');

    -- Edge detection
    signal icp_sync    : std_logic := '0';
    signal icp_prev    : std_logic := '0';
    signal noise_filter: std_logic_vector(3 downto 0) := (others => '0');

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Free-running timer1
    timer_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                timer1_cnt <= (others => '0');
                overflow_flag <= '0';
            else
                if timer1_cnt = x"FFFF" then
                    timer1_cnt <= (others => '0');
                    overflow_flag <= '1';
                else
                    timer1_cnt <= timer1_cnt + 1;
                end if;
            end if;
        end if;
    end process timer_proc;

    -- Edge detection and capture
    capture_proc : process(HCLK)
        variable edge_detected : std_logic;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                icp_sync <= '0';
                icp_prev <= '0';
                noise_filter <= (others => '0');
                capture_flag <= '0';
                value_reg <= (others => '0');
            else
                -- Synchronize input through 2 FFs
                icp_sync <= icp_pin;

                -- Noise canceler: 4-cycle stable filter
                if ctrl_reg(1) = '1' then
                    noise_filter <= noise_filter(2 downto 0) & icp_sync;
                    if noise_filter = "1111" and icp_prev = '0' then
                        edge_detected := '1';
                    elsif noise_filter = "0000" and icp_prev = '1' then
                        edge_detected := '1';
                    else
                        edge_detected := '0';
                    end if;
                else
                    -- Direct edge detection
                    if edge_reg = '0' then
                        edge_detected := icp_sync and not icp_prev; -- rising
                    else
                        edge_detected := not icp_sync and icp_prev; -- falling
                    end if;
                end if;

                icp_prev <= icp_sync;

                -- Capture timer value on detected edge
                if ctrl_reg(0) = '1' and edge_detected = '1' then
                    value_reg <= timer1_cnt;
                    capture_flag <= '1';
                end if;

                -- Clear flag on write to STAT with bit0=1
                if write_en = '1' and reg_sel = REG_STAT and HWDATA(0) = '1' then
                    capture_flag <= '0';
                end if;
                if write_en = '1' and reg_sel = REG_STAT and HWDATA(1) = '1' then
                    overflow_flag <= '0';
                end if;
            end if;
        end if;
    end process capture_proc;

    -- Register writes
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg <= (others => '0');
                edge_reg <= '0';
            elsif write_en = '1' then
                case reg_sel is
                    when REG_CTRL => ctrl_reg <= HWDATA(7 downto 0);
                    when REG_EDGE => edge_reg <= HWDATA(0);
                    when others => null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, value_reg, edge_reg, capture_flag, overflow_flag)
    begin
        case reg_sel is
            when REG_CTRL  => HRDATA <= x"000000" & ctrl_reg;
            when REG_STAT  => HRDATA <= x"000000" & "000000" & overflow_flag & capture_flag;
            when REG_VALUE => HRDATA <= x"0000" & std_logic_vector(value_reg);
            when REG_EDGE  => HRDATA <= x"0000000" & "000" & edge_reg;
            when others    => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    ic_irq <= capture_flag and ctrl_reg(2);

end architecture rtl;
