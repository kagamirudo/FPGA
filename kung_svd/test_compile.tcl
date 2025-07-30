# Test compilation script
set_property target_language VHDL [current_project]

# Analyze all VHDL files
analyze -vhdl [get_files *.vhd]

# Check for any compilation errors
if {[get_msg_config -severity ERROR -count] > 0} {
    puts "ERROR: Compilation failed with errors:"
    get_msg_config -severity ERROR
} else {
    puts "SUCCESS: All files compiled successfully"
} 