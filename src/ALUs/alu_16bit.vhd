-- 16-bit ALU for Cyclone III FPGA
-- Operations: ADD, SUB, AND, OR, XOR, NOT, SLL, SRL, SRA, ROL, ROR, CMP, INC, DEC, MUL, PASS
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity alu_16bit is
    port (
        a        : in  std_logic_vector(15 downto 0);
        b        : in  std_logic_vector(15 downto 0);
        alu_op   : in  std_logic_vector(3 downto 0);
        result   : out std_logic_vector(15 downto 0);
        zero     : out std_logic;
        carry    : out std_logic;
        overflow : out std_logic;
        negative : out std_logic;
        parity   : out std_logic
    );
end entity alu_16bit;

architecture rtl of alu_16bit is

    constant OP_ADD  : std_logic_vector(3 downto 0) := "0000";
    constant OP_SUB  : std_logic_vector(3 downto 0) := "0001";
    constant OP_AND  : std_logic_vector(3 downto 0) := "0010";
    constant OP_OR   : std_logic_vector(3 downto 0) := "0011";
    constant OP_XOR  : std_logic_vector(3 downto 0) := "0100";
    constant OP_NOT  : std_logic_vector(3 downto 0) := "0101";
    constant OP_SLL  : std_logic_vector(3 downto 0) := "0110";
    constant OP_SRL  : std_logic_vector(3 downto 0) := "0111";
    constant OP_SRA  : std_logic_vector(3 downto 0) := "1000";
    constant OP_ROL  : std_logic_vector(3 downto 0) := "1001";
    constant OP_ROR  : std_logic_vector(3 downto 0) := "1010";
    constant OP_CMP  : std_logic_vector(3 downto 0) := "1011";
    constant OP_INC  : std_logic_vector(3 downto 0) := "1100";
    constant OP_DEC  : std_logic_vector(3 downto 0) := "1101";
    constant OP_MUL  : std_logic_vector(3 downto 0) := "1110";
    constant OP_PASS : std_logic_vector(3 downto 0) := "1111";

    signal res : std_logic_vector(15 downto 0);

begin

    process(a, b, alu_op)
        variable sum_ext : unsigned(16 downto 0);
        variable sub_ext : unsigned(16 downto 0);
        variable prod    : unsigned(31 downto 0);
    begin
        res      <= (others => '0');
        carry    <= '0';
        overflow <= '0';

        case alu_op is

            when OP_ADD =>  -- A + B
                sum_ext := ('0' & unsigned(a)) + ('0' & unsigned(b));
                res      <= std_logic_vector(sum_ext(15 downto 0));
                carry    <= sum_ext(16);
                overflow <= (a(15) and b(15) and (not sum_ext(15))) or
                            ((not a(15)) and (not b(15)) and sum_ext(15));

            when OP_SUB =>  -- A - B
                sub_ext := ('0' & unsigned(a)) - ('0' & unsigned(b));
                res      <= std_logic_vector(sub_ext(15 downto 0));
                carry    <= sub_ext(16);
                overflow <= (a(15) and (not b(15)) and (not sub_ext(15))) or
                            ((not a(15)) and b(15) and sub_ext(15));

            when OP_AND =>  -- A AND B
                res <= a and b;

            when OP_OR =>   -- A OR B
                res <= a or b;

            when OP_XOR =>  -- A XOR B
                res <= a xor b;

            when OP_NOT =>  -- NOT A
                res <= not a;

            when OP_SLL =>  -- shift A left logical by 1
                res <= std_logic_vector(shift_left(unsigned(a), 1));

            when OP_SRL =>  -- shift A right logical by 1
                res <= std_logic_vector(shift_right(unsigned(a), 1));

            when OP_SRA =>  -- shift A right arithmetic by 1
                res <= std_logic_vector(shift_right(signed(a), 1));

            when OP_ROL =>  -- rotate A left by 1
                res <= std_logic_vector(rotate_left(unsigned(a), 1));

            when OP_ROR =>  -- rotate A right by 1
                res <= std_logic_vector(rotate_right(unsigned(a), 1));

            when OP_CMP =>  -- compare A and B (A - B)
                sub_ext := ('0' & unsigned(a)) - ('0' & unsigned(b));
                res      <= std_logic_vector(sub_ext(15 downto 0));
                carry    <= sub_ext(16);
                overflow <= (a(15) and (not b(15)) and (not sub_ext(15))) or
                            ((not a(15)) and b(15) and sub_ext(15));

            when OP_INC =>  -- A + 1
                sum_ext := ('0' & unsigned(a)) + 1;
                res      <= std_logic_vector(sum_ext(15 downto 0));
                carry    <= sum_ext(16);
                overflow <= (a(15) and (not sum_ext(15)));

            when OP_DEC =>  -- A - 1
                sub_ext := ('0' & unsigned(a)) - 1;
                res      <= std_logic_vector(sub_ext(15 downto 0));
                carry    <= sub_ext(16);
                overflow <= ((not a(15)) and sub_ext(15));

            when OP_MUL =>  -- A * B (lower 16 bits)
                prod := unsigned(a) * unsigned(b);
                res  <= std_logic_vector(prod(15 downto 0));

            when OP_PASS =>  -- pass A through unchanged
                res <= a;

            when others =>  -- unknown operation, output zero
                res <= (others => '0');

        end case;
    end process;

    zero     <= '1' when res = (res'range => '0') else '0';
    negative <= res(15);

    par_proc : process(res)
        variable p : std_logic;
    begin
        p := '0';
        for i in res'range loop
            p := p xor res(i);
        end loop;
        parity <= p;
    end process;

    result <= res;

end architecture rtl;
