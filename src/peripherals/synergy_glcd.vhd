-- ================================================================================
-- synergy_glcd : Graphics LCD Controller
-- ================================================================================
-- Renesas Synergy-style GLCD for Cyclone III FPGA.
--
-- Features:
--   * Supports up to 480x272 resolution
--   * Programmable HSYNC/VSYNC timing
--   * 18-bit RGB output (6 bits per channel)
--   * Frame buffer address register
--   * Data enable and pixel clock output
--
-- Register Map:
--   0x00: GLCD_CTRL     - bit0=enable, bit1=irq_en
--   0x04: GLCD_STAT     - bit0=vsync, bit1=hsync (write-1-to-clear)
--   0x08: GLCD_FB_ADDR  - frame buffer base address
--   0x0C: GLCD_HSYNC    - bits[15:0]=h_front, bits[23:16]=h_sync_width, bits[31:24]=h_back
--   0x10: GLCD_VSYNC    - bits[15:0]=v_front, bits[23:16]=v_sync_width, bits[31:24]=v_back
--   0x14: GLCD_WIDTH    - display width in pixels
--   0x18: GLCD_HEIGHT   - display height in lines
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity synergy_glcd is
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

        -- LCD interface
        lcd_hsync : out std_logic;
        lcd_vsync : out std_logic;
        lcd_de    : out std_logic;
        lcd_clk   : out std_logic;
        lcd_r     : out std_logic_vector(5 downto 0);
        lcd_g     : out std_logic_vector(5 downto 0);
        lcd_b     : out std_logic_vector(5 downto 0)
    );
end entity synergy_glcd;

