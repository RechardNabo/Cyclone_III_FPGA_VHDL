-- ============================================================================
-- PCI Bridge - FSM Controller
-- States: IDLE, REQ, ADDR_PHASE, DATA_PHASE, TURN_AROUND, DONE
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pci_bridge_fsm is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    start      : in  std_logic;
    rw         : in  std_logic;  -- '1' = read, '0' = write
    load_addr  : out std_logic;  -- load address register
    load_data  : out std_logic;  -- load write data buffer
    read_en    : out std_logic;  -- capture read data
    req_n      : out std_logic;  -- PCI bus request (active low)
    done       : out std_logic
  );
end entity pci_bridge_fsm;

architecture rtl of pci_bridge_fsm is
  -- FSM states for a PCI bus transaction
  type state_type is (IDLE, REQ, ADDR_PHASE, DATA_PHASE,
                      TURN_AROUND, ST_DONE);
  signal state : state_type := IDLE;
begin

  -- Clocked process: state transitions and control signal generation
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        -- Synchronous reset: return to IDLE, deassert request
        state      <= IDLE;
        load_addr  <= '0';
        load_data  <= '0';
        read_en    <= '0';
        req_n      <= '1';
        done       <= '0';
      else
        -- Default control values to avoid latches
        load_addr <= '0';
        load_data <= '0';
        read_en   <= '0';
        req_n     <= '1';
        done      <= '0';

        case state is

          -- IDLE: wait for start signal
          when IDLE =>
            if start = '1' then
              state <= REQ;
            end if;

          -- REQ: assert bus request to arbitrate for the PCI bus
          when REQ =>
            req_n <= '0';          -- request the bus (active low)
            state <= ADDR_PHASE;

          -- ADDR_PHASE: drive address onto the PCI address bus
          when ADDR_PHASE =>
            req_n     <= '0';      -- hold request during transaction
            load_addr <= '1';      -- load address register
            state     <= DATA_PHASE;

          -- DATA_PHASE: perform read or write data transfer
          when DATA_PHASE =>
            req_n <= '0';          -- still holding the bus
            if rw = '1' then
              read_en <= '1';      -- read: capture data from bus
            else
              load_data <= '1';    -- write: drive data onto bus
            end if;
            state <= TURN_AROUND;

          -- TURN_AROUND: release bus, allow targets to stop driving
          when TURN_AROUND =>
            req_n <= '1';          -- release bus request
            state <= ST_DONE;

          -- DONE: assert done for one cycle, return to IDLE
          when ST_DONE =>
            done  <= '1';
            state <= IDLE;

          when others =>
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
