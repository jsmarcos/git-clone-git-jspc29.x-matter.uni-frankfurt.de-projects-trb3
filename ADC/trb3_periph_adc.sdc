# Synopsys, Inc. constraint file
# /d/jspc22/trb/git/trb3/ADC/trb3_periph_adc.sdc
# Written on Tue Aug 26 14:58:43 2014
# by Synplify Pro, F-2012.03-SP1  Scope Editor

#
# Collections
#

#
# Clocks
#
define_clock   {CLK_PCLK_RIGHT} -name {CLK_PCLK_RIGHT}  -freq 200 -clockgroup default_clkgroup_0
define_clock   {n:THE_MEDIA_UPLINK.gen_serdes_1_200\.THE_SERDES.rx_half_clk_ch1} -name {n:THE_MEDIA_UPLINK.gen_serdes_1_200\.THE_SERDES.rx_half_clk_ch1}  -freq 100 -clockgroup default_clkgroup_1
define_clock   {TRIGGER_LEFT} -name {TRIGGER_LEFT}  -freq 10 -clockgroup default_clkgroup_2
define_clock   {n:gen_reallogic\.THE_ADC.THE_ADC_LEFT.gen_7\.THE_7.sclk} -name {n:gen_reallogic\.THE_ADC.THE_ADC_LEFT.gen_7\.THE_7.sclk}  -freq 100 -clockgroup default_clkgroup_3
define_clock   {n:gen_reallogic\.THE_ADC.THE_ADC_RIGHT.gen_5\.THE_5.sclk} -name {n:gen_reallogic\.THE_ADC.THE_ADC_RIGHT.gen_5\.THE_5.sclk}  -freq 100 -clockgroup default_clkgroup_4
define_clock   {n:THE_MAIN_PLL.CLKOP} -name {n:THE_MAIN_PLL.CLKOP}  -freq 100 -clockgroup default_clkgroup_5
define_clock   {n:THE_MEDIA_UPLINK.gen_serdes_1_200\.THE_SERDES.rx_half_clk_ch1} -name {n:THE_MEDIA_UPLINK.gen_serdes_1_200\.THE_SERDES.rx_half_clk_ch1}  -freq 100 -clockgroup default_clkgroup_6
define_clock   {n:THE_MEDIA_UPLINK.gen_serdes_1_200\.THE_SERDES.refclkdiv2_rx_ch1} -name {n:THE_MEDIA_UPLINK.gen_serdes_1_200\.THE_SERDES.refclkdiv2_rx_ch1}  -freq 100 -clockgroup default_clkgroup_7
define_clock   {n:THE_MEDIA_UPLINK.gen_serdes_1_200\.THE_SERDES.refclkdiv2_tx_ch} -name {n:THE_MEDIA_UPLINK.gen_serdes_1_200\.THE_SERDES.refclkdiv2_tx_ch}  -freq 100 -clockgroup default_clkgroup_8

#
# Clock to Clock
#

#
# Inputs/Outputs
#

#
# Registers
#

#
# Delay Paths
#

#
# Attributes
#

#
# I/O Standards
#

#
# Compile Points
#

#
# Other
#
