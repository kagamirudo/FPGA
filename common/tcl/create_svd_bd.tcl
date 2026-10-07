#===============================================================================
# common/tcl/create_svd_bd.tcl
#
# Build PS7 + AXI DMA + svd_array_axis32 system, implement, export XSA.
#
# Prerequisites: IP packaged at ip_repo/svd_array_axis32 (package_svd_ip.tcl)
#
# Args (name=value via -tclargs):
#   skip_impl=0|1     skip synth/impl/bitgen (default 0)
#   fclk_mhz=25       FCLK0 frequency in MHz (default 25; path ~32 ns)
#===============================================================================

set _here [file dirname [file normalize [info script]]]
source [file join $_here board.tcl]

proc ::fpga::_parse {argv} {
  array set opt {skip_impl 0 fclk_mhz 25}
  foreach a $argv {
    if {[regexp {^([^=]+)=(.*)$} $a -> k v]} { set opt($k) $v }
  }
  return [array get opt]
}

if {![info exists ::fpga::CREATE_ARGV]} {
  set ::fpga::CREATE_ARGV $argv
}
array set CFG [::fpga::_parse $::fpga::CREATE_ARGV]

set repo [::fpga::init_paths]
set proj_dir [file join $repo kung_svd]
set ip_repo  [file join $repo ip_repo]
set out_dir  [file join $repo build svd_system]
set xsa_path [file join $out_dir svd_system.xsa]
set xdc_path [file join $proj_dir constrs svd_system.xdc]

file mkdir $out_dir
file mkdir [file join $proj_dir constrs]

puts "================================================================"
puts " SVD system BD  (FCLK0=$CFG(fclk_mhz) MHz  skip_impl=$CFG(skip_impl))"
puts "================================================================"

if {![file isdirectory [file join $ip_repo svd_array_axis32]]} {
  error "Missing IP at $ip_repo/svd_array_axis32 — run package_svd_ip.tcl first"
}

set sys_proj_dir [file join $out_dir vivado_proj]
file delete -force $sys_proj_dir
create_project svd_system $sys_proj_dir -part $::fpga::PART -force
::fpga::apply_board [current_project]
set_property target_language VHDL [current_project]
set_property ip_repo_paths $ip_repo [current_project]
update_ip_catalog -rebuild

create_bd_design svd_system
current_bd_design svd_system

# ---- PS7 ----
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Make DDR / FIXED_IO external without board preset
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
  -config {make_external "FIXED_IO, DDR" apply_board_preset "0" Master "Disable" Slave "Disable"} \
  [get_bd_cells processing_system7_0]

set_property -dict [list \
  CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $CFG(fclk_mhz) \
  CONFIG.PCW_EN_CLK0_PORT {1} \
  CONFIG.PCW_EN_RST0_PORT {1} \
  CONFIG.PCW_USE_M_AXI_GP0 {1} \
  CONFIG.PCW_M_AXI_GP0_ENABLE_STATIC_REMAP {0} \
  CONFIG.PCW_USE_S_AXI_HP0 {1} \
  CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
  CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1} \
  CONFIG.PCW_UART0_UART0_IO {MIO 14 .. 15} \
  CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
  CONFIG.PCW_IRQ_F2P_INTR {1} \
] [get_bd_cells processing_system7_0]

# ---- Reset ----
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
               [get_bd_pins rst_ps7_0/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
               [get_bd_pins rst_ps7_0/ext_reset_in]

# ---- AXI DMA (simple mode) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
set_property -dict [list \
  CONFIG.c_include_sg {0} \
  CONFIG.c_sg_length_width {23} \
  CONFIG.c_sg_include_stscntrl_strm {0} \
  CONFIG.c_include_mm2s {1} \
  CONFIG.c_include_s2mm {1} \
  CONFIG.c_include_mm2s_dre {0} \
  CONFIG.c_include_s2mm_dre {0} \
  CONFIG.c_m_axi_mm2s_data_width {32} \
  CONFIG.c_m_axi_s2mm_data_width {32} \
  CONFIG.c_m_axis_mm2s_tdata_width {32} \
  CONFIG.c_s_axis_s2mm_tdata_width {32} \
  CONFIG.c_mm2s_burst_size {16} \
  CONFIG.c_s2mm_burst_size {16} \
] [get_bd_cells axi_dma_0]

# ---- SVD IP ----
create_bd_cell -type ip -vlnv drexel.edu:user:svd_array_axis32:1.0 svd_0

# ---- IRQ concat ----
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property CONFIG.NUM_PORTS {2} [get_bd_cells xlconcat_0]

# ---- GP0 → DMA Lite (1x1 interconnect) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps7_0_axi_periph
set_property -dict [list CONFIG.NUM_MI {1} CONFIG.NUM_SI {1}] [get_bd_cells ps7_0_axi_periph]

# ---- DMA MM2S/S2MM → HP0 (2x1 interconnect) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_mem_intercon
set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1}] [get_bd_cells axi_mem_intercon]

