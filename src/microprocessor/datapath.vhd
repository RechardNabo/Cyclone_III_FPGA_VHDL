library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Datapath
-- ============================================================================
-- The datapath contains all the data-handling hardware: program counter,
-- instruction register, register file, ALU, a writeback mux, and the output
-- buffer. The control unit drives the control-signal inputs; the datapath
-- produces status (zero flag) and the external output_port.
--
-- Data flow for a typical ALU instruction (e.g. ADD R0,R1):
--   PC -> memory address -> IR (fetch)
--   reg_file reads R[rd] and R[rs] -> ALU computes -> mux -> reg_file write
-- For LOAD: the immediate bypasses the ALU via the mux (use_imm = '1').
-- For OUT:  R[rd] is routed directly into the output buffer.
-- ============================================================================
entity datapath is
  port(
    clk         : in  std_logic;
    rst         : in  std_logic;
    -- control signals from the control unit
    ir_load     : in  std_logic;
    pc_load     : in  std_logic;
    pc_inc      : in  std_logic;
    reg_write   : in  std_logic;
    alu_op      : in  std_logic_vector(2 downto 0);
    out_load    : in  std_logic;
    use_imm     : in  std_logic;
    rd_addr     : in  std_logic_vector(2 downto 0);
    rs_addr     : in  std_logic_vector(2 downto 0);
    imm         : in  std_logic_vector(7 downto 0);
    -- memory interface (instruction fetch)
    mem_addr    : out std_logic_vector(7 downto 0);
    mem_rd_data : in  std_logic_vector(7 downto 0);
    -- status and external outputs
    instruction : out std_logic_vector(7 downto 0);
    zero_flag   : out std_logic;
    output_port : out std_logic_vector(7 downto 0)
  );
end datapath;

architecture rtl of datapath is
  signal pc_q, ir_q          : std_logic_vector(7 downto 0);
  signal rd_data1, rd_data2  : std_logic_vector(7 downto 0);
  signal alu_result          : std_logic_vector(7 downto 0);
  signal alu_zero, alu_carry : std_logic;
  signal wb_data             : std_logic_vector(7 downto 0);
  signal obuf_q              : std_logic_vector(7 downto 0);
begin
  -- Program counter drives the memory address bus for instruction fetch
  u_pc: entity work.pc
    port map(clk => clk, rst => rst, en => pc_inc, load => pc_load,
             d => ir_q, q => pc_q);
  mem_addr <= pc_q;

  -- Instruction register latches the word read from memory
  u_ir: entity work.ir
    port map(clk => clk, rst => rst, load => ir_load,
             d => mem_rd_data, q => ir_q);
  instruction <= ir_q;

  -- Register file: read two registers, write back one
  u_rf: entity work.reg_file
    port map(clk => clk, rst => rst, wr_en => reg_write,
             rd_addr1 => rd_addr, rd_addr2 => rs_addr,
             wr_addr  => rd_addr, wr_data  => wb_data,
             rd_data1 => rd_data1, rd_data2 => rd_data2);

  -- ALU operates on the two registers just read
  u_alu: entity work.alu
    port map(a => rd_data1, b => rd_data2, op => alu_op,
             result => alu_result, zero => alu_zero, carry => alu_carry);
  zero_flag <= alu_zero;

  -- Writeback mux: choose ALU result (normal) or immediate (LOAD)
  u_mux: entity work.smallmux
    port map(d0 => alu_result, d1 => imm, sel => use_imm, y => wb_data);

  -- Output buffer captures R[rd] on an OUT instruction
  u_obuf: entity work.obuf
    port map(clk => clk, rst => rst, load => out_load,
             d => rd_data1, q => obuf_q);
  output_port <= obuf_q;
end rtl;
