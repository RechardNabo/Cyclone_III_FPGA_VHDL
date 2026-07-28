-- ================================================================================
-- bus_matrix : AHB Bus Matrix / Crossbar with round-robin arbitration
-- ================================================================================
-- Educational AHB Bus Matrix for Cyclone III FPGA.
--
-- Features:
--   * Multi-master to multi-slave crossbar
--   * Round-robin arbitration per slave
--   * Address-decode based slave selection
--   * Configurable number of masters and slaves
--
-- Generics:
--   NUM_MASTERS - number of AHB masters (default 4)
--   NUM_SLAVES  - number of AHB slaves  (default 8)
--   ADDR_WIDTH  - address bus width     (default 32)
--   DATA_WIDTH  - data bus width        (default 32)
--
-- Slave address windows are 1MB each, starting at 0x00000000.
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity bus_matrix is
    generic (
        NUM_MASTERS : integer := 4;
        NUM_SLAVES  : integer := 8;
        ADDR_WIDTH  : integer := 32;
        DATA_WIDTH  : integer := 32
    );
    port (
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;

        -- Master-side ports (flat arrays)
        m_HSEL     : in  std_logic_vector(NUM_MASTERS-1 downto 0);
        m_HWRITE   : in  std_logic_vector(NUM_MASTERS-1 downto 0);
        m_HTRANS   : in  std_logic_vector(NUM_MASTERS*2-1 downto 0);
        m_HSIZE    : in  std_logic_vector(NUM_MASTERS*3-1 downto 0);
        m_HADDR    : in  std_logic_vector(NUM_MASTERS*ADDR_WIDTH-1 downto 0);
        m_HWDATA   : in  std_logic_vector(NUM_MASTERS*DATA_WIDTH-1 downto 0);
        m_HREADY   : out std_logic_vector(NUM_MASTERS-1 downto 0);
        m_HRDATA   : out std_logic_vector(NUM_MASTERS*DATA_WIDTH-1 downto 0);
        m_HRESP    : out std_logic_vector(NUM_MASTERS-1 downto 0);

        -- Slave-side ports (flat arrays)
        s_HSEL     : out std_logic_vector(NUM_SLAVES-1 downto 0);
        s_HWRITE   : out std_logic_vector(NUM_SLAVES-1 downto 0);
        s_HTRANS   : out std_logic_vector(NUM_SLAVES*2-1 downto 0);
        s_HSIZE    : out std_logic_vector(NUM_SLAVES*3-1 downto 0);
        s_HADDR    : out std_logic_vector(NUM_SLAVES*ADDR_WIDTH-1 downto 0);
        s_HWDATA   : out std_logic_vector(NUM_SLAVES*DATA_WIDTH-1 downto 0);
        s_HREADY   : in  std_logic_vector(NUM_SLAVES-1 downto 0);
        s_HRDATA   : in  std_logic_vector(NUM_SLAVES*DATA_WIDTH-1 downto 0);
        s_HRESP    : in  std_logic_vector(NUM_SLAVES-1 downto 0)
    );
end entity bus_matrix;

architecture rtl of bus_matrix is

    -- Slave window size: 1 MB (20-bit offset)
    constant SLAVE_WINDOW_BITS : integer := 20;

    type slave_master_t is array (0 to NUM_SLAVES-1) of integer range 0 to NUM_MASTERS-1;
    signal grant       : slave_master_t := (others => 0);
    signal rr_priority : slave_master_t := (others => 0);

    signal slave_active : std_logic_vector(NUM_SLAVES-1 downto 0);

    -- Helper: decode master address to slave index
    function addr_to_slave(addr : std_logic_vector) return integer is
        variable idx : integer;
    begin
        idx := to_integer(unsigned(addr(ADDR_WIDTH-1 downto SLAVE_WINDOW_BITS)));
        if idx >= NUM_SLAVES then
            return NUM_SLAVES - 1;  -- default to last slave
        end if;
        return idx;
    end function;

