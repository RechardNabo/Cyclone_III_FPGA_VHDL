-- ============================================================================
-- Wishbone Classic Slave Interface
-- Target: Altera/Intel Cyclone III FPGA
--
-- Description:
--   A simple Wishbone classic (B4) slave with 32-bit data.
--   Supports single-cycle read and write to one internal register.
--   Uses cyc/stb/we/ack handshaking per the Wishbone specification.
--
-- Beginner Notes:
--   * CYC (cycle) and STB (strobe) must both be 1 for a valid access.
--   * The slave asserts ACK (acknowledge) for one cycle when done.
--   * WE = 1 means write, WE = 0 means read.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity wishbone_interface is
    generic (
        DATA_WIDTH : integer := 32;  -- Data bus width
        ADDR_WIDTH : integer := 32   -- Address bus width
    );
    port (
        -- Clock and reset (active high)
        clk_i : in  std_logic;
        rst_i : in  std_logic;

        -- Wishbone master -> slave (inputs)
        cyc_i : in  std_logic;                                    -- Cycle valid
        stb_i : in  std_logic;                                    -- Strobe
        we_i  : in  std_logic;                                    -- Write enable
        adr_i : in  std_logic_vector(ADDR_WIDTH-1 downto 0);     -- Address
        dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);     -- Data from master

        -- Wishbone slave -> master (outputs)
        dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);     -- Data to master
        ack_o : out std_logic;                                    -- Acknowledge
        err_o : out std_logic                                     -- Error (unused)
    );
end entity wishbone_interface;

architecture rtl of wishbone_interface is

    -- Internal storage register accessible via the bus
    signal internal_reg : std_logic_vector(DATA_WIDTH-1 downto 0) :=
        (others => '0');

    -- Registered acknowledge and output data
    signal ack_reg : std_logic := '0';
    signal dat_reg : std_logic_vector(DATA_WIDTH-1 downto 0) :=
        (others => '0');

begin

    -- -------------------------------------------------------------------------
    -- Wishbone slave process: respond to valid bus cycles
    -- -------------------------------------------------------------------------
    wb_slave : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                internal_reg <= (others => '0');
                ack_reg      <= '0';
                dat_reg      <= (others => '0');
            else
                -- Default: no acknowledge this cycle
                ack_reg <= '0';

                -- A valid Wishbone access requires both CYC and STB high
                if cyc_i = '1' and stb_i = '1' then
                    if we_i = '1' then
                        -- Write: store master data into internal register
                        internal_reg <= dat_i;
                        ack_reg      <= '1';
                    else
                        -- Read: return internal register value to master
                        dat_reg <= internal_reg;
                        ack_reg <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process wb_slave;

    -- Drive outputs from registers
    dat_o <= dat_reg;
    ack_o <= ack_reg;
    err_o <= '0';  -- No error condition in this simple design

end architecture rtl;
