--------------------------------------------------------------------------------
-- tb_onewire_controller : Testbench for 1-Wire bus controller
-- Tests AHB-Lite register write for CTRL and readback of STAT (reset pulse)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_onewire_controller is
end entity tb_onewire_controller;

architecture sim of tb_onewire_controller is
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
    signal ow_dq     : std_logic;
    signal ow_irq    : std_logic;
    signal pass : boolean := true;
begin
    HCLK    <= not HCLK after 10 ns;
    HRESETn <= '0', '1' after 100 ns;

    -- Pull-up on 1-Wire bus
    ow_dq <= 'H';

    DUT : entity work.onewire_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            ow_dq => ow_dq, ow_irq => ow_irq
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

        -- Test 1: Read STAT (0x04) - should be not busy after reset
        rd(x"00000004", rdata);
        if rdata(0) = '0' then
            report "STAT_NOT_BUSY PASS" severity note;
        else
            report "STAT_NOT_BUSY FAIL" severity error;
            pass <= false;
        end if;

        -- Test 2: Write CTRL (0x00) with enable=1
        wr(x"00000000", x"00000001");

        -- Test 3: Write CTRL (0x00) with enable=1, reset_pulse=1
        -- This triggers the 1-Wire reset pulse FSM
        wr(x"00000000", x"00000003");

        -- Test 4: Read STAT (0x04) - should show busy=1
        rd(x"00000004", rdata);
        if rdata(0) = '1' then
            report "STAT_BUSY PASS" severity note;
        else
            report "STAT_BUSY FAIL" severity error;
            pass <= false;
        end if;

        -- Test 5: Write TXDATA (0x08) - byte to transmit
        wr(x"00000008", x"000000A5");

        -- Test 6: Read RXDATA (0x0C) - should be 0 after reset
        rd(x"0000000C", rdata);
        if rdata = x"00000000" then
            report "RXDATA_PASS PASS" severity note;
        else
            report "RXDATA_PASS FAIL" severity error;
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
