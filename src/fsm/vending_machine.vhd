-- ============================================================================
-- Vending Machine FSM
-- ============================================================================
-- Accepts nickel (5c), dime (10c) and quarter (25c) coins.
-- Product costs 25 cents. When the accumulated amount >= 25, the product
-- is dispensed and any change above 25 is returned.
-- Coin inputs are one-cycle pulses (assert for one clock, then deassert).
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity vending_machine is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;        -- active-high synchronous reset
        coin_5        : in  std_logic;        -- insert nickel  (5c pulse)
        coin_10       : in  std_logic;        -- insert dime   (10c pulse)
        coin_25       : in  std_logic;        -- insert quarter(25c pulse)
        dispense      : out std_logic;        -- '1' for one cycle when product ready
        change_out    : out std_logic_vector(6 downto 0)  -- change in cents (0..99)
    );
end entity vending_machine;

architecture rtl of vending_machine is

    constant PRODUCT_PRICE : integer := 25;  -- cents

    -- FSM states
    type state_type is (S_IDLE, S_DISPENSE, S_CHANGE);
    signal current_state : state_type;
    signal next_state    : state_type;

    -- Accumulated amount in cents (0..99 is enough for a few coins)
    signal amount      : integer range 0 to 127;
    signal next_amount : integer range 0 to 127;

begin

    -- -----------------------------------------------------------------------
    -- State register and amount register (clocked)
    -- -----------------------------------------------------------------------
    state_reg : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= S_IDLE;
                amount        <= 0;
            else
                current_state <= next_state;
                amount        <= next_amount;
            end if;
        end if;
    end process state_reg;

    -- -----------------------------------------------------------------------
    -- Next-state and next-amount logic (combinational)
    -- -----------------------------------------------------------------------
    next_state_logic : process(current_state, amount, coin_5, coin_10, coin_25)
        variable new_amount : integer range 0 to 127;
    begin
        -- default: hold state and amount
        next_state   <= current_state;
        next_amount  <= amount;
        dispense     <= '0';
        change_out   <= (others => '0');

        case current_state is

            when S_IDLE =>
                -- add inserted coin to the accumulated amount
                new_amount := amount;
                if coin_5  = '1' then new_amount := new_amount + 5;  end if;
                if coin_10 = '1' then new_amount := new_amount + 10; end if;
                if coin_25 = '1' then new_amount := new_amount + 25; end if;

                next_amount <= new_amount;

                if new_amount >= PRODUCT_PRICE then
                    next_state <= S_DISPENSE;
                else
                    next_state <= S_IDLE;
                end if;

            when S_DISPENSE =>
                -- assert dispense for one cycle, then go to change return
                dispense    <= '1';
                next_amount <= amount - PRODUCT_PRICE;  -- remaining = change
                next_state  <= S_CHANGE;

            when S_CHANGE =>
                -- output the change value and return to idle
                change_out  <= std_logic_vector(to_unsigned(amount, 7));
                next_amount <= 0;
                next_state  <= S_IDLE;

            when others =>
                next_state  <= S_IDLE;
                next_amount <= 0;

        end case;
    end process next_state_logic;

end architecture rtl;