# Clocks
set fclk [get_bd_pins processing_system7_0/FCLK_CLK0]
set arst [get_bd_pins rst_ps7_0/peripheral_aresetn]
set irst [get_bd_pins rst_ps7_0/interconnect_aresetn]

foreach pin [list \
  processing_system7_0/M_AXI_GP0_ACLK \
  processing_system7_0/S_AXI_HP0_ACLK \
  axi_dma_0/s_axi_lite_aclk \
  axi_dma_0/m_axi_mm2s_aclk \
  axi_dma_0/m_axi_s2mm_aclk \
  svd_0/aclk \
  ps7_0_axi_periph/ACLK \
  ps7_0_axi_periph/S00_ACLK \
  ps7_0_axi_periph/M00_ACLK \
  axi_mem_intercon/ACLK \
  axi_mem_intercon/S00_ACLK \
  axi_mem_intercon/S01_ACLK \
  axi_mem_intercon/M00_ACLK \
] {
  connect_bd_net $fclk [get_bd_pins $pin]
}

# Resets
foreach pin [list \
  axi_dma_0/axi_resetn \
  svd_0/aresetn \
  ps7_0_axi_periph/S00_ARESETN \
  ps7_0_axi_periph/M00_ARESETN \
  axi_mem_intercon/S00_ARESETN \
  axi_mem_intercon/S01_ARESETN \
  axi_mem_intercon/M00_ARESETN \
] {
  connect_bd_net $arst [get_bd_pins $pin]
}
connect_bd_net $irst [get_bd_pins ps7_0_axi_periph/ARESETN]
connect_bd_net $irst [get_bd_pins axi_mem_intercon/ARESETN]

# AXI Lite: GP0 → DMA
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] \
                    [get_bd_intf_pins ps7_0_axi_periph/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M00_AXI] \
                    [get_bd_intf_pins axi_dma_0/S_AXI_LITE]

# AXI memory: DMA → HP0
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] \
                    [get_bd_intf_pins axi_mem_intercon/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] \
                    [get_bd_intf_pins axi_mem_intercon/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_intercon/M00_AXI] \
                    [get_bd_intf_pins processing_system7_0/S_AXI_HP0]

# Streams: MM2S → SVD → S2MM
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins svd_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins svd_0/m_axis]         [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

# IRQs
connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins processing_system7_0/IRQ_F2P]

# Address map
assign_bd_address

regenerate_bd_layout
validate_bd_design
save_bd_design

# Wrapper
make_wrapper -files [get_files [get_property FILE_NAME [get_bd_designs svd_system]]] -top
set wrap_files [get_files -quiet *svd_system_wrapper*]
if {[llength $wrap_files] == 0} {
  set wrap_files [glob -nocomplain \
    $sys_proj_dir/*/sources_1/bd/svd_system/hdl/svd_system_wrapper.* \
    $sys_proj_dir/svd_system.gen/sources_1/bd/svd_system/hdl/svd_system_wrapper.*]
  add_files -norecurse $wrap_files
}
set_property top svd_system_wrapper [current_fileset]
update_compile_order -fileset sources_1

set xdc_fh [open $xdc_path w]
puts $xdc_fh "# svd_system — FCLK0 target ${CFG(fclk_mhz)} MHz (PS7 generates the clock)"
close $xdc_fh
add_files -fileset constrs_1 -norecurse $xdc_path

puts "== BD created and wrapper set as top"
puts "PROJECT=$sys_proj_dir/svd_system.xpr"

if {$CFG(skip_impl) eq "1"} {
  puts "== skip_impl=1 — done without bitgen"
} else {
  launch_runs synth_1 -jobs 8
  wait_on_run synth_1
  if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed"
  }
  puts "SYNTH_OK"

  launch_runs impl_1 -to_step write_bitstream -jobs 8
  wait_on_run impl_1
  if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation / bitstream failed"
  }
  puts "IMPL_OK"

  write_hw_platform -fixed -include_bit -force -file $xsa_path
  puts "XSA_OK $xsa_path"
}

puts "================================================================"
puts " Done."
puts "================================================================"
