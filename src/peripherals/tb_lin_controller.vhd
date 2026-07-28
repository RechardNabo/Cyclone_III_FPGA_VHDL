--------------------------------------------------------------------------------
-- tb_lin_controller : Testbench for LIN bus controller
-- Tests AHB-Lite register read/write for CTRL, ID, BAUD registers
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_lin_controller is
end entity tb_lin_controller;

architecture sim of tb_lin_controller is
    signal HCLK      : std_logic := '0';
    signal HRESETn   : std_logic := '0';
    signal HSEL      : std_logic := '0';
    signal HWRITE    : std_logic := '0';
    signal HREADY    : std_logic := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;
    signal lin_tx    : std_logic;
    signal lin_rx    : std_logic := '1';
    signal lin_irq   : std_logic;
    signal pass : boolean := true;
begin
    HCLK    <= not HCLK after 10 ns;
    HRESETn <= '0', '1' after 100 ns;

    DUT : entity work.lin_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            lin_tx => lin_tx, lin_rx => lin_rx, lin_irq => lin_irq
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);

        procedure wr(a : std_logic_vector(31 downto 0);
                     d : std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '1'; HADDR <= a; HWDATA <= d;
            HTRANS <= "10"; HSIZE <= "010";
            wait until rising_edge(HCLK);
            HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
            wait until rising_edge(HCLK);
        end procedure;

        procedure rd(a : std_logic_vector(31 downto 0);
                     variable rv : out std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '0'; HADDR <= a;
            HTRANS <= "10"; HSIZE <= "010";
            wait until rising_edge(HCLK);
            wait for 1 ns;
            rv := HRDATA;
            HSEL <= '0'; HTRANS <= "00";
            wait until rising_edge(HCLK);
        end procedure;
    begin
        wait until HRESETn = '1';
        wait for 40 ns;

        -- Test 1: Write and readback CTRL (0x00)
        -- Bits: enable=1, irq_en=1, master_mode=1 => 0x07
        wr(x"00000000", x"00000007");
        rd(x"00000000", rdata);
        if rdata = x"00000007" then
            report "CTRL PASS" severity note;
        else
            report "CTRL FAIL" severity error;
            pass <= false;
        end if;

        -- Test 2: Write and readback ID (0x08)
        -- LIN protected identifier 0x2A
        wr(x"00000008", x"0000002A");
        rd(x"00000008", rdata);
        if rdata = x"0000002A" then
            report "ID PASS" severity note;
        else
            report "ID FAIL" severity error;
            pass <= false;
        end if;

        -- Test 3: Write and readback BAUD (0x30)
        -- Baud rate divisor
        wr(x"00000030", x"00000341");
        rd(x"00000030", rdata);
        if rdata = x"00000341" then
            report "BAUD PASS" severity note;
        else
            report "BAUD FAIL" severity error;
            pass <= false;
        end if;

        -- Test 4: Read STAT (0x04) - should be idle
        rd(x"00000004", rdata);
        if rdata(0) = '1' then
            report "STAT_IDLE PASS" severity note;
        else
            report "STAT_IDLE FAIL" severity error;
            pass <= false;
        end if;

        if pass then
            report "PASS" severity note;
        else
            report "FAIL" severity error;
        end if;
        std.env.finish;
    end process;
end architecture sim;
