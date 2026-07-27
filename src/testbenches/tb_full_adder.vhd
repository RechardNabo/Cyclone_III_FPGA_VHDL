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
    begin
        -- Test all 8 input combinations
        for i in 0 to 7 loop
            A   <= std_logic'(((i / 4) mod 2));
            B   <= std_logic'(((i / 2) mod 2));
            cin <= std_logic'((i mod 2));
            wait for 20 ns;
            exp_sum  := (std_logic'(((i / 4) mod 2))) xor (std_logic'(((i / 2) mod 2))) xor (std_logic'((i mod 2)));
            exp_cout := ((std_logic'(((i / 4) mod 2))) and (std_logic'(((i / 2) mod 2)))) or
                        ((std_logic'((i mod 2))) and ((std_logic'(((i / 4) mod 2))) xor (std_logic'(((i / 2) mod 2)))));
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
