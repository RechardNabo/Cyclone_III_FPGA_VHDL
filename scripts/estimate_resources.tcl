# =============================================================================
# Cyclone III FPGA - Resource Estimation Script
# =============================================================================
# Target Device : EP3C16F484C6N (Cyclone III, DE0 Board)
# Purpose       : Count total entities, estimate LE usage per module type,
#                 generate a summary table, and save to reports/.
# =============================================================================
# Usage (from Quartus command line or quartus_sh):
#   quartus_sh -t scripts/estimate_resources.tcl
#
# Or from within a standard Tcl shell (tclsh) - the script does not require
# the Quartus Tcl package; it parses VHDL files directly.
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
set src_dir     "src"
set report_dir  "reports"
set report_file "resource_estimate.txt"

# Resolve paths relative to the project root (parent of the scripts/ folder).
set script_dir [file dirname [info script]]
set project_root [file normalize [file join $script_dir ".."]]
set src_dir [file join $project_root $src_dir]
set report_dir [file join $project_root $report_dir]
set report_path [file join $report_dir $report_file]

# Ensure the reports directory exists.
file mkdir $report_dir

# -----------------------------------------------------------------------------
# Open the report file for writing
# -----------------------------------------------------------------------------
set fh [open $report_path w]

# Helper procedure to write a line to both stdout and the report file.
proc log_msg {msg} {
    global fh
    puts $msg
    puts $fh $msg
}

# Helper to write a separator line.
proc log_separator {{char "="} {len 78}} {
    global fh
    set sep [string repeat $char $len]
    puts $sep
    puts $fh $sep
}

# -----------------------------------------------------------------------------
# Module type classification
# -----------------------------------------------------------------------------
# Each VHDL source file is categorized into a module type based on its
# directory location and/or filename pattern. Estimated LE (Logic Element)
# counts are heuristic values based on typical Cyclone III implementations.
# -----------------------------------------------------------------------------

# Define estimated LE usage per module type.
# These are rough heuristics for a Cyclone III EP3C16 (15,408 LEs total).
array set le_estimates {
    "ALU"                   1200
    "Basic Logic"           20
    "Combinational"         150
    "Communication - CAN"   800
    "Communication - Eth"   2000
    "Communication - I2C"   400
    "Communication - I2S"   500
    "Communication - SPI"   350
    "Communication - UART"  300
    "Cryptography"          3000
    "FIR Filter"            1500
    "FSM"                   200
    "GCD Calculator"        250
    "ISA Controller"        600
    "Latch & Flip-Flop"     30
    "MCU Multi-Core"        5000
    "MCU Architecture"      4000
    "Memory"                200
    "Microprocessor"        2000
    "PCI Bridge"            800
    "Peripheral"            600
    "Processor FPGA IF"     500
    "Sequential"            100
    "Serial Adder"          150
    "Signal Processing"     2500
    "Signal/Variable"       50
    "Top Level"             1000
    "Unknown"               300
}

# Define M9K memory block estimates per module type.
array set m9k_estimates {
    "ALU"                   0
    "Basic Logic"           0
    "Combinational"         0
    "Communication - CAN"   0
    "Communication - Eth"   2
    "Communication - I2C"   0
    "Communication - I2S"   1
    "Communication - SPI"   0
    "Communication - UART"  0
    "Cryptography"          4
    "FIR Filter"            2
    "FSM"                   0
    "GCD Calculator"        0
    "ISA Controller"        0
    "Latch & Flip-Flop"     0
    "MCU Multi-Core"        8
    "MCU Architecture"      6
    "Memory"                4
    "Microprocessor"        2
    "PCI Bridge"            0
    "Peripheral"            1
    "Processor FPGA IF"     0
    "Sequential"            0
    "Serial Adder"          0
    "Signal Processing"     3
    "Signal/Variable"       0
    "Top Level"             2
    "Unknown"               0
}

# Define DSP block estimates per module type.
array set dsp_estimates {
    "ALU"                   0
    "Basic Logic"           0
    "Combinational"         0
    "Communication - CAN"   0
    "Communication - Eth"   0
    "Communication - I2C"   0
    "Communication - I2S"   1
    "Communication - SPI"   0
    "Communication - UART"  0
    "Cryptography"          2
    "FIR Filter"            4
    "FSM"                   0
    "GCD Calculator"        0
    "ISA Controller"        0
    "Latch & Flip-Flop"     0
    "MCU Multi-Core"        0
    "MCU Architecture"      0
    "Memory"                0
    "Microprocessor"        0
    "PCI Bridge"            0
    "Peripheral"            1
    "Processor FPGA IF"     0
    "Sequential"            0
    "Serial Adder"          0
    "Signal Processing"     4
    "Signal/Variable"       0
    "Top Level"             0
    "Unknown"               0
}

