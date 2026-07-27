-- ============================================================================
-- AXI4-Lite Slave Interface (Simplified)
-- Target: Altera/Intel Cyclone III FPGA
-- 5 channels (AW, W, B, AR, R), 32-bit data, simple register read/write.
-- AXI uses VALID/READY handshake; transfer occurs when both are high.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity axi_interface is
    generic (
        C_AXI_DATA_WIDTH : integer := 32;
        C_AXI_ADDR_WIDTH : integer := 4
    );
    port (
        ACLK    : in  std_logic;
        ARESETn : in  std_logic;
        -- Write Address Channel
        AWADDR  : in  std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);
        AWVALID : in  std_logic;
        AWREADY : out std_logic;
        -- Write Data Channel
        WDATA   : in  std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
        WVALID  : in  std_logic;
        WREADY  : out std_logic;
        -- Write Response Channel
        BRESP   : out std_logic_vector(1 downto 0);
        BVALID  : out std_logic;
        BREADY  : in  std_logic;
        -- Read Address Channel
        ARADDR  : in  std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);
        ARVALID : in  std_logic;
        ARREADY : out std_logic;
        -- Read Data Channel
        RDATA   : out std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
        RRESP   : out std_logic_vector(1 downto 0);
        RVALID  : out std_logic;
        RREADY  : in  std_logic
    );
end entity axi_interface;

architecture rtl of axi_interface is
    type w_state_t is (W_IDLE, W_DATA, W_RESP);
    type r_state_t is (R_IDLE, R_RESP);
    signal w_state   : w_state_t := W_IDLE;
    signal r_state   : r_state_t := R_IDLE;
    signal reg_file  : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) :=
        (others => '0');
begin

    -- Write Channel FSM: AW -> W -> B
    write_fsm : process(ACLK)
    begin
        if rising_edge(ACLK) then
            if ARESETn = '0' then
                w_state  <= W_IDLE;
                AWREADY  <= '0';
                WREADY   <= '0';
                BVALID   <= '0';
                BRESP    <= "00";
                reg_file <= (others => '0');
            else
                case w_state is
                    when W_IDLE =>
                        BVALID <= '0'; WREADY <= '0';
                        if AWVALID = '1' then
                            AWREADY <= '1';
                            w_state <= W_DATA;
                        else
                            AWREADY <= '0';
                        end if;
                    when W_DATA =>
                        AWREADY <= '0';
                        if WVALID = '1' then
                            WREADY  <= '1';
                            reg_file <= WDATA;  -- Store data
                            BVALID  <= '1';
                            BRESP   <= "00";    -- OKAY
                            w_state <= W_RESP;
                        else
                            WREADY <= '0';
                        end if;
                    when W_RESP =>
                        WREADY <= '0';
                        if BREADY = '1' then
                            BVALID  <= '0';
                            w_state <= W_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process write_fsm;

    -- Read Channel FSM: AR -> R
    read_fsm : process(ACLK)
    begin
        if rising_edge(ACLK) then
            if ARESETn = '0' then
                r_state <= R_IDLE;
                ARREADY <= '0';
                RVALID  <= '0';
                RRESP   <= "00";
                RDATA   <= (others => '0');
            else
                case r_state is
                    when R_IDLE =>
                        RVALID <= '0';
                        if ARVALID = '1' then
                            ARREADY <= '1';
                            RDATA   <= reg_file;  -- Return register value
                            RRESP   <= "00";
                            r_state <= R_RESP;
                        else
                            ARREADY <= '0';
                        end if;
                    when R_RESP =>
                        ARREADY <= '0';
                        RVALID  <= '1';
                        if RREADY = '1' then
                            RVALID  <= '0';
                            r_state <= R_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process read_fsm;

end architecture rtl;
