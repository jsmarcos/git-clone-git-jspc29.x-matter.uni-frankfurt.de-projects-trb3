##-----------------------------------------------------------------------
##			Implementation of TDC in FPGA
##-----------------------------------------------------------------------


---------------------------------------------
## v0.3 25.06.2012
## Cahit Ugur, HIM, Mainz
## ugur@kph.uni-mainz.de
---------------------------------------------

Contents:
---------
tdc_constraints.lpf

Adder_304.vhd
bit_sync.vhd
Channel.vhd
Encoder_304_Bit.vhd
FIFO_32x512_OutReg.vhd
Reference_channel.vhd
ROM_encoder_3.vhd
ROM_FIFO.vhd
TDC.vhd
up_counter.vhd


General Details:
----------------
The control-status registers map and the data format of the tdc can be found
in the repository /daq_docu/trb3


Version Details:
----------------
v0.3 25.06.2012

# of Channels	: 32 (for rising edges of 32 channels)
LUTs used	: 32469 / 149040 (21,8%)
Registers used	: 35148 / 111780 (31,4%)
SLICEs used	: 25637 / 74520  (34,4%)

- 32 physical channels are implemented in order to measure the rising edges
(including the reference channel).
- Designed for "with trigger" and "triggerless" run. (for slow control refer
to the documentation)
- Post trigger window value must be set to minimum 0x1f


v0.2 09.05.2012
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

