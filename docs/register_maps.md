# Register Maps

Summary of AHB-Lite register offsets for each major peripheral. All offsets are byte addresses relative to the peripheral's base address. Registers are 32-bit word-aligned.

---

## Cryptography

### CRC (`crc_accelerator.vhd`)

| Offset | Register | Access | Description                                  |
|--------|----------|--------|----------------------------------------------|
| 0x00   | CTRL     | RW     | [2:0] mode, [3] reset, [4] bit-rev in, [5] bit-rev out |
| 0x04   | SEED     | RW     | Initial CRC value                            |
| 0x08   | DATA     | WO     | Write data to compute CRC                    |
| 0x0C   | RESULT   | RO     | Current CRC result                           |
| 0x10   | POLY     | RW     | Custom polynomial                            |

### AES (`aes_accelerator.vhd`)

| Offset | Register  | Access | Description                                  |
|--------|-----------|--------|----------------------------------------------|
| 0x00   | CTRL      | RW     | [0] start, [1] mode, [2:3] key size          |
| 0x04   | STAT      | RO     | [0] busy, [1] done                           |
| 0x08   | KEY0-3    | RW     | AES-128 key (4 words)                        |
| 0x18   | KEY4-7    | RW     | AES-256 key extension (4 words)              |
| 0x28   | IV0-3     | RW     | Initialization vector (4 words)              |
| 0x38   | DATA_IN   | WO     | Input plaintext/ciphertext                   |
| 0x3C   | DATA_OUT  | RO     | Output ciphertext/plaintext                  |

### SHA-256 (`sha256_accelerator.vhd`)

| Offset | Register  | Access | Description                                  |
|--------|-----------|--------|----------------------------------------------|
| 0x00   | CTRL      | RW     | [0] start, [1] reset                         |
| 0x04   | STAT      | RO     | [0] busy, [1] done                           |
| 0x08   | LEN       | RW     | Message length in bytes                      |
| 0x0C   | DATA_IN   | WO     | Message data (32-bit words)                  |
| 0x10   | HASH0-7   | RO     | Hash output (8 x 32-bit words, H0-H7)        |

### TRNG (`trng_controller.vhd`)

| Offset | Register | Access | Description                                  |
|--------|----------|--------|----------------------------------------------|
| 0x00   | CTRL     | RW     | [0] enable, [1] reset                        |
| 0x04   | STAT     | RO     | [0] ready, [1] overrun                       |
| 0x08   | DATA     | RO     | 32-bit random data                           |
| 0x0C   | SEED     | RW     | PRNG post-processing seed                    |

### FPU (`fpu_single.vhd`)

| Offset | Register | Access | Description                                  |
|--------|----------|--------|----------------------------------------------|
| 0x00   | CTRL     | RW     | [3:0] operation, [4] start                   |
| 0x04   | STAT     | RO     | [0] busy, [1] done, [2] inf, [3] nan, [4] zero, [5] ovf, [6] unf |
| 0x08   | OP_A     | RW     | Operand A (float32)                          |
| 0x0C   | OP_B     | RW     | Operand B (float32)                          |
| 0x10   | OP_C     | RW     | Operand C (for FMA)                          |
| 0x14   | RESULT   | RO     | Result (float32)                             |
| 0x18   | FLAGS    | RO     | Exception flags                              |

---

## Communication

### CAN FD (`canfd_controller.vhd`)

| Offset | Register  | Access | Description                                  |
|--------|-----------|--------|----------------------------------------------|
| 0x00   | CTRL      | RW     | [0] enable, [1] irq_en, [2] loopback, [3] fd_mode, [4] start_tx |
| 0x04   | STAT      | RO     | [0] idle, [1] tx_busy, [2] rx_ready, [3] error, [4] bus_off |
| 0x08   | ID        | RW     | CAN frame identifier (11/29 bit)             |
| 0x0C   | DLC       | RW     | Data length code (0-64 bytes FD)             |
| 0x10   | DATA0-15  | RW     | 16 x 32-bit data words (64 bytes max)        |
| 0x50   | BTR       | RW     | Bit timing register                          |

### USB OTG (`usb20_otg_controller.vhd`)

