library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.trb_net_std.all;

package tdc_components is
  
  component TDC is
    generic (
      CHANNEL_NUMBER : integer range 2 to 65;
      STATUS_REG_NR  : integer range 0 to 31;
      CONTROL_REG_NR : integer range 0 to 6;
      TDC_VERSION    : std_logic_vector(11 downto 0);
      DEBUG          : integer range 0 to 1 := c_YES;
      SIMULATION     : integer range 0 to 1 := c_NO);
    port (
      RESET                 : in  std_logic;
      CLK_TDC               : in  std_logic;
      CLK_READOUT           : in  std_logic;
      REFERENCE_TIME        : in  std_logic;
      HIT_IN                : in  std_logic_vector(CHANNEL_NUMBER-1 downto 1);
      HIT_CAL_IN            : in  std_logic;
      TRG_WIN_PRE           : in  std_logic_vector(10 downto 0);
      TRG_WIN_POST          : in  std_logic_vector(10 downto 0);
      TRG_DATA_VALID_IN     : in  std_logic                     := '0';
      VALID_TIMING_TRG_IN   : in  std_logic                     := '0';
      VALID_NOTIMING_TRG_IN : in  std_logic                     := '0';
      INVALID_TRG_IN        : in  std_logic                     := '0';
      TMGTRG_TIMEOUT_IN     : in  std_logic                     := '0';
      SPIKE_DETECTED_IN     : in  std_logic                     := '0';
      MULTI_TMG_TRG_IN      : in  std_logic                     := '0';
      SPURIOUS_TRG_IN       : in  std_logic                     := '0';
      TRG_NUMBER_IN         : in  std_logic_vector(15 downto 0) := (others => '0');
      TRG_CODE_IN           : in  std_logic_vector(7 downto 0)  := (others => '0');
      TRG_INFORMATION_IN    : in  std_logic_vector(23 downto 0) := (others => '0');
      TRG_TYPE_IN           : in  std_logic_vector(3 downto 0)  := (others => '0');
      TRG_RELEASE_OUT       : out std_logic;
      TRG_STATUSBIT_OUT     : out std_logic_vector(31 downto 0);
      DATA_OUT              : out std_logic_vector(31 downto 0);
      DATA_WRITE_OUT        : out std_logic;
      DATA_FINISHED_OUT     : out std_logic;
      HCB_READ_EN_IN        : in  std_logic;
      HCB_WRITE_EN_IN       : in  std_logic;
      HCB_ADDR_IN           : in  std_logic_vector(6 downto 0);
      HCB_DATA_OUT          : out std_logic_vector(31 downto 0);
      HCB_DATAREADY_OUT     : out std_logic;
      HCB_UNKNOWN_ADDR_OUT  : out std_logic;
      SRB_READ_EN_IN        : in  std_logic;
      SRB_WRITE_EN_IN       : in  std_logic;
      SRB_ADDR_IN           : in  std_logic_vector(6 downto 0);
      SRB_DATA_OUT          : out std_logic_vector(31 downto 0);
      SRB_DATAREADY_OUT     : out std_logic;
      SRB_UNKNOWN_ADDR_OUT  : out std_logic;
      CDB_READ_EN_IN        : in  std_logic;
      CDB_WRITE_EN_IN       : in  std_logic;
      CDB_ADDR_IN           : in  std_logic_vector(6 downto 0);
      CDB_DATA_OUT          : out std_logic_vector(31 downto 0);
      CDB_DATAREADY_OUT     : out std_logic;
      CDB_UNKNOWN_ADDR_OUT  : out std_logic;
      ESB_READ_EN_IN        : in  std_logic;
      ESB_WRITE_EN_IN       : in  std_logic;
      ESB_ADDR_IN           : in  std_logic_vector(6 downto 0);
      ESB_DATA_OUT          : out std_logic_vector(31 downto 0);
      ESB_DATAREADY_OUT     : out std_logic;
      ESB_UNKNOWN_ADDR_OUT  : out std_logic;
      EFB_READ_EN_IN        : in  std_logic;
      EFB_WRITE_EN_IN       : in  std_logic;
      EFB_ADDR_IN           : in  std_logic_vector(6 downto 0);
      EFB_DATA_OUT          : out std_logic_vector(31 downto 0);
      EFB_DATAREADY_OUT     : out std_logic;
      EFB_UNKNOWN_ADDR_OUT  : out std_logic;
      LHB_READ_EN_IN        : in  std_logic;
      LHB_WRITE_EN_IN       : in  std_logic;
      LHB_ADDR_IN           : in  std_logic_vector(6 downto 0);
      LHB_DATA_OUT          : out std_logic_vector(31 downto 0);
      LHB_DATAREADY_OUT     : out std_logic;
      LHB_UNKNOWN_ADDR_OUT  : out std_logic;
      LOGIC_ANALYSER_OUT    : out std_logic_vector(15 downto 0);
      CONTROL_REG_IN        : in  std_logic_vector(32*CONTROL_REG_NR-1 downto 0));
  end component TDC;

  component Channel
    generic (
      CHANNEL_ID : integer range 0 to 64;
      DEBUG      : integer range 0 to 1;
      SIMULATION : integer range 0 to 1;
      REFERENCE  : integer range 0 to 1);
    port (
      RESET_200               : in  std_logic;
      RESET_100               : in  std_logic;
      RESET_COUNTERS          : in  std_logic;
      CLK_200                 : in  std_logic;
      CLK_100                 : in  std_logic;
      HIT_IN                  : in  std_logic;
      HIT_EDGE_IN             : in  std_logic;
      TRG_WIN_END_TDC_IN      : in  std_logic;
      TRG_WIN_END_RDO_IN      : in  std_logic;
      READ_EN_IN              : in  std_logic;
      FIFO_DATA_OUT           : out std_logic_vector(35 downto 0);
      FIFO_DATA_VALID_OUT     : out std_logic;
      FIFO_EMPTY_OUT          : out std_logic;
      FIFO_FULL_OUT           : out std_logic;
      FIFO_ALMOST_EMPTY_OUT   : out std_logic;
      COARSE_COUNTER_IN       : in  std_logic_vector(10 downto 0);
      EPOCH_COUNTER_IN        : in  std_logic_vector(27 downto 0);
      VALID_TIMING_TRG_IN     : in  std_logic;
      VALID_NOTIMING_TRG_IN   : in  std_logic;
      SPIKE_DETECTED_IN       : in  std_logic;
      MULTI_TMG_TRG_IN        : in  std_logic;
      EPOCH_WRITE_EN_IN       : in  std_logic;
      LOST_HIT_NUMBER         : out std_logic_vector(23 downto 0);
      HIT_DETECT_NUMBER       : out std_logic_vector(30 downto 0);
      ENCODER_START_NUMBER    : out std_logic_vector(23 downto 0);
      ENCODER_FINISHED_NUMBER : out std_logic_vector(23 downto 0);
      FIFO_WRITE_NUMBER       : out std_logic_vector(23 downto 0);
      Channel_200_DEBUG_OUT       : out std_logic_vector(31 downto 0);
      Channel_DEBUG_OUT           : out std_logic_vector(31 downto 0));
  end component;

  component Channel_200 is
    generic (
      CHANNEL_ID : integer range 0 to 64;
      DEBUG      : integer range 0 to 1;
      SIMULATION : integer range 0 to 1;
      REFERENCE  : integer range 0 to 1);
    port (
      CLK_200               : in  std_logic;
      RESET_200             : in  std_logic;
      CLK_100               : in  std_logic;
      RESET_100             : in  std_logic;
      HIT_IN                : in  std_logic;
      HIT_EDGE_IN           : in  std_logic;
      TRG_WIN_END_TDC_IN    : in  std_logic;
      TRG_WIN_END_RDO_IN    : in  std_logic;
      EPOCH_COUNTER_IN      : in  std_logic_vector(27 downto 0);
      COARSE_COUNTER_IN     : in  std_logic_vector(10 downto 0);
      READ_EN_IN            : in  std_logic;
      FIFO_DATA_OUT         : out std_logic_vector(35 downto 0);
      FIFO_DATA_VALID_OUT   : out std_logic;
      VALID_TIMING_TRG_IN   : in  std_logic;
      VALID_NOTIMING_TRG_IN : in  std_logic;
      SPIKE_DETECTED_IN     : in  std_logic;
      MULTI_TMG_TRG_IN      : in  std_logic;
      EPOCH_WRITE_EN_IN     : in  std_logic;
      ENCODER_START_OUT     : out std_logic;
      ENCODER_FINISHED_OUT  : out std_logic;
      FIFO_WRITE_OUT        : out std_logic;
      CHANNEL_200_DEBUG_OUT     : out std_logic_vector(31 downto 0)); 
  end component Channel_200;

  component Readout_Header is
    port (
      RESET_100             : in  std_logic;
      CLK_100               : in  std_logic;
      VALID_TIMING_TRG_IN   : in  std_logic;
      VALID_NOTIMING_TRG_IN : in  std_logic;
      INVALID_TRG_IN        : in  std_logic;
      TRG_CODE_IN           : in  std_logic_vector(7 downto 0);
      TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
      TRG_RELEASE_OUT       : out std_logic;
      TRG_STATUSBIT_OUT     : out std_logic_vector(31 downto 0);
      DATA_OUT              : out std_logic_vector(31 downto 0);
      DATA_WRITE_OUT        : out std_logic;
      DATA_FINISHED_OUT     : out std_logic);
  end component Readout_Header;

  component Readout is
    generic (
      CHANNEL_NUMBER : integer range 2 to 65;
      STATUS_REG_NR  : integer range 0 to 31;
      TDC_VERSION    : std_logic_vector(11 downto 0));
    port (
      RESET_100                : in  std_logic;
      RESET_200                : in  std_logic;
      RESET_COUNTERS           : in  std_logic;
      CLK_100                  : in  std_logic;
      CLK_200                  : in  std_logic;
      HIT_IN                   : in  std_logic_vector(CHANNEL_NUMBER-1 downto 1);
      CH_DATA_IN               : in  std_logic_vector_array_36(0 to CHANNEL_NUMBER);
      CH_DATA_VALID_IN         : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
      CH_EMPTY_IN              : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
      CH_FULL_IN               : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
      CH_ALMOST_EMPTY_IN       : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
      TRG_DATA_VALID_IN        : in  std_logic;
      VALID_TIMING_TRG_IN      : in  std_logic;
      VALID_NOTIMING_TRG_IN    : in  std_logic;
      INVALID_TRG_IN           : in  std_logic;
      TMGTRG_TIMEOUT_IN        : in  std_logic;
      SPIKE_DETECTED_IN        : in  std_logic;
      MULTI_TMG_TRG_IN         : in  std_logic;
      SPURIOUS_TRG_IN          : in  std_logic;
      TRG_NUMBER_IN            : in  std_logic_vector(15 downto 0);
      TRG_CODE_IN              : in  std_logic_vector(7 downto 0);
      TRG_INFORMATION_IN       : in  std_logic_vector(23 downto 0);
      TRG_TYPE_IN              : in  std_logic_vector(3 downto 0);
      DATA_LIMIT_IN            : in  unsigned(7 downto 0);
      TRG_RELEASE_OUT          : out std_logic;
      TRG_STATUSBIT_OUT        : out std_logic_vector(31 downto 0);
      DATA_OUT                 : out std_logic_vector(31 downto 0);
      DATA_WRITE_OUT           : out std_logic;
      DATA_FINISHED_OUT        : out std_logic;
      READ_EN_OUT              : out std_logic_vector(CHANNEL_NUMBER-1 downto 0);
      TRG_WIN_PRE_IN           : in  std_logic_vector(10 downto 0);
      TRG_WIN_POST_IN          : in  std_logic_vector(10 downto 0);
      TRG_WIN_EN_IN            : in  std_logic;
      TRG_WIN_END_TDC_IN       : in  std_logic;
      TRG_WIN_END_RDO_IN       : in  std_logic;
      TRG_TDC_IN               : in  std_logic;
      TRG_TIME_IN              : in  std_logic_vector(38 downto 0);
      LIGHT_MODE_IN            : in  std_logic;
      COARSE_COUNTER_IN        : in  std_logic_vector(10 downto 0);
      EPOCH_COUNTER_IN         : in  std_logic_vector(27 downto 0);
      DEBUG_MODE_EN_IN         : in  std_logic;
      STATUS_REGISTERS_BUS_OUT : out std_logic_vector_array_32(0 to STATUS_REG_NR-1);
      READOUT_DEBUG            : out std_logic_vector(31 downto 0);
      REFERENCE_TIME           : in  std_logic); 
  end component Readout;

  component TriggerHandler is
    generic (
      TRIGGER_NUM            : integer;
      PHYSICAL_EVENT_TRG_NUM : integer);
    port (
      CLK_TRG               : in  std_logic;
      CLK_RDO               : in  std_logic;
      CLK_TDC               : in  std_logic;
      RESET_TRG             : in  std_logic;
      RESET_RDO             : in  std_logic;
      RESET_TDC             : in  std_logic;
      VALID_NOTIMING_TRG_IN : in  std_logic;
      TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
      TRG_RELEASE_IN        : in  std_logic;
      TRG_IN                : in  std_logic_vector(TRIGGER_NUM-1 downto 0);
      TRG_RDO_OUT           : out std_logic_vector(TRIGGER_NUM-1 downto 0);
      TRG_TDC_OUT           : out std_logic_vector(TRIGGER_NUM-1 downto 0);
      TRG_WIN_EN_IN         : in  std_logic;
      TRG_WIN_POST_IN       : in  unsigned(10 downto 0);
      TRG_WIN_END_RDO_OUT   : out std_logic;
      TRG_WIN_END_TDC_OUT   : out std_logic;
      COARSE_COUNTER_IN     : in  std_logic_vector(10 downto 0);
      EPOCH_COUNTER_IN      : in  std_logic_vector(27 downto 0);
      TRG_TIME_OUT          : out std_logic_vector(38 downto 0) := (others => '0'));
  end component TriggerHandler;

  component LogicAnalyser
    generic (
      CHANNEL_NUMBER : integer range 2 to 65);
    port (
      CLK        : in  std_logic;
      RESET      : in  std_logic;
      DATA_IN    : in  std_logic_vector(3*32-1 downto 0);
      CONTROL_IN : in  std_logic_vector(3 downto 0);
      DATA_OUT   : out std_logic_vector(15 downto 0));
  end component;

  component BusHandler
    generic (
      BUS_LENGTH : integer range 0 to 64 := 2);
    port (
      RESET            : in  std_logic;
      CLK              : in  std_logic;
      DATA_IN          : in  std_logic_vector_array_32(0 to BUS_LENGTH);
      READ_EN_IN       : in  std_logic;
      WRITE_EN_IN      : in  std_logic;
      ADDR_IN          : in  std_logic_vector(6 downto 0);
      DATA_OUT         : out std_logic_vector(31 downto 0);
      DATAREADY_OUT    : out std_logic;
      UNKNOWN_ADDR_OUT : out std_logic);
  end component;

  component ROM_FIFO
    port (
      Address    : in  std_logic_vector(7 downto 0);
      OutClock   : in  std_logic;
      OutClockEn : in  std_logic;
      Reset      : in  std_logic;
      Q          : out std_logic_vector(3 downto 0));
  end component;

  component Stretcher is
    generic (
      CHANNEL : integer range 1 to 64;
      DEPTH   : integer range 1 to 10);
    port (
      PULSE_IN  : in  std_logic_vector(CHANNEL-1 downto 0);
      PULSE_OUT : out std_logic_vector(CHANNEL-1 downto 0));
  end component Stretcher;

  component Stretcher_A is
    generic (
      CHANNEL : integer range 1 to 64;
      DEPTH   : integer range 1 to 10);
    port (
      PULSE_IN  : in  std_logic_vector(CHANNEL*DEPTH downto 1);
      PULSE_OUT : out std_logic_vector(CHANNEL*DEPTH-1 downto 0));
  end component Stretcher_A;

  component Stretcher_B is
    generic (
      CHANNEL : integer range 1 to 64;
      DEPTH   : integer range 1 to 10);
    port (
      PULSE_IN  : in  std_logic_vector(CHANNEL*DEPTH-1 downto 1);
      PULSE_OUT : out std_logic_vector(CHANNEL*DEPTH-1 downto 1));
  end component Stretcher_B;

  component up_counter
    generic (
      NUMBER_OF_BITS : positive); 
    port (
      CLK       : in  std_logic;
      RESET     : in  std_logic;
      COUNT_OUT : out std_logic_vector(NUMBER_OF_BITS-1 downto 0);
      UP_IN     : in  std_logic); 
  end component;

  component Adder_304
    port (
      CLK    : in  std_logic;
      RESET  : in  std_logic;
      DataA  : in  std_logic_vector(303 downto 0);
      DataB  : in  std_logic_vector(303 downto 0);
      ClkEn  : in  std_logic;
      Result : out std_logic_vector(303 downto 0));
  end component;

  component Encoder_304_Bit is
    port (
      RESET            : in  std_logic;
      CLK              : in  std_logic;
      START_IN         : in  std_logic;
      THERMOCODE_IN    : in  std_logic_vector(303 downto 0);
      FINISHED_OUT     : out std_logic;
      BINARY_CODE_OUT  : out std_logic_vector(9 downto 0);
      ENCODER_INFO_OUT : out std_logic_vector(1 downto 0);
      ENCODER_DEBUG    : out std_logic_vector(31 downto 0));
  end component Encoder_304_Bit;

  component hit_mux is
    port (
      CH_EN_IN           : in  std_logic;
      CALIBRATION_EN_IN  : in  std_logic;
      HIT_CALIBRATION_IN : in  std_logic;
      HIT_PHYSICAL_IN    : in  std_logic;
      HIT_OUT            : out std_logic);
  end component hit_mux;

  component ROM_encoder_3
    port (
      Address    : in  std_logic_vector(9 downto 0);
      OutClock   : in  std_logic;
      OutClockEn : in  std_logic;
      Reset      : in  std_logic;
      Q          : out std_logic_vector(7 downto 0));
  end component;

  component ROM4_Encoder is
    port (
      Address    : in  std_logic_vector(9 downto 0);
      OutClock   : in  std_logic;
      OutClockEn : in  std_logic;
      Reset      : in  std_logic;
      Q          : out std_logic_vector(7 downto 0));
  end component ROM4_Encoder;


end package tdc_components;
