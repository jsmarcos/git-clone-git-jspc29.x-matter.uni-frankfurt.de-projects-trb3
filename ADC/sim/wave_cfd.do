onerror {resume}
quietly virtual signal -install /tb { /tb/adc_data(9 downto 0)} adc_data_0
quietly virtual signal -install /tb { /tb/adc_data(19 downto 10)} adc_data_1
quietly virtual signal -install /tb { /tb/adc_data(29 downto 20)} adc_data_2
quietly virtual signal -install /tb { /tb/adc_data(39 downto 30)} adc_data_3
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Analog-Step -height 84 -max 1023.0 -radix hexadecimal -childformat {{/tb/adc_data_0(9) -radix hexadecimal} {/tb/adc_data_0(8) -radix hexadecimal} {/tb/adc_data_0(7) -radix hexadecimal} {/tb/adc_data_0(6) -radix hexadecimal} {/tb/adc_data_0(5) -radix hexadecimal} {/tb/adc_data_0(4) -radix hexadecimal} {/tb/adc_data_0(3) -radix hexadecimal} {/tb/adc_data_0(2) -radix hexadecimal} {/tb/adc_data_0(1) -radix hexadecimal} {/tb/adc_data_0(0) -radix hexadecimal}} -subitemconfig {/tb/adc_data(9) {-radix hexadecimal} /tb/adc_data(8) {-radix hexadecimal} /tb/adc_data(7) {-radix hexadecimal} /tb/adc_data(6) {-radix hexadecimal} /tb/adc_data(5) {-radix hexadecimal} /tb/adc_data(4) {-radix hexadecimal} /tb/adc_data(3) {-radix hexadecimal} /tb/adc_data(2) {-radix hexadecimal} /tb/adc_data(1) {-radix hexadecimal} /tb/adc_data(0) {-radix hexadecimal}} /tb/adc_data_0
add wave -noupdate -clampanalog 1 -format Analog-Step -height 80 -max 1024.0 -radix hexadecimal -childformat {{/tb/adc_data_1(19) -radix hexadecimal} {/tb/adc_data_1(18) -radix hexadecimal} {/tb/adc_data_1(17) -radix hexadecimal} {/tb/adc_data_1(16) -radix hexadecimal} {/tb/adc_data_1(15) -radix hexadecimal} {/tb/adc_data_1(14) -radix hexadecimal} {/tb/adc_data_1(13) -radix hexadecimal} {/tb/adc_data_1(12) -radix hexadecimal} {/tb/adc_data_1(11) -radix hexadecimal} {/tb/adc_data_1(10) -radix hexadecimal}} -subitemconfig {/tb/adc_data(19) {-radix hexadecimal} /tb/adc_data(18) {-radix hexadecimal} /tb/adc_data(17) {-radix hexadecimal} /tb/adc_data(16) {-radix hexadecimal} /tb/adc_data(15) {-radix hexadecimal} /tb/adc_data(14) {-radix hexadecimal} /tb/adc_data(13) {-radix hexadecimal} /tb/adc_data(12) {-radix hexadecimal} /tb/adc_data(11) {-radix hexadecimal} /tb/adc_data(10) {-radix hexadecimal}} /tb/adc_data_1
add wave -noupdate -clampanalog 1 -format Analog-Step -height 80 -max 1024.0 -radix hexadecimal /tb/adc_data_2
add wave -noupdate -clampanalog 1 -format Analog-Step -height 80 -max 1024.0 -radix hexadecimal /tb/adc_data_3
add wave -noupdate -divider {Buffer Input}
add wave -noupdate /tb/UUT/busy_in_adc
add wave -noupdate /tb/UUT/busy_in_sys
add wave -noupdate /tb/UUT/busy_out_adc
add wave -noupdate /tb/UUT/busy_out_sys
add wave -noupdate -divider Buffers
add wave -noupdate -divider Reader
add wave -noupdate -divider Baseline
add wave -noupdate -format Analog-Step -height 84 -max 511.0 -min -512.0 -radix hexadecimal /tb/UUT/gen_cfd(0)/THE_CFD/baseline
add wave -noupdate -divider Readout
add wave -noupdate /tb/UUT/READOUT_RX.data_valid
add wave -noupdate /tb/UUT/READOUT_RX.valid_timing_trg
add wave -noupdate -divider {data processor}
add wave -noupdate /tb/UUT/READOUT_TX.data_finished
add wave -noupdate /tb/UUT/READOUT_TX.data_write
add wave -noupdate -radix hexadecimal /tb/UUT/READOUT_TX.data
add wave -noupdate /tb/UUT/READOUT_TX.busy_release
add wave -noupdate -divider Config
add wave -noupdate /tb/UUT/CONFIG.BaselineAlwaysOn
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/CONFIG.DebugMode -radix hexadecimal} {/tb/UUT/CONFIG.InputThreshold -radix hexadecimal} {/tb/UUT/CONFIG.PolarityInvert -radix hexadecimal} {/tb/UUT/CONFIG.BaselineAverage -radix hexadecimal} {/tb/UUT/CONFIG.BaselineAlwaysOn -radix hexadecimal} {/tb/UUT/CONFIG.CFDDelay -radix hexadecimal} {/tb/UUT/CONFIG.CFDMult -radix hexadecimal} {/tb/UUT/CONFIG.CFDMultDly -radix hexadecimal} {/tb/UUT/CONFIG.IntegrateWindow -radix hexadecimal} {/tb/UUT/CONFIG.TriggerDelay -radix hexadecimal} {/tb/UUT/CONFIG.CheckWord1 -radix hexadecimal} {/tb/UUT/CONFIG.CheckWord2 -radix hexadecimal} {/tb/UUT/CONFIG.CheckWordEnable -radix hexadecimal} {/tb/UUT/CONFIG.TriggerEnable -radix hexadecimal} {/tb/UUT/CONFIG.ChannelDisable -radix hexadecimal} {/tb/UUT/CONFIG.DebugSamples -radix hexadecimal}} -subitemconfig {/tb/UUT/CONFIG.DebugMode {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.InputThreshold {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.PolarityInvert {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.BaselineAverage {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.BaselineAlwaysOn {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.CFDDelay {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.CFDMult {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.CFDMultDly {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.IntegrateWindow {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.TriggerDelay {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.CheckWord1 {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.CheckWord2 {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.CheckWordEnable {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.TriggerEnable {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.ChannelDisable {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.DebugSamples {-height 15 -radix hexadecimal}} /tb/UUT/CONFIG
add wave -noupdate /tb/UUT/TRIGGER_OUT
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {13950000000 fs} 0}
configure wave -namecolwidth 206
configure wave -valuecolwidth 195
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {13950049215 fs} {14083546647 fs}
