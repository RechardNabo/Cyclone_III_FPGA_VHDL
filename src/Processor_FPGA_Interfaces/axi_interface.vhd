-- ============================================================================
-- AXI4-Lite Slave Interface (FPGA-Optimized) - Programming Guidance
-- ============================================================================
-- 
-- PROJECT OVERVIEW:
-- This file implements an AXI4-Lite slave interface for FPGA designs, enabling
-- efficient communication and control between a processor (e.g., ARM Cortex)
-- and custom FPGA logic. It provides a standardized, low-overhead mechanism
-- for register access and configuration.
--
-- LEARNING OBJECTIVES:
-- 1. Understand AXI4-Lite protocol specifications (read/write channels)
-- 2. Learn to implement AXI slave logic for register access
-- 3. Practice state machine design for AXI transaction handling
-- 4. Integrate custom FPGA logic with AXI bus
-- 5. Verify AXI compliance with simulation testbenches
-- 6. Debug AXI transactions using waveform analysis
--
-- ============================================================================
-- STEP-BY-STEP IMPLEMENTATION GUIDE:
-- ============================================================================
--
-- STEP 1: LIBRARY DECLARATIONS
-- ----------------------------------------------------------------------------
-- Required Libraries:
-- - IEEE library for standard logic types
-- - std_logic_1164 package for std_logic operations
-- - numeric_std package for arithmetic type conversions
--
-- TODO: Add library IEEE;
-- TODO: Add use IEEE.std_logic_1164.all;
-- TODO: Add use IEEE.numeric_std.all;
--
-- ============================================================================
-- STEP 2: ENTITY DECLARATION
-- ----------------------------------------------------------------------------
-- Entity Requirements:
-- - Name: axi_interface
-- - AXI4-Lite standard signals (AW, W, B, AR, R channels)
-- - Configurable data width (e.g., 32-bit)
-- - Configurable address width (e.g., 10-bit for 1KB address space)
-- - Clock and reset signals
--
-- Port Specifications:
-- - ACLK : in std_logic (AXI clock)
-- - ARESETn : in std_logic (AXI active-low reset)
-- - AWADDR : in std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) (Write address)
-- - AWVALID : in std_logic (Write address valid)
-- - AWREADY : out std_logic (Write address ready)
-- - WDATA : in std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) (Write data)
-- - WSTRB : in std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0) (Write strobes)
-- - WVALID : in std_logic (Write data valid)
-- - WREADY : out std_logic (Write data ready)
-- - BRESP : out std_logic_vector(1 downto 0) (Write response)
-- - BVALID : out std_logic (Write response valid)
-- - BREADY : in std_logic (Write response ready)
-- - ARADDR : in std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) (Read address)
-- - ARVALID : in std_logic (Read address valid)
-- - ARREADY : out std_logic (Read address ready)
-- - RDATA : out std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) (Read data)
-- - RRESP : out std_logic_vector(1 downto 0) (Read response)
-- - RVALID : out std_logic (Read data valid)
-- - RREADY : in std_logic (Read data ready)
-- - slave_reg_write : out std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) (Address for internal write)
-- - slave_reg_wdata : out std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) (Data for internal write)
-- - slave_reg_read : out std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) (Address for internal read)
-- - slave_reg_rdata : in std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) (Data for internal read)
--
-- ============================================================================
-- STEP 3: ARCHITECTURE OPTIONS
-- ----------------------------------------------------------------------------
-- OPTION A: SINGLE-CYCLE REGISTER ACCESS (Recommended for Simplicity)
-- - Direct mapping of AXI transactions to internal register reads/writes
-- - Minimal state machine for handshake signals
-- - Suitable for small number of registers
--
-- OPTION B: PIPELINED REGISTER ACCESS (Recommended for Performance)
-- - Pipelined read and write paths
-- - More complex state machine for managing pipeline stages
-- - Suitable for high-frequency register access
--
-- ============================================================================
-- DESIGN CONSIDERATIONS:
-- ============================================================================
-- - ADDRESS DECODING: Implement logic to map AXI addresses to internal registers
-- - HANDSHAKE LOGIC: Ensure correct AXI VALID/READY handshake for all channels
-- - ERROR HANDLING: Implement SLVERR (Slave Error) response for invalid accesses
-- - GENERICS: Use generics for data width, address width, and number of registers
--
-- ============================================================================
-- IMPLEMENTATION TEMPLATE:
-- ============================================================================
-- [Add your library declarations here]
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--
-- [Add your entity declaration here]
entity axi_interface is
    generic (
        C_AXI_DATA_WIDTH : integer := 32;
        C_AXI_ADDR_WIDTH : integer := 10
    );
    port (
        ACLK : in std_logic;
        ARESETn : in std_logic;
        -- Write Address Channel
        AWADDR : in std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);
        AWVALID : in std_logic;
        AWREADY : out std_logic;
        -- Write Data Channel
        WDATA : in std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
        WSTRB : in std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0);
        WVALID : in std_logic;
        WREADY : out std_logic;
        -- Write Response Channel
        BRESP : out std_logic_vector(1 downto 0);
        BVALID : out std_logic;
        BREADY : in std_logic;
        -- Read Address Channel
        ARADDR : in std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);
        ARVALID : in std_logic;
        ARREADY : out std_logic;
        -- Read Data Channel
        RDATA : out std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
        RRESP : out std_logic_vector(1 downto 0);
        RVALID : out std_logic;
        RREADY : in std_logic;
        -- Internal Slave Interface
        slave_reg_write : out std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);
        slave_reg_wdata : out std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
        slave_reg_read : out std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);
        slave_reg_rdata : in std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0)
    );