| Offset | Register   | Access | Description                                  |
|--------|------------|--------|----------------------------------------------|
| 0x00   | CTRL       | RW     | [0] enable, [1] irq_en, [2] host_mode, [3] reset |
| 0x04   | STAT       | RO     | [0] connected, [1] suspended, [2] tx_done, [3] rx_ready, [4] error |
| 0x08   | DEV_ADDR   | RW     | Device address [6:0], [7] enable             |
| 0x0C   | EP_CFG     | RW     | Endpoint config (number, dir, type, max pkt) |
| 0x10   | EP_DATA    | RW     | Endpoint data FIFO port                      |
| 0x14   | HOST_CTRL  | RW     | Host control (token, endpoint, device addr)  |
| 0x18   | HOST_ADDR  | RW     | Host target device address                   |

### Modbus (`modbus_controller.vhd`)

| Offset | Register    | Access | Description                                |
|--------|-------------|--------|--------------------------------------------|
| 0x00   | CTRL        | RW     | [0] enable, [1] irq_en, [2] rtu_mode, [3] master_mode, [4] start_tx |
| 0x04   | STAT        | RO     | [0] idle, [1] tx_busy, [2] rx_ready, [3] crc_error |
| 0x08   | SLAVE_ADDR  | RW     | Modbus slave address (1-247)               |
| 0x0C   | FUNC_CODE   | RW     | Modbus function code                       |
| 0x10   | REG_ADDR    | RW     | Starting register address                  |
| 0x14   | REG_COUNT   | RW     | Number of registers                        |
| 0x18   | DATA_IN     | WO     | Write data to TX buffer                    |
| 0x1C   | DATA_OUT    | RO     | Read data from RX buffer                   |
| 0x20   | CRC         | RO     | Computed CRC-16                            |

### LIN (`lin_controller.vhd`)

| Offset | Register | Access | Description                                  |
|--------|----------|--------|----------------------------------------------|
| 0x00   | CTRL     | RW     | [0] enable, [1] irq_en, [2] master_mode, [3] start_tx |
| 0x04   | STAT     | RO     | [0] idle, [1] tx_busy, [2] rx_ready, [3] checksum_error |
| 0x08   | ID       | RW     | LIN protected identifier (PID + parity)      |
| 0x10   | DATA0-7  | RW     | 8 data bytes                                 |
| 0x30   | BAUD     | RW     | Baud rate divisor                            |

### Ethernet PHY (`ethernet_phy_if.vhd`)

| Offset | Register   | Access | Description                                |
|--------|------------|--------|--------------------------------------------|
| 0x00   | CTRL       | RW     | [0] enable, [1] irq_en, [2] rgmii_mode, [3] start_mdio |
| 0x04   | STAT       | RO     | [0] link_up, [1] speed, [2] full_duplex, [3] mdio_done |
| 0x08   | PHY_ADDR   | RW     | PHY address [4:0], reg address [12:8]      |
| 0x0C   | PHY_DATA   | RW     | MDIO read/write data (16-bit in [15:0])    |
| 0x10   | TX_CTRL    | RW     | TX control (enable, length)                |
| 0x14   | RX_STAT    | RO     | RX status (packet count, length, error)    |

### SD/SDIO (`sd_sdio_controller.vhd`)

| Offset | Register  | Access | Description                                |
|--------|-----------|--------|--------------------------------------------|
| 0x00   | CTRL      | RW     | [0] enable, [1] mode, [2] bus_width, [7:4] clkdiv |
| 0x04   | STAT      | RO     | [0] busy, [1] card_present, [2] data_ready, [3] error |
| 0x08   | CMD       | RW     | SD command index (0-63)                    |
| 0x0C   | ARG       | RW     | 32-bit command argument                    |
| 0x10   | RESP0-3   | RO     | Response words (R1/R3/R7 or R2)            |
| 0x20   | DATA_IN   | RO     | Read data from card                        |
| 0x24   | DATA_OUT  | WO     | Write data to card                         |
| 0x28   | BLKSIZE   | RW     | Block size (default 512)                   |
| 0x2C   | BLKCNT    | RW     | Block count for transfer                   |

### 1-Wire (`onewire_controller.vhd`)

| Offset | Register | Access | Description                                  |
|--------|----------|--------|----------------------------------------------|
| 0x00   | CTRL     | RW     | [0] enable, [1] reset_pulse, [2] search_rom  |
| 0x04   | STAT     | RO     | [0] busy, [1] presence_detect, [2] short_circuit |
| 0x08   | TXDATA   | WO     | Byte to transmit                             |
| 0x0C   | RXDATA   | RO     | Byte received                                |
| 0x10   | BITCTRL  | RW     | [0] send_bit, [1] bit_value, [2] read_bit    |
| 0x14   | BITSTAT  | RO     | [0] bit_value_read                           |

