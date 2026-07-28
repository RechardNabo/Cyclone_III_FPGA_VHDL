# Top-Level Integration Documentation

## Overview

This document describes the top-level integration entities for the Cyclone III FPGA VHDL project. These files integrate individual MCU cores and peripherals into complete System-on-Chip (SoC) designs with AHB-Lite bus matrices.

## Files Created

### 1. Cortex-M4 SoC Top-Level
**File:** `src/MCU_Architectures/ARM_Cortex/Cortex-M4/cortex_m4_top.vhd` (241 lines)

Integrates the Cortex-M4 CPU core with 22 peripherals via an AHB-Lite bus matrix.

#### Integrated Components
| Component | Address Base | Description |
|-----------|-------------|-------------|
| `cortex_m4_interface` | 0x4000_0000 | CPU core with GPIO, SysTick, debug |
| `mpu_controller` | 0x4001_0000 | 16-region memory protection unit |
| `dsp_extensions` | 0x4002_0000 | SIMD DSP accelerator (saturating arithmetic) |
| `fpu_single` | 0x4003_0000 | IEEE 754 single-precision FPU |
| `dwt_controller` | 0x4004_0000 | Data watchpoint and trace unit |
| `itm_controller` | 0x4005_0000 | Instrumentation trace macrocell |
| `nvic_tailchain` | 0x4006_0000 | NVIC with tail-chaining optimization |
| `crc_accelerator` | 0x4007_0000 | Hardware CRC-16/CRC-32 calculator |
| `aes_accelerator` | 0x4008_0000 | AES-128/256 encryption/decryption |
| `sha256_accelerator` | 0x4009_0000 | SHA-256 hash computation |
| `trng_controller` | 0x400A_0000 | True random number generator |
| `exti_controller` | 0x400B_0000 | 32-line external interrupt controller |
| `nmi_controller` | 0x400C_0000 | Non-maskable interrupt controller |
| `cmu_controller` | 0x400D_0000 | Clock management unit with PLL |
| `psc_controller` | 0x400E_0000 | Power and sleep controller |
| `uart_ahb` | 0x400F_0000 | UART controller |
| `spi_master_ahb` | 0x4010_0000 | SPI master controller |
| `i2c_master_ahb` | 0x4011_0000 | I2C master controller |
| `adc_controller` | 0x4012_0000 | 8-channel ADC controller |
| `wdt_controller` | 0x4013_0000 | Watchdog timer |
| `rtc_controller` | 0x4014_0000 | Real-time clock |
| `dma_controller` | 0x4015_0000 | 4-channel DMA controller |

#### Generic
- `CLK_FREQ` (default 50000000): System clock frequency in Hz, passed to WDT and RTC.

#### Bus Matrix
Single-master AHB-Lite bus matrix with address decode on `HADDR[31:16]`. Read data, response, and ready signals are multiplexed from the selected slave using a priority-indexed array.

---

### 2. RISC-V SoC Top-Level
**File:** `src/MCU_Architectures/RISC_V/riscv_top.vhd` (203 lines)

Integrates the RV32I RISC-V core with CSR, CLINT, PLIC, PMP, and M/A/C extensions, plus AHB peripherals.

#### Integrated Components
| Component | Address Base | Description |
|-----------|-------------|-------------|
| `riscv_csr` | 0x4000_0000 | Control & status registers |
| `riscv_clint` | 0x4001_0000 | Core local interruptor (timer + software) |
| `riscv_plic` | 0x4002_0000 | Platform-level interrupt controller (32 sources) |
| `riscv_pmp` | 0x4003_0000 | Physical memory protection (16 regions) |
| `riscv_m_ext` | 0x4004_0000 | Multiply/divide extension |
| `riscv_a_ext` | 0x4005_0000 | Atomic operations extension |
| `riscv_c_ext` | 0x4006_0000 | Compressed instruction decoder |
| `crc_accelerator` | 0x4007_0000 | Hardware CRC calculator |
| `trng_controller` | 0x4008_0000 | True random number generator |
| `uart_ahb` | 0x4009_0000 | UART controller |
| `spi_master_ahb` | 0x400A_0000 | SPI master controller |
| `i2c_master_ahb` | 0x400B_0000 | I2C master controller |

#### Interrupt Routing
- `timer_int` ← CLINT `timer_irq`
- `software_int` ← CLINT `sw_irq`
- `external_int` ← PLIC `ext_irq_out` + external IRQ sources

#### PMP Integration
The PMP monitors the RISC-V core's `dmem_addr` with access type derived from `dmem_we` and `dmem_re`.

---

### 3. Synergy S7 SoC Top-Level
**File:** `src/MCU_Architectures/Renesas_Synergy/synergy_s7_top.vhd` (181 lines)

Integrates the Renesas Synergy S7 CPU (ARM Cortex-M23 + TrustZone) with Synergy-specific peripherals.

