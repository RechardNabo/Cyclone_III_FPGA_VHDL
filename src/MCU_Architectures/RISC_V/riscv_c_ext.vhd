library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- RISC-V RV32C (Compressed instructions) decoder
-- Decodes 16-bit compressed instructions into 32-bit equivalents
-- AHB-Lite slave for configuration (enable/disable compressed mode)
-- Combinational decode of instr_16 to instr_32

entity riscv_c_ext is
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
        instr_16    : in  std_logic_vector(15 downto 0);
        instr_32    : out std_logic_vector(31 downto 0);
        is_compressed : out std_logic
    );
end entity riscv_c_ext;

architecture rtl of riscv_c_ext is

    constant ADDR_ENABLE : std_logic_vector(2 downto 0) := "000";

    signal enable     : std_logic;
    signal write_en   : std_logic;
    signal addr_idx   : std_logic_vector(2 downto 0);
    signal rdata_int  : std_logic_vector(31 downto 0);

    -- Compressed opcode fields
    alias c_opcode    : std_logic_vector(1 downto 0) is instr_16(1 downto 0);
    alias c_funct3    : std_logic_vector(2 downto 0) is instr_16(15 downto 13);
    alias c_rd_rs1    : std_logic_vector(2 downto 0) is instr_16(9 downto 7);   -- 3-bit reg
    alias c_rs2       : std_logic_vector(2 downto 0) is instr_16(4 downto 2);
    alias c_imm_12    : std_logic is instr_16(12);
    alias c_imm_11    : std_logic is instr_16(11);
    alias c_imm_10    : std_logic is instr_16(10);
    alias c_imm_6     : std_logic is instr_16(6);
    alias c_imm_5     : std_logic is instr_16(5);

    -- Expand 3-bit register to 5-bit (x8..x15)
    function expand_reg(r3 : std_logic_vector(2 downto 0)) return std_logic_vector is
    begin
        return "01" & r3;
    end function;

    signal decoded32 : std_logic_vector(31 downto 0);

begin

    addr_idx  <= HADDR(4 downto 2);
    write_en  <= HSEL and HWRITE and HREADY when HTRANS = "10" else '0';

    -- Configuration register
    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            enable     <= '1';
            rdata_int  <= (others => '0');
        elsif rising_edge(HCLK) then
            if write_en = '1' and addr_idx = ADDR_ENABLE then
                enable <= HWDATA(0);
            end if;
            if HSEL = '1' and HWRITE = '0' and HREADY = '1' and HTRANS = "10" then
                if addr_idx = ADDR_ENABLE then
                    rdata_int <= x"0000000" & "000" & enable;
                else
                    rdata_int <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    -- Combinational decode
    process(instr_16, enable, c_opcode, c_funct3, c_rd_rs1, c_rs2)
        variable rd5  : std_logic_vector(4 downto 0);
        variable rs1_5: std_logic_vector(4 downto 0);
        variable rs2_5: std_logic_vector(4 downto 0);
        variable imm  : std_logic_vector(31 downto 0);
    begin
        decoded32 <= (others => '0');
        is_compressed <= '0';

        if enable = '1' and instr_16(1 downto 0) /= "11" then
            is_compressed <= '1';
            rd5  := expand_reg(c_rd_rs1);
            rs1_5:= expand_reg(c_rd_rs1);
            rs2_5:= expand_reg(c_rs2);

            case c_opcode is
                when "00" => -- Quadrant 0: C.ADDI4SPN, C.LW, C.SW, C.FLD, C.FSD
                    case c_funct3 is
                        when "000" => -- C.ADDI4SPN -> ADDI rd', x2, nzuimm
                            decoded32 <= "0000000000" & instr_16(10 downto 7) & instr_16(12 downto 11) &
                                         instr_16(5) & instr_16(6) & "00" & "00010" & "000" & rd5 & "0010011";
                        when "010" => -- C.LW -> LW rd', offset(rs1')
                            decoded32 <= "0000000" & instr_16(5) & instr_16(12 downto 10) &
                                         instr_16(6) & "00" & rs1_5 & "010" & rd5 & "0000011";
                        when "110" => -- C.SW -> SW rs2', offset(rs1')
                            decoded32 <= "0000000" & instr_16(5) & instr_16(12 downto 10) &
                                         instr_16(6) & "00" & rs1_5 & "010" & rs2_5 & "0100011";
                        when others =>
                            decoded32 <= x"00000013"; -- NOP
                    end case;

                when "01" => -- Quadrant 1: C.ADDI, C.JAL, C.LI, C.ADD, C.J, C.BEQZ, C.BNEZ
                    case c_funct3 is
                        when "000" => -- C.ADDI / C.NOP
                            decoded32 <= "0000000" & instr_16(12) & instr_16(6 downto 2) &
                                         "00000" & rd5 & "000" & rd5 & "0010011";
                        when "001" => -- C.JAL -> JAL x1, offset
                            decoded32 <= instr_16(12) & instr_16(8) & instr_16(10 downto 9) &
                                         instr_16(6) & instr_16(7) & instr_16(2) & instr_16(11) &
                                         instr_16(5 downto 3) & "0" & instr_16(12) & "00001" & "1101111";
                        when "010" => -- C.LI -> ADDI rd, x0, imm
                            decoded32 <= "0000000" & instr_16(12) & instr_16(6 downto 2) &
                                         "00000" & rd5 & "000" & rd5 & "0010011";
                        when "101" => -- C.J -> JAL x0, offset
                            decoded32 <= instr_16(12) & instr_16(8) & instr_16(10 downto 9) &
                                         instr_16(6) & instr_16(7) & instr_16(2) & instr_16(11) &
                                         instr_16(5 downto 3) & "0" & instr_16(12) & "00000" & "1101111";
                        when "110" | "111" => -- C.BEQZ / C.BNEZ
                            decoded32 <= "0000000" & instr_16(12) & instr_16(6 downto 5) &
                                         instr_16(2) & "0" & instr_16(13) & instr_16(11 downto 10) &
                                         "00000" & rs1_5 & "000" & rd5 & "1100011";
                        when others =>
                            decoded32 <= x"00000013"; -- NOP
                    end case;

                when "10" => -- Quadrant 2: C.SLLI, C.LWSP, C.JR, C.MV, C.JALR, C.ADD, C.SWSP
                    case c_funct3 is
                        when "000" => -- C.SLLI
                            decoded32 <= "0000000" & instr_16(12) & instr_16(6 downto 2) &
                                         "00000" & rd5 & "001" & rd5 & "0010011";
                        when "010" => -- C.LWSP -> LW rd, offset(x2)
                            decoded32 <= "0000000" & instr_16(3 downto 2) & instr_16(12) &
                                         instr_16(6 downto 4) & "00" & "00010" & "010" & rd5 & "0000011";
                        when "110" => -- C.SWSP -> SW rs2, offset(x2)
                            decoded32 <= "0000000" & instr_16(8 downto 7) & instr_16(12 downto 9) &
                                         "00" & "00010" & "010" & rs2_5 & "0100011";
                        when others =>
                            decoded32 <= x"00000013"; -- NOP
                    end case;

                when others =>
                    decoded32 <= x"00000013";
            end case;
        else
            decoded32 <= (others => '0');
        end if;
    end process;

    instr_32  <= decoded32;
    HRDATA    <= rdata_int;
    HRESP     <= '0';
    HREADYOUT <= '1';

end architecture rtl;
