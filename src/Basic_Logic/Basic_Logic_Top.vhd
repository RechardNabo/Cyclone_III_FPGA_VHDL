-- Top-level module for Basic_Logic
-- Instantiates AND, OR, NOT, XOR, half_adder, full_adder, and mux_2to1
-- to demonstrate all basic logic building blocks on the FPGA board.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Basic_Logic_Top is
    port (
        -- Two general-purpose logic inputs
        A    : in  std_logic;                       -- shared input A
        B    : in  std_logic;                       -- shared input B
        -- Full adder carry-in
        CIN  : in  std_logic;
        -- 2-to-1 mux inputs (4-bit each for demonstration)
        D0   : in  std_logic_vector(3 downto 0);
        D1   : in  std_logic_vector(3 downto 0);
        SEL  : in  std_logic;
        -- Outputs from each sub-module
        Y_AND   : out std_logic;                    -- AND gate output
        Y_OR    : out std_logic;                    -- OR gate output
        Y_NOT   : out std_logic;                    -- NOT gate output (of A)
        Y_XOR   : out std_logic;                    -- XOR gate output
        HA_SUM  : out std_logic;                    -- half adder sum
        HA_CRY  : out std_logic;                    -- half adder carry
        FA_SUM  : out std_logic;                    -- full adder sum
        FA_COUT : out std_logic;                    -- full adder carry-out
        Y_MUX   : out std_logic_vector(3 downto 0)  -- mux output
    );
end entity Basic_Logic_Top;

architecture structural of Basic_Logic_Top is
begin
    -- 2-input AND gate
    u_and : entity work.AND_gate
        port map (A => A, B => B, Y => Y_AND);

    -- 2-input OR gate
    u_or : entity work.OR_Gate
        port map (A => A, B => B, Y => Y_OR);

    -- 1-input NOT gate (inverts A)
    u_not : entity work.not_gate
        port map (A => A, Y => Y_NOT);

    -- 2-input XOR gate
    u_xor : entity work.XOR_gate
        port map (A => A, B => B, Y => Y_XOR);

    -- 1-bit half adder
    u_ha : entity work.half_adder
        port map (A => A, B => B, sum => HA_SUM, carry => HA_CRY);

    -- 1-bit full adder
    u_fa : entity work.full_adder
        port map (A => A, B => B, cin => CIN, sum => FA_SUM, cout => FA_COUT);

    -- 2-to-1 multiplexer (4-bit width)
    u_mux : entity work.mux_2to1
        generic map (WIDTH => 4)
        port map (D0 => D0, D1 => D1, S => SEL, Y => Y_MUX);

end architecture structural;
