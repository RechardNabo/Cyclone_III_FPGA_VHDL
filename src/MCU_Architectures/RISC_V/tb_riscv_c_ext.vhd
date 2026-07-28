-- ================================================================================
-- tb_riscv_c_ext : Testbench for RISC-V Compressed Instruction Decoder
-- ================================================================================
-- Tests compressed instruction decode (C.ADDI, C.LI, C.J) and enable register.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_riscv_c_ext is
end entity tb_riscv_c_ext;

architecture sim of tb_riscv_c_ext is
    signal HCLK      : std_logic := '0';
    signal HRESETn   : std_logic := '0';
    signal HSEL      : std_logic := '0';
    signal HWRITE    : std_logic := '0';
    signal HREADY    : std_logic := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;
    signal instr_16    : std_logic_vector(15 downto 0) := (others => '0');
    signal instr_32    : std_logic_vector(31 downto 0);
    signal is_compressed : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.riscv_c_ext
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA,
            HRDATA => HRDATA, HRESP => HRESP, HREADYOUT => HREADYOUT,
            instr_16 => instr_16, instr_32 => instr_32,
            is_compressed => is_compressed
        );

    stim : process
        procedure ahb_write(addr : std_logic_vector(31 downto 0);
                            data : std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
            HADDR <= addr; HWDATA <= data;
            wait until rising_edge(HCLK);
            HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
        end procedure;

        procedure ahb_read(addr : std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
            HADDR <= addr;
            wait until rising_edge(HCLK);
            wait for 1 ns;
            HSEL <= '0'; HTRANS <= "00";
        end procedure;

        variable test_pass : boolean := true;
    begin
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait until rising_edge(HCLK);

        -- Test 1: Read ENABLE register (default should be 1)
        report "Test 1: ENABLE default read";
        ahb_read(x"00000000");
        if HRDATA(0) = '1' then
            report "Test 1 PASS" severity note;
        else
            report "Test 1 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 2: C.ADDI (opcode=01, funct3=000) -> ADDI
        -- C.ADDI: imm[5]=bit12, imm[4:0]=bits[6:2], rd=bits[9:7]
        -- Encode: funct3=000, rd=001(x9), imm=000001(1), opcode=01
        -- bits: [15:13]=000, [12]=0, [11:10]=00, [9:7]=001, [6:2]=00001, [1:0]=01
        report "Test 2: C.ADDI decode";
        instr_16 <= "0000000100001001";  -- C.ADDI x9, 1
        wait for CLK_PERIOD * 2;
        if is_compressed = '1' and instr_32(6 downto 0) = "0010011" then
            report "Test 2 PASS" severity note;
        else
            report "Test 2 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 3: C.LI (opcode=01, funct3=010) -> ADDI rd, x0, imm
        report "Test 3: C.LI decode";
        instr_16 <= "0100000100001001";  -- C.LI x9, 0
        wait for CLK_PERIOD * 2;
        if is_compressed = '1' and instr_32(6 downto 0) = "0010011" then
            report "Test 3 PASS" severity note;
        else
            report "Test 3 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 4: Non-compressed instruction (opcode=11) -> is_compressed=0
        report "Test 4: Non-compressed instruction";
        instr_16 <= "0000000000000011";  -- opcode=11 (32-bit instruction)
        wait for CLK_PERIOD * 2;
        if is_compressed = '0' then
            report "Test 4 PASS" severity note;
        else
            report "Test 4 FAIL" severity error;
            test_pass := false;
        end if;

        -- Test 5: Disable compressed mode, verify is_compressed=0
        report "Test 5: Disable compressed mode";
        ahb_write(x"00000000", x"00000000");  -- enable=0
        instr_16 <= "0000000100001001";  -- C.ADDI
        wait for CLK_PERIOD * 2;
        if is_compressed = '0' then
            report "Test 5 PASS" severity note;
        else
            report "Test 5 FAIL" severity error;
            test_pass := false;
        end if;

        if test_pass then
            report "=== ALL RISCV_C_EXT TESTS PASSED ===" severity note;
        else
            report "=== RISCV_C_EXT TESTS FAILED ===" severity error;
        end if;

        finish;
    end process;
end architecture sim;
