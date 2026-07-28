-- ================================================================================
-- qei_controller : Quadrature Encoder Interface
-- ================================================================================
-- Decodes quadrature encoder signals (A/B channels) to track position,
-- velocity, and index. Supports direction detection and index reset.
--   * 32-bit position counter with index reset
--   * Velocity estimation via timer-based counting
--   * Direction, index, and overflow interrupts
--
-- AHB-Lite register map:
--   0x00 : CTRL     - [0] enable, [1] irq_en, [2] index_reset, [3] vel_enable
--   0x04 : STAT     - [0] dir, [1] index_detected, [2] overflow, [3] vel_ready
--   0x08 : POSITION - 32-bit position counter
--   0x0C : VELOCITY - estimated velocity (counts per sample period)
--   0x10 : INDEX    - index pulse count
--   0x14 : MAX_POS  - maximum position (for modulo counting)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity qei_controller is
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

        -- QEI interface
        qei_a     : in  std_logic := '0';
        qei_b     : in  std_logic := '0';
        qei_index : in  std_logic := '0';
        qei_irq   : out std_logic
    );
end entity qei_controller;

architecture rtl of qei_controller is
    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal position    : unsigned(31 downto 0) := (others => '0');
    signal velocity    : unsigned(31 downto 0) := (others => '0');
    signal index_count : unsigned(31 downto 0) := (others => '0');
    signal max_pos     : unsigned(31 downto 0) := (others => '0');

    signal qei_a_prev  : std_logic := '0';
    signal qei_b_prev  : std_logic := '0';
    signal qei_idx_prev: std_logic := '0';
    signal direction   : std_logic := '0';  -- 1=forward, 0=reverse
    signal overflow    : std_logic := '0';
    signal irq_pending : std_logic := '0';

    signal vel_counter : unsigned(31 downto 0) := (others => '0');
    signal vel_sample  : unsigned(31 downto 0) := (others => '0');
    signal vel_period  : unsigned(31 downto 0) := x"000186A0";  -- 100k cycles

    signal reg_offset  : std_logic_vector(7 downto 0);
    signal write_en    : std_logic;
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;

    ahb_write : process(HCLK, HRESETn)
        variable a_xor_b : std_logic;
    begin
        if HRESETn = '0' then
            ctrl_reg     <= (others => '0');
            position     <= (others => '0');
            velocity     <= (others => '0');
            index_count  <= (others => '0');
            max_pos      <= (others => '0');
            qei_a_prev   <= '0';
            qei_b_prev   <= '0';
            qei_idx_prev <= '0';
            direction    <= '0';
            overflow     <= '0';
            irq_pending  <= '0';
            vel_counter  <= (others => '0');
            vel_sample   <= (others => '0');
        elsif rising_edge(HCLK) then
            irq_pending <= '0';
            overflow <= '0';

            if write_en = '1' then
                case reg_offset is
                    when x"00" =>
                        ctrl_reg <= HWDATA;
                        if HWDATA(2) = '1' then
                            position <= (others => '0');
                        end if;
                    when x"08" => position   <= unsigned(HWDATA);
                    when x"14" => max_pos    <= unsigned(HWDATA);
                    when others => null;
                end case;
            end if;

            -- Quadrature decode (state machine on A/B transitions)
            if ctrl_reg(0) = '1' then
                -- Detect A edge
                if qei_a /= qei_a_prev then
                    if qei_a = qei_b then
                        direction <= '0';
                        if position > 0 then
                            position <= position - 1;
                        end if;
                    else
                        direction <= '1';
                        if max_pos = 0 or position < max_pos then
                            position <= position + 1;
                        else
                            position <= (others => '0');
                            overflow <= '1';
                        end if;
                    end if;
                end if;

                -- Detect B edge
                if qei_b /= qei_b_prev then
                    if qei_a /= qei_b then
                        direction <= '0';
                        if position > 0 then
                            position <= position - 1;
                        end if;
                    else
                        direction <= '1';
                        if max_pos = 0 or position < max_pos then
                            position <= position + 1;
                        else
                            position <= (others => '0');
                            overflow <= '1';
                        end if;
                    end if;
                end if;

                qei_a_prev <= qei_a;
                qei_b_prev <= qei_b;

                -- Index detection
                if qei_index = '1' and qei_idx_prev = '0' then
                    index_count <= index_count + 1;
                    position <= (others => '0');
                    irq_pending <= ctrl_reg(1);
                end if;
                qei_idx_prev <= qei_index;

                -- Velocity measurement
                if ctrl_reg(3) = '1' then
                    vel_counter <= vel_counter + 1;
                    if (qei_a /= qei_a_prev) or (qei_b /= qei_b_prev) then
                        vel_sample <= vel_sample + 1;
                    end if;
                    if vel_counter >= vel_period then
                        velocity <= vel_sample;
                        vel_sample <= (others => '0');
                        vel_counter <= (others => '0');
                    end if;
                end if;

                if overflow = '1' then
                    irq_pending <= ctrl_reg(1);
                end if;
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, position, velocity,
                       index_count, max_pos, direction, overflow)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"00" => rdata := ctrl_reg;
                when x"04" =>
                    rdata(0) := direction;
                    rdata(2) := overflow;
                when x"08" => rdata := std_logic_vector(position);
                when x"0C" => rdata := std_logic_vector(velocity);
                when x"10" => rdata := std_logic_vector(index_count);
                when x"14" => rdata := std_logic_vector(max_pos);
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    qei_irq   <= irq_pending;

end architecture rtl;
