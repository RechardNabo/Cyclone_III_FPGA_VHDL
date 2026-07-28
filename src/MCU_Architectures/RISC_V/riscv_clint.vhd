library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- RISC-V Core Local Interruptor (CLINT)
-- Provides machine-mode timer and software interrupts
-- Registers: MSIP (32-bit, per hart), MTIMECMP (64-bit), MTIME (64-bit)
-- AHB-Lite slave interface

entity riscv_clint is
    port (
        HCLK        : in  std_logic;
        HRESETn     : in  std_logic;
        HSEL        : in  std_logic;
        HWRITE      : in  std_logic;
        HREADY      : in  std_logic;
        HTRANS      : in  std_logic_vector(1 downto 0);
        HSIZE       : in  std_logic_vector(2 downto 0);
        HADDR       : in  std_logic_vector(31 downto 0);
        HWDATA      : in  std_logic_vector(31 downto 0);
        HRDATA      : out std_logic_vector(31 downto 0);
        HRESP       : out std_logic;
        HREADYOUT   : out std_logic;
        timer_irq   : out std_logic;
        sw_irq      : out std_logic
    );
end entity riscv_clint;

architecture rtl of riscv_clint is

    -- CLINT register offsets (word-addressed, HADDR[7:2])
    constant ADDR_MSIP     : std_logic_vector(5 downto 0) := "000000"; -- 0x0
    constant ADDR_MTIMECMP_LO : std_logic_vector(5 downto 0) := "000100"; -- 0x10
    constant ADDR_MTIMECMP_HI : std_logic_vector(5 downto 0) := "000101"; -- 0x14
    constant ADDR_MTIME_LO  : std_logic_vector(5 downto 0) := "001000"; -- 0x20
    constant ADDR_MTIME_HI  : std_logic_vector(5 downto 0) := "001001"; -- 0x24

    signal msip        : std_logic_vector(31 downto 0);
    signal mtimecmp_lo : std_logic_vector(31 downto 0);
    signal mtimecmp_hi : std_logic_vector(31 downto 0);
    signal mtime_lo    : std_logic_vector(31 downto 0);
    signal mtime_hi    : std_logic_vector(31 downto 0);

    signal write_en    : std_logic;
    signal addr_idx    : std_logic_vector(5 downto 0);
    signal rdata_int   : std_logic_vector(31 downto 0);
    signal timer_cmp_met : std_logic;

begin

    addr_idx  <= HADDR(7 downto 2);
    write_en  <= HSEL and HWRITE and HREADY when HTRANS = "10" else '0';

    -- timer compare: mtime >= mtimecmp
    timer_cmp_met <= '1' when (unsigned(mtime_hi) & unsigned(mtime_lo)) >=
                              (unsigned(mtimecmp_hi) & unsigned(mtimecmp_lo))
                     else '0';

    timer_irq <= timer_cmp_met and msip(0); -- gated by enable bit for simplicity
    sw_irq    <= msip(0);

    process(HCLK, HRESETn)
        variable time64 : unsigned(63 downto 0);
    begin
        if HRESETn = '0' then
            msip        <= (others => '0');
            mtimecmp_lo <= (others => '1');
            mtimecmp_hi <= (others => '1');
            mtime_lo    <= (others => '0');
            mtime_hi    <= (others => '0');
            rdata_int   <= (others => '0');
        elsif rising_edge(HCLK) then
            -- free-running mtime counter
            time64 := unsigned(mtime_hi) & unsigned(mtime_lo);
            time64 := time64 + 1;
            mtime_hi <= std_logic_vector(time64(63 downto 32));
            mtime_lo <= std_logic_vector(time64(31 downto 0));

            -- AHB write
            if write_en = '1' then
                case addr_idx is
                    when ADDR_MSIP        => msip        <= HWDATA;
                    when ADDR_MTIMECMP_LO => mtimecmp_lo <= HWDATA;
                    when ADDR_MTIMECMP_HI => mtimecmp_hi <= HWDATA;
                    when ADDR_MTIME_LO    => mtime_lo    <= HWDATA;
                    when ADDR_MTIME_HI    => mtime_hi    <= HWDATA;
                    when others => null;
                end case;
            end if;

            -- AHB read
            if HSEL = '1' and HWRITE = '0' and HREADY = '1' and HTRANS = "10" then
                case addr_idx is
                    when ADDR_MSIP        => rdata_int <= msip;
                    when ADDR_MTIMECMP_LO => rdata_int <= mtimecmp_lo;
                    when ADDR_MTIMECMP_HI => rdata_int <= mtimecmp_hi;
                    when ADDR_MTIME_LO    => rdata_int <= mtime_lo;
                    when ADDR_MTIME_HI    => rdata_int <= mtime_hi;
                    when others => rdata_int <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    HRDATA    <= rdata_int;
    HRESP     <= '0';
    HREADYOUT <= '1';

end architecture rtl;
