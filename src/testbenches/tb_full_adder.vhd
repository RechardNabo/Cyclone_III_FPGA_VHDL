library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_full_adder is
end entity tb_full_adder;

architecture sim of tb_full_adder is
    signal A, B, cin : std_logic := '0';
    signal sum, cout : std_logic;
begin
    dut : entity work.full_adder
        port map (A => A, B => B, cin => cin, sum => sum, cout => cout);

    stim : process
        variable exp_sum, exp_cout : std_logic;
        variable i_a, i_b, i_cin : integer;
    begin
        -- Test all 8 input combinations
        for i in 0 to 7 loop
            i_a   := (i / 4) rem 2;
            i_b   := (i / 2) rem 2;
            i_cin := i rem 2;
            if i_a = 1 then A <= '1'; else A <= '0'; end if;
            if i_b = 1 then B <= '1'; else B <= '0'; end if;
            if i_cin = 1 then cin <= '1'; else cin <= '0'; end if;
            wait for 20 ns;
            if ((i_a /= i_b) /= (i_cin = 1)) then exp_sum := '1'; else exp_sum := '0'; end if;
            if ((i_a = 1 and i_b = 1) or (i_cin = 1 and (i_a /= i_b))) then exp_cout := '1'; else exp_cout := '0'; end if;
            assert sum = exp_sum
                report "FAIL: sum mismatch for A=" & std_logic'image(A) & " B=" & std_logic'image(B) & " cin=" & std_logic'image(cin)
                severity error;
            assert cout = exp_cout
                report "FAIL: cout mismatch for A=" & std_logic'image(A) & " B=" & std_logic'image(B) & " cin=" & std_logic'image(cin)
                severity error;
        end loop;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
