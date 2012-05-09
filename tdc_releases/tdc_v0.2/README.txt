##-----------------------------------------------------------------------
##			Implementation of TDC in FPGA
##-----------------------------------------------------------------------


---------------------------------------------
## v0.2 09.05.2012
## Cahit Ugur, HIM, Mainz
## ugur@kph.uni-mainz.de
---------------------------------------------

Contents:
---------
bit_file/trb3_periph.bit
lpf_file/trb3_periph_constraints.lpf
prj_file/trb3_periph.prj
prj_file/trb3_periph.edf
source/Adder_304.vhd
source/bit_sync.vhd
source/Channel.vhd
source/corell.vhd
source/Encoder_304_Bit.vhd
source/FIFO_32x512_OutReg.vhd
source/pll_100_in_5_out.vhd
source/Reference_channel.vhd
source/ROM_encoder_3.vhd
source/ROM_FIFO.vhd
source/TDC.vhd
source/trb3_periph.vhd
source/up_counter.vhd
documentation/TDC_data_format.pdf
documentation/trb3_ctrl_stat_regs.odt


General Details:
----------------
The control-status registers map and the data format of the tdc can be found
in the documentation folder.


Version Details:
----------------
v0.2 09.05.2012

# of Channels	: 32 (for rising & falling edges of 16 channels)
LUTs used	: 41718 / 149040 (28,0%)
Registers used	: 34930 / 111780 (31,2%)
SLICEs used	: 26764 / 74520  (35,9%)

- 32 physical channels are implemented in order to measure rising & falling
times of 16 pulses (including the reference channel). The timing information
of the edges of the same pulse are in the adjacent channels, e.g., Ch0-rising
edge of reference time, Ch1-falling edge of reference time, Ch2-rising edge of
INP0, Ch3-falling edge of INP0.
- Designed for "with trigger" and "triggerless" run. (for slow control refer
to the documentation)
- Post trigger window value must be set to minimum 0x1f


v0.1 10.03.2012
- 24 channes are implemented


v0.0 10.03.2012
- 8 channels are implemented.
- 2 transition wave union laucher is used for precise time measurements.
- Single edge (rising edge) is detected.
- ROM based encoder handles the conversion from thermometer code to binary
code.
- The register array (after the delay line) is designed as double
synchroniser.


Known Issues:
-------------

v0.0 10.03.2012
- The ROM table of the encoder has to be filled for bubble errors worse than 2
bits. There are empty bins.
- The double synchroniser should be removed.


Bug Report:
-----------

