-- ================================================================================
-- rp2040_bootrom : RP2040 Boot ROM emulator with AHB-Lite slave interface
-- ================================================================================
-- Emulates the RP2040 boot sequence: reads first 256 bytes from flash,
-- validates a checksum, then jumps to flash address 0x10000000.
--
-- Register Map:
--   0x00: CTRL        - bit0=boot_en, bit1=irq_en, bit2=force_boot
--   0x04: STAT        - bit0=boot_done, bit1=checksum_ok, bit2=flash_err
--   0x08: BOOT_ADDR   - jump target address (default 0x10000000)
--   0x0C: FLASH_SIG   - expected flash signature (checksum)
--   0x10: BOOT_STAGE  - current boot stage (0=idle,1=read,2=validate,3=jump,4=done)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rp2040_bootrom is
    port (
        -- AHB-Lite slave interface
        HCLK      : in  std_logic;
        HRESETn   : in  std_logic;
        HSEL      : in  std_logic;
        HWRITE    : in  std_logic;
        HREADY    : in  std_logic;
        HTRANS    : in  std_logic_vector(1 downto 0);
        HADDR     : in  std_logic_vector(31 downto 0);
        HWDATA    : in  std_logic_vector(31 downto 0);
        HRDATA    : out std_logic_vector(31 downto 0);
        HRESP     : out std_logic;
        HREADYOUT : out std_logic;

        -- Bootrom interface
        boot_irq      : out std_logic;
        boot_addr_out : out std_logic_vector(31 downto 0);
        boot_en       : out std_logic
    );
end entity rp2040_bootrom;

architecture rtl of rp2040_bootrom is
    constant BOOT_FLASH_BASE : std_logic_vector(31 downto 0) := x"10000000";
    constant BOOT_READ_LEN   : integer := 256;
    constant BOOT_READ_WORDS : integer := 64;  -- 256/4

    type boot_stage_t is (STAGE_IDLE, STAGE_READ, STAGE_VALIDATE, STAGE_JUMP, STAGE_DONE);
    signal stage : boot_stage_t := STAGE_IDLE;

    signal ctrl_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal stat_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal boot_addr   : std_logic_vector(31 downto 0) := BOOT_FLASH_BASE;
    signal flash_sig   : std_logic_vector(31 downto 0) := (others => '0');
    signal stage_reg   : std_logic_vector(31 downto 0) := (others => '0');

    signal checksum    : unsigned(31 downto 0) := (others => '0');
    signal read_idx    : integer range 0 to BOOT_READ_WORDS := 0;
    signal flash_err   : std_logic := '0';
    signal cksum_ok    : std_logic := '0';
    signal write_en    : std_logic;

    -- Simulated flash content (first 256 bytes / 64 words)
    type flash_array is array(0 to BOOT_READ_WORDS-1) of std_logic_vector(31 downto 0);
    signal flash_data  : flash_array := (others => (others => '0'));

begin

    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Boot state machine
    boot_fsm : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                stage     <= STAGE_IDLE;
                read_idx  <= 0;
                checksum  <= (others => '0');
                flash_err <= '0';
                cksum_ok  <= '0';
            else
                case stage is
                    when STAGE_IDLE =>
                        if ctrl_reg(0) = '1' or ctrl_reg(2) = '1' then
                            stage    <= STAGE_READ;
                            read_idx <= 0;
                            checksum <= (others => '0');
                            flash_err <= '0';
                            cksum_ok  <= '0';
                        end if;

                    when STAGE_READ =>
                        if read_idx < BOOT_READ_WORDS then
                            checksum <= checksum + unsigned(flash_data(read_idx));
                            read_idx <= read_idx + 1;
                        else
                            stage <= STAGE_VALIDATE;
                        end if;

                    when STAGE_VALIDATE =>
                        if checksum = unsigned(flash_sig) then
                            cksum_ok <= '1';
                            stage    <= STAGE_JUMP;
                        else
                            flash_err <= '1';
                            stage     <= STAGE_DONE;
                        end if;

                    when STAGE_JUMP =>
                        stage <= STAGE_DONE;

                    when STAGE_DONE =>
                        if ctrl_reg(0) = '0' and ctrl_reg(2) = '0' then
                            stage <= STAGE_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process boot_fsm;

    -- Stage encoding
    stage_reg <= x"00000000" when stage = STAGE_IDLE else
                 x"00000001" when stage = STAGE_READ else
                 x"00000002" when stage = STAGE_VALIDATE else
                 x"00000003" when stage = STAGE_JUMP else
                 x"00000004";

    -- Status register
    stat_reg(0) <= '1' when stage = STAGE_DONE else '0';
    stat_reg(1) <= cksum_ok;
    stat_reg(2) <= flash_err;

    -- Register write
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg  <= (others => '0');
                boot_addr <= BOOT_FLASH_BASE;
                flash_sig <= (others => '0');
            elsif write_en = '1' then
                case HADDR(5 downto 2) is
                    when "0000" => ctrl_reg  <= HWDATA;
                    when "0010" => boot_addr <= HWDATA;
                    when "0011" => flash_sig <= HWDATA;
                    when others => null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(HADDR, ctrl_reg, stat_reg, boot_addr, flash_sig, stage_reg)
    begin
        case HADDR(5 downto 2) is
            when "0000" => HRDATA <= ctrl_reg;
            when "0001" => HRDATA <= stat_reg;
            when "0010" => HRDATA <= boot_addr;
            when "0011" => HRDATA <= flash_sig;
            when "0100" => HRDATA <= stage_reg;
            when others => HRDATA <= (others => '0');
        end case;
    end process reg_read;

    -- Outputs
    boot_en       <= '1' when stage = STAGE_JUMP else '0';
    boot_addr_out <= boot_addr;
    boot_irq      <= '1' when (ctrl_reg(1) = '1' and stage = STAGE_DONE) else '0';

end architecture rtl;
