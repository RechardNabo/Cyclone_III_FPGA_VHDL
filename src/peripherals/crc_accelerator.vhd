-- ================================================================================
-- crc_accelerator : Hardware CRC-16/CRC-32 calculator
-- ================================================================================
-- Supports multiple CRC polynomials:
--   * CRC-16-CCITT  (0x1021) - used in X.25, Bluetooth, Modbus
--   * CRC-16-Modbus (0x8005) - used in Modbus RTU
--   * CRC-32        (0x04C11DB7) - used in Ethernet, ZIP, PNG
--
-- AHB-Lite register map:
--   0x00 : CTRL   - [2:0] mode select, [3] reset, [4] bit-reverse input, [5] bit-reverse output
--   0x04 : SEED   - Initial CRC value (written to CRC register on reset)
--   0x08 : DATA   - Write data byte/word to compute CRC
--   0x0C : RESULT - Current CRC result (read-only)
--   0x10 : POLY   - Custom polynomial (optional, overrides mode select)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity crc_accelerator is
    port (
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
        crc_irq   : out std_logic
    );
end entity crc_accelerator;

architecture rtl of crc_accelerator is
    constant CRC16_CCITT  : std_logic_vector(2 downto 0) := "000";
    constant CRC16_MODBUS : std_logic_vector(2 downto 0) := "001";
    constant CRC32_ETH    : std_logic_vector(2 downto 0) := "010";
    constant CRC16_CUSTOM : std_logic_vector(2 downto 0) := "011";
    constant CRC32_CUSTOM : std_logic_vector(2 downto 0) := "100";

    signal mode        : std_logic_vector(2 downto 0) := CRC16_CCITT;
    signal seed        : std_logic_vector(31 downto 0) := x"FFFF0000";
    signal crc_reg     : std_logic_vector(31 downto 0) := x"FFFF0000";
    signal poly_custom : std_logic_vector(31 downto 0) := x"10210000";
    signal bit_rev_in  : std_logic := '0';
    signal bit_rev_out : std_logic := '0';
    signal data_count  : unsigned(15 downto 0) := (others => '0');
    signal done_irq    : std_logic := '0';

    signal reg_offset  : std_logic_vector(7 downto 0);
    signal write_en    : std_logic;

    -- Bit reversal function
    function reverse_bits(v : std_logic_vector; n : integer) return std_logic_vector is
        variable r : std_logic_vector(n-1 downto 0);
    begin
        for i in 0 to n-1 loop
            r(i) := v(n-1-i);
        end loop;
        return r;
    end function;

    -- CRC-16 computation (byte-at-a-time, CCITT polynomial)
    function crc16_next(crc : std_logic_vector(15 downto 0); data_byte : std_logic_vector(7 downto 0);
                        poly : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable c : std_logic_vector(15 downto 0) := crc;
        variable d : std_logic_vector(7 downto 0) := data_byte;
    begin
        for i in 0 to 7 loop
            if (c(15) xor d(7)) = '1' then
                c := (c(14 downto 0) & '0') xor poly;
            else
                c := c(14 downto 0) & '0';
            end if;
            d := d(6 downto 0) & '0';
        end loop;
        return c;
    end function;

    -- CRC-32 computation (byte-at-a-time)
    function crc32_next(crc : std_logic_vector(31 downto 0); data_byte : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable c : std_logic_vector(31 downto 0) := crc;
        variable d : std_logic_vector(7 downto 0) := data_byte;
    begin
        for i in 0 to 7 loop
            if (c(31) xor d(7)) = '1' then
                c := (c(30 downto 0) & '0') xor x"04C11DB7";
            else
                c := c(30 downto 0) & '0';
            end if;
            d := d(6 downto 0) & '0';
        end loop;
        return c;
    end function;

begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;

    ahb_write : process(HCLK, HRESETn)
        variable data_byte : std_logic_vector(7 downto 0);
        variable new_crc16 : std_logic_vector(15 downto 0);
        variable new_crc32 : std_logic_vector(31 downto 0);
        variable poly16   : std_logic_vector(15 downto 0);
    begin
        if HRESETn = '0' then
            mode        <= CRC16_CCITT;
            seed        <= x"FFFF0000";
            crc_reg     <= x"FFFF0000";
            poly_custom <= x"10210000";
            bit_rev_in  <= '0';
            bit_rev_out <= '0';
            data_count  <= (others => '0');
            done_irq    <= '0';
        elsif rising_edge(HCLK) then
            done_irq <= '0';
            if write_en = '1' then
                case reg_offset is
                    when x"00" =>  -- CTRL
                        mode        <= HWDATA(2 downto 0);
                        bit_rev_in  <= HWDATA(4);
                        bit_rev_out <= HWDATA(5);
                        if HWDATA(3) = '1' then  -- reset CRC
                            crc_reg <= seed;
                            data_count <= (others => '0');
                        end if;
                    when x"04" =>  -- SEED
                        seed <= HWDATA;
                    when x"08" =>  -- DATA - process byte
                        if bit_rev_in = '1' then
                            data_byte := reverse_bits(HWDATA(7 downto 0), 8);
                        else
                            data_byte := HWDATA(7 downto 0);
                        end if;
                        case mode is
                            when CRC16_CCITT =>
                                new_crc16 := crc16_next(crc_reg(31 downto 16), data_byte, x"1021");
                                crc_reg <= new_crc16 & x"0000";
                            when CRC16_MODBUS =>
                                new_crc16 := crc16_next(crc_reg(31 downto 16), data_byte, x"8005");
                                crc_reg <= new_crc16 & x"0000";
                            when CRC32_ETH =>
                                new_crc32 := crc32_next(crc_reg, data_byte);
                                crc_reg <= new_crc32;
                            when CRC16_CUSTOM =>
                                poly16 := poly_custom(31 downto 16);
                                new_crc16 := crc16_next(crc_reg(31 downto 16), data_byte, poly16);
                                crc_reg <= new_crc16 & x"0000";
                            when CRC32_CUSTOM =>
                                new_crc32 := crc32_next(crc_reg, data_byte);
                                crc_reg <= new_crc32;
                            when others => null;
                        end case;
                        data_count <= data_count + 1;
                        done_irq <= '1';
                    when x"10" =>  -- POLY custom
                        poly_custom <= HWDATA;
                    when others => null;
                end case;
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, HADDR, reg_offset, crc_reg, mode, seed, poly_custom,
                       bit_rev_in, bit_rev_out, data_count)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"00" =>
                    rdata(2 downto 0) := mode;
                    rdata(4) := bit_rev_in;
                    rdata(5) := bit_rev_out;
                when x"04" => rdata := seed;
                when x"0C" =>
                    if bit_rev_out = '1' then
                        rdata := reverse_bits(crc_reg, 32);
                    else
                        rdata := crc_reg;
                    end if;
                when x"10" => rdata := poly_custom;
                when x"14" => rdata := std_logic_vector(data_count);
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    crc_irq   <= done_irq;

end architecture rtl;
