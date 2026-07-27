# FIR Digital Filter

This folder contains three VHDL implementations of an 8-tap Finite Impulse
Response (FIR) filter for the Cyclone III FPGA educational project.

- `fir_filter.vhd` — Top-level design with valid_in/valid_out handshake and
  a shift-register delay line plus multiply-accumulate (MAC) core.
- `fir_dataflow.vhd` — Dataflow model using concurrent signal assignments for
  the parallel multiplier array and adder tree.
- `fir_rtl.vhd` — RTL model with a 2-stage pipeline (delay line, then
  registered MAC) for improved timing closure.

Each filter uses 8-bit data, 8 taps, and the coefficient set
`(1, 2, 3, 4, 4, 3, 2, 1)`. Feeding an impulse (single 1 followed by zeros)
makes the output equal to the coefficients — the standard FIR verification
method.
