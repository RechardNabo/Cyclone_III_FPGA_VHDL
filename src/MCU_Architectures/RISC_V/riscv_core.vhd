-- ================================================================================
-- riscv_core : Full RV32I educational RISC-V core with CSR and interrupt support
-- Target FPGA : Cyclone III (EP3C16F484C6N)
--
-- RV32I: R-type(ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND) I-type(ADDI..SRAI)
--   U-type(LUI/AUIPC) Loads(LB/LH/LW/LBU/LHU) Stores(SB/SH/SW)
--   Branches(BEQ/BNE/BLT/BGE/BLTU/BGEU) Jumps(JAL/JALR)
--   System(ECALL/EBREAK/FENCE/MRET) CSR(CSRRW/CSRRS/CSRRC/CSRRWI/CSRRSI/CSRRCI)
-- CSRs: mstatus(0x300) mie(0x304) mtvec(0x305) mscratch(0x340) mepc(0x341) mcause(0x342) mtval(0x343) mip(0x344)
-- Regs: x0=zero x1=ra x2=sp x3=gp x4=tp x5-7=t0-2 x8=s0/fp x9=s1 x10-17=a0-7 x18-27=s2-11 x28-31=t3-6
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity riscv_core is
    port (
        clk       : in  std_logic;                     -- System clock
        reset     : in  std_logic;                     -- Active-high reset
        imem_addr : out std_logic_vector(31 downto 0); -- Instruction memory addr (PC)
        imem_data : in  std_logic_vector(31 downto 0); -- Fetched instruction
        dmem_addr : out std_logic_vector(31 downto 0); -- Data memory address
        dmem_wdata: out std_logic_vector(31 downto 0); -- Data to write
        dmem_rdata: in  std_logic_vector(31 downto 0); -- Data read from memory
        dmem_we   : out std_logic;                     -- Data memory write enable
        dmem_re   : out std_logic;                     -- Data memory read enable
        timer_int    : in  std_logic;                  -- Machine timer interrupt (MTIP)
        software_int : in  std_logic;                  -- Machine software interrupt (MSIP)
        external_int : in  std_logic_vector(31 downto 0); -- External interrupts
        irq_out      : out std_logic;                  -- Pulse high when interrupt taken
        mepc_out     : out std_logic_vector(31 downto 0); -- Exception PC (debug)
        mcause_out   : out std_logic_vector(31 downto 0); -- Exception cause (debug)

        -- I2C interface
        i2c_sda : inout std_logic;
        i2c_scl : inout std_logic;
        i2c_int : out std_logic;

        -- SPI interface
        spi_sclk : out std_logic;
        spi_mosi : out std_logic;
        spi_miso : in  std_logic;
        spi_int  : out std_logic;

        -- UART interface
        uart_txd : out std_logic;
        uart_rxd : in  std_logic;
        uart_int : out std_logic;

        -- I2S interface (audio)
        i2s_sck   : out std_logic;
        i2s_ws    : out std_logic;
        i2s_sd_tx : out std_logic;
        i2s_sd_rx : in  std_logic;
        i2s_int   : out std_logic;

        -- Watchdog Timer (WDT)
        wdt_int   : out std_logic;
        wdt_reset : out std_logic;

        -- Real-Time Clock (RTC)
        rtc_int   : out std_logic;

        -- ADC (8-channel, 12-bit = 96 bits)
        adc_in    : in  std_logic_vector(95 downto 0) := (others => '0');
        adc_int   : out std_logic;

        -- DAC (2-channel, 12-bit = 24 bits)
        dac_out   : out std_logic_vector(23 downto 0)
    );
end entity riscv_core;

