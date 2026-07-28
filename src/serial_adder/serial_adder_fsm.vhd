-- ============================================================================
-- Serial Adder - FSM Controller
-- States: IDLE, SHIFTING (8 cycles), DONE
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity serial_adder_fsm is
  port (
    clk      : in  std_logic;
    reset    : in  std_logic;
    start    : in  std_logic;
    load_en  : out std_logic;  -- command datapath to load operands
    shift_en : out std_logic;  -- command datapath to shift one bit
    done     : out std_logic
  );
end entity serial_adder_fsm;

architecture rtl of serial_adder_fsm is
  -- FSM states for the serial adder
  type state_type is (IDLE, SHIFTING, ST_DONE);
  signal state : state_type := IDLE;

  -- Bit counter tracks how many bits have been processed (0 to 7)
  signal bit_cnt : unsigned(3 downto 0) := (others => '0');
  constant WIDTH : integer := 8;
begin

  -- Clocked process: state transitions and control signal generation
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        -- Synchronous reset: return to IDLE
        state     <= IDLE;
        bit_cnt   <= (others => '0');
        load_en   <= '0';
        shift_en  <= '0';
        done      <= '0';
      else
        -- Default control values
        load_en  <= '0';
        shift_en <= '0';
        done     <= '0';

        case state is

          -- IDLE: wait for start signal, then load operands
          when IDLE =>
            if start = '1' then
              load_en <= '1';       -- load operands into datapath
              bit_cnt <= (others => '0');
              state   <= SHIFTING;
            end if;

          -- SHIFTING: shift one bit per cycle for 8 cycles
          when SHIFTING =>
            shift_en <= '1';
            bit_cnt  <= bit_cnt + 1;
            if bit_cnt = to_unsigned(WIDTH - 1, 4) then
              state <= ST_DONE;     -- all 8 bits processed
            end if;

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