architecture rtl of synergy_glcd is

    constant REG_GLCD_CTRL    : std_logic_vector(3 downto 0) := "0000";
    constant REG_GLCD_STAT    : std_logic_vector(3 downto 0) := "0001";
    constant REG_GLCD_FB_ADDR : std_logic_vector(3 downto 0) := "0010";
    constant REG_GLCD_HSYNC   : std_logic_vector(3 downto 0) := "0011";
    constant REG_GLCD_VSYNC   : std_logic_vector(3 downto 0) := "0100";
    constant REG_GLCD_WIDTH   : std_logic_vector(3 downto 0) := "0101";
    constant REG_GLCD_HEIGHT  : std_logic_vector(3 downto 0) := "0110";

    signal glcd_ctrl    : std_logic_vector(31 downto 0) := (others => '0');
    signal glcd_stat    : std_logic_vector(31 downto 0) := (others => '0');
    signal glcd_fb_addr : std_logic_vector(31 downto 0) := (others => '0');
    signal glcd_hsync_r : std_logic_vector(31 downto 0) := x"00401010"; -- default
    signal glcd_vsync_r : std_logic_vector(31 downto 0) := x"00010201"; -- default
    signal glcd_width   : unsigned(31 downto 0) := to_unsigned(480, 32);
    signal glcd_height  : unsigned(31 downto 0) := to_unsigned(272, 32);

    signal h_cnt : unsigned(15 downto 0) := (others => '0');
    signal v_cnt : unsigned(15 downto 0) := (others => '0');
    signal pix_clk_div : unsigned(3 downto 0) := (others => '0');
    signal lcd_clk_reg : std_logic := '0';

    signal h_sync_w : unsigned(7 downto 0);
    signal h_front  : unsigned(15 downto 0);
    signal h_back   : unsigned(7 downto 0);
    signal v_sync_w : unsigned(7 downto 0);
    signal v_front  : unsigned(15 downto 0);
    signal v_back   : unsigned(7 downto 0);

    signal reg_sel  : std_logic_vector(3 downto 0);
    signal write_en : std_logic;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Extract timing parameters
    h_sync_w <= unsigned(glcd_hsync_r(23 downto 16));
    h_front  <= unsigned(glcd_hsync_r(15 downto 0));
    h_back   <= unsigned(glcd_hsync_r(31 downto 24));
    v_sync_w <= unsigned(glcd_vsync_r(23 downto 16));
    v_front  <= unsigned(glcd_vsync_r(15 downto 0));
    v_back   <= unsigned(glcd_vsync_r(31 downto 24));

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                glcd_ctrl    <= (others => '0');
                glcd_stat    <= (others => '0');
                glcd_fb_addr <= (others => '0');
                glcd_hsync_r <= x"00401010";
                glcd_vsync_r <= x"00010201";
                glcd_width   <= to_unsigned(480, 32);
                glcd_height  <= to_unsigned(272, 32);
            elsif write_en = '1' then
                case reg_sel is
                    when REG_GLCD_CTRL    => glcd_ctrl    <= HWDATA;
                    when REG_GLCD_STAT =>
                        if HWDATA(0) = '1' then glcd_stat(0) <= '0'; end if;
                        if HWDATA(1) = '1' then glcd_stat(1) <= '0'; end if;
                    when REG_GLCD_FB_ADDR => glcd_fb_addr <= HWDATA;
                    when REG_GLCD_HSYNC   => glcd_hsync_r <= HWDATA;
                    when REG_GLCD_VSYNC   => glcd_vsync_r <= HWDATA;
                    when REG_GLCD_WIDTH   => glcd_width   <= unsigned(HWDATA);
                    when REG_GLCD_HEIGHT  => glcd_height  <= unsigned(HWDATA);
                    when others => null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Pixel clock generator (divide HCLK by 2)
    pix_clk_gen : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                pix_clk_div <= (others => '0');
                lcd_clk_reg <= '0';
            elsif glcd_ctrl(0) = '1' then
                pix_clk_div <= pix_clk_div + 1;
                if pix_clk_div = 0 then
                    lcd_clk_reg <= not lcd_clk_reg;
                end if;
            else
                lcd_clk_reg <= '0';
            end if;
        end if;
    end process pix_clk_gen;

    -- Timing generator
    timing_gen : process(lcd_clk_reg)
        variable h_total : unsigned(15 downto 0);
        variable v_total : unsigned(15 downto 0);
    begin
        if rising_edge(lcd_clk_reg) then
            if HRESETn = '0' or glcd_ctrl(0) = '0' then
                h_cnt <= (others => '0');
                v_cnt <= (others => '0');
            else
                h_total := glcd_width(15 downto 0) + h_front + h_back + h_sync_w;
                v_total := glcd_height(15 downto 0) + v_front + v_back + v_sync_w;

                if h_cnt < h_total - 1 then
                    h_cnt <= h_cnt + 1;
                else
                    h_cnt <= (others => '0');
                    if v_cnt < v_total - 1 then
                        v_cnt <= v_cnt + 1;
                    else
                        v_cnt <= (others => '0');
                        glcd_stat(0) <= '1';  -- vsync IRQ
                    end if;
                end if;
            end if;
        end if;
    end process timing_gen;

    -- Output signal generation
    lcd_hsync <= '0' when (h_cnt >= h_front and h_cnt < h_front + h_sync_w) else '1';
    lcd_vsync <= '0' when (v_cnt >= v_front and v_cnt < v_front + v_sync_w) else '1';
    lcd_de    <= '1' when (h_cnt >= h_front + h_sync_w + h_back and
                           h_cnt < h_front + h_sync_w + h_back + glcd_width(15 downto 0)) and
                          (v_cnt >= v_front + v_sync_w + v_back and
                           v_cnt < v_front + v_sync_w + v_back + glcd_height(15 downto 0)) else '0';

    -- Pixel data (test pattern: color bars)
    lcd_r <= "111111" when lcd_de = '1' and v_cnt(2) = '1' else (others => '0');
    lcd_g <= "111111" when lcd_de = '1' and v_cnt(1) = '1' else (others => '0');
    lcd_b <= "111111" when lcd_de = '1' and v_cnt(0) = '1' else (others => '0');

    lcd_clk <= lcd_clk_reg;

    -- Register read mux
    reg_read : process(reg_sel, glcd_ctrl, glcd_stat, glcd_fb_addr,
                       glcd_hsync_r, glcd_vsync_r, glcd_width, glcd_height)
    begin
        case reg_sel is
            when REG_GLCD_CTRL    => HRDATA <= glcd_ctrl;
            when REG_GLCD_STAT    => HRDATA <= glcd_stat;
            when REG_GLCD_FB_ADDR => HRDATA <= glcd_fb_addr;
            when REG_GLCD_HSYNC   => HRDATA <= glcd_hsync_r;
            when REG_GLCD_VSYNC   => HRDATA <= glcd_vsync_r;
            when REG_GLCD_WIDTH   => HRDATA <= std_logic_vector(glcd_width);
            when REG_GLCD_HEIGHT  => HRDATA <= std_logic_vector(glcd_height);
            when others           => HRDATA <= (others => '0');
        end case;
    end process reg_read;

end architecture rtl;
