# Renesas Synergy Soft-Core Family

VHDL implementations of Renesas Synergy S-series soft-core interfaces for the Cyclone III FPGA. Each variant provides an AHB-Lite bus interface with a Synergy-specific peripheral set.

---

## Supported Variants

| Variant | File                        | Target Class       |
|---------|-----------------------------|--------------------|
| S1      | `synergy_s1_interface.vhd`  | Entry-level        |
| S2      | `synergy_s2_interface.vhd`  | Entry-level+       |
| S3      | `synergy_s3_interface.vhd`  | Mid-range          |
| S4      | `synergy_s4_interface.vhd`  | Mid-range+         |
| S5      | `synergy_s5_interface.vhd`  | High-performance   |
| S6      | `synergy_s6_interface.vhd`  | High-performance+  |
| S7      | `synergy_s7_interface.vhd`  | Premium            |

All variants share the ARM Cortex-M core (M0+/M4 depending on class) and the Synergy peripheral set below.

---

## Synergy Peripherals

| Peripheral | File                | Description                                              |
|------------|---------------------|----------------------------------------------------------|
| DMAC       | `synergy_dmac.vhd`  | DMA controller, 8 channels, round-robin, per-channel IRQ |
| GPT        | `synergy_gpt.vhd`   | General Purpose Timer, 6 channels, 32-bit, compare/capture |
| AGT        | `synergy_agt.vhd`   | Asynchronous General Timer, 16-bit, periodic/one-shot    |
| ELC        | `synergy_elc.vhd`   | Event Link Controller, routes peripheral events           |
| DTC        | `synergy_dtc.vhd`   | Data Transfer Controller, vector-triggered DMA            |
| SDHI       | `synergy_sdhi.vhd`  | SD Host Interface, SD/SDIO/SDHC, 1-bit/4-bit              |
| GLCD       | `synergy_glcd.vhd`  | Graphics LCD controller, frame buffer, programmable sync  |

---

## Testbenches

Each variant has a dedicated testbench (`synergy_s*_testbench.vhd`):

```bash
ghdl -a --std=08 synergy_s5_interface.vhd synergy_s5_testbench.vhd
ghdl -e --std=08 synergy_s5_testbench
ghdl -r --std=08 synergy_s5_testbench --vcd=s5.vcd
```
