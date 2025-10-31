# VHDL Programming Cheatsheet
## Essential Techniques & Optimization Guide

---

## 🎯 Expert-Level VHDL Mastery Guide
### *Production-Ready Design Patterns & Advanced Techniques*

> **⚡ OBJECTIVE:** Master professional VHDL development for production-level FPGA applications

### 🏗️ **Progressive Learning Architecture**

#### **Foundation Level: Core Competencies**
- **VHDL Fundamentals:** Syntax mastery, entity/architecture patterns
- **Combinational Logic:** Complex logic circuits, encoders, decoders, multiplexers
- **Sequential Logic:** Flip-flops, latches, counters, shift registers
- **Data Handling:** Type systems, conversions, arithmetic operations

#### **Intermediate Level: System Design**
- **State Machine Mastery:** Complex FSM patterns, hierarchical states
- **Memory Architectures:** RAM, ROM, FIFO, cache controllers
- **Communication Protocols:** UART, SPI, I2C, custom protocols
- **System Integration:** Multi-module designs, interface protocols

#### **Advanced Level: Performance & Optimization**
- **Pipelining Techniques:** Multi-stage pipelines, hazard handling
- **DSP Implementation:** Digital filters, signal processing chains
- **Verification Mastery:** Advanced testbenches, assertion-based verification
- **Timing Optimization:** Critical path analysis, constraint management

#### **Expert Level: Production Systems**
- **CPU/Processor Design:** Instruction sets, pipeline architectures
- **System-on-Chip (SoC):** Bus protocols, peripheral integration
- **Real-World Constraints:** Power, area, timing optimization
- **Enterprise Patterns:** Scalable architectures, maintainable code

---

### 🎯 **Expert Competency Framework**

#### **Technical Mastery Requirements:**
- ✅ Design complex, multi-module FPGA systems
- ✅ Optimize for timing, area, and power constraints
- ✅ Implement advanced verification strategies
- ✅ Debug complex timing and functional issues
- ✅ Reverse engineer and analyze existing designs
- ✅ Scale designs for production environments

#### **Professional Skills Portfolio:**
- ✅ Write clean, maintainable, production-ready code
- ✅ Create comprehensive technical documentation
- ✅ Perform thorough design reviews and code analysis
- ✅ Apply industry-standard best practices
- ✅ Mentor junior developers and lead technical teams

#### **Production-Level Project Experience:**
- ✅ 50+ VHDL modules across different complexity levels
- ✅ 5+ complete systems with comprehensive verification
- ✅ 1+ enterprise-grade project demonstrating expertise
- ✅ Performance optimization case studies and benchmarks

---

### ⚡ **Professional Development Accelerators**

#### **Essential Tool Mastery:**
- **Synthesis Tools:** Quartus Prime, Vivado, Synplify Pro
- **Simulation:** ModelSim, QuestaSim, GHDL, Vivado Simulator
- **Debug & Analysis:** SignalTap, ChipScope, logic analyzers
- **Version Control:** Git workflows, branching strategies
- **Documentation:** Markdown, LaTeX, automated documentation

#### **Industry Resources & References:**
- **Standards:** IEEE 1076 (VHDL), IEEE 1364 (Verilog)
- **Books:** "Advanced FPGA Design" by Steve Kilts
- **Communities:** FPGA forums, professional networks
- **Conferences:** DVCon, FPL, FCCM for latest techniques

#### **Professional Mindset:**
- **Hardware-First Thinking:** Every construct maps to physical silicon
- **Optimization Focus:** Balance timing, area, power, and maintainability
- **Verification-Driven:** Test-first development, comprehensive coverage
- **Documentation Excellence:** Self-documenting code with clear intent

---

