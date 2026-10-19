set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports clk100]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports btnC]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN W17 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {led[7]}]
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports {led[8]}]
set_property -dict {PACKAGE_PIN V3 IOSTANDARD LVCMOS33} [get_ports {led[9]}]
set_property -dict {PACKAGE_PIN W3 IOSTANDARD LVCMOS33} [get_ports {led[10]}]
set_property -dict {PACKAGE_PIN U3 IOSTANDARD LVCMOS33} [get_ports {led[11]}]
set_property -dict {PACKAGE_PIN P3 IOSTANDARD LVCMOS33} [get_ports {led[12]}]
set_property -dict {PACKAGE_PIN N3 IOSTANDARD LVCMOS33} [get_ports {led[13]}]
set_property -dict {PACKAGE_PIN P1 IOSTANDARD LVCMOS33} [get_ports {led[14]}]
set_property -dict {PACKAGE_PIN L1 IOSTANDARD LVCMOS33} [get_ports {led[15]}]
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS33} [get_ports {seg[0]}]
set_property -dict {PACKAGE_PIN W6 IOSTANDARD LVCMOS33} [get_ports {seg[1]}]
set_property -dict {PACKAGE_PIN U8 IOSTANDARD LVCMOS33} [get_ports {seg[2]}]
set_property -dict {PACKAGE_PIN V8 IOSTANDARD LVCMOS33} [get_ports {seg[3]}]
set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS33} [get_ports {seg[4]}]
set_property -dict {PACKAGE_PIN V5 IOSTANDARD LVCMOS33} [get_ports {seg[5]}]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports {seg[6]}]
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS33} [get_ports dp]
set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS33} [get_ports {an[0]}]
set_property -dict {PACKAGE_PIN U4 IOSTANDARD LVCMOS33} [get_ports {an[1]}]
set_property -dict {PACKAGE_PIN V4 IOSTANDARD LVCMOS33} [get_ports {an[2]}]
set_property -dict {PACKAGE_PIN W4 IOSTANDARD LVCMOS33} [get_ports {an[3]}]
## Digilent Basys 3 (Artix-7 XC7A35T-1CPG236C), 100 MHz oscillator
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk100]
## The FPGA demo clock is divided by 100 in basys3_top (1 MHz).
## The divider toggles every 50 input cycles, so its output has a 100-cycle period.
## The Basys-3 variants instantiate basys3_top as "impl"; constrain the BUFG output
## that clocks the processor rather than the divider register's data output.
create_generated_clock -name core_clk -source [get_ports clk100] -divide_by 100 [get_pins {impl/core_clock_buf/O}]

## Center push button: active-high reset

## SW[3:1] selects metric; SW0 selects low/high 16-bit display half.

## User LEDs

## Seven-segment cathodes: abcdefg, plus decimal point

## Four anodes are active-low

set_load 5.000 [all_outputs]
set_property LOAD 5 [get_ports {an[0]}]
set_property LOAD 5 [get_ports {an[1]}]
set_property LOAD 5 [get_ports {an[2]}]
set_property LOAD 5 [get_ports {an[3]}]
set_property LOAD 5 [get_ports dp]
set_property LOAD 5 [get_ports {led[0]}]
set_property LOAD 5 [get_ports {led[10]}]
set_property LOAD 5 [get_ports {led[11]}]
set_property LOAD 5 [get_ports {led[12]}]
set_property LOAD 5 [get_ports {led[13]}]
set_property LOAD 5 [get_ports {led[14]}]
set_property LOAD 5 [get_ports {led[15]}]
set_property LOAD 5 [get_ports {led[1]}]
set_property LOAD 5 [get_ports {led[2]}]
set_property LOAD 5 [get_ports {led[3]}]
set_property LOAD 5 [get_ports {led[4]}]
set_property LOAD 5 [get_ports {led[5]}]
set_property LOAD 5 [get_ports {led[6]}]
set_property LOAD 5 [get_ports {led[7]}]
set_property LOAD 5 [get_ports {led[8]}]
set_property LOAD 5 [get_ports {led[9]}]
set_property LOAD 5 [get_ports {seg[0]}]
set_property LOAD 5 [get_ports {seg[1]}]
set_property LOAD 5 [get_ports {seg[2]}]
set_property LOAD 5 [get_ports {seg[3]}]
set_property LOAD 5 [get_ports {seg[4]}]
set_property LOAD 5 [get_ports {seg[5]}]
set_property LOAD 5 [get_ports {seg[6]}]
