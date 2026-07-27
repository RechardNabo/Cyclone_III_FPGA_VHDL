-- ============================================================================
-- ISA Controller - FSM Controller
-- States: IDLE, ADDRESS_PHASE, READ_DATA, WRITE_DATA, WAIT_STATE, DONE
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity isa_controller_fsm is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    start      : in  std_logic;
    rw         : in  std_logic;  -- '1' = read, '0' = write
    load_addr  : out std_logic;  -- load address register
    load_data  : out std_logic;  -- load write data register
    read_en    : out std_logic;  -- capture read data
    done       : out std_logic
  );
end entity isa_controller_fsm;

architecture rtl of isa_controller_fsm is
  -- FSM states for the ISA bus transaction
  type state_type is (IDLE, ADDRESS_PHASE, READ_DATA, WRITE_DATA,
                      WAIT_STATE, DONE);
  signal state : state_type := IDLE;
begin

  -- Clocked process: state transitions and control signal generation
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        -- Synchronous reset: return to IDLE
        state      <= IDLE;
        load_addr  <= '0';
        load_data  <= '0';
        read_en    <= '0';
        done       <= '0';
      else
        -- Default control values to avoid latches
        load_addr <= '0';
        load_data <= '0';
        read_en   <= '0';
        done      <= '0';

        case state is

          -- IDLE: wait for start signal
          when IDLE =>
            if start = '1' then
              state <= ADDRESS_PHASE;
            end if;

          -- ADDRESS_PHASE: load address onto the bus
          when ADDRESS_PHASE =>
            load_addr <= '1';
            if rw = '1' then
              state <= READ_DATA;   -- read transaction
            else
              state <= WRITE_DATA;  -- write transaction
            end if;

          -- READ_DATA: capture data from the bus
          when READ_DATA =>
            read_en <= '1';
            state   <= WAIT_STATE;

          -- WRITE_DATA: drive write data onto the bus
          when WRITE_DATA =>
            load_data <= '1';
            state     <= WAIT_STATE;

          -- WAIT_STATE: allow bus settle time before completing
          when WAIT_STATE =>
            state <= DONE;

          -- DONE: assert done for one cycle, return to IDLE
          when DONE =>
            done  <= '1';
            state <= IDLE;

          when others =>
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
