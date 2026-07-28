--------------------------------------------------------------------------------
-- tb_canfd_controller : Testbench for CAN FD controller
-- Tests AHB-Lite register read/write for CTRL, ID, and BTR registers
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_canfd_controller is
end entity tb_canfd_controller;

architecture sim of tb_canfd_controller is
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
    signal can_tx    : std_logic;
    signal can_rx    : std_logic := '1';
    signal can_irq   : std_logic;
    signal pass : boolean := true;
begin
    HCLK    <= not HCLK after 10 ns;
    HRESETn <= '0', '1' after 100 ns;

    DUT : entity work.canfd_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            can_tx => can_tx, can_rx => can_rx, can_irq => can_irq
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
        -- Bits: enable=1, irq_en=1, loopback=1, fd_mode=1 => 0x1B
        wr(x"00000000", x"0000001B");
        rd(x"00000000", rdata);
        if rdata = x"0000001B" then
            report "CTRL PASS" severity note;
        else
            report "CTRL FAIL" severity error;
            pass <= false;
        end if;

        -- Test 2: Write and readback ID (0x08)
        wr(x"00000008", x"00000567");
        rd(x"00000008", rdata);
        if rdata = x"00000567" then
            report "ID PASS" severity note;
        else
            report "ID FAIL" severity error;
            pass <= false;
        end if;

        -- Test 3: Write and readback BTR (0x50)
        wr(x"00000050", x"00010002");
        rd(x"00000050", rdata);
        if rdata = x"00010002" then
            report "BTR PASS" severity note;
        else
            report "BTR FAIL" severity error;
            pass <= false;
        end if;

        -- Test 4: Read STAT (0x04) - should be idle after reset
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
