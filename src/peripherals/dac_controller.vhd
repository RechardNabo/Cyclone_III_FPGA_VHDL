-- ================================================================================
-- dac_controller : Digital-to-Analog Converter with AHB-Lite slave interface
-- ================================================================================
-- Educational DAC controller for Cyclone III FPGA.
--
-- Features:
--   * Configurable number of channels (default 2)
--   * 12-bit resolution
--   * Per-channel data registers
--   * Output enable per channel
--   * Synchronous output update
--
-- Register Map:
--   0x00: DAC_CTRL
--       bit0      = enable       (RW) - global DAC enable
--       bit1      = irq_en       (RW) - interrupt enable (not used, reserved)
--       bit2..N+1 = channel enables (RW) - per-channel output enable
--   0x04: DAC_UPDATE - write any value to update all outputs simultaneously (WO)
--   0x08..0x08+4*N: DAC_DATA0..N - per-channel 12-bit data (RW)
--
-- The external analog outputs are provided as a vector of 12-bit values.
-- In a real FPGA, these would drive an external DAC chip or FPGA hard IP.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dac_controller is
    generic (
        NUM_CHANNELS : integer := 2
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

        -- External analog outputs (12-bit per channel)
        dac_out   : out std_logic_vector(NUM_CHANNELS*12-1 downto 0)
    );
end entity dac_controller;

architecture rtl of dac_controller is
    type data_array is array(0 to NUM_CHANNELS-1) of std_logic_vector(11 downto 0);
    signal data_regs    : data_array := (others => (others => '0'));
    signal data_shadow  : data_array := (others => (others => '0'));  -- for synchronous update
    signal ctrl_reg     : std_logic_vector(31 downto 0) := (others => '0');

    signal write_en     : std_logic;
    signal dac_out_reg  : data_array := (others => (others => '0'));

begin

    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Register write process
    reg_write : process(HCLK)
        variable ch_idx : integer;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                data_regs   <= (others => (others => '0'));
                data_shadow <= (others => (others => '0'));
                ctrl_reg    <= (others => '0');
            elsif write_en = '1' then
                if HADDR(5 downto 2) = "0000" then
                    -- DAC_CTRL
                    ctrl_reg <= HWDATA;
                elsif HADDR(5 downto 2) = "0001" then
                    -- DAC_UPDATE: copy shadow to output
                    for i in 0 to NUM_CHANNELS-1 loop
                        data_regs(i) <= data_shadow(i);
                    end loop;
                elsif HADDR(5 downto 2) >= "0010" then
                    -- DAC_DATAx: write to shadow register (0x08 + 4*channel)
                    ch_idx := to_integer(unsigned(HADDR(3 downto 2))) - 2;
                    if ch_idx >= 0 and ch_idx < NUM_CHANNELS then
                        data_shadow(ch_idx) <= HWDATA(11 downto 0);
                    end if;
                end if;
            end if;
        end if;
    end process reg_write;

    -- Output generation: drive DAC outputs when enabled
    out_gen : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                dac_out_reg <= (others => (others => '0'));
            elsif ctrl_reg(0) = '1' then
                for i in 0 to NUM_CHANNELS-1 loop
                    if ctrl_reg(i + 2) = '1' then
                        dac_out_reg(i) <= data_regs(i);
                    else
                        dac_out_reg(i) <= (others => '0');
                    end if;
                end loop;
            else
                dac_out_reg <= (others => (others => '0'));
            end if;
        end if;
    end process out_gen;

    -- Assemble output vector
    out_vec : process(dac_out_reg)
        variable tmp : std_logic_vector(NUM_CHANNELS*12-1 downto 0);
    begin
        for i in 0 to NUM_CHANNELS-1 loop
            tmp(i*12+11 downto i*12) := dac_out_reg(i);
        end loop;
        dac_out <= tmp;
    end process out_vec;

    -- Register read mux
    reg_read : process(HADDR, ctrl_reg, data_regs, data_shadow)
        variable ch_idx : integer;
    begin
        if HADDR(5 downto 2) = "0000" then
            HRDATA <= ctrl_reg;
        elsif HADDR(5 downto 2) >= "0010" then
            ch_idx := to_integer(unsigned(HADDR(3 downto 2))) - 2;
            if ch_idx >= 0 and ch_idx < NUM_CHANNELS then
                HRDATA <= x"00000" & data_shadow(ch_idx);
            else
                HRDATA <= (others => '0');
            end if;
        else
            HRDATA <= (others => '0');
        end if;
    end process reg_read;

end architecture rtl;
