library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- RISC-V Control & Status Registers (CSR)
-- Implements machine-mode CSRs: MSTATUS, MISA, MTVEC, MEPC, MCAUSE,
-- MTVAL, MIP, MIE, MCYCLE, MCYCLEH, MINSTRET, MINSTRETH, MSCRATCH, MHARTID
-- AHB-Lite slave interface

entity riscv_csr is
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
        hart_id     : in  std_logic_vector(3 downto 0);
        exception_in: in  std_logic;
        cause_in    : in  std_logic_vector(4 downto 0);
        epc_in      : in  std_logic_vector(31 downto 0);
        irq_timer   : in  std_logic;
        irq_software: in  std_logic;
        irq_external: in  std_logic
    );
end entity riscv_csr;

architecture rtl of riscv_csr is

    -- CSR address map (offset within 0x300_0000 block)
    constant ADDR_MSTATUS   : std_logic_vector(7 downto 0) := x"00"; -- 0x300
    constant ADDR_MISA      : std_logic_vector(7 downto 0) := x"04"; -- 0x301
    constant ADDR_MTVEC     : std_logic_vector(7 downto 0) := x"08"; -- 0x305
    constant ADDR_MEPC      : std_logic_vector(7 downto 0) := x"0C"; -- 0x341
    constant ADDR_MCAUSE    : std_logic_vector(7 downto 0) := x"10"; -- 0x342
    constant ADDR_MTVAL     : std_logic_vector(7 downto 0) := x"14"; -- 0x343
    constant ADDR_MIP       : std_logic_vector(7 downto 0) := x"18"; -- 0x344
    constant ADDR_MIE       : std_logic_vector(7 downto 0) := x"1C"; -- 0x304
    constant ADDR_MCYCLE    : std_logic_vector(7 downto 0) := x"20"; -- 0xB00
    constant ADDR_MCYCLEH   : std_logic_vector(7 downto 0) := x"24"; -- 0xB80
    constant ADDR_MINSTRET  : std_logic_vector(7 downto 0) := x"28"; -- 0xB02
    constant ADDR_MINSTRETH : std_logic_vector(7 downto 0) := x"2C"; -- 0xB82
    constant ADDR_MSCRATCH  : std_logic_vector(7 downto 0) := x"30"; -- 0x340
    constant ADDR_MHARTID   : std_logic_vector(7 downto 0) := x"34"; -- 0xF14

    signal mstatus    : std_logic_vector(31 downto 0);
    signal misa       : std_logic_vector(31 downto 0);
    signal mtvec      : std_logic_vector(31 downto 0);
    signal mepc       : std_logic_vector(31 downto 0);
    signal mcause     : std_logic_vector(31 downto 0);
    signal mtval      : std_logic_vector(31 downto 0);
    signal mip        : std_logic_vector(31 downto 0);
    signal mie        : std_logic_vector(31 downto 0);
    signal mcycle     : std_logic_vector(31 downto 0);
    signal mcycleh    : std_logic_vector(31 downto 0);
    signal minstret   : std_logic_vector(31 downto 0);
    signal minstreth  : std_logic_vector(31 downto 0);
    signal mscratch   : std_logic_vector(31 downto 0);

    signal write_en   : std_logic;
    signal addr_idx   : std_logic_vector(7 downto 0);
    signal rdata_int  : std_logic_vector(31 downto 0);

begin

    addr_idx  <= HADDR(9 downto 2);
    write_en  <= HSEL and HWRITE and HREADY when HTRANS = "10" else '0';

    -- MIP bits: MSIP(3), MTIP(7), MEIP(11)
    mip(3)  <= irq_software;
    mip(7)  <= irq_timer;
    mip(11) <= irq_external;
    mip(31 downto 12) <= (others => '0');
    mip(6 downto 4)   <= (others => '0');
    mip(2 downto 0)   <= (others => '0');

    process(HCLK, HRESETn)
        variable cycle64 : unsigned(63 downto 0);
    begin
        if HRESETn = '0' then
            mstatus   <= (others => '0');
            misa      <= x"40001100"; -- RV32IMAC
            mtvec     <= (others => '0');
            mepc      <= (others => '0');
            mcause    <= (others => '0');
            mtval     <= (others => '0');
            mie       <= (others => '0');
            mcycle    <= (others => '0');
            mcycleh   <= (others => '0');
            minstret  <= (others => '0');
            minstreth <= (others => '0');
            mscratch  <= (others => '0');
            rdata_int <= (others => '0');
        elsif rising_edge(HCLK) then
            -- cycle counter increment
            cycle64 := unsigned(mcycleh) & unsigned(mcycle);
            cycle64 := cycle64 + 1;
            mcycleh <= std_logic_vector(cycle64(63 downto 32));
            mcycle  <= std_logic_vector(cycle64(31 downto 0));

            -- exception capture
            if exception_in = '1' then
                mepc   <= epc_in;
                mcause <= x"0000000" & "000" & cause_in;
                mstatus(7 downto 3) <= mstatus(3 downto 0) & mstatus(7); -- push MPIE/MIE
                mstatus(3) <= '0'; -- clear MIE
            end if;

            -- AHB write
            if write_en = '1' then
                case addr_idx is
                    when ADDR_MSTATUS   => mstatus  <= HWDATA;
                    when ADDR_MISA      => misa     <= HWDATA;
                    when ADDR_MTVEC     => mtvec    <= HWDATA;
                    when ADDR_MEPC      => mepc     <= HWDATA;
                    when ADDR_MCAUSE    => mcause   <= HWDATA;
                    when ADDR_MTVAL     => mtval    <= HWDATA;
                    when ADDR_MIE       => mie      <= HWDATA;
                    when ADDR_MCYCLE    => mcycle   <= HWDATA;
                    when ADDR_MCYCLEH   => mcycleh  <= HWDATA;
                    when ADDR_MINSTRET  => minstret <= HWDATA;
                    when ADDR_MINSTRETH => minstreth<= HWDATA;
                    when ADDR_MSCRATCH  => mscratch <= HWDATA;
                    when others => null;
                end case;
            end if;

            -- AHB read
            if HSEL = '1' and HWRITE = '0' and HREADY = '1' and HTRANS = "10" then
                case addr_idx is
                    when ADDR_MSTATUS   => rdata_int <= mstatus;
                    when ADDR_MISA      => rdata_int <= misa;
                    when ADDR_MTVEC     => rdata_int <= mtvec;
                    when ADDR_MEPC      => rdata_int <= mepc;
                    when ADDR_MCAUSE    => rdata_int <= mcause;
                    when ADDR_MTVAL     => rdata_int <= mtval;
                    when ADDR_MIP       => rdata_int <= mip;
                    when ADDR_MIE       => rdata_int <= mie;
                    when ADDR_MCYCLE    => rdata_int <= mcycle;
                    when ADDR_MCYCLEH   => rdata_int <= mcycleh;
                    when ADDR_MINSTRET  => rdata_int <= minstret;
                    when ADDR_MINSTRETH => rdata_int <= minstreth;
                    when ADDR_MSCRATCH  => rdata_int <= mscratch;
                    when ADDR_MHARTID   => rdata_int <= x"000000" & hart_id;
                    when others => rdata_int <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    HRDATA    <= rdata_int;
    HRESP     <= '0';
    HREADYOUT <= '1';

end architecture rtl;
