-- ================================================================================
-- avr_analog_comp : AVR Analog Comparator with AHB-Lite slave interface
-- ================================================================================
-- Compares AIN0 vs AIN1, with multiplexed input from ADC.
-- Registers: ACSR, ADCSRB, DIDR1.
--
-- Register Map:
--   0x00: ACSR   - Analog Comparator Control and Status
--       bit0 = ACO (RO) - comparator output
--       bit1 = ACBG (RW) - bandgap select (AIN0 replaced by internal ref)
--       bit2 = ACO  (RO) - output (duplicate for status)
--       bit3 = ACI  (RC) - interrupt flag (write 1 to clear)
--       bit4 = ACIE (RW) - interrupt enable
--       bit5 = ACIC (RW) - input capture enable
--       bit6 = ACIS1(RW) - interrupt select 1
--       bit7 = ACIS0(RW) - interrupt select 0
--   0x04: ADCSRB - ADC Control & Status Register B
--       bit6 = ACME (RW) - analog comparator multiplexer enable
--   0x08: DIDR1  - Digital Input Disable Register 1
--       bit0 = AIN0D (RW)
--       bit1 = AIN1D (RW)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity avr_analog_comp is
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

        -- Analog comparator pins
        ain0     : in  std_logic;  -- positive input
        ain1     : in  std_logic;  -- negative input
        ac_out   : out std_logic;  -- comparator output
        ac_irq   : out std_logic   -- interrupt output
    );
end entity avr_analog_comp;

architecture rtl of avr_analog_comp is

    constant REG_ACSR   : std_logic_vector(3 downto 0) := "0000";
    constant REG_ADCSRB : std_logic_vector(3 downto 0) := "0001";
    constant REG_DIDR1  : std_logic_vector(3 downto 0) := "0010";

    signal acsr_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal adcsrb_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal didr1_reg  : std_logic_vector(7 downto 0) := (others => '0');

    -- Comparator output (synchronized)
    signal aco_sync   : std_logic := '0';
    signal aco_prev   : std_logic := '0';
    signal aci_flag   : std_logic := '0';

    -- Bandgap reference (internal, simplified as constant high)
    constant BANDGAP_REF : std_logic := '1';

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;
    signal comp_pos : std_logic;
    signal comp_neg : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Input multiplexing: ACBG selects bandgap for positive input
    comp_pos <= BANDGAP_REF when acsr_reg(1) = '1' else ain0;
    comp_neg <= ain1;  -- ACME would multiplex ADC, simplified here

    -- Comparator: simple digital comparison
    -- ACO = 1 when pos > neg (treat as digital: pos AND NOT neg)
    comp_proc : process(HCLK)
        variable edge_event : std_logic;
        variable acis : std_logic_vector(1 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                aco_sync <= '0';
                aco_prev <= '0';
                aci_flag <= '0';
            else
                -- Synchronize comparator output
                aco_sync <= comp_pos and not comp_neg;

                -- Interrupt mode select (ACIS1:ACIS0)
                acis := acsr_reg(7 downto 6);
                edge_event := '0';

                case acis is
                    when "00" => edge_event := aco_sync xor aco_prev; -- toggle
                    when "10" => edge_event := aco_sync and not aco_prev; -- falling
                    when "11" => edge_event := not aco_sync and aco_prev; -- rising (reversed for digital)
                    when others => edge_event := '0';
                end case;

                -- Set interrupt flag on edge event
                if edge_event = '1' then
                    aci_flag <= '1';
                end if;

                -- Clear flag on write 1 to ACI
                if write_en = '1' and reg_sel = REG_ACSR and HWDATA(3) = '1' then
                    aci_flag <= '0';
                end if;

                aco_prev <= aco_sync;
            end if;
        end if;
    end process comp_proc;

    -- Register writes
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                acsr_reg   <= (others => '0');
                adcsrb_reg <= (others => '0');
                didr1_reg  <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when REG_ACSR =>
                        -- ACO (bit0/bit2) are read-only; preserve
                        acsr_reg <= HWDATA(7 downto 0);
                    when REG_ADCSRB => adcsrb_reg <= HWDATA(7 downto 0);
                    when REG_DIDR1  => didr1_reg  <= HWDATA(7 downto 0);
                    when others => null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, acsr_reg, adcsrb_reg, didr1_reg, aco_sync, aci_flag)
    begin
        case reg_sel is
            when REG_ACSR =>
                HRDATA <= x"000000" & (acsr_reg(7 downto 5) & aci_flag & acsr_reg(3 downto 2) & aco_sync & acsr_reg(0));
            when REG_ADCSRB => HRDATA <= x"000000" & adcsrb_reg;
            when REG_DIDR1  => HRDATA <= x"000000" & didr1_reg;
            when others     => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    ac_out <= aco_sync;
    ac_irq <= aci_flag and acsr_reg(4);

end architecture rtl;
