library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Controller (instruction decoder)
-- ============================================================================
-- The controller examines the current instruction and produces the control
-- signals that tell the datapath what to do. It is pure combinational logic.
--
-- Instruction format (8 bits):
--   [opcode(7:5)] [rd(4:3)] [rs(2:1)] [0]
--   For LOAD, the lower 3 bits (2:0) are a 3-bit immediate.
--
-- Opcodes:
--   000 NOP   001 LOAD rd,imm   010 ADD rd,rs   011 SUB rd,rs
--   100 AND rd,rs   101 OR rd,rs   110 OUT rd   111 HALT
-- ============================================================================
entity controller is
  port(
    instruction : in  std_logic_vector(7 downto 0);  -- current instruction
    reg_write   : out std_logic;                     -- write enable for reg file
    alu_op      : out std_logic_vector(2 downto 0);  -- ALU operation
    mem_read    : out std_logic;                     -- memory read strobe
    mem_write   : out std_logic;                     -- memory write strobe
    pc_load     : out std_logic;                     -- load PC (jump)
    out_load    : out std_logic;                     -- load output buffer
    halt        : out std_logic;                     -- halt the CPU
    use_imm     : out std_logic;                     -- select immediate for writeback
    rd_addr     : out std_logic_vector(2 downto 0);  -- destination register
    rs_addr     : out std_logic_vector(2 downto 0);  -- source register
    imm         : out std_logic_vector(7 downto 0)   -- zero-extended immediate
  );
end controller;

architecture rtl of controller is
  constant OP_NOP  : std_logic_vector(2 downto 0) := "000";
  constant OP_LOAD : std_logic_vector(2 downto 0) := "001";
  constant OP_ADD  : std_logic_vector(2 downto 0) := "010";
  constant OP_SUB  : std_logic_vector(2 downto 0) := "011";
  constant OP_AND  : std_logic_vector(2 downto 0) := "100";
  constant OP_OR   : std_logic_vector(2 downto 0) := "101";
  constant OP_OUT  : std_logic_vector(2 downto 0) := "110";
  constant OP_HALT : std_logic_vector(2 downto 0) := "111";
  signal opcode : std_logic_vector(2 downto 0);
begin
  opcode  <= instruction(7 downto 5);
  -- 2-bit register fields zero-extended to the 3-bit reg-file address width
  rd_addr <= '0' & instruction(4 downto 3);
  rs_addr <= '0' & instruction(2 downto 1);
  -- 3-bit immediate (bits 2:0) zero-extended to 8 bits
  imm     <= "00000" & instruction(2 downto 0);

  process(opcode)
  begin
    -- safe defaults for every signal
    reg_write <= '0'; alu_op <= "000"; mem_read <= '0';
    mem_write <= '0'; pc_load <= '0'; out_load <= '0';
    halt <= '0'; use_imm <= '0';
    case opcode is
      when OP_NOP  => null;                       -- do nothing
      when OP_LOAD =>
        reg_write <= '1'; use_imm <= '1'; alu_op <= "000";
      when OP_ADD  =>
        reg_write <= '1'; alu_op <= "000";        -- ALU ADD
      when OP_SUB  =>
        reg_write <= '1'; alu_op <= "001";        -- ALU SUB
      when OP_AND  =>
        reg_write <= '1'; alu_op <= "010";        -- ALU AND
      when OP_OR   =>
        reg_write <= '1'; alu_op <= "011";        -- ALU OR
      when OP_OUT  =>
        out_load <= '1';                          -- send register to output
      when OP_HALT =>
        halt <= '1';                              -- stop the processor
      when others => null;
    end case;
  end process;
end rtl;
