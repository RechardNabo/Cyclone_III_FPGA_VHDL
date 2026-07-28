-- ================================================================================
-- dap_controller : Debug Access Port (SWD/JTAG) with AHB-Lite slave interface
-- ================================================================================
-- SWD/JTAG debug access port for Cyclone III FPGA.
-- Register Map:
--   0x00 CTRL    - bit0=swd_en, bit1=jtag_en, bit2=reset
--   0x04 STAT    - bit0=swd_active, bit1=jtag_active, bit2=dp_ready
--   0x08 DP_CTRL - DP control register (RW)
--   0x0C AP_CTRL - AP control register (RW)
--   0x10 AP_DATA - AP data register (RW)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dap_controller is
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

        -- SWD interface
        swclk     : in  std_logic;
        swdio     : inout std_logic;
        -- JTAG interface
        tck       : in  std_logic;
        tms       : in  std_logic;
        tdi       : in  std_logic;
        tdo       : out std_logic;
        ntrst     : in  std_logic
    );
end entity dap_controller;

architecture rtl of dap_controller is
    constant DAP_CTRL    : std_logic_vector(3 downto 0) := "0000";
    constant DAP_STAT    : std_logic_vector(3 downto 0) := "0001";
    constant DAP_DP_CTRL : std_logic_vector(3 downto 0) := "0010";
    constant DAP_AP_CTRL : std_logic_vector(3 downto 0) := "0011";
    constant DAP_AP_DATA : std_logic_vector(3 downto 0) := "0100";

    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal dp_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal ap_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal ap_data_reg : std_logic_vector(31 downto 0) := (others => '0');

    signal swd_active  : std_logic := '0';
    signal jtag_active : std_logic := '0';
    signal dp_ready    : std_logic := '1';

    signal reg_sel     : std_logic_vector(3 downto 0);
    signal write_en    : std_logic;
    signal read_en     : std_logic;

    -- SWD shift register
    signal swd_shift   : std_logic_vector(31 downto 0) := (others => '0');
    signal swd_bit_cnt : unsigned(5 downto 0) := (others => '0');
    signal swdio_out   : std_logic := '0';
    signal swdio_drive : std_logic := '0';

    -- JTAG TAP state machine (simplified)
    type jtag_state_t is (TLR, RTI, SEL_DR, CAP_DR, SH_DR, EX1_DR, PAU_DR,
                          SEL_IR, CAP_IR, SH_IR, EX1_IR, PAU_IR);
    signal jtag_state : jtag_state_t := TLR;
    signal jtag_shift  : std_logic_vector(31 downto 0) := (others => '0');

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- SWD I/O
    swdio <= swdio_out when swdio_drive = '1' else 'Z';

    -- Mode selection
    swd_active  <= ctrl_reg(0) and (not ctrl_reg(1));
    jtag_active <= ctrl_reg(1) and (not ctrl_reg(0));

    -- SWD protocol handler (simplified bit shifting)
    swd_proc : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                swd_shift   <= (others => '0');
                swd_bit_cnt <= (others => '0');
                swdio_out   <= '0';
                swdio_drive <= '0';
            elsif swd_active = '1' then
                -- Shift data in on swclk rising (simplified)
                swd_shift <= swd_shift(30 downto 0) & swdio;
                if swd_bit_cnt = 31 then
                    swd_bit_cnt <= (others => '0');
                    ap_data_reg <= swd_shift(30 downto 0) & swdio;
                else
                    swd_bit_cnt <= swd_bit_cnt + 1;
                end if;
            end if;
        end if;
    end process swd_proc;

    -- JTAG TAP (simplified state machine)
    jtag_proc : process(tck, ntrst)
    begin
        if ntrst = '0' then
            jtag_state <= TLR;
            jtag_shift <= (others => '0');
        elsif rising_edge(tck) then
            if jtag_active = '1' then
                case jtag_state is
                    when TLR =>
                        jtag_state <= RTI when tms = '0' else TLR;
                    when RTI =>
                        jtag_state <= SEL_DR when tms = '1' else RTI;
                    when SEL_DR =>
                        jtag_state <= CAP_DR when tms = '0' else SEL_IR;
                    when CAP_DR =>
                        jtag_state <= SH_DR when tms = '0' else EX1_DR;
                    when SH_DR =>
                        jtag_shift <= jtag_shift(30 downto 0) & tdi;
                        jtag_state <= EX1_DR when tms = '1' else SH_DR;
                    when EX1_DR =>
                        jtag_state <= PAU_DR when tms = '0' else SEL_DR;
                    when PAU_DR =>
                        jtag_state <= EX1_DR when tms = '1' else PAU_DR;
                    when SEL_IR =>
                        jtag_state <= CAP_IR when tms = '0' else TLR;
                    when CAP_IR =>
                        jtag_state <= SH_IR when tms = '0' else EX1_IR;
                    when SH_IR =>
                        jtag_state <= EX1_IR when tms = '1' else SH_IR;
                    when EX1_IR =>
                        jtag_state <= PAU_IR when tms = '0' else SEL_DR;
                    when PAU_IR =>
                        jtag_state <= EX1_IR when tms = '1' else PAU_IR;
                end case;
            end if;
        end if;
    end process jtag_proc;

    tdo <= jtag_shift(31) when jtag_state = SH_DR else '0';

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg    <= (others => '0');
                dp_ctrl_reg <= (others => '0');
                ap_ctrl_reg <= (others => '0');
                ap_data_reg <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when DAP_CTRL =>
                        ctrl_reg <= HWDATA;
                    when DAP_DP_CTRL =>
                        dp_ctrl_reg <= HWDATA;
                    when DAP_AP_CTRL =>
                        ap_ctrl_reg <= HWDATA;
                    when DAP_AP_DATA =>
                        ap_data_reg <= HWDATA;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, swd_active, jtag_active, dp_ready,
                       dp_ctrl_reg, ap_ctrl_reg, ap_data_reg)
    begin
        case reg_sel is
            when DAP_CTRL =>
                HRDATA <= ctrl_reg;
            when DAP_STAT =>
                HRDATA <= (0 => swd_active, 1 => jtag_active,
                           2 => dp_ready, others => '0');
            when DAP_DP_CTRL =>
                HRDATA <= dp_ctrl_reg;
            when DAP_AP_CTRL =>
                HRDATA <= ap_ctrl_reg;
            when DAP_AP_DATA =>
                HRDATA <= ap_data_reg;
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

end architecture rtl;
