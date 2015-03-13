--type definitions and components for MuPix readout
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mupix_components is

  --MuPix Board entity with regio to trbv3
  component MuPix3_Board
    port (
      clk                        : in  std_logic;
      fast_clk                   : in  std_logic;
      reset                      : in  std_logic;
      timestamp_from_mupix       : in  std_logic_vector(7 downto 0);
      rowaddr_from_mupix         : in  std_logic_vector(5 downto 0);
      coladdr_from_mupix         : in  std_logic_vector(5 downto 0);
      priout_from_mupix          : in  std_logic;
      sout_c_from_mupix          : in  std_logic;
      sout_d_from_mupix          : in  std_logic;
      hbus_from_mupix            : in  std_logic;
      fpga_aux_from_board        : in  std_logic_vector(5 downto 0);
      ldpix_to_mupix             : out std_logic;
      ldcol_to_mupix             : out std_logic;
      timestamp_to_mupix         : out std_logic_vector(7 downto 0);
      rdcol_to_mupix             : out std_logic;
      pulldown_to_mupix          : out std_logic;
      sin_to_mupix               : out std_logic;
      ck_d_to_mupix              : out std_logic;
      ck_c_to_mupix              : out std_logic;
      ld_c_to_mupix              : out std_logic;
      testpulse1_to_board        : out std_logic;
      testpulse2_to_board        : out std_logic;
      spi_din_to_board           : out std_logic;
      spi_clk_to_board           : out std_logic;
      spi_ld_to_board            : out std_logic;
      fpga_led_to_board          : out std_logic_vector(3 downto 0);
      fpga_aux_to_board          : out std_logic_vector(3 downto 0);
      timestampreset_in          : in std_logic;
      eventcounterreset_in       : in std_logic;
      TIMING_TRG_IN              : in  std_logic;
      LVL1_TRG_DATA_VALID_IN     : in  std_logic;
      LVL1_VALID_TIMING_TRG_IN   : in  std_logic;
      LVL1_VALID_NOTIMING_TRG_IN : in  std_logic;
      LVL1_INVALID_TRG_IN        : in  std_logic;
      LVL1_TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
      LVL1_TRG_NUMBER_IN         : in  std_logic_vector(15 downto 0);
      LVL1_TRG_CODE_IN           : in  std_logic_vector(7 downto 0);
      LVL1_TRG_INFORMATION_IN    : in  std_logic_vector(23 downto 0);
      LVL1_INT_TRG_NUMBER_IN     : in  std_logic_vector(15 downto 0);
      FEE_TRG_RELEASE_OUT        : out std_logic;
      FEE_TRG_STATUSBITS_OUT     : out std_logic_vector(31 downto 0);
      FEE_DATA_OUT               : out std_logic_vector(31 downto 0);
      FEE_DATA_WRITE_OUT         : out std_logic;
      FEE_DATA_FINISHED_OUT      : out std_logic;
      FEE_DATA_ALMOST_FULL_IN    : in  std_logic;
      REGIO_ADDR_IN              : in  std_logic_vector(15 downto 0);
      REGIO_DATA_IN              : in  std_logic_vector(31 downto 0);
      REGIO_DATA_OUT             : out std_logic_vector(31 downto 0);
      REGIO_READ_ENABLE_IN       : in  std_logic;
      REGIO_WRITE_ENABLE_IN      : in  std_logic;
      REGIO_TIMEOUT_IN           : in  std_logic;
      REGIO_DATAREADY_OUT        : out std_logic;
      REGIO_WRITE_ACK_OUT        : out std_logic;
      REGIO_NO_MORE_DATA_OUT     : out std_logic;
      REGIO_UNKNOWN_ADDR_OUT     : out std_logic);
  end component;

  --Interface to MuPix 3/4/6
  component mupix_interface
    port (
      rst                  : in  std_logic;
      clk                  : in  std_logic;
      ldpix                : out std_logic;
      ldcol                : out std_logic;
      rdcol                : out std_logic;
      pulldown             : out std_logic;
      timestamps           : out std_logic_vector(7 downto 0);
      priout               : in  std_logic;
      hit_col              : in  std_logic_vector(5 downto 0);
      hit_row              : in  std_logic_vector(5 downto 0);
      hit_time             : in  std_logic_vector(7 downto 0);
      memdata              : out std_logic_vector(31 downto 0);
      memwren              : out std_logic;
      endofevent           : out std_logic;
      ro_busy              : out std_logic;
      trigger_ext          : in  std_logic;
      timestampreset_in    : in std_logic;
      eventcounterreset_in : in std_logic;
      SLV_READ_IN          : in  std_logic;
      SLV_WRITE_IN         : in  std_logic;
      SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
      SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
      SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
      SLV_ACK_OUT          : out std_logic;
      SLV_NO_MORE_DATA_OUT : out std_logic;
      SLV_UNKNOWN_ADDR_OUT : out std_logic);
  end component;

  --SPI entity to write Sensorboard DACs
  component spi_if
    port (
      clk                  : in  std_logic;
      reset                : in  std_logic;
      SLV_READ_IN          : in  std_logic;
      SLV_WRITE_IN         : in  std_logic;
      SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
      SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
      SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
      SLV_ACK_OUT          : out std_logic;
      SLV_NO_MORE_DATA_OUT : out std_logic;
      SLV_UNKNOWN_ADDR_OUT : out std_logic;
      spi_data             : out std_logic;
      spi_clk              : out std_logic;
      spi_ld               : out std_logic);
  end component;

  --Injection Generator
  component injection_generator
    port (
      rst                  : in  std_logic;
      clk                  : in  std_logic;
      SLV_READ_IN          : in  std_logic;
      SLV_WRITE_IN         : in  std_logic;
      SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
      SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
      SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
      SLV_ACK_OUT          : out std_logic;
      SLV_NO_MORE_DATA_OUT : out std_logic;
      SLV_UNKNOWN_ADDR_OUT : out std_logic;
      testpulse1           : out std_logic;
      testpulse2           : out std_logic);
  end component;

  --HitBus Histogram
  component HitbusHistogram
    generic (
      HistogramRange : integer);
    port (
      clk                  : in  std_logic;
      hitbus               : in  std_logic;
      Trigger              : out std_logic;
      SLV_READ_IN          : in  std_logic;
      SLV_WRITE_IN         : in  std_logic;
      SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
      SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
      SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
      SLV_ACK_OUT          : out std_logic;
      SLV_NO_MORE_DATA_OUT : out std_logic;
      SLV_UNKNOWN_ADDR_OUT : out std_logic);
  end component;

  --Graycounter for timestamp Generation
  component Graycounter
    generic (
      COUNTWIDTH : integer);
    port (
      clk            : in  std_logic;
      reset          : in  std_logic;
      sync_reset     : in  std_logic;
      clk_divcounter : in  std_logic_vector(7 downto 0);
      counter        : out std_logic_vector(COUNTWIDTH-1 downto 0));
  end component;


  --FiFo for Event Buffer
  component fifo_32_data
    port (
      Data        : in  std_logic_vector(31 downto 0);
      Clock       : in  std_logic;
      WrEn        : in  std_logic;
      RdEn        : in  std_logic;
      Reset       : in  std_logic;
      Q           : out std_logic_vector(31 downto 0);
      WCNT        : out std_logic_vector(10 downto 0);
      Empty       : out std_logic;
      Full        : out std_logic;
      AlmostEmpty : out std_logic);
  end component;

  --Event Buffer
  component EventBuffer
    port (
      CLK                     : in  std_logic;
      Reset                   : in  std_logic;
      MuPixData_in            : in  std_logic_vector(31 downto 0);
      MuPixDataWr_in          : in  std_logic;
      MuPixEndOfEvent_in      : in  std_logic;
      FEE_DATA_OUT            : out std_logic_vector(31 downto 0);
      FEE_DATA_WRITE_OUT      : out std_logic;
      FEE_DATA_FINISHED_OUT   : out std_logic;
      FEE_DATA_ALMOST_FULL_IN : in  std_logic;
      valid_trigger_in        : in  std_logic;
      clear_buffer_in         : in  std_logic;
      SLV_READ_IN             : in  std_logic;
      SLV_WRITE_IN            : in  std_logic;
      SLV_DATA_IN             : in  std_logic_vector(31 downto 0);
      SLV_ADDR_IN             : in  std_logic_vector(15 downto 0);
      SLV_DATA_OUT            : out std_logic_vector(31 downto 0);
      SLV_ACK_OUT             : out std_logic;
      SLV_NO_MORE_DATA_OUT    : out std_logic;
      SLV_UNKNOWN_ADDR_OUT    : out std_logic);
  end component;

  --MuPix DAC and Tune DAC Slow Control
  component PixCtr
    port (
      clk                  : in  std_logic;
      sout_c_from_mupix    : in  std_logic;
      sout_d_from_mupix    : in  std_logic;
      ck_d_to_mupix        : out std_logic;
      ck_c_to_mupix        : out std_logic;
      ld_c_to_mupix        : out std_logic;
      sin_to_mupix         : out std_logic;
      SLV_READ_IN          : in  std_logic;
      SLV_WRITE_IN         : in  std_logic;
      SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
      SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
      SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
      SLV_ACK_OUT          : out std_logic;
      SLV_NO_MORE_DATA_OUT : out std_logic;
      SLV_UNKNOWN_ADDR_OUT : out std_logic);
  end component;

  --Trigger Handler
  component TriggerHandler is
    port (
      CLK_IN                     : in  std_logic;
      RESET_IN                   : in  std_logic;
      TIMING_TRIGGER_IN          : in  std_logic;
      LVL1_TRG_DATA_VALID_IN     : in  std_logic;
      LVL1_VALID_TIMING_TRG_IN   : in  std_logic;
      LVL1_VALID_NOTIMING_TRG_IN : in  std_logic;
      LVL1_INVALID_TRG_IN        : in  std_logic;
      LVL1_TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
      LVL1_TRG_NUMBER_IN         : in  std_logic_vector(15 downto 0);
      LVL1_TRG_CODE_IN           : in  std_logic_vector(7 downto 0);
      LVL1_TRG_INFORMATION_IN    : in  std_logic_vector(23 downto 0);
      LVL1_INT_TRG_NUMBER_IN     : in  std_logic_vector(15 downto 0);
      FEE_DATA_OUT               : out std_logic_vector(31 downto 0);
      FEE_DATA_WRITE_OUT         : out std_logic;
      FEE_DATA_FINISHED_OUT      : out std_logic;
      FEE_TRG_RELEASE_OUT        : out std_logic;
      FEE_TRG_STATUSBITS_OUT     : out std_logic_vector(31 downto 0);
      FEE_DATA_0_IN              : in  std_logic_vector(31 downto 0);
      FEE_DATA_WRITE_0_IN        : in  std_logic;
      TRIGGER_BUSY_MUPIX_READ_IN : in  std_logic;
      TRIGGER_BUSY_FIFO_READ_IN  : in  std_logic;
      VALID_TRIGGER_OUT          : out std_logic;
      TRIGGER_TIMING_OUT         : out std_logic;
      TRIGGER_STATUS_OUT         : out std_logic;
      FAST_CLEAR_OUT             : out std_logic;
      FLUSH_BUFFER_OUT           : out std_logic;
      SLV_READ_IN                : in  std_logic;
      SLV_WRITE_IN               : in  std_logic;
      SLV_DATA_OUT               : out std_logic_vector(31 downto 0);
      SLV_DATA_IN                : in  std_logic_vector(31 downto 0);
      SLV_ADDR_IN                : in  std_logic_vector(15 downto 0);
      SLV_ACK_OUT                : out std_logic;
      SLV_NO_MORE_DATA_OUT       : out std_logic;
      SLV_UNKNOWN_ADDR_OUT       : out std_logic);
  end component TriggerHandler;

  component board_interface is
    port (
      clk_in                    : in  std_logic;
      fast_clk_in               : in  std_logic;
      timestamp_from_mupix      : in  std_logic_vector(7 downto 0);
      rowaddr_from_mupix        : in  std_logic_vector(5 downto 0);
      coladdr_from_mupix        : in  std_logic_vector(5 downto 0);
      priout_from_mupix         : in  std_logic;
      sout_c_from_mupix         : in  std_logic;
      sout_d_from_mupix         : in  std_logic;
      hbus_from_mupix           : in  std_logic;
      fpga_aux_from_board       : in  std_logic_vector(5 downto 0);
      timestamp_from_mupix_sync : out std_logic_vector(7 downto 0);
      rowaddr_from_mupix_sync   : out std_logic_vector(5 downto 0);
      coladdr_from_mupix_sync   : out std_logic_vector(5 downto 0);
      priout_from_mupix_sync    : out std_logic;
      sout_c_from_mupix_sync    : out std_logic;
      sout_d_from_mupix_sync    : out std_logic;
      hbus_form_mupix_sync      : out std_logic;
      fpga_aux_from_board_sync  : out std_logic_vector(5 downto 0);
      szintilator_sync          : out std_logic;
      SLV_READ_IN               : in  std_logic;
      SLV_WRITE_IN              : in  std_logic;
      SLV_DATA_OUT              : out std_logic_vector(31 downto 0);
      SLV_DATA_IN               : in  std_logic_vector(31 downto 0);
      SLV_ADDR_IN               : in  std_logic_vector(15 downto 0);
      SLV_ACK_OUT               : out std_logic;
      SLV_NO_MORE_DATA_OUT      : out std_logic;
      SLV_UNKNOWN_ADDR_OUT      : out std_logic);
  end component board_interface;

  component resethandler is
    port (
      CLK_IN                : in  std_logic;
      RESET_IN              : in  std_logic;
      TimestampReset_OUT    : out std_logic;
      EventCounterReset_OUT : out std_logic;
      SLV_READ_IN           : in  std_logic;
      SLV_WRITE_IN          : in  std_logic;
      SLV_DATA_OUT          : out std_logic_vector(31 downto 0);
      SLV_DATA_IN           : in  std_logic_vector(31 downto 0);
      SLV_ADDR_IN           : in  std_logic_vector(15 downto 0);
      SLV_ACK_OUT           : out std_logic;
      SLV_NO_MORE_DATA_OUT  : out std_logic;
      SLV_UNKNOWN_ADDR_OUT  : out std_logic);
  end component resethandler;

  component TimeWalkWithFiFo is
    port (
      trb_slv_clock        : in  std_logic;
      fast_clk             : in  std_logic;
      reset                : in  std_logic;
      hitbus               : in  std_logic;
      szintillator_trigger : in  std_logic;
      SLV_READ_IN          : in  std_logic;
      SLV_WRITE_IN         : in  std_logic;
      SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
      SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
      SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
      SLV_ACK_OUT          : out std_logic;
      SLV_NO_MORE_DATA_OUT : out std_logic;
      SLV_UNKNOWN_ADDR_OUT : out std_logic);
  end component TimeWalkWithFiFo;

  component TimeWalk is
    port (
      clk                  : in  std_logic;
      reset                : in  std_logic;
      hitbus               : in  std_logic;
      hitbus_timeout       : in  std_logic_vector(31 downto 0);
      szintillator_trigger : in  std_logic;
      readyToWrite         : in  std_logic;
      measurementFinished  : out std_logic;
      measurementData      : out std_logic_vector(31 downto 0));
  end component TimeWalk;
  
end mupix_components;
