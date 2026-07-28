-- ================================================================================
-- tb_dsp_extensions : Testbench for DSP SIMD operation
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_dsp_extensions is
end entity tb_dsp_extensions;

architecture sim of tb_dsp_extensions is
    constant CLK_PERIOD : time := 20 ns;

    signal clk       : std_logic := '0';
    signal resetn    : std_logic := '0';
    signal hsel      : std_logic := '0';
    signal hwrite    : std_logic := '0';
    signal hready    : std_logic := '1';
    signal htrans    : std_logic_vector(1 downto 0) := "00";
    signal haddr     : std_logic_vector(31 downto 0) := (others => '0');
    signal hwdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal hrdata    : std_logic_vector(31 downto 0);
    signal hresp     : std_logic;
    signal hreadyout : std_logic;
    signal dsp_irq   : std_logic;

begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.dsp_extensions
        port map (
            HCLK => clk, HRESETn => resetn, HSEL => hsel,
            HWRITE => hwrite, HREADY => hready, HTRANS => htrans,
            HADDR => haddr, HWDATA => hwdata,
            HRDATA => hrdata, HRESP => hresp, HREADYOUT => hreadyout,
            dsp_irq => dsp_irq
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

        -- Test __SADD (op=0): OP_A=100, OP_B=200, expect result=300
        ahb_write(x"00000008", x"00000064");  -- OP_A=100
        ahb_write(x"0000000C", x"000000C8");  -- OP_B=200

        -- Read back OP_A
        ahb_read(x"00000008");
        wait for 1 ns;
        assert hrdata = x"00000064" report "FAIL: OP_A readback" severity error;
        report "PASS: OP_A readback" severity note;

        -- Start operation: op=0 (SADD), start=1
        ahb_write(x"00000000", x"00000010");

        -- Wait for result
        wait until rising_edge(clk);
        wait for 1 ns;

        -- Read result_lo
        ahb_read(x"00000014");
        wait for 1 ns;
        assert hrdata = x"0000012C"  -- 300
            report "FAIL: SADD result mismatch" severity error;
        report "PASS: SADD result = 300" severity note;

        -- Test __SMUL (op=2): OP_A=10, OP_B=20, expect result=200
        ahb_write(x"00000008", x"0000000A");  -- OP_A=10
        ahb_write(x"0000000C", x"00000014");  -- OP_B=20
        ahb_write(x"00000000", x"00000012");  -- op=2, start=1

        wait until rising_edge(clk);
        wait for 1 ns;

        ahb_read(x"00000014");
        wait for 1 ns;
        assert hrdata = x"000000C8"  -- 200
            report "FAIL: SMUL result mismatch" severity error;
        report "PASS: SMUL result = 200" severity note;

        -- Test __SMUAD (op=0xA): dual 16-bit SIMD
        -- OP_A = [0x0002 : 0x0003] = [2 : 3]
        -- OP_B = [0x0004 : 0x0005] = [4 : 5]
        -- result = 2*4 + 3*5 = 8 + 15 = 23
        ahb_write(x"00000008", x"00020003");  -- OP_A
        ahb_write(x"0000000C", x"00040005");  -- OP_B
        ahb_write(x"00000000", x"0000001A");  -- op=0xA, start=1

        wait until rising_edge(clk);
        wait for 1 ns;

        ahb_read(x"00000014");
        wait for 1 ns;
        assert hrdata = x"00000017"  -- 23
            report "FAIL: SMUAD result mismatch" severity error;
        report "PASS: SMUAD result = 23" severity note;

        -- Read STAT (done should be set)
        ahb_read(x"00000004");
        wait for 1 ns;
        assert hrdata(0) = '1' report "FAIL: STAT done not set" severity error;
        report "PASS: STAT done set" severity note;

        report "--- tb_dsp_extensions DONE ---" severity note;
        std.env.finish;
    end process stim;

end architecture sim;
