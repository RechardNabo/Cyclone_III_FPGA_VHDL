-- ============================================================================
-- GCD Calculator - Behavioral Model (Euclidean Algorithm)
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity gcd_behavior is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    start      : in  std_logic;
    a_in       : in  std_logic_vector(7 downto 0);
    b_in       : in  std_logic_vector(7 downto 0);
    gcd_result : out std_logic_vector(7 downto 0);
    done       : out std_logic
  );
end entity gcd_behavior;

architecture behavioral of gcd_behavior is
  -- FSM states for the behavioral GCD computation
  type state_type is (IDLE, CALC, DONE_ST);
  signal state : state_type := IDLE;

  -- Working registers hold the two operands during computation
  signal a_reg : unsigned(7 downto 0) := (others => '0');
  signal b_reg : unsigned(7 downto 0) := (others => '0');
begin

  -- Clocked process: state transitions and datapath updates
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        -- Synchronous reset returns the module to IDLE
        state      <= IDLE;
        a_reg      <= (others => '0');
        b_reg      <= (others => '0');
        gcd_result <= (others => '0');
        done       <= '0';
      else
        case state is

          -- IDLE: wait for start signal, then load operands
          when IDLE =>
            done <= '0';
            if start = '1' then
              a_reg <= unsigned(a_in);
              b_reg <= unsigned(b_in);
              state <= CALC;
            end if;

          -- CALC: perform Euclidean algorithm iteratively
          --   if b = 0 then result = a, go to DONE
          --   else replace (a, b) with (b, a mod b)
          when CALC =>
            if b_reg = to_unsigned(0, 8) then
              gcd_result <= std_logic_vector(a_reg);
              state      <= DONE_ST;
            else
              a_reg <= b_reg;
              b_reg <= a_reg rem b_reg;  -- remainder = modulo for unsigned
            end if;

          -- DONE_ST: assert done for one cycle, then return to IDLE
          when DONE_ST =>
            done  <= '1';
            state <= IDLE;

          when others =>
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;

end architecture behavioral;
