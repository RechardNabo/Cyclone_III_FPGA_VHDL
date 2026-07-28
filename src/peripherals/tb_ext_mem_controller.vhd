--------------------------------------------------------------------------------
-- tb_ext_mem_controller : Testbench for external parallel memory controller
-- Tests AHB-Lite register read/write for CTRL, ADDR, TIMING, CS_CFG registers
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_ext_mem_controller is
end entity tb_ext_mem_controller;

architecture sim of tb_ext_mem_controller is
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
    signal mem_addr   : std_logic_vector(25 downto 0);
    signal mem_data   : std_logic_vector(15 downto 0);
    signal mem_oe_n   : std_logic;
    signal mem_we_n   : std_logic;
    signal mem_cs_n   : std_logic_vector(3 downto 0);
    signal mem_byte_n : std_logic_vector(1 downto 0);
    signal pass : boolean := true;
begin
    HCLK    <= not HCLK after 10 ns;
    HRESETn <= '0', '1' after 100 ns;

    DUT : entity work.ext_mem_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            mem_addr => mem_addr, mem_data => mem_data,
            mem_oe_n => mem_oe_n, mem_we_n => mem_we_n,
            mem_cs_n => mem_cs_n, mem_byte_n => mem_byte_n
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
        -- Bits: enable=1, nor_mode=1, async=0 => 0x03
        wr(x"00000000", x"00000003");
        rd(x"00000000", rdata);
        if rdata = x"00000003" then
            report "CTRL PASS" severity note;
        else
            report "CTRL FAIL" severity error;
            pass <= false;
        end if;

        -- Test 2: Write and readback ADDR (0x08)
        wr(x"00000008", x"00010000");
        rd(x"00000008", rdata);
        if rdata = x"00010000" then
            report "ADDR PASS" severity note;
        else
            report "ADDR FAIL" severity error;
            pass <= false;
        end if;

        -- Test 3: Write and readback TIMING (0x0C)
        -- wait_states=5, hold_cycles=2, setup_cycles=1 => 0x010205
        wr(x"0000000C", x"00010205");
        rd(x"0000000C", rdata);
        if rdata = x"00010205" then
            report "TIMING PASS" severity note;
        else
            report "TIMING FAIL" severity error;
            pass <= false;
        end if;

        -- Test 4: Write and readback CS_CFG (0x10)
        wr(x"00000010", x"00080001");
        rd(x"00000010", rdata);
        if rdata = x"00080001" then
            report "CS_CFG PASS" severity note;
        else
            report "CS_CFG FAIL" severity error;
            pass <= false;
        end if;

        -- Test 5: Read STAT (0x04) - should be ready
        rd(x"00000004", rdata);
        if rdata(0) = '1' then
            report "STAT_READY PASS" severity note;
        else
            report "STAT_READY FAIL" severity error;
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