### EXTI (`exti_controller.vhd`)

| Offset | Register | Access | Description                                  |
|--------|----------|--------|----------------------------------------------|
| 0x00   | IMR      | RW     | Interrupt mask register (per line)           |
| 0x04   | EMR      | RW     | Event mask register (per line)               |
| 0x08   | RTSR     | RW     | Rising trigger selection                     |
| 0x0C   | FTSR     | RW     | Falling trigger selection                    |
| 0x10   | PR       | RC     | Pending register (write-1-to-clear)          |
| 0x14   | SWIER    | WO     | Software interrupt/event trigger             |

### I2S TDM (`i2s_tdm_controller.vhd`)

| Offset | Register    | Access | Description                                |
|--------|-------------|--------|--------------------------------------------|
| 0x00   | CTRL        | RW     | [0] enable, [1] irq_en, [2] tdm_mode, [3] master_clk |
| 0x04   | STAT        | RO     | [0] tx_ready, [1] rx_ready, [2] busy       |
| 0x08   | TDM_SLOTS   | RW     | Number of TDM slots (8 or 16)              |
| 0x0C   | SLOT_SIZE   | RW     | Slot width in bits (16, 24, 32)            |
| 0x10   | TX_DATA     | WO     | Transmit data (write triggers TX slot)     |
| 0x14   | RX_DATA     | RO     | Received data (current slot)               |

---

## Timers & Motor Control

### QEI (`qei_controller.vhd`)

| Offset | Register | Access | Description                                  |
|--------|----------|--------|----------------------------------------------|
| 0x00   | CTRL     | RW     | [0] enable, [1] irq_en, [2] index_reset, [3] vel_enable |
| 0x04   | STAT     | RO     | [0] dir, [1] index_detected, [2] overflow, [3] vel_ready |
| 0x08   | POSITION | RO     | 32-bit position counter                      |
| 0x0C   | VELOCITY | RO     | Estimated velocity (counts/sample)           |
| 0x10   | INDEX    | RO     | Index pulse count                            |
| 0x14   | MAX_POS  | RW     | Maximum position (modulo counting)           |

### TSC (`tsc_controller.vhd`)

| Offset | Register        | Access | Description                              |
|--------|-----------------|--------|------------------------------------------|
| 0x00   | CTRL            | RW     | [0] enable, [1] irq_en, [2] start_scan, [3] continuous |
| 0x04   | STAT            | RO     | [0] busy, [1] done, [8:15] touch_detected |
| 0x08   | CHARGE_TIME     | RW     | Charge transfer cycles per channel       |
| 0x0C   | DISCHARGE_TIME  | RW     | Discharge cycles per channel             |
| 0x10   | THRESHOLD0-7    | RW     | Per-channel touch thresholds             |
| 0x30   | VALUE0-7        | RO     | Per-channel measured values              |

### LPTIM (`lptim_controller.vhd`)

| Offset | Register | Access | Description                                  |
|--------|----------|--------|----------------------------------------------|
| 0x00   | CTRL     | RW     | [0] enable, [1] irq_en, [2] ext_clk, [3] one_pulse, [4] cnt_en |
| 0x04   | STAT     | RO     | [0] arr_matched, [1] cmp_matched, [2] running |
| 0x08   | ARR      | RW     | Auto-reload value (16-bit)                   |
| 0x0C   | CMP      | RW     | Compare value (16-bit)                       |
| 0x10   | CNT      | RO     | Current counter value                        |
| 0x14   | IER      | RW     | Interrupt enable (bit0=arr, bit1=cmp)        |

### RTCC (`rtcc_controller.vhd`)

