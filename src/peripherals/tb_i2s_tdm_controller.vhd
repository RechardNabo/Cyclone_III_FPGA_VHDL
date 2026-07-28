--------------------------------------------------------------------------------
-- tb_i2s_tdm_controller : Testbench for I2S/TDM controller
-- Tests AHB-Lite register read/write for CTRL, TDM_SLOTS, SLOT_SIZE registers
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_i2s_tdm_controller is
end entity tb_i2s_tdm_controller;

architecture sim of tb_i2s_tdm_controller is
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
    signal i2s_sck   : std_logic;
    signal i2s_ws    : std_logic;
    signal i2s_sd_tx : std_logic;
    signal i2s_sd_rx : std_logic := '0';
    signal i2s_fs    : std_logic;
    signal i2s_irq   : std_logic;
    signal pass : boolean := true;
begin
    HCLK    <= not HCLK after 10 ns;
    HRESETn <= '0', '1' after 100 ns;

    DUT : entity work.i2s_tdm_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            i2s_sck => i2s_sck, i2s_ws => i2s_ws, i2s_sd_tx => i2s_sd_tx,
            i2s_sd_rx => i2s_sd_rx, i2s_fs => i2s_fs, i2s_irq => i2s_irq
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
        -- Bits: enable=1, irq_en=1, tdm_mode=1, master_clk=1 => 0x0F
        wr(x"00000000", x"0000000F");
        rd(x"00000000", rdata);
        if rdata = x"0000000F" then
            report "CTRL PASS" severity note;
        else
            report "CTRL FAIL" severity error;
            pass <= false;
        end if;

        -- Test 2: Write and readback TDM_SLOTS (0x08) = 16
        -- Bit 0 = 1 selects 16 slots
        wr(x"00000008", x"00000001");
        rd(x"00000008", rdata);
        if rdata = x"00000001" then
            report "TDM_SLOTS PASS" severity note;
        else
            report "TDM_SLOTS FAIL" severity error;
            pass <= false;
        end if;

        -- Test 3: Write and readback SLOT_SIZE (0x0C) = 32
        -- Value 0x2 maps to 32-bit slot size
        wr(x"0000000C", x"00000002");
        rd(x"0000000C", rdata);
        if rdata = x"00000002" then
            report "SLOT_SIZE PASS" severity note;
        else
            report "SLOT_SIZE FAIL" severity error;
            pass <= false;
        end if;

        -- Test 4: Read STAT (0x04) - check tx_ready
        rd(x"00000004", rdata);
        if rdata(0) = '1' then
            report "STAT_TX_READY PASS" severity note;
        else
            report "STAT_TX_READY FAIL" severity error;
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
