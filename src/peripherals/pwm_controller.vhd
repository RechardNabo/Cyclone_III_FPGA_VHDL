-- ================================================================================
-- pwm_controller : RP2040-style 16-channel PWM controller
-- ================================================================================
-- Implements 16 PWM slices, each with:
--   * 16-bit counter (CSR, DIV, CTR, CC)
--   * A/B outputs per slice (32 PWM channels total)
--   * Programmable divider, top, and compare values
--   * Phase-correct mode option
--
-- AHB-Lite register map (per slice, 4 slices x 4 = 16 bytes per slice group):
--   0x00 : CSR   - Control/Status (enable, phase_correct, polarity A/B)
--   0x04 : DIV   - Clock divider (8.4 fixed point, integer + fractional)
--   0x08 : CTR   - Counter top value
--   0x0C : CC    - Counter compare (A:B, 16 bits each)
--
-- 16 slices mapped at base + (slice_idx * 0x10)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pwm_controller is
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

        -- PWM outputs (16 slices x 2 = 32 channels)
        pwm_out   : out std_logic_vector(31 downto 0);

        -- PWM interrupt
        pwm_int   : out std_logic
    );
end entity pwm_controller;

architecture rtl of pwm_controller is

    constant NUM_SLICES : integer := 16;

    -- Per-slice registers
    type pwm_slice_t is record
        csr           : std_logic_vector(7 downto 0);  -- enable, phase_correct, polA, polB
        div_int       : unsigned(7 downto 0);           -- integer divider
        div_frac      : unsigned(3 downto 0);           -- fractional divider
        ctr_top       : unsigned(15 downto 0);          -- counter top
        cc_a          : unsigned(15 downto 0);          -- compare A
        cc_b          : unsigned(15 downto 0);          -- compare B
        counter       : unsigned(15 downto 0);          -- current counter
        div_counter   : unsigned(11 downto 0);          -- divider counter
        frac_accum    : unsigned(3 downto 0);           -- fractional accumulator
    end record;

    type pwm_array_t is array(0 to NUM_SLICES-1) of pwm_slice_t;

    signal slices : pwm_array_t;

    -- PWM output registers
    signal pwm_out_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal pwm_int_reg : std_logic := '0';

    -- Address decode
    signal slice_idx  : integer range 0 to NUM_SLICES-1;
    signal reg_offset : std_logic_vector(3 downto 0);
    signal write_en   : std_logic;

    -- Default slice
    function init_slice return pwm_slice_t is
        variable s : pwm_slice_t;
    begin
        s.csr         := (others => '0');
        s.div_int     := to_unsigned(1, 8);
        s.div_frac    := (others => '0');
        s.ctr_top     := x"FFFF";
        s.cc_a        := (others => '0');
        s.cc_b        := (others => '0');
        s.counter     := (others => '0');
        s.div_counter := (others => '0');
        s.frac_accum  := (others => '0');
        return s;
    end function;