| Offset | Register      | Access | Description                              |
|--------|---------------|--------|------------------------------------------|
| 0x00   | CTRL          | RW     | [0] enable, [1] irq_en, [2] alarm_en, [3] hr_format |
| 0x04   | STAT          | RO     | [0] running, [1] alarm_triggered         |
| 0x08   | SECONDS       | RW     | Seconds                                  |
| 0x0C   | MINUTES       | RW     | Minutes                                  |
| 0x10   | HOURS         | RW     | Hours                                    |
| 0x14   | DAYS          | RW     | Days                                     |
| 0x18   | MONTHS        | RW     | Months                                   |
| 0x1C   | YEARS         | RW     | Years                                    |
| 0x20   | ALRM_SECONDS  | RW     | Alarm seconds                            |
| 0x24   | ALRM_MINUTES  | RW     | Alarm minutes                            |
| 0x28   | ALRM_HOURS    | RW     | Alarm hours                              |
| 0x2C   | ALRM_DAYS     | RW     | Alarm days                               |
| 0x30   | ALRM_MONTHS   | RW     | Alarm months                             |
| 0x34   | ALRM_YEARS    | RW     | Alarm years                              |
| 0x38   | ALRM_MASK     | RW     | [0]=sec, [1]=min, [2]=hr, [3]=day, [4]=month, [5]=year |

---

## Analog

### PGA (`pga_controller.vhd`)

| Offset | Register       | Access | Description                              |
|--------|----------------|--------|------------------------------------------|
| 0x00   | CTRL           | RW     | [0] enable, [1] irq_en, [2] start_scan, [3] continuous |
| 0x04   | STAT           | RO     | [0] busy, [1] done, [2] channel_ready    |
| 0x08   | CHANNEL_CFG    | RW     | [3:0] active channel, [7:4] scan_mask    |
| 0x10   | GAIN0-7        | RW     | Per-channel gain (3-bit: 0=1x..6=64x)    |
| 0x30   | VALUE0-7       | RO     | Per-channel converted values (12-bit)    |

### Comparator (`comparator_controller.vhd`)

| Offset | Register | Access | Description                                  |
|--------|----------|--------|----------------------------------------------|
| 0x00   | CTRL     | RW     | [0] enable, [1] irq_en, [4:7] per-comp enable |
| 0x04   | STAT     | RO     | [0:3] current output, [4:7] output changed   |
| 0x10   | HYST0-3  | RW     | Hysteresis threshold (4-bit each)             |
| 0x20   | OUTPUT   | RO     | Comparator output register [3:0]              |

---

## System

### CMU (`cmu_controller.vhd`)

| Offset | Register   | Access | Description                              |
|--------|------------|--------|------------------------------------------|
| 0x00   | PLL_CTRL   | RW     | PLL control                              |
| 0x04   | PLL_STAT   | RO     | PLL status                               |
| 0x08   | CLK_SEL    | RW     | Clock source selection                   |
| 0x10   | CLK_DIV0-7 | RW     | Per-clock prescaler (16-bit)             |
| 0x30   | CLK_GATE   | RW     | Clock gating mask                        |

### PSC (`psc_controller.vhd`)

| Offset | Register   | Access | Description                              |
|--------|------------|--------|------------------------------------------|
| 0x00   | CTRL       | RW     | Control register                         |
| 0x04   | STAT       | RO     | Status register                          |
| 0x08   | PERI_GATE  | RW     | 32-bit peripheral clock gate mask        |
| 0x0C   | SLEEP_CFG  | RW     | Sleep configuration                      |
| 0x10   | WAKE_SRC   | RW     | 32-bit wake source enable mask           |

### Bus Matrix (`bus_matrix.vhd`)

Multi-master AHB interconnect — no programmer-visible registers (hardware routing only).

### Cache (`cache_controller.vhd`)

| Offset | Register    | Access | Description                              |
|--------|-------------|--------|------------------------------------------|
| 0x00   | CTRL        | RW     | [0] enable, [1] write_thru               |
| 0x04   | STAT        | RO     | [0] hit, [1] miss, [2] flushing          |
| 0x08   | HIT_COUNT   | RC     | Hit counter (write to clear)             |
| 0x0C   | MISS_COUNT  | RC     | Miss counter (write to clear)            |
| 0x10   | FLUSH       | WO     | Write any value to flush                 |

### MMU (`mmu_controller.vhd`)

| Offset | Register    | Access | Description                              |
|--------|-------------|--------|------------------------------------------|
| 0x00   | CTRL        | RW     | [0] enable, [1] irq_en                   |
| 0x04   | TLB_ENTRY   | RW     | Write VPN/PFN/flags to TLB index         |
| 0x08   | TLB_INDEX   | RW     | TLB index (0-15)                         |
| 0x0C   | FAULT_ADDR  | RO     | Faulting virtual address                 |
| 0x10   | FAULT_TYPE  | RO     | [0] page_fault, [1] permission, [2] tlb_miss |

