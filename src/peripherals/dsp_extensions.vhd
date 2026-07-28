-- ================================================================================
-- dsp_extensions : DSP instruction accelerator with AHB-Lite slave interface
-- ================================================================================
-- Cortex-M4 SIMD DSP accelerator for saturating arithmetic and MAC operations.
--
-- Supported operations (selected via OP code in CTRL[3:0]):
--   0x0 __SADD   0x1 __SSUB   0x2 __SMUL   0x3 __SMLAL
--   0x4 __QADD   0x5 __QSUB   0x6 __SSAT   0x7 __USAT
--   0x8 __SMLAD  0x9 __SMLSDX 0xA __SMUAD  0xB __SMUSD
--
-- Register Map:
--   0x00: CTRL        - bit[3:0]=op, bit[4]=start, bit[7]=irq_en, bit[15:8]=sat_bits
--   0x04: STAT        - bit0=done, bit1=sat_flag
--   0x08: OP_A        - operand A (32-bit)
--   0x0C: OP_B        - operand B (32-bit)
--   0x10: OP_C        - operand C (accumulator)
--   0x14: RESULT_LO   - result low word
--   0x18: RESULT_HI   - result high word
--   0x1C: SAT_FLAG    - saturation flag (RO)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dsp_extensions is
    port (
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
        dsp_irq   : out std_logic
    );
end entity dsp_extensions;

