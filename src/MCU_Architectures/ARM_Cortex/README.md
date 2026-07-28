# ARM Cortex Soft-Core Family

VHDL implementations of ARM Cortex-M class soft-core interfaces for the Cyclone III FPGA. Each core provides an AHB-Lite bus interface and instantiates a configurable set of peripherals.

---

## Supported Cores

| Core       | File                        | Key Features                                              |
|------------|-----------------------------|-----------------------------------------------------------|
| Cortex-M0  | `cortex_m0_interface.vhd`   | ARMv6-M, 32-bit, 3-stage pipeline, WFI/WFE               |
| Cortex-M0+ | `cortex_m0plus_interface.vhd`| ARMv6-M, 2-stage pipeline, MTB, single-cycle I/O         |
| Cortex-M1  | `cortex_m1_interface.vhd`   | ARMv6-M optimized for FPGA, 3-stage pipeline              |
| Cortex-M23 | `cortex_m23_interface.vhd`  | ARMv8-M Baseline, security extension (TrustZone)          |
| Cortex-M3  | `cortex_m3_interface.vhd`   | ARMv7-M, 3-stage pipeline, hardware divide, MPU           |
| Cortex-M4  | `cortex_m4_interface.vhd`   | ARMv7E-M, DSP instructions, optional FPU, MPU             |

---

## Peripherals per Core

| Peripheral       | M0 | M0+ | M1 | M23 | M3 | M4 |
|------------------|----|-----|----|-----|----|----|
| NVIC             | Y  | Y   | Y  | Y   | Y  | Y  |
| MPU              | -  | opt | -  | Y   | Y  | Y  |
| SysTick          | Y  | Y   | Y  | Y   | Y  | Y  |
| FPU (single)     | -  | -   | -  | -   | -  | Y  |
| DSP extensions   | -  | -   | -  | -   | -  | Y  |
| DWT / ITM / ETM  | -  | -   | -  | -   | Y  | Y  |
| Cache controller | -  | -   | -  | -   | opt| opt|
| Bus matrix       | Y  | Y   | Y  | Y   | Y  | Y  |

---

## Integration with MPU, FPU, DSP, Trace

- **MPU** (`mpu_controller.vhd`): 16 regions, RBAR/RASR alias registers, privileged/default access.
- **FPU** (`fpu_single.vhd`): IEEE-754 single-precision add/sub/mul/div/FMA with exception flags.
- **DSP** (`dsp_extensions.vhd`): SIMD-style saturating arithmetic, MAC, dual 16-bit ops.
- **Trace**: DWT (cycle/event counters + watchpoints), ITM (stimulus ports via SWO), ETM (instruction trace with address comparators).

---

## Testbenches

Each core has a dedicated testbench (`cortex_m*_testbench.vhd`). Run with GHDL:

```bash
ghdl -a --std=08 cortex_m4_interface.vhd cortex_m4_testbench.vhd
ghdl -e --std=08 cortex_m4_testbench
ghdl -r --std=08 cortex_m4_testbench --vcd=m4.vcd
```
