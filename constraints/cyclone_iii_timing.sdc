# =============================================================================
# Cyclone III FPGA - SDC Timing Constraints
# =============================================================================
# Target Device : EP3C16F484C6N (Cyclone III, DE0 Board)
# Top-Level      : soc_top
# Input Clock    : 50 MHz on CLOCK_50 (pin R8)
# PLL Outputs    : 100 MHz (core clock), 25 MHz (peripheral clock)
# =============================================================================
# This file is referenced by Quartus via:
#   set_global_assignment -name SDC_FILE constraints/cyclone_iii_timing.sdc
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Base / Master Clock Constraints
# -----------------------------------------------------------------------------

# 50 MHz input clock from the onboard oscillator (CLOCK_50, pin R8).
# Period = 20.000 ns, 50% duty cycle.
create_clock -name {CLOCK_50} -period 20.000 -waveform {0.000 10.000} [get_ports {CLOCK_50}]

# -----------------------------------------------------------------------------
# 2. PLL-Generated Clock Constraints
# -----------------------------------------------------------------------------
# The PLL (ALTPLL megafunction) takes CLOCK_50 as the reference and produces
# two derived clocks:
#   - clk_100 : 100 MHz core/system clock  (period = 10.000 ns)
#   - clk_25  : 25 MHz peripheral clock     (period = 40.000 ns)
#
# Use create_generated_clock to formally relate them to the input clock so
# that Quartus TimeQuest can compute proper clock-domain crossings.
# -----------------------------------------------------------------------------

# 100 MHz core clock output from PLL (c0 output).
create_generated_clock -name {clk_100} \
    -source [get_ports {CLOCK_50}] \
    -multiply_by 2 \
    -duty_cycle 50.00 \
    [get_pins {pll_inst|altpll_component|clk[0]}]

# 25 MHz peripheral clock output from PLL (c1 output).
create_generated_clock -name {clk_25} \
    -source [get_ports {CLOCK_50}] \
    -divide_by 2 \
    -duty_cycle 50.00 \
    [get_pins {pll_inst|altpll_component|clk[1]}]

# -----------------------------------------------------------------------------
# 3. Clock Uncertainty Margins
# -----------------------------------------------------------------------------
# Apply a conservative uncertainty budget to account for PLL jitter and
# on-chip clock distribution skew.
# -----------------------------------------------------------------------------
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_50}] 0.200
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_50}] 0.200
set_clock_uncertainty -rise_from [get_clocks {clk_100}]  -rise_to [get_clocks {clk_100}]  0.150
set_clock_uncertainty -fall_from [get_clocks {clk_100}]  -fall_to [get_clocks {clk_100}]  0.150
set_clock_uncertainty -rise_from [get_clocks {clk_25}]   -rise_to [get_clocks {clk_25}]   0.250
set_clock_uncertainty -fall_from [get_clocks {clk_25}]   -fall_to [get_clocks {clk_25}]   0.250

# -----------------------------------------------------------------------------
# 4. False Paths - Asynchronous Reset Networks
# -----------------------------------------------------------------------------
# The reset signal (reset_n, active-low) is asynchronous by design. It is
# synchronized inside the design via a reset synchronizer, so the static
# timing analyzer should not attempt to time the reset distribution tree.
# -----------------------------------------------------------------------------
set_false_path -from [get_ports {reset_n}] -to [get_registers -hierarchical {*reset_sync*}]
set_false_path -from [get_ports {RESET_n}] -to [get_registers -hierarchical {*reset_sync*}]

# Cover any internal reset synchronizer fan-out to all registers.
set_false_path -from [get_registers -hierarchical {*reset_sync*}] -to [get_registers -hierarchical *]

# Also treat the reset input port as having no arrival requirement.
set_false_path -from [get_ports {reset_n}]
set_false_path -from [get_ports {RESET_n}]

