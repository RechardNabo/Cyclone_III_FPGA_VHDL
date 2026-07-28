# =============================================================================
# Cyclone III FPGA - Quartus Synthesis Check Script
# =============================================================================
# Target Device : EP3C16F484C6N (Cyclone III, DE0 Board)
# Top-Level     : soc_top
# Purpose       : Create project, add VHDL sources, run Analysis & Synthesis,
#                 report resource utilization and timing, save report.
# =============================================================================
# Usage (from Quartus command line or quartus_sh):
#   quartus_sh -t scripts/synthesis_check.tcl
#
# Or from within Quartus Tcl console:
#   source scripts/synthesis_check.tcl
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
set project_name    "soc_synthesis_check"
set device_family   "Cyclone III"
set device_part     "EP3C16F484C6N"
set top_level       "soc_top"
set src_dir         "src"
set report_dir      "reports"
set report_file     "synthesis_report.txt"
set report_path     [file join $report_dir $report_file]

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

log_separator
log_msg "Cyclone III FPGA - Synthesis Check Report"
log_msg "Device Family : $device_family"
log_msg "Device Part   : $device_part"
log_msg "Top-Level     : $top_level"
log_msg "Date          : [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]"
log_separator

# -----------------------------------------------------------------------------
# Step 1: Create or load the Quartus project
# -----------------------------------------------------------------------------
log_msg ""
log_msg ">>> Step 1: Creating Quartus project '$project_name'..."
log_separator "-"

# Close any existing project before creating a new one.
if {[project_exists $project_name]} {
    project_open -revision $project_name $project_name
} else {
    project_new -family $device_family -device $device_part $project_name
}

# Set the top-level entity.
set_global_assignment -name TOP_LEVEL_ENTITY $top_level
set_global_assignment -name FAMILY $device_family
set_global_assignment -name DEVICE $device_part
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY "output_files"
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 1

# -----------------------------------------------------------------------------
# Step 2: Add all VHDL source files (excluding testbenches)
# -----------------------------------------------------------------------------
log_msg ""
log_msg ">>> Step 2: Adding VHDL source files..."
log_separator "-"

set vhdl_files {}
set tb_count 0
set src_count 0

# Recursively find all .vhd files under src/, excluding testbenches.
proc find_vhd_files {dir} {
    global vhdl_files src_count tb_count
    foreach item [glob -nocomplain -directory $dir *] {
        if {[file isdirectory $item]} {
            find_vhd_files $item
        } elseif {[file extension $item] eq ".vhd"} {
            set fname [file tail $item]
            # Exclude testbench files (tb_*.vhd, *_testbench.vhd, *_tb.vhd).
            if {[regexp -nocase {(^tb_|_testbench\.vhd$|_tb\.vhd$)} $fname]} {
                incr tb_count
            } else {
                lappend vhdl_files $item
                incr src_count
            }
        }
    }
}

find_vhd_files $src_dir

# Sort files alphabetically for deterministic ordering.
set vhdl_files [lsort $vhdl_files]

# Add each VHDL file to the project.
foreach f $vhdl_files {
    set_global_assignment -name VHDL_FILE $f
    log_msg "  Added: [file normalize $f]"
}

log_msg ""
log_msg "  Total source files added : $src_count"
log_msg "  Testbench files excluded : $tb_count"

# -----------------------------------------------------------------------------
# Step 3: Add constraint files
# -----------------------------------------------------------------------------
log_msg ""
log_msg ">>> Step 3: Adding constraint files..."
log_separator "-"

set sdc_file [file join $project_root "constraints" "cyclone_iii_timing.sdc"]
set qsf_pins [file join $project_root "constraints" "cyclone_iii_pins.qsf"]

if {[file exists $sdc_file]} {
    set_global_assignment -name SDC_FILE $sdc_file
    log_msg "  Added SDC: $sdc_file"
} else {
    log_msg "  WARNING: SDC file not found at $sdc_file"
}

if {[file exists $qsf_pins]} {
    # Source the pin assignments QSF to include pin locations.
    source $qsf_pins
    log_msg "  Sourced pin assignments: $qsf_pins"
} else {
    log_msg "  WARNING: Pin assignment file not found at $qsf_pins"
}

# -----------------------------------------------------------------------------
# Step 4: Run Analysis & Synthesis
# -----------------------------------------------------------------------------
log_msg ""
log_msg ">>> Step 4: Running Analysis & Synthesis..."
log_separator "-"

# Execute the Quartus map (analysis & synthesis) flow.
if {[catch {execute_module -tool map -args "--analyze_file=false"} result]} {
    log_msg "  ERROR: Analysis & Synthesis failed."
    log_msg "  Error: $result"
} else {
    log_msg "  Analysis & Synthesis completed successfully."
}

