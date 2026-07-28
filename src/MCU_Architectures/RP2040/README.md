# RP2040 Dual Cortex-M0+ Soft-Core

VHDL implementation of a Raspberry Pi RP2040-compatible dual-core soft-core SoC for the Cyclone III FPGA.

---

## Overview

| Feature              | Implementation                          |
|----------------------|-----------------------------------------|
| CPU                  | Dual Cortex-M0+ (`cortex_m0plus_interface.vhd`) |
| Bus                  | AHB-Lite 32-bit                         |
| Top-level entity     | `rp2040_top.vhd`                        |

---

## Instantiated Peripherals

| Peripheral   | File                          | Description                                  |
|--------------|-------------------------------|----------------------------------------------|
| SIO          | `sio_controller.vhd`          | Single-cycle IO, inter-core FIFO, spinlocks, divider, interpolators |
| PIO x2       | `pio_controller.vhd`          | Programmable IO state machines (4 SM each)   |
| PWM          | `pwm_controller.vhd`          | 16 slices, phase-correct, 8.4 fixed-point divider |
| QSPI XIP     | `qspi_xip_controller.vhd`     | QSPI flash execute-in-place with cache       |
| USB Device   | `usb_device.vhd`              | USB 2.0 full-speed device controller         |
| UART         | `uart_ahb.vhd`                | AHB-Lite UART                                |
| SPI          | `spi_master_ahb.vhd`          | AHB-Lite SPI master                          |
| I2C          | `i2c_master_ahb.vhd`          | AHB-Lite I2C master                          |
| ADC          | `adc_controller.vhd`          | Multi-channel ADC                            |
| WDT          | `wdt_controller.vhd`          | Watchdog timer                               |
| RTC          | `rtc_controller.vhd`          | Real-time clock                              |

---

## Key Subsystems

### PIO (Programmable IO)
- 4 state machines per PIO block, 32 instruction words each.
- Independent clock dividers, side-set, delay.
- TX/RX FIFOs (4-deep), IRQ, pin mapping via PINCTRL.

### SIO (Single-Cycle IO)
- GPIO in/out with set/clr/xor atomic operations.
- Inter-core mailbox FIFO (8-deep).
- 32 hardware spinlocks (`SPINLOCK0-31`).
- Hardware signed/unsigned divider.
- Two interpolators (INTERP0/1) with accumulators and base registers.

### Boot ROM
- `rp2040_bootrom.vhd`: Boot stage with USB/UART recovery support.

### USB Endpoints
- `rp2040_usb_endpoints.vhd`: Endpoint FIFO management for USB device mode.

### SRAM Banking
- `rp2040_sram_bank.vhd`: 6 KB SRAM banks with striped interleave for dual-core access.

---

## Testbench

```bash
ghdl -a --std=08 rp2040_top.vhd rp2040_testbench.vhd
ghdl -e --std=08 rp2040_testbench
ghdl -r --std=08 rp2040_testbench --vcd=rp2040.vcd
```
