#===============================================================================
# common/tcl/create_project.tcl
#
# Recreate (or open) the thesis Vivado projects from VHDL sources.
#
# Args (name=value via -tclargs):
#   target=lu|svd|all     which project(s)   (default: all)
#   force=0|1             wipe & recreate    (default: 0 → just open .xpr)
#   gui=0|1               leave project open (batch scripts ignore)
#
# Examples:
#   vivado -mode batch -source common/tcl/create_project.tcl -tclargs target=svd force=1
#   ./scripts/vivado_setup.sh svd --force
#===============================================================================

set _here [file dirname [file normalize [info script]]]
source [file join $_here board.tcl]

proc ::fpga::_parse {argv} {
    array set opt {target all force 0}
    foreach a $argv {
        if {[regexp {^([^=]+)=(.*)$} $a -> k v]} { set opt($k) $v }
    }
    return [array get opt]
}

if {![info exists ::fpga::CREATE_ARGV]} {
    set ::fpga::CREATE_ARGV $argv
}
array set CFG [::fpga::_parse $::fpga::CREATE_ARGV]
set CFG(target) [string tolower $CFG(target)]

set repo [::fpga::init_paths]
puts "================================================================"
puts " FPGA thesis Vivado setup"
puts "   repo   : $repo"
puts "   target : $CFG(target)"
puts "   force  : $CFG(force)"
puts "================================================================"

proc ::fpga::add_vhdl_dir {dir fileset {ftype VHDL}} {
    if {![file isdirectory $dir]} { error "missing dir: $dir" }
    set files [lsort [glob -nocomplain -directory $dir *.vhd *.vhdl]]
    foreach f $files {
        set f [file normalize $f]
        if {[llength [get_files -quiet $f]] == 0} {
            add_files -norecurse -fileset $fileset $f
            puts "  + $fileset : [file tail $f]"
        }
        set_property FILE_TYPE $ftype [get_files $f]
    }
    return $files
}

proc ::fpga::add_mem_dir {dir fileset} {
    if {![file isdirectory $dir]} { return }
    foreach f [lsort [glob -nocomplain -directory $dir *.mem]] {
        set f [file normalize $f]
        if {[llength [get_files -quiet $f]] == 0} {
            add_files -norecurse -fileset $fileset $f
            puts "  + $fileset : [file tail $f]"
        }
    }
}

proc ::fpga::create_or_open {name proj_rel src_rel sim_rel synth_top sim_top} {
    variable REPO_ROOT
    upvar 1 CFG CFG

    set proj_dir [file normalize [file join $REPO_ROOT $proj_rel]]
    set xpr      [file join $proj_dir ${name}.xpr]
    set src_dir  [file normalize [file join $REPO_ROOT $src_rel]]
    set sim_dir  [file normalize [file join $REPO_ROOT $sim_rel]]

    if {[file exists $xpr] && $CFG(force) ne "1"} {
        puts "== Opening existing $xpr"
        open_project $xpr
        return $xpr
    }

    # create_project -force wipes ${name}.srcs in-place — park it first.
    set srcs_tree [file join $proj_dir ${name}.srcs]
    set srcs_park ""
    if {[file isdirectory $srcs_tree]} {
        set srcs_park [file normalize [file join $REPO_ROOT .vivado_srcs_park_${name}]]
        file delete -force $srcs_park
        puts "== Parking $srcs_tree → $srcs_park"
        file rename $srcs_tree $srcs_park
        set src_dir [file normalize [file join $srcs_park sources_1 new]]
        set sim_dir [file normalize [file join $srcs_park sim_1 new]]
    }

    if {$CFG(force) eq "1" && [file exists $proj_dir]} {
        # Keep sources tree (parked above); wipe regenerable Vivado dirs + xpr
        puts "== force=1 → recreating project shell in $proj_dir"
        foreach pat {*.xpr *.cache *.hw *.ip_user_files *.runs *.sim *.gen .Xil} {
            foreach p [glob -nocomplain -directory $proj_dir $pat] {
                file delete -force $p
            }
        }
    }

    file mkdir $proj_dir
    puts "== Creating $name ($::fpga::PART)"
    create_project $name $proj_dir -part $::fpga::PART -force
    ::fpga::apply_board [current_project]
    set_property target_language VHDL [current_project]
    set_property simulator_language Mixed [current_project]

    # Restore parked sources over Vivado's empty .srcs shell
    if {$srcs_park ne "" && [file isdirectory $srcs_park]} {
        close_project
        file delete -force $srcs_tree
        file rename $srcs_park $srcs_tree
        set src_dir [file normalize [file join $srcs_tree sources_1 new]]
        set sim_dir [file normalize [file join $srcs_tree sim_1 new]]
        open_project $xpr
        puts "== Restored $srcs_tree"
    }

    ::fpga::add_vhdl_dir $src_dir sources_1 VHDL
    # TB often needs VHDL-2008
    ::fpga::add_vhdl_dir $sim_dir sim_1 {VHDL 2008}
    ::fpga::add_mem_dir  $sim_dir sim_1

    if {$synth_top ne ""} {
        set_property TOP $synth_top [get_filesets sources_1]
        update_compile_order -fileset sources_1
        puts "  TOP (synth) = $synth_top"
    }
    if {$sim_top ne ""} {
        set_property TOP $sim_top [get_filesets sim_1]
        update_compile_order -fileset sim_1
        puts "  TOP (sim)   = $sim_top"
    }

    puts "== Created $xpr"
    return $xpr
}

set opened {}

if {$CFG(target) eq "lu" || $CFG(target) eq "all"} {
    # Close prior project if switching targets in one run
    catch { close_project -quiet }
    lappend opened [::fpga::create_or_open \
        kung_lu_decom \
        kung_lu_decom \
        kung_lu_decom/kung_lu_decom.srcs/sources_1/new \
        kung_lu_decom/kung_lu_decom.srcs/sim_1/new \
        lu_array4x4 \
        lu]
}

if {$CFG(target) eq "svd" || $CFG(target) eq "all"} {
    catch { close_project -quiet }
    lappend opened [::fpga::create_or_open \
        kung_svd \
        kung_svd \
        kung_svd/kung_svd.srcs/sources_1/new \
        kung_svd/kung_svd.srcs/sim_1/new \
        svd_array_top \
        tb_svd_array]
}

puts "================================================================"
puts " Done. Project(s):"
foreach p $opened { puts "   $p" }
puts " Open GUI:  vivado <path-to.xpr>"
puts " Batch sim (SVD):  cd kung_svd && vivado -mode batch -source test_sim.tcl"
puts "================================================================"
