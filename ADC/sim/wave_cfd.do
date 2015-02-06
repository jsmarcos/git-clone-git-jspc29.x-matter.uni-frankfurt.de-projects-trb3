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
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/ram_wr_pointer(9) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(8) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(7) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(6) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(5) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(4) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(3) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(2) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(1) -radix hexadecimal} {/tb/UUT/ram_wr_pointer(0) -radix hexadecimal}} -subitemconfig {/tb/UUT/ram_wr_pointer(9) {-height 14 -radix hexadecimal} /tb/UUT/ram_wr_pointer(8) {-height 14 -radix hexadecimal} /tb/UUT/ram_wr_pointer(7) {-height 14 -radix hexadecimal} /tb/UUT/ram_wr_pointer(6) {-height 14 -radix hexadecimal} /tb/UUT/ram_wr_pointer(5) {-height 14 -radix hexadecimal} /tb/UUT/ram_wr_pointer(4) {-height 14 -radix hexadecimal} /tb/UUT/ram_wr_pointer(3) {-height 14 -radix hexadecimal} /tb/UUT/ram_wr_pointer(2) {-height 14 -radix hexadecimal} /tb/UUT/ram_wr_pointer(1) {-height 14 -radix hexadecimal} /tb/UUT/ram_wr_pointer(0) {-height 14 -radix hexadecimal}} /tb/UUT/ram_wr_pointer
add wave -noupdate -radix hexadecimal /tb/UUT/ram_rd_pointer(0)
add wave -noupdate -radix hexadecimal /tb/UUT/ram_count(0)
add wave -noupdate -divider Reader
add wave -noupdate -radix hexadecimal /tb/UUT/ram_remove
add wave -noupdate -radix hexadecimal /tb/UUT/reg2_ram_remove
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/ram_data_out(0)(17) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(16) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(15) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(14) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(13) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(12) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(11) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(10) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(9) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(8) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(7) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(6) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(5) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(4) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(3) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(2) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(1) -radix hexadecimal} {/tb/UUT/ram_data_out(0)(0) -radix hexadecimal}} -subitemconfig {/tb/UUT/ram_data_out(0)(17) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(16) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(15) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(14) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(13) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(12) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(11) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(10) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(9) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(8) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(7) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(6) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(5) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(4) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(3) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(2) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(1) {-height 15 -radix hexadecimal} /tb/UUT/ram_data_out(0)(0) {-height 15 -radix hexadecimal}} /tb/UUT/ram_data_out(0)
add wave -noupdate -divider Baseline
add wave -noupdate /tb/UUT/ram_read
add wave -noupdate /tb/UUT/baseline_reset
add wave -noupdate -format Analog-Step -height 80 -max 1024.0 -radix hexadecimal /tb/UUT/baseline(0)
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/baseline(0) -radix hexadecimal} {/tb/UUT/baseline(1) -radix hexadecimal} {/tb/UUT/baseline(2) -radix hexadecimal} {/tb/UUT/baseline(3) -radix hexadecimal}} -subitemconfig {/tb/UUT/baseline(0) {-height 15 -radix hexadecimal} /tb/UUT/baseline(1) {-height 15 -radix hexadecimal} /tb/UUT/baseline(2) {-height 15 -radix hexadecimal} /tb/UUT/baseline(3) {-height 15 -radix hexadecimal}} /tb/UUT/baseline
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/baseline_averages(0) -radix hexadecimal} {/tb/UUT/baseline_averages(1) -radix hexadecimal} {/tb/UUT/baseline_averages(2) -radix hexadecimal} {/tb/UUT/baseline_averages(3) -radix hexadecimal}} -subitemconfig {/tb/UUT/baseline_averages(0) {-height 14 -radix hexadecimal} /tb/UUT/baseline_averages(1) {-height 14 -radix hexadecimal} /tb/UUT/baseline_averages(2) {-height 14 -radix hexadecimal} /tb/UUT/baseline_averages(3) {-height 14 -radix hexadecimal}} /tb/UUT/baseline_averages
add wave -noupdate /tb/UUT/readout_flag
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/thresh_counter(3) -radix hexadecimal} {/tb/UUT/thresh_counter(2) -radix hexadecimal} {/tb/UUT/thresh_counter(1) -radix hexadecimal} {/tb/UUT/thresh_counter(0) -radix hexadecimal}} -subitemconfig {/tb/UUT/thresh_counter(3) {-height 14 -radix hexadecimal} /tb/UUT/thresh_counter(2) {-height 14 -radix hexadecimal} /tb/UUT/thresh_counter(1) {-height 14 -radix hexadecimal} /tb/UUT/thresh_counter(0) {-height 14 -radix hexadecimal}} /tb/UUT/thresh_counter
add wave -noupdate -divider Readout
add wave -noupdate /tb/UUT/READOUT_RX.data_valid
add wave -noupdate /tb/UUT/state
add wave -noupdate /tb/UUT/stop_writing_rdo
add wave -noupdate -radix hexadecimal /tb/UUT/after_trg_cnt
add wave -noupdate /tb/UUT/readout_state
add wave -noupdate /tb/UUT/channelselect
add wave -noupdate /tb/UUT/prepare_header
add wave -noupdate /tb/UUT/blockcurrent
add wave -noupdate -radix hexadecimal /tb/UUT/myavg
add wave -noupdate -divider {data processor}
add wave -noupdate /tb/UUT/ram_valid
add wave -noupdate /tb/UUT/RDO_write_proc
add wave -noupdate -radix hexadecimal /tb/UUT/RDO_data_proc
add wave -noupdate /tb/UUT/READOUT_TX.data_finished
add wave -noupdate /tb/UUT/READOUT_TX.busy_release
add wave -noupdate -divider PSA
add wave -noupdate -radix hexadecimal /tb/UUT/psa_adcdata
add wave -noupdate -radix hexadecimal /tb/UUT/psa_ram_out
add wave -noupdate -radix hexadecimal /tb/UUT/psa_output
add wave -noupdate /tb/UUT/ram_read_psa
add wave -noupdate -radix hexadecimal /tb/UUT/psa_addr_i
add wave -noupdate -radix hexadecimal /tb/UUT/psa_clear
add wave -noupdate -radix hexadecimal /tb/UUT/psa_data_i
add wave -noupdate -radix hexadecimal /tb/UUT/psa_enable
add wave -noupdate -radix hexadecimal /tb/UUT/psa_pointer
add wave -noupdate /tb/UUT/psa_state
add wave -noupdate -divider CFD
add wave -noupdate /tb/UUT/READOUT_RX.valid_timing_trg
add wave -noupdate /tb/UUT/ram_read
add wave -noupdate -radix decimal /tb/UUT/ram_rd_pointer(1)
add wave -noupdate -radix hexadecimal /tb/UUT/ram_data_out(1)
add wave -noupdate -radix hexadecimal /tb/UUT/reg_ram_data_out(1)
add wave -noupdate /tb/UUT/ram_read_cfd
add wave -noupdate /tb/UUT/RDO_write_cfd
add wave -noupdate -radix hexadecimal /tb/UUT/RDO_data_cfd
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/reg_ram_data_out(0)(17) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(16) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(15) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(14) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(13) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(12) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(11) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(10) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(9) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(8) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(7) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(6) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(5) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(4) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(3) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(2) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(1) -radix hexadecimal} {/tb/UUT/reg_ram_data_out(0)(0) -radix hexadecimal}} -subitemconfig {/tb/UUT/reg_ram_data_out(0)(17) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(16) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(15) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(14) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(13) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(12) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(11) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(10) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(9) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(8) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(7) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(6) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(5) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(4) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(3) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(2) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(1) {-height 14 -radix hexadecimal} /tb/UUT/reg_ram_data_out(0)(0) {-height 14 -radix hexadecimal}} /tb/UUT/reg_ram_data_out(0)
add wave -noupdate /tb/UUT/cfd_state
add wave -noupdate -radix decimal /tb/UUT/cfd_integral_sum
add wave -noupdate -format Analog-Step -height 100 -max 1000.0 -min -1000.0 -radix decimal /tb/UUT/cfd_subtracted(1)
add wave -noupdate -radix decimal -childformat {{/tb/UUT/cfd_delay_ram(1)(2)(16) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(15) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(14) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(13) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(12) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(11) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(10) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(9) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(8) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(7) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(6) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(5) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(4) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(3) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(2) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(1) -radix decimal} {/tb/UUT/cfd_delay_ram(1)(2)(0) -radix decimal}} -subitemconfig {/tb/UUT/cfd_delay_ram(1)(2)(16) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(15) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(14) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(13) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(12) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(11) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(10) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(9) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(8) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(7) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(6) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(5) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(4) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(3) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(2) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(1) {-height 14 -radix decimal} /tb/UUT/cfd_delay_ram(1)(2)(0) {-height 14 -radix decimal}} /tb/UUT/cfd_delay_ram(1)(2)
add wave -noupdate -format Analog-Step -height 100 -max 1000.0 -min -1000.0 -radix decimal /tb/UUT/cfd(1)
add wave -noupdate -divider Config
add wave -noupdate -radix hexadecimal -childformat {{/tb/UUT/CONFIG.processing_mode -radix hexadecimal} {/tb/UUT/CONFIG.buffer_depth -radix decimal} {/tb/UUT/CONFIG.samples_after -radix hexadecimal} {/tb/UUT/CONFIG.block_count -radix hexadecimal} {/tb/UUT/CONFIG.trigger_threshold -radix decimal} {/tb/UUT/CONFIG.readout_threshold -radix decimal} {/tb/UUT/CONFIG.presum -radix hexadecimal} {/tb/UUT/CONFIG.averaging -radix hexadecimal} {/tb/UUT/CONFIG.trigger_enable -radix hexadecimal} {/tb/UUT/CONFIG.channel_disable -radix hexadecimal} {/tb/UUT/CONFIG.baseline_always_on -radix hexadecimal} {/tb/UUT/CONFIG.baseline_reset_value -radix hexadecimal} {/tb/UUT/CONFIG.block_avg -radix hexadecimal} {/tb/UUT/CONFIG.block_sums -radix hexadecimal} {/tb/UUT/CONFIG.block_scale -radix hexadecimal} {/tb/UUT/CONFIG.check_word1 -radix hexadecimal} {/tb/UUT/CONFIG.check_word2 -radix hexadecimal} {/tb/UUT/CONFIG.check_word_enable -radix hexadecimal} {/tb/UUT/CONFIG.cfd_window -radix hexadecimal} {/tb/UUT/CONFIG.cfd_delay -radix hexadecimal}} -expand -subitemconfig {/tb/UUT/CONFIG.processing_mode {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.buffer_depth {-height 15 -radix decimal} /tb/UUT/CONFIG.samples_after {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.block_count {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.trigger_threshold {-height 15 -radix decimal} /tb/UUT/CONFIG.readout_threshold {-height 15 -radix decimal} /tb/UUT/CONFIG.presum {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.averaging {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.trigger_enable {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.channel_disable {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.baseline_always_on {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.baseline_reset_value {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.block_avg {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.block_sums {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.block_scale {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.check_word1 {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.check_word2 {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.check_word_enable {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.cfd_window {-height 15 -radix hexadecimal} /tb/UUT/CONFIG.cfd_delay {-height 15 -radix hexadecimal}} /tb/UUT/CONFIG
add wave -noupdate /tb/UUT/TRIGGER_OUT
add wave -noupdate /tb/UUT/trigger_gen
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {74100 ns} 0}
configure wave -namecolwidth 232
configure wave -valuecolwidth 107
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
WaveRestoreZoom {72552 ns} {75048 ns}
