--------------------------------------------------------------------------------
-- tb_i2c_master_ahb : Testbench for I2C master controller
-- Tests AHB-Lite register read/write for CTRL, CLKDIV, ADDR registers
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_i2c_master_ahb is
end entity tb_i2c_master_ahb;

architecture sim of tb_i2c_master_ahb is
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
    signal sda       : std_logic;
    signal scl       : std_logic;
    signal i2c_int   : std_logic;
    signal pass : boolean := true;
begin
    HCLK    <= not HCLK after 10 ns;
    HRESETn <= '0', '1' after 100 ns;

    -- I2C bus pull-ups
    sda <= 'H';
    scl <= 'H';

    DUT : entity work.i2c_master_ahb
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            sda => sda, scl => scl, i2c_int => i2c_int
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
        -- Bits: enable=1, irq_en=1, 10bit_addr=1 => 0x07
        wr(x"00000000", x"00000007");
        rd(x"00000000", rdata);
        if rdata = x"00000007" then
            report "CTRL PASS" severity note;
        else
            report "CTRL FAIL" severity error;
            pass <= false;
        end if;

        -- Test 2: Write and readback CLKDIV (0x04)
        -- Clock divider = 250 (0x00FA)
        wr(x"00000004", x"000000FA");
        rd(x"00000004", rdata);
        if rdata = x"000000FA" then
            report "CLKDIV PASS" severity note;
        else
            report "CLKDIV FAIL" severity error;
            pass <= false;
        end if;

        -- Test 3: Write and readback ADDR (0x0C)
        -- 7-bit slave address 0x48 = 72
        wr(x"0000000C", x"00000048");
        rd(x"0000000C", rdata);
        if rdata(9 downto 0) = "00" & x"48" then
            report "ADDR PASS" severity note;
        else
            report "ADDR FAIL" severity error;
            pass <= false;
        end if;

        -- Test 4: Read STATUS (0x08) - should not be busy
        rd(x"00000008", rdata);
        if rdata(0) = '0' then
            report "STATUS_NOT_BUSY PASS" severity note;
        else
            report "STATUS_NOT_BUSY FAIL" severity error;
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
