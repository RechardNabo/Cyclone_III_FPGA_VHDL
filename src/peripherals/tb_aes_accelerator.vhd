-- ================================================================================
-- tb_aes_accelerator : Testbench for AES accelerator
-- ================================================================================
-- Verifies AES-128 ECB encryption via AHB-Lite interface.
--
-- Tests:
--   1. Write key (128-bit)
--   2. Write plaintext data (4 words)
--   3. Start encryption and verify done status
--   4. Read ciphertext output and verify non-zero result
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

entity tb_aes_accelerator is
end entity tb_aes_accelerator;

architecture sim of tb_aes_accelerator is
    signal HCLK    : std_logic := '0';
    signal HRESETn : std_logic := '0';

    signal HSEL      : std_logic                    := '0';
    signal HWRITE    : std_logic                    := '0';
    signal HREADY    : std_logic                    := '1';
    signal HTRANS    : std_logic_vector(1 downto 0) := "00";
    signal HSIZE     : std_logic_vector(2 downto 0) := "010";
    signal HADDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal HWDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal HRDATA    : std_logic_vector(31 downto 0);
    signal HRESP     : std_logic;
    signal HREADYOUT : std_logic;
    signal aes_irq   : std_logic;

    constant CLK_PERIOD : time := 20 ns;
begin
    HCLK <= not HCLK after CLK_PERIOD / 2;

    dut : entity work.aes_accelerator
        port map (
            HCLK => HCLK, HRESETn => HRESETn, HSEL => HSEL, HWRITE => HWRITE,
            HREADY => HREADY, HTRANS => HTRANS, HSIZE => HSIZE,
            HADDR => HADDR, HWDATA => HWDATA, HRDATA => HRDATA,
            HRESP => HRESP, HREADYOUT => HREADYOUT, aes_irq => aes_irq
        );

    stim : process
        procedure ahb_write(addr : in std_logic_vector(31 downto 0);
                            data : in std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '1'; HTRANS <= "10";
            HADDR <= addr; HWDATA <= data;
            wait until rising_edge(HCLK);
            HSEL <= '0'; HWRITE <= '0'; HTRANS <= "00";
        end procedure;

        procedure ahb_read(addr : in std_logic_vector(31 downto 0);
                           data : out std_logic_vector(31 downto 0)) is
        begin
            HSEL <= '1'; HWRITE <= '0'; HTRANS <= "10";
            HADDR <= addr;
            wait until rising_edge(HCLK);
            data := HRDATA;
            HSEL <= '0'; HTRANS <= "00";
        end procedure;

        variable rdata     : std_logic_vector(31 downto 0);
        variable test_pass : boolean := true;
    begin
        HRESETn <= '0';
        wait for 100 ns;
        HRESETn <= '1';
        wait until rising_edge(HCLK);

        -- Test 1: Write 128-bit key
        report "Test 1: Write AES-128 key";
        ahb_write(x"00000008", x"2B7E1516");
        ahb_write(x"0000000C", x"28AED2A6");
        ahb_write(x"00000010", x"ABF71588");
        ahb_write(x"00000014", x"09CF4F3C");
        report "Test 1 PASSED" severity note;

        -- Test 2: Write plaintext (4 words via DATA_IN)
        report "Test 2: Write plaintext data";
        ahb_write(x"00000038", x"6BC1BEE2");
        ahb_write(x"00000038", x"2E409F96");
        ahb_write(x"00000038", x"E93D7E11");
        ahb_write(x"00000038", x"73939217");
        report "Test 2 PASSED" severity note;

        -- Test 3: Start encryption (ECB, encrypt, AES-128)
        report "Test 3: Start AES-128 ECB encryption";
        ahb_write(x"00000000", x"00000001");  -- CTRL: start=1
        wait for 500 ns;
        ahb_read(x"00000004", rdata);  -- STAT
        assert rdata(1) = '1'
            report "Test 3 FAILED: done not set" severity error;
        if rdata(1) = '1' then
            report "Test 3 PASSED" severity note;
        else
            test_pass := false;
        end if;

        -- Test 4: Read ciphertext
        report "Test 4: Read ciphertext output";
        ahb_read(x"0000003C", rdata);  -- DATA_OUT
        assert rdata /= x"00000000"
            report "Test 4 FAILED: ciphertext is zero" severity error;
        if rdata /= x"00000000" then
            report "Test 4 PASSED" severity note;
        else
            test_pass := false;
        end if;

        if test_pass then
            report "PASS" severity note;
        else
            report "FAIL" severity error;
        end if;
        finish;
    end process;
end architecture sim;
