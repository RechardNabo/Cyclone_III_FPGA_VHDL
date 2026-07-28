# RISC-V RV32IMAC Soft-Core

VHDL implementation of a 32-bit RISC-V soft-core supporting the **RV32IMAC** instruction set (Base Integer + Multiply/Divide + Atomic + Compressed).

---

## Instruction Set Extensions

| Extension | File              | Description                                          |
|-----------|-------------------|------------------------------------------------------|
| I (base)  | `riscv_core.vhd`  | 32-bit integer ISA, 32 GP registers, load/store      |
| M         | `riscv_m_ext.vhd` | MUL, MULH, DIV, DIVU, REM, REMU                      |
| A         | `riscv_a_ext.vhd` | LR/SC, AMOADD, AMOSWAP, AMOAND/OR/XOR/MIN/MAX        |
| C         | `riscv_c_ext.vhd` | 16-bit compressed instructions (CA, CI, CR, CB, CJ)  |

---

## System Modules

| Module    | File            | Description                                              |
|-----------|-----------------|----------------------------------------------------------|
| CSR       | `riscv_csr.vhd` | Machine-mode CSRs: MSTATUS, MISA, MTVEC, MEPC, MCAUSE, MIP/MIE, MCYCLE |
| CLINT     | `riscv_clint.vhd`| Core-local interruptor (MSI, MTIMER, mtime/mtimecmp)    |
| PLIC      | `riscv_plic.vhd`| Platform-level interrupt controller (priority, enable, claim/complete) |
| PMP       | `riscv_pmp.vhd` | Physical memory protection (16 regions, TOR/NA4/NAPOT)  |

### CSR Address Map

| Offset | CSR      | Description                |
|--------|----------|----------------------------|
| 0x00   | MSTATUS  | Machine status             |
| 0x04   | MISA     | ISA & extensions           |
| 0x08   | MTVEC    | Trap vector base           |
| 0x0C   | MEPC     | Exception PC               |
| 0x10   | MCAUSE   | Exception cause            |
| 0x14   | MTVAL    | Trap value                 |
| 0x18   | MIP      | Interrupt pending          |
| 0x1C   | MIE      | Interrupt enable           |
| 0x20   | MCYCLE   | Cycle counter              |

---

## SoC Integration

The RISC-V core connects to peripherals via an AHB-Lite bus. Typical SoC topology:

```
RV32IMAC Core ──┐
  CSR / CLINT   ├── AHB-Lite Bus Matrix ── Peripherals (UART, SPI, GPIO, ...)
  PLIC / PMP    ──┘
```

## Testbench

```bash
ghdl -a --std=08 riscv_core.vhd riscv_csr.vhd riscv_clint.vhd riscv_plic.vhd riscv_pmp.vhd riscv_m_ext.vhd riscv_a_ext.vhd riscv_c_ext.vhd riscv_testbench.vhd
ghdl -e --std=08 riscv_testbench
ghdl -r --std=08 riscv_testbench --vcd=riscv.vcd
```