### DAP (`dap_controller.vhd`)

| Offset | Register | Access | Description                              |
|--------|----------|--------|------------------------------------------|
| 0x00   | CTRL     | RW     | [0] swd_en, [1] jtag_en, [2] reset       |
| 0x04   | STAT     | RO     | [0] swd_active, [1] jtag_active, [2] dp_ready |
| 0x08   | DP_CTRL  | RW     | DP control register                      |
| 0x0C   | AP_CTRL  | RW     | AP control register                      |
| 0x10   | AP_DATA  | RW     | AP data register                         |

### MPU (`mpu_controller.vhd`)

| Offset | Register | Access | Description                              |
|--------|----------|--------|------------------------------------------|
| 0x00   | CTRL     | RW     | MPU control (enable, privdefena, hfnmiena) |
| 0x04   | RNR      | RW     | Region number selector (0-15)            |
| 0x08   | RBAR     | RW     | Region base address                      |
| 0x0C   | RASR     | RW     | Region size & attribute                  |
| 0x10   | RBAR_A1  | RW     | Alias 1 base address                     |
| 0x14   | RASR_A1  | RW     | Alias 1 size & attribute                 |
| 0x18   | RBAR_A2  | RW     | Alias 2 base address                     |
| 0x1C   | RASR_A2  | RW     | Alias 2 size & attribute                 |
| 0x20   | RBAR_A3  | RW     | Alias 3 base address                     |
| 0x24   | RASR_A3  | RW     | Alias 3 size & attribute                 |

### DSP (`dsp_extensions.vhd`)

| Offset | Register   | Access | Description                              |
|--------|------------|--------|------------------------------------------|
| 0x00   | CTRL       | RW     | [3:0] op, [4] start, [7] irq_en, [15:8] sat_bits |
| 0x04   | STAT       | RO     | [0] done, [1] sat_flag                   |
| 0x08   | OP_A       | RW     | Operand A (32-bit)                       |
| 0x0C   | OP_B       | RW     | Operand B (32-bit)                       |
| 0x10   | OP_C       | RW     | Operand C (accumulator)                  |
| 0x14   | RESULT_LO  | RO     | Result low word                          |
| 0x18   | RESULT_HI  | RO     | Result high word                         |
| 0x1C   | SAT_FLAG   | RO     | Saturation flag                          |

### DWT (`dwt_controller.vhd`)

| Offset | Register    | Access | Description                              |
|--------|-------------|--------|------------------------------------------|
| 0x00   | CTRL        | RW     | [0] CYCCNTENA, [5:2] numcomp (RO=4)      |
| 0x04   | CYCCNT      | RW     | Cycle counter                            |
| 0x08   | CPICNT      | RW     | CPI counter                              |
| 0x0C   | EXCCNT      | RW     | Exception counter                        |
| 0x10   | SLEEPCNT    | RW     | Sleep counter                            |
| 0x14   | LSUCNT      | RW     | LSU counter                              |
| 0x18   | FOLDCNT     | RW     | Fold counter                             |
| 0x20   | COMP0       | RW     | Comparator 0 address                     |
| 0x24   | MASK0       | RW     | Comparator 0 mask                        |
| 0x28   | FUNCTION0   | RW     | [0] enable, [3:2] match mode             |
| 0x30   | COMP1-3     | RW     | Comparators 1-3 (same layout, +0x10 each) |

### ITM (`itm_controller.vhd`)

| Offset | Register    | Access | Description                              |
|--------|-------------|--------|------------------------------------------|
| 0x000  | STIM0-31    | WO     | Stimulus ports (32 x 32-bit)             |
| 0x080  | TER         | RW     | Trace enable register (bit per port)     |
| 0x084  | TPR         | RW     | Trace privilege register                 |
| 0x088  | ITM_CTRL    | RW     | [0] ITMEN, [1] TXEN, [2] SYNCEN, [3] SWOEN |

### ETM (`etm_controller.vhd`)