# Define PLL estimates per module type.
array set pll_estimates {
    "ALU"                   0
    "Basic Logic"           0
    "Combinational"         0
    "Communication - CAN"   0
    "Communication - Eth"   0
    "Communication - I2C"   0
    "Communication - I2S"   0
    "Communication - SPI"   0
    "Communication - UART"  0
    "Cryptography"          0
    "FIR Filter"            0
    "FSM"                   0
    "GCD Calculator"        0
    "ISA Controller"        0
    "Latch & Flip-Flop"     0
    "MCU Multi-Core"        0
    "MCU Architecture"      0
    "Memory"                0
    "Microprocessor"        0
    "PCI Bridge"            0
    "Peripheral"            0
    "Processor FPGA IF"     0
    "Sequential"            0
    "Serial Adder"          0
    "Signal Processing"     0
    "Signal/Variable"       0
    "Top Level"             1
    "Unknown"               0
}

# -----------------------------------------------------------------------------
# Classify a VHDL file into a module type
# -----------------------------------------------------------------------------
proc classify_module {filepath} {
    set normalized [file normalize $filepath]
    set dir [file dirname $normalized]
    set fname [file tail $normalized]

    # Classify by directory path first.
    if {[string match -nocase "*/ALUs/*" $normalized]} {
        return "ALU"
    }
    if {[string match -nocase "*/Basic_Logic/*" $normalized]} {
        return "Basic Logic"
    }
    if {[string match -nocase "*/combinational/*" $normalized] || \
        [string match -nocase "*/Combinational Logic Design/*" $normalized] || \
        [string match -nocase "*/Typical Combinational Components/*" $normalized]} {
        return "Combinational"
    }
    if {[string match -nocase "*/Communication_Protocols/CAN/*" $normalized]} {
        return "Communication - CAN"
    }
    if {[string match -nocase "*/Communication_Protocols/Ethernet/*" $normalized]} {
        return "Communication - Eth"
    }
    if {[string match -nocase "*/Communication_Protocols/I2C/*" $normalized]} {
        return "Communication - I2C"
    }
    if {[string match -nocase "*/Communication_Protocols/I2S/*" $normalized]} {
        return "Communication - I2S"
    }
    if {[string match -nocase "*/Communication_Protocols/SPI/*" $normalized]} {
        return "Communication - SPI"
    }
    if {[string match -nocase "*/Communication_Protocols/UART_Enhanced/*" $normalized] || \
        [string match -nocase "*/uart/*" $normalized]} {
        return "Communication - UART"
    }
    if {[string match -nocase "*/Cryptography/*" $normalized]} {
        return "Cryptography"
    }
    if {[string match -nocase "*/fir_filter/*" $normalized] || \
        [string match -nocase "*/FIR_Digital_Filter/*" $normalized]} {
        return "FIR Filter"
    }
    if {[string match -nocase "*/fsm/*" $normalized]} {
        return "FSM"
    }
    if {[string match -nocase "*/gcd_calculator/*" $normalized] || \
        [string match -nocase "*/GCD_Calculator/*" $normalized]} {
        return "GCD Calculator"
    }
    if {[string match -nocase "*/isa_controller/*" $normalized] || \
        [string match -nocase "*/ISA_Bus_Interface/*" $normalized]} {
        return "ISA Controller"
    }
    if {[string match -nocase "*Latch*" $normalized]} {
        return "Latch & Flip-Flop"
    }
    if {[string match -nocase "*/MCU Multi-Cores/*" $normalized]} {
        return "MCU Multi-Core"
    }
    if {[string match -nocase "*/MCU_Architectures/*" $normalized]} {
        return "MCU Architecture"
    }
    if {[string match -nocase "*/memory/*" $normalized]} {
        return "Memory"
    }
    if {[string match -nocase "*/microprocessor/*" $normalized]} {
        return "Microprocessor"
    }
    if {[string match -nocase "*/pci_bridge/*" $normalized] || \
        [string match -nocase "*/PCI_Bridge/*" $normalized]} {
        return "PCI Bridge"
    }
    if {[string match -nocase "*/peripherals/*" $normalized]} {
        return "Peripheral"
    }
    if {[string match -nocase "*/Processor_FPGA_Interfaces/*" $normalized]} {
        return "Processor FPGA IF"
    }
    if {[string match -nocase "*/sequential/*" $normalized]} {
        return "Sequential"
    }
    if {[string match -nocase "*/serial_adder/*" $normalized] || \
        [string match -nocase "*/Serial_Adder/*" $normalized]} {
        return "Serial Adder"
    }
    if {[string match -nocase "*/Signal_Processing/*" $normalized]} {
        return "Signal Processing"
    }
    if {[string match -nocase "*/signal_variable/*" $normalized]} {
        return "Signal/Variable"
    }
    if {[string match -nocase "*/top_level/*" $normalized]} {
        return "Top Level"
    }
    if {[string match -nocase "*/Hardware_Alter_Board_Basics/*" $normalized]} {
        return "Peripheral"
    }

    # Fallback: classify by filename pattern.
    if {[regexp -nocase {alu} $fname]} { return "ALU" }
    if {[regexp -nocase {uart} $fname]} { return "Communication - UART" }
    if {[regexp -nocase {spi} $fname]} { return "Communication - SPI" }
    if {[regexp -nocase {i2c} $fname]} { return "Communication - I2C" }
    if {[regexp -nocase {can} $fname]} { return "Communication - CAN" }
    if {[regexp -nocase {ethernet} $fname]} { return "Communication - Eth" }
    if {[regexp -nocase {memory|ram|rom|fifo} $fname]} { return "Memory" }
    if {[regexp -nocase {fsm|traffic|vending} $fname]} { return "FSM" }

    return "Unknown"
}