# -----------------------------------------------------------------------------
# 5. Multicycle Paths - Multi-Cycle Peripherals
# -----------------------------------------------------------------------------
# Several peripherals operate on slower clocks or require multiple cycles to
# complete a single data transfer. These paths are declared as multicycle to
# relax the timing requirement accordingly.
# -----------------------------------------------------------------------------

# SPI controller: data is sampled every 4 clock cycles (SPI clk divider = 4).
set_multicycle_path -start -from [get_clocks {clk_100}] -to [get_clocks {clk_100}] 4 \
    -through [get_pins -hierarchical {*spi_master*|shift_reg*}]
set_multicycle_path -hold  -from [get_clocks {clk_100}] -to [get_clocks {clk_100}] 3 \
    -through [get_pins -hierarchical {*spi_master*|shift_reg*}]

# I2C controller: operates at ~100 kHz; data register updates span 8 cycles.
set_multicycle_path -start -from [get_clocks {clk_100}] -to [get_clocks {clk_100}] 8 \
    -through [get_pins -hierarchical {*i2c_master*|data_reg*}]
set_multicycle_path -hold  -from [get_clocks {clk_100}] -to [get_clocks {clk_100}] 7 \
    -through [get_pins -hierarchical {*i2c_master*|data_reg*}]

# UART controller: baud-rate divided; the shift register updates once per bit
# period (16x oversampling). Treat as a 16-cycle path.
set_multicycle_path -start -from [get_clocks {clk_100}] -to [get_clocks {clk_100}] 16 \
    -through [get_pins -hierarchical {*uart_tx*|shift_reg*}]
set_multicycle_path -hold  -from [get_clocks {clk_100}] -to [get_clocks {clk_100}] 15 \
    -through [get_pins -hierarchical {*uart_tx*|shift_reg*}]
set_multicycle_path -start -from [get_clocks {clk_100}] -to [get_clocks {clk_100}] 16 \
    -through [get_pins -hierarchical {*uart_rx*|shift_reg*}]
set_multicycle_path -hold  -from [get_clocks {clk_100}] -to [get_clocks {clk_100}] 15 \
    -through [get_pins -hierarchical {*uart_rx*|shift_reg*}]

# SD card controller (SDIO): multi-cycle data path across the slower SD clock.
set_multicycle_path -from [get_clocks {clk_25}] -to [get_clocks {clk_25}] 2 \
    -through [get_pins -hierarchical {*sd_sdio*|data_reg*}]
set_multicycle_path -hold -from [get_clocks {clk_25}] -to [get_clocks {clk_25}] 1 \
    -through [get_pins -hierarchical {*sd_sdio*|data_reg*}]

# Ethernet MAC: MII TX/RX paths run at 25 MHz (2.5x slower than core).
set_multicycle_path -from [get_clocks {clk_100}] -to [get_clocks {clk_25}] 2 \
    -through [get_pins -hierarchical {*ethernet_mac*|tx_fifo*}]
set_multicycle_path -from [get_clocks {clk_25}] -to [get_clocks {clk_100}] 2 \
    -through [get_pins -hierarchical {*ethernet_mac*|rx_fifo*}]

# -----------------------------------------------------------------------------
# 6. Input Delay Constraints - External Buses
# -----------------------------------------------------------------------------
# These define the external-to-FPGA setup/hold relationships for signals
# arriving at the device pins relative to the relevant clock.
# -----------------------------------------------------------------------------

# External SRAM bus (read data) - referenced to clk_100.
set_input_delay -clock [get_clocks {clk_100}] -max 5.000 [get_ports {sram_data[*]}]
set_input_delay -clock [get_clocks {clk_100}] -min 1.000 [get_ports {sram_data[*]}]

# USB D+/D- inputs - asynchronous, referenced to clk_100 for sampling.
set_input_delay -clock [get_clocks {clk_100}] -max 4.000 [get_ports {usb_dp}]
set_input_delay -clock [get_clocks {clk_100}] -min 1.000 [get_ports {usb_dp}]
set_input_delay -clock [get_clocks {clk_100}] -max 4.000 [get_ports {usb_dm}]
set_input_delay -clock [get_clocks {clk_100}] -min 1.000 [get_ports {usb_dm}]

