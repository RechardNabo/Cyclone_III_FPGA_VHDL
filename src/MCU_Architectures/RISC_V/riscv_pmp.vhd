library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- RISC-V Physical Memory Protection (PMP)
-- 16 regions with configurable address ranges and permissions (R/W/X)
-- Registers: PMPCFG0-3 (4 configs per register, 16 total), PMPADDR0-15
-- AHB-Lite slave interface for configuration
-- access_type: 00=read, 01=write, 10=execute

entity riscv_pmp is
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
        vaddr       : in  std_logic_vector(31 downto 0);
        access_type : in  std_logic_vector(1 downto 0);
        pmp_fault   : out std_logic
    );
end entity riscv_pmp;

architecture rtl of riscv_pmp is

    type cfg_array  is array(0 to 15) of std_logic_vector(7 downto 0);
    type addr_array is array(0 to 15) of std_logic_vector(31 downto 0);

    signal pmpcfg   : cfg_array;
    signal pmpaddr  : addr_array;

    signal write_en : std_logic;
    signal addr_idx : std_logic_vector(5 downto 0);
    signal rdata_int: std_logic_vector(31 downto 0);
    signal fault_int: std_logic;

    -- PMP config bits: L(7), A(4:3), X(2), W(1), R(0)
    -- A field: 00=OFF, 01=TOR, 10=NA4, 11=NAPOT

begin

    addr_idx  <= HADDR(7 downto 2);
    write_en  <= HSEL and HWRITE and HREADY when HTRANS = "10" else '0';

    -- PMP check process
    process(vaddr, access_type, pmpcfg, pmpaddr)
        variable match     : boolean;
        variable base      : unsigned(31 downto 0);
        variable region_sz : unsigned(31 downto 0);
        variable perm_ok   : boolean;
        variable matched   : boolean;
    begin
        fault_int <= '0';
        matched   := false;

        for i in 0 to 15 loop
            if pmpcfg(i)(7) = '1' then -- locked and active
                match := false;
                case pmpcfg(i)(4 downto 3) is
                    when "01" => -- TOR
                        if i > 0 then
                            base := unsigned(pmpaddr(i-1)) sll 2;
                        else
                            base := (others => '0');
                        end if;
                        if unsigned(vaddr) >= base and
                           unsigned(vaddr) < (unsigned(pmpaddr(i)) sll 2) then
                            match := true;
                        end if;
                    when "10" => -- NA4
                        base := unsigned(pmpaddr(i)) sll 2;
                        if unsigned(vaddr(31 downto 2)) = base(31 downto 2) then
                            match := true;
                        end if;
                    when "11" => -- NAPOT (simplified: 8-byte granularity)
                        base := unsigned(pmpaddr(i)) sll 2;
                        if unsigned(vaddr(31 downto 3)) = base(31 downto 3) then
                            match := true;
                        end if;
                    when others => -- OFF
                        match := false;
                end case;

                if match then
                    matched := true;
                    perm_ok := false;
                    case access_type is
                        when "00" => perm_ok := pmpcfg(i)(0) = '1'; -- R
                        when "01" => perm_ok := pmpcfg(i)(1) = '1'; -- W
                        when "10" => perm_ok := pmpcfg(i)(2) = '1'; -- X
                        when others => perm_ok := false;
                    end case;
                    if not perm_ok then
                        fault_int <= '1';
                    end if;
                end if;
            end if;
        end loop;

        -- If no region matched and any PMP region is locked, fault
        if not matched then
            for i in 0 to 15 loop
                if pmpcfg(i)(7) = '1' and pmpcfg(i)(4 downto 3) /= "00" then
                    fault_int <= '1';
                end if;
            end loop;
        end if;
    end process;

    pmp_fault <= fault_int;

    process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            pmpcfg    <= (others => (others => '0'));
            pmpaddr   <= (others => (others => '0'));
            rdata_int <= (others => '0');
        elsif rising_edge(HCLK) then
            -- AHB write
            if write_en = '1' then
                if addr_idx(5 downto 4) = "00" and addr_idx(3 downto 2) /= "11" then
                    -- PMPCFG0-3: addr_idx = 0,1,2,3
                    for i in 0 to 3 loop
                        pmpcfg(to_integer(unsigned(addr_idx(1 downto 0))) * 4 + i)
                            <= HWDATA(i*8 + 7 downto i*8);
                    end loop;
                elsif addr_idx(5) = '1' then
                    -- PMPADDR0-15: addr_idx = 32..47
                    pmpaddr(to_integer(unsigned(addr_idx(3 downto 0)))) <= HWDATA;
                end if;
            end if;

            -- AHB read
            if HSEL = '1' and HWRITE = '0' and HREADY = '1' and HTRANS = "10" then
                if addr_idx(5 downto 4) = "00" and addr_idx(3 downto 2) /= "11" then
                    rdata_int <= pmpcfg(to_integer(unsigned(addr_idx(1 downto 0))) * 4 + 3) &
                                 pmpcfg(to_integer(unsigned(addr_idx(1 downto 0))) * 4 + 2) &
                                 pmpcfg(to_integer(unsigned(addr_idx(1 downto 0))) * 4 + 1) &
                                 pmpcfg(to_integer(unsigned(addr_idx(1 downto 0))) * 4 + 0);
                elsif addr_idx(5) = '1' then
                    rdata_int <= pmpaddr(to_integer(unsigned(addr_idx(3 downto 0))));
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
