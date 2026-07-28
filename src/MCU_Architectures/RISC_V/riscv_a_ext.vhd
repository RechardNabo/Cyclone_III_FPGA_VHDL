library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- RISC-V RV32A (Atomic extension)
-- Implements: LR.W, SC.W, AMOSWAP.W, AMOADD.W, AMOAND.W, AMOOR.W,
--             AMOXOR.W, AMOMIN.W, AMOMAX.W, AMOMINU.W, AMOMAXU.W
-- AHB-Lite slave with register interface: CTRL, ADDR, OP_DATA, RESULT, RESERVATION_SET
-- CTRL bits [3:0]: 0000=LR.W, 0001=SC.W, 0010=AMOSWAP, 0011=AMOADD,
--                  0100=AMOAND, 0101=AMOOR, 0110=AMOXOR,
--                  0111=AMOMIN, 1000=AMOMAX, 1001=AMOMINU, 1010=AMOMAXU

entity riscv_a_ext is
    port (
        HCLK        : in  std_logic;
        HRESETn     : in  std_logic;
        HSEL        : in  std_logic;
        HWRITE      : in  std_logic;
        HREADY      : in  std_logic;
        HTRANS      : in  std_logic_vector(1 downto 0);
        HSIZE       : in  std_logic_vector(2 downto 0);
        HADDR       : in  std_logic_vector(31 downto 0);
        HWDATA      : in  std_logic_vector(31 downto 0);
        HRDATA      : out std_logic_vector(31 downto 0);
        HRESP       : out std_logic;
        HREADYOUT   : out std_logic;
        amo_irq     : out std_logic
    );
end entity riscv_a_ext;

architecture rtl of riscv_a_ext is

    constant ADDR_CTRL       : std_logic_vector(2 downto 0) := "000";
    constant ADDR_AMO_ADDR   : std_logic_vector(2 downto 0) := "001";
    constant ADDR_OP_DATA    : std_logic_vector(2 downto 0) := "010";
    constant ADDR_RESULT     : std_logic_vector(2 downto 0) := "011";
    constant ADDR_RESERVATION: std_logic_vector(2 downto 0) := "100";

    signal ctrl        : std_logic_vector(3 downto 0);
    signal amo_addr    : std_logic_vector(31 downto 0);
    signal op_data     : std_logic_vector(31 downto 0);
    signal result      : std_logic_vector(31 downto 0);
    signal reservation : std_logic_vector(31 downto 0);
    signal reserv_valid: std_logic;

    signal write_en    : std_logic;
    signal addr_idx    : std_logic_vector(2 downto 0);
    signal rdata_int   : std_logic_vector(31 downto 0);
    signal start       : std_logic;

begin

    addr_idx  <= HADDR(4 downto 2);
    write_en  <= HSEL and HWRITE and HREADY when HTRANS = "10" else '0';
    start     <= write_en when addr_idx = ADDR_CTRL else '0';
    amo_irq   <= start;

    process(HCLK, HRESETn)
        variable a_s : signed(31 downto 0);
        variable b_s : signed(31 downto 0);
        variable a_u : unsigned(31 downto 0);
        variable b_u : unsigned(31 downto 0);
    begin
        if HRESETn = '0' then
            ctrl         <= (others => '0');
            amo_addr     <= (others => '0');
            op_data      <= (others => '0');
            result       <= (others => '0');
            reservation  <= (others => '0');
            reserv_valid <= '0';
            rdata_int    <= (others => '0');
        elsif rising_edge(HCLK) then
            -- AHB write to registers
            if write_en = '1' then
                case addr_idx is
                    when ADDR_CTRL    => ctrl     <= HWDATA(3 downto 0);
                    when ADDR_AMO_ADDR=> amo_addr <= HWDATA;
                    when ADDR_OP_DATA => op_data  <= HWDATA;
                    when others => null;
                end case;
            end if;

            -- AMO operation on start
            if start = '1' then
                a_s := signed(op_data);
                b_s := signed(result);
                a_u := unsigned(op_data);
                b_u := unsigned(result);

                case ctrl is
                    when "0000" => -- LR.W: load and set reservation
                        result       <= op_data; -- simulates memory read
                        reservation  <= amo_addr;
                        reserv_valid <= '1';
                    when "0001" => -- SC.W: store conditional
                        if reserv_valid = '1' and reservation = amo_addr then
                            result       <= x"00000000"; -- success
                            reserv_valid <= '0';
                        else
                            result <= x"00000001"; -- failure
                        end if;
                    when "0010" => -- AMOSWAP.W
                        result <= op_data;
                    when "0011" => -- AMOADD.W
                        result <= std_logic_vector(a_s + b_s);
                    when "0100" => -- AMOAND.W
                        result <= op_data and result;
                    when "0101" => -- AMOOR.W
                        result <= op_data or result;
                    when "0110" => -- AMOXOR.W
                        result <= op_data xor result;
                    when "0111" => -- AMOMIN.W (signed)
                        if a_s < b_s then
                            result <= op_data;
                        else
                            result <= result;
                        end if;
                    when "1000" => -- AMOMAX.W (signed)
                        if a_s > b_s then
                            result <= op_data;
                        else
                            result <= result;
                        end if;
                    when "1001" => -- AMOMINU.W (unsigned)
                        if a_u < b_u then
                            result <= op_data;
                        else
                            result <= result;
                        end if;
                    when "1010" => -- AMOMAXU.W (unsigned)
                        if a_u > b_u then
                            result <= op_data;
                        else
                            result <= result;
                        end if;
                    when others => null;
                end case;
            end if;

            -- AHB read
            if HSEL = '1' and HWRITE = '0' and HREADY = '1' and HTRANS = "10" then
                case addr_idx is
                    when ADDR_CTRL        => rdata_int <= x"000000" & "0000" & ctrl;
                    when ADDR_AMO_ADDR    => rdata_int <= amo_addr;
                    when ADDR_OP_DATA     => rdata_int <= op_data;
                    when ADDR_RESULT      => rdata_int <= result;
                    when ADDR_RESERVATION => rdata_int <= x"0000000" & "000" & reserv_valid;
                    when others => rdata_int <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    HRDATA    <= rdata_int;
    HRESP     <= '0';
    HREADYOUT <= '1';

end architecture rtl;