begin

    -- Address decode: HADDR[7:4] = slice index, HADDR[3:2] = register
    slice_idx  <= to_integer(unsigned(HADDR(7 downto 4)));
    reg_offset <= HADDR(3 downto 2) & "00";
    write_en   <= HSEL and HREADY and HWRITE;

    -- ========================================================================
    -- AHB-Lite register write
    -- ========================================================================
    ahb_write : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            for i in 0 to NUM_SLICES-1 loop
                slices(i) <= init_slice;
            end loop;
            pwm_int_reg <= '0';
        elsif rising_edge(HCLK) then
            if write_en = '1' then
                case reg_offset is
                    when "0000" =>  -- CSR
                        slices(slice_idx).csr <= HWDATA(7 downto 0);
                    when "0100" =>  -- DIV
                        slices(slice_idx).div_int  <= unsigned(HWDATA(7 downto 0));
                        slices(slice_idx).div_frac <= unsigned(HWDATA(11 downto 8));
                    when "1000" =>  -- CTR (top)
                        slices(slice_idx).ctr_top <= unsigned(HWDATA(15 downto 0));
                    when "1100" =>  -- CC (compare A:B)
                        slices(slice_idx).cc_a <= unsigned(HWDATA(15 downto 0));
                        slices(slice_idx).cc_b <= unsigned(HWDATA(31 downto 16));
                    when others => null;
                end case;
            end if;
        end if;
    end process ahb_write;

    -- ========================================================================
    -- AHB-Lite register read
    -- ========================================================================
    ahb_read : process(HSEL, HADDR, slice_idx, reg_offset, slices)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when "0000" =>
                    rdata(7 downto 0) := slices(slice_idx).csr;
                when "0100" =>
                    rdata(7 downto 0)   := std_logic_vector(slices(slice_idx).div_int);
                    rdata(11 downto 8)  := std_logic_vector(slices(slice_idx).div_frac);
                when "1000" =>
                    rdata(15 downto 0) := std_logic_vector(slices(slice_idx).ctr_top);
                when "1100" =>
                    rdata(15 downto 0) := std_logic_vector(slices(slice_idx).cc_a);
                    rdata(31 downto 16):= std_logic_vector(slices(slice_idx).cc_b);
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';

    -- ========================================================================
    -- PWM counter and output generation
    -- ========================================================================
    pwm_gen : process(HCLK, HRESETn)
        variable div_tick : std_logic;
        variable out_a : std_logic;
        variable out_b : std_logic;
    begin
        if HRESETn = '0' then
            pwm_out_reg <= (others => '0');
            for i in 0 to NUM_SLICES-1 loop
                slices(i).counter     <= (others => '0');
                slices(i).div_counter <= (others => '0');
                slices(i).frac_accum  <= (others => '0');
            end loop;
        elsif rising_edge(HCLK) then
            for i in 0 to NUM_SLICES-1 loop
                -- Check if slice is enabled
                if slices(i).csr(0) = '1' then
                    -- Clock divider
                    div_tick := '0';
                    if slices(i).div_int = 0 then
                        div_tick := '1';
                    elsif slices(i).div_counter >= slices(i).div_int - 1 then
                        div_tick := '1';
                        slices(i).div_counter <= (others => '0');
                    else
                        slices(i).div_counter <= slices(i).div_counter + 1;
                    end if;

                    -- Fractional divider
                    if div_tick = '1' and slices(i).div_frac /= 0 then
                        slices(i).frac_accum <= slices(i).frac_accum + slices(i).div_frac;
                        if slices(i).frac_accum + slices(i).div_frac >= 16 then
                            -- Skip one tick (fractional divide)
                            div_tick := '0';
                        end if;
                    end if;

                    -- Counter operation
                    if div_tick = '1' then
                        if slices(i).csr(1) = '1' then
                            -- Phase-correct mode: count up then down
                            if slices(i).csr(4) = '0' then
                                -- Counting up
                                if slices(i).counter >= slices(i).ctr_top then
                                    slices(i).csr(4) <= '1';
                                    slices(i).counter <= slices(i).counter - 1;
                                else
                                    slices(i).counter <= slices(i).counter + 1;
                                end if;
                            else
                                -- Counting down
                                if slices(i).counter = 0 then
                                    slices(i).csr(4) <= '0';
                                    slices(i).counter <= slices(i).counter + 1;
                                else
                                    slices(i).counter <= slices(i).counter - 1;
                                end if;
                            end if;
                        else
                            -- Edge-aligned mode: count up, wrap to 0
                            if slices(i).counter >= slices(i).ctr_top then
                                slices(i).counter <= (others => '0');
                            else
                                slices(i).counter <= slices(i).counter + 1;
                            end if;
                        end if;
                    end if;

                    -- Generate PWM output
                    if slices(i).counter < slices(i).cc_a then
                        out_a := '1';
                    else
                        out_a := '0';
                    end if;
                    if slices(i).counter < slices(i).cc_b then
                        out_b := '1';
                    else
                        out_b := '0';
                    end if;

                    -- Apply polarity
                    if slices(i).csr(2) = '1' then out_a := not out_a; end if;
                    if slices(i).csr(3) = '1' then out_b := not out_b; end if;

                    pwm_out_reg(i*2)     <= out_a;
                    pwm_out_reg(i*2 + 1) <= out_b;
                end if;
            end loop;
        end if;
    end process pwm_gen;

    -- PWM interrupt (when counter wraps - simplified)
    pwm_int_reg <= '1' when (slices(0).counter = 0 and slices(0).csr(0) = '1') else '0';
    pwm_int <= pwm_int_reg;
    pwm_out <= pwm_out_reg;

end architecture rtl;