architecture rtl of dsp_extensions is
    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal stat_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal op_a_reg    : signed(31 downto 0) := (others => '0');
    signal op_b_reg    : signed(31 downto 0) := (others => '0');
    signal op_c_reg    : signed(31 downto 0) := (others => '0');
    signal result_lo   : std_logic_vector(31 downto 0) := (others => '0');
    signal result_hi   : std_logic_vector(31 downto 0) := (others => '0');
    signal sat_flag    : std_logic := '0';
    signal reg_sel     : std_logic_vector(3 downto 0);
    signal write_en    : std_logic;

    function sat_signed(val : signed(31 downto 0); n : integer) return signed is
        variable max_v, min_v : signed(31 downto 0);
    begin
        if n >= 31 then return val; end if;
        max_v := shift_left(to_signed(1, 32), n - 1) - 1;
        min_v := -shift_left(to_signed(1, 32), n - 1);
        if val > max_v then return max_v;
        elsif val < min_v then return min_v;
        else return val; end if;
    end function;

    function sat_unsigned(val : signed(31 downto 0); n : integer) return unsigned is
        variable max_v : signed(31 downto 0);
    begin
        if n >= 32 then return unsigned(val); end if;
        max_v := shift_left(to_signed(1, 32), n) - 1;
        if val > max_v then return unsigned(max_v);
        elsif val < 0 then return to_unsigned(0, val'length);
        else return unsigned(val); end if;
    end function;

    function qadd(a, b : signed(31 downto 0)) return signed is
        variable sum : signed(32 downto 0);
    begin
        sum := resize(a, 33) + resize(b, 33);
        if sum > 2147483647 then return x"7FFFFFFF";
        elsif sum < -2147483648 then return x"80000000";
        else return sum(31 downto 0); end if;
    end function;

    function qsub(a, b : signed(31 downto 0)) return signed is
        variable diff : signed(32 downto 0);
    begin
        diff := resize(a, 33) - resize(b, 33);
        if diff > 2147483647 then return x"7FFFFFFF";
        elsif diff < -2147483648 then return x"80000000";
        else return diff(31 downto 0); end if;
    end function;

begin
    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    HREADYOUT <= '1';
    HRESP     <= '0';

    dsp_proc : process(HCLK)
        variable op, sat_bits : integer;
        variable prod64       : signed(63 downto 0);
        variable a16_lo, a16_hi, b16_lo, b16_hi : signed(15 downto 0);
        variable dual_sum     : signed(32 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                stat_reg  <= (others => '0');
                result_lo <= (others => '0');
                result_hi <= (others => '0');
                sat_flag  <= '0';
            elsif ctrl_reg(4) = '1' then
                op       := to_integer(unsigned(ctrl_reg(3 downto 0)));
                sat_bits := to_integer(unsigned(ctrl_reg(15 downto 8)));
                sat_flag <= '0';
                case op is
                    when 0 =>  -- __SADD
                        result_lo <= std_logic_vector(op_a_reg + op_b_reg);
                        result_hi <= (others => '0');
                    when 1 =>  -- __SSUB
                        result_lo <= std_logic_vector(op_a_reg - op_b_reg);
                        result_hi <= (others => '0');
                    when 2 =>  -- __SMUL
                        prod64 := op_a_reg * op_b_reg;
                        result_lo <= std_logic_vector(prod64(31 downto 0));
                        result_hi <= std_logic_vector(prod64(63 downto 32));
                    when 3 =>  -- __SMLAL
                        prod64 := op_a_reg * op_b_reg + resize(op_c_reg, 64);
                        result_lo <= std_logic_vector(prod64(31 downto 0));
                        result_hi <= std_logic_vector(prod64(63 downto 32));
                    when 4 =>  -- __QADD
                        result_lo <= std_logic_vector(qadd(op_a_reg, op_b_reg));
                        if (op_a_reg(31) = op_b_reg(31)) and
                           (qadd(op_a_reg, op_b_reg)(31) /= op_a_reg(31))
                           then sat_flag <= '1'; end if;
                    when 5 =>  -- __QSUB
                        result_lo <= std_logic_vector(qsub(op_a_reg, op_b_reg));
                        if (op_a_reg(31) /= op_b_reg(31)) and
                           (qsub(op_a_reg, op_b_reg)(31) /= op_a_reg(31))
                           then sat_flag <= '1'; end if;
                    when 6 =>  -- __SSAT
                        result_lo <= std_logic_vector(sat_signed(op_a_reg, sat_bits));
                        if sat_signed(op_a_reg, sat_bits) /= op_a_reg then
                            sat_flag <= '1'; end if;
                    when 7 =>  -- __USAT
                        result_lo <= std_logic_vector(sat_unsigned(op_a_reg, sat_bits));
                        if (op_a_reg < 0) or
                           (op_a_reg > sat_signed(op_a_reg, sat_bits)) then
                            sat_flag <= '1'; end if;
                    when 8 | 9 | 10 | 11 =>  -- dual 16-bit ops
                        a16_lo := op_a_reg(15 downto 0);
                        a16_hi := op_a_reg(31 downto 16);
                        b16_lo := op_b_reg(15 downto 0);
                        b16_hi := op_b_reg(31 downto 16);
                        case op is
                            when 8 =>  -- __SMLAD
                                dual_sum := resize(a16_lo*b16_lo, 33) +
                                            resize(a16_hi*b16_hi, 33) +
                                            resize(op_c_reg, 33);
                            when 9 =>  -- __SMLSDX
                                dual_sum := resize(a16_lo*b16_hi, 33) +
                                            resize(a16_hi*b16_lo, 33) +
                                            resize(op_c_reg, 33);
                            when 10 => -- __SMUAD
                                dual_sum := resize(a16_lo*b16_lo, 33) +
                                            resize(a16_hi*b16_hi, 33);
                            when others => -- __SMUSD
                                dual_sum := resize(a16_lo*b16_lo, 33) -
                                            resize(a16_hi*b16_hi, 33);
                        end case;
                        result_lo <= std_logic_vector(dual_sum(31 downto 0));
                        result_hi <= (others => '0');
                    when others => null;
                end case;
                stat_reg(0) <= '1';
            else
                stat_reg(0) <= '0';
            end if;
        end if;
    end process dsp_proc;

    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg <= (others => '0');
                op_a_reg <= (others => '0');
                op_b_reg <= (others => '0');
                op_c_reg <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when "0000" => ctrl_reg <= HWDATA;
                    when "0010" => op_a_reg <= signed(HWDATA);
                    when "0011" => op_b_reg <= signed(HWDATA);
                    when "0100" => op_c_reg <= signed(HWDATA);
                    when others => null;
                end case;
            end if;
        end if;
    end process reg_write;

    reg_read : process(reg_sel, ctrl_reg, stat_reg, op_a_reg, op_b_reg,
                       op_c_reg, result_lo, result_hi, sat_flag)
    begin
        case reg_sel is
            when "0000" => HRDATA <= ctrl_reg;
            when "0001" => HRDATA <= stat_reg;
            when "0010" => HRDATA <= std_logic_vector(op_a_reg);
            when "0011" => HRDATA <= std_logic_vector(op_b_reg);
            when "0100" => HRDATA <= std_logic_vector(op_c_reg);
            when "0101" => HRDATA <= result_lo;
            when "0110" => HRDATA <= result_hi;
            when "0111" => HRDATA <= (0 => sat_flag, others => '0');
            when others => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    dsp_irq <= stat_reg(0) and ctrl_reg(7);

end architecture rtl;
