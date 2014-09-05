onerror {resume}
quietly virtual signal -install /tb { /tb/adc_data(9 downto 0)} adc_data_0
quietly virtual signal -install /tb { /tb/adc_data(19 downto 10)} adc_data_1
quietly virtual signal -install /tb { /tb/adc_data(29 downto 20)} adc_data_2
quietly virtual signal -install /tb { /tb/adc_data(39 downto 30)} adc_data_3
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /tb/clock
add wave -noupdate -format Analog-Step -height 84 -max 1023.0 -radix hexadecimal -childformat {{/tb/adc_data_0(9) -radix hexadecimal} {/tb/adc_data_0(8) -radix hexadecimal} {/tb/adc_data_0(7) -radix hexadecimal} {/tb/adc_data_0(6) -radix hexadecimal} {/tb/adc_data_0(5) -radix hexadecimal} {/tb/adc_data_0(4) -radix hexadecimal} {/tb/adc_data_0(3) -radix hexadecimal} {/tb/adc_data_0(2) -radix hexadecimal} {/tb/adc_data_0(1) -radix hexadecimal} {/tb/adc_data_0(0) -radix hexadecimal}} -subitemconfig {/tb/adc_data(9) {-radix hexadecimal} /tb/adc_data(8) {-radix hexadecimal} /tb/adc_data(7) {-radix hexadecimal} /tb/adc_data(6) {-radix hexadecimal} /tb/adc_data(5) {-radix hexadecimal} /tb/adc_data(4) {-radix hexadecimal} /tb/adc_data(3) {-radix hexadecimal} /tb/adc_data(2) {-radix hexadecimal} /tb/adc_data(1) {-radix hexadecimal} /tb/adc_data(0) {-radix hexadecimal}} /tb/adc_data_0
add wave -noupdate -clampanalog 1 -format Analog-Step -height 80 -max 1024.0 -radix hexadecimal -childformat {{/tb/adc_data_1(19) -radix hexadecimal} {/tb/adc_data_1(18) -radix hexadecimal} {/tb/adc_data_1(17) -radix hexadecimal} {/tb/adc_data_1(16) -radix hexadecimal} {/tb/adc_data_1(15) -radix hexadecimal} {/tb/adc_data_1(14) -radix hexadecimal} {/tb/adc_data_1(13) -radix hexadecimal} {/tb/adc_data_1(12) -radix hexadecimal} {/tb/adc_data_1(11) -radix hexadecimal} {/tb/adc_data_1(10) -radix hexadecimal}} -subitemconfig {/tb/adc_data(19) {-radix hexadecimal} /tb/adc_data(18) {-radix hexadecimal} /tb/adc_data(17) {-radix hexadecimal} /tb/adc_data(16) {-radix hexadecimal} /tb/adc_data(15) {-radix hexadecimal} /tb/adc_data(14) {-radix hexadecimal} /tb/adc_data(13) {-radix hexadecimal} /tb/adc_data(12) {-radix hexadecimal} /tb/adc_data(11) {-radix hexadecimal} /tb/adc_data(10) {-radix hexadecimal}} /tb/adc_data_1
add wave -noupdate -clampanalog 1 -format Analog-Step -height 80 -max 1024.0 -radix hexadecimal /tb/adc_data_2
add wave -noupdate -clampanalog 1 -format Analog-Step -height 80 -max 1024.0 -radix hexadecimal /tb/adc_data_3
add wave -noupdate -radix hexadecimal /tb/adc_valid
add wave -noupdate -divider {Buffer Input}
add wave -noupdate -radix hexadecimal /tb/UUT/ram_data_in
add wave -noupdate -radix hexadecimal /tb/UUT/ram_write
add wave -noupdate -radix hexadecimal /tb/UUT/stop_writing
add wave -noupdate -divider Buffers
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/ram_wr_pointer(9) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(8) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(7) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(6) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(5) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(4) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(3) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(2) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(1) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(0) -radix hexadecimal}} -subitemconfig {/tb/UUT/ram_wr_pointer(9) {-height 16 -radix hexadecimal} /tb/UUT/ram_wr_pointer(8) {-height 16 -radix hexadecimal} /tb/UUT/ram_wr_pointer(7) {-height 16 -radix hexadecimal} /tb/UUT/ram_wr_pointer(6) {-height 16 -radix hexadecimal} /tb/UUT/ram_wr_pointer(5) {-height 16 -radix hexadecimal} /tb/UUT/ram_wr_pointer(4) {-height 16 -radix hexadecimal} /tb/UUT/ram_wr_pointer(3) {-height 16 -radix hexadecimal} /tb/UUT/ram_wr_pointer(2) {-height 16 -radix hexadecimal} /tb/UUT/ram_wr_pointer(1) {-height 16 -radix hexadecimal} /tb/UUT/ram_wr_pointer(0) {-height 16 -radix hexadecimal}} /tb/UUT/ram_wr_pointer
add wave -noupdate -radix hexadecimal /tb/UUT/ram_rd_pointer(0)
add wave -noupdate -radix hexadecimal /tb/UUT/ram_count(0)
add wave -noupdate -divider Reader
add wave -noupdate -radix hexadecimal /tb/UUT/ram_remove
add wave -noupdate -radix hexadecimal /tb/UUT/reg2_ram_remove
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/ram_data_out(0)(17) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(16) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(15) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(14) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(13) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(12) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(11) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(10) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(9) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(8) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(7) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(6) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(5) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(4) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(3) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(2) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(1) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(0) -radix hexadecimal}} -subitemconfig {/tb/UUT/ram_data_out(0)(17) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(16) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(15) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(14) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(13) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(12) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(11) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(10) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(9) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(8) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(7) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(6) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(5) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(4) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(3) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(2) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(1) {-height 16 -radix hexadecimal} /tb/UUT/ram_data_out(0)(0) {-height 16 -radix hexadecimal}} /tb/UUT/ram_data_out(0)
add wave -noupdate -divider Baseline
add wave -noupdate -format Analog-Step -height 80 -max 1024.0 -radix hexadecimal /tb/UUT/baseline(0)
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/baseline(0) -radix hexadecimal} {/tb/UUT/baseline(1) -radix hexadecimal} {/tb/UUT/baseline(2) -radix hexadecimal} {/tb/UUT/baseline(3) -radix hexadecimal}} -subitemconfig {/tb/UUT/baseline(0) {-height 16 -radix hexadecimal} /tb/UUT/baseline(1) {-height 16 -radix hexadecimal} /tb/UUT/baseline(2) {-height 16 -radix hexadecimal} /tb/UUT/baseline(3) {-height 16 -radix hexadecimal}} /tb/UUT/baseline
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/baseline_averages(0) -radix hexadecimal} {/tb/UUT/baseline_averages(1) -radix hexadecimal} {/tb/UUT/baseline_averages(2) -radix hexadecimal} {/tb/UUT/baseline_averages(3) -radix hexadecimal}} -subitemconfig {/tb/UUT/baseline_averages(0) {-height 16 -radix hexadecimal} /tb/UUT/baseline_averages(1) {-height 16 -radix hexadecimal} /tb/UUT/baseline_averages(2) {-height 16 -radix hexadecimal} /tb/UUT/baseline_averages(3) {-height 16 -radix hexadecimal}} /tb/UUT/baseline_averages
add wave -noupdate -expand /tb/UUT/readout_flag
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/thresh_counter(3) -radix hexadecimal} {/tb/UUT/thresh_counter(2) -radix hexadecimal} {/tb/UUT/thresh_counter(1) -radix hexadecimal} {/tb/UUT/thresh_counter(0) -radix hexadecimal}} -expand -subitemconfig {/tb/UUT/thresh_counter(3) {-height 16 -radix hexadecimal} /tb/UUT/thresh_counter(2) {-height 16 -radix hexadecimal} /tb/UUT/thresh_counter(1) {-height 16 -radix hexadecimal} /tb/UUT/thresh_counter(0) {-height 16 -radix hexadecimal}} /tb/UUT/thresh_counter
add wave -noupdate -divider Readout
add wave -noupdate /tb/UUT/READOUT_RX.data_valid
add wave -noupdate /tb/UUT/READOUT_RX.valid_timing_trg
add wave -noupdate /tb/UUT/state
add wave -noupdate /tb/UUT/stop_writing_rdo
add wave -noupdate -radix hexadecimal /tb/UUT/after_trg_cnt
add wave -noupdate -divider Config
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/CONFIG.buffer_depth -radix hexadecimal} {/tb/UUT/CONFIG.samples_after -radix hexadecimal} {/tb/UUT/CONFIG.block_count -radix hexadecimal} {/tb/UUT/CONFIG.trigger_threshold -radix hexadecimal} {/tb/UUT/CONFIG.readout_threshold -radix hexadecimal} {/tb/UUT/CONFIG.presum -radix hexadecimal} {/tb/UUT/CONFIG.averaging -radix hexadecimal} {/tb/UUT/CONFIG.trigger_enable -radix hexadecimal} {/tb/UUT/CONFIG.baseline_always_on -radix hexadecimal} {/tb/UUT/CONFIG.baseline_reset_value -radix hexadecimal} {/tb/UUT/CONFIG.block_avg -radix hexadecimal} {/tb/UUT/CONFIG.block_sums -radix hexadecimal} {/tb/UUT/CONFIG.block_scale -radix hexadecimal}} -subitemconfig {/tb/UUT/CONFIG.buffer_depth {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.samples_after {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.block_count {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.trigger_threshold {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.readout_threshold {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.presum {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.averaging {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.trigger_enable {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.baseline_always_on {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.baseline_reset_value {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.block_avg {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.block_sums {-height 16 -radix hexadecimal} /tb/UUT/CONFIG.block_scale {-height 16 -radix hexadecimal}} /tb/UUT/CONFIG
add wave -noupdate /tb/UUT/TRIGGER_OUT
add wave -noupdate -expand /tb/UUT/trigger_gen
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {15136 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
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
WaveRestoreZoom {14644 ns} {15626 ns}