# Ethernet RX inputs (MII) - referenced to clk_25.
set_input_delay -clock [get_clocks {clk_25}] -max 8.000 [get_ports {eth_rxd[*]}]
set_input_delay -clock [get_clocks {clk_25}] -min 2.000 [get_ports {eth_rxd[*]}]
set_input_delay -clock [get_clocks {clk_25}] -max 8.000 [get_ports {eth_rx_dv}]
set_input_delay -clock [get_clocks {clk_25}] -min 2.000 [get_ports {eth_rx_dv}]
set_input_delay -clock [get_clocks {clk_25}] -max 8.000 [get_ports {eth_rx_clk}]
set_input_delay -clock [get_clocks {clk_25}] -min 2.000 [get_ports {eth_rx_clk}]

# SD card DAT/CMD inputs - referenced to clk_25.
set_input_delay -clock [get_clocks {clk_25}] -max 10.000 [get_ports {sd_dat[*]}]
set_input_delay -clock [get_clocks {clk_25}] -min 2.000  [get_ports {sd_dat[*]}]
set_input_delay -clock [get_clocks {clk_25}] -max 10.000 [get_ports {sd_cmd}]
set_input_delay -clock [get_clocks {clk_25}] -min 2.000  [get_ports {sd_cmd}]

# -----------------------------------------------------------------------------
# 7. Output Delay Constraints - External Buses
# -----------------------------------------------------------------------------
# These define the FPGA-to-external clock-to-out requirements.
# -----------------------------------------------------------------------------

# External SRAM bus (address / control / write data) - referenced to clk_100.
set_output_delay -clock [get_clocks {clk_100}] -max 4.000 [get_ports {sram_addr[*]}]
set_output_delay -clock [get_clocks {clk_100}] -min 1.000 [get_ports {sram_addr[*]}]
set_output_delay -clock [get_clocks {clk_100}] -max 4.000 [get_ports {sram_data[*]}]
set_output_delay -clock [get_clocks {clk_100}] -min 1.000 [get_ports {sram_data[*]}]
set_output_delay -clock [get_clocks {clk_100}] -max 4.000 [get_ports {sram_oe_n}]
set_output_delay -clock [get_clocks {clk_100}] -min 1.000 [get_ports {sram_oe_n}]
set_output_delay -clock [get_clocks {clk_100}] -max 4.000 [get_ports {sram_we_n}]
set_output_delay -clock [get_clocks {clk_100}] -min 1.000 [get_ports {sram_we_n}]
set_output_delay -clock [get_clocks {clk_100}] -max 4.000 [get_ports {sram_cs_n}]
set_output_delay -clock [get_clocks {clk_100}] -min 1.000 [get_ports {sram_cs_n}]

# USB D+/D- outputs.
set_output_delay -clock [get_clocks {clk_100}] -max 4.000 [get_ports {usb_dp}]
set_output_delay -clock [get_clocks {clk_100}] -min 1.000 [get_ports {usb_dp}]
set_output_delay -clock [get_clocks {clk_100}] -max 4.000 [get_ports {usb_dm}]
set_output_delay -clock [get_clocks {clk_100}] -min 1.000 [get_ports {usb_dm}]

# Ethernet TX outputs (MII) - referenced to clk_25.
set_output_delay -clock [get_clocks {clk_25}] -max 6.000 [get_ports {eth_txd[*]}]
set_output_delay -clock [get_clocks {clk_25}] -min 1.000 [get_ports {eth_txd[*]}]
set_output_delay -clock [get_clocks {clk_25}] -max 6.000 [get_ports {eth_tx_en}]
set_output_delay -clock [get_clocks {clk_25}] -min 1.000 [get_ports {eth_tx_en}]
set_output_delay -clock [get_clocks {clk_25}] -max 6.000 [get_ports {eth_tx_clk}]
set_output_delay -clock [get_clocks {clk_25}] -min 1.000 [get_ports {eth_tx_clk}]