| Offset | Register      | Access | Description                              |
|--------|---------------|--------|------------------------------------------|
| 0x00   | CTRL          | RW     | [0] ETMEN, [1] TRACEEN, [2] SYNCEN, [3] IRQEN |
| 0x04   | TRACE_EN      | RW     | Trace enable control                     |
| 0x08   | TRACE_STAT    | RO     | [0] tracing, [1] fifo_full, [2] sync_req |
| 0x10   | ADDR_COMP0-7  | RW     | Address comparators (+0x08 each)         |
| 0x14   | ADDR_MASK0-7  | RW     | Address masks (+0x08 each)               |

### NVIC (`nvic_tailchain.vhd`)

| Offset | Register | Access | Description                              |
|--------|----------|--------|------------------------------------------|
| 0x00   | ICSR     | RW     | [6:0] VECTACTIVE, [15:9] VECTPENDING, [31] PENDSVSET |
| 0x04   | ISER     | WO     | Interrupt set-enable (bit per IRQ)       |
| 0x08   | ICER     | WO     | Interrupt clear-enable                   |
| 0x0C   | ISPR     | WO     | Interrupt set-pending                    |
| 0x10   | ICPR     | WO     | Interrupt clear-pending                  |
| 0x14   | IABR     | RO     | Interrupt active (bit per IRQ)           |
| 0x18   | IPR0-7   | RW     | Priority registers (4 IRQs each)         |

---

## Synergy Peripherals

### DMAC (`synergy_dmac.vhd`)

| Offset         | Register   | Access | Description                              |
|----------------|------------|--------|------------------------------------------|
| 0x00           | DMAC_CTRL  | RW     | [0] enable, [1] round_robin              |
| 0x04           | DMAC_STAT  | RC     | [7:0] channel done flags                 |
| 0x08+ch*0x0C   | CHx_CTRL   | RW     | [0] enable, [1] irq_en, [2] trigger      |
| 0x0C+ch*0x0C   | CHx_SRC    | RW     | Source address                           |
| 0x10+ch*0x0C   | CHx_DST    | RW     | Destination address                      |
| 0x14+ch*0x0C   | CHx_LEN    | RW     | Transfer length in words                 |

### GPT (`synergy_gpt.vhd`)

| Offset         | Register   | Access | Description                              |
|----------------|------------|--------|------------------------------------------|
| 0x00           | GPT_CTRL   | RW     | [5:0] channel enable, [11:6] irq enable  |
| 0x04           | GPT_STAT   | RC     | [5:0] channel IRQ flags                  |
| 0x08+ch*0x0C   | GPTx_CNT   | RO     | Current counter value                    |
| 0x0C+ch*0x0C   | GPTx_PER   | RW     | Period / top value                       |
| 0x10+ch*0x0C   | GPTx_CC    | RW     | Compare/capture value                    |

### AGT (`synergy_agt.vhd`)

| Offset | Register | Access | Description                              |
|--------|----------|--------|------------------------------------------|
| 0x00   | AGT_CTRL | RW     | [0] enable, [1] irq_en, [2] mode         |
| 0x04   | AGT_STAT | RC     | [0] underflow flag                       |
| 0x08   | AGT_CNT  | RO     | Current 16-bit counter                   |
| 0x0C   | AGT_PER  | RW     | 16-bit period value                      |
| 0x10   | AGT_CC   | RW     | 16-bit compare/capture                   |

### ELC (`synergy_elc.vhd`)

| Offset | Register | Access | Description                              |
|--------|----------|--------|------------------------------------------|
| 0x00   | ELC_CTRL | RW     | [0] enable                               |
| 0x04   | ELC_STAT | RC     | [0] event_detected                       |
| 0x08   | ELSR0    | RW     | Event link setting 0                     |
| 0x0C   | ELSR1    | RW     | Event link setting 1                     |
| 0x10   | ELSR2    | RW     | Event link setting 2                     |
| 0x14   | ELSR3    | RW     | Event link setting 3                     |

### DTC (`synergy_dtc.vhd`)

| Offset | Register | Access | Description                              |
|--------|----------|--------|------------------------------------------|
| 0x00   | DTC_CTRL | RW     | [0] enable, [1] irq_en, [2] start        |
| 0x04   | DTC_STAT | RC     | [0] busy, [1] done                       |
| 0x08   | DTC_VEC  | RW     | Vector number triggering transfer        |
| 0x0C   | DTC_SRC  | RW     | Source address                           |
| 0x10   | DTC_DST  | RW     | Destination address                      |
| 0x14   | DTC_LEN  | RW     | Transfer length in words                 |