# -----------------------------------------------------------------------------
# Count entities in a VHDL file
# -----------------------------------------------------------------------------
proc count_entities {filepath} {
    set count 0
    set fh [open $filepath r]
    set content [read $fh]
    close $fh

    # Count "entity <name> is" patterns (case-insensitive).
    set matches [regexp -all -nocase -inline {\mentity\s+\w+\s+is\M} $content]
    set count [llength $matches]

    return $count
}

# -----------------------------------------------------------------------------
# Find all VHDL files (excluding testbenches)
# -----------------------------------------------------------------------------
proc find_vhd_files {dir} {
    global all_files
    foreach item [glob -nocomplain -directory $dir *] {
        if {[file isdirectory $item]} {
            find_vhd_files $item
        } elseif {[file extension $item] eq ".vhd"} {
            set fname [file tail $item]
            # Exclude testbench files.
            if {![regexp -nocase {(^tb_|_testbench\.vhd$|_tb\.vhd$)} $fname]} {
                lappend all_files $item
            }
        }
    }
}

# -----------------------------------------------------------------------------
# Main estimation logic
# -----------------------------------------------------------------------------
log_separator
log_msg "Cyclone III FPGA - Resource Estimation Report"
log_msg "Device         : EP3C16F484C6N (Cyclone III)"
log_msg "Total LEs      : 15,408"
log_msg "Total M9K      : 56 (504 Kb total)"
log_msg "Total DSP 9x9  : 56"
log_msg "Total PLLs     : 4"
log_msg "Date           : [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]"
log_separator

# Find all VHDL source files.
set all_files {}
find_vhd_files $src_dir
set all_files [lsort $all_files]

log_msg ""
log_msg ">>> Step 1: Counting total entities in the project..."
log_separator "-"

set total_entities 0
set file_entity_map {}

foreach f $all_files {
    set n [count_entities $f]
    incr total_entities $n
    lappend file_entity_map [list $f $n]
}

log_msg "  Total VHDL source files : [llength $all_files]"
log_msg "  Total entities found    : $total_entities"

log_msg ""
log_msg ">>> Step 2: Estimating LE usage per module type..."
log_separator "-"

# Accumulate counts per module type.
array set type_file_count {}
array set type_entity_count {}
array set type_le_total {}
array set type_m9k_total {}
array set type_dsp_total {}
array set type_pll_total {}

foreach entry $file_entity_map {
    set fpath [lindex $entry 0]
    set ents  [lindex $entry 1]
    set mtype [classify_module $fpath]

    if {![info exists type_file_count($mtype)]} {
        set type_file_count($mtype) 0
        set type_entity_count($mtype) 0
        set type_le_total($mtype) 0
        set type_m9k_total($mtype) 0
        set type_dsp_total($mtype) 0
        set type_pll_total($mtype) 0
    }

    incr type_file_count($mtype)
    incr type_entity_count($mtype) $ents
    incr type_le_total($mtype) $le_estimates($mtype)
    incr type_m9k_total($mtype) $m9k_estimates($mtype)
    incr type_dsp_total($mtype) $dsp_estimates($mtype)
    incr type_pll_total($mtype) $pll_estimates($mtype)
}

# -----------------------------------------------------------------------------
# Step 3: Generate summary table
# -----------------------------------------------------------------------------
log_msg ""
log_msg ">>> Step 3: Resource Estimate Summary Table"
log_separator "-"

