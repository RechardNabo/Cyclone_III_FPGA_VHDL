-- ================================================================================
-- fuse_otp_controller : One-Time-Programmable Fuse Controller
-- ================================================================================
-- 256-bit fuse array (8 x 32-bit words). Educational OTP emulator.
-- Register Map:
--   0x00 CTRL      - bit0=prog_en, bit1=read_en, bit2=irq_en
--   0x04 STAT      - bit0=ready, bit1=prog_done, bit2=fuse_error
--   0x08 FUSE_DATA - read/write fuse word at FUSE_ADDR
--   0x0C FUSE_ADDR - fuse word index (0-7)
--   0x10 FUSE_PROG - write magic 0x504F to program fuse (WO)
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fuse_otp_controller is
    port (
        -- AHB-Lite slave interface
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

        -- Fuse interface
        fuse_irq  : out std_logic
    );
end entity fuse_otp_controller;

architecture rtl of fuse_otp_controller is
    constant FUSE_CTRL  : std_logic_vector(3 downto 0) := "0000";
    constant FUSE_STAT  : std_logic_vector(3 downto 0) := "0001";
    constant FUSE_DATA  : std_logic_vector(3 downto 0) := "0010";
    constant FUSE_ADDR  : std_logic_vector(3 downto 0) := "0011";
    constant FUSE_PROG  : std_logic_vector(3 downto 0) := "0100";

    constant FUSE_WORDS : integer := 8;
    constant PROG_MAGIC : std_logic_vector(15 downto 0) := x"504F";

    signal ctrl_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal fuse_addr_reg  : unsigned(31 downto 0) := (others => '0');

    type fuse_array_t is array (0 to FUSE_WORDS-1) of std_logic_vector(31 downto 0);
    signal fuse_data_mem  : fuse_array_t := (others => (others => '0'));
    signal fuse_programmed: std_logic_vector(FUSE_WORDS-1 downto 0) := (others => '0');

    signal prog_pending   : std_logic_vector(31 downto 0) := (others => '0');
    signal prog_done      : std_logic := '0';
    signal fuse_error     : std_logic := '0';
    signal ready          : std_logic := '1';

    signal reg_sel        : std_logic_vector(3 downto 0);
    signal write_en       : std_logic;
    signal read_en        : std_logic;

    type state_t is (IDLE, PROGRAMMING, DONE_STATE, ERROR_STATE);
    signal state : state_t := IDLE;

begin

    reg_sel  <= HADDR(5 downto 2);
    write_en <= HSEL and HWRITE and HREADY and (HTRANS(0) or HTRANS(1));
    read_en  <= HSEL and (not HWRITE) and HREADY and (HTRANS(0) or HTRANS(1));

    HREADYOUT <= '1';
    HRESP     <= '0';

    -- Fuse programming state machine
    fuse_fsm : process(HCLK)
        variable idx : integer range 0 to FUSE_WORDS-1;
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                state           <= IDLE;
                prog_done       <= '0';
                fuse_error      <= '0';
                ready           <= '1';
                prog_pending    <= (others => '0');
            else
                case state is
                    when IDLE =>
                        ready     <= '1';
                        prog_done <= '0';
                        if write_en = '1' and reg_sel = FUSE_PROG then
                            if HWDATA(15 downto 0) = PROG_MAGIC and
                               ctrl_reg(0) = '1' then
                                idx := to_integer(fuse_addr_reg(2 downto 0));
                                if fuse_programmed(idx) = '0' then
                                    state        <= PROGRAMMING;
                                    ready        <= '0';
                                else
                                    fuse_error   <= '1';
                                    state        <= ERROR_STATE;
                                end if;
                            else
                                fuse_error <= '1';
                                state      <= ERROR_STATE;
                            end if;
                        end if;

                    when PROGRAMMING =>
                        idx := to_integer(fuse_addr_reg(2 downto 0));
                        fuse_data_mem(idx)   <= prog_pending;
                        fuse_programmed(idx) <= '1';
                        state                <= DONE_STATE;

                    when DONE_STATE =>
                        prog_done <= '1';
                        state     <= IDLE;

                    when ERROR_STATE =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process fuse_fsm;

    -- Register write process
    reg_write : process(HCLK)
    begin
        if rising_edge(HCLK) then
            if HRESETn = '0' then
                ctrl_reg      <= (others => '0');
                fuse_addr_reg <= (others => '0');
            elsif write_en = '1' then
                case reg_sel is
                    when FUSE_CTRL =>
                        ctrl_reg <= HWDATA;
                    when FUSE_ADDR =>
                        fuse_addr_reg <= unsigned(HWDATA);
                    when FUSE_DATA =>
                        prog_pending <= HWDATA;
                    when FUSE_STAT =>
                        if HWDATA(2) = '1' then
                            fuse_error <= '0';
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process reg_write;

    -- Register read mux
    reg_read : process(reg_sel, ctrl_reg, ready, prog_done, fuse_error,
                       fuse_addr_reg, fuse_data_mem)
        variable idx : integer range 0 to FUSE_WORDS-1;
    begin
        case reg_sel is
            when FUSE_CTRL =>
                HRDATA <= ctrl_reg;
            when FUSE_STAT =>
                HRDATA <= (0 => ready, 1 => prog_done,
                           2 => fuse_error, others => '0');
            when FUSE_DATA =>
                idx := to_integer(fuse_addr_reg(2 downto 0));
                HRDATA <= fuse_data_mem(idx);
            when FUSE_ADDR =>
                HRDATA <= std_logic_vector(fuse_addr_reg);
            when others =>
                HRDATA <= (others => '0');
        end case;
    end process reg_read;

    fuse_irq <= prog_done and ctrl_reg(2);

end architecture rtl;
