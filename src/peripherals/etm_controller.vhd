-- ================================================================================
-- etm_controller : Embedded Trace Macrocell (simplified) with AHB-Lite slave interface
-- ================================================================================
-- ARM Cortex-M ETM for instruction trace with address comparators.
--
-- Features:
--   * 8 address comparators for instruction trace triggering
--   * 8 address mask registers
--   * Trace enable / disable control
--   * 4-bit trace data output with sync signaling
--   * Trace status register
--
-- Register Map:
--   0x00: CTRL          - bit0=ETMEN, bit1=TRACEEN, bit2=SYNCEN, bit3=IRQEN
--   0x04: TRACE_EN      - trace enable control
--   0x08: TRACE_STAT    - bit0=tracing, bit1=fifo_full, bit2=sync_req
--   0x10+0x08*n: ADDR_COMP0-7  - address comparator value
--   0x14+0x08*n: ADDR_MASK0-7  - address mask (ignore low N bits)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity etm_controller is
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

        -- CPU instruction address for tracing
        cpu_iaddr : in  std_logic_vector(31 downto 0);

        -- ETM trace outputs
        etm_clk   : out std_logic;
        etm_data  : out std_logic_vector(3 downto 0);
        etm_sync  : out std_logic
    );
end entity etm_controller;

architecture rtl of etm_controller is
    constant NUM_COMP : integer := 8;

    type addr_array_t is array (0 to NUM_COMP-1) of std_logic_vector(31 downto 0);
    type mask_array_t is array (0 to NUM_COMP-1) of std_logic_vector(4 downto 0);

    signal ctrl_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal trace_en_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal trace_stat    : std_logic_vector(31 downto 0) := (others => '0');

    signal addr_comp_mem : addr_array_t := (others => (others => '0'));
    signal addr_mask_mem : mask_array_t := (others => (others => '0'));

    signal trace_active  : std_logic := '0';
    signal sync_req      : std_logic := '0';
    signal data_shift    : std_logic_vector(3 downto 0) := (others => '0');
    signal bit_cnt       : integer range 0 to 7 := 0;
    signal trace_clk     : std_logic := '0';

    signal reg_sel       : std_logic_vector(5 downto 0);
    signal write_en      : std_logic;

begin
    reg_sel  <= HADDR(7 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Address comparison and trace control
    trace_proc : process(HCLK)
        variable matched    : boolean;
        variable masked_a   : unsigned(31 downto 0);
        variable masked_c   : unsigned(31 downto 0);
        variable mask_val   : integer;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                trace_active <= '0';
                sync_req     <= '0';
                trace_stat   <= (others => '0');
                trace_clk    <= '0';
                bit_cnt      <= 0;
                data_shift   <= (others => '0');
            elsif ctrl_reg(0) = '1' then  -- ETM enabled
                -- Check address comparators
                matched := false;
                for c in 0 to NUM_COMP-1 loop
                    if trace_en_reg(c) = '1' then
                        mask_val := to_integer(unsigned(addr_mask_mem(c)));
                        if mask_val = 0 then
                            masked_a := unsigned(cpu_iaddr);
                            masked_c := unsigned(addr_comp_mem(c));
                        else
                            masked_a := unsigned(cpu_iaddr) srl mask_val;
                            masked_c := unsigned(addr_comp_mem(c)) srl mask_val;
                        end if;
                        if masked_a = masked_c then
                            matched := true;
                        end if;
                    end if;
                end loop;

                if matched and ctrl_reg(1) = '1' then
                    trace_active <= '1';
                elsif ctrl_reg(1) = '0' then
                    trace_active <= '0';
                end if;

                -- Generate trace clock and data
                if trace_active = '1' then
                    trace_clk <= not trace_clk;
                    if trace_clk = '0' then  -- on rising edge sample
                        case bit_cnt is
                            when 0 => data_shift <= cpu_iaddr(3 downto 0);
                            when 1 => data_shift <= cpu_iaddr(7 downto 4);
                            when 2 => data_shift <= cpu_iaddr(11 downto 8);
                            when 3 => data_shift <= cpu_iaddr(15 downto 12);
                            when 4 => data_shift <= cpu_iaddr(19 downto 16);
                            when 5 => data_shift <= cpu_iaddr(23 downto 20);
                            when 6 => data_shift <= cpu_iaddr(27 downto 24);
                            when others => data_shift <= cpu_iaddr(31 downto 28);
                        end case;
                        if bit_cnt = 7 then
                            bit_cnt  <= 0;
                            sync_req <= '1';
                        else
                            bit_cnt  <= bit_cnt + 1;
                        end if;
                    else
                        sync_req <= '0';
                    end if;
                else
                    trace_clk <= '0';
                    bit_cnt   <= 0;
                    sync_req  <= '0';
                end if;

                -- Status register
                trace_stat(0) <= trace_active;
                trace_stat(2) <= sync_req;
            else
                trace_active <= '0';
                trace_clk    <= '0';
                sync_req     <= '0';
            end if;
        end if;
    end process trace_proc;

    -- Register write process
    reg_write : process(HCLK)
        variable cidx : integer range 0 to NUM_COMP-1;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg      <= (others => '0');
                trace_en_reg  <= (others => '0');
                addr_comp_mem <= (others => (others => '0'));
                addr_mask_mem <= (others => (others => '0'));
            elsif write_en = '1' then
                case reg_sel is
                    when "000000" => ctrl_reg     <= HWDATA;
                    when "000001" => trace_en_reg <= HWDATA;
                    when others =>
                        for c in 0 to NUM_COMP-1 loop
                            cidx := c;
                            -- ADDR_COMPn at 0x10 + 0x08*n => reg_sel = 4 + 2*n
                            if reg_sel = std_logic_vector(to_unsigned(4 + 2*c, 6)) then
                                addr_comp_mem(cidx) <= HWDATA;
                            elsif reg_sel = std_logic_vector(to_unsigned(5 + 2*c, 6)) then
                                addr_mask_mem(cidx) <= HWDATA(4 downto 0);
                            end if;
                        end loop;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, trace_en_reg, trace_stat,
                       addr_comp_mem, addr_mask_mem)
    begin
        case reg_sel is
            when "000000" => HRDATA <= ctrl_reg;
            when "000001" => HRDATA <= trace_en_reg;
            when "000010" => HRDATA <= trace_stat;
            when others =>
                HRDATA <= (others => '0');
                for c in 0 to NUM_COMP-1 loop
                    if reg_sel = std_logic_vector(to_unsigned(4 + 2*c, 6)) then
                        HRDATA <= addr_comp_mem(c);
                    elsif reg_sel = std_logic_vector(to_unsigned(5 + 2*c, 6)) then
                        HRDATA <= x"000000" & "000" & addr_mask_mem(c);
                    end if;
                end loop;
        end case;
    end process reg_read;

    etm_clk  <= trace_clk;
    etm_data <= data_shift;
    etm_sync <= sync_req;

end architecture rtl;
