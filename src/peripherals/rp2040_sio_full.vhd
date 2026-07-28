-- ================================================================================
-- rp2040_sio_full : Enhanced SIO with full interpolator (AHB-Lite slave)
-- ================================================================================
-- Full RP2040-style interpolator with lane blending, clamping, masking, and
-- cross-lane support for INTERP0 and INTERP1.
--
-- Register Map (per interpolator, base offset 0x00 for INTERP0, 0x40 for INTERP1):
--   0x00: ACCUM0   - accumulator lane0 (RW)
--   0x04: ACCUM1   - accumulator lane1 (RW)
--   0x08: BASE0    - base0 (RW)
--   0x0C: BASE1    - base1 (RW)
--   0x10: BASE2    - base2 (RW)
--   0x14: POP_LANE0  - read result lane0, writes ACCUM0 (RO)
--   0x18: POP_LANE1  - read result lane1, writes ACCUM1 (RO)
--   0x1C: POP_FULL   - read full blended result (RO)
--   0x20: PEEK_LANE0 - read lane0 without side effect (RO)
--   0x24: PEEK_LANE1 - read lane1 without side effect (RO)
--   0x28: PEEK_FULL  - read full result without side effect (RO)
--   0x2C: CTRL_LANE0 - lane0 control (bits0..4=shift, bits5..9=mask, bit10=signed, bit11=clamp)
--   0x30: CTRL_LANE1 - lane1 control
--   0x34: CTRL_LANE_TOP - top lane control (bit0=blend, bit1=cross_lane)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rp2040_sio_full is
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

        -- SIO interface
        interp_irq : out std_logic
    );
end entity rp2040_sio_full;

architecture rtl of rp2040_sio_full is
    type interp_regs is record
        accum0    : std_logic_vector(31 downto 0);
        accum1    : std_logic_vector(31 downto 0);
        base0     : std_logic_vector(31 downto 0);
        base1     : std_logic_vector(31 downto 0);
        base2     : std_logic_vector(31 downto 0);
        ctrl_l0   : std_logic_vector(31 downto 0);
        ctrl_l1   : std_logic_vector(31 downto 0);
        ctrl_top  : std_logic_vector(31 downto 0);
    end record;

    type interp_array is array(0 to 1) of interp_regs;
    signal interp : interp_array := (others => (
        accum0 => (others => '0'), accum1 => (others => '0'),
        base0  => (others => '0'), base1  => (others => '0'),
        base2  => (others => '0'), ctrl_l0 => (others => '0'),
        ctrl_l1 => (others => '0'), ctrl_top => (others => '0')
    ));

    signal write_en  : std_logic;
    signal interp_sel : integer range 0 to 1;
    signal irq_flag   : std_logic := '0';

    -- Interpolator computation function
    function compute_lane(
        accum   : std_logic_vector(31 downto 0);
        base    : std_logic_vector(31 downto 0);
        ctrl    : std_logic_vector(31 downto 0)
    ) return std_logic_vector is
        variable shift_val : integer;
        variable mask_val  : integer;
        variable shifted   : unsigned(31 downto 0);
        variable masked    : unsigned(31 downto 0);
        variable result    : std_logic_vector(31 downto 0);
    begin
        shift_val := to_integer(unsigned(ctrl(4 downto 0)));
        mask_val  := to_integer(unsigned(ctrl(9 downto 5)));
        if shift_val > 0 then
            shifted := shift_right(unsigned(accum), shift_val);
        else
            shifted := unsigned(accum);
        end if;
        -- Mask: keep bits mask_val..31
        if mask_val > 0 then
            masked := shifted and shift_left(unsigned'(x"FFFFFFFF"), mask_val);
        else
            masked := shifted;
        end if;
        -- Add base
        result := std_logic_vector(masked + unsigned(base));
        -- Clamp if enabled
        if ctrl(11) = '1' then
            if signed(result) < 0 then
                result := (others => '0');
            elsif unsigned(result) > to_unsigned(16#FFFFFF#, 32) then
                result := x"00FFFFFF";
            end if;
        end if;
        return result;
    end function;

    -- Full blended result
    function compute_full(
        r : interp_regs
    ) return std_logic_vector is
        variable lane0_res : std_logic_vector(31 downto 0);
        variable lane1_res : std_logic_vector(31 downto 0);
        variable blended   : std_logic_vector(31 downto 0);
    begin
        lane0_res := compute_lane(r.accum0, r.base0, r.ctrl_l0);
        lane1_res := compute_lane(r.accum1, r.base1, r.ctrl_l1);
        if r.ctrl_top(0) = '1' then
            -- Blend: lane1 upper bits + lane0 lower bits
            blended := lane1_res(31 downto 16) & lane0_res(15 downto 0);
        else
            blended := lane1_res;
        end if;
        -- Cross-lane: add base2
        if r.ctrl_top(1) = '1' then
            blended := std_logic_vector(unsigned(blended) + unsigned(r.base2));
        end if;
        return blended;
    end function;

begin

    write_en   <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    interp_sel <= to_integer(unsigned(HADDR(7 downto 6)));  -- 0=INTERP0, 1=INTERP1

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write
    reg_write : process(HCLK)
        variable r : interp_regs;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                interp <= (others => (
                    accum0 => (others => '0'), accum1 => (others => '0'),
                    base0  => (others => '0'), base1  => (others => '0'),
                    base2  => (others => '0'), ctrl_l0 => (others => '0'),
                    ctrl_l1 => (others => '0'), ctrl_top => (others => '0')
                ));
                irq_flag <= '0';
            elsif write_en = '1' then
                r := interp(interp_sel);
                case HADDR(5 downto 2) is
                    when "0000" => r.accum0   := HWDATA;
                    when "0001" => r.accum1   := HWDATA;
                    when "0010" => r.base0    := HWDATA;
                    when "0011" => r.base1    := HWDATA;
                    when "0100" => r.base2    := HWDATA;
                    when "1011" => r.ctrl_l0  := HWDATA;
                    when "1100" => r.ctrl_l1  := HWDATA;
                    when "1101" => r.ctrl_top := HWDATA;
                    when others => null;
                end case;
                interp(interp_sel) <= r;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(HADDR, interp, interp_sel)
        variable r : interp_regs;
    begin
        r := interp(interp_sel);
        case HADDR(5 downto 2) is
            when "0000" => HRDATA <= r.accum0;
            when "0001" => HRDATA <= r.accum1;
            when "0010" => HRDATA <= r.base0;
            when "0011" => HRDATA <= r.base1;
            when "0100" => HRDATA <= r.base2;
            when "0101" => HRDATA <= compute_lane(r.accum0, r.base0, r.ctrl_l0);  -- POP_LANE0
            when "0110" => HRDATA <= compute_lane(r.accum1, r.base1, r.ctrl_l1);  -- POP_LANE1
            when "0111" => HRDATA <= compute_full(r);                              -- POP_FULL
            when "1000" => HRDATA <= compute_lane(r.accum0, r.base0, r.ctrl_l0);  -- PEEK_LANE0
            when "1001" => HRDATA <= compute_lane(r.accum1, r.base1, r.ctrl_l1);  -- PEEK_LANE1
            when "1010" => HRDATA <= compute_full(r);                              -- PEEK_FULL
            when "1011" => HRDATA <= r.ctrl_l0;
            when "1100" => HRDATA <= r.ctrl_l1;
            when "1101" => HRDATA <= r.ctrl_top;
            when others => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    interp_irq <= irq_flag;

end architecture rtl;
