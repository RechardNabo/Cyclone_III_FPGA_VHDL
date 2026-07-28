-- ================================================================================
-- fpga_dsp_block : DSP block wrapper for multiply-accumulate
-- ================================================================================
-- Wraps Cyclone III embedded multiplier blocks for MAC operations.
--
-- Features:
--   * 18x18 signed multiply with 36-bit accumulator
--   * Accumulate, clear, and subtract modes
--   * Pipeline registers for maximum clock frequency
--   * Interrupt on operation complete
--
-- Register Map:
--   0x00: OP_A    - 18-bit signed operand A
--   0x04: OP_B    - 18-bit signed operand B
--   0x08: OP_C    - 18-bit signed operand C (for subtract mode)
--   0x0C: ACC_LO  - accumulator low 32 bits (RO, write to load)
--   0x10: ACC_HI  - accumulator high 4 bits (RO, write to load)
--   0x14: CTRL    - bit0=start, bit1=accumulate, bit2=clear, bit3=subtract, bit4=irq_en
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fpga_dsp_block is
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

        -- DSP interrupt
        dsp_irq   : out std_logic
    );
end entity fpga_dsp_block;

architecture rtl of fpga_dsp_block is

    constant REG_OP_A   : std_logic_vector(3 downto 0) := "0000";
    constant REG_OP_B   : std_logic_vector(3 downto 0) := "0001";
    constant REG_OP_C   : std_logic_vector(3 downto 0) := "0010";
    constant REG_ACC_LO : std_logic_vector(3 downto 0) := "0011";
    constant REG_ACC_HI : std_logic_vector(3 downto 0) := "0100";
    constant REG_CTRL   : std_logic_vector(3 downto 0) := "0101";

    signal op_a    : signed(17 downto 0) := (others => '0');
    signal op_b    : signed(17 downto 0) := (others => '0');
    signal op_c    : signed(17 downto 0) := (others => '0');
    signal acc_lo  : signed(31 downto 0) := (others => '0');
    signal acc_hi  : signed(3 downto 0)  := (others => '0');
    signal ctrl    : std_logic_vector(31 downto 0) := (others => '0');

    signal mult_result : signed(35 downto 0) := (others => '0');
    signal acc_full    : signed(35 downto 0) := (others => '0');
    signal done_flag   : std_logic := '0';

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Combine accumulator halves
    acc_full <= acc_hi & acc_lo;

    -- Register write process
    reg_write : process(HCLK)
        variable new_acc : signed(35 downto 0);
        variable product : signed(35 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                op_a   <= (others => '0');
                op_b   <= (others => '0');
                op_c   <= (others => '0');
                acc_lo <= (others => '0');
                acc_hi <= (others => '0');
                ctrl   <= (others => '0');
                done_flag <= '0';
            elsif write_en = '1' then
                case reg_sel is
                    when REG_OP_A =>
                        op_a <= signed(HWDATA(17 downto 0));
                    when REG_OP_B =>
                        op_b <= signed(HWDATA(17 downto 0));
                    when REG_OP_C =>
                        op_c <= signed(HWDATA(17 downto 0));
                    when REG_ACC_LO =>
                        acc_lo <= signed(HWDATA);
                    when REG_ACC_HI =>
                        acc_hi <= signed(HWDATA(3 downto 0));
                    when REG_CTRL =>
                        ctrl <= HWDATA;
                        if HWDATA(2) = '1' then
                            -- Clear accumulator
                            acc_lo <= (others => '0');
                            acc_hi <= (others => '0');
                        elsif HWDATA(0) = '1' then
                            -- Start MAC operation
                            product := op_a * op_b;
                            if HWDATA(3) = '1' then
                                -- Subtract mode: acc = acc - product + C
                                new_acc := acc_full - product + resize(op_c, 36);
                            elsif HWDATA(1) = '1' then
                                -- Accumulate mode: acc = acc + product
                                new_acc := acc_full + product;
                            else
                                -- Multiply only: acc = product
                                new_acc := product;
                            end if;
                            acc_lo <= new_acc(31 downto 0);
                            acc_hi <= new_acc(35 downto 32);
                            done_flag <= '1';
                        end if;
                    when others =>
                        null;
                end case;
            elsif done_flag = '1' then
                done_flag <= '0';  -- single-cycle pulse
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, op_a, op_b, op_c, acc_lo, acc_hi, ctrl, done_flag)
    begin
        case reg_sel is
            when REG_OP_A =>
                HRDATA <= std_logic_vector(resize(op_a, 32));
            when REG_OP_B =>
                HRDATA <= std_logic_vector(resize(op_b, 32));
            when REG_OP_C =>
                HRDATA <= std_logic_vector(resize(op_c, 32));
            when REG_ACC_LO =>
                HRDATA <= std_logic_vector(acc_lo);
            when REG_ACC_HI =>
                HRDATA <= std_logic_vector(resize(acc_hi, 32));
            when REG_CTRL =>
                HRDATA <= ctrl;
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    dsp_irq <= done_flag and ctrl(4);

end architecture rtl;