# -----------------------------------------------------------------------------
# Step 5: Report Resource Utilization
# -----------------------------------------------------------------------------
log_msg ""
log_msg ">>> Step 5: Resource Utilization Report"
log_separator "-"

# Load the Quartus report database to extract resource counts.
if {[catch {load_report} result]} {
    log_msg "  WARNING: Could not load report database: $result"
} else {
    # Logic Elements (LEs)
    set le_used 0
    set le_total 0
    foreach panel [get_report_panels] {
        if {[string match -nocase "*Flow Summary*" $panel]} {
            set rows [get_report_panel_rows $panel]
            foreach row $rows {
                set label [lindex $row 0]
                set value [lindex $row 1]
                if {[string match -nocase "*logic utilization*" $label] || \
                    [string match -nocase "*Total logic elements*" $label]} {
                    log_msg "  $label : $value"
                }
                if {[string match -nocase "*Total pins*" $label]} {
                    log_msg "  $label : $value"
                }
                if {[string match -nocase "*Total memory bits*" $label]} {
                    log_msg "  $label : $value"
                }
                if {[string match -nocase "*Total PLLs*" $label]} {
                    log_msg "  $label : $value"
                }
                if {[string match -nocase "*Total DSP blocks*" $label]} {
                    log_msg "  $label : $value"
                }
            }
        }
    }

    # Try to read specific resource panels.
    # Analysis & Synthesis -> Resource Usage Summary
    set panel_names {
        "Flow Summary"
        "Analysis & Synthesis\\Resource Usage Summary"
        "Analysis & Synthesis\\Resource Utilization by Entity"
    }

    foreach pname $panel_names {
        set panel_id [get_report_panel_id $pname]
        if {$panel_id >= 0} {
            log_msg ""
            log_msg "  --- Panel: $pname ---"
            set rows [get_report_panel_rows $panel_id]
            set header [get_report_panel_headers $panel_id]
            log_msg "  [join $header " | "]"
            foreach row $rows {
                log_msg "  [join $row " | "]"
            }
        }
    }

    unload_report
}

# -----------------------------------------------------------------------------
# Step 6: Report Timing Summary
# -----------------------------------------------------------------------------
log_msg ""
log_msg ">>> Step 6: Timing Summary"
log_separator "-"

# After synthesis, run a quick timing analysis if possible.
# Note: Full STA requires the fitter to complete. Here we report what is
# available from the synthesis stage.
if {[catch {load_report} result]} {
    log_msg "  Timing information not available at synthesis stage."
    log_msg "  Run the full Quartus flow (quartus_fit + quartus_sta) for STA."
} else {
    set timing_panels {
        "TimeQuest Timing Analyzer\\Summary"
        "TimeQuest Timing Analyzer\\Clock Setup Summary"
        "TimeQuest Timing Analyzer\\Clock Hold Summary"
    }

    foreach pname $timing_panels {
        set panel_id [get_report_panel_id $pname]
        if {$panel_id >= 0} {
            log_msg ""
            log_msg "  --- Panel: $pname ---"
            set header [get_report_panel_headers $panel_id]
            log_msg "  [join $header " | "]"
            set rows [get_report_panel_rows $panel_id]
            foreach row $rows {
                log_msg "  [join $row " | "]"
            }
        }
    }

    unload_report
}

# If the STA report file exists from a prior full compilation, include it.
set sta_rpt [file join $project_root "output_files" "${project_name}.sta.summary"]
if {![file exists $sta_rpt]} {
    set sta_rpt [file join $project_root "output_files" "EP3C16F484C6N_Cyclone_3.sta.summary"]
}
if {[file exists $sta_rpt]} {
    log_msg ""
    log_msg "  --- STA Summary (from $sta_rpt) ---"
    set sta_fh [open $sta_rpt r]
    while {[gets $sta_fh line] >= 0} {
        log_msg "  $line"
    }
    close $sta_fh
}

# -----------------------------------------------------------------------------
# Step 7: Save and close project
# -----------------------------------------------------------------------------
log_msg ""
log_msg ">>> Step 7: Saving project..."
log_separator "-"

export_assignments
project_close

log_msg "  Project saved and closed."

# -----------------------------------------------------------------------------
# Final Summary
# -----------------------------------------------------------------------------
log_msg ""
log_separator
log_msg "Synthesis check complete."
log_msg "Report saved to: $report_path"
log_separator

# Close the report file.
close $fh

puts ""
puts "Synthesis report written to: [file normalize $report_path]"