### SDHI (`synergy_sdhi.vhd`)

| Offset | Register     | Access | Description                              |
|--------|--------------|--------|------------------------------------------|
| 0x00   | SDHI_CTRL    | RW     | [0] enable, [1] irq_en, [2] 4bit_mode    |
| 0x04   | SDHI_STAT    | RC     | [0] cmd_done, [1] data_done, [2] card_detected, [3] error |
| 0x08   | SDHI_CMD     | RW     | Command index [5:0], [8] resp_expected, [9] data |
| 0x0C   | SDHI_ARG     | RW     | 32-bit command argument                  |
| 0x10   | SDHI_RESP0-3 | RO     | Response words                            |
| 0x20   | SDHI_DATA    | RW     | Data port (read/write)                   |
| 0x24   | SDHI_BLKSIZE | RW     | Block size in bytes                      |
| 0x28   | SDHI_BLKCNT  | RW     | Block count for transfer                 |

### GLCD (`synergy_glcd.vhd`)

| Offset | Register      | Access | Description                              |
|--------|---------------|--------|------------------------------------------|
| 0x00   | GLCD_CTRL     | RW     | [0] enable, [1] irq_en                   |
| 0x04   | GLCD_STAT     | RC     | [0] vsync, [1] hsync                     |
| 0x08   | GLCD_FB_ADDR  | RW     | Frame buffer base address                |
| 0x0C   | GLCD_HSYNC    | RW     | [15:0] h_front, [23:16] h_sync_width, [31:24] h_back |
| 0x10   | GLCD_VSYNC    | RW     | [15:0] v_front, [23:16] v_sync_width, [31:24] v_back |
| 0x14   | GLCD_WIDTH    | RW     | Display width in pixels                  |
| 0x18   | GLCD_HEIGHT   | RW     | Display height in lines                  |

---

## FPGA Wrappers

### PLL Wrapper (`fpga_pll_wrapper.vhd`)

| Offset | Register  | Access | Description                              |
|--------|-----------|--------|------------------------------------------|
| 0x00   | PLL_CTRL  | RW     | [0] reset (write 1 to assert PLL reset)  |
| 0x04   | PLL_STAT  | RO     | [0] locked                               |
| 0x08   | PLL_RESET | WO     | [0] soft_reset (write 1 to trigger pulse)|

### DSP Block (`fpga_dsp_block.vhd`)

| Offset | Register | Access | Description                              |
|--------|----------|--------|------------------------------------------|
| 0x00   | OP_A     | RW     | 18-bit signed operand A                  |
| 0x04   | OP_B     | RW     | 18-bit signed operand B                  |
| 0x08   | OP_C     | RW     | 18-bit signed operand C (subtract mode)  |
| 0x0C   | ACC_LO   | RW     | Accumulator low 32 bits                  |
| 0x10   | ACC_HI   | RW     | Accumulator high 4 bits                  |
| 0x14   | CTRL     | RW     | [0] start, [1] accumulate, [2] clear, [3] subtract, [4] irq_en |

### BRAM Controller (`fpga_bram_controller.vhd`)

| Offset | Register    | Access | Description                              |
|--------|-------------|--------|------------------------------------------|
| 0x00   | PORTA_ADDR  | RW     | Port A address                           |
| 0x04   | PORTA_DATA  | RW     | Port A data (write triggers WEN)         |
| 0x08   | PORTB_ADDR  | RW     | Port B address                           |
| 0x0C   | PORTB_DATA  | RW     | Port B data (write triggers WEN)         |

### Resource Monitor (`fpga_resource_monitor.vhd`)

| Offset | Register   | Access | Description                              |
|--------|------------|--------|------------------------------------------|
| 0x00   | LE_COUNT   | RO     | Active LE count                          |
| 0x04   | M9K_COUNT  | RO     | Active M9K block count                   |
| 0x08   | DSP_COUNT  | RO     | Active DSP block count                   |
| 0x0C   | PLL_COUNT  | RO     | Active PLL count                         |
| 0x10   | TOTAL_LE   | RW     | Total available LEs                      |
| 0x14   | TOTAL_M9K  | RW     | Total available M9K blocks               |
| 0x18   | TOTAL_DSP  | RW     | Total available DSP blocks               |
| 0x1C   | THRESHOLD  | RW     | Utilization threshold % for IRQ          |
