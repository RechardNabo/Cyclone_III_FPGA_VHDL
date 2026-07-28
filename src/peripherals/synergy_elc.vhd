-- ================================================================================
-- synergy_elc : Event Link Controller
-- ================================================================================
-- Renesas Synergy-style ELC for Cyclone III FPGA.
--
-- Features:
--   * Routes hardware events between peripherals without CPU intervention
--   * 32 event sources (input)
--   * 32 event destinations (output)
--   * 4 event link setting registers (ELSR0-3) mapping events to destinations
--   * Event detection with interrupt
--
-- Register Map:
--   0x00: ELC_CTRL - bit0=enable
--   0x04: ELC_STAT - bit0=event_detected (write-1-to-clear)
--   0x08: ELSR0    - event link setting 0 (maps source to dest group 0)
--   0x0C: ELSR1    - event link setting 1
--   0x10: ELSR2    - event link setting 2
--   0x14: ELSR3    - event link setting 3
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_elc is
    port (
        -- AHB-Lite slave interface
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;
        HSEL      : in  std_logic;
        HWRITE    : in  std_logic;
        HREADY    : in  std_logic;
        HTRANS    : in  std_logic_vector(1 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;
        HREADYOUT : out std_logic;

        -- Event interface
        elc_event_in  : in  std_logic_vector(31 downto 0);  -- 32 event sources
        elc_event_out : out std_logic_vector(31 downto 0)   -- 32 event destinations
    );
end entity synergy_elc;

architecture rtl of synergy_elc is

    constant REG_ELC_CTRL : std_logic_vector(3 downto 0) := "0000";
    constant REG_ELC_STAT : std_logic_vector(3 downto 0) := "0001";
    constant REG_ELSR0    : std_logic_vector(3 downto 0) := "0010";
    constant REG_ELSR1    : std_logic_vector(3 downto 0) := "0011";
    constant REG_ELSR2    : std_logic_vector(3 downto 0) := "0100";
    constant REG_ELSR3    : std_logic_vector(3 downto 0) := "0101";

    signal elc_ctrl : std_logic_vector(31 downto 0) := (others => '0');
    signal elc_stat : std_logic_vector(31 downto 0) := (others => '0');

    -- Each ELSR maps a 5-bit event source to a 5-bit event destination
    -- bits[4:0] = source index, bits[12:8] = destination index
    -- bit16 = link enable
    type elsr_t is array(0 to 3) of std_logic_vector(31 downto 0);
    signal elsr : elsr_t := (others => (others => '0'));

    signal event_out_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal event_prev    : std_logic_vector(31 downto 0) := (others => '0');

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                elc_ctrl <= (others => '0');
                elc_stat <= (others => '0');
                elsr     <= (others => (others => '0'));
            elsif write_en = '1' then
                case reg_sel is
                    when REG_ELC_CTRL =>
                        elc_ctrl <= HWDATA;
                    when REG_ELC_STAT =>
                        if HWDATA(0) = '1' then
                            elc_stat(0) <= '0';
                        end if;
                    when REG_ELSR0 =>
                        elsr(0) <= HWDATA;
                    when REG_ELSR1 =>
                        elsr(1) <= HWDATA;
                    when REG_ELSR2 =>
                        elsr(2) <= HWDATA;
                    when REG_ELSR3 =>
                        elsr(3) <= HWDATA;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Event routing process
    event_route : process(HCLK)
        variable src_idx : integer range 0 to 31;
        variable dst_idx : integer range 0 to 31;
        variable event_detected : std_logic;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                event_out_reg <= (others => '0');
                event_prev    <= (others => '0');
                elc_stat(0)   <= '0';
            elsif elc_ctrl(0) = '1' then
                event_detected := '0';
                event_out_reg  <= (others => '0');

                -- Check each ELSR for rising-edge event
                for i in 0 to 3 loop
                    if elsr(i)(16) = '1' then  -- link enabled
                        src_idx := to_integer(unsigned(elsr(i)(4 downto 0)));
                        dst_idx := to_integer(unsigned(elsr(i)(12 downto 8)));
                        -- Rising edge detection on event source
                        if elc_event_in(src_idx) = '1' and event_prev(src_idx) = '0' then
                            event_out_reg(dst_idx) <= '1';
                            event_detected := '1';
                        end if;
                    end if;
                end loop;

                if event_detected = '1' then
                    elc_stat(0) <= '1';
                end if;

                event_prev <= elc_event_in;
            end if;
        end if;
    end process event_route;

    -- Register read mux
    reg_read : process(reg_sel, elc_ctrl, elc_stat, elsr)
    begin
        case reg_sel is
            when REG_ELC_CTRL => HRDATA <= elc_ctrl;
            when REG_ELC_STAT => HRDATA <= elc_stat;
            when REG_ELSR0    => HRDATA <= elsr(0);
            when REG_ELSR1    => HRDATA <= elsr(1);
            when REG_ELSR2    => HRDATA <= elsr(2);
            when REG_ELSR3    => HRDATA <= elsr(3);
            when others       => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    elc_event_out <= event_out_reg;

end architecture rtl;
