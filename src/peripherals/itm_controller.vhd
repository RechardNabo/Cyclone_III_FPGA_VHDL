-- ================================================================================
-- itm_controller : Instrumentation Trace Macrocell with AHB-Lite slave interface
-- ================================================================================
-- ARM Cortex-M ITM for software-driven trace via 32 stimulus ports.
--
-- Features:
--   * 32 write-only stimulus ports (STIM0-31)
--   * Trace Enable Register (TER) - per-port enable
--   * Trace Privilege Register (TPR) - per-port privilege control
--   * ITM control register with enable, SWO output
--   * Single-wire viewer (SWV) output for trace data
--   * Interrupt on stimulus port write
--
-- Register Map:
--   0x000-0x07C: STIM0-31  - stimulus ports (write-only, 32-bit)
--   0x080: TER             - trace enable register (bit per port)
--   0x084: TPR             - trace privilege register
--   0x088: ITM_CTRL        - bit0=ITMEN, bit1=TXEN, bit2=SYNCEN, bit3=SWOEN
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity itm_controller is
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

        itm_swv   : out std_logic;   -- single wire viewer output (serial)
        itm_irq   : out std_logic
    );
end entity itm_controller;

architecture rtl of itm_controller is
    constant NUM_PORTS : integer := 32;

    type stim_array_t is array (0 to NUM_PORTS-1) of std_logic_vector(31 downto 0);

    signal stim_mem    : stim_array_t := (others => (others => '0'));
    signal stim_valid  : std_logic_vector(NUM_PORTS-1 downto 0) := (others => '0');
    signal ter_reg     : std_logic_vector(NUM_PORTS-1 downto 0) := (others => '0');
    signal tpr_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal itm_ctrl    : std_logic_vector(31 downto 0) := (others => '0');

    -- SWV serial output shift register
    signal swv_shift   : std_logic_vector(7 downto 0) := (others => '0');
    signal swv_cnt     : integer range 0 to 9 := 0;  -- 8 data + 1 start + 1 idle
    signal swv_busy    : std_logic := '0';
    signal swv_data_out: std_logic := '1';  -- idle high

    signal reg_sel     : std_logic_vector(6 downto 0);
    signal write_en    : std_logic;
    signal port_idx    : integer range 0 to 127;

begin
    reg_sel  <= HADDR(8 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    port_idx <= to_integer(unsigned(HADDR(8 downto 2)));
    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Stimulus port write process
    stim_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                stim_mem   <= (others => (others => '0'));
                stim_valid <= (others => '0');
                ter_reg    <= (others => '0');
                tpr_reg    <= (others => '0');
                itm_ctrl   <= (others => '0');
            elsif write_en = '1' then
                if port_idx < 32 then
                    -- Stimulus port write (0x00-0x7C)
                    if ter_reg(port_idx) = '1' and itm_ctrl(0) = '1' then
                        stim_mem(port_idx)   <= HWDATA;
                        stim_valid(port_idx) <= '1';
                    end if;
                elsif reg_sel = "1000000" then  -- 0x080 TER
                    ter_reg <= HWDATA(NUM_PORTS-1 downto 0);
                elsif reg_sel = "1000001" then  -- 0x084 TPR
                    tpr_reg <= HWDATA;
                elsif reg_sel = "1000010" then  -- 0x088 ITM_CTRL
                    itm_ctrl <= HWDATA;
                end if;
            else
                -- Clear valid flags once consumed by SWV
                if swv_busy = '0' then
                    stim_valid <= (others => '0');
                end if;
            end if;
        end if;
    end process stim_write;

    -- SWV serial output process - sends lowest-numbered pending stimulus byte
    swv_proc : process(HCLK)
        variable found : boolean;
        variable pidx   : integer range 0 to NUM_PORTS-1;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                swv_shift    <= (others => '0');
                swv_cnt      <= 0;
                swv_busy     <= '0';
                swv_data_out <= '1';
            elsif itm_ctrl(3) = '1' then  -- SWO enabled
                if swv_busy = '0' then
                    -- Find pending stimulus port
                    found := false;
                    pidx  := 0;
                    for c in 0 to NUM_PORTS-1 loop
                        if stim_valid(c) = '1' and found = false then
                            pidx  := c;
                            found := true;
                        end if;
                    end loop;
                    if found then
                        -- Load byte (port index as header + low byte of data)
                        swv_shift <= std_logic_vector(to_unsigned(pidx, 8));
                        swv_cnt   <= 9;  -- start bit + 8 data bits
                        swv_busy  <= '1';
                        swv_data_out <= '0';  -- start bit
                    else
                        swv_data_out <= '1';  -- idle
                    end if;
                else
                    -- Shift out
                    if swv_cnt = 9 then
                        -- Already sent start bit, now send data bits
                        swv_data_out <= swv_shift(0);
                        swv_shift    <= '1' & swv_shift(7 downto 1);
                        swv_cnt      <= swv_cnt - 1;
                    elsif swv_cnt > 0 then
                        swv_data_out <= swv_shift(0);
                        swv_shift    <= '1' & swv_shift(7 downto 1);
                        swv_cnt      <= swv_cnt - 1;
                    else
                        swv_data_out <= '1';  -- stop/idle
                        swv_busy     <= '0';
                    end if;
                end if;
            else
                swv_data_out <= '1';
                swv_busy     <= '0';
            end if;
        end if;
    end process swv_proc;

    -- Register read mux
    reg_read : process(reg_sel, ter_reg, tpr_reg, itm_ctrl)
    begin
        case reg_sel is
            when "1000000" => HRDATA <= ter_reg;  -- TER
            when "1000001" => HRDATA <= tpr_reg;                 -- TPR
            when "1000010" => HRDATA <= itm_ctrl;                -- ITM_CTRL
            when others    => HRDATA <= (others => '0');  -- STIM ports read-only=0
        end case;
    end process reg_read;

    itm_swv <= swv_data_out;
    itm_irq <= '0' when (stim_valid = x"00000000") else '1';

end architecture rtl;
