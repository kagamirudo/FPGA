#-------------------------------------------------------------------------------
# common/tcl/board.tcl — Cora Z7-07S defaults for this thesis repo
#-------------------------------------------------------------------------------
namespace eval ::fpga {
    variable PART       "xc7z007sclg400-1"
    variable BOARD_PART "digilentinc.com:cora-z7-07s:part0:1.1"
    variable REPO_ROOT  ""
}

proc ::fpga::find_repo_root {{start ""}} {
    if {$start eq ""} {
        set start [file normalize [file dirname [info script]]]
    }
    set d [file normalize $start]
    while {$d ne "/" && $d ne ""} {
        if {[file isdirectory [file join $d kung_svd]] &&
            [file isdirectory [file join $d kung_lu_decom]]} {
            return $d
        }
        set parent [file dirname $d]
        if {$parent eq $d} { break }
        set d $parent
    }
    error "Could not locate FPGA repo root from $start"
}

proc ::fpga::init_paths {{root ""}} {
    variable REPO_ROOT
    if {$root eq ""} { set root [::fpga::find_repo_root] }
    set REPO_ROOT [file normalize $root]
    return $REPO_ROOT
}

proc ::fpga::apply_board {proj} {
    variable PART
    variable BOARD_PART
    set_property part $PART $proj
    if {[catch {set_property board_part $BOARD_PART $proj} msg]} {
        puts "WARN: board_part not applied ($msg) — using part=$PART only"
    }
}
