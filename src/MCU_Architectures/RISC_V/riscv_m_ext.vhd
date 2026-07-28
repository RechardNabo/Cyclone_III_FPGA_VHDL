library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- RISC-V RV32M (Multiply/Divide extension)
-- Implements: MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
-- AHB-Lite slave with register interface: CTRL, OP_A, OP_B, RESULT_LO, RESULT_HI, STAT
-- CTRL bits [2:0]: 000=MUL, 001=MULH, 010=MULHSU, 011=MULHU,
--                  100=DIV, 101=DIVU, 110=REM, 111=REMU

entity riscv_m_ext is
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
        mul_irq     : out std_logic
    );
end entity riscv_m_ext;

architecture rtl of riscv_m_ext is

    constant ADDR_CTRL      : std_logic_vector(2 downto 0) := "000";
    constant ADDR_OP_A      : std_logic_vector(2 downto 0) := "001";
    constant ADDR_OP_B      : std_logic_vector(2 downto 0) := "010";
    constant ADDR_RESULT_LO : std_logic_vector(2 downto 0) := "011";
    constant ADDR_RESULT_HI : std_logic_vector(2 downto 0) := "100";
    constant ADDR_STAT      : std_logic_vector(2 downto 0) := "101";

    signal ctrl      : std_logic_vector(2 downto 0);
    signal op_a      : std_logic_vector(31 downto 0);
    signal op_b      : std_logic_vector(31 downto 0);
    signal result_lo : std_logic_vector(31 downto 0);
    signal result_hi : std_logic_vector(31 downto 0);
    signal stat      : std_logic_vector(31 downto 0); -- [0]=done, [1]=div_by_zero

    signal write_en  : std_logic;
    signal addr_idx  : std_logic_vector(2 downto 0);
    signal rdata_int : std_logic_vector(31 downto 0);
    signal start     : std_logic;

begin

    addr_idx  <= HADDR(4 downto 2);
    write_en  <= HSEL and HWRITE and HREADY when HTRANS = "10" else '0';
    start     <= write_en when addr_idx = ADDR_CTRL else '0';
    mul_irq   <= stat(0);

    process(HCLK, HRESETn)
        variable a_signed   : signed(31 downto 0);
        variable b_signed   : signed(31 downto 0);
        variable a_uns      : unsigned(31 downto 0);
        variable b_uns      : unsigned(31 downto 0);
        variable prod_s     : signed(63 downto 0);
        variable prod_u     : unsigned(63 downto 0);
        variable div_res    : signed(31 downto 0);
        variable div_rem    : signed(31 downto 0);
        variable divu_res   : unsigned(31 downto 0);
        variable divu_rem   : unsigned(31 downto 0);
    begin
        if HRESETn = '0' then
            ctrl      <= (others => '0');
            op_a      <= (others => '0');
            op_b      <= (others => '0');
            result_lo <= (others => '0');
            result_hi <= (others => '0');
            stat      <= (others => '0');
            rdata_int <= (others => '0');
        elsif rising_edge(HCLK) then
            -- AHB write
            if write_en = '1' then
                case addr_idx is
                    when ADDR_CTRL => ctrl <= HWDATA(2 downto 0);
                    when ADDR_OP_A => op_a <= HWDATA;
                    when ADDR_OP_B => op_b <= HWDATA;
                    when others => null;
                end case;
            end if;

            -- compute on start
            if start = '1' then
                stat(1) <= '0'; -- clear div_by_zero
                a_signed := signed(op_a);
                b_signed := signed(op_b);
                a_uns    := unsigned(op_a);
                b_uns    := unsigned(op_b);

                case ctrl is
                    when "000" => -- MUL
                        prod_s := a_signed * b_signed;
                        result_lo <= std_logic_vector(prod_s(31 downto 0));
                        result_hi <= (others => '0');
                    when "001" => -- MULH (signed*signed)
                        prod_s := a_signed * b_signed;
                        result_lo <= (others => '0');
                        result_hi <= std_logic_vector(prod_s(63 downto 32));
                    when "010" => -- MULHSU (signed*unsigned)
                        prod_s := a_signed * signed(op_b);
                        result_lo <= (others => '0');
                        result_hi <= std_logic_vector(prod_s(63 downto 32));
                    when "011" => -- MULHU (unsigned*unsigned)
                        prod_u := a_uns * b_uns;
                        result_lo <= (others => '0');
                        result_hi <= std_logic_vector(prod_u(63 downto 32));
                    when "100" => -- DIV
                        if op_b = x"00000000" then
                            result_lo <= x"FFFFFFFF";
                            stat(1) <= '1';
                        elsif op_a = x"80000000" and op_b = x"FFFFFFFF" then
                            result_lo <= x"80000000";
                        else
                            div_res := a_signed / b_signed;
                            result_lo <= std_logic_vector(div_res);
                        end if;
                    when "101" => -- DIVU
                        if op_b = x"00000000" then
                            result_lo <= x"FFFFFFFF";
                            stat(1) <= '1';
                        else
                            divu_res := a_uns / b_uns;
                            result_lo <= std_logic_vector(divu_res);
                        end if;
                    when "110" => -- REM
                        if op_b = x"00000000" then
                            result_lo <= op_a;
                            stat(1) <= '1';
                        elsif op_a = x"80000000" and op_b = x"FFFFFFFF" then
                            result_lo <= (others => '0');
                        else
                            div_rem := a_signed rem b_signed;
                            result_lo <= std_logic_vector(div_rem);
                        end if;
                    when "111" => -- REMU
                        if op_b = x"00000000" then
                            result_lo <= op_a;
                            stat(1) <= '1';
                        else
                            divu_rem := a_uns rem b_uns;
                            result_lo <= std_logic_vector(divu_rem);
                        end if;
                    when others => null;
                end case;
                stat(0) <= '1'; -- done flag
            end if;

            -- AHB read
            if HSEL = '1' and HWRITE = '0' and HREADY = '1' and HTRANS = "10" then
                case addr_idx is
                    when ADDR_CTRL      => rdata_int <= x"0000000" & "0" & ctrl;
                    when ADDR_OP_A      => rdata_int <= op_a;
                    when ADDR_OP_B      => rdata_int <= op_b;
                    when ADDR_RESULT_LO => rdata_int <= result_lo;
                    when ADDR_RESULT_HI => rdata_int <= result_hi;
                    when ADDR_STAT      => rdata_int <= stat;
                    when others => rdata_int <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    HRDATA    <= rdata_int;
    HRESP     <= '0';
    HREADYOUT <= '1';

end architecture rtl;
