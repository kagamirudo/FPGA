#===============================================================================
# common/tcl/package_svd_ip.tcl
#
# Package svd_array_axis32 (+ RTL deps) as a Vivado IP in ip_repo/.
#
# Usage:
#   vivado -mode batch -source common/tcl/package_svd_ip.tcl
#===============================================================================

set _here [file dirname [file normalize [info script]]]
source [file join $_here board.tcl]

set repo [::fpga::init_paths]
set src_dir [file join $repo kung_svd kung_svd.srcs sources_1 new]
set ip_root [file join $repo ip_repo]
set ip_dir  [file join $ip_root svd_array_axis32]
set tmp_proj [file join $repo build vivado_ip_pkg]

file mkdir $ip_root
file mkdir [file join $repo build]
file delete -force $tmp_proj
file delete -force $ip_dir

puts "== Packaging svd_array_axis32 → $ip_dir"

create_project ip_pkg $tmp_proj -part $::fpga::PART -force
set_property target_language VHDL [current_project]

# RTL required by svd_array_axis32 hierarchy (exclude unused legacy modules)
set vhdl_files {
  svd_pkg.vhd
  svd_angle_cordic.vhd
  svd_gram.vhd
  svd_pair_pipeline.vhd
  svd_blv_schedule_pkg.vhd
  svd_jacobi_blv.vhd
  svd_jacobi_top.vhd
  svd_array_core.vhd
  svd_axi_stream.vhd
  svd_array.vhd
  svd_array_axis32.vhd
}

foreach f $vhdl_files {
  set path [file join $src_dir $f]
  if {![file exists $path]} { error "missing source: $path" }
  add_files -norecurse $path
  set_property FILE_TYPE {VHDL} [get_files $path]
}

update_compile_order -fileset sources_1
set_property top svd_array_axis32 [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $ip_dir -vendor drexel.edu -library user \
  -taxonomy /UserIP -import_files -set_current true

set core [ipx::current_core]
set_property name svd_array_axis32 $core
set_property display_name {SVD Array AXIS32} $core
set_property description {One-sided Jacobi SVD systolic array (32-bit AXI4-Stream)} $core
set_property vendor_display_name {Drexel ECE} $core
set_property company_url {https://drexel.edu} $core
set_property version {1.0} $core
set_property core_revision 1 $core

# Infer AXI4-Stream + clock/reset from port names
ipx::infer_bus_interface aclk xilinx.com:signal:clock_rtl:1.0 $core
ipx::infer_bus_interface aresetn xilinx.com:signal:reset_rtl:1.0 $core
ipx::infer_bus_interfaces xilinx.com:interface:axis_rtl:1.0 $core

# Associate streams with clock
foreach bif {s_axis m_axis} {
  if {[llength [ipx::get_bus_interfaces $bif -of_objects $core]]} {
    ipx::associate_bus_interfaces -busif $bif -clock aclk $core
  }
}
ipx::associate_bus_interfaces -clock aclk -reset aresetn $core

# Reset polarity
set rst_bif [ipx::get_bus_interfaces aresetn -of_objects $core]
if {[llength $rst_bif]} {
  set_property value ACTIVE_LOW [ipx::get_bus_parameters POLARITY -of_objects $rst_bif]
}

# Memory map not required (stream-only IP)
set_property supported_families {zynq Production zynquplus Production} $core

ipx::update_checksums $core
ipx::save_core $core
close_project

# Drop temporary packaging project
file delete -force $tmp_proj

puts "== IP packaged: $ip_dir"
puts "   VLNV: drexel.edu:user:svd_array_axis32:1.0"
