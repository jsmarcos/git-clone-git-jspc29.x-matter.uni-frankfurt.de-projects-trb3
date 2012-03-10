##-----------------------------------------------------------------------
##			Implementation of TDC in FPGA
##-----------------------------------------------------------------------


---------------------------------------------
## v0.0 10.03.2010
## Cahit Ugur, HIM, Mainz
## ugur@kph.uni-mainz.de
---------------------------------------------

Contents:
---------
bit_file/trb3_periph.bit
lpf_file/trb3_periph_constraints.lpf
prj_file/trb3_periph.prj
source/Adder_304.vhd
source/bit_sync.vhd
source/Channel.vhd
source/Encoder_304_Bit.vhd
source/Encoder_304_ROMsuz.vhd
source/FIFO_32x512_OutReg.vhd
source/Reference_channel.vhd
source/reset_generator.vhd
source/ROM_Encoder.vhd
source/ROM_FIFO.vhd
source/TDC.vhd
source/trb3_periph.vhd
source/up_counter.vhd
documentation/TDC_data_format.pdf
documentation/trb3_ctrl_stat_regs.odt


General Details:
----------------
This is the first release of the TDC in FPGA.
The first channel (ch0) of the TDC is design as the reference channel.
The control-status registers map and the data format of the tdc can be found
in the documentation folder.


Version Details:
----------------

v0.0 10.03.2012
- 8 channels are implemented.
- 2 transition wave union laucher is used for precise time measurements.
- Single edge (rising edge) is detected.
- ROM based encoder handles the conversion from thermometer code to binary
code.
- The register array (after the delay line) is designed as double
synchroniser.

v0.1 10.03.2012
- 24 channes are implemented


Known Issues:
-------------

v0.0 10.03.2012
- The ROM table of the encoder has to be filled for bubble errors worse than 2
bits. There are empty bins.
- The double synchroniser should be removed.


Changes:
--------

v0.0 10.03.2012
- first release

v0.1 10.03.2012
- number of channels is increased to 24
