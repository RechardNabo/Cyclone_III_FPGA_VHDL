# Cyclone III FPGA Soft-Core MCU Library

A comprehensive VHDL library of soft-core microcontroller architectures and peripherals targeting the **Cyclone III EP3C16F484C6N** FPGA on the **DE0** development board. The library provides synthesizable VHDL for multiple MCU families, a rich peripheral set, and FPGA-specific wrappers for on-chip resources.

---

## Overview

| Property            | Value                          |
|---------------------|--------------------------------|
| Target FPGA         | EP3C16F484C6N (Cyclone III)    |
| Target Board        | DE0 (Terasic)                  |
| Logic Elements      | 15,408                         |
| RAM Bits            | ~516 Kbits                     |
| PLLs                | 4                              |
| Multipliers         | 56                             |
| I/O Pins            | 295                            |
| HDL Language        | VHDL (IEEE 1076)              |
| Bus Protocol        | AHB-Lite (32-bit)             |
| VHDL Files          | 418+                           |
| Peripherals         | 87                             |

### Supported MCU Architectures

| Family           | Cores / Variants                          |
|------------------|-------------------------------------------|
| ARM Cortex       | M0, M0+, M1, M23, M3, M4                  |
| RISC-V           | RV32IMAC (I + M + A + C extensions)       |
| RP2040           | Dual Cortex-M0+ soft-core                 |
| AVR              | ATmega-style 8-bit core                   |
| MSP430           | 16-bit ultra-low-power core               |
| PIC              | 16C5x, 16F, 18F families                  |
| Renesas Synergy  | S1, S2, S3, S4, S5, S6, S7               |

---

## Directory Structure

```
Cyclone_III_FPGA_VHDL/
├── src/
│   ├── MCU_Architectures/      # Soft-core CPU cores & interfaces
│   │   ├── ARM_Cortex/         # Cortex-M0/M0+/M1/M23/M3/M4
│   │   ├── RISC_V/             # RV32IMAC core + CSR/CLINT/PLIC/PMP
│   │   ├── RP2040/             # Dual M0+ top-level with PIO/SIO
│   │   ├── AVR/                # 8-bit AVR core
│   │   ├── MSP/                # MSP430 16-bit core
│   │   ├── PIC/                # PIC16C5x/16F/18F cores
│   │   ├── Renesas_Synergy/    # Synergy S1-S7 interfaces
│   │   └── ESP32_Interface/    # ESP32 bridge (SPI/UART)
│   ├── peripherals/            # 87 AHB-Lite peripheral IP cores
│   ├── Communication_Protocols/# CAN, Ethernet, I2C, I2S, SPI, UART
│   ├── Cryptography/           # Crypto primitives
│   ├── Signal_Processing/      # DSP / FIR filters
│   ├── memory/                 # RAM / ROM controllers
│   ├── top_level/              # FPGA top-level entities
│   ├── testbenches/            # VHDL testbenches
│   └── ...                     # ALUs, FSMs, combinational, sequential
├── simulation/                 # ModelSim simulation output
├── output_files/               # Quartus build artifacts
├── docs/                       # Documentation
└── README.md
```

---

## Compiling with GHDL

[GHDL](https://ghdl.github.io/ghdl/) is the open-source VHDL simulator used for functional verification.

```bash
# Analyze all source files
ghdl -a --std=08 src/peripherals/*.vhd
ghdl -a --std=08 src/MCU_Architectures/RISC_V/*.vhd

# Elaborate and simulate a testbench
ghdl -e --std=08 riscv_testbench
ghdl -r --std=08 riscv_testbench --vcd=riscv.vcd

# View waveform with GTKWave
gtkwave riscv.vcd
```

> **Tip:** Analyze peripheral files before architecture files, since cores instantiate peripherals via `entity work.<name>`.

---

## Synthesizing with Quartus

The project targets **Quartus II 13.0 SP1** (last version supporting Cyclone III).

1. Open the `.qpf` project file in Quartus II 13.0 SP1.
2. Assign all `.vhd` files under `src/` to the project.
3. Set the top-level entity (e.g., `rp2040_top` or your custom top).
4. Pin assignments: DE0 board pin constraints (FBGA-484).
5. Run **Analysis & Synthesis** then **Fitter (Place & Route)**.
6. Program the FPGA via **Programmer** (JTAG / AS mode).

> For modern Quartus Prime Lite, use a Cyclone IV E (EP4CE15) as a drop-in replacement — see the FPGA alternatives section below.

---

## FPGA Device Alternatives

Quartus Prime Lite does not support Cyclone III. Compatible alternatives:

| Family         | Part Number       | LEs    | Quartus Support       |
|----------------|-------------------|--------|-----------------------|
| Cyclone IV E   | EP4CE15F23C8N     | 15,408 | Quartus Prime Lite    |
| Cyclone IV E   | EP4CE22F17C6N     | 22,320 | Quartus Prime Lite    |
| Cyclone 10 LP  | 10CL025YU484I7G   | 24,624 | Quartus Prime Lite    |

---

## Resources

- [GHDL Documentation](https://ghdl.github.io/ghdl/)
- [Intel Quartus Prime Downloads](https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/download.html)
- [Quartus II 13.0 SP1 Archive](https://www.intel.com/content/www/us/en/software-kit/667396/nios-ii-eds-13-0-sp1.html)
- [DE0 Board Resources (Terasic)](https://www.terasic.com.tw)

---

## Contact

For questions, device selection help, or project setup support, feel free to reach out or open an issue.
