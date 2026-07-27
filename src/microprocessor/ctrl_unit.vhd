library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- Control Unit (FSM + decoder)
-- ============================================================================
-- The control unit wraps the combinational controller and adds a finite state
-- machine that sequences each instruction through four classic CPU stages:
--
--   FETCH      -> latch instruction from memory, increment PC
--   DECODE     -> controller decodes the instruction
--   EXECUTE    -> ALU/result settles
--   WRITEBACK  -> write result to register file / output buffer, then loop
--   HALT_STATE -> entered after a HALT instruction; asserts done forever
-- ============================================================================
entity ctrl_unit is
  port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    instruction  : in  std_logic_vector(7 downto 0);  -- from instruction register
    zero_flag    : in  std_logic;                     -- ALU zero flag (status)
    -- control signals driven to the datapath
    ir_load      : out std_logic;
    pc_load      : out std_logic;
    pc_inc       : out std_logic;
    reg_write    : out std_logic;
    alu_op       : out std_logic_vector(2 downto 0);
    mem_read     : out std_logic;
    mem_write    : out std_logic;
    out_load     : out std_logic;
    use_imm      : out std_logic;
    rd_addr      : out std_logic_vector(2 downto 0);
    rs_addr      : out std_logic_vector(2 downto 0);
    imm          : out std_logic_vector(7 downto 0);
    done         : out std_logic                      -- '1' when CPU has halted
  );
end ctrl_unit;

architecture rtl of ctrl_unit is
  type state_type is (FETCH, DECODE, EXECUTE, WRITEBACK, HALT_STATE);
  signal state : state_type := FETCH;
  -- decoded signals from the combinational controller
  signal d_reg_write, d_out_load, d_halt, d_use_imm : std_logic;
  signal d_alu_op      : std_logic_vector(2 downto 0);
  signal d_mem_read, d_mem_write, d_pc_load : std_logic;
  signal d_rd_addr, d_rs_addr : std_logic_vector(2 downto 0);
  signal d_imm         : std_logic_vector(7 downto 0);
begin
  -- Combinational instruction decoder
  u_ctrl: entity work.controller
    port map(
      instruction => instruction,
      reg_write   => d_reg_write,
      alu_op      => d_alu_op,
      mem_read    => d_mem_read,
      mem_write   => d_mem_write,
      pc_load     => d_pc_load,
      out_load    => d_out_load,
      halt        => d_halt,
      use_imm     => d_use_imm,
      rd_addr     => d_rd_addr,
      rs_addr     => d_rs_addr,
      imm         => d_imm
    );

  -- State register: advance one stage per clock, loop after WRITEBACK
  process(clk, rst)
  begin
    if rst = '1' then
      state <= FETCH;
    elsif rising_edge(clk) then
      case state is
        when FETCH      => state <= DECODE;
        when DECODE     => state <= EXECUTE;
        when EXECUTE    => state <= WRITEBACK;
        when WRITEBACK  =>
          if d_halt = '1' then state <= HALT_STATE;
          else state <= FETCH; end if;
        when HALT_STATE => state <= HALT_STATE;
      end case;
    end if;
  end process;

  -- Gated control outputs (only active in the right state)
  ir_load   <= '1' when state = FETCH else '0';
  pc_inc    <= '1' when state = FETCH else '0';
  reg_write <= d_reg_write when state = WRITEBACK else '0';
  out_load  <= d_out_load  when state = WRITEBACK else '0';
  pc_load   <= d_pc_load   when state = WRITEBACK else '0';
  -- these are passed through continuously (used during EXECUTE)
  alu_op    <= d_alu_op;
  mem_read  <= d_mem_read;
  mem_write <= d_mem_write;
  use_imm   <= d_use_imm;
  rd_addr   <= d_rd_addr;
  rs_addr   <= d_rs_addr;
  imm       <= d_imm;
  done      <= '1' when state = HALT_STATE else '0';
end rtl;
