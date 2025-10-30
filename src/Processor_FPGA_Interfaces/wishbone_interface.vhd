-- ============================================================================
-- Project: FPGA-Optimized Wishbone Interface
--
-- Description:
-- This VHDL module implements a Wishbone Bus interface, optimized for FPGA
-- integration. The Wishbone Bus is a popular, open-source hardware interface
-- that facilitates communication between various IP cores within a System-on-Chip (SoC)
-- or FPGA design. This implementation focuses on creating a compliant Wishbone
-- slave interface, allowing a master (e.g., a soft-core processor) to access
-- and control registers or memory blocks within the FPGA fabric.
--
-- Learning Objectives:
-- 1. Understand the Wishbone Bus specification (Rev. B4 or later).
-- 2. Learn how to implement a Wishbone slave interface in VHDL.
-- 3. Understand the different Wishbone cycles (e.g., single read/write, block transfer).
-- 4. Develop control logic for Wishbone handshaking signals (ACK, STB, CYC, WE, etc.).
-- 5. Gain experience in designing a robust and efficient bus interface for FPGAs.
-- 6. Learn how to integrate Wishbone-compliant IP cores into a larger system.
--
-- Implementation Guidance:
-- 1. **Wishbone Specification**: Refer to the official Wishbone Bus specification
--    (e.g., Rev. B4) for detailed signal definitions, timing diagrams, and transaction types.
-- 2. **Slave Interface**: Implement the slave logic that responds to a Wishbone master.
--    This involves decoding the address, handling read/write operations, and generating
--    the appropriate acknowledge (ACK) and error (ERR) signals.
-- 3. **Address Decoding**: Design a robust address decoding mechanism to map Wishbone
--    addresses to internal registers or memory blocks. This can be done using a simple
--    combinatorial logic or a more complex state machine for multiple address ranges.
-- 4. **Read/Write Operations**: Implement the logic for reading data from internal
--    registers/memory and writing data to them. Ensure proper data alignment and byte
--    enable (SEL) handling.
-- 5. **Handshaking**: Correctly implement the Wishbone handshaking protocol, including
--    `cyc_i` (cycle), `stb_i` (strobe), `we_i` (write enable), `adr_i` (address),
--    `dat_i` (data in), `dat_o` (data out), `ack_o` (acknowledge), and `err_o` (error).
-- 6. **State Machine**: A state machine is often useful for managing the different
--    phases of a Wishbone transaction (e.g., idle, read, write, acknowledge).
-- 7. **Generics**: Use generics for configurable parameters like data width, address width,
--    and base address, to make the module reusable.
-- 8. **Testbench Development**: Create a comprehensive testbench that simulates Wishbone
--    master transactions (single read/write, burst transfers) to verify the slave's
--    correct behavior and compliance with the specification.
--
-- ----------------------------------------------------------------------------
-- Architecture:
-- A Wishbone slave interface typically consists of:
-- - Input/Output Ports: For all Wishbone signals.
-- - Address Decoder: To determine which internal resource is being accessed.
-- - Read/Write Logic: To handle data transfers to/from internal registers/memory.
-- - Control State Machine: To manage the Wishbone transaction flow.
-- - Internal Registers/Memory: The actual resources being accessed by the master.
--
-- This VHDL template provides a basic structure for a Wishbone slave interface.
-- The internal logic for address decoding and data access will need to be
-- customized based on the specific application requirements.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wishbone_interface is
    generic (
        DATA_WIDTH      : natural := 32; -- Wishbone data bus width
        ADDR_WIDTH      : natural := 32  -- Wishbone address bus width
    );
    port (
        -- Global Signals
        clk_i           : in  std_logic;
        rst_i           : in  std_logic;

        -- Wishbone Master Interface (Inputs to Slave)
        cyc_i           : in  std_logic; -- Cycle valid
        stb_i           : in  std_logic; -- Strobe
        we_i            : in  std_logic; -- Write enable
        adr_i           : in  std_logic_vector(ADDR_WIDTH-1 downto 0); -- Address
        dat_i           : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- Data in
        sel_i           : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0); -- Byte select

        -- Wishbone Slave Interface (Outputs from Slave)
        dat_o           : out std_logic_vector(DATA_WIDTH-1 downto 0); -- Data out
        ack_o           : out std_logic; -- Acknowledge
        err_o           : out std_logic; -- Error
        rty_o           : out std_logic  -- Retry
    );
end entity wishbone_interface;

architecture rtl of wishbone_interface is

    -- Internal signals for data and control
    signal internal_register : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ack_reg           : std_logic;
    signal err_reg           : std_logic;

begin

    -- Wishbone Slave Logic
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg <= '0';
                err_reg <= '0';
                internal_register <= (others => '0');
                dat_o <= (others => '0');
            else
                ack_reg <= '0'; -- Default to no acknowledge
                err_reg <= '0'; -- Default to no error

                if cyc_i = '1' and stb_i = '1' then
                    -- Valid Wishbone cycle
                    if we_i = '1' then
                        -- Write operation
                        -- Example: Write to internal_register if address matches
                        if adr_i = X"00000000" then -- Example address
                            internal_register <= dat_i;
                            ack_reg <= '1';
                        else
                            err_reg <= '1'; -- Address mismatch
                        end if;
                    else
                        -- Read operation
                        -- Example: Read from internal_register if address matches
                        if adr_i = X"00000000" then -- Example address
                            dat_o <= internal_register;
                            ack_reg <= '1';
                        else
                            err_reg <= '1'; -- Address mismatch
                            dat_o <= (others => '0');
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    ack_o <= ack_reg;
    err_o <= err_reg;
    rty_o <= '0'; -- Not implementing retry for this basic example

end architecture rtl;