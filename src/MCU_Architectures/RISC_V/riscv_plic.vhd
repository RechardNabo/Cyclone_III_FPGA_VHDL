library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- RISC-V Platform-Level Interrupt Controller (PLIC)
-- 32 external interrupt sources with priority, enable, and threshold
-- Registers: PRIORITY0-31, PENDING, ENABLE0-31, THRESHOLD, CLAIM, COMPLETE
-- AHB-Lite slave interface

entity riscv_plic is
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
        ext_irq_in  : in  std_logic_vector(31 downto 0);
        ext_irq_out : out std_logic;
        ext_irq_id  : out std_logic_vector(5 downto 0)
    );
end entity riscv_plic;

architecture rtl of riscv_plic is

    type priority_array is array(0 to 31) of std_logic_vector(2 downto 0);
    type enable_array  is array(0 to 31) of std_logic;

    signal priority    : priority_array;
    signal enable      : enable_array;
    signal threshold   : std_logic_vector(2 downto 0);
    signal pending     : std_logic_vector(31 downto 0);
    signal claim_id    : std_logic_vector(5 downto 0);

    signal write_en    : std_logic;
    signal addr_idx    : std_logic_vector(11 downto 0);
    signal rdata_int   : std_logic_vector(31 downto 0);

    -- Address decode
    -- PRIORITY: 0x000-0x07C (32 regs, 4B each) -> addr[11:2] = 0..31
    -- PENDING:  0x1000 (read-only)
    -- ENABLE:   0x2000 (32-bit, one word)
    -- THRESHOLD:0x3000
    -- CLAIM:    0x3004 (read=claim, write=complete)

    constant BASE_PRIORITY  : std_logic_vector(11 downto 0) := x"000";
    constant ADDR_PENDING   : std_logic_vector(11 downto 0) := x"400"; -- 0x1000>>2
    constant ADDR_ENABLE    : std_logic_vector(11 downto 0) := x"800"; -- 0x2000>>2
    constant ADDR_THRESHOLD : std_logic_vector(11 downto 0) := x"C00"; -- 0x3000>>2
    constant ADDR_CLAIM     : std_logic_vector(11 downto 0) := x"C01"; -- 0x3004>>2

begin

    addr_idx  <= HADDR(13 downto 2);
    write_en  <= HSEL and HWRITE and HREADY when HTRANS = "10" else '0';

    -- pending set from external inputs, cleared on claim
    process(HCLK, HRESETn)
        variable best_pri   : std_logic_vector(2 downto 0);
        variable best_id    : integer range 0 to 31;
        variable found      : boolean;
    begin
        if HRESETn = '0' then
            priority   <= (others => (others => '0'));
            enable     <= (others => '0');
            threshold  <= (others => '0');
            pending    <= (others => '0');
            claim_id   <= (others => '0');
            rdata_int  <= (others => '0');
            ext_irq_out <= '0';
        elsif rising_edge(HCLK) then
            -- latch pending from external IRQ edges
            for i in 0 to 31 loop
                if ext_irq_in(i) = '1' then
                    pending(i) <= '1';
                end if;
            end loop;

            -- find highest priority enabled pending interrupt
            best_pri := threshold;
            best_id  := 0;
            found    := false;
            for i in 0 to 31 loop
                if pending(i) = '1' and enable(i) = '1' then
                    if priority(i) > best_pri then
                        best_pri := priority(i);
                        best_id  := i;
                        found    := true;
                    end if;
                end if;
            end loop;

            if found then
                ext_irq_out <= '1';
                ext_irq_id  <= std_logic_vector(to_unsigned(best_id, 6));
            else
                ext_irq_out <= '0';
                ext_irq_id  <= (others => '0');
            end if;

            -- AHB write
            if write_en = '1' then
                if addr_idx(11 downto 5) = "0000000" and addr_idx(4 downto 0) /= "00000" then
                    -- priority 1..31 (source 0 reserved)
                    priority(to_integer(unsigned(addr_idx(4 downto 0)))) <= HWDATA(2 downto 0);
                elsif addr_idx = ADDR_ENABLE then
                    for i in 0 to 31 loop
                        enable(i) <= HWDATA(i);
                    end loop;
                elsif addr_idx = ADDR_THRESHOLD then
                    threshold <= HWDATA(2 downto 0);
                elsif addr_idx = ADDR_CLAIM then
                    -- complete: clear pending for claimed ID
                    if claim_id /= "000000" then
                        pending(to_integer(unsigned(claim_id(4 downto 0)))) <= '0';
                    end if;
                end if;
            end if;

            -- AHB read
            if HSEL = '1' and HWRITE = '0' and HREADY = '1' and HTRANS = "10" then
                if addr_idx(11 downto 5) = "0000000" then
                    rdata_int <= x"000000" & "00000" & priority(to_integer(unsigned(addr_idx(4 downto 0))));
                elsif addr_idx = ADDR_PENDING then
                    rdata_int <= pending;
                elsif addr_idx = ADDR_ENABLE then
                    rdata_int <= std_logic_vector(enable);
                elsif addr_idx = ADDR_THRESHOLD then
                    rdata_int <= x"000000" & "00000" & threshold;
                elsif addr_idx = ADDR_CLAIM then
                    if found then
                        claim_id  <= std_logic_vector(to_unsigned(best_id, 6));
                        rdata_int <= x"000000" & std_logic_vector(to_unsigned(best_id, 6));
                    else
                        claim_id  <= (others => '0');
                        rdata_int <= (others => '0');
                    end if;
                else
                    rdata_int <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    HRDATA    <= rdata_int;
    HRESP     <= '0';
    HREADYOUT <= '1';

end architecture rtl;