end entity axi_interface;
--
-- [Add your architecture implementation here]
architecture rtl of axi_interface is
    -- State machine for AXI write channel
    type write_state_type is (W_IDLE, W_ADDR, W_DATA, W_RESP);
    signal write_state : write_state_type := W_IDLE;
    -- State machine for AXI read channel
    type read_state_type is (R_IDLE, R_ADDR, R_DATA);
    signal read_state : read_state_type := R_IDLE;
    -- Internal signals for AXI handshakes
    signal aw_ready_i : std_logic;
    signal w_ready_i : std_logic;
    signal b_valid_i : std_logic;
    signal ar_ready_i : std_logic;
    signal r_valid_i : std_logic;
    signal r_data_i : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
begin
    -- Assign outputs
    AWREADY <= aw_ready_i;
    WREADY <= w_ready_i;
    BVALID <= b_valid_i;
    ARREADY <= ar_ready_i;
    RVALID <= r_valid_i;
    RDATA <= r_data_i;
    -- AXI Write Channel FSM
    process(ACLK, ARESETn)
    begin
        if ARESETn = '0' then
            write_state <= W_IDLE;
            aw_ready_i <= '0';
            w_ready_i <= '0';
            b_valid_i <= '0';
            BRESP <= "00";
            slave_reg_write <= (others => '0');
            slave_reg_wdata <= (others => '0');
        elsif rising_edge(ACLK) then
            case write_state is
                when W_IDLE =>
                    if AWVALID = '1' then
                        aw_ready_i <= '1';
                        write_state <= W_ADDR;
                    else
                        aw_ready_i <= '0';
                    end if;
                    b_valid_i <= '0';
                when W_ADDR =>
                    aw_ready_i <= '0';
                    if WVALID = '1' then
                        w_ready_i <= '1';
                        slave_reg_write <= AWADDR;
                        slave_reg_wdata <= WDATA;
                        write_state <= W_DATA;
                    else
                        w_ready_i <= '0';
                    end if;
                when W_DATA =>
                    w_ready_i <= '0';
                    b_valid_i <= '1';
                    BRESP <= "00"; -- OKAY response
                    if BREADY = '1' then
                        write_state <= W_IDLE;
                    end if;
                when W_RESP =>
                    b_valid_i <= '0';
                    write_state <= W_IDLE;
            end case;
        end if;
    end process;
    -- AXI Read Channel FSM
    process(ACLK, ARESETn)
    begin
        if ARESETn = '0' then
            read_state <= R_IDLE;
            ar_ready_i <= '0';
            r_valid_i <= '0';
            RRESP <= "00";
            r_data_i <= (others => '0');
            slave_reg_read <= (others => '0');
        elsif rising_edge(ACLK) then
            case read_state is
                when R_IDLE =>
                    if ARVALID = '1' then
                        ar_ready_i <= '1';
                        slave_reg_read <= ARADDR;
                        read_state <= R_ADDR;
                    else
                        ar_ready_i <= '0';
                    end if;
                    r_valid_i <= '0';
                when R_ADDR =>
                    ar_ready_i <= '0';
                    r_valid_i <= '1';
                    RRESP <= "00"; -- OKAY response
                    r_data_i <= slave_reg_rdata; -- Read data from internal slave
                    if RREADY = '1' then
                        read_state <= R_IDLE;
                    end if;
                when R_DATA =>
                    r_valid_i <= '0';
                    read_state <= R_IDLE;
            end case;
        end if;
    end process;
end architecture rtl;
-- ============================================================================