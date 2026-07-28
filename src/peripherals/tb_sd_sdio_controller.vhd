--------------------------------------------------------------------------------
-- tb_sd_sdio_controller : Testbench for SD/SDIO host controller
-- Tests AHB-Lite register config for CTRL, BLKSIZE, BLKCNT and STAT readback
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_sd_sdio_controller is
end entity tb_sd_sdio_controller;

architecture sim of tb_sd_sdio_controller is
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
    signal sd_clk    : std_logic;
    signal sd_cmd    : std_logic;
    signal sd_dat    : std_logic_vector(3 downto 0);
    signal sd_cd_n   : std_logic := '1';  -- no card inserted
    signal sd_irq    : std_logic;
    signal pass : boolean := true;
begin
    HCLK    <= not HCLK after 10 ns;
    HRESETn <= '0', '1' after 100 ns;

    -- SD bus pull-ups
    sd_cmd <= 'H';
    sd_dat <= (others => 'H');

    DUT : entity work.sd_sdio_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            sd_clk => sd_clk, sd_cmd => sd_cmd, sd_dat => sd_dat,
            sd_cd_n => sd_cd_n, sd_irq => sd_irq
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

        -- Test 1: Write CTRL (0x00) to configure controller
        -- enable=1, sd_mode=1, bus_width=1 (4-bit), clkdiv=3 => 0x31
        wr(x"00000000", x"00000031");

        -- Test 2: Write ARG (0x0C) - CMD0 argument
        wr(x"0000000C", x"00000000");

        -- Test 3: Write and readback BLKSIZE (0x28) = 512
        wr(x"00000028", x"00000200");
        rd(x"00000028", rdata);
        if rdata = x"00000200" then
            report "BLKSIZE PASS" severity note;
        else
            report "BLKSIZE FAIL" severity error;
            pass <= false;
        end if;

        -- Test 4: Write and readback BLKCNT (0x2C) = 4
        wr(x"0000002C", x"00000004");
        rd(x"0000002C", rdata);
        if rdata = x"00000004" then
            report "BLKCNT PASS" severity note;
        else
            report "BLKCNT FAIL" severity error;
            pass <= false;
        end if;

        -- Test 5: Read STAT (0x04) - should not be busy
        rd(x"00000004", rdata);
        if rdata(0) = '0' then
            report "STAT_NOT_BUSY PASS" severity note;
        else
            report "STAT_NOT_BUSY FAIL" severity error;
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
