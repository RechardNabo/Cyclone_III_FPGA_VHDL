# Peripheral IP Library

A collection of **87 AHB-Lite peripheral IP cores** in synthesizable VHDL, shared across all MCU architectures in this project.

---

## Communication

| Peripheral   | File                        | Description                              |
|--------------|-----------------------------|------------------------------------------|
| CAN          | `can_controller.vhd`        | CAN 2.0B, acceptance filter, bit timing  |
| CAN FD       | `canfd_controller.vhd`      | CAN FD, up to 64-byte frames, BTR config |
| USB Device   | `usb_device.vhd`            | USB 2.0 FS device, multi-endpoint FIFO   |
| USB OTG      | `usb20_otg_controller.vhd`  | USB 2.0 OTG, host/device modes           |
| Ethernet MAC | `ethernet_mac.vhd`          | MAC with TX/RX FIFO, multicast hash      |
| Ethernet PHY | `ethernet_phy_if.vhd`       | RMII/RGMII, MDIO management              |
| I2C          | `i2c_master_ahb.vhd`        | I2C master, programmable SCL             |
| SPI          | `spi_master_ahb.vhd`        | SPI master, 8/16/32-bit transfers        |
| UART         | `uart_ahb.vhd`              | UART with programmable baud              |
| I2S          | `i2s_master_ahb.vhd`        | I2S master, L/R channel                  |
| I2S TDM      | `i2s_tdm_controller.vhd`    | TDM mode, 8/16 slots                     |
| 1-Wire       | `onewire_controller.vhd`    | 1-Wire master, ROM search                |
| LIN          | `lin_controller.vhd`        | LIN master/slave, checksum               |
| Modbus       | `modbus_controller.vhd`     | Modbus RTU master/slave, CRC-16          |
| SD/SDIO      | `sd_sdio_controller.vhd`    | SD/SDIO, SPI/SD mode, 1/4-bit            |

## Cryptography

| Peripheral | File                        | Description                              |
|------------|-----------------------------|------------------------------------------|
| AES        | `aes_accelerator.vhd`       | AES-128/256, enc/dec, key + IV registers |
| SHA-256    | `sha256_accelerator.vhd`    | SHA-256 hash, 256-bit output             |
| CRC        | `crc_accelerator.vhd`       | CRC-16/32 (CCITT, Modbus, Ethernet)      |
| TRNG       | `trng_controller.vhd`       | True random number generator + PRNG      |

## Timers

| Peripheral | File                        | Description                              |
|------------|-----------------------------|------------------------------------------|
| PWM        | `pwm_controller.vhd`        | 16 slices, phase-correct, 8.4 divider    |
| LPTIM      | `lptim_controller.vhd`      | Low-power 16-bit timer                   |
| RTCC       | `rtcc_controller.vhd`       | Real-time clock calendar with alarm      |
| RTC        | `rtc_controller.vhd`        | Simple RTC with sub-second counter       |
| WDT        | `wdt_controller.vhd`        | Watchdog with windowed mode              |
| GPT        | `synergy_gpt.vhd`           | General Purpose Timer (Synergy)          |
| AGT        | `synergy_agt.vhd`           | Asynchronous General Timer (Synergy)     |
| Timer_A/B  | `msp430_timer_a/b.vhd`      | MSP430 16-bit timers                     |

## Analog

| Peripheral  | File                        | Description                              |
|-------------|-----------------------------|------------------------------------------|
| ADC         | `adc_controller.vhd`        | Multi-channel 12-bit ADC                 |
| DAC         | `dac_controller.vhd`        | Multi-channel 12-bit DAC                 |
| PGA         | `pga_controller.vhd`        | Programmable Gain Amplifier (1x-64x)     |
| Comparator  | `comparator_controller.vhd` | 4 comparators with hysteresis            |
| TSC         | `tsc_controller.vhd`        | Touch sensing controller                 |

## System

| Peripheral   | File                        | Description                              |
|--------------|-----------------------------|------------------------------------------|
| CMU          | `cmu_controller.vhd`        | Clock management unit, PLL, dividers     |
| PSC          | `psc_controller.vhd`        | Peripheral clock gating & sleep config   |
| Bus Matrix   | `bus_matrix.vhd`            | Multi-master AHB interconnect            |
| Cache        | `cache_controller.vhd`      | Instruction/data cache with statistics   |
| MMU          | `mmu_controller.vhd`        | Memory management unit, 16-entry TLB     |
| MPU          | `mpu_controller.vhd`        | Memory protection unit, 16 regions       |
| NVIC         | `nvic_tailchain.vhd`        | Nested vectored interrupt controller     |
| DWT          | `dwt_controller.vhd`        | Data watchpoint & trace                  |
| ITM          | `itm_controller.vhd`        | Instrumentation trace macrocell          |
| ETM          | `etm_controller.vhd`        | Embedded trace macrocell                 |
| DAP          | `dap_controller.vhd`        | Debug access port (SWD/JTAG)             |
| VTOR         | `vtor_controller.vhd`       | Vector table offset register             |
| NMI          | `nmi_controller.vhd`        | Non-maskable interrupt controller        |
| Bitband      | `bitband_controller.vhd`    | ARM bit-banding controller               |
| Bootloader   | `bootloader_rom.vhd`        | Boot ROM with UART/SPI/USB recovery      |
| Ext Mem      | `ext_mem_controller.vhd`    | External memory controller (NOR/SRAM)    |
| Ext SRAM     | `ext_sram_controller.vhd`   | External SRAM controller                 |
| Fuse/OTP     | `fuse_otp_controller.vhd`   | Fuse / OTP controller                    |
| DMA          | `dma_controller.vhd`        | DMA controller, multi-channel            |
| EXTI         | `exti_controller.vhd`       | External interrupt/event controller      |
| QSPI XIP     | `qspi_xip_controller.vhd`   | QSPI flash execute-in-place              |
| PIO          | `pio_controller.vhd`        | Programmable IO (RP2040-style)           |
| SIO          | `sio_controller.vhd`        | Single-cycle IO (RP2040-style)           |

## FPGA-Specific

| Peripheral     | File                          | Description                          |
|----------------|-------------------------------|--------------------------------------|
| PLL Wrapper    | `fpga_pll_wrapper.vhd`        | Cyclone III PLL wrapper              |
| DSP Block      | `fpga_dsp_block.vhd`          | 18x18 signed multiply-accumulate     |
| BRAM Controller| `fpga_bram_controller.vhd`    | Dual-port BRAM controller            |
| Resource Monitor| `fpga_resource_monitor.vhd` | LE/M9K/DSP/PLL utilization monitor   |

---

## Register Map Conventions

- All peripherals use **AHB-Lite** 32-bit bus interface.
- Registers are **word-aligned** (offsets in multiples of 4 bytes).
- `HADDR[9:2]` or `HADDR[7:2]` selects the register (256 or 64 word window).
- Bit fields documented in each file's header comment block.
- Read-only (RO), write-only (WO), read-write (RW) indicated per register.
- IRQ output (`*_irq`) where applicable, routed through NVIC/PLIC.
