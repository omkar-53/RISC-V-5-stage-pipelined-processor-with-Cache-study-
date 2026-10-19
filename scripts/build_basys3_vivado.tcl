# Build a clean Basys 3 project from rtl_independent and its compiled demo image.
# Run with: vivado -mode batch -source scripts/build_basys3_vivado.tcl
set repo [file dirname [file dirname [info script]]]
set source_dir [file join $repo rtl_independent]
set image_dir [file join $repo vivado RV32IM_Basys3]
set project_name RV32IM_Basys3_FPGA
if {[llength $argv] > 0} {
    set project_name [lindex $argv 0]
}
set project_dir [file join $repo vivado $project_name]

# This machine has a damaged per-user Tcl Store catalog. Register the valid
# installed support package explicitly so ordinary project commands can run.
set tcl_support [file join $::env(XILINX_VIVADO) data XilinxTclStore support]
set tcl_apps [file join $::env(XILINX_VIVADO) data XilinxTclStore tclapp]
if {[catch {package require ::tclapp::support::appinit 1.2}]} {
    set dir $tcl_support
    source [file join $tcl_support pkgIndex.tcl]
    package require ::tclapp::support::appinit 1.2
}
set dir $tcl_apps
source [file join $tcl_apps pkgIndex.tcl]
set dir [file join $tcl_apps xilinx xsim]
source [file join $dir pkgIndex.tcl]
package require ::tclapp::xilinx::xsim 2.527

create_project $project_name $project_dir -part xc7a35tcpg236-1 -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_files [list \
    alu_logic.sv branch_comp.sv control_unit.sv data_mem.sv fwd_logic.sv \
    imm_gen.sv inst_mem.sv l1_cache.sv program_counter.sv reg_file.sv top.sv \
    basys3_top.sv]
foreach rtl $rtl_files {
    add_files -norecurse [list [file join $source_dir $rtl]]
}
set imem_file [file join $image_dir instructions.mem]
set dmem_file [file join $image_dir data_mem.mem]
add_files -norecurse [list $imem_file]
add_files -norecurse [list $dmem_file]
set_property file_type {Memory Initialization Files} [get_files -all -quiet [list $imem_file]]
set_property file_type {Memory Initialization Files} [get_files -all -quiet [list $dmem_file]]
add_files -fileset constrs_1 -norecurse [list [file join $image_dir basys3.xdc]]
set_property top basys3_top [get_filesets sources_1]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "Synthesis did not complete successfully; inspect the Vivado run log."
}
open_run synth_1
report_utilization -file [file join $project_dir synthesis_utilization.rpt]
report_timing_summary -file [file join $project_dir synthesis_timing.rpt]
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![string match "*Complete!*" [get_property STATUS [get_runs impl_1]]]} {
    error "Implementation/bitstream did not complete; inspect the impl_1 run log."
}
open_run impl_1
report_utilization -file [file join $project_dir implementation_utilization.rpt]
report_timing_summary -file [file join $project_dir implementation_timing.rpt]
puts "BASYS3_PROJECT=$project_dir"
puts "SYNTHESIS_STATUS=[get_property STATUS [get_runs synth_1]]"
puts "IMPLEMENTATION_STATUS=[get_property STATUS [get_runs impl_1]]"
puts "UTILIZATION_REPORT=[file join $project_dir synthesis_utilization.rpt]"
puts "TIMING_REPORT=[file join $project_dir synthesis_timing.rpt]"
puts "BITSTREAM=[file join $project_dir ${project_name}.runs impl_1 basys3_top.bit]"
close_project