## 📚 Table of Contents
1. [🚀 Expert-Level VHDL Mastery Guide](#-expert-level-vhdl-mastery-guide)
2. [Basic Structure & Syntax](#basic-structure--syntax)
3. [Data Types & Objects](#data-types--objects)
4. [Operators & Expressions](#operators--expressions)
5. [Control Structures](#control-structures)
6. [Concurrent vs Sequential](#concurrent-vs-sequential)
7. [Clocking & Reset Strategies](#clocking--reset-strategies)
8. [State Machines](#state-machines)
9. [Memory & Storage](#memory--storage)
10. [Optimization Techniques](#optimization-techniques)
11. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
12. [Synthesis Guidelines](#synthesis-guidelines)
13. [Testbench Essentials](#testbench-essentials)

---

## 📏 Conventions: Reset Strategy & Preferred Libraries

## ⏱️ Clocking & Reset Strategies (Cross-links)
<a name="clock-reset-strategies"></a>
- Reset: use synchronous, active-low `rst_n` across modules; synchronize deassertion per domain.
- Multi-clock: apply domain-specific resets; use synchronizers/FIFOs/bridges for CDC.
- Timing: register I/O boundaries, constrain clocks, and budget fanout on shared interconnects.
- See also: Conventions, State Machines, Synthesis Guidelines, Testbench Essentials.

### Reset Strategy
- Use synchronous, active-low resets named `rst_n` for consistency and reliable synthesis.
- Gate all sequential logic resets inside a clocked process; avoid asynchronous resets unless interfacing with external hardware that requires them.
- For multi-clock designs, apply domain-specific resets and proper synchronization on release.

```vhdl
-- Reset/clock conventions
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

signal rst_n : std_logic;  -- Active-low synchronous reset
signal clk   : std_logic;
signal reg_a : unsigned(7 downto 0);

process(clk)
begin
    if rising_edge(clk) then
        if rst_n = '0' then
            reg_a <= (others => '0');
        else
            reg_a <= reg_a + 1;
        end if;
    end if;
end process;
```

### Preferred Libraries
- Prefer `ieee.std_logic_1164` and `ieee.numeric_std` for all synthesizable arithmetic.
- Use `unsigned`/`signed` types for math; convert explicitly with `to_unsigned`/`to_signed`.
- Avoid legacy `std_logic_arith` and `std_logic_unsigned` in production code; reserve for legacy testbenches only.

```vhdl
use ieee.numeric_std.all;
signal a_u : unsigned(15 downto 0);
signal b_s : signed(15 downto 0);
signal sum_s : signed(15 downto 0);

sum_s <= b_s + to_signed(1, b_s'length);
a_u   <= a_u + to_unsigned(1, a_u'length);
```

### Naming & Interface Conventions
- Signals: `clk`, `rst_n`, `valid`, `ready`, `data_in`, `data_out`.
- Use clear, intent-revealing names; keep widths and ranges explicit.
- For CDC, reference Clock/Reset strategy and employ synchronizers and FIFOs as appropriate.

See also: Clocking & Reset Strategies, State Machines, Synthesis Guidelines, Testbench Essentials.

## 🧾 Documentation Style for VHDL Modules

This repository adopts a documentation-first template for new module files under `src`: modules should contain commented documentation only (no functional VHDL code) unless explicitly authorized. Use the following structure, mirroring the style used in `barrel_shifter.vhd`:

- Project Overview
- Learning Objectives
- Step-by-Step Implementation Guide
- Common Design Considerations
- Design Verification Checklist
- Digital Design Context
- Physical Implementation Notes
- Advanced Concepts
- Simulation & Verification Notes
- Implementation Template (commented skeleton only)

Cross-reference core sections in this cheatsheet for deeper guidance: Basic Structure & Syntax, State Machines, Synthesis Guidelines, Testbench Essentials, and Reverse Engineering Techniques.

## 🏗️ Basic Structure & Syntax

### Entity Declaration
```vhdl
entity my_design is
    generic (
        DATA_WIDTH : integer := 8;
        ADDR_WIDTH : integer := 4
    );
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic;
        enable  : in  std_logic;
        data_in : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_out: out std_logic_vector(DATA_WIDTH-1 downto 0);
        valid   : out std_logic
    );
end entity my_design;
```

### Architecture Structure
```vhdl
architecture behavioral of my_design is
    -- Signal declarations
    signal internal_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal counter      : integer range 0 to 15;
    
    -- Type declarations
    type state_type is (IDLE, ACTIVE, DONE);
    signal current_state : state_type;
    
begin
    -- Concurrent statements
    data_out <= internal_reg;
    
    -- Process statements
    process(clk, reset_n)
    begin
        -- Sequential statements
    end process;
    
end architecture behavioral;
```

### Essential Libraries
```vhdl
library ieee;
use ieee.std_logic_1164.all;    -- Basic logic types
use ieee.numeric_std.all;       -- Arithmetic operations
use ieee.std_logic_arith.all;   -- Legacy (avoid in new designs)
use ieee.std_logic_unsigned.all; -- Legacy (avoid in new designs)

-- For file I/O in testbenches
use std.textio.all;
use ieee.std_logic_textio.all;
```

### Protocol BFMs: Avalon-MM and Wishbone
```vhdl
-- Avalon-MM Master BFM (write/read examples)
-- Signals: clk, address, writedata, readdata, write, read, waitreq

procedure avalon_write(
    signal clk       : in  std_logic;
    signal address   : out std_logic_vector;
    signal writedata : out std_logic_vector;
    signal write     : out std_logic;
    signal waitreq   : in  std_logic;
    constant addr    : in  unsigned;
    constant data    : in  std_logic_vector
) is
begin
    wait until rising_edge(clk);
    address   <= std_logic_vector(addr);
    writedata <= data;
    write     <= '1';
    -- Wait while slave asserts waitreq
    while waitreq = '1' loop
        wait until rising_edge(clk);
    end loop;
    write <= '0';
end procedure;

procedure avalon_read(
    signal clk       : in  std_logic;
    signal address   : out std_logic_vector;
    signal read      : out std_logic;
    signal waitreq   : in  std_logic;
    signal readdata  : in  std_logic_vector;
    constant addr    : in  unsigned;
    out data_o       : std_logic_vector
) is
begin
    wait until rising_edge(clk);
    address <= std_logic_vector(addr);
    read    <= '1';
    while waitreq = '1' loop
        wait until rising_edge(clk);
    end loop;
    read   <= '0';
    data_o := readdata;
end procedure;

-- Example usage in stimulus
-- avalon_write(clk, address, writedata, write, waitreq, to_unsigned(16, address'length), x"DEADBEEF");
-- avalon_read(clk, address, read, waitreq, readdata, to_unsigned(16, address'length), rd_value);

-- Wishbone Master BFM (write/read examples)
-- Signals: clk_i, adr_i, dat_i, dat_o, we_i, cyc_i, stb_i, ack_o, err_o

procedure wb_write(
    signal clk_i   : in  std_logic;
    signal adr_i   : out std_logic_vector;
    signal dat_i   : out std_logic_vector;
    signal we_i    : out std_logic;
    signal cyc_i   : out std_logic;
    signal stb_i   : out std_logic;
    signal ack_o   : in  std_logic;
    signal err_o   : in  std_logic;
    constant addr  : in  unsigned;
    constant data  : in  std_logic_vector
) is
begin
    wait until rising_edge(clk_i);
    adr_i <= std_logic_vector(addr);
    dat_i <= data;
    we_i  <= '1';
    cyc_i <= '1';
    stb_i <= '1';
    -- Wait for acknowledge
    while ack_o = '0' loop
        wait until rising_edge(clk_i);
        assert err_o = '0' report "Wishbone error during write" severity error;
    end loop;
    cyc_i <= '0';
    stb_i <= '0';
    we_i  <= '0';
end procedure;

procedure wb_read(
    signal clk_i   : in  std_logic;
    signal adr_i   : out std_logic_vector;
    signal dat_o   : in  std_logic_vector;
    signal we_i    : out std_logic;
    signal cyc_i   : out std_logic;
    signal stb_i   : out std_logic;
    signal ack_o   : in  std_logic;
    signal err_o   : in  std_logic;
    constant addr  : in  unsigned;
    out data_o     : std_logic_vector
) is
begin
    wait until rising_edge(clk_i);
    adr_i <= std_logic_vector(addr);
    we_i  <= '0';
    cyc_i <= '1';
    stb_i <= '1';
    while ack_o = '0' loop
        wait until rising_edge(clk_i);
        assert err_o = '0' report "Wishbone error during read" severity error;
    end loop;
    data_o := dat_o;
    cyc_i <= '0';
    stb_i <= '0';
end procedure;
```

Notes:
- Adapt signal names to match your DUT or Platform Designer/Qsys system.
- Keep reset synchronous (`rst_n`) and ensure any BFMs honor deassertion synchronization.
- For Avalon-ST pipelines, add backpressure handling (`valid`/`ready`).

---

## 🔢 Data Types & Objects

### Standard Logic Types
```vhdl
-- Basic types
signal bit_signal     : bit;           -- '0' or '1' only
signal logic_signal   : std_logic;     -- '0','1','Z','X','-','U','W','L','H'
signal logic_vector   : std_logic_vector(7 downto 0);

-- Preferred for arithmetic
signal unsigned_val   : unsigned(7 downto 0);
signal signed_val     : signed(7 downto 0);
signal integer_val    : integer range 0 to 255;
```

### Custom Types
```vhdl
-- Enumerated types
type cpu_state is (FETCH, DECODE, EXECUTE, WRITEBACK);
signal cpu_current_state : cpu_state;

-- Array types
type memory_array is array (0 to 255) of std_logic_vector(7 downto 0);
signal ram : memory_array;

-- Record types
type instruction_type is record
    opcode  : std_logic_vector(3 downto 0);
    operand : std_logic_vector(7 downto 0);
    valid   : std_logic;
end record;
signal instruction : instruction_type;
```

### Signal vs Variable
```vhdl
-- SIGNALS (use <= operator)
signal reg_signal : std_logic_vector(7 downto 0);

process(clk)
begin
    if rising_edge(clk) then
        reg_signal <= input_data;  -- Scheduled assignment
    end if;
end process;

-- VARIABLES (use := operator)
process(clk)
    variable temp_var : std_logic_vector(7 downto 0);
begin
    if rising_edge(clk) then
        temp_var := input_data;    -- Immediate assignment
        output_data <= temp_var;   -- Use updated value
    end if;
end process;
```

---

## 🎯 Variable Declaration & Assignment Strategies
### *Production-Level Design Patterns by Project Type*

### 🏭 **Industrial Control Systems**
```vhdl
-- State machine with error handling
type control_state is (INIT, IDLE, RUNNING, ERROR, SHUTDOWN);
signal current_state, next_state : control_state;

-- Safety-critical signals with redundancy
signal emergency_stop     : std_logic;
signal emergency_stop_n   : std_logic;  -- Inverted for safety
signal system_enable      : std_logic;
signal fault_detected     : std_logic_vector(7 downto 0);

-- Process control variables
process(clk, reset_n)
    variable error_count    : integer range 0 to 255;
    variable timeout_counter: unsigned(15 downto 0);
    variable safety_check   : std_logic;
begin
    if reset_n = '0' then
        current_state <= INIT;
        error_count := 0;
        timeout_counter := (others => '0');
    elsif rising_edge(clk) then
        -- Safety checks first
        safety_check := emergency_stop and (not emergency_stop_n);
        
        if safety_check = '0' then
            current_state <= ERROR;
            error_count := error_count + 1;
        else
            current_state <= next_state;
        end if;
    end if;
end process;
```

### 🚗 **Automotive Electronics**
```vhdl
-- CAN bus controller with timing constraints
signal can_tx_data      : std_logic_vector(63 downto 0);
signal can_rx_data      : std_logic_vector(63 downto 0);
signal can_bit_timing   : unsigned(7 downto 0);
signal can_error_flags  : std_logic_vector(2 downto 0);

-- Engine control variables (fixed-point arithmetic)
process(clk, reset_n)
    variable throttle_position : unsigned(11 downto 0);  -- 12-bit ADC
    variable engine_rpm        : unsigned(15 downto 0);  -- RPM counter
    variable fuel_injection    : unsigned(9 downto 0);   -- PWM duty cycle
    variable ignition_timing   : signed(7 downto 0);     -- Advance/retard
begin
    if reset_n = '0' then
        throttle_position := (others => '0');
        engine_rpm := (others => '0');
        fuel_injection := (others => '0');
        ignition_timing := (others => '0');
    elsif rising_edge(clk) then
        -- Real-time calculations with bounds checking
        if throttle_position > 4000 then  -- Max throttle limit
            fuel_injection := to_unsigned(1023, 10);  -- Max fuel
        else
            fuel_injection := throttle_position(11 downto 2);
        end if;
    end if;
end process;
```

### 📡 **Communication Systems & Protocol Implementations**

## 🔌 **I2C Protocol Implementation**
```vhdl
-- I2C Master Controller with Multi-Device Support
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is
    generic (
        CLK_FREQ    : integer := 50_000_000;  -- System clock frequency
        I2C_FREQ    : integer := 400_000      -- I2C clock frequency (400kHz)
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        -- Control interface
        start       : in  std_logic;
        stop        : in  std_logic;
        read_write  : in  std_logic;  -- '1' for read, '0' for write
        slave_addr  : in  std_logic_vector(6 downto 0);
        data_in     : in  std_logic_vector(7 downto 0);
        data_out    : out std_logic_vector(7 downto 0);
        busy        : out std_logic;
        ack_error   : out std_logic;
        -- I2C bus
        scl         : inout std_logic;
        sda         : inout std_logic
    );
end entity i2c_master;

architecture rtl of i2c_master is
    -- I2C timing constants
    constant CLK_DIVIDER : integer := CLK_FREQ / (4 * I2C_FREQ);
    
    -- State machine
    type i2c_state_type is (IDLE, START_COND, ADDR_BYTE, ADDR_ACK, 
                           DATA_BYTE, DATA_ACK, STOP_COND, ERROR);
    signal state : i2c_state_type;
    
    -- Internal signals
    signal scl_clk      : std_logic;
    signal scl_enable   : std_logic;
    signal sda_int      : std_logic;
    signal sda_enable   : std_logic;
    signal bit_counter  : integer range 0 to 7;
    signal byte_buffer  : std_logic_vector(7 downto 0);
    signal ack_bit      : std_logic;
    
    -- Clock divider for I2C timing
    signal clk_div_counter : integer range 0 to CLK_DIVIDER-1;
    signal clk_div_pulse   : std_logic;
    
begin
    -- Clock divider process
    clock_divider: process(clk, reset_n)
    begin
        if reset_n = '0' then
            clk_div_counter <= 0;
            clk_div_pulse <= '0';
        elsif rising_edge(clk) then
            if clk_div_counter = CLK_DIVIDER-1 then
                clk_div_counter <= 0;
                clk_div_pulse <= '1';
            else
                clk_div_counter <= clk_div_counter + 1;
                clk_div_pulse <= '0';
            end if;
        end if;
    end process;
    
    -- I2C state machine
    i2c_fsm: process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            bit_counter <= 0;
            byte_buffer <= (others => '0');
            busy <= '0';
            ack_error <= '0';
            scl_enable <= '1';
            sda_enable <= '1';
            sda_int <= '1';
        elsif rising_edge(clk) then
            if clk_div_pulse = '1' then
                case state is
                    when IDLE =>
                        busy <= '0';
                        scl_enable <= '1';
                        sda_enable <= '1';
                        sda_int <= '1';
                        if start = '1' then
                            state <= START_COND;
                            busy <= '1';
                        end if;
                    
                    when START_COND =>
                        sda_int <= '0';  -- Start condition: SDA low while SCL high
                        byte_buffer <= slave_addr & read_write;
                        bit_counter <= 7;
                        state <= ADDR_BYTE;
                    
                    when ADDR_BYTE =>
                        sda_int <= byte_buffer(bit_counter);
                        if bit_counter = 0 then
                            state <= ADDR_ACK;
                        else
                            bit_counter <= bit_counter - 1;
                        end if;
                    
                    when ADDR_ACK =>
                        sda_enable <= '0';  -- Release SDA for ACK
                        if sda = '0' then   -- ACK received
                            if read_write = '1' then
                                state <= DATA_BYTE;
                                bit_counter <= 7;
                            else
                                byte_buffer <= data_in;
                                state <= DATA_BYTE;
                                bit_counter <= 7;
                            end if;
                        else
                            ack_error <= '1';
                            state <= ERROR;
                        end if;
                    
                    when DATA_BYTE =>
                        if read_write = '1' then
                            -- Read operation
                            byte_buffer(bit_counter) <= sda;
                        else
                            -- Write operation
                            sda_int <= byte_buffer(bit_counter);
                        end if;
                        
                        if bit_counter = 0 then
                            state <= DATA_ACK;
                        else
                            bit_counter <= bit_counter - 1;
                        end if;
                    
                    when DATA_ACK =>
                        if read_write = '1' then
                            sda_int <= '1';  -- NACK for read completion
                            data_out <= byte_buffer;
                        else
                            sda_enable <= '0';  -- Release for ACK check
                        end if;
                        state <= STOP_COND;
                    
                    when STOP_COND =>
                        sda_int <= '0';
                        -- Generate stop condition in next cycle
                        sda_int <= '1';  -- Stop condition: SDA high while SCL high
                        state <= IDLE;
                    
                    when ERROR =>
                        if stop = '1' then
                            state <= STOP_COND;
                            ack_error <= '0';
                        end if;
                end case;
            end if;
        end if;
    end process;
    
    -- I2C bus control
    scl <= '0' when scl_enable = '0' else 'Z';
    sda <= sda_int when sda_enable = '1' else 'Z';
    
end architecture rtl;
```

---

# 🏭 **Manufacturer-Specific IP Processor Implementations**

## 🔵 **Intel/Altera IP Processors**

### **Nios II Soft Processor Integration**
```vhdl
-- Nios II System Integration with Custom Peripherals
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nios_ii_system is
    port (
        clk_50          : in  std_logic;
        reset_n         : in  std_logic;
        -- SDRAM Interface
        sdram_addr      : out std_logic_vector(12 downto 0);
        sdram_ba        : out std_logic_vector(1 downto 0);
        sdram_cas_n     : out std_logic;
        sdram_cke       : out std_logic;
        sdram_clk       : out std_logic;
        sdram_cs_n      : out std_logic;
        sdram_dq        : inout std_logic_vector(15 downto 0);
        sdram_dqm       : out std_logic_vector(1 downto 0);
        sdram_ras_n     : out std_logic;
        sdram_we_n      : out std_logic;
        -- UART Interface
        uart_rxd        : in  std_logic;
        uart_txd        : out std_logic;
        -- GPIO
        gpio_export     : inout std_logic_vector(31 downto 0);
        -- Custom Avalon-MM Slave
        custom_address  : in  std_logic_vector(7 downto 0);
        custom_read     : in  std_logic;
        custom_write    : in  std_logic;
        custom_writedata: in  std_logic_vector(31 downto 0);
        custom_readdata : out std_logic_vector(31 downto 0);
        custom_waitrequest : out std_logic
    );
end entity nios_ii_system;

architecture rtl of nios_ii_system is
    -- Nios II System Component
    component nios_ii_gen2_0 is
        port (
            clk_clk                    : in  std_logic;
            reset_reset_n              : in  std_logic;
            sdram_controller_addr      : out std_logic_vector(12 downto 0);
            sdram_controller_ba        : out std_logic_vector(1 downto 0);
            sdram_controller_cas_n     : out std_logic;
            sdram_controller_cke       : out std_logic;
            sdram_controller_cs_n      : out std_logic;
            sdram_controller_dq        : inout std_logic_vector(15 downto 0);
            sdram_controller_dqm       : out std_logic_vector(1 downto 0);
            sdram_controller_ras_n     : out std_logic;
            sdram_controller_we_n      : out std_logic;
            uart_0_external_connection_rxd : in  std_logic;
            uart_0_external_connection_txd : out std_logic;
            pio_0_external_connection_export : inout std_logic_vector(31 downto 0);
            custom_peripheral_address  : in  std_logic_vector(7 downto 0);
            custom_peripheral_read     : in  std_logic;
            custom_peripheral_write    : in  std_logic;
            custom_peripheral_writedata: in  std_logic_vector(31 downto 0);
            custom_peripheral_readdata : out std_logic_vector(31 downto 0);
            custom_peripheral_waitrequest : out std_logic
        );
    end component;

    -- PLL Component for Clock Generation
    component pll_50_to_100 is
        port (
            inclk0 : in  std_logic;
            c0     : out std_logic;  -- 100 MHz for SDRAM
            c1     : out std_logic;  -- 50 MHz for system
            locked : out std_logic
        );
    end component;

    signal clk_100      : std_logic;
    signal clk_sys      : std_logic;
    signal pll_locked   : std_logic;
    signal system_reset : std_logic;

begin
    -- PLL Instance
    pll_inst : pll_50_to_100
        port map (
            inclk0 => clk_50,
            c0     => clk_100,
            c1     => clk_sys,
            locked => pll_locked
        );

    system_reset <= not (reset_n and pll_locked);
    sdram_clk <= clk_100;

    -- Nios II System Instance
    nios_system : nios_ii_gen2_0
        port map (
            clk_clk                    => clk_sys,
            reset_reset_n              => not system_reset,
            sdram_controller_addr      => sdram_addr,
            sdram_controller_ba        => sdram_ba,
            sdram_controller_cas_n     => sdram_cas_n,
            sdram_controller_cke       => sdram_cke,
            sdram_controller_cs_n      => sdram_cs_n,
            sdram_controller_dq        => sdram_dq,
            sdram_controller_dqm       => sdram_dqm,
            sdram_controller_ras_n     => sdram_ras_n,
            sdram_controller_we_n      => sdram_we_n,
            uart_0_external_connection_rxd => uart_rxd,
            uart_0_external_connection_txd => uart_txd,
            pio_0_external_connection_export => gpio_export,
            custom_peripheral_address  => custom_address,
            custom_peripheral_read     => custom_read,
            custom_peripheral_write    => custom_write,
            custom_peripheral_writedata=> custom_writedata,
            custom_peripheral_readdata => custom_readdata,
            custom_peripheral_waitrequest => custom_waitrequest
        );

end architecture rtl;
```

### **Intel RISC-V Implementation**
```vhdl
-- Intel RISC-V Core Integration
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity intel_riscv_system is
    generic (
        XLEN : integer := 32  -- 32-bit or 64-bit RISC-V
    );
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;
        -- Instruction Memory Interface
        imem_addr       : out std_logic_vector(XLEN-1 downto 0);
        imem_rdata      : in  std_logic_vector(31 downto 0);
        imem_req        : out std_logic;
        imem_gnt        : in  std_logic;
        imem_rvalid     : in  std_logic;
        -- Data Memory Interface
        dmem_addr       : out std_logic_vector(XLEN-1 downto 0);
        dmem_wdata      : out std_logic_vector(XLEN-1 downto 0);
        dmem_rdata      : in  std_logic_vector(XLEN-1 downto 0);
        dmem_we         : out std_logic;
        dmem_be         : out std_logic_vector((XLEN/8)-1 downto 0);
        dmem_req        : out std_logic;
        dmem_gnt        : in  std_logic;
        dmem_rvalid     : in  std_logic;
        -- Interrupt Interface
        irq_external    : in  std_logic;
        irq_timer       : in  std_logic;
        irq_software    : in  std_logic;
        -- Debug Interface
        debug_req       : in  std_logic;
        debug_gnt       : out std_logic;
        debug_rvalid    : out std_logic;
        debug_addr      : in  std_logic_vector(14 downto 0);
        debug_we        : in  std_logic;
        debug_wdata     : in  std_logic_vector(XLEN-1 downto 0);
        debug_rdata     : out std_logic_vector(XLEN-1 downto 0)
    );
end entity intel_riscv_system;

architecture rtl of intel_riscv_system is
    -- RISC-V Core Component (Intel IP)
    component riscv_core is
        generic (
            RV32E          : integer := 0;
            RV32M          : integer := 1;
            RV32C          : integer := 0
        );
        port (
            clk_i          : in  std_logic;
            rst_ni         : in  std_logic;
            -- Instruction Memory Interface
            instr_addr_o   : out std_logic_vector(31 downto 0);
            instr_rdata_i  : in  std_logic_vector(31 downto 0);
            instr_req_o    : out std_logic;
            instr_gnt_i    : in  std_logic;
            instr_rvalid_i : in  std_logic;
            -- Data Memory Interface
            data_addr_o    : out std_logic_vector(31 downto 0);
            data_wdata_o   : out std_logic_vector(31 downto 0);
            data_rdata_i   : in  std_logic_vector(31 downto 0);
            data_we_o      : out std_logic;
            data_be_o      : out std_logic_vector(3 downto 0);
            data_req_o     : out std_logic;
            data_gnt_i     : in  std_logic;
            data_rvalid_i  : in  std_logic;
            -- Interrupt Interface
            irq_i          : in  std_logic_vector(31 downto 0);
            irq_ack_o      : out std_logic;
            irq_id_o       : out std_logic_vector(4 downto 0);
            -- Debug Interface
            debug_req_i    : in  std_logic;
            debug_gnt_o    : out std_logic;
            debug_rvalid_o : out std_logic;
            debug_addr_i   : in  std_logic_vector(14 downto 0);
            debug_we_i     : in  std_logic;
            debug_wdata_i  : in  std_logic_vector(31 downto 0);
            debug_rdata_o  : out std_logic_vector(31 downto 0)
        );
    end component;

    signal irq_vector : std_logic_vector(31 downto 0);

begin
    -- Interrupt Vector Assembly
    irq_vector <= (0 => irq_software, 7 => irq_timer, 11 => irq_external, others => '0');

    -- RISC-V Core Instance
    riscv_inst : riscv_core
        generic map (
            RV32E => 0,  -- Full register set
            RV32M => 1,  -- Multiply/Divide extension
            RV32C => 0   -- Compressed instructions disabled
        )
        port map (
            clk_i          => clk,
            rst_ni         => reset_n,
            instr_addr_o   => imem_addr,
            instr_rdata_i  => imem_rdata,
            instr_req_o    => imem_req,
            instr_gnt_i    => imem_gnt,
            instr_rvalid_i => imem_rvalid,
            data_addr_o    => dmem_addr,
            data_wdata_o   => dmem_wdata,
            data_rdata_i   => dmem_rdata,
            data_we_o      => dmem_we,
            data_be_o      => dmem_be,
            data_req_o     => dmem_req,
            data_gnt_i     => dmem_gnt,
            data_rvalid_i  => dmem_rvalid,
            irq_i          => irq_vector,
            irq_ack_o      => open,
            irq_id_o       => open,
            debug_req_i    => debug_req,
            debug_gnt_o    => debug_gnt,
            debug_rvalid_o => debug_rvalid,
            debug_addr_i   => debug_addr,
            debug_we_i     => debug_we,
            debug_wdata_i  => debug_wdata,
            debug_rdata_o  => debug_rdata
        );

end architecture rtl;
```

## 🟠 **Xilinx IP Processors**

### **MicroBlaze Soft Processor System**
```vhdl
-- MicroBlaze System with AXI4-Lite Peripherals
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity microblaze_system is
    port (
        sys_clk_p       : in  std_logic;
        sys_clk_n       : in  std_logic;
        reset           : in  std_logic;
        -- DDR3 Interface
        ddr3_addr       : out std_logic_vector(13 downto 0);
        ddr3_ba         : out std_logic_vector(2 downto 0);
        ddr3_cas_n      : out std_logic;
        ddr3_ck_n       : out std_logic_vector(0 downto 0);
        ddr3_ck_p       : out std_logic_vector(0 downto 0);
        ddr3_cke        : out std_logic_vector(0 downto 0);
        ddr3_cs_n       : out std_logic_vector(0 downto 0);
        ddr3_dm         : out std_logic_vector(1 downto 0);
        ddr3_dq         : inout std_logic_vector(15 downto 0);
        ddr3_dqs_n      : inout std_logic_vector(1 downto 0);
        ddr3_dqs_p      : inout std_logic_vector(1 downto 0);
        ddr3_odt        : out std_logic_vector(0 downto 0);
        ddr3_ras_n      : out std_logic;
        ddr3_reset_n    : out std_logic;
        ddr3_we_n       : out std_logic;
        -- UART Interface
        uart_rxd        : in  std_logic;
        uart_txd        : out std_logic;
        -- GPIO
        gpio_tri_io     : inout std_logic_vector(31 downto 0);
        -- Custom AXI4-Lite Interface
        custom_axi_aclk    : out std_logic;
        custom_axi_aresetn : out std_logic;
        custom_axi_awaddr  : out std_logic_vector(31 downto 0);
        custom_axi_awprot  : out std_logic_vector(2 downto 0);
        custom_axi_awvalid : out std_logic;
        custom_axi_awready : in  std_logic;
        custom_axi_wdata   : out std_logic_vector(31 downto 0);
        custom_axi_wstrb   : out std_logic_vector(3 downto 0);
        custom_axi_wvalid  : out std_logic;
        custom_axi_wready  : in  std_logic;
        custom_axi_bresp   : in  std_logic_vector(1 downto 0);
        custom_axi_bvalid  : in  std_logic;
        custom_axi_bready  : out std_logic;
        custom_axi_araddr  : out std_logic_vector(31 downto 0);
        custom_axi_arprot  : out std_logic_vector(2 downto 0);
        custom_axi_arvalid : out std_logic;
        custom_axi_arready : in  std_logic;
        custom_axi_rdata   : in  std_logic_vector(31 downto 0);
        custom_axi_rresp   : in  std_logic_vector(1 downto 0);
        custom_axi_rvalid  : in  std_logic;
        custom_axi_rready  : out std_logic
    );
end entity microblaze_system;

architecture rtl of microblaze_system is
    -- MicroBlaze System Component (Generated from Vivado)
    component microblaze_mcs_0 is
        port (
            Clk             : in  std_logic;
            Reset           : in  std_logic;
            -- DDR3 Interface
            DDR3_addr       : out std_logic_vector(13 downto 0);
            DDR3_ba         : out std_logic_vector(2 downto 0);
            DDR3_cas_n      : out std_logic;
            DDR3_ck_n       : out std_logic_vector(0 downto 0);
            DDR3_ck_p       : out std_logic_vector(0 downto 0);
            DDR3_cke        : out std_logic_vector(0 downto 0);
            DDR3_cs_n       : out std_logic_vector(0 downto 0);
            DDR3_dm         : out std_logic_vector(1 downto 0);
            DDR3_dq         : inout std_logic_vector(15 downto 0);
            DDR3_dqs_n      : inout std_logic_vector(1 downto 0);
            DDR3_dqs_p      : inout std_logic_vector(1 downto 0);
            DDR3_odt        : out std_logic_vector(0 downto 0);
            DDR3_ras_n      : out std_logic;
            DDR3_reset_n    : out std_logic;
            DDR3_we_n       : out std_logic;
            -- UART Interface
            UART_rxd        : in  std_logic;
            UART_txd        : out std_logic;
            -- GPIO Interface
            GPIO_tri_io     : inout std_logic_vector(31 downto 0);
            -- AXI4-Lite Master Interface
            M_AXI_ACLK      : out std_logic;
            M_AXI_ARESETN   : out std_logic;
            M_AXI_AWADDR    : out std_logic_vector(31 downto 0);
            M_AXI_AWPROT    : out std_logic_vector(2 downto 0);
            M_AXI_AWVALID   : out std_logic;
            M_AXI_AWREADY   : in  std_logic;
            M_AXI_WDATA     : out std_logic_vector(31 downto 0);
            M_AXI_WSTRB     : out std_logic_vector(3 downto 0);
            M_AXI_WVALID    : out std_logic;
            M_AXI_WREADY    : in  std_logic;
            M_AXI_BRESP     : in  std_logic_vector(1 downto 0);
            M_AXI_BVALID    : in  std_logic;
            M_AXI_BREADY    : out std_logic;
            M_AXI_ARADDR    : out std_logic_vector(31 downto 0);
            M_AXI_ARPROT    : out std_logic_vector(2 downto 0);
            M_AXI_ARVALID   : out std_logic;
            M_AXI_ARREADY   : in  std_logic;
            M_AXI_RDATA     : in  std_logic_vector(31 downto 0);
            M_AXI_RRESP     : in  std_logic_vector(1 downto 0);
            M_AXI_RVALID    : in  std_logic;
            M_AXI_RREADY    : out std_logic
        );
    end component;

    -- Clock Management
    component clk_wiz_0 is
        port (
            clk_out1 : out std_logic;
            reset    : in  std_logic;
            locked   : out std_logic;
            clk_in1_p: in  std_logic;
            clk_in1_n: in  std_logic
        );
    end component;

    signal clk_100      : std_logic;
    signal clk_locked   : std_logic;
    signal sys_reset    : std_logic;

begin
    -- Clock Wizard Instance
    clk_gen : clk_wiz_0
        port map (
            clk_out1  => clk_100,
            reset     => reset,
            locked    => clk_locked,
            clk_in1_p => sys_clk_p,
            clk_in1_n => sys_clk_n
        );

    sys_reset <= reset or not clk_locked;

    -- MicroBlaze System Instance
    mb_system : microblaze_mcs_0
        port map (
            Clk           => clk_100,
            Reset         => sys_reset,
            DDR3_addr     => ddr3_addr,
            DDR3_ba       => ddr3_ba,
            DDR3_cas_n    => ddr3_cas_n,
            DDR3_ck_n     => ddr3_ck_n,
            DDR3_ck_p     => ddr3_ck_p,
            DDR3_cke      => ddr3_cke,
            DDR3_cs_n     => ddr3_cs_n,
            DDR3_dm       => ddr3_dm,
            DDR3_dq       => ddr3_dq,
            DDR3_dqs_n    => ddr3_dqs_n,
            DDR3_dqs_p    => ddr3_dqs_p,
            DDR3_odt      => ddr3_odt,
            DDR3_ras_n    => ddr3_ras_n,
            DDR3_reset_n  => ddr3_reset_n,
            DDR3_we_n     => ddr3_we_n,
            UART_rxd      => uart_rxd,
            UART_txd      => uart_txd,
            GPIO_tri_io   => gpio_tri_io,
            M_AXI_ACLK    => custom_axi_aclk,
            M_AXI_ARESETN => custom_axi_aresetn,
            M_AXI_AWADDR  => custom_axi_awaddr,
            M_AXI_AWPROT  => custom_axi_awprot,
            M_AXI_AWVALID => custom_axi_awvalid,
            M_AXI_AWREADY => custom_axi_awready,
            M_AXI_WDATA   => custom_axi_wdata,
            M_AXI_WSTRB   => custom_axi_wstrb,
            M_AXI_WVALID  => custom_axi_wvalid,
            M_AXI_WREADY  => custom_axi_wready,
            M_AXI_BRESP   => custom_axi_bresp,
            M_AXI_BVALID  => custom_axi_bvalid,
            M_AXI_BREADY  => custom_axi_bready,
            M_AXI_ARADDR  => custom_axi_araddr,
            M_AXI_ARPROT  => custom_axi_arprot,
            M_AXI_ARVALID => custom_axi_arvalid,
            M_AXI_ARREADY => custom_axi_arready,
            M_AXI_RDATA   => custom_axi_rdata,
            M_AXI_RRESP   => custom_axi_rresp,
            M_AXI_RVALID  => custom_axi_rvalid,
            M_AXI_RREADY  => custom_axi_rready
        );

end architecture rtl;
```

### **Zynq ARM + FPGA Integration**
```vhdl
-- Zynq-7000 ARM Cortex-A9 + FPGA Logic Integration
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity zynq_arm_fpga_system is
    port (
        -- PS-PL Interface (Zynq Processing System to Programmable Logic)
        FCLK_CLK0       : out std_logic;
        FCLK_RESET0_N   : out std_logic;
        -- AXI4 GP0 Master Interface (PS to PL)
        M_AXI_GP0_ACLK    : in  std_logic;
        M_AXI_GP0_ARESETN : in  std_logic;
        M_AXI_GP0_AWADDR  : out std_logic_vector(31 downto 0);
        M_AXI_GP0_AWPROT  : out std_logic_vector(2 downto 0);
        M_AXI_GP0_AWVALID : out std_logic;
        M_AXI_GP0_AWREADY : in  std_logic;
        M_AXI_GP0_WDATA   : out std_logic_vector(31 downto 0);
        M_AXI_GP0_WSTRB   : out std_logic_vector(3 downto 0);
        M_AXI_GP0_WVALID  : out std_logic;
        M_AXI_GP0_WREADY  : in  std_logic;
        M_AXI_GP0_BRESP   : in  std_logic_vector(1 downto 0);
        M_AXI_GP0_BVALID  : in  std_logic;
        M_AXI_GP0_BREADY  : out std_logic;
        M_AXI_GP0_ARADDR  : out std_logic_vector(31 downto 0);
        M_AXI_GP0_ARPROT  : out std_logic_vector(2 downto 0);
        M_AXI_GP0_ARVALID : out std_logic;
        M_AXI_GP0_ARREADY : in  std_logic;
        M_AXI_GP0_RDATA   : in  std_logic_vector(31 downto 0);
        M_AXI_GP0_RRESP   : in  std_logic_vector(1 downto 0);
        M_AXI_GP0_RVALID  : in  std_logic;
        M_AXI_GP0_RREADY  : out std_logic;
        -- AXI4 HP0 Slave Interface (PL to PS)
        S_AXI_HP0_ACLK    : in  std_logic;
        S_AXI_HP0_ARESETN : in  std_logic;
        S_AXI_HP0_AWADDR  : in  std_logic_vector(31 downto 0);
        S_AXI_HP0_AWBURST : in  std_logic_vector(1 downto 0);
        S_AXI_HP0_AWCACHE : in  std_logic_vector(3 downto 0);
        S_AXI_HP0_AWID    : in  std_logic_vector(5 downto 0);
        S_AXI_HP0_AWLEN   : in  std_logic_vector(3 downto 0);
        S_AXI_HP0_AWLOCK  : in  std_logic_vector(1 downto 0);
        S_AXI_HP0_AWPROT  : in  std_logic_vector(2 downto 0);
        S_AXI_HP0_AWQOS   : in  std_logic_vector(3 downto 0);
        S_AXI_HP0_AWREADY : out std_logic;
        S_AXI_HP0_AWSIZE  : in  std_logic_vector(2 downto 0);
        S_AXI_HP0_AWVALID : in  std_logic;
        S_AXI_HP0_WDATA   : in  std_logic_vector(63 downto 0);
        S_AXI_HP0_WID     : in  std_logic_vector(5 downto 0);
        S_AXI_HP0_WLAST   : in  std_logic;
        S_AXI_HP0_WREADY  : out std_logic;
        S_AXI_HP0_WSTRB   : in  std_logic_vector(7 downto 0);
        S_AXI_HP0_WVALID  : in  std_logic;
        S_AXI_HP0_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_HP0_BID     : out std_logic_vector(5 downto 0);
        S_AXI_HP0_BREADY  : in  std_logic;
        S_AXI_HP0_BVALID  : out std_logic;
        -- External Interfaces
        gpio_tri_io       : inout std_logic_vector(31 downto 0);
        uart_txd          : out std_logic;
        uart_rxd          : in  std_logic;
        -- Custom FPGA Logic Interfaces
        fpga_data_in      : in  std_logic_vector(31 downto 0);
        fpga_data_out     : out std_logic_vector(31 downto 0);
        fpga_valid_in     : in  std_logic;
        fpga_valid_out    : out std_logic;
        fpga_ready_in     : out std_logic;
        fpga_ready_out    : in  std_logic
    );
end entity zynq_arm_fpga_system;

architecture rtl of zynq_arm_fpga_system is
    -- Zynq Processing System Component
    component processing_system7_0 is
        port (
            FCLK_CLK0         : out std_logic;
            FCLK_RESET0_N     : out std_logic;
            M_AXI_GP0_ACLK    : in  std_logic;
            M_AXI_GP0_ARESETN : in  std_logic;
            M_AXI_GP0_AWADDR  : out std_logic_vector(31 downto 0);
            M_AXI_GP0_AWPROT  : out std_logic_vector(2 downto 0);
            M_AXI_GP0_AWVALID : out std_logic;
            M_AXI_GP0_AWREADY : in  std_logic;
            M_AXI_GP0_WDATA   : out std_logic_vector(31 downto 0);
            M_AXI_GP0_WSTRB   : out std_logic_vector(3 downto 0);
            M_AXI_GP0_WVALID  : out std_logic;
            M_AXI_GP0_WREADY  : in  std_logic;
            M_AXI_GP0_BRESP   : in  std_logic_vector(1 downto 0);
            M_AXI_GP0_BVALID  : in  std_logic;
            M_AXI_GP0_BREADY  : out std_logic;
            M_AXI_GP0_ARADDR  : out std_logic_vector(31 downto 0);
            M_AXI_GP0_ARPROT  : out std_logic_vector(2 downto 0);
            M_AXI_GP0_ARVALID : out std_logic;
            M_AXI_GP0_ARREADY : in  std_logic;
            M_AXI_GP0_RDATA   : in  std_logic_vector(31 downto 0);
            M_AXI_GP0_RRESP   : in  std_logic_vector(1 downto 0);
            M_AXI_GP0_RVALID  : in  std_logic;
            M_AXI_GP0_RREADY  : out std_logic;
            S_AXI_HP0_ACLK    : in  std_logic;
            S_AXI_HP0_ARESETN : in  std_logic;
            S_AXI_HP0_AWADDR  : in  std_logic_vector(31 downto 0);
            S_AXI_HP0_AWBURST : in  std_logic_vector(1 downto 0);
            S_AXI_HP0_AWCACHE : in  std_logic_vector(3 downto 0);
            S_AXI_HP0_AWID    : in  std_logic_vector(5 downto 0);
            S_AXI_HP0_AWLEN   : in  std_logic_vector(3 downto 0);
            S_AXI_HP0_AWLOCK  : in  std_logic_vector(1 downto 0);
            S_AXI_HP0_AWPROT  : in  std_logic_vector(2 downto 0);
            S_AXI_HP0_AWQOS   : in  std_logic_vector(3 downto 0);
            S_AXI_HP0_AWREADY : out std_logic;
            S_AXI_HP0_AWSIZE  : in  std_logic_vector(2 downto 0);
            S_AXI_HP0_AWVALID : in  std_logic;
            S_AXI_HP0_WDATA   : in  std_logic_vector(63 downto 0);
            S_AXI_HP0_WID     : in  std_logic_vector(5 downto 0);
            S_AXI_HP0_WLAST   : in  std_logic;
            S_AXI_HP0_WREADY  : out std_logic;
            S_AXI_HP0_WSTRB   : in  std_logic_vector(7 downto 0);
            S_AXI_HP0_WVALID  : in  std_logic;
            S_AXI_HP0_BRESP   : out std_logic_vector(1 downto 0);
            S_AXI_HP0_BID     : out std_logic_vector(5 downto 0);
            S_AXI_HP0_BREADY  : in  std_logic;
            S_AXI_HP0_BVALID  : out std_logic;
            GPIO_tri_io       : inout std_logic_vector(31 downto 0);
            UART_txd          : out std_logic;
            UART_rxd          : in  std_logic
        );
    end component;

    -- Custom FPGA Accelerator Component
    component fpga_accelerator is
        port (
            clk           : in  std_logic;
            reset_n       : in  std_logic;
            -- AXI4-Lite Slave Interface
            s_axi_awaddr  : in  std_logic_vector(31 downto 0);
            s_axi_awprot  : in  std_logic_vector(2 downto 0);
            s_axi_awvalid : in  std_logic;
            s_axi_awready : out std_logic;
            s_axi_wdata   : in  std_logic_vector(31 downto 0);
            s_axi_wstrb   : in  std_logic_vector(3 downto 0);
            s_axi_wvalid  : in  std_logic;
            s_axi_wready  : out std_logic;
            s_axi_bresp   : out std_logic_vector(1 downto 0);
            s_axi_bvalid  : out std_logic;
            s_axi_bready  : in  std_logic;
            s_axi_araddr  : in  std_logic_vector(31 downto 0);
            s_axi_arprot  : in  std_logic_vector(2 downto 0);
            s_axi_arvalid : in  std_logic;
            s_axi_arready : out std_logic;
            s_axi_rdata   : out std_logic_vector(31 downto 0);
            s_axi_rresp   : out std_logic_vector(1 downto 0);
            s_axi_rvalid  : out std_logic;
            s_axi_rready  : in  std_logic;
            -- Data Processing Interface
            data_in       : in  std_logic_vector(31 downto 0);
            data_out      : out std_logic_vector(31 downto 0);
            valid_in      : in  std_logic;
            valid_out     : out std_logic;
            ready_in      : out std_logic;
            ready_out     : in  std_logic
        );
    end component;

    signal fclk_clk0_sig   : std_logic;
    signal fclk_reset0_n_sig : std_logic;

begin
    -- Connect PS clock and reset to outputs
    FCLK_CLK0 <= fclk_clk0_sig;
    FCLK_RESET0_N <= fclk_reset0_n_sig;

    -- Zynq Processing System Instance
    ps7_inst : processing_system7_0
        port map (
            FCLK_CLK0         => fclk_clk0_sig,
            FCLK_RESET0_N     => fclk_reset0_n_sig,
            M_AXI_GP0_ACLK    => M_AXI_GP0_ACLK,
            M_AXI_GP0_ARESETN => M_AXI_GP0_ARESETN,
            M_AXI_GP0_AWADDR  => M_AXI_GP0_AWADDR,
            M_AXI_GP0_AWPROT  => M_AXI_GP0_AWPROT,
            M_AXI_GP0_AWVALID => M_AXI_GP0_AWVALID,
            M_AXI_GP0_AWREADY => M_AXI_GP0_AWREADY,
            M_AXI_GP0_WDATA   => M_AXI_GP0_WDATA,
            M_AXI_GP0_WSTRB   => M_AXI_GP0_WSTRB,
            M_AXI_GP0_WVALID  => M_AXI_GP0_WVALID,
            M_AXI_GP0_WREADY  => M_AXI_GP0_WREADY,
            M_AXI_GP0_BRESP   => M_AXI_GP0_BRESP,
            M_AXI_GP0_BVALID  => M_AXI_GP0_BVALID,
            M_AXI_GP0_BREADY  => M_AXI_GP0_BREADY,
            M_AXI_GP0_ARADDR  => M_AXI_GP0_ARADDR,
            M_AXI_GP0_ARPROT  => M_AXI_GP0_ARPROT,
            M_AXI_GP0_ARVALID => M_AXI_GP0_ARVALID,
            M_AXI_GP0_ARREADY => M_AXI_GP0_ARREADY,
            M_AXI_GP0_RDATA   => M_AXI_GP0_RDATA,
            M_AXI_GP0_RRESP   => M_AXI_GP0_RRESP,
            M_AXI_GP0_RVALID  => M_AXI_GP0_RVALID,
            M_AXI_GP0_RREADY  => M_AXI_GP0_RREADY,
            S_AXI_HP0_ACLK    => S_AXI_HP0_ACLK,
            S_AXI_HP0_ARESETN => S_AXI_HP0_ARESETN,
            S_AXI_HP0_AWADDR  => S_AXI_HP0_AWADDR,
            S_AXI_HP0_AWBURST => S_AXI_HP0_AWBURST,
            S_AXI_HP0_AWCACHE => S_AXI_HP0_AWCACHE,
            S_AXI_HP0_AWID    => S_AXI_HP0_AWID,
            S_AXI_HP0_AWLEN   => S_AXI_HP0_AWLEN,
            S_AXI_HP0_AWLOCK  => S_AXI_HP0_AWLOCK,
            S_AXI_HP0_AWPROT  => S_AXI_HP0_AWPROT,
            S_AXI_HP0_AWQOS   => S_AXI_HP0_AWQOS,
            S_AXI_HP0_AWREADY => S_AXI_HP0_AWREADY,
            S_AXI_HP0_AWSIZE  => S_AXI_HP0_AWSIZE,
            S_AXI_HP0_AWVALID => S_AXI_HP0_AWVALID,
            S_AXI_HP0_WDATA   => S_AXI_HP0_WDATA,
            S_AXI_HP0_WID     => S_AXI_HP0_WID,
            S_AXI_HP0_WLAST   => S_AXI_HP0_WLAST,
            S_AXI_HP0_WREADY  => S_AXI_HP0_WREADY,
            S_AXI_HP0_WSTRB   => S_AXI_HP0_WSTRB,
            S_AXI_HP0_WVALID  => S_AXI_HP0_WVALID,
            S_AXI_HP0_BRESP   => S_AXI_HP0_BRESP,
            S_AXI_HP0_BID     => S_AXI_HP0_BID,
            S_AXI_HP0_BREADY  => S_AXI_HP0_BREADY,
            S_AXI_HP0_BVALID  => S_AXI_HP0_BVALID,
            GPIO_tri_io       => gpio_tri_io,
            UART_txd          => uart_txd,
            UART_rxd          => uart_rxd
        );

    -- FPGA Accelerator Instance
    fpga_accel : fpga_accelerator
        port map (
            clk           => M_AXI_GP0_ACLK,
            reset_n       => M_AXI_GP0_ARESETN,
            s_axi_awaddr  => M_AXI_GP0_AWADDR,
            s_axi_awprot  => M_AXI_GP0_AWPROT,
            s_axi_awvalid => M_AXI_GP0_AWVALID,
            s_axi_awready => M_AXI_GP0_AWREADY,
            s_axi_wdata   => M_AXI_GP0_WDATA,
            s_axi_wstrb   => M_AXI_GP0_WSTRB,
            s_axi_wvalid  => M_AXI_GP0_WVALID,
            s_axi_wready  => M_AXI_GP0_WREADY,
            s_axi_bresp   => M_AXI_GP0_BRESP,
            s_axi_bvalid  => M_AXI_GP0_BVALID,
            s_axi_bready  => M_AXI_GP0_BREADY,
            s_axi_araddr  => M_AXI_GP0_ARADDR,
            s_axi_arprot  => M_AXI_GP0_ARPROT,
            s_axi_arvalid => M_AXI_GP0_ARVALID,
            s_axi_arready => M_AXI_GP0_ARREADY,
            s_axi_rdata   => M_AXI_GP0_RDATA,
            s_axi_rresp   => M_AXI_GP0_RRESP,
            s_axi_rvalid  => M_AXI_GP0_RVALID,
            s_axi_rready  => M_AXI_GP0_RREADY,
            data_in       => fpga_data_in,
            data_out      => fpga_data_out,
            valid_in      => fpga_valid_in,
            valid_out     => fpga_valid_out,
            ready_in      => fpga_ready_in,
            ready_out     => fpga_ready_out
        );

end architecture rtl;
```

## 🟢 **Lattice IP Processors**

### Learning Objectives
- Understand LM32 integration and Wishbone bus interfacing.
- Map instruction/data buses to memory and peripherals.
- Configure JTAG/debug signals and interrupts.
- Apply consistent reset strategies (`rst_n`) and clocking.

### Integration Guide (LM32 + Wishbone)
1. Instantiate the LM32 core with appropriate generics for caches and debug.
2. Connect Wishbone Instruction/Data masters to on-chip memory and peripheral slaves.
3. Create address maps for ROM/RAM and memory-mapped I/O.
4. Bridge external I/O (GPIO/UART) via Wishbone slave components.
5. Integrate JTAG signals for debug and set interrupt routing.

### Common Pitfalls
- Incomplete Wishbone handshake (STB/CYC/ACK) causing bus stalls.
- Mixed reset conventions (`rst_i` vs `rst_n`) across subsystems.
- Cache settings mismatched to memory latencies.
- Un-synchronized external inputs leading to metastability.

### Design Verification Checklist
- Exercise Wishbone transactions with BFMs (reads/writes, burst, error paths).
- Validate address decoding and peripheral access timing.
- Check interrupt latencies and JTAG debug functionality.
- Confirm reset sequencing and clock domain boundaries.

### Physical Notes
- Constrain Wishbone timing; budget for fanout on shared buses.
- Review resource utilization for instruction/data paths and caches.
- Ensure clean CDC for peripherals crossing domains.

References: State Machines, Testbench Essentials, Code Analysis & Reverse Engineering, Enterprise Patterns.

## 🔵 **Intel/Altera IP Processors (Cyclone III)**

### Overview
Cyclone III designs commonly use Nios II and Platform Designer (Qsys) with Avalon-MM/Avalon-ST interconnect. This section provides integration guidance tailored to this project.

### Learning Objectives
- Build a Nios II system in Platform Designer/Qsys.
- Integrate Avalon-MM slaves for memory-mapped peripherals.
- Manage clock/reset, address maps, and interrupt routing.
- Validate interfaces using Avalon BFMs and simulation.

### Integration Guide (Nios II + Avalon-MM)
1. In Platform Designer, create a system: add `Nios II`, `On-Chip Memory`, and custom `Avalon-MM Slave` components.
2. Define clock (`clk`) and reset (`rst_n`) sources; connect all components consistently.
3. Map address spaces for memory and peripherals; export conduit signals for I/O.
4. Generate HDL; instantiate the system in your top-level and connect board I/O.
5. Implement a simple Avalon-MM slave wrapper for LEDs or registers.

```vhdl
-- Example Avalon-MM slave (cheatsheet example; do not place directly in src modules)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity avalon_led_slave is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        address  : in  std_logic_vector(3 downto 0);
        writedata: in  std_logic_vector(31 downto 0);
        readdata : out std_logic_vector(31 downto 0);
        write    : in  std_logic;
        read     : in  std_logic;
        waitreq  : out std_logic;
        leds     : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of avalon_led_slave is
    signal reg0 : unsigned(7 downto 0);
begin
    waitreq <= '0';
    leds    <= std_logic_vector(reg0);

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                reg0 <= (others => '0');
                readdata <= (others => '0');
            else
                if write = '1' and address = x"0" then
                    reg0 <= unsigned(writedata(7 downto 0));
                end if;
                if read = '1' then
                    case address is
                        when x"0" => readdata <= (23 downto 0 => '0') & std_logic_vector(reg0);
                        when others => readdata <= (others => '0');
                    end case;
                end if;
            end if;
        end if;
    end process;
end architecture;
```

### Common Pitfalls
- Incorrect Avalon-MM address alignment and byte enables.
- Not handling `waitreq` for slaves with variable latency.
- Mixed reset polarities between Platform Designer system and user logic.
- Ignoring Qsys-generated timing constraints or clock relationships.

### Design Verification Checklist
- Simulate with Avalon BFMs for read/write/burst coverage.
- Verify reset sequencing and that `rst_n` deassertion is synchronized.
- Check address map correctness and readdata/writedata widths.
- Validate resource usage and timing closure under Cyclone III constraints.

### Physical Implementation Notes
- Partition interconnect to manage fanout; register bridges to improve timing.
- Use on-chip memory for low-latency control paths; constrain I/O timing.
- For multi-clock systems, use clock crossing bridges and proper constraints.

### Advanced Concepts
- DMA engines for high-throughput paths; cache-coherent buffers where applicable.
- Avalon-ST pipelines for streaming data; backpressure handling.
- Interrupt controllers; latency budgeting for real-time responsiveness.

See also: Clocking & Reset Strategies, Synthesis Guidelines, Testbench Essentials, Enterprise Patterns.

### **LatticeMico32 (LM32) Soft Processor**

Reset alias note: LM32 examples often use active-high `rst_i`. For consistency with this cheatsheet’s synchronous, active-low `rst_n` convention, alias the reset in your wrapper or top-level:

```vhdl
-- Reset/clock aliasing (wrapper/top-level)
signal clk    : std_logic;
signal rst_n  : std_logic;
signal clk_i  : std_logic;
signal rst_i  : std_logic;

clk_i <= clk;       -- Direct clock mapping
rst_i <= not rst_n; -- Active-low to active-high reset alias
```

```vhdl
-- LatticeMico32 System Integration
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lm32_system is
    port (
        clk_i           : in  std_logic;
        rst_i           : in  std_logic;
        -- Wishbone Master Interface (Instruction)
        I_ADR_O         : out std_logic_vector(31 downto 0);
        I_DAT_I         : in  std_logic_vector(31 downto 0);
        I_DAT_O         : out std_logic_vector(31 downto 0);
        I_SEL_O         : out std_logic_vector(3 downto 0);
        I_CYC_O         : out std_logic;
        I_STB_O         : out std_logic;
        I_ACK_I         : in  std_logic;
        I_WE_O          : out std_logic;
        I_CTI_O         : out std_logic_vector(2 downto 0);
        I_LOCK_O        : out std_logic;
        I_BTE_O         : out std_logic_vector(1 downto 0);
        I_ERR_I         : in  std_logic;
        I_RTY_I         : in  std_logic;
        -- Wishbone Master Interface (Data)
        D_ADR_O         : out std_logic_vector(31 downto 0);
        D_DAT_I         : in  std_logic_vector(31 downto 0);
        D_DAT_O         : out std_logic_vector(31 downto 0);
        D_SEL_O         : out std_logic_vector(3 downto 0);
        D_CYC_O         : out std_logic;
        D_STB_O         : out std_logic;
        D_ACK_I         : in  std_logic;
        D_WE_O          : out std_logic;
        D_CTI_O         : out std_logic_vector(2 downto 0);
        D_LOCK_O        : out std_logic;
        D_BTE_O         : out std_logic_vector(1 downto 0);
        D_ERR_I         : in  std_logic;
        D_RTY_I         : in  std_logic;
        -- Interrupt Interface
        interrupt       : in  std_logic_vector(31 downto 0);
        -- JTAG Debug Interface
        jtag_clk        : in  std_logic;
        jtag_update     : in  std_logic;
        jtag_reg_q      : out std_logic_vector(7 downto 0);
        jtag_reg_addr_q : out std_logic_vector(2 downto 0)
    );
end entity lm32_system;

architecture rtl of lm32_system is
    -- LM32 CPU Core Component
    component lm32_cpu is
        generic (
            eba_reset       : std_logic_vector(31 downto 0) := x"00000000";
            sdb_address     : std_logic_vector(31 downto 0) := x"00000000";
            CFG_EBA_RESET   : std_logic_vector(31 downto 0) := x"00000000";
            CFG_DEBA_RESET  : std_logic_vector(31 downto 0) := x"10000000";
            CFG_PL_MULTIPLY_ENABLED : boolean := true;
            CFG_PL_BARREL_SHIFT_ENABLED : boolean := true;
            CFG_SIGN_EXTEND_ENABLED : boolean := true;
            CFG_MC_DIVIDE_ENABLED : boolean := true;
            CFG_EBR_POSEDGE_REGISTER_FILE : boolean := false;
            CFG_EBR_NEGEDGE_REGISTER_FILE : boolean := false;
            CFG_EBR_ONE_HOT_REGISTER_FILE : boolean := false;
            CFG_JTAG_ENABLED : boolean := true;
            CFG_DEBUG_ENABLED : boolean := true;
            CFG_HW_DEBUG_ENABLED : boolean := true;
            CFG_ROM_DEBUG_ENABLED : boolean := true;
            CFG_BREAKPOINTS : integer := 4;
            CFG_WATCHPOINTS : integer := 4;
            CFG_EXTERNAL_BREAK_ENABLED : boolean := false;
            CFG_GDBSTUB_ENABLED : boolean := false;
            CFG_ICACHE_ENABLED : boolean := false;
            CFG_ICACHE_ASSOCIATIVITY : integer := 1;
            CFG_ICACHE_SETS : integer := 256;
            CFG_ICACHE_BYTES_PER_LINE : integer := 16;
            CFG_DCACHE_ENABLED : boolean := false;
            CFG_DCACHE_ASSOCIATIVITY : integer := 1;
            CFG_DCACHE_SETS : integer := 256;
            CFG_DCACHE_BYTES_PER_LINE : integer := 16
        );
        port (
            clk_i           : in  std_logic;
            rst_i           : in  std_logic;
            interrupt       : in  std_logic_vector(31 downto 0);
            -- Wishbone Instruction Interface
            I_ADR_O         : out std_logic_vector(31 downto 0);
            I_DAT_I         : in  std_logic_vector(31 downto 0);
            I_DAT_O         : out std_logic_vector(31 downto 0);
            I_SEL_O         : out std_logic_vector(3 downto 0);
            I_CYC_O         : out std_logic;
            I_STB_O         : out std_logic;
            I_ACK_I         : in  std_logic;
            I_WE_O          : out std_logic;
            I_CTI_O         : out std_logic_vector(2 downto 0);
            I_LOCK_O        : out std_logic;
            I_BTE_O         : out std_logic_vector(1 downto 0);
            I_ERR_I         : in  std_logic;
            I_RTY_I         : in  std_logic;
            -- Wishbone Data Interface
            D_ADR_O         : out std_logic_vector(31 downto 0);
            D_DAT_I         : in  std_logic_vector(31 downto 0);
            D_DAT_O         : out std_logic_vector(31 downto 0);
            D_SEL_O         : out std_logic_vector(3 downto 0);
            D_CYC_O         : out std_logic;
            D_STB_O         : out std_logic;
            D_ACK_I         : in  std_logic;
            D_WE_O          : out std_logic;
            D_CTI_O         : out std_logic_vector(2 downto 0);
            D_LOCK_O        : out std_logic;
            D_BTE_O         : out std_logic_vector(1 downto 0);
            D_ERR_I         : in  std_logic;
            D_RTY_I         : in  std_logic;
            -- JTAG Interface
            jtag_clk        : in  std_logic;
            jtag_update     : in  std_logic;
            jtag_reg_q      : out std_logic_vector(7 downto 0);
            jtag_reg_addr_q : out std_logic_vector(2 downto 0)
        );
    end component;

begin
    -- LM32 CPU Instance
    lm32_inst : lm32_cpu
        generic map (
            eba_reset       => x"00000000",
            sdb_address     => x"00000000",
            CFG_EBA_RESET   => x"00000000",
            CFG_DEBA_RESET  => x"10000000",
            CFG_PL_MULTIPLY_ENABLED => true,
            CFG_PL_BARREL_SHIFT_ENABLED => true,
            CFG_SIGN_EXTEND_ENABLED => true,
            CFG_MC_DIVIDE_ENABLED => true,
            CFG_EBR_POSEDGE_REGISTER_FILE => false,
            CFG_EBR_NEGEDGE_REGISTER_FILE => false,
            CFG_EBR_ONE_HOT_REGISTER_FILE => false,
            CFG_JTAG_ENABLED => true,
            CFG_DEBUG_ENABLED => true,
            CFG_HW_DEBUG_ENABLED => true,
            CFG_ROM_DEBUG_ENABLED => true,
            CFG_BREAKPOINTS => 4,
            CFG_WATCHPOINTS => 4,
            CFG_EXTERNAL_BREAK_ENABLED => false,
            CFG_GDBSTUB_ENABLED => false,
            CFG_ICACHE_ENABLED => false,
            CFG_ICACHE_ASSOCIATIVITY => 1,
            CFG_ICACHE_SETS => 256,
            CFG_ICACHE_BYTES_PER_LINE => 16,
            CFG_DCACHE_ENABLED => false,
            CFG_DCACHE_ASSOCIATIVITY => 1,
            CFG_DCACHE_SETS => 256,
            CFG_DCACHE_BYTES_PER_LINE => 16
        )
        port map (
            clk_i           => clk_i,
            rst_i           => rst_i,
            interrupt       => interrupt,
            I_ADR_O         => I_ADR_O,
            I_DAT_I         => I_DAT_I,
            I_DAT_O         => I_DAT_O,
            I_SEL_O         => I_SEL_O,
            I_CYC_O         => I_CYC_O,
            I_STB_O         => I_STB_O,
            I_ACK_I         => I_ACK_I,
            I_WE_O          => I_WE_O,
            I_CTI_O         => I_CTI_O,
            I_LOCK_O        => I_LOCK_O,
            I_BTE_O         => I_BTE_O,
            I_ERR_I         => I_ERR_I,
            I_RTY_I         => I_RTY_I,
            D_ADR_O         => D_ADR_O,
            D_DAT_I         => D_DAT_I,
            D_DAT_O         => D_DAT_O,
            D_SEL_O         => D_SEL_O,
            D_CYC_O         => D_CYC_O,
            D_STB_O         => D_STB_O,
            D_ACK_I         => D_ACK_I,
            D_WE_O          => D_WE_O,
            D_CTI_O         => D_CTI_O,
            D_LOCK_O        => D_LOCK_O,
            D_BTE_O         => D_BTE_O,
            D_ERR_I         => D_ERR_I,
            D_RTY_I         => D_RTY_I,
            jtag_clk        => jtag_clk,
            jtag_update     => jtag_update,
            jtag_reg_q      => jtag_reg_q,
            jtag_reg_addr_q => jtag_reg_addr_q
        );

end architecture rtl;
```

## 🔴 **Microsemi/Microchip IP Processors**

### **CoreRISCV Implementation**
```vhdl
-- Microsemi CoreRISCV Integration
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity core_riscv_system is
    generic (
        RESET_VECTOR_ADDR : std_logic_vector(31 downto 0) := x"00000000";
        DEBUG_HALT_ADDR   : std_logic_vector(31 downto 0) := x"00000800";
        ISA_CONFIG        : integer := 0;  -- RV32I
        MULTIPLY_TYPE     : integer := 1;  -- Fast multiplier
        BUS_INTERFACE_TYPE: integer := 0   -- AHB-Lite
    );
    port (
        CLK             : in  std_logic;
        RESETN          : in  std_logic;
        -- AHB-Lite Master Interface
        HADDR           : out std_logic_vector(31 downto 0);
        HBURST          : out std_logic_vector(2 downto 0);
        HMASTLOCK       : out std_logic;
        HPROT           : out std_logic_vector(3 downto 0);
        HSIZE           : out std_logic_vector(2 downto 0);
        HTRANS          : out std_logic_vector(1 downto 0);
        HWDATA          : out std_logic_vector(31 downto 0);
        HWRITE          : out std_logic;
        HRDATA          : in  std_logic_vector(31 downto 0);
        HREADY          : in  std_logic;
        HRESP           : in  std_logic;
        -- Interrupt Interface
        IRQ             : in  std_logic_vector(30 downto 0);
        NMI             : in  std_logic;
        EXT_IRQ         : in  std_logic;
        -- Debug Interface
        TCK             : in  std_logic;
        TDI             : in  std_logic;
        TDO             : out std_logic;
        TMS             : in  std_logic;
        TRST            : in  std_logic;
        -- GPR Interface (for debugging)
        GPR_DATA        : out std_logic_vector(31 downto 0);
        GPR_ADDR        : out std_logic_vector(4 downto 0);
        GPR_WE          : out std_logic;
        -- Performance Counters
        RETIRE          : out std_logic;
        MHARTID         : in  std_logic_vector(31 downto 0)
    );
end entity core_riscv_system;

architecture rtl of core_riscv_system is
    -- CoreRISCV Component
    component CORERISCV_AXI4 is
        generic (
            RESET_VECTOR_ADDR : std_logic_vector(31 downto 0) := x"00000000";
            DEBUG_HALT_ADDR   : std_logic_vector(31 downto 0) := x"00000800";
            ISA_CONFIG        : integer := 0;
            MULTIPLY_TYPE     : integer := 1;
            BUS_INTERFACE_TYPE: integer := 0;
            BIT_MANIPULATION_ISA : integer := 0;
            COMPRESSED_ISA    : integer := 0;
            FLOATING_POINT_ISA: integer := 0;
            DEBUG_INTERFACE   : integer := 1;
            M_EXTENSION       : integer := 1;
            C_EXTENSION       : integer := 0;
            BITMANIP_EXTENSION: integer := 0;
            FP_EXTENSION      : integer := 0
        );
        port (
            CLK             : in  std_logic;
            RESETN          : in  std_logic;
            HADDR           : out std_logic_vector(31 downto 0);
            HBURST          : out std_logic_vector(2 downto 0);
            HMASTLOCK       : out std_logic;
            HPROT           : out std_logic_vector(3 downto 0);
            HSIZE           : out std_logic_vector(2 downto 0);
            HTRANS          : out std_logic_vector(1 downto 0);
            HWDATA          : out std_logic_vector(31 downto 0);
            HWRITE          : out std_logic;
            HRDATA          : in  std_logic_vector(31 downto 0);
            HREADY          : in  std_logic;
            HRESP           : in  std_logic;
            IRQ             : in  std_logic_vector(30 downto 0);
            NMI             : in  std_logic;
            EXT_IRQ         : in  std_logic;
            TCK             : in  std_logic;
            TDI             : in  std_logic;
            TDO             : out std_logic;
            TMS             : in  std_logic;
            TRST            : in  std_logic;
            GPR_DATA        : out std_logic_vector(31 downto 0);
            GPR_ADDR        : out std_logic_vector(4 downto 0);
            GPR_WE          : out std_logic;
            RETIRE          : out std_logic;
            MHARTID         : in  std_logic_vector(31 downto 0)
        );
    end component;

begin
    -- CoreRISCV Instance
    core_riscv_inst : CORERISCV_AXI4
        generic map (
            RESET_VECTOR_ADDR => RESET_VECTOR_ADDR,
            DEBUG_HALT_ADDR   => DEBUG_HALT_ADDR,
            ISA_CONFIG        => ISA_CONFIG,
            MULTIPLY_TYPE     => MULTIPLY_TYPE,
            BUS_INTERFACE_TYPE=> BUS_INTERFACE_TYPE,
            BIT_MANIPULATION_ISA => 0,
            COMPRESSED_ISA    => 0,
            FLOATING_POINT_ISA=> 0,
            DEBUG_INTERFACE   => 1,
            M_EXTENSION       => 1,
            C_EXTENSION       => 0,
            BITMANIP_EXTENSION=> 0,
            FP_EXTENSION      => 0
        )
        port map (
            CLK             => CLK,
            RESETN          => RESETN,
            HADDR           => HADDR,
            HBURST          => HBURST,
            HMASTLOCK       => HMASTLOCK,
            HPROT           => HPROT,
            HSIZE           => HSIZE,
            HTRANS          => HTRANS,
            HWDATA          => HWDATA,
            HWRITE          => HWRITE,
            HRDATA          => HRDATA,
            HREADY          => HREADY,
            HRESP           => HRESP,
            IRQ             => IRQ,
            NMI             => NMI,
            EXT_IRQ         => EXT_IRQ,
            TCK             => TCK,
            TDI             => TDI,
            TDO             => TDO,
            TMS             => TMS,
            TRST            => TRST,
            GPR_DATA        => GPR_DATA,
            GPR_ADDR        => GPR_ADDR,
            GPR_WE          => GPR_WE,
            RETIRE          => RETIRE,
            MHARTID         => MHARTID
        );

end architecture rtl;
```

## 🟣 **Custom RISC-V Processor Implementation**

### **Custom 5-Stage Pipeline RISC-V Core**
```vhdl
-- Custom RISC-V RV32I Implementation with 5-Stage Pipeline
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity custom_riscv_core is
    generic (
        XLEN            : integer := 32;
        RESET_VECTOR    : std_logic_vector(31 downto 0) := x"00000000";
        ENABLE_M_EXT    : boolean := true;
        ENABLE_C_EXT    : boolean := false;
        ENABLE_COUNTERS : boolean := true
    );
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;
        -- Instruction Memory Interface
        imem_addr       : out std_logic_vector(31 downto 0);
        imem_rdata      : in  std_logic_vector(31 downto 0);
        imem_req        : out std_logic;
        imem_ack        : in  std_logic;
        -- Data Memory Interface
        dmem_addr       : out std_logic_vector(31 downto 0);
        dmem_wdata      : out std_logic_vector(31 downto 0);
        dmem_rdata      : in  std_logic_vector(31 downto 0);
        dmem_we         : out std_logic;
        dmem_be         : out std_logic_vector(3 downto 0);
        dmem_req        : out std_logic;
        dmem_ack        : in  std_logic;
        -- Interrupt Interface
        external_irq    : in  std_logic;
        timer_irq       : in  std_logic;
        software_irq    : in  std_logic;
        -- Debug Interface
        debug_halt      : in  std_logic;
        debug_resume    : in  std_logic;
        debug_pc        : out std_logic_vector(31 downto 0);
        debug_reg_addr  : in  std_logic_vector(4 downto 0);
        debug_reg_data  : out std_logic_vector(31 downto 0);
        debug_reg_we    : in  std_logic;
        debug_reg_wdata : in  std_logic_vector(31 downto 0)
    );
end entity custom_riscv_core;

architecture rtl of custom_riscv_core is
    -- Pipeline Stage Registers
    type if_id_reg_type is record
        pc          : std_logic_vector(31 downto 0);
        instruction : std_logic_vector(31 downto 0);
        valid       : std_logic;
    end record;

    type id_ex_reg_type is record
        pc          : std_logic_vector(31 downto 0);
        rs1_data    : std_logic_vector(31 downto 0);
        rs2_data    : std_logic_vector(31 downto 0);
        immediate   : std_logic_vector(31 downto 0);
        rd_addr     : std_logic_vector(4 downto 0);
        alu_op      : std_logic_vector(3 downto 0);
        mem_read    : std_logic;
        mem_write   : std_logic;
        reg_write   : std_logic;
        branch      : std_logic;
        jump        : std_logic;
        valid       : std_logic;
    end record;

    type ex_mem_reg_type is record
        pc          : std_logic_vector(31 downto 0);
        alu_result  : std_logic_vector(31 downto 0);
        rs2_data    : std_logic_vector(31 downto 0);
        rd_addr     : std_logic_vector(4 downto 0);
        mem_read    : std_logic;
        mem_write   : std_logic;
        reg_write   : std_logic;
        valid       : std_logic;
    end record;

    type mem_wb_reg_type is record
        alu_result  : std_logic_vector(31 downto 0);
        mem_data    : std_logic_vector(31 downto 0);
        rd_addr     : std_logic_vector(4 downto 0);
        reg_write   : std_logic;
        mem_to_reg  : std_logic;
        valid       : std_logic;
    end record;

    -- Pipeline Registers
    signal if_id_reg    : if_id_reg_type;
    signal id_ex_reg    : id_ex_reg_type;
    signal ex_mem_reg   : ex_mem_reg_type;
    signal mem_wb_reg   : mem_wb_reg_type;

    -- Program Counter
    signal pc           : std_logic_vector(31 downto 0);
    signal pc_next      : std_logic_vector(31 downto 0);
    signal pc_plus_4    : std_logic_vector(31 downto 0);

    -- Register File
    type reg_file_type is array (0 to 31) of std_logic_vector(31 downto 0);
    signal reg_file     : reg_file_type;

    -- Control Signals
    signal stall        : std_logic;
    signal flush        : std_logic;
    signal branch_taken : std_logic;
    signal jump_taken   : std_logic;

    -- ALU Signals
    signal alu_a        : std_logic_vector(31 downto 0);
    signal alu_b        : std_logic_vector(31 downto 0);
    signal alu_result   : std_logic_vector(31 downto 0);
    signal alu_zero     : std_logic;

    -- Instruction Decode Signals
    signal opcode       : std_logic_vector(6 downto 0);
    signal rd           : std_logic_vector(4 downto 0);
    signal rs1          : std_logic_vector(4 downto 0);
    signal rs2          : std_logic_vector(4 downto 0);
    signal funct3       : std_logic_vector(2 downto 0);
    signal funct7       : std_logic_vector(6 downto 0);
    signal immediate    : std_logic_vector(31 downto 0);

    -- CSR Registers
    signal mstatus      : std_logic_vector(31 downto 0);
    signal mie          : std_logic_vector(31 downto 0);
    signal mtvec        : std_logic_vector(31 downto 0);
    signal mepc         : std_logic_vector(31 downto 0);
    signal mcause       : std_logic_vector(31 downto 0);
    signal mtval        : std_logic_vector(31 downto 0);
    signal mip          : std_logic_vector(31 downto 0);

    -- Performance Counters
    signal mcycle       : std_logic_vector(63 downto 0);
    signal minstret     : std_logic_vector(63 downto 0);

begin
    -- Program Counter Logic
    pc_plus_4 <= std_logic_vector(unsigned(pc) + 4);
    
    pc_next <= RESET_VECTOR when reset_n = '0' else
               ex_mem_reg.alu_result when (branch_taken = '1' or jump_taken = '1') else
               pc_plus_4 when stall = '0' else
               pc;

    -- Instruction Fetch Stage
    process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                pc <= RESET_VECTOR;
                if_id_reg.valid <= '0';
            elsif stall = '0' then
                pc <= pc_next;
                if_id_reg.pc <= pc;
                if_id_reg.instruction <= imem_rdata;
                if_id_reg.valid <= imem_ack and not flush;
            end if;
        end if;
    end process;

    imem_addr <= pc;
    imem_req <= '1';

    -- Instruction Decode
    opcode <= if_id_reg.instruction(6 downto 0);
    rd <= if_id_reg.instruction(11 downto 7);
    rs1 <= if_id_reg.instruction(19 downto 15);
    rs2 <= if_id_reg.instruction(24 downto 20);
    funct3 <= if_id_reg.instruction(14 downto 12);
    funct7 <= if_id_reg.instruction(31 downto 25);

    -- Immediate Generation
    process(if_id_reg.instruction, opcode)
    begin
        case opcode is
            when "0010011" | "0000011" | "1100111" => -- I-type
                immediate <= (31 downto 12 => if_id_reg.instruction(31)) & if_id_reg.instruction(31 downto 20);
            when "0100011" => -- S-type
                immediate <= (31 downto 12 => if_id_reg.instruction(31)) & if_id_reg.instruction(31 downto 25) & if_id_reg.instruction(11 downto 7);
            when "1100011" => -- B-type
                immediate <= (31 downto 13 => if_id_reg.instruction(31)) & if_id_reg.instruction(31) & if_id_reg.instruction(7) & if_id_reg.instruction(30 downto 25) & if_id_reg.instruction(11 downto 8) & '0';
            when "0110111" | "0010111" => -- U-type
                immediate <= if_id_reg.instruction(31 downto 12) & x"000";
            when "1101111" => -- J-type
                immediate <= (31 downto 21 => if_id_reg.instruction(31)) & if_id_reg.instruction(31) & if_id_reg.instruction(19 downto 12) & if_id_reg.instruction(20) & if_id_reg.instruction(30 downto 21) & '0';
            when others =>
                immediate <= (others => '0');
        end case;
    end process;

    -- Register File
    process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                for i in 0 to 31 loop
                    reg_file(i) <= (others => '0');
                end loop;
            elsif mem_wb_reg.reg_write = '1' and mem_wb_reg.rd_addr /= "00000" then
                if mem_wb_reg.mem_to_reg = '1' then
                    reg_file(to_integer(unsigned(mem_wb_reg.rd_addr))) <= mem_wb_reg.mem_data;
                else
                    reg_file(to_integer(unsigned(mem_wb_reg.rd_addr))) <= mem_wb_reg.alu_result;
                end if;
            end if;
        end if;
    end process;

    -- ID/EX Pipeline Register
    process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '0' or flush = '1' then
                id_ex_reg.valid <= '0';
            elsif stall = '0' then
                id_ex_reg.pc <= if_id_reg.pc;
                id_ex_reg.rs1_data <= reg_file(to_integer(unsigned(rs1)));
                id_ex_reg.rs2_data <= reg_file(to_integer(unsigned(rs2)));
                id_ex_reg.immediate <= immediate;
                id_ex_reg.rd_addr <= rd;
                id_ex_reg.valid <= if_id_reg.valid;
                
                -- Control signal generation based on opcode
                case opcode is
                    when "0110011" => -- R-type
                        id_ex_reg.alu_op <= funct7(5) & funct3;
                        id_ex_reg.mem_read <= '0';
                        id_ex_reg.mem_write <= '0';
                        id_ex_reg.reg_write <= '1';
                        id_ex_reg.branch <= '0';
                        id_ex_reg.jump <= '0';
                    when "0010011" => -- I-type ALU
                        id_ex_reg.alu_op <= '0' & funct3;
                        id_ex_reg.mem_read <= '0';
                        id_ex_reg.mem_write <= '0';
                        id_ex_reg.reg_write <= '1';
                        id_ex_reg.branch <= '0';
                        id_ex_reg.jump <= '0';
                    when "0000011" => -- Load
                        id_ex_reg.alu_op <= "0000"; -- ADD
                        id_ex_reg.mem_read <= '1';
                        id_ex_reg.mem_write <= '0';
                        id_ex_reg.reg_write <= '1';
                        id_ex_reg.branch <= '0';
                        id_ex_reg.jump <= '0';
                    when "0100011" => -- Store
                        id_ex_reg.alu_op <= "0000"; -- ADD
                        id_ex_reg.mem_read <= '0';
                        id_ex_reg.mem_write <= '1';
                        id_ex_reg.reg_write <= '0';
                        id_ex_reg.branch <= '0';
                        id_ex_reg.jump <= '0';
                    when "1100011" => -- Branch
                        id_ex_reg.alu_op <= '0' & funct3;
                        id_ex_reg.mem_read <= '0';
                        id_ex_reg.mem_write <= '0';
                        id_ex_reg.reg_write <= '0';
                        id_ex_reg.branch <= '1';
                        id_ex_reg.jump <= '0';
                    when "1101111" => -- JAL
                        id_ex_reg.alu_op <= "0000"; -- ADD
                        id_ex_reg.mem_read <= '0';
                        id_ex_reg.mem_write <= '0';
                        id_ex_reg.reg_write <= '1';
                        id_ex_reg.branch <= '0';
                        id_ex_reg.jump <= '1';
                    when others =>
                        id_ex_reg.alu_op <= "0000";
                        id_ex_reg.mem_read <= '0';
                        id_ex_reg.mem_write <= '0';
                        id_ex_reg.reg_write <= '0';
                        id_ex_reg.branch <= '0';
                        id_ex_reg.jump <= '0';
                end case;
            end if;
        end if;
    end process;

    -- ALU
    alu_a <= id_ex_reg.rs1_data;
    alu_b <= id_ex_reg.rs2_data when id_ex_reg.alu_op(3) = '1' else id_ex_reg.immediate;

    process(alu_a, alu_b, id_ex_reg.alu_op)
    begin
        case id_ex_reg.alu_op(2 downto 0) is
            when "000" => -- ADD/SUB
                if id_ex_reg.alu_op(3) = '1' then
                    alu_result <= std_logic_vector(unsigned(alu_a) - unsigned(alu_b));
                else
                    alu_result <= std_logic_vector(unsigned(alu_a) + unsigned(alu_b));
                end if;
            when "001" => -- SLL
                alu_result <= std_logic_vector(shift_left(unsigned(alu_a), to_integer(unsigned(alu_b(4 downto 0)))));
            when "010" => -- SLT
                if signed(alu_a) < signed(alu_b) then
                    alu_result <= x"00000001";
                else
                    alu_result <= x"00000000";
                end if;
            when "011" => -- SLTU
                if unsigned(alu_a) < unsigned(alu_b) then
                    alu_result <= x"00000001";
                else
                    alu_result <= x"00000000";
                end if;
            when "100" => -- XOR
                alu_result <= alu_a xor alu_b;
            when "101" => -- SRL/SRA
                if id_ex_reg.alu_op(3) = '1' then
                    alu_result <= std_logic_vector(shift_right(signed(alu_a), to_integer(unsigned(alu_b(4 downto 0)))));
                else
                    alu_result <= std_logic_vector(shift_right(unsigned(alu_a), to_integer(unsigned(alu_b(4 downto 0)))));
                end if;
            when "110" => -- OR
                alu_result <= alu_a or alu_b;
            when "111" => -- AND
                alu_result <= alu_a and alu_b;
            when others =>
                alu_result <= (others => '0');
        end case;
    end process;

    alu_zero <= '1' when alu_result = x"00000000" else '0';

    -- Branch Logic
    process(id_ex_reg.alu_op, alu_zero, alu_result)
    begin
        branch_taken <= '0';
        if id_ex_reg.branch = '1' then
            case id_ex_reg.alu_op(2 downto 0) is
                when "000" => -- BEQ
                    branch_taken <= alu_zero;
                when "001" => -- BNE
                    branch_taken <= not alu_zero;
                when "100" => -- BLT
                    branch_taken <= alu_result(0);
                when "101" => -- BGE
                    branch_taken <= not alu_result(0);
                when "110" => -- BLTU
                    branch_taken <= alu_result(0);
                when "111" => -- BGEU
                    branch_taken <= not alu_result(0);
                when others =>
                    branch_taken <= '0';
            end case;
        end if;
    end process;

    jump_taken <= id_ex_reg.jump;

    -- EX/MEM Pipeline Register
    process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                ex_mem_reg.valid <= '0';
            else
                ex_mem_reg.pc <= id_ex_reg.pc;
                ex_mem_reg.alu_result <= alu_result;
                ex_mem_reg.rs2_data <= id_ex_reg.rs2_data;
                ex_mem_reg.rd_addr <= id_ex_reg.rd_addr;
                ex_mem_reg.mem_read <= id_ex_reg.mem_read;
                ex_mem_reg.mem_write <= id_ex_reg.mem_write;
                ex_mem_reg.reg_write <= id_ex_reg.reg_write;
                ex_mem_reg.valid <= id_ex_reg.valid;
            end if;
        end if;
    end process;

    -- Data Memory Interface
    dmem_addr <= ex_mem_reg.alu_result;
    dmem_wdata <= ex_mem_reg.rs2_data;
    dmem_we <= ex_mem_reg.mem_write;
    dmem_be <= "1111"; -- Word access
    dmem_req <= ex_mem_reg.mem_read or ex_mem_reg.mem_write;

    -- MEM/WB Pipeline Register
    process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                mem_wb_reg.valid <= '0';
            else
                mem_wb_reg.alu_result <= ex_mem_reg.alu_result;
                mem_wb_reg.mem_data <= dmem_rdata;
                mem_wb_reg.rd_addr <= ex_mem_reg.rd_addr;
                mem_wb_reg.reg_write <= ex_mem_reg.reg_write;
                mem_wb_reg.mem_to_reg <= ex_mem_reg.mem_read;
                mem_wb_reg.valid <= ex_mem_reg.valid;
            end if;
        end if;
    end process;

    -- Hazard Detection and Control
    stall <= '1' when (id_ex_reg.mem_read = '1' and 
                      (id_ex_reg.rd_addr = rs1 or id_ex_reg.rd_addr = rs2)) else '0';
    
    flush <= branch_taken or jump_taken;

    -- Performance Counters
    process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                mcycle <= (others => '0');
                minstret <= (others => '0');
            else
                mcycle <= std_logic_vector(unsigned(mcycle) + 1);
                if mem_wb_reg.valid = '1' then
                    minstret <= std_logic_vector(unsigned(minstret) + 1);
                end if;
            end if;
        end if;
    end process;

    -- Debug Interface
    debug_pc <= pc;
    debug_reg_data <= reg_file(to_integer(unsigned(debug_reg_addr)));

    -- Debug Register Write
    process(clk)
    begin
        if rising_edge(clk) then
            if debug_reg_we = '1' and debug_reg_addr /= "00000" then
                reg_file(to_integer(unsigned(debug_reg_addr))) <= debug_reg_wdata;
            end if;
        end if;
    end process;

end architecture rtl;
```

## 🔵 **ARM Cortex-M Integration for FPGA**

### **ARM Cortex-M3 DesignStart Integration**
```vhdl
-- ARM Cortex-M3 DesignStart FPGA Integration
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cortex_m3_fpga_system is
    port (
        -- System Clock and Reset
        HCLK            : in  std_logic;
        HRESETn         : in  std_logic;
        -- AHB-Lite Master Interface
        HADDR           : out std_logic_vector(31 downto 0);
        HBURST          : out std_logic_vector(2 downto 0);
        HMASTLOCK       : out std_logic;
        HPROT           : out std_logic_vector(3 downto 0);
        HSIZE           : out std_logic_vector(2 downto 0);
        HTRANS          : out std_logic_vector(1 downto 0);
        HWDATA          : out std_logic_vector(31 downto 0);
        HWRITE          : out std_logic;
        HRDATA          : in  std_logic_vector(31 downto 0);
        HREADY          : in  std_logic;
        HRESP           : in  std_logic;
        -- Interrupt Interface
        IRQ             : in  std_logic_vector(239 downto 0);
        NMI             : in  std_logic;
        -- Debug Interface
        SWCLKTCK        : in  std_logic;
        SWDIOTMS        : inout std_logic;
        nTRST           : in  std_logic;
        TDI             : in  std_logic;
        TDO             : out std_logic;
        nTDOEN          : out std_logic;
        -- System Control
        SLEEPING        : out std_logic;
        SLEEPDEEP       : out std_logic;
        WAKEUP          : in  std_logic;
        WICSENSE        : in  std_logic_vector(33 downto 0);
        -- Code Sequentiality and Speculation
        CODENSEQ        : out std_logic;
        CODEHINTDE      : out std_logic_vector(2 downto 0);
        SPECHTRANS      : out std_logic;
        -- External Interfaces
        gpio_in         : in  std_logic_vector(31 downto 0);
        gpio_out        : out std_logic_vector(31 downto 0);
        gpio_oe         : out std_logic_vector(31 downto 0);
        uart_tx         : out std_logic;
        uart_rx         : in  std_logic;
        spi_sclk        : out std_logic;
        spi_mosi        : out std_logic;
        spi_miso        : in  std_logic;
        spi_cs          : out std_logic_vector(3 downto 0)
    );
end entity cortex_m3_fpga_system;

architecture rtl of cortex_m3_fpga_system is
    -- ARM Cortex-M3 DesignStart Component
    component CORTEXM3INTEGRATIONDS is
        port (
            -- Clock and Reset
            HCLK            : in  std_logic;
            HRESETn         : in  std_logic;
            -- AHB-Lite Master Interface
            HADDR           : out std_logic_vector(31 downto 0);
            HBURST          : out std_logic_vector(2 downto 0);
            HMASTLOCK       : out std_logic;
            HPROT           : out std_logic_vector(3 downto 0);
            HSIZE           : out std_logic_vector(2 downto 0);
            HTRANS          : out std_logic_vector(1 downto 0);
            HWDATA          : out std_logic_vector(31 downto 0);
            HWRITE          : out std_logic;
            HRDATA          : in  std_logic_vector(31 downto 0);
            HREADY          : in  std_logic;
            HRESP           : in  std_logic;
            -- Interrupt Interface
            IRQ             : in  std_logic_vector(239 downto 0);
            NMI             : in  std_logic;
            -- Debug Interface
            SWCLKTCK        : in  std_logic;
            SWDIOTMS        : inout std_logic;
            nTRST           : in  std_logic;
            TDI             : in  std_logic;
            TDO             : out std_logic;
            nTDOEN          : out std_logic;
            -- System Control
            SLEEPING        : out std_logic;
            SLEEPDEEP       : out std_logic;
            WAKEUP          : in  std_logic;
            WICSENSE        : in  std_logic_vector(33 downto 0);
            -- Code Sequentiality and Speculation
            CODENSEQ        : out std_logic;
            CODEHINTDE      : out std_logic_vector(2 downto 0);
            SPECHTRANS      : out std_logic
        );
    end component;

    -- AHB-Lite Decoder Component
    component ahb_lite_decoder is
        port (
            HCLK            : in  std_logic;
            HRESETn         : in  std_logic;
            -- Master Interface
            HADDR_M         : in  std_logic_vector(31 downto 0);
            HBURST_M        : in  std_logic_vector(2 downto 0);
            HMASTLOCK_M     : in  std_logic;
            HPROT_M         : in  std_logic_vector(3 downto 0);
            HSIZE_M         : in  std_logic_vector(2 downto 0);
            HTRANS_M        : in  std_logic_vector(1 downto 0);
            HWDATA_M        : in  std_logic_vector(31 downto 0);
            HWRITE_M        : in  std_logic;
            HRDATA_M        : out std_logic_vector(31 downto 0);
            HREADY_M        : out std_logic;
            HRESP_M         : out std_logic;
            -- Slave Interfaces (GPIO, UART, SPI, etc.)
            HADDR_S         : out std_logic_vector(31 downto 0);
            HBURST_S        : out std_logic_vector(2 downto 0);
            HMASTLOCK_S     : out std_logic;
            HPROT_S         : out std_logic_vector(3 downto 0);
            HSIZE_S         : out std_logic_vector(2 downto 0);
            HTRANS_S        : out std_logic_vector(1 downto 0);
            HWDATA_S        : out std_logic_vector(31 downto 0);
            HWRITE_S        : out std_logic;
            HSEL_GPIO       : out std_logic;
            HSEL_UART       : out std_logic;
            HSEL_SPI        : out std_logic;
            HRDATA_GPIO     : in  std_logic_vector(31 downto 0);
            HREADY_GPIO     : in  std_logic;
            HRESP_GPIO      : in  std_logic;
            HRDATA_UART     : in  std_logic_vector(31 downto 0);
            HREADY_UART     : in  std_logic;
            HRESP_UART      : in  std_logic;
            HRDATA_SPI      : in  std_logic_vector(31 downto 0);
            HREADY_SPI      : in  std_logic;
            HRESP_SPI       : in  std_logic
        );
    end component;

    -- GPIO Controller Component
    component ahb_gpio is
        port (
            HCLK            : in  std_logic;
            HRESETn         : in  std_logic;
            HSEL            : in  std_logic;
            HADDR           : in  std_logic_vector(31 downto 0);
            HTRANS          : in  std_logic_vector(1 downto 0);
            HSIZE           : in  std_logic_vector(2 downto 0);
            HWRITE          : in  std_logic;
            HWDATA          : in  std_logic_vector(31 downto 0);
            HRDATA          : out std_logic_vector(31 downto 0);
            HREADY          : out std_logic;
            HRESP           : out std_logic;
            gpio_in         : in  std_logic_vector(31 downto 0);
            gpio_out        : out std_logic_vector(31 downto 0);
            gpio_oe         : out std_logic_vector(31 downto 0);
            gpio_irq        : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Internal Signals
    signal haddr_int        : std_logic_vector(31 downto 0);
    signal hburst_int       : std_logic_vector(2 downto 0);
    signal hmastlock_int    : std_logic;
    signal hprot_int        : std_logic_vector(3 downto 0);
    signal hsize_int        : std_logic_vector(2 downto 0);
    signal htrans_int       : std_logic_vector(1 downto 0);
    signal hwdata_int       : std_logic_vector(31 downto 0);
    signal hwrite_int       : std_logic;
    signal hrdata_int       : std_logic_vector(31 downto 0);
    signal hready_int       : std_logic;
    signal hresp_int        : std_logic;

    -- Peripheral Signals
    signal hsel_gpio        : std_logic;
    signal hsel_uart        : std_logic;
    signal hsel_spi         : std_logic;
    signal hrdata_gpio      : std_logic_vector(31 downto 0);
    signal hready_gpio      : std_logic;
    signal hresp_gpio       : std_logic;
    signal hrdata_uart      : std_logic_vector(31 downto 0);
    signal hready_uart      : std_logic;
    signal hresp_uart       : std_logic;
    signal hrdata_spi       : std_logic_vector(31 downto 0);
    signal hready_spi       : std_logic;
    signal hresp_spi        : std_logic;

    signal gpio_irq         : std_logic_vector(31 downto 0);
    signal irq_combined     : std_logic_vector(239 downto 0);

begin
    -- ARM Cortex-M3 Instance
    cortex_m3_inst : CORTEXM3INTEGRATIONDS
        port map (
            HCLK            => HCLK,
            HRESETn         => HRESETn,
            HADDR           => haddr_int,
            HBURST          => hburst_int,
            HMASTLOCK       => hmastlock_int,
            HPROT           => hprot_int,
            HSIZE           => hsize_int,
            HTRANS          => htrans_int,
            HWDATA          => hwdata_int,
            HWRITE          => hwrite_int,
            HRDATA          => hrdata_int,
            HREADY          => hready_int,
            HRESP           => hresp_int,
            IRQ             => irq_combined,
            NMI             => NMI,
            SWCLKTCK        => SWCLKTCK,
            SWDIOTMS        => SWDIOTMS,
            nTRST           => nTRST,
            TDI             => TDI,
            TDO             => TDO,
            nTDOEN          => nTDOEN,
            SLEEPING        => SLEEPING,
            SLEEPDEEP       => SLEEPDEEP,
            WAKEUP          => WAKEUP,
            WICSENSE        => WICSENSE,
            CODENSEQ        => CODENSEQ,
            CODEHINTDE      => CODEHINTDE,
            SPECHTRANS      => SPECHTRANS
        );

    -- AHB-Lite Decoder Instance
    ahb_decoder_inst : ahb_lite_decoder
        port map (
            HCLK            => HCLK,
            HRESETn         => HRESETn,
            HADDR_M         => haddr_int,
            HBURST_M        => hburst_int,
            HMASTLOCK_M     => hmastlock_int,
            HPROT_M         => hprot_int,
            HSIZE_M         => hsize_int,
            HTRANS_M        => htrans_int,
            HWDATA_M        => hwdata_int,
            HWRITE_M        => hwrite_int,
            HRDATA_M        => hrdata_int,
            HREADY_M        => hready_int,
            HRESP_M         => hresp_int,
            HADDR_S         => HADDR,
            HBURST_S        => HBURST,
            HMASTLOCK_S     => HMASTLOCK,
            HPROT_S         => HPROT,
            HSIZE_S         => HSIZE,
            HTRANS_S        => HTRANS,
            HWDATA_S        => HWDATA,
            HWRITE_S        => HWRITE,
            HSEL_GPIO       => hsel_gpio,
            HSEL_UART       => hsel_uart,
            HSEL_SPI        => hsel_spi,
            HRDATA_GPIO     => hrdata_gpio,
            HREADY_GPIO     => hready_gpio,
            HRESP_GPIO      => hresp_gpio,
            HRDATA_UART     => hrdata_uart,
            HREADY_UART     => hready_uart,
            HRESP_UART      => hresp_uart,
            HRDATA_SPI      => hrdata_spi,
            HREADY_SPI      => hready_spi,
            HRESP_SPI       => hresp_spi
        );

    -- GPIO Controller Instance
    gpio_inst : ahb_gpio
        port map (
            HCLK            => HCLK,
            HRESETn         => HRESETn,
            HSEL            => hsel_gpio,
            HADDR           => HADDR,
            HTRANS          => HTRANS,
            HSIZE           => HSIZE,
            HWRITE          => HWRITE,
            HWDATA          => HWDATA,
            HRDATA          => hrdata_gpio,
            HREADY          => hready_gpio,
            HRESP           => hresp_gpio,
            gpio_in         => gpio_in,
            gpio_out        => gpio_out,
            gpio_oe         => gpio_oe,
            gpio_irq        => gpio_irq
        );

    -- Interrupt Mapping
    irq_combined(31 downto 0) <= gpio_irq;
    irq_combined(239 downto 32) <= IRQ(239 downto 32);

    -- External Interface Connections
    HRDATA <= hrdata_int;
    HREADY <= hready_int;
    HRESP <= hresp_int;

end architecture rtl;
```

---

# 🖥️ **Microcontroller Architecture Designs**

## 🧠 **Complete CPU Core Implementation**
```vhdl
-- 8-bit RISC Microcontroller CPU Core
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_core is
    generic (
        DATA_WIDTH    : integer := 8;
        ADDR_WIDTH    : integer := 16;
        REG_COUNT     : integer := 16
    );
    port (
        clk           : in  std_logic;
        reset_n       : in  std_logic;
        -- Memory interface
        mem_addr      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        mem_data_in   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_data_out  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_read      : out std_logic;
        mem_write     : out std_logic;
        mem_ready     : in  std_logic;
        -- Interrupt interface
        interrupt_req : in  std_logic;
        interrupt_ack : out std_logic;
        -- Debug interface
        debug_pc      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        debug_state   : out std_logic_vector(3 downto 0);
        debug_flags   : out std_logic_vector(7 downto 0)
    );
end entity cpu_core;

architecture behavioral of cpu_core is
    -- CPU States
    type cpu_state_type is (RESET, FETCH, DECODE, EXECUTE, WRITEBACK, INTERRUPT);
    signal cpu_state : cpu_state_type;
    
    -- Instruction format (8-bit instructions)
    -- [7:6] - Instruction type: 00=ALU, 01=Load/Store, 10=Branch, 11=Special
    -- [5:3] - Operation code
    -- [2:0] - Register/Immediate field
    
    -- Registers
    type register_file_type is array(0 to REG_COUNT-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal registers : register_file_type;
    
    -- Special registers
    signal pc           : unsigned(ADDR_WIDTH-1 downto 0);  -- Program Counter
    signal sp           : unsigned(ADDR_WIDTH-1 downto 0);  -- Stack Pointer
    signal ir           : std_logic_vector(DATA_WIDTH-1 downto 0);  -- Instruction Register
    signal acc          : std_logic_vector(DATA_WIDTH-1 downto 0);  -- Accumulator
    
    -- Status flags
    signal flag_zero    : std_logic;
    signal flag_carry   : std_logic;
    signal flag_negative: std_logic;
    signal flag_overflow: std_logic;
    signal flag_interrupt_enable : std_logic;
    
    -- Internal signals
    signal alu_a        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal alu_b        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal alu_result   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal alu_operation: std_logic_vector(3 downto 0);
    signal alu_flags    : std_logic_vector(3 downto 0);
    
    -- Instruction decode signals
    signal inst_type    : std_logic_vector(1 downto 0);
    signal inst_opcode  : std_logic_vector(2 downto 0);
    signal inst_reg     : std_logic_vector(2 downto 0);
    
    -- Memory control
    signal mem_addr_int : unsigned(ADDR_WIDTH-1 downto 0);
    
begin
    -- Instruction decode
    inst_type   <= ir(7 downto 6);
    inst_opcode <= ir(5 downto 3);
    inst_reg    <= ir(2 downto 0);
    
    -- ALU instance
    alu_inst: entity work.alu_8bit
        port map (
            a         => alu_a,
            b         => alu_b,
            operation => alu_operation,
            result    => alu_result,
            flags     => alu_flags
        );
    
    -- Main CPU state machine
    cpu_fsm: process(clk, reset_n)
        variable reg_addr : integer;
        variable branch_target : unsigned(ADDR_WIDTH-1 downto 0);
    begin
        if reset_n = '0' then
            cpu_state <= RESET;
            pc <= (others => '0');
            sp <= to_unsigned(2**ADDR_WIDTH - 1, ADDR_WIDTH);  -- Stack grows down
            ir <= (others => '0');
            acc <= (others => '0');
            flag_zero <= '0';
            flag_carry <= '0';
            flag_negative <= '0';
            flag_overflow <= '0';
            flag_interrupt_enable <= '0';
            mem_read <= '0';
            mem_write <= '0';
            interrupt_ack <= '0';
            
            -- Initialize register file
            for i in 0 to REG_COUNT-1 loop
                registers(i) <= (others => '0');
            end loop;
            
        elsif rising_edge(clk) then
            case cpu_state is
                when RESET =>
                    cpu_state <= FETCH;
                    pc <= (others => '0');
                
                when FETCH =>
                    -- Fetch instruction from memory
                    mem_addr_int <= pc;
                    mem_read <= '1';
                    mem_write <= '0';
                    
                    if mem_ready = '1' then
                        ir <= mem_data_in;
                        pc <= pc + 1;
                        cpu_state <= DECODE;
                        mem_read <= '0';
                    end if;
                
                when DECODE =>
                    -- Decode instruction and prepare operands
                    cpu_state <= EXECUTE;
                    
                    case inst_type is
                        when "00" =>  -- ALU operations
                            reg_addr := to_integer(unsigned(inst_reg));
                            alu_a <= acc;
                            alu_b <= registers(reg_addr);
                            alu_operation <= '0' & inst_opcode;
                        
                        when "01" =>  -- Load/Store operations
                            reg_addr := to_integer(unsigned(inst_reg));
                            mem_addr_int <= unsigned(registers(reg_addr));
                        
                        when "10" =>  -- Branch operations
                            reg_addr := to_integer(unsigned(inst_reg));
                            branch_target := pc + unsigned(registers(reg_addr));
                        
                        when others =>  -- Special operations
                            null;
                    end case;
                
                when EXECUTE =>
                    case inst_type is
                        when "00" =>  -- ALU operations
                            case inst_opcode is
                                when "000" =>  -- ADD
                                    acc <= alu_result;
                                    flag_zero <= alu_flags(0);
                                    flag_carry <= alu_flags(1);
                                    flag_negative <= alu_flags(2);
                                    flag_overflow <= alu_flags(3);
                                
                                when "001" =>  -- SUB
                                    acc <= alu_result;
                                    flag_zero <= alu_flags(0);
                                    flag_carry <= alu_flags(1);
                                    flag_negative <= alu_flags(2);
                                    flag_overflow <= alu_flags(3);
                                
                                when "010" =>  -- AND
                                    acc <= alu_result;
                                    flag_zero <= alu_flags(0);
                                    flag_negative <= alu_flags(2);
                                
                                when "011" =>  -- OR
                                    acc <= alu_result;
                                    flag_zero <= alu_flags(0);
                                    flag_negative <= alu_flags(2);
                                
                                when "100" =>  -- XOR
                                    acc <= alu_result;
                                    flag_zero <= alu_flags(0);
                                    flag_negative <= alu_flags(2);
                                
                                when "101" =>  -- SHL (Shift Left)
                                    acc <= alu_result;
                                    flag_carry <= alu_flags(1);
                                
                                when "110" =>  -- SHR (Shift Right)
                                    acc <= alu_result;
                                    flag_carry <= alu_flags(1);
                                
                                when others =>  -- CMP (Compare)
                                    -- Don't update accumulator, only flags
                                    flag_zero <= alu_flags(0);
                                    flag_carry <= alu_flags(1);
                                    flag_negative <= alu_flags(2);
                                    flag_overflow <= alu_flags(3);
                            end case;
                            
                            cpu_state <= FETCH;
                        
                        when "01" =>  -- Load/Store operations
                            case inst_opcode is
                                when "000" =>  -- LOAD acc, [reg]
                                    mem_read <= '1';
                                    if mem_ready = '1' then
                                        acc <= mem_data_in;
                                        mem_read <= '0';
                                        cpu_state <= FETCH;
                                    end if;
                                
                                when "001" =>  -- STORE [reg], acc
                                    mem_data_out <= acc;
                                    mem_write <= '1';
                                    if mem_ready = '1' then
                                        mem_write <= '0';
                                        cpu_state <= FETCH;
                                    end if;
                                
                                when "010" =>  -- LOAD reg, immediate
                                    -- Next byte is immediate value
                                    mem_addr_int <= pc;
                                    mem_read <= '1';
                                    if mem_ready = '1' then
                                        reg_addr := to_integer(unsigned(inst_reg));
                                        registers(reg_addr) <= mem_data_in;
                                        pc <= pc + 1;
                                        mem_read <= '0';
                                        cpu_state <= FETCH;
                                    end if;
                                
                                when "011" =>  -- MOVE reg, acc
                                    reg_addr := to_integer(unsigned(inst_reg));
                                    registers(reg_addr) <= acc;
                                    cpu_state <= FETCH;
                                
                                when "100" =>  -- MOVE acc, reg
                                    reg_addr := to_integer(unsigned(inst_reg));
                                    acc <= registers(reg_addr);
                                    cpu_state <= FETCH;
                                
                                when others =>
                                    cpu_state <= FETCH;
                            end case;
                        
                        when "10" =>  -- Branch operations
                            case inst_opcode is
                                when "000" =>  -- JMP (unconditional)
                                    pc <= branch_target;
                                
                                when "001" =>  -- JZ (jump if zero)
                                    if flag_zero = '1' then
                                        pc <= branch_target;
                                    end if;
                                
                                when "010" =>  -- JNZ (jump if not zero)
                                    if flag_zero = '0' then
                                        pc <= branch_target;
                                    end if;
                                
                                when "011" =>  -- JC (jump if carry)
                                    if flag_carry = '1' then
                                        pc <= branch_target;
                                    end if;
                                
                                when "100" =>  -- JNC (jump if no carry)
                                    if flag_carry = '0' then
                                        pc <= branch_target;
                                    end if;
                                
                                when "101" =>  -- CALL (subroutine call)
                                    -- Push return address to stack
                                    mem_addr_int <= sp;
                                    mem_data_out <= std_logic_vector(pc(DATA_WIDTH-1 downto 0));
                                    mem_write <= '1';
                                    if mem_ready = '1' then
                                        sp <= sp - 1;
                                        pc <= branch_target;
                                        mem_write <= '0';
                                    end if;
                                
                                when "110" =>  -- RET (return from subroutine)
                                    sp <= sp + 1;
                                    mem_addr_int <= sp + 1;
                                    mem_read <= '1';
                                    if mem_ready = '1' then
                                        pc <= unsigned(mem_data_in);
                                        mem_read <= '0';
                                    end if;
                                
                                when others =>
                                    null;
                            end case;
                            
                            cpu_state <= FETCH;
                        
                        when others =>  -- Special operations
                            case inst_opcode is
                                when "000" =>  -- NOP
                                    null;
                                
                                when "001" =>  -- HALT
                                    cpu_state <= RESET;  -- Stop execution
                                
                                when "010" =>  -- EI (Enable Interrupts)
                                    flag_interrupt_enable <= '1';
                                
                                when "011" =>  -- DI (Disable Interrupts)
                                    flag_interrupt_enable <= '0';
                                
                                when others =>
                                    null;
                            end case;
                            
                            cpu_state <= FETCH;
                    end case;
                
                when INTERRUPT =>
                    -- Handle interrupt
                    if interrupt_req = '1' and flag_interrupt_enable = '1' then
                        -- Save context (simplified - save PC to stack)
                        mem_addr_int <= sp;
                        mem_data_out <= std_logic_vector(pc(DATA_WIDTH-1 downto 0));
                        mem_write <= '1';
                        
                        if mem_ready = '1' then
                            sp <= sp - 1;
                            pc <= to_unsigned(16#FF#, ADDR_WIDTH);  -- Interrupt vector
                            interrupt_ack <= '1';
                            flag_interrupt_enable <= '0';  -- Disable interrupts
                            cpu_state <= FETCH;
                            mem_write <= '0';
                        end if;
                    else
                        cpu_state <= FETCH;
                    end if;
                
                when WRITEBACK =>
                    -- Additional writeback stage if needed
                    cpu_state <= FETCH;
            end case;
            
            -- Check for interrupts
            if interrupt_req = '1' and flag_interrupt_enable = '1' and 
               cpu_state = FETCH then
                cpu_state <= INTERRUPT;
            end if;
        end if;
    end process;
    
    -- Memory address output
    mem_addr <= std_logic_vector(mem_addr_int);
    
    -- Debug outputs
    debug_pc <= std_logic_vector(pc);
    debug_state <= "0000" when cpu_state = RESET else
                   "0001" when cpu_state = FETCH else
                   "0010" when cpu_state = DECODE else
                   "0011" when cpu_state = EXECUTE else
                   "0100" when cpu_state = WRITEBACK else
                   "0101" when cpu_state = INTERRUPT else
                   "1111";
    
    debug_flags <= flag_interrupt_enable & "000" & 
                   flag_overflow & flag_negative & flag_carry & flag_zero;
    
end architecture behavioral;
```

## 🧮 **Advanced ALU Implementation**
```vhdl
-- 8-bit Arithmetic Logic Unit with Extended Operations
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_8bit is
    port (
        a         : in  std_logic_vector(7 downto 0);
        b         : in  std_logic_vector(7 downto 0);
        operation : in  std_logic_vector(3 downto 0);
        result    : out std_logic_vector(7 downto 0);
        flags     : out std_logic_vector(3 downto 0)  -- [overflow, negative, carry, zero]
    );
end entity alu_8bit;

architecture behavioral of alu_8bit is
    signal temp_result : std_logic_vector(8 downto 0);  -- 9-bit for carry detection
    signal signed_a    : signed(7 downto 0);
    signal signed_b    : signed(7 downto 0);
    signal signed_result : signed(8 downto 0);
    
begin
    signed_a <= signed(a);
    signed_b <= signed(b);
    
    alu_process: process(a, b, operation, signed_a, signed_b)
        variable mult_result : signed(15 downto 0);
        variable div_result  : signed(7 downto 0);
        variable shift_count : integer;
    begin
        -- Default values
        temp_result <= (others => '0');
        signed_result <= (others => '0');
        
        case operation is
            when "0000" =>  -- ADD
                temp_result <= std_logic_vector(unsigned('0' & a) + unsigned('0' & b));
                signed_result <= resize(signed_a + signed_b, 9);
            
            when "0001" =>  -- SUB
                temp_result <= std_logic_vector(unsigned('0' & a) - unsigned('0' & b));
                signed_result <= resize(signed_a - signed_b, 9);
            
            when "0010" =>  -- AND
                temp_result <= '0' & (a and b);
            
            when "0011" =>  -- OR
                temp_result <= '0' & (a or b);
            
            when "0100" =>  -- XOR
                temp_result <= '0' & (a xor b);
            
            when "0101" =>  -- NOT A
                temp_result <= '0' & (not a);
            
            when "0110" =>  -- SHL (Shift Left)
                shift_count := to_integer(unsigned(b(2 downto 0)));  -- Use lower 3 bits
                if shift_count = 0 then
                    temp_result <= '0' & a;
                else
                    temp_result <= std_logic_vector(shift_left(unsigned('0' & a), shift_count));
                end if;
            
            when "0111" =>  -- SHR (Shift Right)
                shift_count := to_integer(unsigned(b(2 downto 0)));
                if shift_count = 0 then
                    temp_result <= '0' & a;
                else
                    temp_result <= '0' & std_logic_vector(shift_right(unsigned(a), shift_count));
                end if;
            
            when "1000" =>  -- ROL (Rotate Left)
                shift_count := to_integer(unsigned(b(2 downto 0)));
                temp_result <= '0' & std_logic_vector(rotate_left(unsigned(a), shift_count));
            
            when "1001" =>  -- ROR (Rotate Right)
                shift_count := to_integer(unsigned(b(2 downto 0)));
                temp_result <= '0' & std_logic_vector(rotate_right(unsigned(a), shift_count));
            
            when "1010" =>  -- MUL (Multiply - lower 8 bits)
                mult_result := signed_a * signed_b;
                temp_result <= '0' & std_logic_vector(mult_result(7 downto 0));
                signed_result <= resize(mult_result(8 downto 0), 9);
            
            when "1011" =>  -- DIV (Divide)
                if signed_b /= 0 then
                    div_result := signed_a / signed_b;
                    temp_result <= '0' & std_logic_vector(div_result);
                    signed_result <= resize(div_result, 9);
                else
                    temp_result <= (others => '1');  -- Division by zero
                    signed_result <= (others => '1');
                end if;
            
            when "1100" =>  -- MOD (Modulo)
                if signed_b /= 0 then
                    div_result := signed_a mod signed_b;
                    temp_result <= '0' & std_logic_vector(div_result);
                    signed_result <= resize(div_result, 9);
                else
                    temp_result <= (others => '0');
                    signed_result <= (others => '0');
                end if;
            
            when "1101" =>  -- CMP (Compare - A - B, set flags only)
                temp_result <= std_logic_vector(unsigned('0' & a) - unsigned('0' & b));
                signed_result <= resize(signed_a - signed_b, 9);
            
            when "1110" =>  -- INC (Increment A)
                temp_result <= std_logic_vector(unsigned('0' & a) + 1);
                signed_result <= resize(signed_a + 1, 9);
            
            when others =>  -- DEC (Decrement A)
                temp_result <= std_logic_vector(unsigned('0' & a) - 1);
                signed_result <= resize(signed_a - 1, 9);
        end case;
    end process;
    
    -- Output result
    result <= temp_result(7 downto 0);
    
    -- Flag generation
    flags(0) <= '1' when temp_result(7 downto 0) = "00000000" else '0';  -- Zero flag
    flags(1) <= temp_result(8);  -- Carry flag
    flags(2) <= temp_result(7);  -- Negative flag (MSB of result)
    
    -- Overflow flag (for signed arithmetic)
    flags(3) <= '1' when (operation = "0000" or operation = "0001" or 
                         operation = "1010" or operation = "1110" or 
                         operation = "1111") and
                        (signed_result(8) /= signed_result(7)) else '0';
    
end architecture behavioral;
```

## 🧠 **Memory Controller with Cache**
```vhdl
-- Memory Controller with Simple Cache Implementation
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory_controller is
    generic (
        ADDR_WIDTH     : integer := 16;
        DATA_WIDTH     : integer := 8;
        CACHE_SIZE     : integer := 64;   -- Cache lines
        CACHE_LINE_SIZE: integer := 4     -- Words per cache line
    );
    port (
        clk            : in  std_logic;
        reset_n        : in  std_logic;
        -- CPU interface
        cpu_addr       : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        cpu_data_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        cpu_data_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        cpu_read       : in  std_logic;
        cpu_write      : in  std_logic;
        cpu_ready      : out std_logic;
        -- External memory interface
        mem_addr       : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        mem_data_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_data_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_read       : out std_logic;
        mem_write      : out std_logic;
        mem_ready      : in  std_logic;
        -- Cache statistics
        cache_hits     : out std_logic_vector(15 downto 0);
        cache_misses   : out std_logic_vector(15 downto 0)
    );
end entity memory_controller;

architecture behavioral of memory_controller is
    -- Cache structure
    type cache_line_type is record
        valid : std_logic;
        dirty : std_logic;
        tag   : std_logic_vector(ADDR_WIDTH-6 downto 0);  -- Assuming 6-bit cache index
        data  : std_logic_vector(DATA_WIDTH*CACHE_LINE_SIZE-1 downto 0);
    end record;
    
    type cache_array_type is array(0 to CACHE_SIZE-1) of cache_line_type;
    signal cache_array : cache_array_type;
    
    -- Cache control signals
    signal cache_index : integer range 0 to CACHE_SIZE-1;
    signal cache_tag   : std_logic_vector(ADDR_WIDTH-6 downto 0);
    signal word_offset : integer range 0 to CACHE_LINE_SIZE-1;
    signal cache_hit   : std_logic;
    signal cache_miss  : std_logic;
    
    -- State machine
    type mem_state_type is (IDLE, CACHE_CHECK, CACHE_HIT_STATE, 
                           CACHE_MISS_READ, CACHE_MISS_WRITE, 
                           WRITEBACK, FILL_CACHE);
    signal mem_state : mem_state_type;
    
    -- Statistics counters
    signal hit_counter  : unsigned(15 downto 0);
    signal miss_counter : unsigned(15 downto 0);
    
    -- Internal signals
    signal fill_counter : integer range 0 to CACHE_LINE_SIZE;
    signal wb_counter   : integer range 0 to CACHE_LINE_SIZE;
    signal current_addr : unsigned(ADDR_WIDTH-1 downto 0);
    
begin
    -- Address decoding
    cache_index <= to_integer(unsigned(cpu_addr(5 downto 0)));  -- 6-bit index
    cache_tag   <= cpu_addr(ADDR_WIDTH-1 downto 6);
    word_offset <= to_integer(unsigned(cpu_addr(1 downto 0))) when CACHE_LINE_SIZE = 4 else 0;
    
    -- Cache hit detection
    cache_hit <= '1' when cache_array(cache_index).valid = '1' and 
                         cache_array(cache_index).tag = cache_tag else '0';
    cache_miss <= not cache_hit;
    
    -- Memory controller state machine
    mem_controller_fsm: process(clk, reset_n)
        variable data_word_start : integer;
        variable data_word_end   : integer;
    begin
        if reset_n = '0' then
            mem_state <= IDLE;
            cpu_ready <= '0';
            mem_read <= '0';
            mem_write <= '0';
            hit_counter <= (others => '0');
            miss_counter <= (others => '0');
            fill_counter <= 0;
            wb_counter <= 0;
            current_addr <= (others => '0');
            
            -- Initialize cache
            for i in 0 to CACHE_SIZE-1 loop
                cache_array(i).valid <= '0';
                cache_array(i).dirty <= '0';
                cache_array(i).tag <= (others => '0');
                cache_array(i).data <= (others => '0');
            end loop;
            
        elsif rising_edge(clk) then
            case mem_state is
                when IDLE =>
                    cpu_ready <= '0';
                    mem_read <= '0';
                    mem_write <= '0';
                    
                    if cpu_read = '1' or cpu_write = '1' then
                        mem_state <= CACHE_CHECK;
                    end if;
                
                when CACHE_CHECK =>
                    if cache_hit = '1' then
                        mem_state <= CACHE_HIT_STATE;
                        hit_counter <= hit_counter + 1;
                    else
                        miss_counter <= miss_counter + 1;
                        
                        -- Check if we need to writeback dirty line
                        if cache_array(cache_index).valid = '1' and 
                           cache_array(cache_index).dirty = '1' then
                            mem_state <= WRITEBACK;
                            wb_counter <= 0;
                            current_addr <= unsigned(cache_array(cache_index).tag & 
                                          std_logic_vector(to_unsigned(cache_index, 6)) & "00");
                        else
                            mem_state <= FILL_CACHE;
                            fill_counter <= 0;
                            current_addr <= unsigned(cpu_addr(ADDR_WIDTH-1 downto 2) & "00");
                        end if;
                    end if;
                
                when CACHE_HIT_STATE =>
                    -- Handle cache hit
                    if cpu_read = '1' then
                        -- Read from cache
                        data_word_start := word_offset * DATA_WIDTH;
                        data_word_end := data_word_start + DATA_WIDTH - 1;
                        cpu_data_out <= cache_array(cache_index).data(data_word_end downto data_word_start);
                        cpu_ready <= '1';
                        mem_state <= IDLE;
                        
                    elsif cpu_write = '1' then
                        -- Write to cache
                        data_word_start := word_offset * DATA_WIDTH;
                        data_word_end := data_word_start + DATA_WIDTH - 1;
                        cache_array(cache_index).data(data_word_end downto data_word_start) <= cpu_data_in;
                        cache_array(cache_index).dirty <= '1';
                        cpu_ready <= '1';
                        mem_state <= IDLE;
                    end if;
                
                when WRITEBACK =>
                    -- Write dirty cache line back to memory
                    mem_addr <= std_logic_vector(current_addr);
                    data_word_start := wb_counter * DATA_WIDTH;
                    data_word_end := data_word_start + DATA_WIDTH - 1;
                    mem_data_out <= cache_array(cache_index).data(data_word_end downto data_word_start);
                    mem_write <= '1';
                    
                    if mem_ready = '1' then
                        wb_counter <= wb_counter + 1;
                        current_addr <= current_addr + 1;
                        
                        if wb_counter = CACHE_LINE_SIZE - 1 then
                            mem_write <= '0';
                            cache_array(cache_index).dirty <= '0';
                            mem_state <= FILL_CACHE;
                            fill_counter <= 0;
                            current_addr <= unsigned(cpu_addr(ADDR_WIDTH-1 downto 2) & "00");
                        end if;
                    end if;
                
                when FILL_CACHE =>
                    -- Fill cache line from memory
                    mem_addr <= std_logic_vector(current_addr);
                    mem_read <= '1';
                    
                    if mem_ready = '1' then
                        data_word_start := fill_counter * DATA_WIDTH;
                        data_word_end := data_word_start + DATA_WIDTH - 1;
                        cache_array(cache_index).data(data_word_end downto data_word_start) <= mem_data_in;
                        
                        fill_counter <= fill_counter + 1;
                        current_addr <= current_addr + 1;
                        
                        if fill_counter = CACHE_LINE_SIZE - 1 then
                            mem_read <= '0';
                            cache_array(cache_index).valid <= '1';
                            cache_array(cache_index).dirty <= '0';
                            cache_array(cache_index).tag <= cache_tag;
                            mem_state <= CACHE_HIT_STATE;  -- Now handle the original request
                        end if;
                    end if;
                
                when others =>
                    mem_state <= IDLE;
            end case;
        end if;
    end process;
    
    -- Output statistics
    cache_hits <= std_logic_vector(hit_counter);
    cache_misses <= std_logic_vector(miss_counter);
    
end architecture behavioral;
```

## 🔍 **Instruction Decoder & Control Unit**
```vhdl
-- Instruction Decoder and Control Unit
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instruction_decoder is
    generic (
        INSTRUCTION_WIDTH : integer := 8;
        CONTROL_WIDTH     : integer := 16
    );
    port (
        clk               : in  std_logic;
        reset_n           : in  std_logic;
        -- Instruction input
        instruction       : in  std_logic_vector(INSTRUCTION_WIDTH-1 downto 0);
        instruction_valid : in  std_logic;
        -- Control outputs
        alu_operation     : out std_logic_vector(3 downto 0);
        reg_write_enable  : out std_logic;
        reg_read_addr1    : out std_logic_vector(2 downto 0);
        reg_read_addr2    : out std_logic_vector(2 downto 0);
        reg_write_addr    : out std_logic_vector(2 downto 0);
        mem_read          : out std_logic;
        mem_write         : out std_logic;
        branch_enable     : out std_logic;
        branch_condition  : out std_logic_vector(2 downto 0);
        immediate_enable  : out std_logic;
        immediate_value   : out std_logic_vector(7 downto 0);
        -- Pipeline control
        stall_request     : out std_logic;
        flush_request     : out std_logic;
        -- Exception handling
        illegal_instruction : out std_logic;
        privilege_violation : out std_logic
    );
end entity instruction_decoder;

architecture behavioral of instruction_decoder is
    -- Instruction format fields
    signal inst_type    : std_logic_vector(1 downto 0);
    signal inst_opcode  : std_logic_vector(2 downto 0);
    signal inst_reg     : std_logic_vector(2 downto 0);
    
    -- Decoded control signals
    signal control_word : std_logic_vector(CONTROL_WIDTH-1 downto 0);
    
    -- Instruction categories
    constant INST_ALU     : std_logic_vector(1 downto 0) := "00";
    constant INST_MEMORY  : std_logic_vector(1 downto 0) := "01";
    constant INST_BRANCH  : std_logic_vector(1 downto 0) := "10";
    constant INST_SPECIAL : std_logic_vector(1 downto 0) := "11";
    
begin
    -- Extract instruction fields
    inst_type   <= instruction(7 downto 6);
    inst_opcode <= instruction(5 downto 3);
    inst_reg    <= instruction(2 downto 0);
    
    -- Main instruction decoder
    decoder_process: process(clk, reset_n)
    begin
        if reset_n = '0' then
            alu_operation <= (others => '0');
            reg_write_enable <= '0';
            reg_read_addr1 <= (others => '0');
            reg_read_addr2 <= (others => '0');
            reg_write_addr <= (others => '0');
            mem_read <= '0';
            mem_write <= '0';
            branch_enable <= '0';
            branch_condition <= (others => '0');
            immediate_enable <= '0';
            immediate_value <= (others => '0');
            stall_request <= '0';
            flush_request <= '0';
            illegal_instruction <= '0';
            privilege_violation <= '0';
            
        elsif rising_edge(clk) then
            if instruction_valid = '1' then
                -- Default values
                reg_write_enable <= '0';
                mem_read <= '0';
                mem_write <= '0';
                branch_enable <= '0';
                immediate_enable <= '0';
                stall_request <= '0';
                flush_request <= '0';
                illegal_instruction <= '0';
                privilege_violation <= '0';
                
                case inst_type is
                    when INST_ALU =>  -- ALU instructions
                        alu_operation <= '0' & inst_opcode;
                        reg_write_enable <= '1';
                        reg_read_addr1 <= "000";  -- Accumulator
                        reg_read_addr2 <= inst_reg;
                        reg_write_addr <= "000";  -- Write back to accumulator
                        
                        case inst_opcode is
                            when "000" =>  -- ADD
                                null;  -- Default settings apply
                            when "001" =>  -- SUB
                                null;
                            when "010" =>  -- AND
                                null;
                            when "011" =>  -- OR
                                null;
                            when "100" =>  -- XOR
                                null;
                            when "101" =>  -- SHL
                                null;
                            when "110" =>  -- SHR
                                null;
                            when others =>  -- CMP
                                reg_write_enable <= '0';  -- Don't write result for compare
                        end case;
                    
                    when INST_MEMORY =>  -- Memory instructions
                        case inst_opcode is
                            when "000" =>  -- LOAD acc, [reg]
                                mem_read <= '1';
                                reg_write_enable <= '1';
                                reg_read_addr1 <= inst_reg;  -- Address register
                                reg_write_addr <= "000";     -- Accumulator
                            
                            when "001" =>  -- STORE [reg], acc
                                mem_write <= '1';
                                reg_read_addr1 <= inst_reg;  -- Address register
                                reg_read_addr2 <= "000";     -- Accumulator (data)
                            
                            when "010" =>  -- LOAD reg, immediate
                                immediate_enable <= '1';
                                reg_write_enable <= '1';
                                reg_write_addr <= inst_reg;
                                stall_request <= '1';  -- Need to fetch immediate value
                            
                            when "011" =>  -- MOVE reg, acc
                                reg_write_enable <= '1';
                                reg_read_addr1 <= "000";     -- Accumulator
                                reg_write_addr <= inst_reg;
                            
                            when "100" =>  -- MOVE acc, reg
                                reg_write_enable <= '1';
                                reg_read_addr1 <= inst_reg;
                                reg_write_addr <= "000";     -- Accumulator
                            
                            when others =>
                                illegal_instruction <= '1';
                        end case;
                    
                    when INST_BRANCH =>  -- Branch instructions
                        branch_enable <= '1';
                        branch_condition <= inst_opcode;
                        reg_read_addr1 <= inst_reg;  -- Branch target register
                        flush_request <= '1';  -- Flush pipeline on branch
                        
                        case inst_opcode is
                            when "000" =>  -- JMP (unconditional)
                                null;
                            when "001" =>  -- JZ (jump if zero)
                                null;
                            when "010" =>  -- JNZ (jump if not zero)
                                null;
                            when "011" =>  -- JC (jump if carry)
                                null;
                            when "100" =>  -- JNC (jump if no carry)
                                null;
                            when "101" =>  -- CALL
                                mem_write <= '1';  -- Push return address
                            when "110" =>  -- RET
                                mem_read <= '1';   -- Pop return address
                            when others =>
                                illegal_instruction <= '1';
                        end case;
                    
                    when INST_SPECIAL =>  -- Special instructions
                        case inst_opcode is
                            when "000" =>  -- NOP
                                null;  -- No operation
                            
                            when "001" =>  -- HALT
                                stall_request <= '1';  -- Stop pipeline
                            
                            when "010" =>  -- EI (Enable Interrupts)
                                -- Privileged instruction check could go here
                                null;
                            
                            when "011" =>  -- DI (Disable Interrupts)
                                -- Privileged instruction check could go here
                                null;
                            
                            when "100" =>  -- PUSH acc
                                mem_write <= '1';
                                reg_read_addr1 <= "000";  -- Accumulator
                            
                            when "101" =>  -- POP acc
                                mem_read <= '1';
                                reg_write_enable <= '1';
                                reg_write_addr <= "000";  -- Accumulator
                            
                            when "110" =>  -- IN acc, port
                                -- I/O instruction
                                reg_write_enable <= '1';
                                reg_write_addr <= "000";
                                immediate_enable <= '1';  -- Port number as immediate
                            
                            when "111" =>  -- OUT port, acc
                                -- I/O instruction
                                reg_read_addr1 <= "000";  -- Accumulator
                                immediate_enable <= '1';  -- Port number as immediate
                            
                            when others =>
                                illegal_instruction <= '1';
                        end case;
                    
                    when others =>
                        illegal_instruction <= '1';
                end case;
            end if;
        end if;
    end process;
    
end architecture behavioral;
```

## 🏗️ **Complete Microcontroller System Integration**
```vhdl
-- Complete 8-bit Microcontroller System
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity microcontroller_system is
    generic (
        CLOCK_FREQ     : integer := 50_000_000;  -- 50 MHz
        BAUD_RATE      : integer := 9600;
        RAM_SIZE       : integer := 1024;        -- 1KB RAM
        ROM_SIZE       : integer := 2048         -- 2KB ROM
    );
    port (
        clk            : in  std_logic;
        reset_n        : in  std_logic;
        -- External I/O
        gpio_in        : in  std_logic_vector(7 downto 0);
        gpio_out       : out std_logic_vector(7 downto 0);
        gpio_dir       : out std_logic_vector(7 downto 0);  -- 1=output, 0=input
        -- UART interface
        uart_tx        : out std_logic;
        uart_rx        : in  std_logic;
        -- SPI interface
        spi_sclk       : out std_logic;
        spi_mosi       : out std_logic;
        spi_miso       : in  std_logic;
        spi_cs         : out std_logic_vector(3 downto 0);
        -- I2C interface
        i2c_sda        : inout std_logic;
        i2c_scl        : inout std_logic;
        -- Interrupt inputs
        ext_int        : in  std_logic_vector(3 downto 0);
        -- Debug interface
        debug_pc       : out std_logic_vector(15 downto 0);
        debug_state    : out std_logic_vector(3 downto 0);
        debug_registers: out std_logic_vector(127 downto 0)  -- 16 x 8-bit registers
    );
end entity microcontroller_system;

architecture structural of microcontroller_system is
    -- Internal bus signals
    signal cpu_addr        : std_logic_vector(15 downto 0);
    signal cpu_data_out    : std_logic_vector(7 downto 0);
    signal cpu_data_in     : std_logic_vector(7 downto 0);
    signal cpu_read        : std_logic;
    signal cpu_write       : std_logic;
    signal cpu_ready       : std_logic;
    
    -- Memory interface signals
    signal mem_addr        : std_logic_vector(15 downto 0);
    signal mem_data_in     : std_logic_vector(7 downto 0);
    signal mem_data_out    : std_logic_vector(7 downto 0);
    signal mem_read        : std_logic;
    signal mem_write       : std_logic;
    signal mem_ready       : std_logic;
    
    -- Peripheral select signals
    signal ram_select      : std_logic;
    signal rom_select      : std_logic;
    signal uart_select     : std_logic;
    signal gpio_select     : std_logic;
    signal spi_select      : std_logic;
    signal i2c_select      : std_logic;
    signal timer_select    : std_logic;
    
    -- Peripheral data outputs
    signal ram_data_out    : std_logic_vector(7 downto 0);
    signal rom_data_out    : std_logic_vector(7 downto 0);
    signal uart_data_out   : std_logic_vector(7 downto 0);
    signal gpio_data_out   : std_logic_vector(7 downto 0);
    signal spi_data_out    : std_logic_vector(7 downto 0);
    signal i2c_data_out    : std_logic_vector(7 downto 0);
    signal timer_data_out  : std_logic_vector(7 downto 0);
    
    -- Peripheral ready signals
    signal ram_ready       : std_logic;
    signal rom_ready       : std_logic;
    signal uart_ready      : std_logic;
    signal gpio_ready      : std_logic;
    signal spi_ready       : std_logic;
    signal i2c_ready       : std_logic;
    signal timer_ready     : std_logic;
    
    -- Interrupt signals
    signal interrupt_req   : std_logic;
    signal interrupt_ack   : std_logic;
    signal timer_interrupt : std_logic;
    signal uart_interrupt  : std_logic;
    
    -- Clock and reset
    signal system_clk      : std_logic;
    signal system_reset_n  : std_logic;
    
begin
    -- Clock and reset management
    system_clk <= clk;
    system_reset_n <= reset_n;
    
    -- Address decoding
    -- Memory map:
    -- 0x0000-0x03FF: RAM (1KB)
    -- 0x0400-0x0BFF: ROM (2KB)  
    -- 0xF000-0xF00F: UART
    -- 0xF010-0xF01F: GPIO
    -- 0xF020-0xF02F: SPI
    -- 0xF030-0xF03F: I2C
    -- 0xF040-0xF04F: Timer
    
    ram_select   <= '1' when unsigned(cpu_addr) < RAM_SIZE else '0';
    rom_select   <= '1' when unsigned(cpu_addr) >= 16#0400# and 
                            unsigned(cpu_addr) < (16#0400# + ROM_SIZE) else '0';
    uart_select  <= '1' when cpu_addr(15 downto 4) = x"F00" else '0';
    gpio_select  <= '1' when cpu_addr(15 downto 4) = x"F01" else '0';
    spi_select   <= '1' when cpu_addr(15 downto 4) = x"F02" else '0';
    i2c_select   <= '1' when cpu_addr(15 downto 4) = x"F03" else '0';
    timer_select <= '1' when cpu_addr(15 downto 4) = x"F04" else '0';
    
    -- Data bus multiplexer
    cpu_data_in <= ram_data_out   when ram_select = '1' else
                   rom_data_out   when rom_select = '1' else
                   uart_data_out  when uart_select = '1' else
                   gpio_data_out  when gpio_select = '1' else
                   spi_data_out   when spi_select = '1' else
                   i2c_data_out   when i2c_select = '1' else
                   timer_data_out when timer_select = '1' else
                   (others => '0');
    
    -- Ready signal OR gate
    cpu_ready <= ram_ready or rom_ready or uart_ready or gpio_ready or 
                 spi_ready or i2c_ready or timer_ready;
    
    -- Interrupt controller (simple OR gate for this example)
    interrupt_req <= timer_interrupt or uart_interrupt or 
                     ext_int(0) or ext_int(1) or ext_int(2) or ext_int(3);
    
    -- CPU Core instantiation
    cpu_inst: entity work.cpu_core
        generic map (
            DATA_WIDTH => 8,
            ADDR_WIDTH => 16,
            REG_COUNT  => 16
        )
        port map (
            clk           => system_clk,
            reset_n       => system_reset_n,
            mem_addr      => cpu_addr,
            mem_data_in   => cpu_data_in,
            mem_data_out  => cpu_data_out,
            mem_read      => cpu_read,
            mem_write     => cpu_write,
            mem_ready     => cpu_ready,
            interrupt_req => interrupt_req,
            interrupt_ack => interrupt_ack,
            debug_pc      => debug_pc,
            debug_state   => debug_state,
            debug_flags   => open
        );
    
    -- RAM instantiation
    ram_inst: entity work.ram_module
        generic map (
            ADDR_WIDTH => 10,  -- 1KB = 2^10
            DATA_WIDTH => 8
        )
        port map (
            clk       => system_clk,
            reset_n   => system_reset_n,
            addr      => cpu_addr(9 downto 0),
            data_in   => cpu_data_out,
            data_out  => ram_data_out,
            read_en   => cpu_read and ram_select,
            write_en  => cpu_write and ram_select,
            ready     => ram_ready
        );
    
    -- ROM instantiation
    rom_inst: entity work.rom_module
        generic map (
            ADDR_WIDTH => 11,  -- 2KB = 2^11
            DATA_WIDTH => 8
        )
        port map (
            clk       => system_clk,
            reset_n   => system_reset_n,
            addr      => cpu_addr(10 downto 0),
            data_out  => rom_data_out,
            read_en   => cpu_read and rom_select,
            ready     => rom_ready
        );
    
    -- UART instantiation
    uart_inst: entity work.uart_controller
        generic map (
            BAUD_RATE => BAUD_RATE,
            CLK_FREQ  => CLOCK_FREQ
        )
        port map (
            clk         => system_clk,
            reset_n     => system_reset_n,
            addr        => cpu_addr(3 downto 0),
            data_in     => cpu_data_out,
            data_out    => uart_data_out,
            read_en     => cpu_read and uart_select,
            write_en    => cpu_write and uart_select,
            ready       => uart_ready,
            uart_tx     => uart_tx,
            uart_rx     => uart_rx,
            interrupt   => uart_interrupt
        );
    
    -- GPIO instantiation
    gpio_inst: entity work.gpio_controller
        port map (
            clk         => system_clk,
            reset_n     => system_reset_n,
            addr        => cpu_addr(3 downto 0),
            data_in     => cpu_data_out,
            data_out    => gpio_data_out,
            read_en     => cpu_read and gpio_select,
            write_en    => cpu_write and gpio_select,
            ready       => gpio_ready,
            gpio_in     => gpio_in,
            gpio_out    => gpio_out,
            gpio_dir    => gpio_dir
        );
    
    -- SPI instantiation
    spi_inst: entity work.spi_controller
        port map (
            clk         => system_clk,
            reset_n     => system_reset_n,
            addr        => cpu_addr(3 downto 0),
            data_in     => cpu_data_out,
            data_out    => spi_data_out,
            read_en     => cpu_read and spi_select,
            write_en    => cpu_write and spi_select,
            ready       => spi_ready,
            spi_sclk    => spi_sclk,
            spi_mosi    => spi_mosi,
            spi_miso    => spi_miso,
            spi_cs      => spi_cs
        );
    
    -- I2C instantiation
    i2c_inst: entity work.i2c_controller
        port map (
            clk         => system_clk,
            reset_n     => system_reset_n,
            addr        => cpu_addr(3 downto 0),
            data_in     => cpu_data_out,
            data_out    => i2c_data_out,
            read_en     => cpu_read and i2c_select,
            write_en    => cpu_write and i2c_select,
            ready       => i2c_ready,
            i2c_sda     => i2c_sda,
            i2c_scl     => i2c_scl
        );
    
    -- Timer instantiation
    timer_inst: entity work.timer_controller
        generic map (
            CLK_FREQ => CLOCK_FREQ
        )
        port map (
            clk         => system_clk,
            reset_n     => system_reset_n,
            addr        => cpu_addr(3 downto 0),
            data_in     => cpu_data_out,
            data_out    => timer_data_out,
            read_en     => cpu_read and timer_select,
            write_en    => cpu_write and timer_select,
            ready       => timer_ready,
            interrupt   => timer_interrupt
        );
    
    -- Debug register output (simplified - showing first 16 registers)
    debug_registers <= (others => '0');  -- Would connect to actual register file
    
end architecture structural;
```

## 🏭 **Modbus RTU/TCP Protocol Implementation**
```vhdl
-- Modbus RTU Master Controller
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity modbus_rtu_master is
    generic (
        BAUD_RATE   : integer := 9600;
        CLK_FREQ    : integer := 50_000_000
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        -- Control interface
        start_req   : in  std_logic;
        slave_addr  : in  std_logic_vector(7 downto 0);
        func_code   : in  std_logic_vector(7 downto 0);
        reg_addr    : in  std_logic_vector(15 downto 0);
        reg_count   : in  std_logic_vector(15 downto 0);
        write_data  : in  std_logic_vector(255 downto 0);  -- Max 16 registers
        read_data   : out std_logic_vector(255 downto 0);
        busy        : out std_logic;
        done        : out std_logic;
        error       : out std_logic;
        -- UART interface
        uart_tx     : out std_logic;
        uart_rx     : in  std_logic
    );
end entity modbus_rtu_master;

architecture rtl of modbus_rtu_master is
    -- Modbus function codes
    constant READ_COILS             : std_logic_vector(7 downto 0) := x"01";
    constant READ_DISCRETE_INPUTS   : std_logic_vector(7 downto 0) := x"02";
    constant READ_HOLDING_REGISTERS : std_logic_vector(7 downto 0) := x"03";
    constant READ_INPUT_REGISTERS   : std_logic_vector(7 downto 0) := x"04";
    constant WRITE_SINGLE_COIL      : std_logic_vector(7 downto 0) := x"05";
    constant WRITE_SINGLE_REGISTER  : std_logic_vector(7 downto 0) := x"06";
    constant WRITE_MULTIPLE_COILS   : std_logic_vector(7 downto 0) := x"0F";
    constant WRITE_MULTIPLE_REGS    : std_logic_vector(7 downto 0) := x"10";
    
    -- State machine
    type modbus_state_type is (IDLE, BUILD_FRAME, SEND_FRAME, WAIT_RESPONSE, 
                              RECEIVE_FRAME, VALIDATE_CRC, PARSE_RESPONSE, ERROR_STATE);
    signal state : modbus_state_type;
    
    -- Frame buffers
    signal tx_frame     : std_logic_vector(255 downto 0);
    signal rx_frame     : std_logic_vector(255 downto 0);
    signal tx_length    : integer range 0 to 32;
    signal rx_length    : integer range 0 to 32;
    signal frame_index  : integer range 0 to 32;
    
    -- CRC calculation
    signal crc_calc     : std_logic_vector(15 downto 0);
    signal crc_received : std_logic_vector(15 downto 0);
    
    -- Timing
    constant CHAR_TIME  : integer := CLK_FREQ / BAUD_RATE * 11;  -- 11 bits per char
    constant T35_TIME   : integer := CHAR_TIME * 4;  -- 3.5 character times
    signal timeout_counter : integer range 0 to T35_TIME;
    
    -- UART interface signals
    signal uart_tx_data   : std_logic_vector(7 downto 0);
    signal uart_tx_valid  : std_logic;
    signal uart_tx_ready  : std_logic;
    signal uart_rx_data   : std_logic_vector(7 downto 0);
    signal uart_rx_valid  : std_logic;
    
begin
    -- UART instance (simplified interface)
    uart_inst: entity work.uart_controller
        generic map (
            BAUD_RATE => BAUD_RATE,
            CLK_FREQ  => CLK_FREQ
        )
        port map (
            clk       => clk,
            reset_n   => reset_n,
            tx_data   => uart_tx_data,
            tx_valid  => uart_tx_valid,
            tx_ready  => uart_tx_ready,
            rx_data   => uart_rx_data,
            rx_valid  => uart_rx_valid,
            uart_tx   => uart_tx,
            uart_rx   => uart_rx
        );
    
    -- CRC-16 calculation function
    function calc_crc16(data : std_logic_vector; length : integer) return std_logic_vector is
        variable crc : std_logic_vector(15 downto 0) := x"FFFF";
        variable temp : std_logic_vector(15 downto 0);
    begin
        for i in 0 to length-1 loop
            temp := crc xor ("00000000" & data(i*8+7 downto i*8));
            for j in 0 to 7 loop
                if temp(0) = '1' then
                    temp := ('0' & temp(15 downto 1)) xor x"A001";
                else
                    temp := '0' & temp(15 downto 1);
                end if;
            end loop;
            crc := temp;
        end loop;
        return crc;
    end function;
    
    -- Main Modbus state machine
    modbus_fsm: process(clk, reset_n)
        variable byte_count : integer;
    begin
        if reset_n = '0' then
            state <= IDLE;
            busy <= '0';
            done <= '0';
            error <= '0';
            tx_length <= 0;
            rx_length <= 0;
            frame_index <= 0;
            timeout_counter <= 0;
            uart_tx_valid <= '0';
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    done <= '0';
                    error <= '0';
                    if start_req = '1' then
                        state <= BUILD_FRAME;
                        busy <= '1';
                        frame_index <= 0;
                    end if;
                
                when BUILD_FRAME =>
                    -- Build Modbus RTU frame
                    tx_frame(255 downto 248) <= slave_addr;  -- Slave address
                    tx_frame(247 downto 240) <= func_code;   -- Function code
                    tx_frame(239 downto 224) <= reg_addr;    -- Register address
                    
                    case func_code is
                        when READ_HOLDING_REGISTERS | READ_INPUT_REGISTERS =>
                            tx_frame(223 downto 208) <= reg_count;  -- Register count
                            tx_length <= 6;  -- 4 bytes + 2 CRC
                            
                        when WRITE_SINGLE_REGISTER =>
                            tx_frame(223 downto 208) <= write_data(15 downto 0);
                            tx_length <= 6;  -- 4 bytes + 2 CRC
                            
                        when WRITE_MULTIPLE_REGS =>
                            tx_frame(223 downto 208) <= reg_count;  -- Register count
                            byte_count := to_integer(unsigned(reg_count)) * 2;
                            tx_frame(207 downto 200) <= std_logic_vector(to_unsigned(byte_count, 8));
                            
                            -- Copy write data
                            for i in 0 to byte_count-1 loop
                                tx_frame(199-i*8 downto 192-i*8) <= 
                                    write_data(255-i*8 downto 248-i*8);
                            end loop;
                            
                            tx_length <= 7 + byte_count;
                            
                        when others =>
                            state <= ERROR_STATE;
                    end case;
                    
                    -- Calculate and append CRC
                    crc_calc <= calc_crc16(tx_frame(255 downto 256-tx_length*8), tx_length-2);
                    tx_frame(15 downto 0) <= crc_calc;  -- CRC at end of frame
                    
                    state <= SEND_FRAME;
                
                when SEND_FRAME =>
                    if uart_tx_ready = '1' and frame_index < tx_length then
                        uart_tx_data <= tx_frame(255-frame_index*8 downto 248-frame_index*8);
                        uart_tx_valid <= '1';
                        frame_index <= frame_index + 1;
                    elsif frame_index >= tx_length then
                        uart_tx_valid <= '0';
                        state <= WAIT_RESPONSE;
                        timeout_counter <= T35_TIME;
                        frame_index <= 0;
                    else
                        uart_tx_valid <= '0';
                    end if;
                
                when WAIT_RESPONSE =>
                    if uart_rx_valid = '1' then
                        state <= RECEIVE_FRAME;
                        timeout_counter <= T35_TIME;
                    elsif timeout_counter = 0 then
                        state <= ERROR_STATE;
                        error <= '1';
                    else
                        timeout_counter <= timeout_counter - 1;
                    end if;
                
                when RECEIVE_FRAME =>
                    if uart_rx_valid = '1' then
                        rx_frame(255-frame_index*8 downto 248-frame_index*8) <= uart_rx_data;
                        frame_index <= frame_index + 1;
                        timeout_counter <= T35_TIME;  -- Reset timeout
                    elsif timeout_counter = 0 then
                        -- End of frame detected
                        rx_length <= frame_index;
                        state <= VALIDATE_CRC;
                    else
                        timeout_counter <= timeout_counter - 1;
                    end if;
                
                when VALIDATE_CRC =>
                    -- Extract received CRC
                    crc_received <= rx_frame(15 downto 0);
                    -- Calculate CRC of received data
                    crc_calc <= calc_crc16(rx_frame(255 downto 16), rx_length-2);
                    
                    if crc_calc = crc_received then
                        state <= PARSE_RESPONSE;
                    else
                        state <= ERROR_STATE;
                        error <= '1';
                    end if;
                
                when PARSE_RESPONSE =>
                    -- Check slave address and function code
                    if rx_frame(255 downto 248) = slave_addr and 
                       rx_frame(247 downto 240) = func_code then
                        -- Extract data based on function code
                        case func_code is
                            when READ_HOLDING_REGISTERS | READ_INPUT_REGISTERS =>
                                byte_count := to_integer(unsigned(rx_frame(239 downto 232)));
                                for i in 0 to byte_count-1 loop
                                    read_data(255-i*8 downto 248-i*8) <= 
                                        rx_frame(231-i*8 downto 224-i*8);
                                end loop;
                            
                            when others =>
                                null;  -- Other function codes
                        end case;
                        
                        state <= IDLE;
                        busy <= '0';
                        done <= '1';
                    else
                        state <= ERROR_STATE;
                        error <= '1';
                    end if;
                
                when ERROR_STATE =>
                    busy <= '0';
                    error <= '1';
                    if start_req = '0' then
                        state <= IDLE;
                        error <= '0';
                    end if;
            end case;
        end if;
    end process;
    
end architecture rtl;
```

## 🌐 **SNMP Protocol Implementation**
```vhdl
-- SNMP Agent with Basic MIB Support
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity snmp_agent is
    generic (
        UDP_PORT    : integer := 161;
        COMMUNITY   : string := "public"
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        -- Network interface
        udp_rx_data : in  std_logic_vector(7 downto 0);
        udp_rx_valid: in  std_logic;
        udp_rx_sof  : in  std_logic;
        udp_rx_eof  : in  std_logic;
        udp_tx_data : out std_logic_vector(7 downto 0);
        udp_tx_valid: out std_logic;
        udp_tx_sof  : out std_logic;
        udp_tx_eof  : out std_logic;
        udp_tx_ready: in  std_logic;
        -- MIB interface
        mib_oid     : out std_logic_vector(127 downto 0);
        mib_value   : in  std_logic_vector(31 downto 0);
        mib_valid   : in  std_logic;
        mib_error   : in  std_logic;
        -- Status
        snmp_requests : out std_logic_vector(31 downto 0);
        snmp_responses: out std_logic_vector(31 downto 0)
    );
end entity snmp_agent;

architecture rtl of snmp_agent is
    -- SNMP PDU types
    constant GET_REQUEST    : std_logic_vector(7 downto 0) := x"A0";
    constant GET_NEXT_REQ   : std_logic_vector(7 downto 0) := x"A1";
    constant GET_RESPONSE   : std_logic_vector(7 downto 0) := x"A2";
    constant SET_REQUEST    : std_logic_vector(7 downto 0) := x"A3";
    constant TRAP           : std_logic_vector(7 downto 0) := x"A4";
    
    -- ASN.1 types
    constant ASN1_INTEGER   : std_logic_vector(7 downto 0) := x"02";
    constant ASN1_OCTET_STR : std_logic_vector(7 downto 0) := x"04";
    constant ASN1_NULL      : std_logic_vector(7 downto 0) := x"05";
    constant ASN1_OID       : std_logic_vector(7 downto 0) := x"06";
    constant ASN1_SEQUENCE  : std_logic_vector(7 downto 0) := x"30";
    
    -- State machine
    type snmp_state_type is (IDLE, PARSE_HEADER, PARSE_COMMUNITY, 
                            PARSE_PDU, PARSE_VARBIND, PROCESS_REQUEST,
                            BUILD_RESPONSE, SEND_RESPONSE);
    signal state : snmp_state_type;
    
    -- Packet buffers
    signal rx_buffer    : std_logic_vector(1023 downto 0);
    signal tx_buffer    : std_logic_vector(1023 downto 0);
    signal rx_index     : integer range 0 to 127;
    signal tx_index     : integer range 0 to 127;
    signal packet_length: integer range 0 to 127;
    
    -- SNMP message fields
    signal version      : std_logic_vector(7 downto 0);
    signal community_str: std_logic_vector(63 downto 0);
    signal pdu_type     : std_logic_vector(7 downto 0);
    signal request_id   : std_logic_vector(31 downto 0);
    signal error_status : std_logic_vector(7 downto 0);
    signal error_index  : std_logic_vector(7 downto 0);
    
    -- Statistics
    signal req_counter  : unsigned(31 downto 0);
    signal resp_counter : unsigned(31 downto 0);
    
begin
    -- SNMP packet processing
    snmp_processor: process(clk, reset_n)
        variable oid_length : integer;
        variable value_length : integer;
    begin
        if reset_n = '0' then
            state <= IDLE;
            rx_index <= 0;
            tx_index <= 0;
            packet_length <= 0;
            version <= (others => '0');
            pdu_type <= (others => '0');
            request_id <= (others => '0');
            error_status <= (others => '0');
            error_index <= (others => '0');
            req_counter <= (others => '0');
            resp_counter <= (others => '0');
            udp_tx_valid <= '0';
            udp_tx_sof <= '0';
            udp_tx_eof <= '0';
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    udp_tx_valid <= '0';
                    udp_tx_sof <= '0';
                    udp_tx_eof <= '0';
                    
                    if udp_rx_sof = '1' then
                        state <= PARSE_HEADER;
                        rx_index <= 0;
                        packet_length <= 0;
                    end if;
                
                when PARSE_HEADER =>
                    if udp_rx_valid = '1' then
                        rx_buffer(1023-rx_index*8 downto 1016-rx_index*8) <= udp_rx_data;
                        rx_index <= rx_index + 1;
                        
                        -- Parse SNMP version (after sequence header)
                        if rx_index = 4 then  -- Assuming fixed header structure
                            version <= udp_rx_data;
                            state <= PARSE_COMMUNITY;
                        end if;
                    elsif udp_rx_eof = '1' then
                        packet_length <= rx_index;
                        state <= IDLE;  -- Incomplete packet
                    end if;
                
                when PARSE_COMMUNITY =>
                    if udp_rx_valid = '1' then
                        rx_buffer(1023-rx_index*8 downto 1016-rx_index*8) <= udp_rx_data;
                        rx_index <= rx_index + 1;
                        
                        -- Simple community string check (first 6 bytes = "public")
                        if rx_index >= 10 then  -- After community string
                            state <= PARSE_PDU;
                        end if;
                    elsif udp_rx_eof = '1' then
                        packet_length <= rx_index;
                        state <= IDLE;
                    end if;
                
                when PARSE_PDU =>
                    if udp_rx_valid = '1' then
                        rx_buffer(1023-rx_index*8 downto 1016-rx_index*8) <= udp_rx_data;
                        
                        -- Parse PDU type
                        if rx_index = 12 then  -- PDU type position
                            pdu_type <= udp_rx_data;
                        elsif rx_index >= 16 and rx_index <= 19 then
                            -- Parse request ID (4 bytes)
                            request_id((19-rx_index)*8+7 downto (19-rx_index)*8) <= udp_rx_data;
                        end if;
                        
                        rx_index <= rx_index + 1;
                        
                        if rx_index >= 22 then  -- Start of variable bindings
                            state <= PARSE_VARBIND;
                        end if;
                    elsif udp_rx_eof = '1' then
                        packet_length <= rx_index;
                        state <= PROCESS_REQUEST;
                    end if;
                
                when PARSE_VARBIND =>
                    if udp_rx_valid = '1' then
                        rx_buffer(1023-rx_index*8 downto 1016-rx_index*8) <= udp_rx_data;
                        rx_index <= rx_index + 1;
                    elsif udp_rx_eof = '1' then
                        packet_length <= rx_index;
                        state <= PROCESS_REQUEST;
                    end if;
                
                when PROCESS_REQUEST =>
                    -- Process the SNMP request
                    req_counter <= req_counter + 1;
                    
                    if pdu_type = GET_REQUEST or pdu_type = GET_NEXT_REQ then
                        -- Extract OID from variable binding
                        -- Simplified: assume single OID at fixed position
                        mib_oid <= rx_buffer(511 downto 384);  -- Example OID position
                        
                        if mib_valid = '1' then
                            state <= BUILD_RESPONSE;
                            error_status <= x"00";  -- No error
                        elsif mib_error = '1' then
                            state <= BUILD_RESPONSE;
                            error_status <= x"02";  -- No such name
                        end if;
                    else
                        -- Unsupported PDU type
                        error_status <= x"05";  -- Gen error
                        state <= BUILD_RESPONSE;
                    end if;
                
                when BUILD_RESPONSE =>
                    -- Build SNMP response packet
                    tx_index <= 0;
                    
                    -- SNMP message header
                    tx_buffer(1023 downto 1016) <= ASN1_SEQUENCE;  -- Message sequence
                    tx_buffer(1015 downto 1008) <= x"82";          -- Length (2 bytes)
                    -- ... (build complete response structure)
                    
                    -- Change PDU type to GET_RESPONSE
                    pdu_type <= GET_RESPONSE;
                    
                    state <= SEND_RESPONSE;
                
                when SEND_RESPONSE =>
                    if udp_tx_ready = '1' then
                        if tx_index = 0 then
                            udp_tx_sof <= '1';
                        else
                            udp_tx_sof <= '0';
                        end if;
                        
                        udp_tx_data <= tx_buffer(1023-tx_index*8 downto 1016-tx_index*8);
                        udp_tx_valid <= '1';
                        tx_index <= tx_index + 1;
                        
                        if tx_index >= packet_length-1 then
                            udp_tx_eof <= '1';
                            resp_counter <= resp_counter + 1;
                            state <= IDLE;
                        end if;
                    end if;
            end case;
        end if;
    end process;
    
    -- Output statistics
    snmp_requests <= std_logic_vector(req_counter);
    snmp_responses <= std_logic_vector(resp_counter);
    
end architecture rtl;
```

## 🚀 **SPI Protocol Implementation**
```vhdl
-- SPI Master with Configurable Parameters
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
    generic (
        DATA_WIDTH  : integer := 8;      -- Data width (8, 16, 32)
        CLK_DIV     : integer := 4;      -- Clock divider
        CPOL        : std_logic := '0';  -- Clock polarity
        CPHA        : std_logic := '0'   -- Clock phase
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        -- Control interface
        start       : in  std_logic;
        data_in     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_out    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        busy        : out std_logic;
        done        : out std_logic;
        -- SPI interface
        sclk        : out std_logic;
        mosi        : out std_logic;
        miso        : in  std_logic;
        cs_n        : out std_logic_vector(7 downto 0)  -- 8 chip selects
    );
end entity spi_master;

architecture rtl of spi_master is
    type spi_state_type is (IDLE, ACTIVE, DONE_STATE);
    signal state : spi_state_type;
    
    signal sclk_int     : std_logic;
    signal bit_counter  : integer range 0 to DATA_WIDTH-1;
    signal clk_counter  : integer range 0 to CLK_DIV-1;
    signal shift_reg    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal cs_select    : integer range 0 to 7;
    
begin
    spi_process: process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            sclk_int <= CPOL;
            bit_counter <= DATA_WIDTH-1;
            clk_counter <= 0;
            shift_reg <= (others => '0');
            busy <= '0';
            done <= '0';
            cs_n <= (others => '1');
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    done <= '0';
                    if start = '1' then
                        state <= ACTIVE;
                        busy <= '1';
                        shift_reg <= data_in;
                        bit_counter <= DATA_WIDTH-1;
                        cs_n(cs_select) <= '0';  -- Select slave
                    end if;
                
                when ACTIVE =>
                    if clk_counter = CLK_DIV-1 then
                        clk_counter <= 0;
                        sclk_int <= not sclk_int;
                        
                        -- Data transfer on appropriate clock edge
                        if (sclk_int = CPOL and CPHA = '0') or 
                           (sclk_int = not CPOL and CPHA = '1') then
                            -- Sample MISO
                            shift_reg <= shift_reg(DATA_WIDTH-2 downto 0) & miso;
                            
                            if bit_counter = 0 then
                                state <= DONE_STATE;
                                data_out <= shift_reg(DATA_WIDTH-2 downto 0) & miso;
                            else
                                bit_counter <= bit_counter - 1;
                            end if;
                        end if;
                    else
                        clk_counter <= clk_counter + 1;
                    end if;
                
                when DONE_STATE =>
                    busy <= '0';
                    done <= '1';
                    cs_n <= (others => '1');  -- Deselect all slaves
                    sclk_int <= CPOL;
                    state <= IDLE;
            end case;
        end if;
    end process;
    
    -- Output assignments
    sclk <= sclk_int;
    mosi <= shift_reg(DATA_WIDTH-1);
    
end architecture rtl;
```

## 🚗 **CAN Bus Protocol Implementation**
```vhdl
-- CAN Bus Controller with Error Handling
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity can_controller is
    generic (
        BIT_RATE    : integer := 500_000;  -- 500 kbps
        CLK_FREQ    : integer := 50_000_000
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        -- Message interface
        tx_start    : in  std_logic;
        tx_id       : in  std_logic_vector(10 downto 0);  -- 11-bit ID
        tx_data     : in  std_logic_vector(63 downto 0);  -- 8 bytes max
        tx_dlc      : in  std_logic_vector(3 downto 0);   -- Data length
        tx_busy     : out std_logic;
        tx_done     : out std_logic;
        tx_error    : out std_logic;
        -- Receive interface
        rx_valid    : out std_logic;
        rx_id       : out std_logic_vector(10 downto 0);
        rx_data     : out std_logic_vector(63 downto 0);
        rx_dlc      : out std_logic_vector(3 downto 0);
        rx_error    : out std_logic;
        -- CAN bus
        can_tx      : out std_logic;
        can_rx      : in  std_logic
    );
end entity can_controller;

architecture rtl of can_controller is
    -- CAN frame structure
    type can_tx_state_type is (IDLE, SOF, ARBITRATION, CONTROL, DATA, 
                              CRC, ACK, EOF, ERROR_FRAME);
    signal tx_state : can_tx_state_type;
    
    type can_rx_state_type is (RX_IDLE, RX_SOF, RX_ARBITRATION, RX_CONTROL, 
                              RX_DATA, RX_CRC, RX_ACK, RX_EOF);
    signal rx_state : can_rx_state_type;
    
    -- Bit timing
    constant BIT_TIME : integer := CLK_FREQ / BIT_RATE;
    signal bit_timer : integer range 0 to BIT_TIME-1;
    signal bit_sample : std_logic;
    
    -- TX signals
    signal tx_shift_reg : std_logic_vector(127 downto 0);  -- Max frame size
    signal tx_bit_count : integer range 0 to 127;
    signal tx_crc       : std_logic_vector(14 downto 0);
    signal tx_stuff_count : integer range 0 to 5;
    signal tx_last_bit  : std_logic;
    
    -- RX signals
    signal rx_shift_reg : std_logic_vector(127 downto 0);
    signal rx_bit_count : integer range 0 to 127;
    signal rx_crc       : std_logic_vector(14 downto 0);
    signal rx_stuff_count : integer range 0 to 5;
    signal rx_last_bit  : std_logic;
    
    -- Error detection
    signal error_count  : integer range 0 to 255;
    signal stuff_error  : std_logic;
    signal crc_error    : std_logic;
    signal ack_error    : std_logic;
    
begin
    -- Bit timing generator
    bit_timing: process(clk, reset_n)
    begin
        if reset_n = '0' then
            bit_timer <= 0;
            bit_sample <= '0';
        elsif rising_edge(clk) then
            if bit_timer = BIT_TIME-1 then
                bit_timer <= 0;
                bit_sample <= '1';
            else
                bit_timer <= bit_timer + 1;
                bit_sample <= '0';
            end if;
        end if;
    end process;
    
    -- CAN transmitter
    can_transmitter: process(clk, reset_n)
        variable frame_bits : integer;
    begin
        if reset_n = '0' then
            tx_state <= IDLE;
            tx_busy <= '0';
            tx_done <= '0';
            tx_error <= '0';
            can_tx <= '1';  -- Recessive state
            tx_bit_count <= 0;
            tx_crc <= (others => '0');
            tx_stuff_count <= 0;
            tx_last_bit <= '1';
            
        elsif rising_edge(clk) and bit_sample = '1' then
            case tx_state is
                when IDLE =>
                    can_tx <= '1';
                    tx_done <= '0';
                    if tx_start = '1' then
                        -- Build CAN frame
                        tx_shift_reg(127) <= '0';  -- SOF
                        tx_shift_reg(126 downto 116) <= tx_id;  -- ID
                        tx_shift_reg(115) <= '0';  -- RTR
                        tx_shift_reg(114) <= '0';  -- IDE
                        tx_shift_reg(113) <= '0';  -- r0
                        tx_shift_reg(112 downto 109) <= tx_dlc;  -- DLC
                        
                        -- Data field
                        for i in 0 to 7 loop
                            if i < to_integer(unsigned(tx_dlc)) then
                                tx_shift_reg(108-i*8 downto 101-i*8) <= 
                                    tx_data(63-i*8 downto 56-i*8);
                            end if;
                        end loop;
                        
                        tx_state <= SOF;
                        tx_busy <= '1';
                        tx_bit_count <= 0;
                        frame_bits := 44 + to_integer(unsigned(tx_dlc)) * 8;
                    end if;
                
                when SOF =>
                    can_tx <= tx_shift_reg(127-tx_bit_count);
                    tx_bit_count <= tx_bit_count + 1;
                    if tx_bit_count = 0 then  -- SOF is 1 bit
                        tx_state <= ARBITRATION;
                    end if;
                
                when ARBITRATION =>
                    can_tx <= tx_shift_reg(127-tx_bit_count);
                    -- Check for arbitration loss
                    if can_tx = '1' and can_rx = '0' then
                        tx_state <= IDLE;  -- Lost arbitration
                        tx_busy <= '0';
                        tx_error <= '1';
                    else
                        tx_bit_count <= tx_bit_count + 1;
                        if tx_bit_count = 11 then  -- 11-bit ID
                            tx_state <= CONTROL;
                        end if;
                    end if;
                
                when CONTROL =>
                    can_tx <= tx_shift_reg(127-tx_bit_count);
                    tx_bit_count <= tx_bit_count + 1;
                    if tx_bit_count = 17 then  -- Control field complete
                        tx_state <= DATA;
                    end if;
                
                when DATA =>
                    can_tx <= tx_shift_reg(127-tx_bit_count);
                    tx_bit_count <= tx_bit_count + 1;
                    if tx_bit_count = 17 + to_integer(unsigned(tx_dlc)) * 8 then
                        tx_state <= CRC;
                    end if;
                
                when CRC =>
                    -- Transmit 15-bit CRC + delimiter
                    if tx_bit_count < frame_bits + 16 then
                        can_tx <= tx_crc(14-(tx_bit_count-frame_bits));
                        tx_bit_count <= tx_bit_count + 1;
                    else
                        tx_state <= ACK;
                        can_tx <= '1';  -- ACK delimiter (recessive)
                    end if;
                
                when ACK =>
                    -- Wait for ACK from receiver
                    if can_rx = '0' then  -- ACK received
                        tx_state <= EOF;
                        tx_bit_count <= 0;
                    else
                        ack_error <= '1';
                        tx_state <= ERROR_FRAME;
                    end if;
                
                when EOF =>
                    can_tx <= '1';  -- EOF is 7 recessive bits
                    tx_bit_count <= tx_bit_count + 1;
                    if tx_bit_count = 6 then
                        tx_state <= IDLE;
                        tx_busy <= '0';
                        tx_done <= '1';
                    end if;
                
                when ERROR_FRAME =>
                    can_tx <= '0';  -- Error flag (6 dominant bits)
                    tx_bit_count <= tx_bit_count + 1;
                    if tx_bit_count = 5 then
                        tx_state <= IDLE;
                        tx_busy <= '0';
                        tx_error <= '1';
                    end if;
            end case;
        end if;
    end process;
    
    -- CAN receiver (simplified)
    can_receiver: process(clk, reset_n)
    begin
        if reset_n = '0' then
            rx_state <= RX_IDLE;
            rx_valid <= '0';
            rx_error <= '0';
            rx_bit_count <= 0;
            
        elsif rising_edge(clk) and bit_sample = '1' then
            case rx_state is
                when RX_IDLE =>
                    rx_valid <= '0';
                    if can_rx = '0' then  -- SOF detected
                        rx_state <= RX_SOF;
                        rx_bit_count <= 0;
                    end if;
                
                when RX_SOF =>
                    rx_state <= RX_ARBITRATION;
                
                when RX_ARBITRATION =>
                    rx_shift_reg(126-rx_bit_count) <= can_rx;
                    rx_bit_count <= rx_bit_count + 1;
                    if rx_bit_count = 10 then  -- 11-bit ID received
                        rx_id <= rx_shift_reg(126 downto 116);
                        rx_state <= RX_CONTROL;
                    end if;
                
                -- Additional RX states would be implemented similarly...
                
                when others =>
                    rx_state <= RX_IDLE;
            end case;
        end if;
    end process;
    
end architecture rtl;
```

### 📡 **Legacy Communication Systems**
```vhdl
-- High-speed serial transceiver
signal tx_data_parallel : std_logic_vector(31 downto 0);
signal rx_data_parallel : std_logic_vector(31 downto 0);
signal tx_clock_div     : unsigned(3 downto 0);
signal rx_clock_recovery: std_logic;

-- Protocol stack variables
process(clk, reset_n)
    variable packet_header  : std_logic_vector(15 downto 0);
    variable payload_length : unsigned(11 downto 0);
    variable crc_checksum   : std_logic_vector(15 downto 0);
    variable retry_count    : integer range 0 to 7;
    variable ack_timeout    : unsigned(19 downto 0);  -- 1ms timeout
begin
    if reset_n = '0' then
        packet_header := (others => '0');
        payload_length := (others => '0');
        retry_count := 0;
        ack_timeout := (others => '0');
    elsif rising_edge(clk) then
        -- Protocol state machine with timeout handling
        if ack_timeout = 0 and retry_count < 3 then
            retry_count := retry_count + 1;
            ack_timeout := to_unsigned(50000, 20);  -- Reset timeout
        elsif retry_count >= 3 then
            -- Handle communication failure
            retry_count := 0;
        end if;
    end if;
end process;
```

### 🎮 **Digital Signal Processing**
```vhdl
-- Fixed-point DSP with pipeline registers
signal sample_input     : signed(15 downto 0);
signal sample_output    : signed(15 downto 0);
signal filter_coeffs    : array(0 to 7) of signed(15 downto 0);

-- Multi-stage pipeline variables
process(clk, reset_n)
    -- Pipeline stage 1: Input buffering
    variable stage1_buffer  : array(0 to 7) of signed(15 downto 0);
    -- Pipeline stage 2: Multiplication
    variable stage2_products: array(0 to 7) of signed(31 downto 0);
    -- Pipeline stage 3: Accumulation
    variable stage3_sum     : signed(34 downto 0);  -- Extra bits for overflow
    -- Pipeline stage 4: Scaling and output
    variable stage4_scaled  : signed(15 downto 0);
begin
    if reset_n = '0' then
        -- Initialize pipeline registers
        for i in 0 to 7 loop
            stage1_buffer(i) := (others => '0');
            stage2_products(i) := (others => '0');
        end loop;
        stage3_sum := (others => '0');
        stage4_scaled := (others => '0');
    elsif rising_edge(clk) then
        -- Stage 1: Shift register for input samples
        stage1_buffer(0) := sample_input;
        for i in 1 to 7 loop
            stage1_buffer(i) := stage1_buffer(i-1);
        end loop;
        
        -- Stage 2: Parallel multiplication
        for i in 0 to 7 loop
            stage2_products(i) := stage1_buffer(i) * filter_coeffs(i);
        end loop;
        
        -- Stage 3: Tree accumulation
        stage3_sum := resize(stage2_products(0), 35) + 
                     resize(stage2_products(1), 35) +
                     resize(stage2_products(2), 35) +
                     resize(stage2_products(3), 35) +
                     resize(stage2_products(4), 35) +
                     resize(stage2_products(5), 35) +
                     resize(stage2_products(6), 35) +
                     resize(stage2_products(7), 35);
        
        -- Stage 4: Scale and saturate
        if stage3_sum > 32767 then
            stage4_scaled := to_signed(32767, 16);
        elsif stage3_sum < -32768 then
            stage4_scaled := to_signed(-32768, 16);
        else
            stage4_scaled := stage3_sum(15 downto 0);
        end if;
        
        sample_output <= stage4_scaled;
    end if;
end process;
```

### 🖥️ **CPU/Processor Design**
```vhdl
-- RISC-V style processor registers
type register_file is array(0 to 31) of std_logic_vector(31 downto 0);
signal registers : register_file;

-- Pipeline control signals
signal pc_current, pc_next : unsigned(31 downto 0);
signal instruction_fetch   : std_logic_vector(31 downto 0);
signal instruction_decode  : std_logic_vector(31 downto 0);

-- Execution unit variables
process(clk, reset_n)
    variable opcode        : std_logic_vector(6 downto 0);
    variable rs1, rs2, rd  : integer range 0 to 31;
    variable immediate     : signed(31 downto 0);
    variable alu_result    : signed(31 downto 0);
    variable branch_taken  : std_logic;
    variable memory_address: unsigned(31 downto 0);
begin
    if reset_n = '0' then
        pc_current <= (others => '0');
        for i in 0 to 31 loop
            registers(i) <= (others => '0');
        end loop;
    elsif rising_edge(clk) then
        -- Instruction decode
        opcode := instruction_decode(6 downto 0);
        rs1 := to_integer(unsigned(instruction_decode(19 downto 15)));
        rs2 := to_integer(unsigned(instruction_decode(24 downto 20)));
        rd  := to_integer(unsigned(instruction_decode(11 downto 7)));
        
        -- ALU operations based on opcode
        case opcode is
            when "0110011" =>  -- R-type instructions
                case instruction_decode(14 downto 12) is
                    when "000" =>  -- ADD/SUB
                        if instruction_decode(30) = '0' then
                            alu_result := signed(registers(rs1)) + signed(registers(rs2));
                        else
                            alu_result := signed(registers(rs1)) - signed(registers(rs2));
                        end if;
                    when "001" =>  -- SLL
                        alu_result := shift_left(signed(registers(rs1)), 
                                               to_integer(unsigned(registers(rs2)(4 downto 0))));
                    when others =>
                        alu_result := (others => '0');
                end case;
                
                -- Write back to register (x0 is hardwired to 0)
                if rd /= 0 then
                    registers(rd) <= std_logic_vector(alu_result);
                end if;
                
            when others =>
                -- Handle other instruction types
        end case;
        
        -- Program counter update
        pc_current <= pc_next;
    end if;
end process;
```

### 🌐 **Network Processing**
```vhdl
-- Ethernet packet processing
signal eth_rx_data      : std_logic_vector(7 downto 0);
signal eth_tx_data      : std_logic_vector(7 downto 0);
signal packet_valid     : std_logic;
signal packet_error     : std_logic;

-- Packet parsing variables
process(clk, reset_n)
    variable packet_buffer  : array(0 to 1517) of std_logic_vector(7 downto 0);
    variable buffer_index   : integer range 0 to 1517;
    variable packet_length  : unsigned(15 downto 0);
    variable eth_type       : std_logic_vector(15 downto 0);
    variable ip_header_len  : integer range 0 to 60;
    variable tcp_header_len : integer range 0 to 60;
    variable checksum_calc  : unsigned(15 downto 0);
begin
    if reset_n = '0' then
        buffer_index := 0;
        packet_length := (others => '0');
        checksum_calc := (others => '0');
    elsif rising_edge(clk) then
        if packet_valid = '1' then
            packet_buffer(buffer_index) := eth_rx_data;
            
            -- Parse Ethernet header
            if buffer_index = 12 then
                eth_type(15 downto 8) := eth_rx_data;
            elsif buffer_index = 13 then
                eth_type(7 downto 0) := eth_rx_data;
                
                -- Determine packet type
                if eth_type = x"0800" then  -- IPv4
                    -- Continue parsing IP header
                elsif eth_type = x"0806" then  -- ARP
                    -- Handle ARP packet
                end if;
            end if;
            
            buffer_index := buffer_index + 1;
        end if;
    end if;
end process;
```

### 🎯 **Variable Declaration Best Practices by Design Type**

#### **Real-Time Systems:**
- Use **bounded integers** for counters: `integer range 0 to MAX_COUNT`
- Implement **timeout variables** with appropriate bit widths
- Add **safety redundancy** for critical signals
- Use **fixed-point arithmetic** for deterministic timing

#### **High-Speed Systems:**
- Minimize **variable scope** to reduce logic depth
- Use **pipeline registers** for multi-stage operations
- Implement **parallel processing** with variable arrays
- Apply **register balancing** for timing closure

#### **Memory-Constrained Systems:**
- Use **packed records** for efficient storage
- Implement **shared variables** for common data
- Apply **bit-level optimization** for flags
- Use **enumerated types** instead of std_logic_vector

#### **Safety-Critical Systems:**
- Implement **dual-rail logic** for error detection
- Use **range-constrained types** to prevent overflow
- Add **parity/ECC variables** for data integrity
- Implement **watchdog counters** for fault detection

---

## ⚡ Operators & Expressions

### Logical Operators
```vhdl
result <= a and b;      -- AND
result <= a or b;       -- OR  
result <= a xor b;      -- XOR
result <= not a;        -- NOT
result <= a nand b;     -- NAND
result <= a nor b;      -- NOR
```

### Arithmetic Operators (use numeric_std)
```vhdl
-- Preferred method with numeric_std
signal a, b, sum : unsigned(7 downto 0);
signal product   : unsigned(15 downto 0);

sum <= a + b;
product <= a * b;
quotient <= a / b;      -- Synthesis support varies
remainder <= a mod b;   -- Synthesis support varies

-- Type conversions
integer_val <= to_integer(unsigned_signal);
unsigned_signal <= to_unsigned(integer_val, 8);
std_logic_vector_signal <= std_logic_vector(unsigned_signal);
```

### Comparison Operators
```vhdl
result <= '1' when a = b else '0';      -- Equality
result <= '1' when a /= b else '0';     -- Inequality
result <= '1' when a > b else '0';      -- Greater than
result <= '1' when a >= b else '0';     -- Greater or equal
result <= '1' when a < b else '0';      -- Less than
result <= '1' when a <= b else '0';     -- Less or equal
```

### Bit Manipulation
```vhdl
-- Concatenation
result <= a & b;                        -- Concatenate vectors
result <= '1' & data(6 downto 0);      -- Add bit to vector

-- Slicing
upper_nibble <= data(7 downto 4);
lower_nibble <= data(3 downto 0);

-- Shifting (VHDL-2008)
shifted_left  <= data sll 2;            -- Shift left logical
shifted_right <= data srl 2;            -- Shift right logical
rotated_left  <= data rol 1;            -- Rotate left
```

---

## 🔄 Control Structures

### Conditional Assignments
```vhdl
-- Simple conditional
output <= input1 when select_sig = '1' else input2;

-- Multiple conditions
output <= input1 when sel = "00" else
          input2 when sel = "01" else
          input3 when sel = "10" else
          input4;

-- With select statement
with sel select
    output <= input1 when "00",
              input2 when "01", 
              input3 when "10",
              input4 when others;
```

### If-Then-Else (Sequential)
```vhdl
process(clk, reset_n)
begin
    if reset_n = '0' then
        counter <= 0;
    elsif rising_edge(clk) then
        if enable = '1' then
            if counter = MAX_COUNT then
                counter <= 0;
            else
                counter <= counter + 1;
            end if;
        end if;
    end if;
end process;
```

### Case Statements (Sequential)
```vhdl
process(clk, reset_n)
begin
    if reset_n = '0' then
        output <= (others => '0');
    elsif rising_edge(clk) then
        case opcode is
            when "0000" => output <= a + b;        -- ADD
            when "0001" => output <= a - b;        -- SUB
            when "0010" => output <= a and b;      -- AND
            when "0011" => output <= a or b;       -- OR
            when others => output <= (others => '0');
        end case;
    end if;
end process;
```

### Loops (Sequential Only)
```vhdl
process(clk, reset_n)
    variable temp : std_logic_vector(7 downto 0);
begin
    if reset_n = '0' then
        output_array <= (others => (others => '0'));
    elsif rising_edge(clk) then
        -- For loop
        for i in 0 to 7 loop
            temp(i) := input_data(7-i);  -- Bit reversal
        end loop;
        
        -- While loop
        variable j : integer := 0;
        while j < 8 and temp(j) = '0' loop
            j := j + 1;
        end loop;
        
        output_data <= temp;
    end if;
end process;
```

---

## ⚖️ Concurrent vs Sequential

### Concurrent Statements (Outside Process)
```vhdl
-- Always active, order doesn't matter
output1 <= input1 and input2;
output2 <= input3 or input4;
mux_out <= data_a when sel = '0' else data_b;

-- Generate statements
gen_array: for i in 0 to 7 generate
    output_array(i) <= input_array(i) xor key(i);
end generate;
```

### Sequential Statements (Inside Process)
```vhdl
process(clk, reset_n)
begin
    if reset_n = '0' then
        -- Reset conditions
        reg1 <= (others => '0');
        reg2 <= (others => '0');
    elsif rising_edge(clk) then
        -- Order matters here!
        reg1 <= input_data;
        reg2 <= reg1;  -- Creates shift register
    end if;
end process;
```

---

## 🕐 Clocking & Reset Strategies

### Synchronous Reset (Recommended)
```vhdl
process(clk)
begin
    if rising_edge(clk) then
        if reset_n = '0' then
            -- Reset logic
            counter <= 0;
            state <= IDLE;
        else
            -- Normal operation
            counter <= counter + 1;
        end if;
    end if;
end process;
```

### Asynchronous Reset
```vhdl
process(clk, reset_n)
begin
    if reset_n = '0' then
        -- Asynchronous reset
        counter <= 0;
        state <= IDLE;
    elsif rising_edge(clk) then
        -- Normal operation
        counter <= counter + 1;
    end if;
end process;
```

### Clock Domain Crossing (CDC)
```vhdl
-- Synchronizer for single bit
process(clk_dest, reset_n)
begin
    if reset_n = '0' then
        sync_reg <= (others => '0');
    elsif rising_edge(clk_dest) then
        sync_reg <= sync_reg(1 downto 0) & async_input;
    end if;
end process;

sync_output <= sync_reg(2);  -- Synchronized output
```

---

## 🔄 State Machines

### Two-Process State Machine (Recommended)
```vhdl
type state_type is (IDLE, START, PROCESS_DATA, DONE);
signal current_state, next_state : state_type;

-- State register process
state_reg: process(clk, reset_n)
begin
    if reset_n = '0' then
        current_state <= IDLE;
    elsif rising_edge(clk) then
        current_state <= next_state;
    end if;
end process;

-- Next state logic process
next_state_logic: process(current_state, start, data_valid, counter)
begin
    next_state <= current_state;  -- Default assignment
    
    case current_state is
        when IDLE =>
            if start = '1' then
                next_state <= START;
            end if;
            
        when START =>
            if data_valid = '1' then
                next_state <= PROCESS_DATA;
            end if;
            
        when PROCESS_DATA =>
            if counter = MAX_COUNT then
                next_state <= DONE;
            end if;
            
        when DONE =>
            next_state <= IDLE;
            
        when others =>
            next_state <= IDLE;
    end case;
end process;

-- Output logic (can be concurrent or sequential)
output_logic: process(current_state, counter)
begin
    -- Default outputs
    busy <= '0';
    done <= '0';
    
    case current_state is
        when IDLE =>
            -- Outputs for IDLE state
            
        when START | PROCESS_DATA =>
            busy <= '1';
            
        when DONE =>
            done <= '1';
            
        when others =>
            null;
    end case;
end process;
```

### One-Process State Machine (Compact)
```vhdl
process(clk, reset_n)
begin
    if reset_n = '0' then
        current_state <= IDLE;
        counter <= 0;
        output_reg <= (others => '0');
    elsif rising_edge(clk) then
        case current_state is
            when IDLE =>
                if start = '1' then
                    current_state <= ACTIVE;
                    counter <= 0;
                end if;
                
            when ACTIVE =>
                counter <= counter + 1;
                if counter = MAX_COUNT then
                    current_state <= DONE;
                    output_reg <= result_data;
                end if;
                
            when DONE =>
                current_state <= IDLE;
                
            when others =>
                current_state <= IDLE;
        end case;
    end if;
end process;
```

---

## 💾 Memory & Storage

### Register Implementation
```vhdl
-- Simple register
process(clk, reset_n)
begin
    if reset_n = '0' then
        data_reg <= (others => '0');
    elsif rising_edge(clk) then
        if enable = '1' then
            data_reg <= data_in;
        end if;
    end if;
end process;

-- Shift register
process(clk, reset_n)
begin
    if reset_n = '0' then
        shift_reg <= (others => '0');
    elsif rising_edge(clk) then
        shift_reg <= shift_reg(6 downto 0) & serial_in;
    end if;
end process;
```

### RAM Implementation
```vhdl
-- Single-port RAM
type ram_type is array (0 to 2**ADDR_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal ram : ram_type;

process(clk)
begin
    if rising_edge(clk) then
        if write_enable = '1' then
            ram(to_integer(unsigned(address))) <= data_in;
        end if;
        data_out <= ram(to_integer(unsigned(address)));
    end if;
end process;

-- Dual-port RAM
process(clk_a)
begin
    if rising_edge(clk_a) then
        if we_a = '1' then
            ram(to_integer(unsigned(addr_a))) <= data_in_a;
        end if;
        data_out_a <= ram(to_integer(unsigned(addr_a)));
    end if;
end process;

process(clk_b)
begin
    if rising_edge(clk_b) then
        if we_b = '1' then
            ram(to_integer(unsigned(addr_b))) <= data_in_b;
        end if;
        data_out_b <= ram(to_integer(unsigned(addr_b)));
    end if;
end process;
```

### FIFO Implementation
```vhdl
type fifo_array is array (0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal fifo_mem : fifo_array;
signal wr_ptr, rd_ptr : integer range 0 to FIFO_DEPTH-1;
signal fifo_count : integer range 0 to FIFO_DEPTH;

process(clk, reset_n)
begin
    if reset_n = '0' then
        wr_ptr <= 0;
        rd_ptr <= 0;
        fifo_count <= 0;
    elsif rising_edge(clk) then
        if write_en = '1' and fifo_count < FIFO_DEPTH then
            fifo_mem(wr_ptr) <= data_in;
            wr_ptr <= (wr_ptr + 1) mod FIFO_DEPTH;
            fifo_count <= fifo_count + 1;
        end if;
        
        if read_en = '1' and fifo_count > 0 then
            rd_ptr <= (rd_ptr + 1) mod FIFO_DEPTH;
            fifo_count <= fifo_count - 1;
        end if;
    end if;
end process;

data_out <= fifo_mem(rd_ptr);
empty <= '1' when fifo_count = 0 else '0';
full <= '1' when fifo_count = FIFO_DEPTH else '0';
```

---

## ⚡ Advanced VHDL Techniques & Production Patterns
### *Enterprise-Grade Design Methodologies*

### 🏗️ **Hierarchical Design Architecture**
```vhdl
-- Top-level system architecture with clean interfaces
entity system_top is
    generic (
        SYSTEM_CLK_FREQ : integer := 100_000_000;  -- 100 MHz
        DATA_WIDTH      : integer := 32;
        ADDR_WIDTH      : integer := 24;
        NUM_CHANNELS    : integer := 8
    );
    port (
        -- System clocks and resets
        sys_clk         : in  std_logic;
        sys_reset_n     : in  std_logic;
        
        -- External interfaces
        ext_bus_addr    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        ext_bus_data    : inout std_logic_vector(DATA_WIDTH-1 downto 0);
        ext_bus_ctrl    : out std_logic_vector(3 downto 0);
        
        -- Status and control
        system_status   : out std_logic_vector(7 downto 0);
        interrupt_req   : out std_logic
    );
end entity system_top;

architecture structural of system_top is
    -- Internal clock domains
    signal cpu_clk, dsp_clk, io_clk : std_logic;
    
    -- Inter-module communication buses
    signal cpu_to_mem_bus   : cpu_mem_bus_type;
    signal mem_to_io_bus    : mem_io_bus_type;
    signal dsp_data_bus     : dsp_bus_type;
    
    -- Clock domain crossing signals
    signal async_fifo_full  : std_logic;
    signal async_fifo_empty : std_logic;
    
begin
    -- Clock generation and distribution
    clock_manager_inst : entity work.clock_manager
        generic map (
            INPUT_FREQ  => SYSTEM_CLK_FREQ,
            CPU_FREQ    => 50_000_000,
            DSP_FREQ    => 200_000_000,
            IO_FREQ     => 25_000_000
        )
        port map (
            sys_clk     => sys_clk,
            sys_reset_n => sys_reset_n,
            cpu_clk     => cpu_clk,
            dsp_clk     => dsp_clk,
            io_clk      => io_clk
        );
    
    -- CPU subsystem
    cpu_subsystem_inst : entity work.cpu_subsystem
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            clk         => cpu_clk,
            reset_n     => sys_reset_n,
            mem_bus     => cpu_to_mem_bus,
            interrupt   => interrupt_req
        );
    
    -- DSP processing chain
    dsp_chain_inst : entity work.dsp_processing_chain
        generic map (
            NUM_CHANNELS => NUM_CHANNELS,
            DATA_WIDTH   => 24  -- 24-bit audio processing
        )
        port map (
            clk         => dsp_clk,
            reset_n     => sys_reset_n,
            data_bus    => dsp_data_bus
        );
        
end architecture structural;
```

### 🔄 **Advanced State Machine Patterns**
```vhdl
-- Hierarchical state machine with sub-states
type main_state_type is (INIT, IDLE, ACTIVE, ERROR, SHUTDOWN);
type active_substate_type is (SETUP, PROCESSING, CLEANUP);

signal main_state : main_state_type;
signal active_substate : active_substate_type;

-- State machine with timeout and error handling
process(clk, reset_n)
    variable timeout_counter : unsigned(15 downto 0);
    variable error_code      : std_logic_vector(7 downto 0);
    variable retry_count     : integer range 0 to 3;
begin
    if reset_n = '0' then
        main_state <= INIT;
        active_substate <= SETUP;
        timeout_counter := (others => '0');
        error_code := (others => '0');
        retry_count := 0;
    elsif rising_edge(clk) then
        -- Timeout handling for all states
        if timeout_counter > 0 then
            timeout_counter := timeout_counter - 1;
        end if;
        
        case main_state is
            when INIT =>
                -- System initialization
                if initialization_complete = '1' then
                    main_state <= IDLE;
                elsif timeout_counter = 0 then
                    main_state <= ERROR;
                    error_code := x"01";  -- Init timeout
                end if;
                
            when IDLE =>
                if start_request = '1' then
                    main_state <= ACTIVE;
                    active_substate <= SETUP;
                    timeout_counter := to_unsigned(10000, 16);  -- 10ms timeout
                end if;
                
            when ACTIVE =>
                case active_substate is
                    when SETUP =>
                        if setup_complete = '1' then
                            active_substate <= PROCESSING;
                            timeout_counter := to_unsigned(50000, 16);  -- 50ms timeout
                        elsif timeout_counter = 0 then
                            main_state <= ERROR;
                            error_code := x"02";  -- Setup timeout
                        end if;
                        
                    when PROCESSING =>
                        if processing_done = '1' then
                            active_substate <= CLEANUP;
                        elsif error_detected = '1' then
                            if retry_count < 3 then
                                retry_count := retry_count + 1;
                                active_substate <= SETUP;  -- Retry
                            else
                                main_state <= ERROR;
                                error_code := x"03";  -- Processing error
                            end if;
                        end if;
                        
                    when CLEANUP =>
                        if cleanup_done = '1' then
                            main_state <= IDLE;
                            retry_count := 0;
                        end if;
                end case;
                
            when ERROR =>
                -- Error handling and recovery
                if error_acknowledge = '1' then
                    case error_code is
                        when x"01" | x"02" =>
                            main_state <= INIT;  -- Reinitialize
                        when x"03" =>
                            main_state <= IDLE;  -- Return to idle
                        when others =>
                            main_state <= SHUTDOWN;
                    end case;
                end if;
                
            when SHUTDOWN =>
                -- Graceful shutdown sequence
                if shutdown_complete = '1' then
                    main_state <= INIT;
                end if;
        end case;
    end if;
end process;
```

### 🚀 **High-Performance Pipeline Architectures**
```vhdl
-- Multi-stage pipeline with hazard detection
entity pipeline_processor is
    generic (
        PIPELINE_DEPTH : integer := 5;
        DATA_WIDTH     : integer := 32
    );
    port (
        clk            : in  std_logic;
        reset_n        : in  std_logic;
        
        -- Pipeline control
        pipeline_stall : in  std_logic;
        pipeline_flush : in  std_logic;
        
        -- Data interfaces
        instruction_in : in  std_logic_vector(31 downto 0);
        data_in        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        result_out     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Pipeline status
        pipeline_busy  : out std_logic;
        hazard_detected: out std_logic
    );
end entity pipeline_processor;

architecture behavioral of pipeline_processor is
    -- Pipeline stage registers
    type pipeline_stage is record
        valid       : std_logic;
        instruction : std_logic_vector(31 downto 0);
        data        : std_logic_vector(DATA_WIDTH-1 downto 0);
        control     : std_logic_vector(7 downto 0);
    end record;
    
    type pipeline_array is array(0 to PIPELINE_DEPTH-1) of pipeline_stage;
    signal pipeline_regs : pipeline_array;
    
    -- Hazard detection signals
    signal data_hazard    : std_logic;
    signal control_hazard : std_logic;
    signal structural_hazard : std_logic;
    
begin
    -- Pipeline advancement process
    process(clk, reset_n)
        variable next_stage : pipeline_stage;
    begin
        if reset_n = '0' then
            for i in 0 to PIPELINE_DEPTH-1 loop
                pipeline_regs(i).valid <= '0';
                pipeline_regs(i).instruction <= (others => '0');
                pipeline_regs(i).data <= (others => '0');
                pipeline_regs(i).control <= (others => '0');
            end loop;
        elsif rising_edge(clk) then
            if pipeline_flush = '1' then
                -- Flush all pipeline stages
                for i in 0 to PIPELINE_DEPTH-1 loop
                    pipeline_regs(i).valid <= '0';
                end loop;
            elsif pipeline_stall = '0' and hazard_detected = '0' then
                -- Advance pipeline stages
                for i in PIPELINE_DEPTH-1 downto 1 loop
                    pipeline_regs(i) <= pipeline_regs(i-1);
                end loop;
                
                -- Insert new instruction at stage 0
                pipeline_regs(0).valid <= '1';
                pipeline_regs(0).instruction <= instruction_in;
                pipeline_regs(0).data <= data_in;
                pipeline_regs(0).control <= decode_control(instruction_in);
            end if;
        end if;
    end process;
    
    -- Hazard detection logic
    hazard_detection_proc : process(pipeline_regs)
        variable src_reg1, src_reg2, dest_reg : integer;
    begin
        data_hazard <= '0';
        control_hazard <= '0';
        structural_hazard <= '0';
        
        -- Check for data hazards (RAW, WAR, WAW)
        if pipeline_regs(0).valid = '1' and pipeline_regs(1).valid = '1' then
            src_reg1 := to_integer(unsigned(pipeline_regs(0).instruction(19 downto 15)));
            src_reg2 := to_integer(unsigned(pipeline_regs(0).instruction(24 downto 20)));
            dest_reg := to_integer(unsigned(pipeline_regs(1).instruction(11 downto 7)));
            
            if (src_reg1 = dest_reg or src_reg2 = dest_reg) and dest_reg /= 0 then
                data_hazard <= '1';
            end if;
        end if;
        
        -- Check for control hazards (branches, jumps)
        if pipeline_regs(0).instruction(6 downto 0) = "1100011" then  -- Branch instruction
            control_hazard <= '1';
        end if;
        
        hazard_detected <= data_hazard or control_hazard or structural_hazard;
    end process;
    
    -- Pipeline status outputs
    pipeline_busy <= '1' when (pipeline_regs(0).valid = '1' or 
                              pipeline_regs(1).valid = '1' or 
                              pipeline_regs(2).valid = '1') else '0';
    
end architecture behavioral;
```

### 🔄 **Clock Domain Crossing (CDC) Techniques**
```vhdl
-- Asynchronous FIFO for CDC
entity async_fifo is
    generic (
        DATA_WIDTH : integer := 32;
        FIFO_DEPTH : integer := 16
    );
    port (
        -- Write clock domain
        wr_clk    : in  std_logic;
        wr_reset_n: in  std_logic;
        wr_en     : in  std_logic;
        wr_data   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        wr_full   : out std_logic;
        wr_almost_full : out std_logic;
        
        -- Read clock domain
        rd_clk    : in  std_logic;
        rd_reset_n: in  std_logic;
        rd_en     : in  std_logic;
        rd_data   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        rd_empty  : out std_logic;
        rd_almost_empty : out std_logic
    );
end entity async_fifo;

architecture behavioral of async_fifo is
    constant ADDR_WIDTH : integer := integer(ceil(log2(real(FIFO_DEPTH))));
    
    -- Memory array
    type memory_type is array(0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal memory : memory_type;
    
    -- Gray code pointers
    signal wr_ptr_gray, wr_ptr_gray_next : std_logic_vector(ADDR_WIDTH downto 0);
    signal rd_ptr_gray, rd_ptr_gray_next : std_logic_vector(ADDR_WIDTH downto 0);
    
    -- Binary pointers for memory addressing
    signal wr_ptr_bin, rd_ptr_bin : std_logic_vector(ADDR_WIDTH-1 downto 0);
    
    -- Synchronized pointers for flag generation
    signal wr_ptr_gray_sync : std_logic_vector(ADDR_WIDTH downto 0);
    signal rd_ptr_gray_sync : std_logic_vector(ADDR_WIDTH downto 0);
    
begin
    -- Write clock domain
    wr_process : process(wr_clk, wr_reset_n)
    begin
        if wr_reset_n = '0' then
            wr_ptr_gray <= (others => '0');
            wr_ptr_bin <= (others => '0');
        elsif rising_edge(wr_clk) then
            if wr_en = '1' and wr_full = '0' then
                memory(to_integer(unsigned(wr_ptr_bin))) <= wr_data;
                wr_ptr_bin <= std_logic_vector(unsigned(wr_ptr_bin) + 1);
                wr_ptr_gray <= wr_ptr_gray_next;
            end if;
        end if;
    end process;
    
    -- Gray code conversion for write pointer
    wr_ptr_gray_next <= ('0' & wr_ptr_bin) xor ('0' & ('0' & wr_ptr_bin(ADDR_WIDTH-1 downto 1)));
    
    -- Read clock domain
    rd_process : process(rd_clk, rd_reset_n)
    begin
        if rd_reset_n = '0' then
            rd_ptr_gray <= (others => '0');
            rd_ptr_bin <= (others => '0');
            rd_data <= (others => '0');
        elsif rising_edge(rd_clk) then
            if rd_en = '1' and rd_empty = '0' then
                rd_data <= memory(to_integer(unsigned(rd_ptr_bin)));
                rd_ptr_bin <= std_logic_vector(unsigned(rd_ptr_bin) + 1);
                rd_ptr_gray <= rd_ptr_gray_next;
            end if;
        end if;
    end process;
    
    -- Gray code conversion for read pointer
    rd_ptr_gray_next <= ('0' & rd_ptr_bin) xor ('0' & ('0' & rd_ptr_bin(ADDR_WIDTH-1 downto 1)));
    
    -- Synchronizers for cross-domain pointer comparison
    wr_sync : entity work.synchronizer
        generic map (WIDTH => ADDR_WIDTH+1)
        port map (
            clk     => wr_clk,
            reset_n => wr_reset_n,
            data_in => rd_ptr_gray,
            data_out=> rd_ptr_gray_sync
        );
    
    rd_sync : entity work.synchronizer
        generic map (WIDTH => ADDR_WIDTH+1)
        port map (
            clk     => rd_clk,
            reset_n => rd_reset_n,
            data_in => wr_ptr_gray,
            data_out=> wr_ptr_gray_sync
        );
    
    -- Flag generation
    wr_full <= '1' when (wr_ptr_gray_next = (rd_ptr_gray_sync xor (1 << ADDR_WIDTH) xor (1 << (ADDR_WIDTH-1)))) else '0';
    rd_empty <= '1' when (rd_ptr_gray = wr_ptr_gray_sync) else '0';
    
end architecture behavioral;
```

### 🎯 **Resource Optimization Strategies**
```vhdl
-- Intelligent resource sharing
entity shared_arithmetic_unit is
    generic (
        DATA_WIDTH : integer := 16
    );
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        
        -- Operation control
        operation  : in  std_logic_vector(2 downto 0);  -- 000=ADD, 001=SUB, 010=MUL, 011=DIV
        operand_a  : in  signed(DATA_WIDTH-1 downto 0);
        operand_b  : in  signed(DATA_WIDTH-1 downto 0);
        start      : in  std_logic;
        
        -- Results
        result     : out signed(DATA_WIDTH-1 downto 0);
        result_ext : out signed(2*DATA_WIDTH-1 downto 0);  -- For multiplication
        valid      : out std_logic;
        busy       : out std_logic
    );
end entity shared_arithmetic_unit;

architecture behavioral of shared_arithmetic_unit is
    type operation_state is (IDLE, COMPUTING, DONE);
    signal current_state : operation_state;
    
    -- Shared multiplier/divider resources
    signal mult_result : signed(2*DATA_WIDTH-1 downto 0);
    signal div_quotient : signed(DATA_WIDTH-1 downto 0);
    signal div_remainder : signed(DATA_WIDTH-1 downto 0);
    
    -- Pipeline registers for timing optimization
    signal op_reg : std_logic_vector(2 downto 0);
    signal a_reg, b_reg : signed(DATA_WIDTH-1 downto 0);
    
begin
    process(clk, reset_n)
        variable cycle_count : integer range 0 to 31;
    begin
        if reset_n = '0' then
            current_state <= IDLE;
            result <= (others => '0');
            result_ext <= (others => '0');
            valid <= '0';
            busy <= '0';
            cycle_count := 0;
        elsif rising_edge(clk) then
            case current_state is
                when IDLE =>
                    valid <= '0';
                    if start = '1' then
                        current_state <= COMPUTING;
                        busy <= '1';
                        op_reg <= operation;
                        a_reg <= operand_a;
                        b_reg <= operand_b;
                        cycle_count := 0;
                    end if;
                    
                when COMPUTING =>
                    cycle_count := cycle_count + 1;
                    
                    case op_reg is
                        when "000" =>  -- Addition (1 cycle)
                            result <= a_reg + b_reg;
                            current_state <= DONE;
                            
                        when "001" =>  -- Subtraction (1 cycle)
                            result <= a_reg - b_reg;
                            current_state <= DONE;
                            
                        when "010" =>  -- Multiplication (3 cycles for pipelining)
                            if cycle_count = 1 then
                                mult_result <= a_reg * b_reg;
                            elsif cycle_count = 3 then
                                result_ext <= mult_result;
                                result <= mult_result(DATA_WIDTH-1 downto 0);
                                current_state <= DONE;
                            end if;
                            
                        when "011" =>  -- Division (16 cycles for iterative)
                            -- Implement iterative division algorithm
                            if cycle_count = 16 then
                                result <= div_quotient;
                                current_state <= DONE;
                            end if;
                            
                        when others =>
                            current_state <= DONE;
                    end case;
                    
                when DONE =>
                    valid <= '1';
                    busy <= '0';
                    current_state <= IDLE;
            end case;
        end if;
    end process;
    
end architecture behavioral;
```

### 🔧 **Advanced Timing Optimization**
```vhdl
-- Register retiming for critical paths
entity optimized_datapath is
    generic (
        DATA_WIDTH : integer := 32;
        PIPELINE_STAGES : integer := 4
    );
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        data_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        coeff      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_out  : out std_logic
    );
end entity optimized_datapath;

architecture behavioral of optimized_datapath is
    -- Pipeline stage registers
    type pipeline_data is array(0 to PIPELINE_STAGES-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal stage_data : pipeline_data;
    signal stage_valid : std_logic_vector(PIPELINE_STAGES-1 downto 0);
    
    -- Intermediate calculation registers
    signal mult_stage1 : std_logic_vector(2*DATA_WIDTH-1 downto 0);
    signal mult_stage2 : std_logic_vector(2*DATA_WIDTH-1 downto 0);
    signal add_stage1  : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Timing optimization attributes
    attribute KEEP : string;
    attribute KEEP of mult_stage1 : signal is "TRUE";
    attribute KEEP of mult_stage2 : signal is "TRUE";
    
    attribute MAX_FANOUT : integer;
    attribute MAX_FANOUT of stage_valid : signal is 4;
    
begin
    -- Pipelined datapath with optimal register placement
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            for i in 0 to PIPELINE_STAGES-1 loop
                stage_data(i) <= (others => '0');
                stage_valid(i) <= '0';
            end loop;
            mult_stage1 <= (others => '0');
            mult_stage2 <= (others => '0');
            add_stage1 <= (others => '0');
        elsif rising_edge(clk) then
            -- Stage 0: Input registration
            stage_data(0) <= data_in;
            stage_valid(0) <= '1';  -- Assume always valid for this example
            
            -- Stage 1: First multiplication stage
            mult_stage1 <= signed(stage_data(0)) * signed(coeff);
            stage_valid(1) <= stage_valid(0);
            
            -- Stage 2: Second multiplication stage (register retiming)
            mult_stage2 <= mult_stage1;
            stage_valid(2) <= stage_valid(1);
            
            -- Stage 3: Addition and scaling
            add_stage1 <= mult_stage2(DATA_WIDTH+7 downto 8);  -- Scale down
            stage_valid(3) <= stage_valid(2);
            
            -- Stage 4: Output registration
            stage_data(3) <= add_stage1;
            valid_out <= stage_valid(3);
        end if;
    end process;
    
    data_out <= stage_data(3);
    
end architecture behavioral;
```

---

## ⚡ Optimization Techniques

### Resource Optimization
```vhdl
-- Use appropriate data widths
signal counter : integer range 0 to 15;  -- Better than integer
signal address : unsigned(3 downto 0);   -- 4-bit address

-- Avoid unnecessary registers
-- BAD: Creates extra register
process(clk)
begin
    if rising_edge(clk) then
        temp_reg <= input_data;
        output_data <= temp_reg;
    end if;
end process;

-- GOOD: Direct assignment
output_data <= input_data;

-- Resource sharing
process(clk)
begin
    if rising_edge(clk) then
        case operation is
            when "00" => result <= a + b;      -- Adder
            when "01" => result <= a - b;      -- Subtractor (shared with adder)
            when "10" => result <= a and b;    -- AND gate
            when others => result <= a or b;   -- OR gate
        end case;
    end if;
end process;
```

### Timing Optimization
```vhdl
-- Pipeline long combinational paths
process(clk, reset_n)
begin
    if reset_n = '0' then
        stage1_reg <= (others => '0');
        stage2_reg <= (others => '0');
        result_reg <= (others => '0');
    elsif rising_edge(clk) then
        -- Stage 1: Input processing
        stage1_reg <= input_a + input_b;
        
        -- Stage 2: Intermediate processing  
        stage2_reg <= stage1_reg * coefficient;
        
        -- Stage 3: Final result
        result_reg <= stage2_reg + offset;
    end if;
end process;

-- Register outputs for better timing
process(clk, reset_n)
begin
    if reset_n = '0' then
        output_reg <= (others => '0');
    elsif rising_edge(clk) then
        output_reg <= complex_logic_result;
    end if;
end process;

output <= output_reg;  -- Registered output
```

### Power Optimization
```vhdl
-- Clock gating
gated_clock <= clk and clock_enable;

process(gated_clock, reset_n)
begin
    if reset_n = '0' then
        data_reg <= (others => '0');
    elsif rising_edge(gated_clock) then
        data_reg <= data_in;
    end if;
end process;

-- Conditional processing
process(clk, reset_n)
begin
    if reset_n = '0' then
        result <= (others => '0');
    elsif rising_edge(clk) then
        if enable = '1' then  -- Only process when needed
            result <= complex_calculation(input_data);
        end if;
    end if;
end process;
```

---

## ⚠️ Common Pitfalls & Solutions

### Latch Inference (Avoid!)
```vhdl
-- BAD: Creates unwanted latch
process(sel, a, b)
begin
    case sel is
        when "00" => output <= a;
        when "01" => output <= b;
        -- Missing cases create latch!
    end case;
end process;

-- GOOD: Complete case coverage
process(sel, a, b, c, d)
begin
    case sel is
        when "00" => output <= a;
        when "01" => output <= b;
        when "10" => output <= c;
        when others => output <= d;  -- Covers all cases
    end case;
end process;
```

### Multiple Drivers
```vhdl
-- BAD: Multiple drivers on same signal
process(clk)
begin
    if rising_edge(clk) then
        data_bus <= reg1;  -- Driver 1
    end if;
end process;

process(other_clk)
begin
    if rising_edge(other_clk) then
        data_bus <= reg2;  -- Driver 2 - ERROR!
    end if;
end process;

-- GOOD: Use tri-state or multiplexer
data_bus <= reg1 when enable1 = '1' else 'Z';
data_bus <= reg2 when enable2 = '1' else 'Z';
```

### Sensitivity List Issues
```vhdl
-- BAD: Incomplete sensitivity list
process(clk)  -- Missing reset_n
begin
    if reset_n = '0' then
        counter <= 0;
    elsif rising_edge(clk) then
        counter <= counter + 1;
    end if;
end process;

-- GOOD: Complete sensitivity list
process(clk, reset_n)  -- Include all signals read
begin
    if reset_n = '0' then
        counter <= 0;
    elsif rising_edge(clk) then
        counter <= counter + 1;
    end if;
end process;

-- BETTER: Use process(all) in VHDL-2008
process(all)
begin
    -- Automatically includes all signals
end process;
```

---

## 🔧 Synthesis Guidelines

### Synthesizable Constructs
```vhdl
-- ✅ GOOD for synthesis
signal counter : integer range 0 to 255;    -- Bounded integers
signal state : state_type;                   -- Enumerated types
signal data_reg : std_logic_vector(7 downto 0);

-- ❌ AVOID for synthesis
signal delay_time : time := 10 ns;          -- Time values
wait for 10 ns;                             -- Wait statements
file operations                             -- File I/O
```

### Coding for Synthesis
```vhdl
-- Infer specific hardware structures
-- D Flip-Flop
process(clk, reset_n)
begin
    if reset_n = '0' then
        q <= '0';
    elsif rising_edge(clk) then
        q <= d;
    end if;
end process;

-- Multiplexer
output <= input1 when sel = '0' else input2;

-- Decoder
process(address)
begin
    decode_out <= (others => '0');
    decode_out(to_integer(unsigned(address))) <= '1';
end process;

-- Counter
process(clk, reset_n)
begin
    if reset_n = '0' then
        count <= 0;
    elsif rising_edge(clk) then
        if enable = '1' then
            count <= count + 1;
        end if;
    end if;
end process;
```

---

## 🧪 Testbench Essentials

### Basic Testbench Structure
```vhdl
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_my_design is
end entity tb_my_design;

architecture testbench of tb_my_design is
    -- Constants
    constant CLK_PERIOD : time := 10 ns;
    constant DATA_WIDTH : integer := 8;
    
    -- Signals
    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';
    signal data_in : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal data_out: std_logic_vector(DATA_WIDTH-1 downto 0);
    signal enable  : std_logic := '0';
    
    -- Test control
    signal test_done : boolean := false;
    
begin
    -- Device Under Test (DUT)
    dut: entity work.my_design
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk      => clk,
            reset_n  => reset_n,
            data_in  => data_in,
            data_out => data_out,
            enable   => enable
        );
    
    -- Clock generation
    clk_gen: process
    begin
        while not test_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- Stimulus process
    stimulus: process
    begin
        -- Reset sequence
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait for CLK_PERIOD;
        
        -- Test case 1
        data_in <= x"AA";
        enable <= '1';
        wait for CLK_PERIOD;
        enable <= '0';
        
        -- Check result
        wait for CLK_PERIOD;
        assert data_out = x"AA" 
            report "Test case 1 failed" 
            severity error;
        
        -- More test cases...
        
        -- End simulation
        test_done <= true;
        report "Testbench completed successfully";
        wait;
    end process;
    
end architecture testbench;
```

### Advanced Testbench Techniques
```vhdl
-- Procedure for common operations
procedure write_data(
    signal clk : in std_logic;
    signal addr : out std_logic_vector;
    signal data : out std_logic_vector;
    signal we : out std_logic;
    constant address : in integer;
    constant write_data : in std_logic_vector
) is
begin
    wait until rising_edge(clk);
    addr <= std_logic_vector(to_unsigned(address, addr'length));
    data <= write_data;
    we <= '1';
    wait until rising_edge(clk);
    we <= '0';
end procedure;

-- Function for data generation
function generate_test_pattern(seed : integer) return std_logic_vector is
    variable result : std_logic_vector(7 downto 0);
begin
    result := std_logic_vector(to_unsigned(seed * 17 + 23, 8));
    return result;
end function;
```

---

## 📋 Quick Reference Summary

### Essential Do's and Don'ts

#### ✅ DO:
- Use `numeric_std` for arithmetic operations
- Always include complete sensitivity lists
- Use bounded integers instead of plain integers
- Register outputs for better timing
- Use synchronous resets when possible
- Include default assignments in case statements
- Use meaningful signal and variable names
- Comment complex logic

#### ❌ DON'T:
- Mix `std_logic_arith` with `numeric_std`
- Create latches unintentionally
- Use multiple drivers on same signal
- Forget to handle all cases in case statements
- Use unbounded integers in synthesis
- Use `wait` statements in synthesizable code
- Create long combinational paths
- Ignore synthesis warnings

### Performance Tips
1. **Pipeline long paths** - Break complex logic into stages
2. **Register boundaries** - Add registers at module interfaces
3. **Use appropriate widths** - Don't waste resources
4. **Share resources** - Multiplex operations when possible
5. **Clock domain crossing** - Use proper synchronizers

### Debugging Tips
1. **Use assertions** - Check assumptions in code
2. **Add debug signals** - Make internal states visible
3. **Incremental testing** - Test modules individually
4. **Waveform analysis** - Use simulation tools effectively
5. **Synthesis reports** - Check resource utilization

---

## 🔍 Code Analysis & Reverse Engineering Techniques
### *Expert-Level VHDL Code Assessment & Understanding*

### 📊 **Systematic Code Analysis Framework**
```vhdl
-- When analyzing unknown VHDL code, follow this systematic approach:

-- 1. ENTITY ANALYSIS: Understand the interface
entity unknown_module is
    generic (
        -- Analyze generic parameters for configurability
        DATA_WIDTH : integer := 32;
        ADDR_WIDTH : integer := 16;
        FIFO_DEPTH : integer := 1024
    );
    port (
        -- Clock and reset analysis
        clk         : in  std_logic;
        reset_n     : in  std_logic;  -- Active low reset
        
        -- Data flow analysis
        data_in     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_out    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Control signal analysis
        enable      : in  std_logic;
        ready       : out std_logic;
        valid       : out std_logic;
        
        -- Bus interface analysis
        addr_bus    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        data_bus    : inout std_logic_vector(DATA_WIDTH-1 downto 0);
        control_bus : out std_logic_vector(3 downto 0)
    );
end entity unknown_module;

-- ANALYSIS CHECKLIST:
-- ✓ What is the primary function? (Processing, Memory, Interface, Control)
-- ✓ What are the data widths and their significance?
-- ✓ What clock domains are involved?
-- ✓ What are the reset strategies?
-- ✓ What protocols are being used? (AXI, Avalon, Custom)
-- ✓ What is the expected throughput/latency?
```

### 🧩 **Architecture Pattern Recognition**
```vhdl
-- PATTERN 1: State Machine Detection
architecture behavioral of unknown_module is
    type state_type is (IDLE, FETCH, DECODE, EXECUTE, WRITEBACK);
    signal current_state, next_state : state_type;
    
    -- ANALYSIS: This is a processor-like state machine
    -- Look for: instruction processing, pipeline stages, control flow
    
-- PATTERN 2: FIFO/Buffer Detection
    type memory_array is array(0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal buffer_memory : memory_array;
    signal write_ptr, read_ptr : integer range 0 to FIFO_DEPTH-1;
    
    -- ANALYSIS: This is a circular buffer/FIFO
    -- Look for: pointer management, full/empty flags, flow control
    
-- PATTERN 3: Pipeline Detection
    signal stage1_reg, stage2_reg, stage3_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal stage1_valid, stage2_valid, stage3_valid : std_logic;
    
    -- ANALYSIS: This is a pipelined datapath
    -- Look for: data advancement, hazard handling, throughput optimization
    
-- PATTERN 4: Memory Controller Detection
    signal mem_cmd : std_logic_vector(2 downto 0);  -- READ/WRITE/REFRESH
    signal mem_addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal mem_data : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal mem_ready, mem_valid : std_logic;
    
    -- ANALYSIS: This is a memory interface controller
    -- Look for: command queuing, timing constraints, refresh logic
```

### 🔬 **Signal Flow Analysis Techniques**
```vhdl
-- TECHNIQUE 1: Data Path Tracing
-- Follow data from input to output through all transformations

-- Example analysis of a complex datapath:
architecture rtl of dsp_processor is
    -- Input stage
    signal input_reg : signed(DATA_WIDTH-1 downto 0);
    
    -- Processing stages
    signal mult_stage1 : signed(2*DATA_WIDTH-1 downto 0);
    signal mult_stage2 : signed(2*DATA_WIDTH-1 downto 0);
    signal add_stage   : signed(DATA_WIDTH-1 downto 0);
    signal scale_stage : signed(DATA_WIDTH-1 downto 0);
    
    -- Output stage
    signal output_reg : signed(DATA_WIDTH-1 downto 0);
    
begin
    -- ANALYSIS APPROACH:
    -- 1. Identify all signal assignments
    -- 2. Map the data transformation chain
    -- 3. Identify pipeline stages and delays
    -- 4. Calculate overall latency and throughput
    
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            input_reg <= (others => '0');
            mult_stage1 <= (others => '0');
            mult_stage2 <= (others => '0');
            add_stage <= (others => '0');
            scale_stage <= (others => '0');
            output_reg <= (others => '0');
        elsif rising_edge(clk) then
            -- Stage 1: Input registration
            input_reg <= signed(data_in);
            
            -- Stage 2: First multiplication
            mult_stage1 <= input_reg * coefficient1;
            
            -- Stage 3: Second multiplication  
            mult_stage2 <= mult_stage1;
            
            -- Stage 4: Addition
            add_stage <= mult_stage2(DATA_WIDTH-1 downto 0) + bias_value;
            
            -- Stage 5: Scaling
            scale_stage <= shift_right(add_stage, scale_factor);
            
            -- Stage 6: Output registration
            output_reg <= scale_stage;
        end if;
    end process;
    
    data_out <= std_logic_vector(output_reg);
    
    -- ANALYSIS RESULT:
    -- - 6-stage pipeline
    -- - 6 clock cycle latency
    -- - 1 sample per clock throughput
    -- - DSP function: (input * coeff1 + bias) >> scale_factor
end architecture rtl;
```

### 🕵️ **Control Logic Reverse Engineering**
```vhdl
-- TECHNIQUE 2: State Machine Reconstruction
-- When encountering complex control logic, reconstruct the state diagram

-- Example: Reverse engineering a communication protocol controller
process(clk, reset_n)
    variable byte_count : integer range 0 to 255;
    variable timeout_counter : integer range 0 to 1000;
begin
    if reset_n = '0' then
        current_state <= IDLE;
        byte_count := 0;
        timeout_counter := 0;
        -- ... other resets
    elsif rising_edge(clk) then
        -- ANALYSIS: Look for state transitions and conditions
        case current_state is
            when IDLE =>
                if start_transmission = '1' then
                    current_state <= SEND_HEADER;
                    byte_count := 0;
                end if;
                
            when SEND_HEADER =>
                if tx_ready = '1' then
                    if byte_count < 4 then  -- 4-byte header
                        byte_count := byte_count + 1;
                    else
                        current_state <= SEND_DATA;
                        byte_count := 0;
                    end if;
                end if;
                
            when SEND_DATA =>
                if tx_ready = '1' then
                    if byte_count < data_length then
                        byte_count := byte_count + 1;
                    else
                        current_state <= SEND_CHECKSUM;
                    end if;
                end if;
                
            when SEND_CHECKSUM =>
                if tx_ready = '1' then
                    current_state <= WAIT_ACK;
                    timeout_counter := 1000;  -- 1000 clock timeout
                end if;
                
            when WAIT_ACK =>
                if ack_received = '1' then
                    current_state <= IDLE;
                elsif timeout_counter = 0 then
                    current_state <= SEND_HEADER;  -- Retry
                else
                    timeout_counter := timeout_counter - 1;
                end if;
        end case;
    end if;
end process;

-- ANALYSIS RESULT:
-- Protocol: Header(4 bytes) + Data(variable) + Checksum(1 byte) + ACK
-- Features: Timeout handling, automatic retry, variable data length
-- Timing: 1000 clock cycle timeout for ACK
```

### 📈 **Performance Analysis Techniques**
```vhdl
-- TECHNIQUE 3: Resource and Timing Analysis
-- Estimate resource usage and timing characteristics

-- Example: Analyzing a complex arithmetic unit
entity arithmetic_analyzer is
    port (
        clk : in std_logic;
        -- ... other ports
    );
end entity;

architecture analysis of arithmetic_analyzer is
    -- RESOURCE ANALYSIS:
    signal mult_result : signed(35 downto 0);  -- 18x18 multiplier (1 DSP block)
    signal add_result  : signed(36 downto 0);  -- 37-bit adder (LUTs + carry chain)
    signal shift_result: signed(31 downto 0);  -- Barrel shifter (LUTs)
    
    -- TIMING ANALYSIS:
    -- Critical path: input -> multiplier -> adder -> shifter -> output
    -- Estimated delay: Tmult + Tadd + Tshift + Tsetup
    
    -- PIPELINE ANALYSIS:
    signal pipe_stage1 : signed(35 downto 0);  -- Multiply stage
    signal pipe_stage2 : signed(36 downto 0);  -- Add stage  
    signal pipe_stage3 : signed(31 downto 0);  -- Shift stage
    
begin
    process(clk)
    begin
        if rising_edge(clk) then
            -- Stage 1: Multiplication (1 clock)
            pipe_stage1 <= signed(operand_a) * signed(operand_b);
            
            -- Stage 2: Addition (1 clock)
            pipe_stage2 <= pipe_stage1 + signed(operand_c);
            
            -- Stage 3: Shift (1 clock)
            pipe_stage3 <= shift_right(pipe_stage2, shift_amount);
        end if;
    end process;
    
    -- ANALYSIS CONCLUSIONS:
    -- Resources: 1 DSP48, ~50 LUTs, ~40 FFs
    -- Latency: 3 clock cycles
    -- Throughput: 1 operation per clock
    -- Max frequency: Limited by critical path timing
end architecture analysis;
```

### 🔧 **Code Quality Assessment Framework**
```vhdl
-- ASSESSMENT CRITERIA for VHDL code quality:

-- 1. CODING STYLE ANALYSIS
-- ✓ Consistent naming conventions
-- ✓ Proper indentation and formatting
-- ✓ Meaningful signal and variable names
-- ✓ Adequate commenting
-- ✓ Modular design with clear interfaces

-- 2. SYNTHESIS QUALITY ANALYSIS
-- ✓ No inferred latches (check for incomplete case/if statements)
-- ✓ Proper reset strategies (synchronous vs asynchronous)
-- ✓ Clock domain crossing handled correctly
-- ✓ No multiple drivers on signals
-- ✓ Appropriate use of synthesis attributes

-- 3. TIMING ANALYSIS
-- ✓ Critical path identification
-- ✓ Setup/hold time margins
-- ✓ Clock skew considerations
-- ✓ Pipeline depth optimization
-- ✓ Register placement strategy

-- 4. RESOURCE UTILIZATION ANALYSIS
-- ✓ LUT usage efficiency
-- ✓ Memory block utilization
-- ✓ DSP block usage
-- ✓ I/O pin assignments
-- ✓ Power consumption estimates

-- 5. TESTABILITY ANALYSIS
-- ✓ Testbench coverage
-- ✓ Debug signal accessibility
-- ✓ Simulation vs synthesis consistency
-- ✓ Formal verification compatibility
-- ✓ In-system debugging support
```

### 🎯 **Reverse Engineering Workflow**
```vhdl
-- STEP-BY-STEP REVERSE ENGINEERING PROCESS:

-- PHASE 1: Initial Assessment (30 minutes)
-- 1. Read entity declarations - understand interfaces
-- 2. Identify major architectural blocks
-- 3. Recognize common design patterns
-- 4. Estimate complexity and scope

-- PHASE 2: Detailed Analysis (2-4 hours)
-- 1. Trace all signal paths
-- 2. Reconstruct state machines
-- 3. Identify timing relationships
-- 4. Map resource utilization

-- PHASE 3: Functional Verification (1-2 hours)
-- 1. Create test vectors
-- 2. Simulate and verify behavior
-- 3. Compare with expected functionality
-- 4. Document findings

-- PHASE 4: Optimization Assessment (1 hour)
-- 1. Identify performance bottlenecks
-- 2. Suggest resource optimizations
-- 3. Recommend timing improvements
-- 4. Propose architectural enhancements

-- EXAMPLE ANALYSIS TEMPLATE:
-- MODULE: [Module Name]
-- PURPOSE: [Primary Function]
-- COMPLEXITY: [Low/Medium/High]
-- RESOURCES: [LUTs: X, FFs: Y, DSPs: Z, BRAMs: W]
-- TIMING: [Max Freq: X MHz, Latency: Y cycles]
-- INTERFACES: [List all protocols and standards]
-- DEPENDENCIES: [Required libraries and components]
-- QUALITY: [Code quality score 1-10]
-- RECOMMENDATIONS: [List of improvements]
```

---

## 🏢 Enterprise-Level Design Patterns & Architectural Guidelines
### *Production-Scale FPGA System Architecture*

### 🏗️ **Scalable System Architecture Patterns**
```vhdl
-- PATTERN 1: Layered Architecture for Complex Systems
-- Layer 1: Hardware Abstraction Layer (HAL)
entity hardware_abstraction_layer is
    generic (
        PLATFORM_TYPE : string := "CYCLONE_V";
        CLOCK_FREQ    : integer := 100_000_000;
        NUM_CHANNELS  : integer := 16
    );
    port (
        -- Platform-specific interfaces
        platform_clk    : in  std_logic;
        platform_reset  : in  std_logic;
        
        -- Standardized internal interfaces
        system_clk      : out std_logic;
        system_reset_n  : out std_logic;
        
        -- Resource management
        resource_req    : in  std_logic_vector(NUM_CHANNELS-1 downto 0);
        resource_grant  : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        resource_busy   : out std_logic_vector(NUM_CHANNELS-1 downto 0)
    );
end entity hardware_abstraction_layer;

-- Layer 2: Service Layer
entity service_layer is
    generic (
        SERVICE_COUNT : integer := 8;
        DATA_WIDTH    : integer := 32
    );
    port (
        clk           : in  std_logic;
        reset_n       : in  std_logic;
        
        -- Service interfaces (standardized)
        service_req   : in  std_logic_vector(SERVICE_COUNT-1 downto 0);
        service_ack   : out std_logic_vector(SERVICE_COUNT-1 downto 0);
        service_data  : in  std_logic_vector(SERVICE_COUNT*DATA_WIDTH-1 downto 0);
        service_result: out std_logic_vector(SERVICE_COUNT*DATA_WIDTH-1 downto 0);
        
        -- Resource arbitration
        priority      : in  std_logic_vector(SERVICE_COUNT*3-1 downto 0);
        qos_level     : in  std_logic_vector(SERVICE_COUNT*2-1 downto 0)
    );
end entity service_layer;

-- Layer 3: Application Layer
entity application_layer is
    generic (
        APP_ID        : integer := 1;
        CONFIG_WIDTH  : integer := 64
    );
    port (
        clk           : in  std_logic;
        reset_n       : in  std_logic;
        
        -- Application-specific interfaces
        app_config    : in  std_logic_vector(CONFIG_WIDTH-1 downto 0);
        app_status    : out std_logic_vector(31 downto 0);
        
        -- Service layer interface
        service_if    : out service_interface_type;
        
        -- External application interfaces
        ext_data_in   : in  std_logic_vector(31 downto 0);
        ext_data_out  : out std_logic_vector(31 downto 0);
        ext_valid     : in  std_logic;
        ext_ready     : out std_logic
    );
end entity application_layer;
```

### 🔄 **Enterprise Communication Patterns**
```vhdl
-- PATTERN 2: Message-Based Communication Infrastructure
package message_infrastructure_pkg is
    -- Message types for enterprise systems
    type message_type is (
        MSG_DATA,           -- Data transfer message
        MSG_CONTROL,        -- Control/command message
        MSG_STATUS,         -- Status/response message
        MSG_ERROR,          -- Error notification
        MSG_HEARTBEAT,      -- System health check
        MSG_CONFIG,         -- Configuration update
        MSG_DEBUG           -- Debug/diagnostic message
    );
    
    -- Message header structure
    type message_header is record
        msg_type    : message_type;
        source_id   : std_logic_vector(7 downto 0);
        dest_id     : std_logic_vector(7 downto 0);
        sequence    : std_logic_vector(15 downto 0);
        length      : std_logic_vector(15 downto 0);
        priority    : std_logic_vector(2 downto 0);
        timestamp   : std_logic_vector(31 downto 0);
        checksum    : std_logic_vector(7 downto 0);
    end record;
    
    -- Message payload (variable length)
    type message_payload is array(0 to 255) of std_logic_vector(7 downto 0);
    
    -- Complete message structure
    type message_packet is record
        header  : message_header;
        payload : message_payload;
        valid   : std_logic;
    end record;
    
end package message_infrastructure_pkg;

-- Message Router for Enterprise Systems
entity enterprise_message_router is
    generic (
        NUM_PORTS     : integer := 16;
        BUFFER_DEPTH  : integer := 64;
        ROUTING_TABLE_SIZE : integer := 256
    );
    port (
        clk           : in  std_logic;
        reset_n       : in  std_logic;
        
        -- Input ports
        input_ports   : in  message_packet_array(0 to NUM_PORTS-1);
        input_valid   : in  std_logic_vector(NUM_PORTS-1 downto 0);
        input_ready   : out std_logic_vector(NUM_PORTS-1 downto 0);
        
        -- Output ports
        output_ports  : out message_packet_array(0 to NUM_PORTS-1);
        output_valid  : out std_logic_vector(NUM_PORTS-1 downto 0);
        output_ready  : in  std_logic_vector(NUM_PORTS-1 downto 0);
        
        -- Management interface
        routing_config: in  std_logic_vector(31 downto 0);
        statistics    : out std_logic_vector(31 downto 0);
        error_status  : out std_logic_vector(15 downto 0)
    );
end entity enterprise_message_router;

architecture behavioral of enterprise_message_router is
    -- Routing table for message forwarding
    type routing_entry is record
        dest_id     : std_logic_vector(7 downto 0);
        output_port : integer range 0 to NUM_PORTS-1;
        priority    : std_logic_vector(2 downto 0);
        valid       : std_logic;
    end record;
    
    type routing_table_type is array(0 to ROUTING_TABLE_SIZE-1) of routing_entry;
    signal routing_table : routing_table_type;
    
    -- Message buffers for each port
    type message_buffer_type is array(0 to BUFFER_DEPTH-1) of message_packet;
    type port_buffers_type is array(0 to NUM_PORTS-1) of message_buffer_type;
    signal input_buffers : port_buffers_type;
    
    -- Buffer management
    type buffer_pointers is array(0 to NUM_PORTS-1) of integer range 0 to BUFFER_DEPTH-1;
    signal write_ptr, read_ptr : buffer_pointers;
    signal buffer_full, buffer_empty : std_logic_vector(NUM_PORTS-1 downto 0);
    
begin
    -- Message routing process
    routing_process : process(clk, reset_n)
        variable dest_port : integer range 0 to NUM_PORTS-1;
        variable route_found : std_logic;
    begin
        if reset_n = '0' then
            -- Initialize routing table and buffers
            for i in 0 to NUM_PORTS-1 loop
                write_ptr(i) <= 0;
                read_ptr(i) <= 0;
                buffer_full(i) <= '0';
                buffer_empty(i) <= '1';
            end loop;
        elsif rising_edge(clk) then
            -- Process incoming messages
            for i in 0 to NUM_PORTS-1 loop
                if input_valid(i) = '1' and buffer_full(i) = '0' then
                    -- Store message in input buffer
                    input_buffers(i)(write_ptr(i)) <= input_ports(i);
                    write_ptr(i) <= (write_ptr(i) + 1) mod BUFFER_DEPTH;
                    
                    -- Update buffer status
                    if (write_ptr(i) + 1) mod BUFFER_DEPTH = read_ptr(i) then
                        buffer_full(i) <= '1';
                    end if;
                    buffer_empty(i) <= '0';
                end if;
            end loop;
            
            -- Route messages from buffers to output ports
            for i in 0 to NUM_PORTS-1 loop
                if buffer_empty(i) = '0' and output_ready(i) = '1' then
                    -- Look up destination in routing table
                    route_found := '0';
                    for j in 0 to ROUTING_TABLE_SIZE-1 loop
                        if routing_table(j).valid = '1' and 
                           routing_table(j).dest_id = input_buffers(i)(read_ptr(i)).header.dest_id then
                            dest_port := routing_table(j).output_port;
                            route_found := '1';
                            exit;
                        end if;
                    end loop;
                    
                    if route_found = '1' then
                        -- Forward message to destination port
                        output_ports(dest_port) <= input_buffers(i)(read_ptr(i));
                        output_valid(dest_port) <= '1';
                        
                        -- Update buffer pointers
                        read_ptr(i) <= (read_ptr(i) + 1) mod BUFFER_DEPTH;
                        buffer_full(i) <= '0';
                        
                        if (read_ptr(i) + 1) mod BUFFER_DEPTH = write_ptr(i) then
                            buffer_empty(i) <= '1';
                        end if;
                    end if;
                end if;
            end loop;
        end if;
    end process;
    
    -- Generate ready signals
    gen_ready : for i in 0 to NUM_PORTS-1 generate
        input_ready(i) <= not buffer_full(i);
    end generate;
    
end architecture behavioral;
```

### 🛡️ **Fault-Tolerant Design Patterns**
```vhdl
-- PATTERN 3: Triple Modular Redundancy (TMR) for Critical Systems
entity tmr_processor is
    generic (
        DATA_WIDTH : integer := 32
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        
        -- Input data (triplicated)
        data_in     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Output data (voted)
        data_out    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Error detection
        error_detected : out std_logic;
        error_corrected: out std_logic;
        
        -- Health monitoring
        module_health  : out std_logic_vector(2 downto 0)  -- Health of each module
    );
end entity tmr_processor;

architecture behavioral of tmr_processor is
    -- Three identical processing modules
    signal module_a_out, module_b_out, module_c_out : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal module_a_valid, module_b_valid, module_c_valid : std_logic;
    
    -- Voting logic signals
    signal vote_ab, vote_ac, vote_bc : std_logic;
    signal majority_vote : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Error detection and correction
    signal single_error, double_error : std_logic;
    
begin
    -- Instantiate three identical processing modules
    module_a : entity work.processing_core
        generic map (DATA_WIDTH => DATA_WIDTH)
        port map (
            clk      => clk,
            reset_n  => reset_n,
            data_in  => data_in,
            data_out => module_a_out,
            valid    => module_a_valid
        );
    
    module_b : entity work.processing_core
        generic map (DATA_WIDTH => DATA_WIDTH)
        port map (
            clk      => clk,
            reset_n  => reset_n,
            data_in  => data_in,
            data_out => module_b_out,
            valid    => module_b_valid
        );
    
    module_c : entity work.processing_core
        generic map (DATA_WIDTH => DATA_WIDTH)
        port map (
            clk      => clk,
            reset_n  => reset_n,
            data_in  => data_in,
            data_out => module_c_out,
            valid    => module_c_valid
        );
    
    -- Majority voting logic
    voting_process : process(clk, reset_n)
    begin
        if reset_n = '0' then
            majority_vote <= (others => '0');
            single_error <= '0';
            double_error <= '0';
        elsif rising_edge(clk) then
            -- Compare outputs from three modules
            vote_ab <= '1' when module_a_out = module_b_out else '0';
            vote_ac <= '1' when module_a_out = module_c_out else '0';
            vote_bc <= '1' when module_b_out = module_c_out else '0';
            
            -- Majority voting decision
            if vote_ab = '1' then
                majority_vote <= module_a_out;  -- A and B agree
                single_error <= not vote_ac;   -- C disagrees
            elsif vote_ac = '1' then
                majority_vote <= module_a_out;  -- A and C agree
                single_error <= not vote_ab;   -- B disagrees
            elsif vote_bc = '1' then
                majority_vote <= module_b_out;  -- B and C agree
                single_error <= not vote_ab;   -- A disagrees
            else
                -- All three disagree - double error
                majority_vote <= module_a_out;  -- Default to A
                double_error <= '1';
                single_error <= '0';
            end if;
        end if;
    end process;
    
    -- Output assignments
    data_out <= majority_vote;
    error_detected <= single_error or double_error;
    error_corrected <= single_error and not double_error;
    
    -- Health monitoring
    module_health(0) <= module_a_valid and not (single_error and not vote_ab and not vote_ac);
    module_health(1) <= module_b_valid and not (single_error and not vote_ab and not vote_bc);
    module_health(2) <= module_c_valid and not (single_error and not vote_ac and not vote_bc);
    
end architecture behavioral;
```

### 📊 **Performance Monitoring & Analytics**
```vhdl
-- PATTERN 4: Real-time Performance Monitoring System
entity performance_monitor is
    generic (
        NUM_COUNTERS    : integer := 16;
        COUNTER_WIDTH   : integer := 32;
        SAMPLE_PERIOD   : integer := 1000000  -- 1M clock cycles
    );
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;
        
        -- Performance events to monitor
        events          : in  std_logic_vector(NUM_COUNTERS-1 downto 0);
        
        -- Configuration interface
        counter_enable  : in  std_logic_vector(NUM_COUNTERS-1 downto 0);
        counter_reset   : in  std_logic_vector(NUM_COUNTERS-1 downto 0);
        
        -- Statistics output
        counter_values  : out std_logic_vector(NUM_COUNTERS*COUNTER_WIDTH-1 downto 0);
        sample_valid    : out std_logic;
        
        -- Threshold monitoring
        threshold_values: in  std_logic_vector(NUM_COUNTERS*COUNTER_WIDTH-1 downto 0);
        threshold_exceeded: out std_logic_vector(NUM_COUNTERS-1 downto 0);
        
        -- System health indicators
        system_load     : out std_logic_vector(7 downto 0);   -- 0-255 (0-100%)
        bottleneck_id   : out std_logic_vector(7 downto 0);   -- ID of bottleneck
        performance_grade: out std_logic_vector(3 downto 0)   -- A-F grade (0-15)
    );
end entity performance_monitor;

architecture behavioral of performance_monitor is
    -- Performance counters
    type counter_array is array(0 to NUM_COUNTERS-1) of unsigned(COUNTER_WIDTH-1 downto 0);
    signal counters : counter_array;
    signal prev_counters : counter_array;
    
    -- Sampling control
    signal sample_counter : unsigned(31 downto 0);
    signal sample_trigger : std_logic;
    
    -- Performance analysis
    signal max_counter_value : unsigned(COUNTER_WIDTH-1 downto 0);
    signal max_counter_id : integer range 0 to NUM_COUNTERS-1;
    signal total_activity : unsigned(COUNTER_WIDTH+4-1 downto 0);
    
begin
    -- Event counting process
    counting_process : process(clk, reset_n)
    begin
        if reset_n = '0' then
            for i in 0 to NUM_COUNTERS-1 loop
                counters(i) <= (others => '0');
            end loop;
            sample_counter <= (others => '0');
            sample_trigger <= '0';
        elsif rising_edge(clk) then
            -- Update sample counter
            if sample_counter = SAMPLE_PERIOD-1 then
                sample_counter <= (others => '0');
                sample_trigger <= '1';
                
                -- Save previous values for delta calculation
                prev_counters <= counters;
            else
                sample_counter <= sample_counter + 1;
                sample_trigger <= '0';
            end if;
            
            -- Update performance counters
            for i in 0 to NUM_COUNTERS-1 loop
                if counter_reset(i) = '1' then
                    counters(i) <= (others => '0');
                elsif counter_enable(i) = '1' and events(i) = '1' then
                    counters(i) <= counters(i) + 1;
                end if;
            end loop;
        end if;
    end process;
    
    -- Performance analysis process
    analysis_process : process(clk, reset_n)
        variable temp_max : unsigned(COUNTER_WIDTH-1 downto 0);
        variable temp_id : integer range 0 to NUM_COUNTERS-1;
        variable temp_total : unsigned(COUNTER_WIDTH+4-1 downto 0);
        variable load_percentage : unsigned(7 downto 0);
    begin
        if reset_n = '0' then
            max_counter_value <= (others => '0');
            max_counter_id <= 0;
            total_activity <= (others => '0');
            system_load <= (others => '0');
            bottleneck_id <= (others => '0');
            performance_grade <= (others => '0');
        elsif rising_edge(clk) then
            if sample_trigger = '1' then
                -- Find maximum counter (bottleneck identification)
                temp_max := (others => '0');
                temp_id := 0;
                temp_total := (others => '0');
                
                for i in 0 to NUM_COUNTERS-1 loop
                    if counters(i) > temp_max then
                        temp_max := counters(i);
                        temp_id := i;
                    end if;
                    temp_total := temp_total + counters(i);
                end loop;
                
                max_counter_value <= temp_max;
                max_counter_id <= temp_id;
                total_activity <= temp_total;
                bottleneck_id <= std_logic_vector(to_unsigned(temp_id, 8));
                
                -- Calculate system load (0-100%)
                load_percentage := resize(temp_total * 100 / SAMPLE_PERIOD, 8);
                system_load <= std_logic_vector(load_percentage);
                
                -- Performance grading (A=15, B=12, C=9, D=6, F=0)
                if load_percentage < 50 then
                    performance_grade <= x"F";  -- Excellent (A)
                elsif load_percentage < 70 then
                    performance_grade <= x"C";  -- Good (B)
                elsif load_percentage < 85 then
                    performance_grade <= x"9";  -- Fair (C)
                elsif load_percentage < 95 then
                    performance_grade <= x"6";  -- Poor (D)
                else
                    performance_grade <= x"0";  -- Critical (F)
                end if;
            end if;
        end if;
    end process;
    
    -- Threshold monitoring
    threshold_process : process(clk, reset_n)
    begin
        if reset_n = '0' then
            threshold_exceeded <= (others => '0');
        elsif rising_edge(clk) then
            for i in 0 to NUM_COUNTERS-1 loop
                if counters(i) >= unsigned(threshold_values((i+1)*COUNTER_WIDTH-1 downto i*COUNTER_WIDTH)) then
                    threshold_exceeded(i) <= '1';
                else
                    threshold_exceeded(i) <= '0';
                end if;
            end loop;
        end if;
    end process;
    
    -- Output counter values
    gen_outputs : for i in 0 to NUM_COUNTERS-1 generate
        counter_values((i+1)*COUNTER_WIDTH-1 downto i*COUNTER_WIDTH) <= 
            std_logic_vector(counters(i));
    end generate;
    
    sample_valid <= sample_trigger;
    
end architecture behavioral;
```

### 🔐 **Security & Access Control Patterns**
```vhdl
-- PATTERN 5: Hardware Security Module (HSM) for Enterprise Systems
entity hardware_security_module is
    generic (
        KEY_WIDTH       : integer := 256;
        USER_ID_WIDTH   : integer := 8;
        NUM_USERS       : integer := 16
    );
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;
        
        -- User authentication
        user_id         : in  std_logic_vector(USER_ID_WIDTH-1 downto 0);
        user_credential : in  std_logic_vector(KEY_WIDTH-1 downto 0);
        auth_request    : in  std_logic;
        auth_granted    : out std_logic;
        auth_level      : out std_logic_vector(3 downto 0);  -- 0-15 access levels
        
        -- Secure operations
        operation_code  : in  std_logic_vector(7 downto 0);
        input_data      : in  std_logic_vector(KEY_WIDTH-1 downto 0);
        output_data     : out std_logic_vector(KEY_WIDTH-1 downto 0);
        operation_valid : out std_logic;
        
        -- Security monitoring
        intrusion_detected : out std_logic;
        tamper_detected    : out std_logic;
        security_violation : out std_logic;
        
        -- Audit trail
        audit_log_entry : out std_logic_vector(63 downto 0);
        audit_log_valid : out std_logic
    );
end entity hardware_security_module;

architecture behavioral of hardware_security_module is
    -- User credential storage (encrypted)
    type credential_array is array(0 to NUM_USERS-1) of std_logic_vector(KEY_WIDTH-1 downto 0);
    signal user_credentials : credential_array;
    
    -- Access control matrix
    type access_matrix is array(0 to NUM_USERS-1) of std_logic_vector(15 downto 0);
    signal user_permissions : access_matrix;
    
    -- Security state
    type security_state is (SECURE, AUTHENTICATING, AUTHENTICATED, VIOLATION, LOCKDOWN);
    signal current_security_state : security_state;
    
    -- Intrusion detection
    signal failed_auth_count : unsigned(7 downto 0);
    signal tamper_sensors : std_logic_vector(7 downto 0);
    
    -- Audit logging
    type audit_entry is record
        timestamp   : std_logic_vector(31 downto 0);
        user_id     : std_logic_vector(USER_ID_WIDTH-1 downto 0);
        operation   : std_logic_vector(7 downto 0);
        result      : std_logic_vector(7 downto 0);
        severity    : std_logic_vector(3 downto 0);
    end record;
    
    signal current_audit_entry : audit_entry;
    
begin
    -- Authentication and access control process
    security_process : process(clk, reset_n)
        variable auth_success : std_logic;
        variable user_index : integer range 0 to NUM_USERS-1;
    begin
        if reset_n = '0' then
            current_security_state <= SECURE;
            auth_granted <= '0';
            auth_level <= (others => '0');
            failed_auth_count <= (others => '0');
            intrusion_detected <= '0';
            security_violation <= '0';
        elsif rising_edge(clk) then
            case current_security_state is
                when SECURE =>
                    if auth_request = '1' then
                        current_security_state <= AUTHENTICATING;
                        user_index := to_integer(unsigned(user_id));
                    end if;
                    
                when AUTHENTICATING =>
                    -- Verify user credentials
                    auth_success := '0';
                    if user_index < NUM_USERS then
                        if user_credential = user_credentials(user_index) then
                            auth_success := '1';
                            auth_granted <= '1';
                            auth_level <= user_permissions(user_index)(3 downto 0);
                            current_security_state <= AUTHENTICATED;
                            failed_auth_count <= (others => '0');
                        end if;
                    end if;
                    
                    if auth_success = '0' then
                        failed_auth_count <= failed_auth_count + 1;
                        current_security_state <= SECURE;
                        
                        -- Intrusion detection
                        if failed_auth_count > 3 then
                            intrusion_detected <= '1';
                            current_security_state <= VIOLATION;
                        end if;
                    end if;
                    
                when AUTHENTICATED =>
                    -- User is authenticated, allow operations
                    if auth_request = '0' then
                        auth_granted <= '0';
                        current_security_state <= SECURE;
                    end if;
                    
                when VIOLATION =>
                    security_violation <= '1';
                    -- Implement security response (lockdown, alert, etc.)
                    if failed_auth_count > 10 then
                        current_security_state <= LOCKDOWN;
                    end if;
                    
                when LOCKDOWN =>
                    -- System locked down, require administrative reset
                    auth_granted <= '0';
                    intrusion_detected <= '1';
                    security_violation <= '1';
            end case;
            
            -- Tamper detection
            tamper_detected <= '1' when tamper_sensors /= x"00" else '0';
            if tamper_sensors /= x"00" then
                current_security_state <= VIOLATION;
            end if;
        end if;
    end process;
    
    -- Audit logging process
    audit_process : process(clk, reset_n)
        variable timestamp_counter : unsigned(31 downto 0);
    begin
        if reset_n = '0' then
            timestamp_counter := (others => '0');
            audit_log_valid <= '0';
        elsif rising_edge(clk) then
            timestamp_counter := timestamp_counter + 1;
            
            -- Log security events
            if auth_request = '1' or security_violation = '1' or tamper_detected = '1' then
                current_audit_entry.timestamp <= std_logic_vector(timestamp_counter);
                current_audit_entry.user_id <= user_id;
                current_audit_entry.operation <= operation_code;
                
                if security_violation = '1' then
                    current_audit_entry.result <= x"FF";  -- Security violation
                    current_audit_entry.severity <= x"F"; -- Critical
                elsif tamper_detected = '1' then
                    current_audit_entry.result <= x"FE";  -- Tamper detected
                    current_audit_entry.severity <= x"F"; -- Critical
                elsif auth_granted = '1' then
                    current_audit_entry.result <= x"00";  -- Success
                    current_audit_entry.severity <= x"1"; -- Info
                else
                    current_audit_entry.result <= x"01";  -- Auth failed
                    current_audit_entry.severity <= x"8"; -- Warning
                end if;
                
                audit_log_valid <= '1';
            else
                audit_log_valid <= '0';
            end if;
        end if;
    end process;
    
    -- Pack audit entry for output
    audit_log_entry <= current_audit_entry.timestamp & 
                      current_audit_entry.user_id & 
                      current_audit_entry.operation & 
                      current_audit_entry.result & 
                      current_audit_entry.severity;
    
end architecture behavioral;
```

---

## 🎯 Conclusion

This cheatsheet covers the essential VHDL programming techniques and optimization strategies. Focus on:

1. **Clean, readable code** with proper structure
2. **Synthesis-friendly constructs** that map to hardware efficiently  
3. **Proper clocking and reset strategies** for reliable designs
4. **Resource optimization** for area and power efficiency
5. **Comprehensive testing** with well-structured testbenches

Remember: VHDL describes hardware, not software. Always think about the physical implementation when writing code.

---

*Happy VHDL coding! 🚀*