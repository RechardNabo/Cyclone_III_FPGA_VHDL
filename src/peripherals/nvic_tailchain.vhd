-- ================================================================================
-- nvic_tailchain : Enhanced NVIC with tail-chaining optimization
-- ================================================================================
-- ARM Cortex-M NVIC with tail-chaining support. Instead of full push/pop
-- between consecutive interrupts, chains pending interrupts directly.
--
-- Features:
--   * 32 external interrupts with 8 priority levels (3-bit priority)
--   * Tail-chaining: when an exception returns, if another is pending
--     with equal/higher priority, enters it directly without pop/push
--   * Set-pending, clear-pending, enable, disable registers
--   * Active register showing currently-active exceptions
--   * 8 priority registers (4 interrupts per register, 8-bit each)
--
-- Register Map:
--   0x00: ICSR  - bit[6:0]=VECTACTIVE, bit[15:9]=VECTPENDING, bit31=PENDSVSET
--   0x04: ISER  - interrupt set-enable (WO, bit per interrupt)
--   0x08: ICER  - interrupt clear-enable (WO, bit per interrupt)
--   0x0C: ISPR  - interrupt set-pending (WO, bit per interrupt)
--   0x10: ICPR  - interrupt clear-pending (WO, bit per interrupt)
--   0x14: IABR  - interrupt active (RO, bit per interrupt)
--   0x18-0x34: IPR0-IPR7 - priority registers (4 interrupts each)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity nvic_tailchain is
    port (
        HCLK             : in  std_logic;
        HRESETn          : in  std_logic;
        HSEL             : in  std_logic;
        HWRITE           : in  std_logic;
        HREADY           : in  std_logic;
        HTRANS           : in  std_logic_vector(1 downto 0);
        HADDR            : in  std_logic_vector(31 downto 0);
        HWDATA           : in  std_logic_vector(31 downto 0);
        HRDATA           : out std_logic_vector(31 downto 0);
        HRESP            : out std_logic;
        HREADYOUT        : out std_logic;

        -- External interrupt inputs
        irq_in           : in  std_logic_vector(31 downto 0);

        -- CPU interface
        exception_return : in  std_logic;  -- signal from CPU on exception return
        cpu_pri          : in  std_logic_vector(2 downto 0);  -- current exec priority

        -- Outputs to CPU
        irq_out          : out std_logic;   -- exception pending
        irq_num          : out std_logic_vector(5 downto 0);  -- 0-31 + 32=none
        exception_active : out std_logic
    );
end entity nvic_tailchain;

architecture rtl of nvic_tailchain is
    constant NUM_IRQ  : integer := 32;
    constant NUM_PRI  : integer := 8;

    signal enable_reg   : std_logic_vector(NUM_IRQ-1 downto 0) := (others => '0');
    signal pending_reg  : std_logic_vector(NUM_IRQ-1 downto 0) := (others => '0');
    signal active_reg   : std_logic_vector(NUM_IRQ-1 downto 0) := (others => '0');

    type pri_array_t is array (0 to NUM_IRQ-1) of std_logic_vector(2 downto 0);
    signal priority_mem : pri_array_t := (others => (others => '0'));

    signal selected_irq : integer range 0 to 31 := 31;
    signal tailchain    : std_logic := '0';

    signal reg_sel      : std_logic_vector(4 downto 0);
    signal write_en     : std_logic;

    -- Find highest priority pending & enabled interrupt
    -- Lower priority value = higher urgency
    function find_highest(pending, enabled : std_logic_vector;
                          pri_mem : pri_array_t;
                          cur_pri : std_logic_vector) return integer is
        variable best_idx : integer range 0 to 31 := 31;
        variable best_pri : unsigned(2 downto 0) := "111";
        variable cur_u    : unsigned(2 downto 0);
        variable found    : boolean := false;
    begin
        cur_u := unsigned(cur_pri(2 downto 0));
        for i in 0 to NUM_IRQ-1 loop
            if pending(i) = '1' and enabled(i) = '1' then
                if unsigned(pri_mem(i)) < cur_u then  -- higher urgency
                    if (not found) or (unsigned(pri_mem(i)) < best_pri) or
                       (unsigned(pri_mem(i)) = best_pri and i < best_idx) then
                        best_idx := i;
                        best_pri := unsigned(pri_mem(i));
                        found    := true;
                    end if;
                end if;
            end if;
        end loop;
        if found then return best_idx;
        else return 31; end if;  -- 31 used as "none" sentinel when no match
    end function;

