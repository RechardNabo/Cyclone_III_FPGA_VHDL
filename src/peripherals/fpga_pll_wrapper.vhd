-- ================================================================================
-- fpga_pll_wrapper : Cyclone III PLL wrapper (ALTPLL megafunction)
-- ================================================================================
-- Wraps the Altera/Intel ALTPLL megafunction for Cyclone III FPGA.
--
-- Features:
--   * Configurable input and output clock frequencies
--   * Locked status output
--   * Software-controlled reset via AHB-Lite register interface
--   * Phase-locked loop status monitoring
--
-- Generics:
--   INPUT_CLOCK  - input clock frequency in Hz (default 50 MHz)
--   OUTPUT_CLOCK - output clock frequency in Hz (default 100 MHz)
--
-- Register Map:
--   0x00: PLL_CTRL  - bit0=reset (write 1 to assert PLL reset)
--   0x04: PLL_STAT  - bit0=locked (RO)
--   0x08: PLL_RESET - bit0=soft_reset (write 1 to trigger reset pulse)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fpga_pll_wrapper is
    generic (
        INPUT_CLOCK  : integer := 50000000;   -- 50 MHz input
        OUTPUT_CLOCK : integer := 100000000   -- 100 MHz output
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

        -- PLL interface
        clk_in    : in  std_logic;
        clk_out   : out std_logic;
        locked    : out std_logic;
        reset     : out std_logic
    );
end entity fpga_pll_wrapper;

architecture rtl of fpga_pll_wrapper is

    constant REG_PLL_CTRL  : std_logic_vector(2 downto 0) := "000";
    constant REG_PLL_STAT  : std_logic_vector(2 downto 0) := "001";
    constant REG_PLL_RESET : std_logic_vector(2 downto 0) := "010";

    signal pll_ctrl  : std_logic_vector(31 downto 0) := (others => '0');
    signal pll_stat  : std_logic_vector(31 downto 0) := (others => '0');
    signal reset_reg : std_logic := '0';
    signal locked_reg : std_logic := '0';
    signal reset_pulse : std_logic := '0';
    signal reset_timer : unsigned(15 downto 0) := (others => '0');

    signal reg_sel  : std_logic_vector(2 downto 0);
    signal write_en : std_logic;

    -- ALTPLL component declaration
    component altpll
        generic (
            clk0_divide_by      : natural;
            clk0_duty_cycle     : natural;
            clk0_multiply_by    : natural;
            clk0_phase_shift    : string;
            compensate_clock    : string;
            gate_lock_signal    : string;
            inclk0_input_frequency : natural;
            intended_device_family : string;
            lpm_hint            : string;
            lpm_type            : string;
            operation_mode      : string;
            pll_type            : string;
            port_activeclock    : string;
            port_areset         : string;
            port_clkbad         : string;
            port_clkena         : string;
            port_clkloss        : string;
            port_clkswitch      : string;
            port_configupdate   : string;
            port_fbin           : string;
            port_inclk          : string;
            port_locked         : string;
            port_pfdena         : string;
            port_phasecounterselect : string;
            port_phasedone      : string;
            port_phasestep      : string;
            port_phaseupdown    : string;
            port_pllena         : string;
            port_extclk         : string
        );
        port (
            areset  : in  std_logic;
            clk     : out std_logic;
            inclk   : in  std_logic;
            locked  : out std_logic
        );
    end component;

    -- Calculate multiply/divide factors
    constant GCD_VAL : integer := 50000000;
    constant MULT_BY : integer := OUTPUT_CLOCK / GCD_VAL;
    constant DIV_BY  : integer := INPUT_CLOCK / GCD_VAL;

begin

    reg_sel  <= HADDR(4 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- ALTPLL instance
    pll_inst : altpll
        generic map (
            clk0_divide_by         => DIV_BY,
            clk0_duty_cycle        => 50,
            clk0_multiply_by       => MULT_BY,
            clk0_phase_shift       => "0",
            compensate_clock       => "CLK0",
            gate_lock_signal       => "NO",
            inclk0_input_frequency => 1000000000 / INPUT_CLOCK,
            intended_device_family => "Cyclone III",
            lpm_hint               => "CBX_MODULE_PREFIX=pll_inst",
            lpm_type               => "altpll",
            operation_mode         => "NORMAL",
            pll_type               => "AUTO",
            port_activeclock       => "PORT_UNUSED",
            port_areset            => "PORT_USED",
            port_clkbad            => "PORT_UNUSED",
            port_clkena            => "PORT_UNUSED",
            port_clkloss           => "PORT_UNUSED",
            port_clkswitch         => "PORT_UNUSED",
            port_configupdate      => "PORT_UNUSED",
            port_fbin              => "PORT_UNUSED",
            port_inclk             => "PORT_USED",
            port_locked            => "PORT_USED",
            port_pfdena            => "PORT_UNUSED",
            port_phasecounterselect=> "PORT_UNUSED",
            port_phasedone         => "PORT_UNUSED",
            port_phasestep         => "PORT_UNUSED",
            port_phaseupdown       => "PORT_UNUSED",
            port_pllena            => "PORT_UNUSED",
            port_extclk            => "PORT_UNUSED"
        )
        port map (
            areset => reset_reg,
            clk    => clk_out,
            inclk  => clk_in,
            locked => locked_reg
        );

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                pll_ctrl  <= (others => '0');
                reset_reg <= '0';
                reset_pulse <= '0';
                reset_timer <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when REG_PLL_CTRL =>
                        pll_ctrl  <= HWDATA;
                        reset_reg <= HWDATA(0);
                    when REG_PLL_RESET =>
                        if HWDATA(0) = '1' then
                            reset_reg   <= '1';
                            reset_pulse <= '1';
                            reset_timer <= (others => '0');
                        end if;
                    when others =>
                        null;
                end case;
            end if;

            -- Auto-clear reset pulse after timer expires
            if reset_pulse = '1' then
                if reset_timer = 1000 then
                    reset_reg   <= '0';
                    reset_pulse <= '0';
                else
                    reset_timer <= reset_timer + 1;
                end if;
            end if;
        end if;
    end process reg_write;

    -- Status register update
    pll_stat(0) <= locked_reg;

    -- Register read mux
    reg_read : process(reg_sel, pll_ctrl, pll_stat)
    begin
        case reg_sel is
            when REG_PLL_CTRL  => HRDATA <= pll_ctrl;
            when REG_PLL_STAT  => HRDATA <= pll_stat;
            when REG_PLL_RESET => HRDATA <= (0 => reset_pulse, others => '0');
            when others        => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    locked <= locked_reg;
    reset  <= reset_reg;

end architecture rtl;
