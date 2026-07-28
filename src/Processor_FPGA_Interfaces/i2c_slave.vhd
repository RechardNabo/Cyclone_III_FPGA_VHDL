-- ============================================================================
-- I2C Slave Controller
-- Target: Altera/Intel Cyclone III FPGA
-- 7-bit address, 8-bit data register, SDA/SCL, simple register read/write.
-- Start: SDA falls while SCL high. Stop: SDA rises while SCL high.
-- Data sampled on SCL rising edge. Slave pulls SDA low for ACK.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity i2c_slave is
    generic (
        SLAVE_ADDRESS : std_logic_vector(6 downto 0) := "0101001"
    );
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        scl_i        : in  std_logic;
        sda_i        : in  std_logic;
        sda_o        : out std_logic;
        reg_write_o  : out std_logic_vector(7 downto 0);
        reg_read_i   : in  std_logic_vector(7 downto 0);
        write_strobe : out std_logic
    );
end entity i2c_slave;

architecture rtl of i2c_slave is
    type state_t is (IDLE, ADDR, ACK_ADDR, WR_DATA, ACK_WR,
                     RD_DATA, ACK_RD, STOP);
    signal state       : state_t := IDLE;
    signal scl_s1, scl_s2 : std_logic := '1';
    signal sda_s1, sda_s2 : std_logic := '1';
    signal scl_prev    : std_logic := '1';
    signal shift_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_cnt     : integer range 0 to 8 := 0;
    signal rw_bit      : std_logic := '0';
    signal addr_match  : std_logic := '0';
    signal write_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal ack_seen_low : std_logic := '0';  -- Tracks SCL low in ACK states
begin

    -- Synchronizers for async I2C bus signals
    sync_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                scl_s1 <= '1'; scl_s2 <= '1';
                sda_s1 <= '1'; sda_s2 <= '1';
            else
                scl_s1 <= scl_i; scl_s2 <= scl_s1;
                sda_s1 <= sda_i; sda_s2 <= sda_s1;
            end if;
        end if;
    end process sync_proc;

    -- Main I2C slave FSM
    i2c_fsm : process(clk_i)
        variable start_cond : boolean;
        variable stop_cond  : boolean;
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state <= IDLE; sda_o <= '1'; shift_reg <= (others => '0');
                bit_cnt <= 0; rw_bit <= '0'; addr_match <= '0';
                write_reg <= (others => '0'); write_strobe <= '0';
                scl_prev <= '1';
                ack_seen_low <= '0';
            else
                sda_o <= '1';  -- Default: release SDA
                write_strobe <= '0';
                -- START: SDA falls (high->low) while SCL high
                -- sda_s2 is older (2 cycles), sda_s1 is newer (1 cycle)
                start_cond := (scl_s2 = '1') and (sda_s2 = '1') and (sda_s1 = '0');
                -- STOP: SDA rises (low->high) while SCL high
                stop_cond  := (scl_s2 = '1') and (sda_s2 = '0') and (sda_s1 = '1');
                scl_prev <= scl_s2;

                if start_cond then
                    state <= ADDR; bit_cnt <= 0;
                    ack_seen_low <= '0';
                elsif stop_cond then
                    state <= IDLE;
                    ack_seen_low <= '0';
                else
                    case state is
                        when IDLE => null;
                        when ADDR =>
                            if scl_s2 = '1' and scl_prev = '0' then
                                if bit_cnt < 7 then
                                    shift_reg(6-bit_cnt) <= sda_s2;
                                    bit_cnt <= bit_cnt + 1;
                                else
                                    rw_bit <= sda_s2;
                                    if shift_reg(6 downto 0) = SLAVE_ADDRESS then
                                        addr_match <= '1';
                                    else
                                        addr_match <= '0';
                                    end if;
                                    bit_cnt <= 0; state <= ACK_ADDR;
                                    ack_seen_low <= '0';
                                end if;
                            end if;
                        when ACK_ADDR =>
                            if addr_match = '1' then sda_o <= '0'; end if;
                            -- Track when SCL goes low (marks end of data bit SCL cycle)
                            if scl_s2 = '0' then
                                ack_seen_low <= '1';
                            end if;
                            -- Only transition on SCL falling edge AFTER
                            -- seeing SCL low (i.e., the ACK clock's falling edge,
                            -- not the data bit's falling edge)
                            if scl_s2 = '0' and scl_prev = '1' and ack_seen_low = '1' then
                                if rw_bit = '0' then state <= WR_DATA;
                                else state <= RD_DATA; end if;
                                bit_cnt <= 0;
                                ack_seen_low <= '0';
                            end if;
                        when WR_DATA =>
                            if scl_s2 = '1' and scl_prev = '0' then
                                if bit_cnt < 8 then
                                    shift_reg(7-bit_cnt) <= sda_s2;
                                    bit_cnt <= bit_cnt + 1;
                                end if;
                                if bit_cnt = 7 then
                                    state <= ACK_WR;
                                    ack_seen_low <= '0';
                                end if;
                            end if;
                        when ACK_WR =>
                            sda_o <= '0';
                            if scl_s2 = '0' then
                                ack_seen_low <= '1';
                            end if;
                            if scl_s2 = '0' and scl_prev = '1' and ack_seen_low = '1' then
                                write_reg <= shift_reg;
                                write_strobe <= '1';
                                bit_cnt <= 0; state <= WR_DATA;
                                ack_seen_low <= '0';
                            end if;
                        when RD_DATA =>
                            if bit_cnt < 8 then
                                sda_o <= reg_read_i(7-bit_cnt);
                                if scl_s2 = '1' and scl_prev = '0' then
                                    bit_cnt <= bit_cnt + 1;
                                end if;
                            else
                                state <= ACK_RD;
                            end if;
                        when ACK_RD =>
                            if scl_s2 = '1' and scl_prev = '0' then
                                if sda_s2 = '0' then
                                    bit_cnt <= 0; state <= RD_DATA;
                                else state <= STOP; end if;
                            end if;
                        when STOP => state <= IDLE;
                    end case;
                end if;
            end if;
        end if;
    end process i2c_fsm;

    reg_write_o <= write_reg;

end architecture rtl;