architecture rtl of riscv_core is

    -- Opcode constants (bits 6:0 of every RV32I instruction)
    constant OP_RTYPE  : std_logic_vector(6 downto 0) := "0110011"; -- R-type ALU
    constant OP_ITYPE  : std_logic_vector(6 downto 0) := "0010011"; -- I-type ALU
    constant OP_LOAD   : std_logic_vector(6 downto 0) := "0000011"; -- Load
    constant OP_STORE  : std_logic_vector(6 downto 0) := "0100011"; -- Store
    constant OP_BRANCH : std_logic_vector(6 downto 0) := "1100011"; -- Branch
    constant OP_JAL    : std_logic_vector(6 downto 0) := "1101111"; -- Jump and link
    constant OP_JALR   : std_logic_vector(6 downto 0) := "1100111"; -- Jump and link reg
    constant OP_LUI    : std_logic_vector(6 downto 0) := "0110111"; -- Load upper imm
    constant OP_AUIPC  : std_logic_vector(6 downto 0) := "0010111"; -- Add upper imm to PC
    constant OP_SYSTEM : std_logic_vector(6 downto 0) := "1110011"; -- ECALL/EBREAK/MRET/CSR
    constant OP_FENCE  : std_logic_vector(6 downto 0) := "0001111"; -- FENCE (NOP)

    -- CSR address constants (12-bit, bits 31:20 of CSR instructions)
    constant CSR_MSTATUS_ADDR  : std_logic_vector(11 downto 0) := x"300";
    constant CSR_MIE_ADDR      : std_logic_vector(11 downto 0) := x"304";
    constant CSR_MTVEC_ADDR    : std_logic_vector(11 downto 0) := x"305";
    constant CSR_MSCRATCH_ADDR : std_logic_vector(11 downto 0) := x"340";
    constant CSR_MEPC_ADDR     : std_logic_vector(11 downto 0) := x"341";
    constant CSR_MCAUSE_ADDR   : std_logic_vector(11 downto 0) := x"342";
    constant CSR_MTVAL_ADDR    : std_logic_vector(11 downto 0) := x"343";
    constant CSR_MIP_ADDR      : std_logic_vector(11 downto 0) := x"344";

    -- Exception cause constants (written to mcause on trap)
    constant CAUSE_ECALL     : std_logic_vector(31 downto 0) := x"0000000B";
    constant CAUSE_EBREAK    : std_logic_vector(31 downto 0) := x"00000003";
    constant CAUSE_MTIMER    : std_logic_vector(31 downto 0) := x"80000007";
    constant CAUSE_MSOFTWARE : std_logic_vector(31 downto 0) := x"80000003";

    -- 32 x 32-bit general purpose registers (x0 hardwired to 0)
    type regfile_t is array(0 to 31) of std_logic_vector(31 downto 0);
    signal regs : regfile_t := (others => (others => '0'));

    signal pc : unsigned(31 downto 0) := (others => '0'); -- Program counter

    -- CSR registers (machine-mode privilege level)
    signal csr_mstatus  : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_mie      : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_mtvec    : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_mscratch : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_mepc     : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_mcause   : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_mtval    : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_mip      : std_logic_vector(31 downto 0) := (others => '0');

    -- Decoded instruction fields (combinational from imem_data)
    signal opcode  : std_logic_vector(6 downto 0);   -- Opcode (bits 6:0)
    signal funct3  : std_logic_vector(2 downto 0);   -- Funct3 (bits 14:12)
    signal funct7  : std_logic_vector(6 downto 0);   -- Funct7 (bits 31:25)
    signal rd      : integer range 0 to 31;          -- Destination register
    signal rs1     : integer range 0 to 31;          -- Source register 1
    signal rs2     : integer range 0 to 31;          -- Source register 2
    signal rs1_val : std_logic_vector(31 downto 0);  -- rs1 value (x0=0)
    signal rs2_val : std_logic_vector(31 downto 0);  -- rs2 value (x0=0)
    signal imm_i   : signed(31 downto 0);  -- I-type immediate (12-bit signed)
    signal imm_s   : signed(31 downto 0);  -- S-type immediate (12-bit signed)
    signal imm_b   : signed(31 downto 0);  -- B-type immediate (13-bit, LSB=0)
    signal imm_u   : signed(31 downto 0);  -- U-type immediate (20-bit upper)
    signal imm_j   : signed(31 downto 0);  -- J-type immediate (21-bit, LSB=0)
    signal imm_sh  : integer range 0 to 31; -- Shift amount for SLLI/SRLI/SRAI
    signal csr_addr: std_logic_vector(11 downto 0); -- 12-bit CSR address
    signal csr_imm : std_logic_vector(4 downto 0);  -- 5-bit CSR zimm

    -- Helper function: read a CSR by address (reduces code duplication)
    function csr_read(addr : std_logic_vector(11 downto 0);
                      mstatus, mie, mtvec, mscratch, mepc, mcause, mtval, mip
                      : std_logic_vector(31 downto 0))
                      return std_logic_vector is
    begin
        case addr is
            when CSR_MSTATUS_ADDR  => return mstatus;
            when CSR_MIE_ADDR      => return mie;
            when CSR_MTVEC_ADDR    => return mtvec;
            when CSR_MSCRATCH_ADDR => return mscratch;
            when CSR_MEPC_ADDR     => return mepc;
            when CSR_MCAUSE_ADDR   => return mcause;
            when CSR_MTVAL_ADDR    => return mtval;
            when CSR_MIP_ADDR      => return mip;
            when others       => return std_logic_vector'(x"00000000");
        end case;
    end function;

    -- =========================================================================
    -- COMPONENT DECLARATIONS: AHB-Lite wrapped peripheral modules
    -- =========================================================================
    component i2c_master_ahb is
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
            sda       : inout std_logic;
            scl       : inout std_logic;
            i2c_int   : out std_logic
        );
    end component;

    component spi_master_ahb is
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
            sclk      : out std_logic;
            mosi      : out std_logic;
            miso      : in  std_logic;
            ss_n      : out std_logic_vector(3 downto 0);
            spi_int   : out std_logic
        );
    end component;

    component uart_ahb is
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
            txd       : out std_logic;
            rxd       : in  std_logic;
            uart_int  : out std_logic
        );
    end component;

    component i2s_master_ahb is
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
            sck       : out std_logic;
            ws        : out std_logic;
            sd_tx     : out std_logic;
            sd_rx     : in  std_logic;
            mclk      : out std_logic;
            i2s_int   : out std_logic
        );
    end component;

    component wdt_controller is
        port (
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
            wdt_int   : out std_logic;
            wdt_reset : out std_logic
        );
    end component;

    component rtc_controller is
        port (
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
            rtc_int   : out std_logic
        );
    end component;

    component adc_controller is
        port (
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
            adc_in    : in  std_logic_vector(95 downto 0);
            adc_int   : out std_logic
        );
    end component;

    component dac_controller is
        port (
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
            dac_out   : out std_logic_vector(23 downto 0)
        );
    end component;

    -- =========================================================================
    -- AHB-LITE INTERNAL BUS SIGNALS
    -- The RISC-V core uses a simple memory interface (dmem). These signals
    -- bridge to AHB-Lite for the wrapped peripheral modules.
    -- =========================================================================
    signal ahb_hresetn    : std_logic;
    signal ahb_hsel_i2c  : std_logic;
    signal ahb_hsel_spi  : std_logic;
    signal ahb_hsel_uart : std_logic;
    signal ahb_hsel_i2s  : std_logic;
    signal ahb_hsel_wdt  : std_logic;
    signal ahb_hsel_rtc  : std_logic;
    signal ahb_hsel_adc  : std_logic;
    signal ahb_hsel_dac  : std_logic;
    signal periph_sel    : std_logic;
    signal ahb_hwrite    : std_logic;
    signal ahb_hready    : std_logic;
    signal ahb_htrans    : std_logic_vector(1 downto 0);
    signal ahb_hsize     : std_logic_vector(2 downto 0);
    signal ahb_haddr     : std_logic_vector(31 downto 0);
    signal ahb_hwdata    : std_logic_vector(31 downto 0);

    -- Peripheral AHB response signals
    signal i2c_hrdata    : std_logic_vector(31 downto 0);
    signal i2c_hresp     : std_logic;
    signal i2c_hreadyout : std_logic;
    signal spi_hrdata    : std_logic_vector(31 downto 0);
    signal spi_hresp     : std_logic;
    signal spi_hreadyout : std_logic;
    signal uart_hrdata   : std_logic_vector(31 downto 0);
    signal uart_hresp    : std_logic;
    signal uart_hreadyout: std_logic;
    signal i2s_hrdata    : std_logic_vector(31 downto 0);
    signal i2s_hresp     : std_logic;
    signal i2s_hreadyout : std_logic;

    -- New peripheral AHB response signals
    signal wdt_hrdata    : std_logic_vector(31 downto 0);
    signal wdt_hresp     : std_logic;
    signal wdt_hreadyout : std_logic;
    signal rtc_hrdata    : std_logic_vector(31 downto 0);
    signal rtc_hresp     : std_logic;
    signal rtc_hreadyout : std_logic;
    signal adc_hrdata    : std_logic_vector(31 downto 0);
    signal adc_hresp     : std_logic;
    signal adc_hreadyout : std_logic;
    signal dac_hrdata    : std_logic_vector(31 downto 0);
    signal dac_hresp     : std_logic;
    signal dac_hreadyout : std_logic;

    -- Internal-only peripheral signals (not exposed on entity)
    signal spi_ss_n      : std_logic_vector(3 downto 0);
    signal i2s_mclk      : std_logic;

    -- Internal data memory signals (for gating external memory access)
    signal dmem_we_int   : std_logic;
    signal dmem_re_int   : std_logic;
    signal dmem_rdata_int: std_logic_vector(31 downto 0);