#### Integrated Components
| Component | Address Base | Description |
|-----------|-------------|-------------|
| `synergy_s7_interface` | 0x4000_0000 | S7 CPU with TrustZone, TRNG, secure boot |
| `synergy_dmac` | 0x4001_0000 | 8-channel DMA controller |
| `synergy_gpt` | 0x4002_0000 | 6-channel general purpose timer |
| `synergy_agt` | 0x4003_0000 | Asynchronous general timer (low-power) |
| `synergy_elc` | 0x4004_0000 | Event link controller |
| `synergy_dtc` | 0x4005_0000 | Data transfer controller |
| `synergy_sdhi` | 0x4006_0000 | SD host interface (SD/SDHC/SDXC) |
| `synergy_glcd` | 0x4007_0000 | Graphics LCD controller (480x272, 18-bit RGB) |

#### DMA Master Loopback
The S7 CPU's DMA master port is tied with a loopback acknowledge (`dma_done <= dma_req`) for standalone operation.

---

### 4. Unified Multi-Core SoC Top-Level
**File:** `src/top_level/soc_top.vhd` (230 lines)

Unified SoC integrating all 4 MCU architectures with a shared AHB-Lite bus matrix.

#### Bus Matrix Architecture
- **4 Master Ports** (priority arbitration: M0 > M1 > M2 > M3):
  - Master 0: Cortex-M4
  - Master 1: RISC-V
  - Master 2: RP2040 (available for shared bus access)
  - Master 3: Synergy S7

- **Shared Slaves:**

| Slave | Address Base | Description |
|-------|-------------|-------------|
| `ext_sram_controller` | 0x0000_0000 | External SRAM/BRAM controller |
| `bootloader_rom` | 0x1000_0000 | Bootloader ROM emulator |
| `cortex_m4_top` | 0x4000_0000 | Cortex-M4 SoC subsystem |
| `riscv_top` | 0x5000_0000 | RISC-V SoC subsystem |
| `synergy_s7_top` | 0x6000_0000 | Synergy S7 SoC subsystem |

#### Packed Master Signal Format
Master ports use packed vectors for compactness:
- `m_HSEL`, `m_HWRITE`, `m_HREADY`, `m_HMASTLOCK`: 4-bit (1 bit per master)
- `m_HTRANS`: 8-bit (2 bits per master)
- `m_HSIZE`: 12-bit (3 bits per master)
- `m_HPROT`: 16-bit (4 bits per master)
- `m_HADDR`, `m_HWDATA`, `m_HRDATA`: 128-bit (32 bits per master)

#### RP2040 Integration
The RP2040 is instantiated as a standalone subsystem (not on the AHB bus matrix) since it uses its own QSPI flash interface. Its `irq_out` is combined into the global interrupt output.

---

## Testbenches

### 5. Cortex-M4 SoC Testbench
**File:** `src/MCU_Architectures/ARM_Cortex/Cortex-M4/cortex_m4_top_tb.vhd` (133 lines)

- 50 MHz clock (20 ns period)
- Tests UART CTRL register write/read-back at 0x400F_0000
- Tests CRC CTRL register write at 0x4007_0000
- Tests CRC RESULT register read at 0x4007_000C
- Asserts PASS/FAIL, uses `std.env.finish`

### 6. RISC-V SoC Testbench
**File:** `src/MCU_Architectures/RISC_V/riscv_top_tb.vhd` (135 lines)

- 50 MHz clock (20 ns period)
- Tests UART CTRL register write/read-back at 0x4009_0000
- Tests CRC CTRL register write at 0x4007_0000
- Tests TRNG STAT register read at 0x4008_0004
- Asserts PASS/FAIL, uses `std.env.finish`

### 7. Unified SoC Testbench
**File:** `src/top_level/soc_top_tb.vhd` (132 lines)

- 50 MHz clock (20 ns period)
- Uses master 0 (Cortex-M4) to access shared peripherals
- Tests ext_sram CTRL register write/read-back at 0x0000_0000
- Tests bootloader STAT register read at 0x1000_0004
- Asserts PASS/FAIL, uses `std.env.finish`

---

## Design Conventions

### VHDL Style
- All files use: `library IEEE; use IEEE.std_logic_1164.all; use IEEE.numeric_std.all;`
- Testbenches additionally use: `use std.env.all;`
- Direct entity instantiation (`entity work.component_name`) used throughout (no component declarations)
- Active-low reset (`HRESETn`) for AHB interfaces
- Active-high reset for RISC-V core

### AHB-Lite Bus Matrix Pattern
1. **Address Decode**: Upper address bits select slave via comparison
2. **HSEL Generation**: One-hot select signal per slave
3. **Read Mux**: Array-indexed multiplexer selects active slave's `HRDATA`/`HRESP`/`HREADYOUT`
4. **Default Response**: Non-selected slaves return `HREADYOUT='1'`

### Interrupt Aggregation
All peripheral interrupt outputs are OR-reduced into a single `global_irq` output at each SoC level.

## Compilation Order

1. All peripheral files in `src/peripherals/`
2. All MCU architecture files in `src/MCU_Architectures/`
3. `cortex_m4_top.vhd`
4. `riscv_top.vhd`
5. `synergy_s7_top.vhd`
6. `soc_top.vhd`
7. Testbench files (for simulation only)