begin

    -- Determine which slaves are being requested and by which masters
    arbitrate : process(HCLK)
        variable req_master : integer;
        variable found      : boolean;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                for s in 0 to NUM_SLAVES-1 loop
                    grant(s)       <= 0;
                    rr_priority(s) <= 0;
                end loop;
            else
                for s in 0 to NUM_SLAVES-1 loop
                    found := false;
                    -- Round-robin starting from priority pointer
                    for offset in 0 to NUM_MASTERS-1 loop
                        req_master := (rr_priority(s) + offset) mod NUM_MASTERS;
                        if m_HSEL(req_master) = '1' and
                           (m_HTRANS(req_master*2+1) or m_HTRANS(req_master*2)) = '1' then
                            if addr_to_slave(
                                m_HADDR((req_master+1)*ADDR_WIDTH-1 downto
                                        req_master*ADDR_WIDTH)) = s then
                                grant(s)       <= req_master;
                                rr_priority(s) <= (req_master + 1) mod NUM_MASTERS;
                                found := true;
                                exit;
                            end if;
                        end if;
                    end loop;
                    if not found then
                        grant(s) <= 0;
                    end if;
                end loop;
            end if;
        end if;
    end process arbitrate;

    -- Slave active signals
    slave_gen : for s in 0 to NUM_SLAVES-1 generate
        slave_active(s) <= '1' when m_HSEL(grant(s)) = '1' and
                                   addr_to_slave(
                                     m_HADDR((grant(s)+1)*ADDR_WIDTH-1 downto
                                             grant(s)*ADDR_WIDTH)) = s
                           else '0';
    end generate;

    -- Drive slave-side signals from granted master
    slave_drive : for s in 0 to NUM_SLAVES-1 generate
        s_HSEL(s)  <= slave_active(s);
        s_HWRITE(s) <= m_HWRITE(grant(s)) when slave_active(s) = '1' else '0';
        s_HTRANS(s*2+1 downto s*2) <=
            m_HTRANS(grant(s)*2+1 downto grant(s)*2) when slave_active(s) = '1'
            else "00";
        s_HSIZE(s*3+2 downto s*3) <=
            m_HSIZE(grant(s)*3+2 downto grant(s)*3) when slave_active(s) = '1'
            else "000";
        s_HADDR((s+1)*ADDR_WIDTH-1 downto s*ADDR_WIDTH) <=
            m_HADDR((grant(s)+1)*ADDR_WIDTH-1 downto grant(s)*ADDR_WIDTH)
            when slave_active(s) = '1' else (others => '0');
        s_HWDATA((s+1)*DATA_WIDTH-1 downto s*DATA_WIDTH) <=
            m_HWDATA((grant(s)+1)*DATA_WIDTH-1 downto grant(s)*DATA_WIDTH)
            when slave_active(s) = '1' else (others => '0');
    end generate;

    -- Drive master-side responses from granted slave
    master_resp : for m in 0 to NUM_MASTERS-1 generate
        master_mux : process(grant, slave_active, s_HREADY, s_HRDATA, s_HRESP,
                             m_HSEL, m_HADDR)
            variable sel_slave : integer;
        begin
            -- Find which slave this master is connected to
            sel_slave := -1;
            for s in 0 to NUM_SLAVES-1 loop
                if grant(s) = m and slave_active(s) = '1' then
                    sel_slave := s;
                    exit;
                end if;
            end loop;

            if sel_slave >= 0 then
                m_HREADY(m) <= s_HREADY(sel_slave);
                m_HRDATA((m+1)*DATA_WIDTH-1 downto m*DATA_WIDTH) <=
                    s_HRDATA((sel_slave+1)*DATA_WIDTH-1 downto
                             sel_slave*DATA_WIDTH);
                m_HRESP(m) <= s_HRESP(sel_slave);
            else
                m_HREADY(m) <= '1';
                m_HRDATA((m+1)*DATA_WIDTH-1 downto m*DATA_WIDTH) <=
                    (others => '0');
                m_HRESP(m) <= '0';
            end if;
        end process master_mux;
    end generate;

end architecture rtl;