begin

    -- =========================================================================
    -- AHB-LITE BUS GENERATION FOR PERIPHERAL MODULES
    -- The RISC-V core uses a simple memory interface. We generate AHB-Lite
    -- signals from the dmem interface to connect to AHB-wrapped peripherals.
    -- Address map: I2C=0x1000, SPI=0x2000, UART=0x3000, I2S=0x4000
    -- =========================================================================

    -- AHB reset (RISC-V uses active-high reset, AHB uses active-low)
    ahb_hresetn <= not reset;

    -- AHB-Lite master signals (generated from dmem interface)
    ahb_hwrite <= dmem_we_int;
    ahb_hready <= '1';  -- Master always ready
    ahb_htrans <= "10" when (dmem_we_int = '1' or dmem_re_int = '1') else "00";
    ahb_hsize  <= "010";  -- Word transfer (32-bit)
    ahb_haddr  <= dmem_addr;
    ahb_hwdata <= dmem_wdata;

    -- Address decode: upper 4 bits of dmem_addr select peripheral
    ahb_hsel_i2c  <= '1' when dmem_addr(15 downto 12) = "0001" else '0';
    ahb_hsel_spi  <= '1' when dmem_addr(15 downto 12) = "0010" else '0';
    ahb_hsel_uart <= '1' when dmem_addr(15 downto 12) = "0011" else '0';
    ahb_hsel_i2s  <= '1' when dmem_addr(15 downto 12) = "0100" else '0';
    ahb_hsel_wdt  <= '1' when dmem_addr(15 downto 12) = "0101" else '0';
    ahb_hsel_rtc  <= '1' when dmem_addr(15 downto 12) = "0110" else '0';
    ahb_hsel_adc  <= '1' when dmem_addr(15 downto 12) = "0111" else '0';
    ahb_hsel_dac  <= '1' when dmem_addr(15 downto 12) = "1000" else '0';
    periph_sel    <= ahb_hsel_i2c or ahb_hsel_spi or ahb_hsel_uart or ahb_hsel_i2s or
                     ahb_hsel_wdt or ahb_hsel_rtc or ahb_hsel_adc or ahb_hsel_dac;

    -- Gate external memory access: don't assert dmem_we/dmem_re to external
    -- memory when a peripheral is being accessed
    dmem_we <= dmem_we_int and not periph_sel;
    dmem_re <= dmem_re_int and not periph_sel;

    -- Read data multiplexer: select between external memory and peripherals
    dmem_rdata_int <= i2c_hrdata  when ahb_hsel_i2c  = '1' else
                      spi_hrdata  when ahb_hsel_spi  = '1' else
                      uart_hrdata when ahb_hsel_uart = '1' else
                      i2s_hrdata  when ahb_hsel_i2s  = '1' else
                      wdt_hrdata  when ahb_hsel_wdt  = '1' else
                      rtc_hrdata  when ahb_hsel_rtc  = '1' else
                      adc_hrdata  when ahb_hsel_adc  = '1' else
                      dac_hrdata  when ahb_hsel_dac  = '1' else
                      dmem_rdata;

    -- =========================================================================
    -- I2C MASTER (AHB-Lite) - base address 0x1000
    -- =========================================================================
    u_i2c_master : i2c_master_ahb
        port map (
            HCLK      => clk,
            HRESETn   => ahb_hresetn,
            HSEL      => ahb_hsel_i2c,
            HWRITE    => ahb_hwrite,
            HREADY    => ahb_hready,
            HTRANS    => ahb_htrans,
            HSIZE     => ahb_hsize,
            HADDR     => ahb_haddr,
            HWDATA    => ahb_hwdata,
            HRDATA    => i2c_hrdata,
            HRESP     => i2c_hresp,
            HREADYOUT => i2c_hreadyout,
            sda       => i2c_sda,
            scl       => i2c_scl,
            i2c_int   => i2c_int
        );

    -- =========================================================================
    -- SPI MASTER (AHB-Lite) - base address 0x2000
    -- =========================================================================
    u_spi_master : spi_master_ahb
        port map (
            HCLK      => clk,
            HRESETn   => ahb_hresetn,
            HSEL      => ahb_hsel_spi,
            HWRITE    => ahb_hwrite,
            HREADY    => ahb_hready,
            HTRANS    => ahb_htrans,
            HSIZE     => ahb_hsize,
            HADDR     => ahb_haddr,
            HWDATA    => ahb_hwdata,
            HRDATA    => spi_hrdata,
            HRESP     => spi_hresp,
            HREADYOUT => spi_hreadyout,
            sclk      => spi_sclk,
            mosi      => spi_mosi,
            miso      => spi_miso,
            ss_n      => spi_ss_n,
            spi_int   => spi_int
        );

    -- =========================================================================
    -- UART (AHB-Lite) - base address 0x3000
    -- =========================================================================
    u_uart : uart_ahb
        port map (
            HCLK      => clk,
            HRESETn   => ahb_hresetn,
            HSEL      => ahb_hsel_uart,
            HWRITE    => ahb_hwrite,
            HREADY    => ahb_hready,
            HTRANS    => ahb_htrans,
            HSIZE     => ahb_hsize,
            HADDR     => ahb_haddr,
            HWDATA    => ahb_hwdata,
            HRDATA    => uart_hrdata,
            HRESP     => uart_hresp,
            HREADYOUT => uart_hreadyout,
            txd       => uart_txd,
            rxd       => uart_rxd,
            uart_int  => uart_int
        );

    -- =========================================================================
    -- I2S MASTER (AHB-Lite) - base address 0x4000
    -- =========================================================================
    u_i2s_master : i2s_master_ahb
        port map (
            HCLK      => clk,
            HRESETn   => ahb_hresetn,
            HSEL      => ahb_hsel_i2s,
            HWRITE    => ahb_hwrite,
            HREADY    => ahb_hready,
            HTRANS    => ahb_htrans,
            HSIZE     => ahb_hsize,
            HADDR     => ahb_haddr,
            HWDATA    => ahb_hwdata,
            HRDATA    => i2s_hrdata,
            HRESP     => i2s_hresp,
            HREADYOUT => i2s_hreadyout,
            sck       => i2s_sck,
            ws        => i2s_ws,
            sd_tx     => i2s_sd_tx,
            sd_rx     => i2s_sd_rx,
            mclk      => i2s_mclk,
            i2s_int   => i2s_int
        );

    -- =========================================================================
    -- WDT CONTROLLER (AHB-Lite) - base address 0x5000
    -- =========================================================================
    u_wdt : wdt_controller
        port map (
            HCLK      => clk,
            HRESETn   => ahb_hresetn,
            HSEL      => ahb_hsel_wdt,
            HWRITE    => ahb_hwrite,
            HREADY    => ahb_hready,
            HTRANS    => ahb_htrans,
            HADDR     => ahb_haddr,
            HWDATA    => ahb_hwdata,
            HRDATA    => wdt_hrdata,
            HRESP     => wdt_hresp,
            HREADYOUT => wdt_hreadyout,
            wdt_int   => wdt_int,
            wdt_reset => wdt_reset
        );

    -- =========================================================================
    -- RTC CONTROLLER (AHB-Lite) - base address 0x6000
    -- =========================================================================
    u_rtc : rtc_controller
        port map (
            HCLK      => clk,
            HRESETn   => ahb_hresetn,
            HSEL      => ahb_hsel_rtc,
            HWRITE    => ahb_hwrite,
            HREADY    => ahb_hready,
            HTRANS    => ahb_htrans,
            HADDR     => ahb_haddr,
            HWDATA    => ahb_hwdata,
            HRDATA    => rtc_hrdata,
            HRESP     => rtc_hresp,
            HREADYOUT => rtc_hreadyout,
            rtc_int   => rtc_int
        );

    -- =========================================================================
    -- ADC CONTROLLER (AHB-Lite) - base address 0x7000
    -- =========================================================================
    u_adc : adc_controller
        port map (
            HCLK      => clk,
            HRESETn   => ahb_hresetn,
            HSEL      => ahb_hsel_adc,
            HWRITE    => ahb_hwrite,
            HREADY    => ahb_hready,
            HTRANS    => ahb_htrans,
            HADDR     => ahb_haddr,
            HWDATA    => ahb_hwdata,
            HRDATA    => adc_hrdata,
            HRESP     => adc_hresp,
            HREADYOUT => adc_hreadyout,
            adc_in    => adc_in,
            adc_int   => adc_int
        );

    -- =========================================================================
    -- DAC CONTROLLER (AHB-Lite) - base address 0x8000
    -- =========================================================================
    u_dac : dac_controller
        port map (
            HCLK      => clk,
            HRESETn   => ahb_hresetn,
            HSEL      => ahb_hsel_dac,
            HWRITE    => ahb_hwrite,
            HREADY    => ahb_hready,
            HTRANS    => ahb_htrans,
            HADDR     => ahb_haddr,
            HWDATA    => ahb_hwdata,
            HRDATA    => dac_hrdata,
            HRESP     => dac_hresp,
            HREADYOUT => dac_hreadyout,
            dac_out   => dac_out
        );

    -- =========================================================================
    -- INSTRUCTION DECODE (Combinational): extract fields from instruction word
    -- =========================================================================
    opcode   <= imem_data(6 downto 0);
    rd       <= to_integer(unsigned(imem_data(11 downto 7)));
    funct3   <= imem_data(14 downto 12);
    rs1      <= to_integer(unsigned(imem_data(19 downto 15)));
    rs2      <= to_integer(unsigned(imem_data(24 downto 20)));
    funct7   <= imem_data(31 downto 25);
    csr_addr <= imem_data(31 downto 20);
    csr_imm  <= imem_data(24 downto 20);

    -- Register reads: x0 always returns 0 (hardwired zero register)
    rs1_val <= (others => '0') when rs1 = 0 else regs(rs1);
    rs2_val <= (others => '0') when rs2 = 0 else regs(rs2);

    -- Immediate decoding (sign-extended to 32 bits per RISC-V spec)
    imm_i  <= resize(signed(imem_data(31 downto 20)), 32);
    imm_s  <= resize(signed(std_logic_vector'(imem_data(31 downto 25) & imem_data(11 downto 7))), 32);
    imm_b  <= resize(signed(std_logic_vector'(imem_data(31) & imem_data(7) &
                 imem_data(30 downto 25) & imem_data(11 downto 8) & '0')), 32);
    imm_u  <= signed(std_logic_vector'(imem_data(31 downto 12) & x"000"));
    imm_j  <= resize(signed(std_logic_vector'(imem_data(31) & imem_data(19 downto 12) &
                 imem_data(20) & imem_data(30 downto 21) & '0')), 32);
    imm_sh <= to_integer(unsigned(imem_data(24 downto 20)));

    -- Memory interface: instruction addr = PC, data addr = rs1 + immediate
    -- Note: dmem_wdata is assigned inside the process (for store width selection)
    imem_addr  <= std_logic_vector(pc);
    dmem_addr  <= std_logic_vector(unsigned(rs1_val) + unsigned(imm_i));

    -- =========================================================================
    -- MAIN EXECUTION PROCESS: decode + execute + PC update each clock cycle
    -- =========================================================================
    process(clk, reset)
        variable alu_result   : std_logic_vector(31 downto 0); -- ALU output
        variable branch_taken : std_logic;                     -- Branch condition
        variable next_pc      : unsigned(31 downto 0);         -- Next PC value
        variable do_trap      : std_logic;                     -- Exception flag
        variable trap_cause   : std_logic_vector(31 downto 0); -- Trap cause
        variable csr_rdata    : std_logic_vector(31 downto 0); -- CSR read value
        variable shamt        : integer range 0 to 31;         -- Shift amount
        variable load_result  : std_logic_vector(31 downto 0); -- Load data
        variable csr_wdata    : std_logic_vector(31 downto 0); -- CSR write data
    begin
        if reset = '1' then
            -- Active-high reset: clear all state
            pc <= (others => '0'); dmem_we_int <= '0'; dmem_re_int <= '0';
            regs <= (others => (others => '0'));
            csr_mstatus <= (others => '0'); csr_mie <= (others => '0');
            csr_mtvec <= (others => '0'); csr_mscratch <= (others => '0');
            csr_mepc <= (others => '0'); csr_mcause <= (others => '0');
            csr_mtval <= (others => '0'); csr_mip <= (others => '0');
            irq_out <= '0';

        elsif rising_edge(clk) then
            -- Defaults: no memory access, PC advances by 4, no trap
            dmem_we_int <= '0'; dmem_re_int <= '0'; dmem_wdata <= rs2_val; do_trap := '0';
            trap_cause := (others => '0'); next_pc := pc + 4;
            alu_result := (others => '0'); branch_taken := '0';
            irq_out <= '0';

            -- Update mip with incoming interrupt sources
            -- MTIP(bit7)=timer, MSIP(bit3)=software, MEIP(bit11)=external[0]
            csr_mip(7) <= timer_int; csr_mip(3) <= software_int; csr_mip(11) <= external_int(0);

            -- INTERRUPT CHECK: only when mstatus.MIE=1 and corresponding mie bit set
            if csr_mstatus(3) = '1' then
                if csr_mie(7) = '1' and timer_int = '1' then
                    do_trap := '1'; trap_cause := CAUSE_MTIMER;
                elsif csr_mie(3) = '1' and software_int = '1' then
                    do_trap := '1'; trap_cause := CAUSE_MSOFTWARE;
                end if;
            end if;

            if do_trap = '1' then
                -- TRAP: save PC to mepc, set cause, jump to mtvec, disable MIE
                csr_mepc <= std_logic_vector(pc);
                csr_mcause <= trap_cause;
                csr_mstatus(3) <= '0';  -- Clear MIE (disable further interrupts)
                csr_mstatus(7) <= '1';  -- Set MPIE (save previous MIE state)
                next_pc := unsigned(csr_mtvec);
                irq_out <= '1';

            else
                -- NORMAL EXECUTION: decode opcode and execute instruction
                case opcode is

                    -- R-TYPE: rd = rs1 OP rs2 (register-register ALU operations)
                    when OP_RTYPE =>
                        case funct3 is
                            when "000" => -- ADD (funct7=0) or SUB (funct7=0100000)
                                if funct7(5) = '1' then
                                    alu_result := std_logic_vector(signed(rs1_val) - signed(rs2_val));
                                else
                                    alu_result := std_logic_vector(signed(rs1_val) + signed(rs2_val));
                                end if;
                            when "001" => -- SLL: shift left logical by rs2[4:0]
                                shamt := to_integer(unsigned(rs2_val(4 downto 0)));
                                alu_result := std_logic_vector(shift_left(unsigned(rs1_val), shamt));
                            when "010" => -- SLT: set less than (signed)
                                if signed(rs1_val) < signed(rs2_val) then
                                    alu_result := x"00000001";
                                else
                                    alu_result := x"00000000";
                                end if;
                            when "011" => -- SLTU: set less than unsigned
                                if unsigned(rs1_val) < unsigned(rs2_val) then
                                    alu_result := x"00000001";
                                else
                                    alu_result := x"00000000";
                                end if;
                            when "100" => -- XOR: bitwise exclusive OR
                                alu_result := rs1_val xor rs2_val;
                            when "101" => -- SRL (funct7=0) or SRA (funct7=0100000)
                                shamt := to_integer(unsigned(rs2_val(4 downto 0)));
                                if funct7(5) = '1' then
                                    alu_result := std_logic_vector(shift_right(signed(rs1_val), shamt));
                                else
                                    alu_result := std_logic_vector(shift_right(unsigned(rs1_val), shamt));
                                end if;
                            when "110" => -- OR: bitwise OR
                                alu_result := rs1_val or rs2_val;
                            when "111" => -- AND: bitwise AND
                                alu_result := rs1_val and rs2_val;
                            when others => alu_result := (others => '0');
                        end case;
                        if rd /= 0 then regs(rd) <= alu_result; end if;

                    -- I-TYPE ALU: rd = rs1 OP imm (register-immediate operations)
                    when OP_ITYPE =>
                        case funct3 is
                            when "000" => alu_result := std_logic_vector(signed(rs1_val) + imm_i);       -- ADDI
                            when "010" => -- SLTI: set less than immediate (signed)
                                if signed(rs1_val) < imm_i then
                                    alu_result := x"00000001";
                                else
                                    alu_result := x"00000000";
                                end if;
                            when "011" => -- SLTIU: set less than immediate unsigned
                                if unsigned(rs1_val) < unsigned(imm_i) then
                                    alu_result := x"00000001";
                                else
                                    alu_result := x"00000000";
                                end if;
                            when "100" => alu_result := rs1_val xor std_logic_vector(imm_i);              -- XORI
                            when "110" => alu_result := rs1_val or std_logic_vector(imm_i);               -- ORI
                            when "111" => alu_result := rs1_val and std_logic_vector(imm_i);              -- ANDI
                            when "001" => alu_result := std_logic_vector(shift_left(unsigned(rs1_val), imm_sh)); -- SLLI
                            when "101" => -- SRLI or SRAI
                                if funct7(5) = '1' then
                                    alu_result := std_logic_vector(shift_right(signed(rs1_val), imm_sh)); -- SRAI
                                else
                                    alu_result := std_logic_vector(shift_right(unsigned(rs1_val), imm_sh)); -- SRLI
                                end if;
                            when others => alu_result := (others => '0');
                        end case;
                        if rd /= 0 then regs(rd) <= alu_result; end if;

                    -- LOAD: read from data memory with sign/zero extension
                    when OP_LOAD =>
                        dmem_re_int <= '1';
                        case funct3 is
                            when "000" => -- LB: load byte, sign-extend
                                load_result := (others => dmem_rdata_int(7));
                                load_result(7 downto 0) := dmem_rdata_int(7 downto 0);
                            when "001" => -- LH: load halfword, sign-extend
                                load_result := (others => dmem_rdata_int(15));
                                load_result(15 downto 0) := dmem_rdata_int(15 downto 0);
                            when "010" => load_result := dmem_rdata_int;  -- LW: load word
                            when "100" => -- LBU: load byte, zero-extend
                                load_result := (others => '0');
                                load_result(7 downto 0) := dmem_rdata_int(7 downto 0);
                            when "101" => -- LHU: load halfword, zero-extend
                                load_result := (others => '0');
                                load_result(15 downto 0) := dmem_rdata_int(15 downto 0);
                            when others => load_result := dmem_rdata_int;
                        end case;
                        if rd /= 0 then regs(rd) <= load_result; end if;

                    -- STORE: write to data memory with width selection
                    when OP_STORE =>
                        dmem_we_int <= '1';
                        case funct3 is
                            when "000" => dmem_wdata <= x"000000" & rs2_val(7 downto 0);  -- SB
                            when "001" => dmem_wdata <= x"0000" & rs2_val(15 downto 0);   -- SH
                            when "010" => dmem_wdata <= rs2_val;                          -- SW
                            when others => dmem_wdata <= rs2_val;
                        end case;

                    -- BRANCH: conditional PC change using B-type immediate
                    when OP_BRANCH =>
                        case funct3 is
                            when "000" => if rs1_val = rs2_val then branch_taken := '1'; end if;    -- BEQ
                            when "001" => if rs1_val /= rs2_val then branch_taken := '1'; end if;   -- BNE
                            when "100" => if signed(rs1_val) < signed(rs2_val) then branch_taken := '1'; end if; -- BLT
                            when "101" => if signed(rs1_val) >= signed(rs2_val) then branch_taken := '1'; end if; -- BGE
                            when "110" => if unsigned(rs1_val) < unsigned(rs2_val) then branch_taken := '1'; end if; -- BLTU
                            when "111" => if unsigned(rs1_val) >= unsigned(rs2_val) then branch_taken := '1'; end if; -- BGEU
                            when others => branch_taken := '0';
                        end case;
                        if branch_taken = '1' then next_pc := pc + unsigned(imm_b); end if;

                    -- JAL: save return address (PC+4) in rd, jump to PC + J-imm
                    when OP_JAL =>
                        if rd /= 0 then regs(rd) <= std_logic_vector(pc + 4); end if;
                        next_pc := pc + unsigned(imm_j);

                    -- JALR: save return address in rd, jump to (rs1 + imm) & ~1
                    when OP_JALR =>
                        if rd /= 0 then regs(rd) <= std_logic_vector(pc + 4); end if;
                        next_pc := unsigned(rs1_val) + unsigned(imm_i);
                        next_pc(0) := '0'; -- Clear LSB per RISC-V spec

                    -- LUI: load 20-bit immediate into upper bits of rd
                    when OP_LUI =>
                        if rd /= 0 then regs(rd) <= std_logic_vector(imm_u); end if;

                    -- AUIPC: rd = PC + (imm << 12) (PC-relative upper immediate)
                    when OP_AUIPC =>
                        if rd /= 0 then regs(rd) <= std_logic_vector(pc + unsigned(imm_u)); end if;

                    -- FENCE: memory barrier (NOP in this single-cycle model)
                    when OP_FENCE => null;

                    -- SYSTEM: ECALL, EBREAK, MRET, and CSR instructions
                    when OP_SYSTEM =>
                        case funct3 is
                            when "000" => -- ECALL / EBREAK / MRET (distinguished by imm field)
                                if imem_data(31 downto 20) = x"000" then
                                    -- ECALL: environment call triggers exception
                                    csr_mepc <= std_logic_vector(pc);
                                    csr_mcause <= CAUSE_ECALL;
                                    csr_mstatus(3) <= '0'; csr_mstatus(7) <= '1';
                                    next_pc := unsigned(csr_mtvec); irq_out <= '1';
                                elsif imem_data(31 downto 20) = x"001" then
                                    -- EBREAK: breakpoint triggers exception
                                    csr_mepc <= std_logic_vector(pc);
                                    csr_mcause <= CAUSE_EBREAK;
                                    csr_mstatus(3) <= '0'; csr_mstatus(7) <= '1';
                                    next_pc := unsigned(csr_mtvec); irq_out <= '1';
                                elsif imem_data(31 downto 20) = x"302" then
                                    -- MRET: return from trap, restore PC and MIE
                                    next_pc := unsigned(csr_mepc);
                                    csr_mstatus(3) <= csr_mstatus(7); -- MIE = MPIE
                                    csr_mstatus(7) <= '1';            -- MPIE = 1
                                end if;
                            when "001" | "010" | "011" => -- CSRRW / CSRRS / CSRRC
                                -- Read current CSR value using helper function
                                csr_rdata := csr_read(csr_addr, csr_mstatus, csr_mie,
                                    csr_mtvec, csr_mscratch, csr_mepc, csr_mcause,
                                    csr_mtval, csr_mip);
                                if rd /= 0 then regs(rd) <= csr_rdata; end if;
                                -- Compute write data based on operation type
                                case funct3 is
                                    when "001" => csr_wdata := rs1_val;                    -- CSRRW: write rs1
                                    when "010" => csr_wdata := csr_rdata or rs1_val;      -- CSRRS: set bits
                                    when "011" => csr_wdata := csr_rdata and not rs1_val; -- CSRRC: clear bits
                                    when others => csr_wdata := csr_rdata;
                                end case;
                                -- Write to the selected CSR
                                case csr_addr is
                                    when CSR_MSTATUS_ADDR  => csr_mstatus  <= csr_wdata;
                                    when CSR_MIE_ADDR      => csr_mie      <= csr_wdata;
                                    when CSR_MTVEC_ADDR    => csr_mtvec    <= csr_wdata;
                                    when CSR_MSCRATCH_ADDR => csr_mscratch <= csr_wdata;
                                    when CSR_MEPC_ADDR     => csr_mepc     <= csr_wdata;
                                    when CSR_MCAUSE_ADDR   => csr_mcause   <= csr_wdata;
                                    when CSR_MTVAL_ADDR    => csr_mtval    <= csr_wdata;
                                    when CSR_MIP_ADDR      => csr_mip      <= csr_wdata;
                                    when others => null;
                                end case;
                            when "101" | "110" | "111" => -- CSRRWI / CSRRSI / CSRRCI
                                -- Read current CSR value
                                csr_rdata := csr_read(csr_addr, csr_mstatus, csr_mie,
                                    csr_mtvec, csr_mscratch, csr_mepc, csr_mcause,
                                    csr_mtval, csr_mip);
                                if rd /= 0 then regs(rd) <= csr_rdata; end if;
                                -- Compute write data from 5-bit zero-extended immediate
                                case funct3 is
                                    when "101" => csr_wdata := x"000000" & "000" & csr_imm;                    -- CSRRWI
                                    when "110" => csr_wdata := csr_rdata or (x"000000" & "000" & csr_imm);      -- CSRRSI
                                    when "111" => csr_wdata := csr_rdata and not (x"000000" & "000" & csr_imm); -- CSRRCI
                                    when others => csr_wdata := csr_rdata;
                                end case;
                                -- Write to the selected CSR
                                case csr_addr is
                                    when CSR_MSTATUS_ADDR  => csr_mstatus  <= csr_wdata;
                                    when CSR_MIE_ADDR      => csr_mie      <= csr_wdata;
                                    when CSR_MTVEC_ADDR    => csr_mtvec    <= csr_wdata;
                                    when CSR_MSCRATCH_ADDR => csr_mscratch <= csr_wdata;
                                    when CSR_MEPC_ADDR     => csr_mepc     <= csr_wdata;
                                    when CSR_MCAUSE_ADDR   => csr_mcause   <= csr_wdata;
                                    when CSR_MTVAL_ADDR    => csr_mtval    <= csr_wdata;
                                    when CSR_MIP_ADDR      => csr_mip      <= csr_wdata;
                                    when others => null;
                                end case;
                            when others => null;
                        end case;

                    -- Unknown opcode: treat as NOP (advance PC by 4)
                    when others => null;
                end case;
            end if;

            -- Update Program Counter
            pc <= next_pc;
        end if;
    end process;

    -- Debug outputs: expose CSR values for external observation
    mepc_out   <= csr_mepc;
    mcause_out <= csr_mcause;

end architecture rtl;
