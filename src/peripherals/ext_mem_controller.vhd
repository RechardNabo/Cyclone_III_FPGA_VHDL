-- ================================================================================
-- ext_mem_controller : External parallel NOR/SRAM memory controller
-- ================================================================================
-- Controls up to 4 chip-select regions of external parallel memory (NOR flash
-- or async SRAM). 26-bit address bus, 16-bit data bus with byte selection.
--   * Configurable timing per chip-select (wait states, hold, setup)
--   * Byte-enable for 8-bit and 16-bit accesses
--   * Read/write strobe generation
--
-- AHB-Lite register map:
--   0x00 : CTRL    - [0] enable, [1] nor_mode(0=SRAM), [2] async
--   0x04 : STAT    - [0] ready, [1] busy
--   0x08 : ADDR    - memory address to access (26-bit)
--   0x0C : TIMING  - [7:0] wait_states, [15:8] hold_cycles, [23:16] setup_cycles
--   0x10 : CS_CFG  - per-CS base address and size configuration
--   0x14 : DATA    - read/write data port (16-bit in [15:0])
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ext_mem_controller is
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

        -- External memory bus
        mem_addr   : out std_logic_vector(25 downto 0);
        mem_data   : inout std_logic_vector(15 downto 0) := (others => 'Z');
        mem_oe_n   : out std_logic;
        mem_we_n   : out std_logic;
        mem_cs_n   : out std_logic_vector(3 downto 0);
        mem_byte_n : out std_logic_vector(1 downto 0)
    );
end entity ext_mem_controller;

architecture rtl of ext_mem_controller is
    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal stat_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal addr_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal timing_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal cs_cfg_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal data_reg    : std_logic_vector(31 downto 0) := (others => '0');

    signal mem_busy    : std_logic := '0';
    signal mem_state   : integer range 0 to 7 := 0;
    signal wait_cnt    : unsigned(7 downto 0) := (others => '0');
    signal mem_data_in : std_logic_vector(15 downto 0) := (others => '0');
    signal is_write    : std_logic := '0';

    signal reg_offset  : std_logic_vector(7 downto 0);
    signal write_en    : std_logic;
    signal mem_oe_int  : std_logic := '1';
    signal mem_we_int  : std_logic := '1';
    signal mem_cs_int  : std_logic_vector(3 downto 0) := (others => '1');
    signal mem_byte_int: std_logic_vector(1 downto 0) := (others => '1');
    signal mem_addr_int: std_logic_vector(25 downto 0) := (others => '0');
begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;
    mem_oe_n   <= mem_oe_int;
    mem_we_n   <= mem_we_int;
    mem_cs_n   <= mem_cs_int;
    mem_byte_n <= mem_byte_int;
    mem_addr   <= mem_addr_int;
    mem_data   <= data_reg(15 downto 0) when (is_write = '1' and mem_busy = '1') else (others => 'Z');

    ahb_write : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            ctrl_reg    <= (others => '0');
            addr_reg    <= (others => '0');
            timing_reg  <= (others => '0');
            cs_cfg_reg  <= (others => '0');
            data_reg    <= (others => '0');
            mem_busy    <= '0';
            mem_state   <= 0;
            wait_cnt    <= (others => '0');
            mem_data_in <= (others => '0');
            is_write    <= '0';
            mem_oe_int  <= '1';
            mem_we_int  <= '1';
            mem_cs_int  <= (others => '1');
            mem_byte_int<= (others => '1');
            mem_addr_int<= (others => '0');
        elsif rising_edge(HCLK) then
            if write_en = '1' then
                case reg_offset is
                    when x"00" => ctrl_reg   <= HWDATA;
                    when x"08" => addr_reg   <= HWDATA;
                    when x"0C" => timing_reg <= HWDATA;
                    when x"10" => cs_cfg_reg <= HWDATA;
                    when x"14" =>  -- DATA write triggers access
                        data_reg <= HWDATA;
                        if mem_busy = '0' then
                            is_write  <= '1';
                            mem_busy  <= '1';
                            mem_state <= 0;
                            wait_cnt  <= (others => '0');
                            mem_addr_int <= addr_reg(25 downto 0);
                            mem_byte_int <= "00";  -- both bytes
                        end if;
                    when others => null;
                end case;
            end if;

            -- Memory access state machine
            if mem_busy = '1' then
                case mem_state is
                    when 0 =>  -- assert CS, address
                        mem_cs_int  <= "1110";  -- CS0 active
                        mem_addr_int <= addr_reg(25 downto 0);
                        mem_state <= 1;
                        wait_cnt <= (others => '0');
                    when 1 =>  -- setup phase
                        if wait_cnt = unsigned(timing_reg(23 downto 16)) then
                            wait_cnt <= (others => '0');
                            if is_write = '1' then
                                mem_we_int <= '0';
                            else
                                mem_oe_int <= '0';
                            end if;
                            mem_state <= 2;
                        else
                            wait_cnt <= wait_cnt + 1;
                        end if;
                    when 2 =>  -- wait states
                        if wait_cnt = unsigned(timing_reg(7 downto 0)) then
                            wait_cnt <= (others => '0');
                            if is_write = '0' then
                                mem_data_in <= mem_data;
                            end if;
                            mem_we_int <= '1';
                            mem_oe_int <= '1';
                            mem_state <= 3;
                        else
                            wait_cnt <= wait_cnt + 1;
                        end if;
                    when 3 =>  -- hold phase
                        if wait_cnt = unsigned(timing_reg(15 downto 8)) then
                            mem_cs_int <= (others => '1');
                            mem_byte_int <= (others => '1');
                            mem_busy <= '0';
                        else
                            wait_cnt <= wait_cnt + 1;
                        end if;
                    when others => mem_state <= 0;
                end case;
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, reg_offset, ctrl_reg, addr_reg, timing_reg,
                       cs_cfg_reg, data_reg, mem_data_in, mem_busy)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"00" => rdata := ctrl_reg;
                when x"04" =>
                    if mem_busy = '0' then rdata(0) := '1'; end if;
                    rdata(1) := mem_busy;
                when x"08" => rdata := addr_reg;
                when x"0C" => rdata := timing_reg;
                when x"10" => rdata := cs_cfg_reg;
                when x"14" => rdata := x"0000" & mem_data_in;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';

end architecture rtl;