begin
    reg_sel  <= HADDR(6 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    HREADYOUT <= '1';
    HRESP     <= '0';

    -- NVIC core process
    nvic_proc : process(HCLK)
        variable next_irq : integer range 0 to 31;
        variable found_any: boolean;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                enable_reg  <= (others => '0');
                pending_reg <= (others => '0');
                active_reg  <= (others => '0');
                selected_irq <= 31;
                tailchain   <= '0';
            else
                -- Latch external IRQ edges into pending
                for i in 0 to NUM_IRQ-1 loop
                    if irq_in(i) = '1' and enable_reg(i) = '1' then
                        pending_reg(i) <= '1';
                    end if;
                end loop;

                -- Handle exception return
                if exception_return = '1' then
                    -- Clear active for current
                    if selected_irq < 32 then
                        active_reg(selected_irq) <= '0';
                    end if;
                    -- Check for tail-chain: any pending with higher priority?
                    next_irq := find_highest(pending_reg, enable_reg,
                                              priority_mem, "111");
                    if next_irq < 31 or (next_irq = 31 and pending_reg(31) = '1'
                                          and enable_reg(31) = '1'
                                          and unsigned(priority_mem(31)) < "111") then
                        selected_irq <= next_irq;
                        active_reg(next_irq) <= '1';
                        pending_reg(next_irq) <= '0';
                        tailchain <= '1';
                    else
                        selected_irq <= 31;
                        tailchain <= '0';
                    end if;
                elsif active_reg = x"00000000" then
                    -- No active exception, check for new one
                    next_irq := find_highest(pending_reg, enable_reg,
                                              priority_mem, cpu_pri);
                    found_any := false;
                    if next_irq < 31 then
                        found_any := true;
                    elsif next_irq = 31 and pending_reg(31) = '1'
                          and enable_reg(31) = '1'
                          and unsigned(priority_mem(31)) < unsigned(cpu_pri) then
                        found_any := true;
                    end if;
                    if found_any then
                        selected_irq <= next_irq;
                        active_reg(next_irq) <= '1';
                        pending_reg(next_irq) <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process nvic_proc;

    -- Register write process
    reg_write : process(HCLK)
        variable pri_idx : integer range 0 to NUM_PRI-1;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                priority_mem <= (others => (others => '0'));
            elsif write_en = '1' then
                case reg_sel is
                    when "00001" => -- ISER
                        enable_reg <= enable_reg or HWDATA(NUM_IRQ-1 downto 0);
                    when "00010" => -- ICER
                        enable_reg <= enable_reg and
                                      not HWDATA(NUM_IRQ-1 downto 0);
                    when "00011" => -- ISPR
                        pending_reg <= pending_reg or HWDATA(NUM_IRQ-1 downto 0);
                    when "00100" => -- ICPR
                        pending_reg <= pending_reg and
                                       not HWDATA(NUM_IRQ-1 downto 0);
                    when others =>
                        -- IPR0-IPR7 at 0x18-0x34 => reg_sel 6 to 13
                        if unsigned(reg_sel) >= 6 and unsigned(reg_sel) <= 13 then
                            pri_idx := to_integer(unsigned(reg_sel)) - 6;
                            for k in 0 to 3 loop
                                if (pri_idx * 4 + k) < NUM_IRQ then
                                    priority_mem(pri_idx*4 + k) <=
                                        HWDATA(k*8 + 7 downto k*8 + 5);
                                end if;
                            end loop;
                        end if;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, enable_reg, pending_reg, active_reg,
                       priority_mem, selected_irq, tailchain)
        variable pri_idx : integer range 0 to NUM_PRI-1;
        variable rdata   : std_logic_vector(31 downto 0);
    begin
        case reg_sel is
            when "00000" => -- ICSR
                HRDATA <= tailchain & "000000000000000" &
                          std_logic_vector(to_unsigned(selected_irq, 7)) &
                          "00" &
                          std_logic_vector(to_unsigned(selected_irq, 7));
            when "00001" => HRDATA <= enable_reg;
            when "00010" => HRDATA <= enable_reg;
            when "00011" => HRDATA <= pending_reg;
            when "00100" => HRDATA <= pending_reg;
            when "00101" => HRDATA <= active_reg;
            when others =>
                rdata := (others => '0');
                if unsigned(reg_sel) >= 6 and unsigned(reg_sel) <= 13 then
                    pri_idx := to_integer(unsigned(reg_sel)) - 6;
                    for k in 0 to 3 loop
                        if (pri_idx * 4 + k) < NUM_IRQ then
                            rdata(k*8 + 7 downto k*8 + 5) :=
                                priority_mem(pri_idx*4 + k);
                        end if;
                    end loop;
                end if;
                HRDATA <= rdata;
        end case;
    end process reg_read;

    irq_out <= '1' when (active_reg /= x"00000000") or
                       (pending_reg /= x"00000000" and
                        enable_reg /= x"00000000")
               else '0';
    irq_num <= std_logic_vector(to_unsigned(selected_irq, 6));
    exception_active <= '1' when active_reg /= x"00000000" else '0';

end architecture rtl;
