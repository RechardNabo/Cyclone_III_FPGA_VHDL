--------------------------------------------------------------------------------
-- tb_modbus_controller : Testbench for Modbus RTU/ASCII controller
-- Tests AHB-Lite register read/write for CTRL, SLAVE_ADDR, FUNC_CODE registers
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_modbus_controller is
end entity tb_modbus_controller;

architecture sim of tb_modbus_controller is
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
    signal modbus_txd : std_logic;
    signal modbus_rxd : std_logic := '1';
    signal modbus_irq : std_logic;
    signal pass : boolean := true;
begin
    HCLK    <= not HCLK after 10 ns;
    HRESETn <= '0', '1' after 100 ns;

    DUT : entity work.modbus_controller
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT,
            modbus_txd => modbus_txd, modbus_rxd => modbus_rxd,
            modbus_irq => modbus_irq
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
        -- Bits: enable=1, irq_en=1, rtu_mode=1 => 0x07
        wr(x"00000000", x"00000007");
        rd(x"00000000", rdata);
        if rdata = x"00000007" then
            report "CTRL PASS" severity note;
        else
            report "CTRL FAIL" severity error;
            pass <= false;
        end if;

        -- Test 2: Write and readback SLAVE_ADDR (0x08)
        -- Slave address 24 (0x18)
        wr(x"00000008", x"00000018");
        rd(x"00000008", rdata);
        if rdata = x"00000018" then
            report "SLAVE_ADDR PASS" severity note;
        else
            report "SLAVE_ADDR FAIL" severity error;
            pass <= false;
        end if;

        -- Test 3: Write and readback FUNC_CODE (0x0C)
        -- Function code 3 (read holding registers)
        wr(x"0000000C", x"00000003");
        rd(x"0000000C", rdata);
        if rdata = x"00000003" then
            report "FUNC_CODE PASS" severity note;
        else
            report "FUNC_CODE FAIL" severity error;
            pass <= false;
        end if;

        -- Test 4: Write and readback REG_ADDR (0x10)
        wr(x"00000010", x"00001000");
        rd(x"00000010", rdata);
        if rdata = x"00001000" then
            report "REG_ADDR PASS" severity note;
        else
            report "REG_ADDR FAIL" severity error;
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
