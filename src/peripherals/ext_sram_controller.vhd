-- ================================================================================
-- ext_sram_controller : External SRAM/Block RAM Controller
-- ================================================================================
-- Educational External SRAM Controller for Cyclone III FPGA.
--
-- Features:
--   * 32-bit data bus interface to external SRAM/BRAM
--   * Configurable wait-state generation
--   * Address masking and base address remapping
--   * Byte-lane strobes for partial writes
--   * AHB-Lite slave interface for CPU access
--
-- Register Map:
--   0x00: CTRL
--       bit0 = enable       (RW) - controller enable
--       bit1 = wait_en      (RW) - wait-state generation enable
--   0x04: TIMING
--       bits[7:0] = read wait states  (RW)
--       bits[15:8] = write wait states (RW)
--   0x08: ADDR_MASK - address mask for external address (RW)
--   0x0C: BASE_ADDR - base address remap (RW)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ext_sram_controller is
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

        -- External SRAM interface
        sram_addr  : out std_logic_vector(19 downto 0);
        sram_data  : inout std_logic_vector(31 downto 0);
        sram_oe_n  : out std_logic;
        sram_we_n  : out std_logic;
        sram_cs_n  : out std_logic;
        sram_bls_n : out std_logic_vector(3 downto 0)  -- byte lane strobes
    );
end entity ext_sram_controller;

architecture rtl of ext_sram_controller is
    constant SRAM_CTRL      : std_logic_vector(3 downto 0) := "0000";
    constant SRAM_TIMING    : std_logic_vector(3 downto 0) := "0001";
    constant SRAM_ADDR_MASK : std_logic_vector(3 downto 0) := "0010";
    constant SRAM_BASE_ADDR : std_logic_vector(3 downto 0) := "0011";

    signal ctrl_reg       : std_logic_vector(31 downto 0) := (0 => '1', others => '0');
    signal timing_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal addr_mask_reg  : std_logic_vector(31 downto 0) := x"000FFFFF";
    signal base_addr_reg  : std_logic_vector(31 downto 0) := (others => '0');

    signal reg_sel        : std_logic_vector(3 downto 0);
    signal write_en       : std_logic;
    signal read_en        : std_logic;

    type state_t is (IDLE, READ_WAIT, WRITE_WAIT, COMPLETE);
    signal state      : state_t := IDLE;
    signal wait_cnt   : unsigned(7 downto 0) := (others => '0');
    signal wait_max   : unsigned(7 downto 0) := (others => '0');
    signal sram_data_i: std_logic_vector(31 downto 0) := (others => '0');
    signal sram_data_o: std_logic_vector(31 downto 0) := (others => '0');
    signal sram_drive : std_logic := '0';

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HRESP <= '0';

    -- SRAM data bus tri-state
    sram_data <= sram_data_o when sram_drive = '1' else (others => 'Z');

    -- SRAM FSM
    sram_fsm : process(HCLK)
        variable ext_addr  : std_logic_vector(19 downto 0);
        variable full_addr : std_logic_vector(31 downto 0);
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                state       <= IDLE;
                sram_oe_n   <= '1';
                sram_we_n   <= '1';
                sram_cs_n   <= '1';
                sram_bls_n  <= (others => '1');
                sram_drive  <= '0';
                wait_cnt    <= (others => '0');
                HREADYOUT   <= '1';
            elsif ctrl_reg(0) = '1' then
                case state is
                    when IDLE =>
                        if read_en = '1' then
                            full_addr := (HADDR and addr_mask_reg) or base_addr_reg;
                            ext_addr := full_addr(19 downto 0);
                            sram_addr  <= ext_addr;
                            sram_cs_n  <= '0';
                            sram_oe_n  <= '0';
                            sram_we_n  <= '1';
                            sram_bls_n <= (others => '0');
                            sram_drive <= '0';
                            if ctrl_reg(1) = '1' then
                                wait_max <= unsigned(timing_reg(7 downto 0));
                                wait_cnt <= (others => '0');
                                state    <= READ_WAIT;
                                HREADYOUT <= '0';
                            else
                                sram_data_i <= sram_data;
                                sram_oe_n   <= '1';
                                sram_cs_n   <= '1';
                                state       <= COMPLETE;
                                HREADYOUT   <= '0';
                            end if;
                        elsif write_en = '1' then
                            full_addr := (HADDR and addr_mask_reg) or base_addr_reg;
                            ext_addr := full_addr(19 downto 0);
                            sram_addr   <= ext_addr;
                            sram_cs_n   <= '0';
                            sram_oe_n   <= '1';
                            sram_we_n   <= '0';
                            sram_bls_n  <= (others => '0');
                            sram_data_o <= HWDATA;
                            sram_drive  <= '1';
                            if ctrl_reg(1) = '1' then
                                wait_max <= unsigned(timing_reg(15 downto 8));
                                wait_cnt <= (others => '0');
                                state    <= WRITE_WAIT;
                                HREADYOUT <= '0';
                            else
                                sram_we_n  <= '1';
                                sram_cs_n  <= '1';
                                sram_drive <= '0';
                                state      <= COMPLETE;
                                HREADYOUT  <= '0';
                            end if;
                        else
                            HREADYOUT <= '1';
                        end if;

                    when READ_WAIT =>
                        if wait_cnt = wait_max then
                            sram_data_i <= sram_data;
                            sram_oe_n   <= '1';
                            sram_cs_n   <= '1';
                            state       <= COMPLETE;
                        else
                            wait_cnt <= wait_cnt + 1;
                        end if;

                    when WRITE_WAIT =>
                        if wait_cnt = wait_max then
                            sram_we_n  <= '1';
                            sram_cs_n  <= '1';
                            sram_drive <= '0';
                            state      <= COMPLETE;
                        else
                            wait_cnt <= wait_cnt + 1;
                        end if;

                    when COMPLETE =>
                        state     <= IDLE;
                        HREADYOUT <= '1';
                end case;
            else
                HREADYOUT <= '1';
            end if;
        end if;
    end process sram_fsm;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg      <= (0 => '1', others => '0');
                timing_reg    <= (others => '0');
                addr_mask_reg <= x"000FFFFF";
                base_addr_reg <= (others => '0');
            elsif write_en = '1' and state = IDLE then
                case reg_sel is
                    when SRAM_CTRL =>
                        ctrl_reg <= HWDATA;
                    when SRAM_TIMING =>
                        timing_reg <= HWDATA;
                    when SRAM_ADDR_MASK =>
                        addr_mask_reg <= HWDATA;
                    when SRAM_BASE_ADDR =>
                        base_addr_reg <= HWDATA;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, timing_reg, addr_mask_reg,
                       base_addr_reg, sram_data_i, state)
    begin
        case reg_sel is
            when SRAM_CTRL =>
                HRDATA <= ctrl_reg;
            when SRAM_TIMING =>
                HRDATA <= timing_reg;
            when SRAM_ADDR_MASK =>
                HRDATA <= addr_mask_reg;
            when SRAM_BASE_ADDR =>
                HRDATA <= base_addr_reg;
            when others =>
                -- Direct memory read data
                if state = COMPLETE or state = IDLE then
                    HRDATA <= sram_data_i;
                else
                    HRDATA <= (others => '0');
                end if;
        end case;
    end process reg_read;

end architecture rtl;
