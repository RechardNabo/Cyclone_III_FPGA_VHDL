-- ================================================================================
-- tb_pwm_controller : Testbench for PWM duty cycle config
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_pwm_controller is
end entity tb_pwm_controller;

architecture sim of tb_pwm_controller is
    constant CLK_PERIOD : time := 20 ns;

    signal clk       : std_logic := '0';
    signal resetn    : std_logic := '0';
    signal hsel      : std_logic := '0';
    signal hwrite    : std_logic := '0';
    signal hready    : std_logic := '1';
    signal htrans    : std_logic_vector(1 downto 0) := "00";
    signal hsize     : std_logic_vector(2 downto 0) := "010";
    signal haddr     : std_logic_vector(31 downto 0) := (others => '0');
    signal hwdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal hrdata    : std_logic_vector(31 downto 0);
    signal hresp     : std_logic;
    signal hreadyout : std_logic;
    signal pwm_out   : std_logic_vector(31 downto 0);
    signal pwm_int   : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.pwm_controller
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HSIZE => hsize, HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            pwm_out => pwm_out, pwm_int => pwm_int
        );

    stim : process
        procedure ahb_write(addr : std_logic_vector(31 downto 0);
                            data : std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            hsel <= '1'; hwrite <= '1'; htrans <= "11";
            haddr <= addr; hwdata <= data;
            wait until rising_edge(clk);
            hsel <= '0'; hwrite <= '0'; htrans <= "00";
        end procedure;

        procedure ahb_read(addr : std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            hsel <= '1'; hwrite <= '0'; htrans <= "11";
            haddr <= addr;
            wait until rising_edge(clk);
            hsel <= '0'; htrans <= "00";
        end procedure;
    begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);

        -- Slice 0: write CSR (enable=1)
        ahb_write(x"00000000", x"00000001");

        -- Read back CSR
        ahb_read(x"00000000");
        wait for 1 ns;
        assert hrdata(0) = '1' report "FAIL: CSR readback" severity error;
        report "PASS: CSR readback" severity note;

        -- Write DIV (integer=2, frac=0)
        ahb_write(x"00000004", x"00000002");

        -- Read back DIV
        ahb_read(x"00000004");
        wait for 1 ns;
        assert hrdata(7 downto 0) = x"02"
            report "FAIL: DIV readback" severity error;
        report "PASS: DIV readback" severity note;

        -- Write CTR (top=1000)
        ahb_write(x"00000008", x"000003E8");

        -- Read back CTR
        ahb_read(x"00000008");
        wait for 1 ns;
        assert hrdata(15 downto 0) = x"03E8"
            report "FAIL: CTR readback" severity error;
        report "PASS: CTR readback" severity note;

        -- Write CC (A=250, B=500) -> 25% and 50% duty
        ahb_write(x"0000000C", x"01F400FA");

        -- Read back CC
        ahb_read(x"0000000C");
        wait for 1 ns;
        assert hrdata(15 downto 0) = x"00FA" and hrdata(31 downto 16) = x"01F4"
            report "FAIL: CC readback" severity error;
        report "PASS: CC readback (duty cycle config)" severity note;

        -- Let PWM run a few cycles
        wait for 500 ns;

        report "--- tb_pwm_controller DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;
