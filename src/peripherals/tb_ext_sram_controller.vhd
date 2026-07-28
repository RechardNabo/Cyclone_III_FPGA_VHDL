--------------------------------------------------------------------------------
-- tb_ext_sram_controller : Testbench for external SRAM controller
-- Tests AHB-Lite register read/write for CTRL, TIMING, ADDR_MASK, BASE_ADDR
-- Note: SRAM controller FSM interferes with register writes when enabled,
--       so writes wait for HREADYOUT and reads use HTRANS=00 to avoid FSM.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_ext_sram_controller is
end entity tb_ext_sram_controller;

architecture sim of tb_ext_sram_controller is
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
    signal sram_addr  : std_logic_vector(19 downto 0);
    signal sram_data  : std_logic_vector(31 downto 0);
    signal sram_oe_n  : std_logic;
    signal sram_we_n  : std_logic;
    signal sram_cs_n  : std_logic;
    signal sram_bls_n : std_logic_vector(3 downto 0);
    signal pass : boolean := true;
begin
    HCLK    <= not HCLK after 10 ns;
    HRESETn <= '0', '1' after 100 ns;

    DUT : entity work.ext_sram_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            sram_addr => sram_addr, sram_data => sram_data,
            sram_oe_n => sram_oe_n, sram_we_n => sram_we_n,
            sram_cs_n => sram_cs_n, sram_bls_n => sram_bls_n
        );

    stim : process
        variable rdata : std_logic_vector(31 downto 0);

        -- Write: wait for HREADYOUT, drive signals, capture at rising edge
        procedure wr(a : std_logic_vector(31 downto 0);
                     d : std_logic_vector(31 downto 0)) is
        begin
            -- Wait for bus ready
            loop
                wait until rising_edge(HCLK);
                exit when HREADYOUT = '1';
            end loop;
            -- Drive write transaction
            HSEL <= '1'; HWRITE <= '1'; HADDR <= a; HWDATA <= d;
            HTRANS <= "10"; HSIZE <= "010";
            wait until rising_edge(HCLK);
            HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
        end procedure;

        -- Read: use HTRANS=00 to avoid triggering SRAM FSM
        procedure rd(a : std_logic_vector(31 downto 0);
                     variable rv : out std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(HCLK);
            HSEL <= '1'; HWRITE <= '0'; HADDR <= a;
            HTRANS <= "00"; HSIZE <= "010";
            wait for 1 ns;
            rv := HRDATA;
            HSEL <= '0';
        end procedure;
    begin
        wait until HRESETn = '1';
        wait for 40 ns;

        -- Test 1: Write TIMING (0x04)
        -- read_wait=3, write_wait=2 => 0x0203
        wr(x"00000004", x"00000203");

        -- Test 2: Write ADDR_MASK (0x08)
        wr(x"00000008", x"000FFFFF");

        -- Test 3: Write BASE_ADDR (0x0C)
        wr(x"0000000C", x"10000000");

        -- Test 4: Read back TIMING
        rd(x"00000004", rdata);
        if rdata = x"00000203" then
            report "TIMING PASS" severity note;
        else
            report "TIMING FAIL" severity error;
            pass <= false;
        end if;

        -- Test 5: Read back ADDR_MASK
        rd(x"00000008", rdata);
        if rdata = x"000FFFFF" then
            report "ADDR_MASK PASS" severity note;
        else
            report "ADDR_MASK FAIL" severity error;
            pass <= false;
        end if;

        -- Test 6: Read back BASE_ADDR
        rd(x"0000000C", rdata);
        if rdata = x"10000000" then
            report "BASE_ADDR PASS" severity note;
        else
            report "BASE_ADDR FAIL" severity error;
            pass <= false;
        end if;

        -- Test 7: Read CTRL (0x00) - should be 0x01 after reset (enabled)
        rd(x"00000000", rdata);
        if rdata(0) = '1' then
            report "CTRL_ENABLED PASS" severity note;
        else
            report "CTRL_ENABLED FAIL" severity error;
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
