-- ================================================================================
-- trng_controller : True Random Number Generator using ring oscillators
-- ================================================================================
-- Uses multiple free-running ring oscillators (implementable on FPGA) whose
-- phase noise is sampled and XOR'd together, then passed through a von Neumann
-- extractor and a simple entropy accumulator.
--
-- AHB-Lite register map:
--   0x00 : CTRL   - [0] enable, [1] reset
--   0x04 : STAT   - [0] ready, [1] overrun
--   0x08 : DATA   - 32-bit random data (read)
--   0x0C : SEED   - 32-bit seed for PRNG post-processing
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity trng_controller is
    port (
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;
        HSEL      : in  std_logic;
        HWRITE    : in  std_logic;
        HREADY    : in  std_logic;
        HTRANS    : in  std_logic_vector(1 downto 0);
        HSIZE     : in  std_logic_vector(2 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;
        HREADYOUT : out std_logic;
        trng_irq  : out std_logic
    );
end entity trng_controller;

architecture rtl of trng_controller is
    -- Ring oscillator signals (simulated with LFSR-based pseudo-noise)
    -- In real FPGA: use odd number of inverters in a chain
    signal ring_clk_0 : std_logic := '0';
    signal ring_clk_1 : std_logic := '0';
    signal ring_clk_2 : std_logic := '0';
    signal ring_clk_3 : std_logic := '0';

    -- LFSR for simulating ring oscillator jitter
    signal lfsr_0 : std_logic_vector(15 downto 0) := x"ACE1";
    signal lfsr_1 : std_logic_vector(15 downto 0) := x"1234";
    signal lfsr_2 : std_logic_vector(15 downto 0) := x"BEEF";
    signal lfsr_3 : std_logic_vector(15 downto 0) := x"FEED";

    -- Raw entropy samples
    signal raw_sample : std_logic := '0';
    signal prev_sample : std_logic := '0';

    -- Von Neumann extractor
    signal vn_data : std_logic_vector(31 downto 0) := (others => '0');
    signal vn_bit_cnt : integer range 0 to 32 := 0;

    -- Entropy accumulator (XOR fold + shift)
    signal entropy_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal entropy_ready : std_logic := '0';

    -- PRNG post-processing (Xoshiro128** simplified)
    signal prng_s0, prng_s1, prng_s2, prng_s3 : std_logic_vector(31 downto 0);
    signal prng_output : std_logic_vector(31 downto 0) := (others => '0');

    signal enabled : std_logic := '0';
    signal sample_cnt : unsigned(15 downto 0) := (others => '0');

    signal reg_offset : std_logic_vector(7 downto 0);
    signal write_en   : std_logic;

begin
    reg_offset <= HADDR(9 downto 2);
    write_en   <= HSEL and HREADY and HWRITE;

    -- ========================================================================
    -- Ring oscillator simulation (LFSR-based jitter)
    -- ========================================================================
    ring_proc : process(HCLK, HRESETn)
        variable lsb : std_logic;
    begin
        if HRESETn = '0' then
            lfsr_0 <= x"ACE1"; lfsr_1 <= x"1234";
            lfsr_2 <= x"BEEF"; lfsr_3 <= x"FEED";
            ring_clk_0 <= '0'; ring_clk_1 <= '0';
            ring_clk_2 <= '0'; ring_clk_3 <= '0';
        elsif rising_edge(HCLK) then
            if enabled = '1' then
                -- LFSR0 (Galois LFSR, period 2^16-1)
                lsb := lfsr_0(0);
                lfsr_0 <= '0' & lfsr_0(15 downto 1);
                if lsb = '1' then
                    lfsr_0 <= lfsr_0 xor x"B400";
                end if;
                ring_clk_0 <= lfsr_0(3);  -- tap at different positions

                -- LFSR1
                lsb := lfsr_1(0);
                lfsr_1 <= '0' & lfsr_1(15 downto 1);
                if lsb = '1' then
                    lfsr_1 <= lfsr_1 xor x"D008";
                end if;
                ring_clk_1 <= lfsr_1(5);

                -- LFSR2
                lsb := lfsr_2(0);
                lfsr_2 <= '0' & lfsr_2(15 downto 1);
                if lsb = '1' then
                    lfsr_2 <= lfsr_2 xor x"A006";
                end if;
                ring_clk_2 <= lfsr_2(7);

                -- LFSR3
                lsb := lfsr_3(0);
                lfsr_3 <= '0' & lfsr_3(15 downto 1);
                if lsb = '1' then
                    lfsr_3 <= lfsr_3 xor x"F00F";
                end if;
                ring_clk_3 <= lfsr_3(9);
            end if;
        end if;
    end process ring_proc;

    -- ========================================================================
    -- Entropy sampling and von Neumann extraction
    -- ========================================================================
    sample_proc : process(HCLK, HRESETn)
        variable combined : std_logic;
    begin
        if HRESETn = '0' then
            raw_sample <= '0';
            prev_sample <= '0';
            vn_data <= (others => '0');
            vn_bit_cnt <= 0;
            entropy_reg <= (others => '0');
            entropy_ready <= '0';
            sample_cnt <= (others => '0');
        elsif rising_edge(HCLK) then
            if enabled = '1' then
                -- XOR all ring oscillator outputs
                combined := ring_clk_0 xor ring_clk_1 xor ring_clk_2 xor ring_clk_3;
                raw_sample <= combined;
                sample_cnt <= sample_cnt + 1;

                -- Von Neumann extractor:
                --   00 -> discard, 11 -> discard
                --   01 -> output 0, 10 -> output 1
                if sample_cnt(0) = '1' then  -- every other sample
                    if prev_sample = '0' and combined = '1' then
                        vn_data <= vn_data(30 downto 0) & '0';
                        vn_bit_cnt <= vn_bit_cnt + 1;
                    elsif prev_sample = '1' and combined = '0' then
                        vn_data <= vn_data(30 downto 0) & '1';
                        vn_bit_cnt <= vn_bit_cnt + 1;
                    end if;
                    -- When 32 bits collected, fold into entropy register
                    if vn_bit_cnt >= 32 then
                        entropy_reg <= entropy_reg xor vn_data;
                        entropy_ready <= '1';
                        vn_bit_cnt <= 0;
                    else
                        entropy_ready <= '0';
                    end if;
                end if;
                prev_sample <= combined;
            end if;
        end if;
    end process sample_proc;

    -- ========================================================================
    -- PRNG post-processing (XOR with PRNG for whitening)
    -- ========================================================================
    prng_proc : process(HCLK, HRESETn)
        variable tmp : std_logic_vector(31 downto 0);
    begin
        if HRESETn = '0' then
            prng_s0 <= x"180ec6a3"; prng_s1 <= x"42d0a9c3";
            prng_s2 <= x"6a9e2b18"; prng_s3 <= x"5c36c55a";
            prng_output <= (others => '0');
        elsif rising_edge(HCLK) then
            if entropy_ready = '1' then
                -- Re-seed PRNG with entropy
                prng_s0 <= entropy_reg;
                prng_s1 <= entropy_reg xor prng_s1;
                prng_s2 <= entropy_reg xor prng_s2;
                prng_s3 <= entropy_reg xor prng_s3;
            end if;

            -- Xoshiro128** step
            tmp := std_logic_vector(shift_left(unsigned(prng_s1) * 5, 7));
            prng_s1 <= prng_s2 xor prng_s0;
            prng_s2 <= prng_s0 xor prng_s3;
            prng_s3 <= prng_s1 xor prng_s2;
            prng_s0 <= prng_s2;
            prng_output <= tmp;
        end if;
    end process prng_proc;

    -- ========================================================================
    -- AHB register interface
    -- ========================================================================
    ahb_write : process(HCLK, HRESETn)
    begin
        if HRESETn = '0' then
            enabled <= '0';
        elsif rising_edge(HCLK) then
            if write_en = '1' then
                case reg_offset is
                    when x"00" =>  -- CTRL
                        enabled <= HWDATA(0);
                        if HWDATA(1) = '1' then
                            entropy_reg <= (others => '0');
                            vn_bit_cnt <= 0;
                            sample_cnt <= (others => '0');
                        end if;
                    when x"0C" =>  -- SEED
                        prng_s0 <= HWDATA;
                        prng_s1 <= HWDATA xor prng_s1;
                    when others => null;
                end case;
            end if;
        end if;
    end process ahb_write;

    ahb_read : process(HSEL, HADDR, reg_offset, prng_output, enabled, entropy_ready)
        variable rdata : std_logic_vector(31 downto 0);
    begin
        rdata := (others => '0');
        if HSEL = '1' then
            case reg_offset is
                when x"00" => rdata(0) := enabled;
                when x"04" => rdata(0) := entropy_ready;
                when x"08" => rdata := prng_output;
                when others => null;
            end case;
        end if;
        HRDATA <= rdata;
    end process ahb_read;

    HRESP     <= '0';
    HREADYOUT <= '1';
    trng_irq  <= entropy_ready;

end architecture rtl;