# SD card CLK/CMD/DAT outputs - referenced to clk_25.
set_output_delay -clock [get_clocks {clk_25}] -max 8.000 [get_ports {sd_clk}]
set_output_delay -clock [get_clocks {clk_25}] -min 2.000 [get_ports {sd_clk}]
set_output_delay -clock [get_clocks {clk_25}] -max 8.000 [get_ports {sd_cmd}]
set_output_delay -clock [get_clocks {clk_25}] -min 2.000 [get_ports {sd_cmd}]
set_output_delay -clock [get_clocks {clk_25}] -max 8.000 [get_ports {sd_dat[*]}]
set_output_delay -clock [get_clocks {clk_25}] -min 2.000 [get_ports {sd_dat[*]}]

# -----------------------------------------------------------------------------
# 8. Maximum Delay - Slow-Speed Peripherals
# -----------------------------------------------------------------------------
# UART, I2C, and SPI operate at significantly lower data rates than the core
# clock. Rather than constraining them to a single cycle, a maximum delay
# (set_max_delay) is applied to relax the fitter while still bounding the
# path latency.
# -----------------------------------------------------------------------------

# UART TX/RX - max 50 ns (effectively unconstrained at 9600-115200 baud).
set_max_delay -from [get_registers -hierarchical {*uart_tx*}] -to [get_ports {uart_tx}] 50.000
set_max_delay -from [get_ports {uart_rx}] -to [get_registers -hierarchical {*uart_rx*}] 50.000

# I2C SDA/SCL - max 100 ns (supports up to 1 MHz fast-mode+).
set_max_delay -from [get_registers -hierarchical {*i2c_master*}] -to [get_ports {i2c_sda}] 100.000
set_max_delay -from [get_registers -hierarchical {*i2c_master*}] -to [get_ports {i2c_scl}] 100.000
set_max_delay -from [get_ports {i2c_sda}] -to [get_registers -hierarchical {*i2c_master*}] 100.000
set_max_delay -from [get_ports {i2c_scl}] -to [get_registers -hierarchical {*i2c_master*}] 100.000

# SPI MOSI/MISO/SCK/CS - max 30 ns (supports up to ~33 MHz SPI clock).
set_max_delay -from [get_registers -hierarchical {*spi_master*}] -to [get_ports {spi_mosi}] 30.000
set_max_delay -from [get_registers -hierarchical {*spi_master*}] -to [get_ports {spi_sck}]  30.000
set_max_delay -from [get_registers -hierarchical {*spi_master*}] -to [get_ports {spi_cs_n}] 30.000
set_max_delay -from [get_ports {spi_miso}] -to [get_registers -hierarchical {*spi_master*}] 30.000

# CAN TX/RX - max 50 ns (CAN runs up to 1 Mbps).
set_max_delay -from [get_registers -hierarchical {*can_controller*}] -to [get_ports {can_tx}] 50.000
set_max_delay -from [get_ports {can_rx}] -to [get_registers -hierarchical {*can_controller*}] 50.000

# -----------------------------------------------------------------------------
# 9. Clock Domain Crossing (CDC) False Paths
# -----------------------------------------------------------------------------
# Between clk_100 (core) and clk_25 (peripherals) the data is passed through
# dual-clock FIFOs or handshake synchronizers. These crossings are explicitly
# marked as false paths so the analyzer does not try to time them as single-
# cycle transfers.
# -----------------------------------------------------------------------------
set_false_path -from [get_clocks {clk_100}] -to [get_clocks {clk_25}] \
    -through [get_registers -hierarchical {*cdc_sync*}]
set_false_path -from [get_clocks {clk_25}] -to [get_clocks {clk_100}] \
    -through [get_registers -hierarchical {*cdc_sync*}]

# -----------------------------------------------------------------------------
# End of SDC
# -----------------------------------------------------------------------------
