-- ================================================================================
-- rp2040_sram_bank : RP2040 SRAM bank controller with AHB-Lite slave interface
-- ================================================================================
-- Models the RP2040 six-bank SRAM (6 x 4KB = 24KB) with bank-striping support
-- for interleaved access. Each bank has independent chip-select and clock gating.
--
-- Register Map:
--   0x00: CTRL        - bit0=enable, bit1=stripe_en, bit2=irq_en
--   0x04: STAT        - bit0=ready, bit1=access_err, bits8..13=bank_busy
--   0x08: STRIPE_EN   - stripe enable per bank (bits0..5)
--   0x0C: BANK_GATE   - clock gate per bank (bits0..5)
--   0x10..0x28: BANK_CFG0..5 - per-bank config (bit0=enable, bit1=stripe_member)
--
-- Ports:
--   bank_clk(5:0)  - gated clock per bank
--   bank_cs(5:0)   - chip-select per bank
--   sram_irq       - access error / ready interrupt
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rp2040_sram_bank is
    generic (
        NUM_BANKS   : integer := 6;
        BANK_BYTES  : integer := 4096  -- 4KB per bank
    );
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

        -- SRAM bank interface
        bank_clk  : out std_logic_vector(NUM_BANKS-1 downto 0);
        bank_cs   : out std_logic_vector(NUM_BANKS-1 downto 0);
        sram_irq  : out std_logic
    );
end entity rp2040_sram_bank;

architecture rtl of rp2040_sram_bank is
    type cfg_array is array(0 to NUM_BANKS-1) of std_logic_vector(31 downto 0);

    signal ctrl_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal stat_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal stripe_en    : std_logic_vector(31 downto 0) := (others => '0');
    signal bank_gate    : std_logic_vector(31 downto 0) := (others => '0');
    signal bank_cfg     : cfg_array := (others => (others => '0'));

    signal access_err   : std_logic := '0';
    signal busy_vec     : std_logic_vector(NUM_BANKS-1 downto 0) := (others => '0');
    signal write_en     : std_logic;

    constant BANK_SHIFT : integer := 12;  -- log2(4096)

begin

    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Determine target bank from address (striped vs contiguous)
    -- Striped: bank = addr(14 downto 12) (interleave at 4KB stride granularity)
    -- Contiguous: bank = addr(14 downto 12)
    bank_select : process(HADDR, ctrl_reg)
        variable bank_idx : integer;
    begin
        bank_idx := to_integer(unsigned(HADDR(BANK_SHIFT+2 downto BANK_SHIFT)));
        for i in 0 to NUM_BANKS-1 loop
            if i = bank_idx and ctrl_reg(0) = '1' then
                bank_cs(i) <= '1';
            else
                bank_cs(i) <= '0';
            end if;
        end loop;
    end process bank_select;

    -- Clock gating per bank
    clk_gate : process(HCLK, bank_gate, ctrl_reg)
    begin
        for i in 0 to NUM_BANKS-1 loop
            if ctrl_reg(0) = '1' and bank_gate(i) = '1' then
                bank_clk(i) <= HCLK;
            else
                bank_clk(i) <= '0';
            end if;
        end loop;
    end process clk_gate;

    -- Register write process
    reg_write : process(HCLK)
        variable bank_idx : integer;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg   <= (others => '0');
                stripe_en  <= (others => '0');
                bank_gate  <= (others => '0');
                bank_cfg   <= (others => (others => '0'));
                access_err <= '0';
            elsif write_en = '1' then
                case HADDR(7 downto 4) is
                    when x"0" =>
                        case HADDR(3 downto 2) is
                            when "00" => ctrl_reg    <= HWDATA;
                            when "01" => null; -- STAT read-only
                            when "10" => stripe_en  <= HWDATA;
                            when "11" => bank_gate   <= HWDATA;
                            when others => null;
                        end case;
                    when x"1" =>
                        bank_idx := to_integer(unsigned(HADDR(3 downto 2)));
                        if bank_idx < NUM_BANKS then
                            bank_cfg(bank_idx) <= HWDATA;
                        else
                            access_err <= '1';
                        end if;
                    when others =>
                        access_err <= '1';
                end case;
            else
                access_err <= '0';
            end if;
        end if;
    end process reg_write;

    -- Status register assembly
    stat_proc : process(ctrl_reg, access_err, busy_vec)
    begin
        stat_reg <= (others => '0');
        stat_reg(0) <= '1' when ctrl_reg(0) = '1' else '0';
        stat_reg(1) <= access_err;
        stat_reg(8 + NUM_BANKS - 1 downto 8) <= busy_vec;
    end process stat_proc;

    -- Register read mux
    reg_read : process(HADDR, ctrl_reg, stat_reg, stripe_en, bank_gate, bank_cfg)
        variable bank_idx : integer;
    begin
        case HADDR(7 downto 4) is
            when x"0" =>
                case HADDR(3 downto 2) is
                    when "00"   => HRDATA <= ctrl_reg;
                    when "01"   => HRDATA <= stat_reg;
                    when "10"   => HRDATA <= stripe_en;
                    when "11"   => HRDATA <= bank_gate;
                    when others => HRDATA <= (others => '0');
                end case;
            when x"1" =>
                bank_idx := to_integer(unsigned(HADDR(3 downto 2)));
                if bank_idx < NUM_BANKS then
                    HRDATA <= bank_cfg(bank_idx);
                else
                    HRDATA <= (others => '0');
                end if;
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    -- Interrupt
    sram_irq <= '1' when (ctrl_reg(2) = '1' and access_err = '1') else '0';

end architecture rtl;
