-- ============================================================================
-- SPI Slave Controller
-- ============================================================================
-- Responds to an SPI master. When the master asserts SS (low) and
-- generates SCK, this slave shifts data out on MISO and reads data
-- in on MOSI simultaneously (full-duplex). After 8 clocks the
-- received byte is available on rx_data and rx_valid pulses high.
-- Supports CPOL and CPHA for mode matching with the master.
-- Beginner-friendly, synthesizable VHDL for the Cyclone III FPGA.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_slave is
    port (
        clk      : in  std_logic;       -- system clock
        reset    : in  std_logic;
        -- SPI mode (must match master)
        cpol     : in  std_logic;
        cpha     : in  std_logic;
        -- SPI bus (driven by master)
        sck      : in  std_logic;
        mosi     : in  std_logic;
        miso     : out std_logic;
        ss       : in  std_logic;       -- slave select (active low)
        -- CPU interface
        tx_data  : in  std_logic_vector(7 downto 0); -- byte to send back
        tx_load  : in  std_logic;       -- load tx_data into shift register
        rx_data  : out std_logic_vector(7 downto 0); -- received byte
        rx_valid : out std_logic        -- pulse high when byte received
    );
end entity spi_slave;

architecture rtl of spi_slave is
    signal tx_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_cnt  : integer range 0 to 7 := 0;
    signal sck_prev : std_logic := '0';
    signal active   : std_logic := '0';
begin

    spi_slave_proc : process(clk, reset)
    begin
        if reset = '1' then
            tx_reg    <= (others => '0');
            rx_reg    <= (others => '0');
            miso      <= '0';
            bit_cnt   <= 0;
            sck_prev  <= '0';
            rx_valid  <= '0';
            rx_data   <= (others => '0');
            active    <= '0';
        elsif rising_edge(clk) then
            rx_valid <= '0';  -- default

            -- Load data to send when CPU requests
            if tx_load = '1' then
                tx_reg <= tx_data;
            end if;

            -- Only operate when selected (SS low)
            if ss = '1' then
                active   <= '0';
                bit_cnt  <= 0;
                sck_prev <= sck;
                miso     <= 'Z';  -- not selected: high-impedance
            else
                active <= '1';
                miso   <= tx_reg(7);  -- output MSB first

                -- Detect SCK edges
                if sck /= sck_prev then
                    if cpha = '0' then
                        -- Mode 0/2: sample on leading edge, shift on trailing
                        if sck = cpol then
                            -- Leading edge: sample MOSI
                            rx_reg <= rx_reg(6 downto 0) & mosi;
                            if bit_cnt = 7 then
                                rx_data  <= rx_reg(6 downto 0) & mosi;
                                rx_valid <= '1';
                                bit_cnt  <= 0;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        else
                            -- Trailing edge: shift TX register
                            tx_reg <= tx_reg(6 downto 0) & '0';
                        end if;
                    else
                        -- Mode 1/3: shift on leading edge, sample on trailing
                        if sck = cpol then
                            -- Leading edge: shift TX register
                            tx_reg <= tx_reg(6 downto 0) & '0';
                        else
                            -- Trailing edge: sample MOSI
                            rx_reg <= rx_reg(6 downto 0) & mosi;
                            if bit_cnt = 7 then
                                rx_data  <= rx_reg(6 downto 0) & mosi;
                                rx_valid <= '1';
                                bit_cnt  <= 0;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        end if;
                    end if;
                    sck_prev <= sck;
                end if;
            end if;
        end if;
    end process spi_slave_proc;

end architecture rtl;
