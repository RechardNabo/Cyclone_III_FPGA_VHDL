-- ================================================================================
-- msp430_bor : MSP430 Brown-Out Reset controller with AHB-Lite slave interface
-- ================================================================================
-- Programmable threshold brown-out detection with interrupt and reset output.
-- Registers: BOR_CTRL, BOR_STAT, BOR_THR.
--
-- Register Map:
--   0x00: BOR_CTRL - Control register
--       bit0 = BOREN (RW) - BOR enable
--       bit1 = BORIE (RW) - BOR interrupt enable
--       bit2 = BORRST (RW) - BOR reset enable
--       bit3 = BORFS (RW) - fast sampling mode
--   0x04: BOR_STAT - Status register (RO)
--       bit0 = bor_active (brown-out detected)
--       bit1 = bor_irq_pending
--       bit2 = bor_reset_pending
--   0x08: BOR_THR  - Programmable threshold (RW, 8-bit)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity msp430_bor is
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

        -- BOR outputs
        bor_out : out std_logic;  -- brown-out detected (active high)
        bor_irq : out std_logic   -- interrupt output
    );
end entity msp430_bor;

architecture rtl of msp430_bor is

    constant REG_BOR_CTRL : std_logic_vector(3 downto 0) := "0000";
    constant REG_BOR_STAT : std_logic_vector(3 downto 0) := "0001";
    constant REG_BOR_THR  : std_logic_vector(3 downto 0) := "0010";

    signal ctrl_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal thr_reg  : std_logic_vector(7 downto 0) := x"80"; -- default threshold
    signal bor_active : std_logic := '0';
    signal irq_pending : std_logic := '0';
    signal reset_pending : std_logic := '0';

    -- Simulated supply voltage level (for educational purposes)
    -- In real hardware, this would come from an analog comparator
    signal vcc_level : unsigned(7 downto 0) := x"C0"; -- nominal 75% of max
    signal sample_cnt : unsigned(15 downto 0) := (others => '0');

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- BOR monitoring process
    bor_proc : process(HCLK)
        variable sample_max : unsigned(15 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg <= (others => '0');
                thr_reg  <= x"80";
                bor_active <= '0';
                irq_pending <= '0';
                reset_pending <= '0';
                sample_cnt <= (others => '0');
            else
                -- Register writes
                if write_en = '1' then
                    case reg_sel is
                        when REG_BOR_CTRL => ctrl_reg <= HWDATA(7 downto 0);
                        when REG_BOR_THR  => thr_reg  <= HWDATA(7 downto 0);
                        when others => null;
                    end case;
                end if;

                -- Sampling rate: fast mode = every 16 cycles, normal = every 4096
                if ctrl_reg(3) = '1' then
                    sample_max := to_unsigned(15, 16);
                else
                    sample_max := to_unsigned(4095, 16);
                end if;

                if sample_cnt = sample_max then
                    sample_cnt <= (others => '0');
                    -- Check if supply voltage is below threshold
                    if vcc_level < unsigned(thr_reg) then
                        if bor_active = '0' then
                            bor_active <= '1';
                            if ctrl_reg(1) = '1' then
                                irq_pending <= '1';
                            end if;
                            if ctrl_reg(2) = '1' then
                                reset_pending <= '1';
                            end if;
                        end if;
                    else
                        bor_active <= '0';
                    end if;
                else
                    sample_cnt <= sample_cnt + 1;
                end if;

                -- Clear IRQ on status read with clear bit
                if write_en = '1' and reg_sel = REG_BOR_STAT and HWDATA(0) = '1' then
                    irq_pending <= '0';
                end if;
                if write_en = '1' and reg_sel = REG_BOR_STAT and HWDATA(1) = '1' then
                    reset_pending <= '0';
                end if;
            end if;
        end if;
    end process bor_proc;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, thr_reg, bor_active, irq_pending, reset_pending)
    begin
        case reg_sel is
            when REG_BOR_CTRL => HRDATA <= x"000000" & ctrl_reg;
            when REG_BOR_STAT => HRDATA <= x"000000" & "00000" & reset_pending & irq_pending & bor_active;
            when REG_BOR_THR  => HRDATA <= x"000000" & thr_reg;
            when others       => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    bor_out <= bor_active and ctrl_reg(0);
    bor_irq <= irq_pending and ctrl_reg(1);

end architecture rtl;
