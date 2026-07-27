library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Microprocessor (top-level)
-- ============================================================================
-- This is the top-level entity that wires together the three major blocks:
--   * memory     -- holds the program and data
--   * datapath   -- PC, IR, register file, ALU, muxes, output buffer
--   * ctrl_unit  -- FSM + decoder that drives the datapath
--
-- External interface:
--   clk         -- system clock
--   reset       -- asynchronous reset (active high)
--   output_port -- 8-bit result from the last OUT instruction
--   done        -- '1' once a HALT instruction has completed
-- ============================================================================
entity microprocessor is
  port(
    clk         : in  std_logic;
    reset       : in  std_logic;
    output_port : out std_logic_vector(7 downto 0);
    done        : out std_logic
  );
end microprocessor;

architecture rtl of microprocessor is
  -- memory <-> datapath
  signal mem_addr    : std_logic_vector(7 downto 0);
  signal mem_rd_data : std_logic_vector(7 downto 0);
  -- datapath <-> control unit
  signal instruction : std_logic_vector(7 downto 0);
  signal zero_flag   : std_logic;
  signal ir_load     : std_logic;
  signal pc_load     : std_logic;
  signal pc_inc      : std_logic;
  signal reg_write   : std_logic;
  signal alu_op      : std_logic_vector(2 downto 0);
  signal mem_read    : std_logic;
  signal mem_write   : std_logic;
  signal out_load    : std_logic;
  signal use_imm     : std_logic;
  signal rd_addr     : std_logic_vector(2 downto 0);
  signal rs_addr     : std_logic_vector(2 downto 0);
  signal imm         : std_logic_vector(7 downto 0);
begin
  -- Instruction/data memory (write port unused for this ISA)
  u_mem: entity work.memory
    port map(clk => clk, addr => mem_addr, wr_en => mem_write,
             wr_data => (others => '0'), rd_data => mem_rd_data);

  -- Datapath: all data registers and the ALU
  u_dp: entity work.datapath
    port map(clk => clk, rst => reset, ir_load => ir_load, pc_load => pc_load,
             pc_inc => pc_inc, reg_write => reg_write, alu_op => alu_op,
             out_load => out_load, use_imm => use_imm,
             rd_addr => rd_addr, rs_addr => rs_addr, imm => imm,
             mem_addr => mem_addr, mem_rd_data => mem_rd_data,
             instruction => instruction, zero_flag => zero_flag,
             output_port => output_port);

  -- Control unit: FSM + decoder
  u_ctrl: entity work.ctrl_unit
    port map(clk => clk, rst => reset, instruction => instruction,
             zero_flag => zero_flag,
             ir_load => ir_load, pc_load => pc_load, pc_inc => pc_inc,
             reg_write => reg_write, alu_op => alu_op,
             mem_read => mem_read, mem_write => mem_write,
             out_load => out_load, use_imm => use_imm,
             rd_addr => rd_addr, rs_addr => rs_addr, imm => imm,
             done => done);
end rtl;