# Print table header.
set hdr_format "%-28s %6s %8s %10s %8s %8s %6s"
log_msg [format $hdr_format "Module Type" "Files" "Entities" "Est. LEs" "M9K" "DSP" "PLL"]
log_msg [format $hdr_format "---------------------------" "------" "--------" "----------" "--------" "--------" "------"]

# Sort module types alphabetically.
set sorted_types [lsort [array names type_file_count]]

set grand_le 0
set grand_m9k 0
set grand_dsp 0
set grand_pll 0
set grand_files 0
set grand_entities 0

foreach mtype $sorted_types {
    log_msg [format $hdr_format \
        $mtype \
        $type_file_count($mtype) \
        $type_entity_count($mtype) \
        $type_le_total($mtype) \
        $type_m9k_total($mtype) \
        $type_dsp_total($mtype) \
        $type_pll_total($mtype)]

    incr grand_le        $type_le_total($mtype)
    incr grand_m9k       $type_m9k_total($mtype)
    incr grand_dsp       $type_dsp_total($mtype)
    incr grand_pll       $type_pll_total($mtype)
    incr grand_files     $type_file_count($mtype)
    incr grand_entities  $type_entity_count($mtype)
}

log_msg [format $hdr_format "---------------------------" "------" "--------" "----------" "--------" "--------" "------"]
log_msg [format $hdr_format "TOTAL" $grand_files $grand_entities $grand_le $grand_m9k $grand_dsp $grand_pll]

# -----------------------------------------------------------------------------
# Step 4: Device utilization summary
# -----------------------------------------------------------------------------
log_msg ""
log_msg ">>> Step 4: Device Utilization Summary (EP3C16F484C6N)"
log_separator "-"

set total_le  15408
set total_m9k 56
set total_dsp 56
set total_pll 4

set le_pct  [expr {double($grand_le)  / $total_le  * 100}]
set m9k_pct [expr {double($grand_m9k) / $total_m9k * 100}]
set dsp_pct [expr {double($grand_dsp) / $total_dsp * 100}]
set pll_pct [expr {double($grand_pll) / $total_pll * 100}]

set util_format "  %-25s : %8d / %-8d  (%5.1f%%)"
log_msg [format $util_format "Logic Elements (LEs)"   $grand_le  $total_le  $le_pct]
log_msg [format $util_format "M9K Memory Blocks"      $grand_m9k $total_m9k $m9k_pct]
log_msg [format $util_format "DSP 9x9 Multipliers"    $grand_dsp $total_dsp $dsp_pct]
log_msg [format $util_format "PLLs"                   $grand_pll $total_pll $pll_pct]

# Warning if estimates exceed device capacity.
log_msg ""
if {$le_pct > 100} {
    log_msg "  WARNING: Estimated LE usage exceeds device capacity!"
}
if {$m9k_pct > 100} {
    log_msg "  WARNING: Estimated M9K usage exceeds device capacity!"
}
if {$dsp_pct > 100} {
    log_msg "  WARNING: Estimated DSP usage exceeds device capacity!"
}
if {$pll_pct > 100} {
    log_msg "  WARNING: Estimated PLL usage exceeds device capacity!"
}

# -----------------------------------------------------------------------------
# Step 5: Per-file detail listing
# -----------------------------------------------------------------------------
log_msg ""
log_msg ">>> Step 5: Per-File Entity Count Detail"
log_separator "-"

set detail_format "  %-55s %5s %s"
log_msg [format $detail_format "File" "Ents" "Module Type"]
log_msg [format $detail_format "-------------------------------------------------------" "-----" "---------------------------"]

foreach entry $file_entity_map {
    set fpath [lindex $entry 0]
    set ents  [lindex $entry 1]
    set mtype [classify_module $fpath]
    set short_path [file normalize $fpath]
    # Trim the project root prefix for readability.
    set short_path [regsub "^$project_root/" $short_path ""]
    log_msg [format $detail_format $short_path $ents $mtype]
}

# -----------------------------------------------------------------------------
# Footer
# -----------------------------------------------------------------------------
log_msg ""
log_separator
log_msg "Resource estimation complete."
log_msg "Report saved to: $report_path"
log_msg ""
log_msg "NOTE: These are heuristic estimates based on module type classification."
log_msg "      Actual resource usage may vary. Run Quartus synthesis for exact"
log_msg "      numbers: quartus_sh -t scripts/synthesis_check.tcl"
log_separator

# Close the report file.
close $fh

puts ""
puts "Resource estimate written to: [file normalize $report_path]"
