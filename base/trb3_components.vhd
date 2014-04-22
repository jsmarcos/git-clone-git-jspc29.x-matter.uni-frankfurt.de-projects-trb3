library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.trb_net_std.all;

package trb3_components is

  type std_logic_vector_array_36 is array (integer range <>) of std_logic_vector(35 downto 0);
  type std_logic_vector_array_32 is array (integer range <>) of std_logic_vector(31 downto 0);
  type std_logic_vector_array_24 is array (integer range <>) of std_logic_vector(23 downto 0);
  type std_logic_vector_array_11 is array (integer range <>) of std_logic_vector(10 downto 0);
  type std_logic_vector_array_8 is array (integer range <>) of std_logic_vector(7 downto 0);
  type unsigned_array_8 is array (integer range <>) of unsigned(7 downto 0);

  component oddr is
    port (
      clk    : in  std_logic;
      clkout : out std_logic;
      da     : in  std_logic_vector(0 downto 0);
      db     : in  std_logic_vector(0 downto 0);
      q      : out std_logic_vector(0 downto 0));
  end component;

  component pll_in125_out125
    port (
      CLK   : in  std_logic;
      CLKOP : out std_logic;            --125 MHz
      CLKOK : out std_logic;            --125 MHz, bypass
      LOCK  : out std_logic
      );
  end component;

  component pll_in125_out20 is
    port (
      CLK   : in  std_logic;
      CLKOP : out std_logic;            -- 20 MHz
      CLKOK : out std_logic;            -- 125 MHz, bypass
      LOCK  : out std_logic);
  end component pll_in125_out20;

  component OSCF  -- internal oscillator with a frequency of 2MHz
    port (OSC : out
          std_logic);
  end component;

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
      HIT_CALIBRATION       : in  std_logic;
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
      FWB_READ_EN_IN        : in  std_logic;  -- not used after version 1.3
      FWB_WRITE_EN_IN       : in  std_logic;  -- not used after version 1.3
      FWB_ADDR_IN           : in  std_logic_vector(6 downto 0);  -- not used after version 1.3
      FWB_DATA_OUT          : out std_logic_vector(31 downto 0);  -- not used after version 1.3
      FWB_DATAREADY_OUT     : out std_logic;  -- not used after version 1.3
      FWB_UNKNOWN_ADDR_OUT  : out std_logic;  -- not used after version 1.3
      LHB_READ_EN_IN        : in  std_logic;
      LHB_WRITE_EN_IN       : in  std_logic;
      LHB_ADDR_IN           : in  std_logic_vector(6 downto 0);
      LHB_DATA_OUT          : out std_logic_vector(31 downto 0);
      LHB_DATAREADY_OUT     : out std_logic;
      LHB_UNKNOWN_ADDR_OUT  : out std_logic;
      LOGIC_ANALYSER_OUT    : out std_logic_vector(15 downto 0);
      CONTROL_REG_IN        : in  std_logic_vector(32*CONTROL_REG_NR-1 downto 0));
  end component TDC;

  component Reference_Channel
    generic (
      CHANNEL_ID : integer range 0 to 0);
    port (
      RESET_200              : in  std_logic;
      RESET_100              : in  std_logic;
      CLK_200                : in  std_logic;
      CLK_100                : in  std_logic;
      HIT_IN                 : in  std_logic;
      READ_EN_IN             : in  std_logic;
      VALID_TMG_TRG_IN       : in  std_logic;
      SPIKE_DETECTED_IN      : in  std_logic;
      MULTI_TMG_TRG_IN       : in  std_logic;
      FIFO_DATA_OUT          : out std_logic_vector(35 downto 0);
      FIFO_WCNT_OUT          : out unsigned(7 downto 0);
      FIFO_EMPTY_OUT         : out std_logic;
      FIFO_FULL_OUT          : out std_logic;
      FIFO_ALMOST_FULL_OUT   : out std_logic;
      COARSE_COUNTER_IN      : in  std_logic_vector(10 downto 0);
      EPOCH_COUNTER_IN       : in  std_logic_vector(27 downto 0);
      TRIGGER_WINDOW_END_IN  : in  std_logic;
      DATA_FINISHED_IN       : in  std_logic;
      RUN_MODE               : in  std_logic;
      TRIGGER_TIME_STAMP_OUT : out std_logic_vector(38 downto 0);
      REF_DEBUG_OUT          : out std_logic_vector(31 downto 0));
  end component;

  component Reference_Channel_200
    generic (
      CHANNEL_ID : integer range 0 to 0);
    port (
      CLK_200                : in  std_logic;
      RESET_200              : in  std_logic;
      CLK_100                : in  std_logic;
      RESET_100              : in  std_logic;
      VALID_TMG_TRG_IN       : in  std_logic;
      SPIKE_DETECTED_IN      : in  std_logic;
      MULTI_TMG_TRG_IN       : in  std_logic;
      HIT_IN                 : in  std_logic;
      READ_EN_IN             : in  std_logic;
      FIFO_DATA_OUT          : out std_logic_vector(35 downto 0);
      FIFO_WCNT_OUT          : out unsigned(7 downto 0);
      FIFO_EMPTY_OUT         : out std_logic;
      FIFO_FULL_OUT          : out std_logic;
      FIFO_ALMOST_FULL_OUT   : out std_logic;
      EPOCH_COUNTER_IN       : in  std_logic_vector(27 downto 0);
      TRIGGER_WINDOW_END_IN  : in  std_logic;
      TRIGGER_TIME_STAMP_OUT : out std_logic_vector(38 downto 0);
      DATA_FINISHED_IN       : in  std_logic;
      RUN_MODE               : in  std_logic;
      COARSE_COUNTER_IN      : in  std_logic_vector(10 downto 0));
  end component;

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
      TRIGGER_WIN_END_TDC     : in  std_logic;
      TRIGGER_WIN_END_RDO     : in  std_logic;
      READ_EN_IN              : in  std_logic;
      FIFO_DATA_OUT           : out std_logic_vector(35 downto 0);
      FIFO_DATA_VALID_OUT     : out std_logic;
      FIFO_EMPTY_OUT          : out std_logic;
      FIFO_FULL_OUT           : out std_logic;
      FIFO_ALMOST_EMPTY_OUT   : out std_logic;
      FIFO_ALMOST_FULL_OUT    : out std_logic;
      COARSE_COUNTER_IN       : in  std_logic_vector(10 downto 0);
      EPOCH_COUNTER_IN        : in  std_logic_vector(27 downto 0);
      VALID_TIMING_TRG_IN     : in  std_logic;
      VALID_NOTIMING_TRG_IN   : in  std_logic;
      SPIKE_DETECTED_IN       : in  std_logic;
      MULTI_TMG_TRG_IN        : in  std_logic;
      EPOCH_WRITE_EN_IN       : in  std_logic;
      LOST_HIT_NUMBER         : out std_logic_vector(23 downto 0);
      HIT_DETECT_NUMBER       : out std_logic_vector(23 downto 0);
      ENCODER_START_NUMBER    : out std_logic_vector(23 downto 0);
      ENCODER_FINISHED_NUMBER : out std_logic_vector(23 downto 0);
      FIFO_WRITE_NUMBER       : out std_logic_vector(23 downto 0);
      Channel_200_DEBUG       : out std_logic_vector(31 downto 0);
      Channel_DEBUG           : out std_logic_vector(31 downto 0));
  end component;

  component Channel_200
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
      RESET_COUNTERS        : in  std_logic;
      HIT_IN                : in  std_logic;
      TRIGGER_WIN_END_TDC   : in  std_logic;
      TRIGGER_WIN_END_RDO   : in  std_logic;
      EPOCH_COUNTER_IN      : in  std_logic_vector(27 downto 0);
      COARSE_COUNTER_IN     : in  std_logic_vector(10 downto 0);
      READ_EN_IN            : in  std_logic;
      FIFO_DATA_OUT         : out std_logic_vector(35 downto 0);
      FIFO_DATA_VALID_OUT   : out std_logic;
      FIFO_EMPTY_OUT        : out std_logic;
      FIFO_FULL_OUT         : out std_logic;
      FIFO_ALMOST_FULL_OUT  : out std_logic;
      VALID_TIMING_TRG_IN   : in  std_logic;
      VALID_NOTIMING_TRG_IN : in  std_logic;
      SPIKE_DETECTED_IN     : in  std_logic;
      MULTI_TMG_TRG_IN      : in  std_logic;
      EPOCH_WRITE_EN_IN     : in  std_logic;
      ENCODER_START_OUT     : out std_logic;
      ENCODER_FINISHED_OUT  : out std_logic;
      FIFO_WRITE_OUT        : out std_logic;
      Channel_200_DEBUG     : out std_logic_vector(31 downto 0));
  end component;

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
      TRIGGER_RDO_IN           : in  std_logic;
      TRIGGER_TDC_IN           : in  std_logic;
      CH_DATA_IN               : in  std_logic_vector_array_36(0 to CHANNEL_NUMBER);
      CH_DATA_VALID_IN         : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
      CH_EMPTY_IN              : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
      CH_FULL_IN               : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
      CH_ALMOST_EMPTY_IN       : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
      CH_ALMOST_FULL_IN        : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
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
      TRG_WIN_PRE              : in  std_logic_vector(10 downto 0);
      TRG_WIN_POST             : in  std_logic_vector(10 downto 0);
      TRIGGER_WIN_EN_IN        : in  std_logic;
      TRIG_WIN_END_TDC_IN      : in  std_logic;
      TRIG_WIN_END_RDO_IN      : in  std_logic;
      COARSE_COUNTER_IN        : in  std_logic_vector(10 downto 0);
      EPOCH_COUNTER_IN         : in  std_logic_vector(27 downto 0);
      DEBUG_MODE_EN_IN         : in  std_logic;
      STATUS_REGISTERS_BUS_OUT : out std_logic_vector_array_32(0 to STATUS_REG_NR-1);
      READOUT_DEBUG            : out std_logic_vector(31 downto 0);
-- ports not used after tdc_v1.5.2
      TRIGGER_WIN_END_OUT      : out std_logic;
      CH_WCNT_IN               : in  unsigned_array_8(0 to CHANNEL_NUMBER-1);
      REFERENCE_TIME           : in  std_logic;
      TRIGGER_TIME_IN          : in  std_logic_vector(38 downto 0)
      );
  end component Readout;


  component TriggerHandler is
    generic (
      TRIGGER_NUM            : integer;
      PHYSICAL_EVENT_TRG_NUM : integer);
    port (
      CLK_TRG                 : in  std_logic;
      CLK_RDO                 : in  std_logic;
      CLK_TDC                 : in  std_logic;
      RESET_TRG               : in  std_logic;
      RESET_RDO               : in  std_logic;
      RESET_TDC               : in  std_logic;
      TRIGGER_IN              : in  std_logic_vector(TRIGGER_NUM-1 downto 0);
      TRIGGER_RDO_OUT         : out std_logic_vector(TRIGGER_NUM-1 downto 0);
      TRIGGER_TDC_OUT         : out std_logic_vector(TRIGGER_NUM-1 downto 0);
      TRIGGER_WIN_EN_IN       : in  std_logic;
      TRIGGER_WIN_POST_IN     : in  unsigned(10 downto 0);
      TRIGGER_WIN_END_RDO_OUT : out std_logic;
      TRIGGER_WIN_END_TDC_OUT : out std_logic);
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

  --component Encoder_304_Bit
  --  port (
  --    RESET           : in  std_logic;
  --    CLK             : in  std_logic;
  --    START_IN        : in  std_logic;
  --    THERMOCODE_IN   : in  std_logic_vector(303 downto 0);
  --    FINISHED_OUT    : out std_logic;
  --    BINARY_CODE_OUT : out std_logic_vector(9 downto 0);
  --    ENCODER_DEBUG   : out std_logic_vector(31 downto 0));
  --end component;

  component hit_mux is
    port (
      CH_EN_IN           : in  std_logic;
      CALIBRATION_EN_IN  : in  std_logic;
      HIT_CALIBRATION_IN : in  std_logic;
      HIT_PHYSICAL_IN    : in  std_logic;
      HIT_OUT            : out std_logic);
  end component hit_mux;

  component FIFO_32x32_OutReg
    port (
      Data       : in  std_logic_vector(31 downto 0);
      WrClock    : in  std_logic;
      RdClock    : in  std_logic;
      WrEn       : in  std_logic;
      RdEn       : in  std_logic;
      Reset      : in  std_logic;
      RPReset    : in  std_logic;
      Q          : out std_logic_vector(31 downto 0);
      Empty      : out std_logic;
      Full       : out std_logic;
      AlmostFull : out std_logic);
  end component;

  component FIFO_36x128_OutReg is
    port (
      Data        : in  std_logic_vector(35 downto 0);
      Clock       : in  std_logic;
      WrEn        : in  std_logic;
      RdEn        : in  std_logic;
      Reset       : in  std_logic;
      Q           : out std_logic_vector(35 downto 0);
      Empty       : out std_logic;
      Full        : out std_logic;
      AlmostEmpty : out std_logic);
  end component FIFO_36x128_OutReg;

  component FIFO_DC_36x128_OutReg is
    port (
      Data       : in  std_logic_vector(35 downto 0);
      WrClock    : in  std_logic;
      RdClock    : in  std_logic;
      WrEn       : in  std_logic;
      RdEn       : in  std_logic;
      Reset      : in  std_logic;
      RPReset    : in  std_logic;
      Q          : out std_logic_vector(35 downto 0);
      Empty      : out std_logic;
      Full       : out std_logic;
      AlmostFull : out std_logic);
  end component FIFO_DC_36x128_OutReg;

  component FIFO_DC_36x64_OutReg is
    port (
      Data       : in  std_logic_vector(35 downto 0);
      WrClock    : in  std_logic;
      RdClock    : in  std_logic;
      WrEn       : in  std_logic;
      RdEn       : in  std_logic;
      Reset      : in  std_logic;
      RPReset    : in  std_logic;
      Q          : out std_logic_vector(35 downto 0);
      Empty      : out std_logic;
      Full       : out std_logic;
      AlmostFull : out std_logic);
  end component FIFO_DC_36x64_OutReg;

  component FIFO_36x128_OutReg_Counter is
    port (
      Data    : in  std_logic_vector(35 downto 0);
      WrClock : in  std_logic;
      RdClock : in  std_logic;
      WrEn    : in  std_logic;
      RdEn    : in  std_logic;
      Reset   : in  std_logic;
      RPReset : in  std_logic;
      Q       : out std_logic_vector(35 downto 0);
      WCNT    : out std_logic_vector(7 downto 0);
      Empty   : out std_logic;
      Full    : out std_logic);
  end component FIFO_36x128_OutReg_Counter;

  --component FIFO_24x2_OutReg
  --  port (
  --    Data    : in  std_logic_vector(23 downto 0);
  --    WrClock : in  std_logic;
  --    RdClock : in  std_logic;
  --    WrEn    : in  std_logic;
  --    RdEn    : in  std_logic;
  --    Reset   : in  std_logic;
  --    RPReset : in  std_logic;
  --    Q       : out std_logic_vector(23 downto 0);
  --    Empty   : out std_logic;
  --    Full    : out std_logic);
  --end component;

  component ROM_Encoder
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

  component bit_sync
    generic (
      DEPTH : integer);
    port (
      RESET : in  std_logic;
      CLK0  : in  std_logic;
      CLK1  : in  std_logic;
      D_IN  : in  std_logic;
      D_OUT : out std_logic);
  end component;

  component edge_to_pulse
    port (
      clock     : in  std_logic;
      en_clk    : in  std_logic;
      signal_in : in  std_logic;
      pulse     : out std_logic);
  end component;

  component risingEdgeDetect is
    port (
      CLK       : in  std_logic;
      SIGNAL_IN : in  std_logic;
      PULSE_OUT : out std_logic);
  end component risingEdgeDetect;

  component fallingEdgeDetect is
    port (
      CLK       : in  std_logic;
      SIGNAL_IN : in  std_logic;
      PULSE_OUT : out std_logic);
  end component fallingEdgeDetect;

  component ShiftRegisterSISO
    generic (
      DEPTH : integer range 1 to 32;
      WIDTH : integer range 1 to 32);
    port (
      CLK   : in  std_logic;
      D_IN  : in  std_logic_vector(WIDTH-1 downto 0);
      D_OUT : out std_logic_vector(WIDTH-1 downto 0));
  end component;

  component Stretcher
    port (
      PULSE_IN  : in  std_logic;
      PULSE_OUT : out std_logic);
  end component;

  component WaveLauncher is
    port (
      HIT_IN  : in  std_logic;
      HIT_OUT : out std_logic);
  end component WaveLauncher;

  component adc_ad9222
    generic(
      CHANNELS   : integer range 4 to 4   := 4;
      DEVICES    : integer range 2 to 2   := 2;
      RESOLUTION : integer range 12 to 12 := 12
      );
    port(
      CLK        : in  std_logic;
      CLK_ADCREF : in  std_logic;
      CLK_ADCDAT : in  std_logic;
      RESTART_IN : in  std_logic;
      ADCCLK_OUT : out std_logic;
      ADC_DATA   : in  std_logic_vector(DEVICES*CHANNELS-1 downto 0);
      ADC_DCO    : in  std_logic_vector(DEVICES-1 downto 0);
      ADC_FCO    : in  std_logic_vector(DEVICES-1 downto 0);

      DATA_OUT       : out std_logic_vector(DEVICES*CHANNELS*RESOLUTION-1 downto 0);
      FCO_OUT        : out std_logic_vector(DEVICES*RESOLUTION-1 downto 0);
      DATA_VALID_OUT : out std_logic_vector(DEVICES-1 downto 0);
      DEBUG          : out std_logic_vector(31 downto 0)

      );
  end component;

  component fifo_32x512
    port (
      Data  : in  std_logic_vector(31 downto 0);
      Clock : in  std_logic;
      WrEn  : in  std_logic;
      RdEn  : in  std_logic;
      Reset : in  std_logic;
      Q     : out std_logic_vector(31 downto 0);
      Empty : out std_logic;
      Full  : out std_logic);
  end component;

  component dqsinput
    port (
      clk_0        : in  std_logic;
      clk_1        : in  std_logic;
      clkdiv_reset : in  std_logic;
      eclk         : in  std_logic;
      reset_0      : in  std_logic;
      reset_1      : in  std_logic;
      sclk         : out std_logic;
      datain_0     : in  std_logic_vector(4 downto 0);
      datain_1     : in  std_logic_vector(4 downto 0);
      q_0          : out std_logic_vector(19 downto 0);
      q_1          : out std_logic_vector(19 downto 0)
      );
  end component;

  component fifo_cdt_200
    port (
      Data    : in  std_logic_vector(59 downto 0);
      WrClock : in  std_logic;
      RdClock : in  std_logic;
      WrEn    : in  std_logic;
      RdEn    : in  std_logic;
      Reset   : in  std_logic;
      RPReset : in  std_logic;
      Q       : out std_logic_vector(59 downto 0);
      Empty   : out std_logic;
      Full    : out std_logic);
  end component;


  component med_ecp3_sfp_sync is
    generic(
      SERDES_NUM    : integer range 0 to 3 := 0;
--     MASTER_CLOCK_SWITCH : integer := c_NO;   --just for debugging, should be NO
      IS_SYNC_SLAVE : integer              := 0  --select slave mode
      );
    port(
      CLK                : in  std_logic;  -- _internal_ 200 MHz reference clock
      SYSCLK             : in  std_logic;  -- 100 MHz main clock net, synchronous to RX clock
      RESET              : in  std_logic;  -- synchronous reset
      CLEAR              : in  std_logic;  -- asynchronous reset
      --Internal Connection TX
      MED_DATA_IN        : in  std_logic_vector(c_DATA_WIDTH-1 downto 0);
      MED_PACKET_NUM_IN  : in  std_logic_vector(c_NUM_WIDTH-1 downto 0);
      MED_DATAREADY_IN   : in  std_logic;
      MED_READ_OUT       : out std_logic                                 := '0';
      --Internal Connection RX
      MED_DATA_OUT       : out std_logic_vector(c_DATA_WIDTH-1 downto 0) := (others => '0');
      MED_PACKET_NUM_OUT : out std_logic_vector(c_NUM_WIDTH-1 downto 0)  := (others => '0');
      MED_DATAREADY_OUT  : out std_logic                                 := '0';
      MED_READ_IN        : in  std_logic;
      CLK_RX_HALF_OUT    : out std_logic                                 := '0';  --received 100 MHz
      CLK_RX_FULL_OUT    : out std_logic                                 := '0';  --received 200 MHz

      --Sync operation
      RX_DLM      : out std_logic                    := '0';
      RX_DLM_WORD : out std_logic_vector(7 downto 0) := x"00";
      TX_DLM      : in  std_logic                    := '0';
      TX_DLM_WORD : in  std_logic_vector(7 downto 0) := x"00";

      --SFP Connection
      SD_RXD_P_IN    : in  std_logic;
      SD_RXD_N_IN    : in  std_logic;
      SD_TXD_P_OUT   : out std_logic;
      SD_TXD_N_OUT   : out std_logic;
      SD_REFCLK_P_IN : in  std_logic;   --not used
      SD_REFCLK_N_IN : in  std_logic;   --not used
      SD_PRSNT_N_IN  : in  std_logic;  -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
      SD_LOS_IN      : in  std_logic;  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
      SD_TXDIS_OUT   : out std_logic                      := '0';  -- SFP disable
      --Control Interface
      SCI_DATA_IN    : in  std_logic_vector(7 downto 0)   := (others => '0');
      SCI_DATA_OUT   : out std_logic_vector(7 downto 0)   := (others => '0');
      SCI_ADDR       : in  std_logic_vector(8 downto 0)   := (others => '0');
      SCI_READ       : in  std_logic                      := '0';
      SCI_WRITE      : in  std_logic                      := '0';
      SCI_ACK        : out std_logic                      := '0';
      SCI_NACK       : out std_logic                      := '0';
      -- Status and control port
      STAT_OP        : out std_logic_vector (15 downto 0);
      CTRL_OP        : in  std_logic_vector (15 downto 0) := (others => '0');
      STAT_DEBUG     : out std_logic_vector (63 downto 0);
      CTRL_DEBUG     : in  std_logic_vector (63 downto 0) := (others => '0')
      );
  end component;


  component input_to_trigger_logic is
    generic(
      INPUTS     : integer range 1 to 32 := 24;
      OUTPUTS    : integer range 1 to 16 := 4
      );
    port(
      CLK        : in std_logic;
      
      INPUT      : in  std_logic_vector(INPUTS-1 downto 0);
      OUTPUT     : out std_logic_vector(OUTPUTS-1 downto 0);

      DATA_IN    : in  std_logic_vector(31 downto 0) := (others => '0');
      DATA_OUT   : out std_logic_vector(31 downto 0);
      WRITE_IN   : in  std_logic := '0';
      READ_IN    : in  std_logic := '0';
      ACK_OUT    : out std_logic;
      NACK_OUT   : out std_logic;
      ADDR_IN    : in  std_logic_vector(15 downto 0) := (others => '0')
      
      );
  end component;

  component input_statistics is
    generic (
      INPUTS : integer range 1 to 32);
    port (
      CLK      : in  std_logic;
      INPUT    : in  std_logic_vector(INPUTS-1 downto 0);
      DATA_IN  : in  std_logic_vector(31 downto 0) := (others => '0');
      DATA_OUT : out std_logic_vector(31 downto 0);
      WRITE_IN : in  std_logic                     := '0';
      READ_IN  : in  std_logic                     := '0';
      ACK_OUT  : out std_logic;
      NACK_OUT : out std_logic;
      ADDR_IN  : in  std_logic_vector(15 downto 0) := (others => '0'));
  end component input_statistics;


component serdes_full_ctc is
   GENERIC (USER_CONFIG_FILE    :  String := "serdes_full_ctc.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (15 downto 0);
    tx_k_ch0    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch0    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch0    :   in std_logic_vector (1 downto 0);
    rxdata_ch0   :   out std_logic_vector (15 downto 0);
    rx_k_ch0   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch0   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch0   :   out std_logic_vector (1 downto 0);
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    ctc_urun_ch0_s   :   out std_logic;
    ctc_orun_ch0_s   :   out std_logic;
    ctc_ins_ch0_s   :   out std_logic;
    ctc_del_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
    hdinp_ch1, hdinn_ch1    :   in std_logic;
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    sci_sel_ch1    :   in std_logic;
    rxiclk_ch1    :   in std_logic;
    txiclk_ch1    :   in std_logic;
    rx_full_clk_ch1   :   out std_logic;
    rx_half_clk_ch1   :   out std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    fpga_rxrefclk_ch1    :   in std_logic;
    txdata_ch1    :   in std_logic_vector (15 downto 0);
    tx_k_ch1    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch1    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch1    :   in std_logic_vector (1 downto 0);
    rxdata_ch1   :   out std_logic_vector (15 downto 0);
    rx_k_ch1   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch1   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch1   :   out std_logic_vector (1 downto 0);
    sb_felb_ch1_c    :   in std_logic;
    sb_felb_rst_ch1_c    :   in std_logic;
    tx_pwrup_ch1_c    :   in std_logic;
    rx_pwrup_ch1_c    :   in std_logic;
    rx_los_low_ch1_s   :   out std_logic;
    lsm_status_ch1_s   :   out std_logic;
    ctc_urun_ch1_s   :   out std_logic;
    ctc_orun_ch1_s   :   out std_logic;
    ctc_ins_ch1_s   :   out std_logic;
    ctc_del_ch1_s   :   out std_logic;
    rx_cdr_lol_ch1_s   :   out std_logic;
    tx_div2_mode_ch1_c   : in std_logic;
    rx_div2_mode_ch1_c   : in std_logic;
-- CH2 --
    hdinp_ch2, hdinn_ch2    :   in std_logic;
    hdoutp_ch2, hdoutn_ch2   :   out std_logic;
    sci_sel_ch2    :   in std_logic;
    rxiclk_ch2    :   in std_logic;
    txiclk_ch2    :   in std_logic;
    rx_full_clk_ch2   :   out std_logic;
    rx_half_clk_ch2   :   out std_logic;
    tx_full_clk_ch2   :   out std_logic;
    tx_half_clk_ch2   :   out std_logic;
    fpga_rxrefclk_ch2    :   in std_logic;
    txdata_ch2    :   in std_logic_vector (15 downto 0);
    tx_k_ch2    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch2    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch2    :   in std_logic_vector (1 downto 0);
    rxdata_ch2   :   out std_logic_vector (15 downto 0);
    rx_k_ch2   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch2   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch2   :   out std_logic_vector (1 downto 0);
    sb_felb_ch2_c    :   in std_logic;
    sb_felb_rst_ch2_c    :   in std_logic;
    tx_pwrup_ch2_c    :   in std_logic;
    rx_pwrup_ch2_c    :   in std_logic;
    rx_los_low_ch2_s   :   out std_logic;
    lsm_status_ch2_s   :   out std_logic;
    ctc_urun_ch2_s   :   out std_logic;
    ctc_orun_ch2_s   :   out std_logic;
    ctc_ins_ch2_s   :   out std_logic;
    ctc_del_ch2_s   :   out std_logic;
    rx_cdr_lol_ch2_s   :   out std_logic;
    tx_div2_mode_ch2_c   : in std_logic;
    rx_div2_mode_ch2_c   : in std_logic;
-- CH3 --
    hdinp_ch3, hdinn_ch3    :   in std_logic;
    hdoutp_ch3, hdoutn_ch3   :   out std_logic;
    sci_sel_ch3    :   in std_logic;
    rxiclk_ch3    :   in std_logic;
    txiclk_ch3    :   in std_logic;
    rx_full_clk_ch3   :   out std_logic;
    rx_half_clk_ch3   :   out std_logic;
    tx_full_clk_ch3   :   out std_logic;
    tx_half_clk_ch3   :   out std_logic;
    fpga_rxrefclk_ch3    :   in std_logic;
    txdata_ch3    :   in std_logic_vector (15 downto 0);
    tx_k_ch3    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch3    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch3    :   in std_logic_vector (1 downto 0);
    rxdata_ch3   :   out std_logic_vector (15 downto 0);
    rx_k_ch3   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch3   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch3   :   out std_logic_vector (1 downto 0);
    sb_felb_ch3_c    :   in std_logic;
    sb_felb_rst_ch3_c    :   in std_logic;
    tx_pwrup_ch3_c    :   in std_logic;
    rx_pwrup_ch3_c    :   in std_logic;
    rx_los_low_ch3_s   :   out std_logic;
    lsm_status_ch3_s   :   out std_logic;
    ctc_urun_ch3_s   :   out std_logic;
    ctc_orun_ch3_s   :   out std_logic;
    ctc_ins_ch3_s   :   out std_logic;
    ctc_del_ch3_s   :   out std_logic;
    rx_cdr_lol_ch3_s   :   out std_logic;
    tx_div2_mode_ch3_c   : in std_logic;
    rx_div2_mode_ch3_c   : in std_logic;
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    tx_sync_qd_c    :   in std_logic;
    refclk2fpga   :   out std_logic;
    rst_n      :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;
  
component serdes_full_noctc is
   GENERIC (USER_CONFIG_FILE    :  String := "serdes_full_noctc.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (15 downto 0);
    tx_k_ch0    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch0    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch0    :   in std_logic_vector (1 downto 0);
    rxdata_ch0   :   out std_logic_vector (15 downto 0);
    rx_k_ch0   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch0   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch0   :   out std_logic_vector (1 downto 0);
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
    hdinp_ch1, hdinn_ch1    :   in std_logic;
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    sci_sel_ch1    :   in std_logic;
    rxiclk_ch1    :   in std_logic;
    txiclk_ch1    :   in std_logic;
    rx_full_clk_ch1   :   out std_logic;
    rx_half_clk_ch1   :   out std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    fpga_rxrefclk_ch1    :   in std_logic;
    txdata_ch1    :   in std_logic_vector (15 downto 0);
    tx_k_ch1    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch1    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch1    :   in std_logic_vector (1 downto 0);
    rxdata_ch1   :   out std_logic_vector (15 downto 0);
    rx_k_ch1   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch1   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch1   :   out std_logic_vector (1 downto 0);
    sb_felb_ch1_c    :   in std_logic;
    sb_felb_rst_ch1_c    :   in std_logic;
    tx_pwrup_ch1_c    :   in std_logic;
    rx_pwrup_ch1_c    :   in std_logic;
    rx_los_low_ch1_s   :   out std_logic;
    lsm_status_ch1_s   :   out std_logic;
    rx_cdr_lol_ch1_s   :   out std_logic;
    tx_div2_mode_ch1_c   : in std_logic;
    rx_div2_mode_ch1_c   : in std_logic;
-- CH2 --
    hdinp_ch2, hdinn_ch2    :   in std_logic;
    hdoutp_ch2, hdoutn_ch2   :   out std_logic;
    sci_sel_ch2    :   in std_logic;
    rxiclk_ch2    :   in std_logic;
    txiclk_ch2    :   in std_logic;
    rx_full_clk_ch2   :   out std_logic;
    rx_half_clk_ch2   :   out std_logic;
    tx_full_clk_ch2   :   out std_logic;
    tx_half_clk_ch2   :   out std_logic;
    fpga_rxrefclk_ch2    :   in std_logic;
    txdata_ch2    :   in std_logic_vector (15 downto 0);
    tx_k_ch2    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch2    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch2    :   in std_logic_vector (1 downto 0);
    rxdata_ch2   :   out std_logic_vector (15 downto 0);
    rx_k_ch2   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch2   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch2   :   out std_logic_vector (1 downto 0);
    sb_felb_ch2_c    :   in std_logic;
    sb_felb_rst_ch2_c    :   in std_logic;
    tx_pwrup_ch2_c    :   in std_logic;
    rx_pwrup_ch2_c    :   in std_logic;
    rx_los_low_ch2_s   :   out std_logic;
    lsm_status_ch2_s   :   out std_logic;
    rx_cdr_lol_ch2_s   :   out std_logic;
    tx_div2_mode_ch2_c   : in std_logic;
    rx_div2_mode_ch2_c   : in std_logic;
-- CH3 --
    hdinp_ch3, hdinn_ch3    :   in std_logic;
    hdoutp_ch3, hdoutn_ch3   :   out std_logic;
    sci_sel_ch3    :   in std_logic;
    rxiclk_ch3    :   in std_logic;
    txiclk_ch3    :   in std_logic;
    rx_full_clk_ch3   :   out std_logic;
    rx_half_clk_ch3   :   out std_logic;
    tx_full_clk_ch3   :   out std_logic;
    tx_half_clk_ch3   :   out std_logic;
    fpga_rxrefclk_ch3    :   in std_logic;
    txdata_ch3    :   in std_logic_vector (15 downto 0);
    tx_k_ch3    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch3    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch3    :   in std_logic_vector (1 downto 0);
    rxdata_ch3   :   out std_logic_vector (15 downto 0);
    rx_k_ch3   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch3   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch3   :   out std_logic_vector (1 downto 0);
    sb_felb_ch3_c    :   in std_logic;
    sb_felb_rst_ch3_c    :   in std_logic;
    tx_pwrup_ch3_c    :   in std_logic;
    rx_pwrup_ch3_c    :   in std_logic;
    rx_los_low_ch3_s   :   out std_logic;
    lsm_status_ch3_s   :   out std_logic;
    rx_cdr_lol_ch3_s   :   out std_logic;
    tx_div2_mode_ch3_c   : in std_logic;
    rx_div2_mode_ch3_c   : in std_logic;
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    tx_sync_qd_c    :   in std_logic;
    refclk2fpga   :   out std_logic;
    rst_n      :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;
  

component serdes_onboard_full is
   GENERIC (USER_CONFIG_FILE    :  String := "serdes_onboard_full.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (15 downto 0);
    tx_k_ch0    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch0    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch0    :   in std_logic_vector (1 downto 0);
    rxdata_ch0   :   out std_logic_vector (15 downto 0);
    rx_k_ch0   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch0   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch0   :   out std_logic_vector (1 downto 0);
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
    hdinp_ch1, hdinn_ch1    :   in std_logic;
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    sci_sel_ch1    :   in std_logic;
    rxiclk_ch1    :   in std_logic;
    txiclk_ch1    :   in std_logic;
    rx_full_clk_ch1   :   out std_logic;
    rx_half_clk_ch1   :   out std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    fpga_rxrefclk_ch1    :   in std_logic;
    txdata_ch1    :   in std_logic_vector (15 downto 0);
    tx_k_ch1    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch1    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch1    :   in std_logic_vector (1 downto 0);
    rxdata_ch1   :   out std_logic_vector (15 downto 0);
    rx_k_ch1   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch1   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch1   :   out std_logic_vector (1 downto 0);
    sb_felb_ch1_c    :   in std_logic;
    sb_felb_rst_ch1_c    :   in std_logic;
    tx_pwrup_ch1_c    :   in std_logic;
    rx_pwrup_ch1_c    :   in std_logic;
    rx_los_low_ch1_s   :   out std_logic;
    lsm_status_ch1_s   :   out std_logic;
    rx_cdr_lol_ch1_s   :   out std_logic;
    tx_div2_mode_ch1_c   : in std_logic;
    rx_div2_mode_ch1_c   : in std_logic;
-- CH2 --
    hdinp_ch2, hdinn_ch2    :   in std_logic;
    hdoutp_ch2, hdoutn_ch2   :   out std_logic;
    sci_sel_ch2    :   in std_logic;
    rxiclk_ch2    :   in std_logic;
    txiclk_ch2    :   in std_logic;
    rx_full_clk_ch2   :   out std_logic;
    rx_half_clk_ch2   :   out std_logic;
    tx_full_clk_ch2   :   out std_logic;
    tx_half_clk_ch2   :   out std_logic;
    fpga_rxrefclk_ch2    :   in std_logic;
    txdata_ch2    :   in std_logic_vector (15 downto 0);
    tx_k_ch2    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch2    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch2    :   in std_logic_vector (1 downto 0);
    rxdata_ch2   :   out std_logic_vector (15 downto 0);
    rx_k_ch2   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch2   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch2   :   out std_logic_vector (1 downto 0);
    sb_felb_ch2_c    :   in std_logic;
    sb_felb_rst_ch2_c    :   in std_logic;
    tx_pwrup_ch2_c    :   in std_logic;
    rx_pwrup_ch2_c    :   in std_logic;
    rx_los_low_ch2_s   :   out std_logic;
    lsm_status_ch2_s   :   out std_logic;
    rx_cdr_lol_ch2_s   :   out std_logic;
    tx_div2_mode_ch2_c   : in std_logic;
    rx_div2_mode_ch2_c   : in std_logic;
-- CH3 --
    hdinp_ch3, hdinn_ch3    :   in std_logic;
    hdoutp_ch3, hdoutn_ch3   :   out std_logic;
    sci_sel_ch3    :   in std_logic;
    rxiclk_ch3    :   in std_logic;
    txiclk_ch3    :   in std_logic;
    rx_full_clk_ch3   :   out std_logic;
    rx_half_clk_ch3   :   out std_logic;
    tx_full_clk_ch3   :   out std_logic;
    tx_half_clk_ch3   :   out std_logic;
    fpga_rxrefclk_ch3    :   in std_logic;
    txdata_ch3    :   in std_logic_vector (15 downto 0);
    tx_k_ch3    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch3    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch3    :   in std_logic_vector (1 downto 0);
    rxdata_ch3   :   out std_logic_vector (15 downto 0);
    rx_k_ch3   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch3   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch3   :   out std_logic_vector (1 downto 0);
    sb_felb_ch3_c    :   in std_logic;
    sb_felb_rst_ch3_c    :   in std_logic;
    tx_pwrup_ch3_c    :   in std_logic;
    rx_pwrup_ch3_c    :   in std_logic;
    rx_los_low_ch3_s   :   out std_logic;
    lsm_status_ch3_s   :   out std_logic;
    rx_cdr_lol_ch3_s   :   out std_logic;
    tx_div2_mode_ch3_c   : in std_logic;
    rx_div2_mode_ch3_c   : in std_logic;
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    tx_sync_qd_c    :   in std_logic;
    refclk2fpga   :   out std_logic;
    rst_n      :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;


component serdes_onboard_full_125 is
   GENERIC (USER_CONFIG_FILE    :  String := "serdes_onboard_full_125.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (15 downto 0);
    tx_k_ch0    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch0    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch0    :   in std_logic_vector (1 downto 0);
    rxdata_ch0   :   out std_logic_vector (15 downto 0);
    rx_k_ch0   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch0   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch0   :   out std_logic_vector (1 downto 0);
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
    hdinp_ch1, hdinn_ch1    :   in std_logic;
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    sci_sel_ch1    :   in std_logic;
    rxiclk_ch1    :   in std_logic;
    txiclk_ch1    :   in std_logic;
    rx_full_clk_ch1   :   out std_logic;
    rx_half_clk_ch1   :   out std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    fpga_rxrefclk_ch1    :   in std_logic;
    txdata_ch1    :   in std_logic_vector (15 downto 0);
    tx_k_ch1    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch1    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch1    :   in std_logic_vector (1 downto 0);
    rxdata_ch1   :   out std_logic_vector (15 downto 0);
    rx_k_ch1   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch1   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch1   :   out std_logic_vector (1 downto 0);
    sb_felb_ch1_c    :   in std_logic;
    sb_felb_rst_ch1_c    :   in std_logic;
    tx_pwrup_ch1_c    :   in std_logic;
    rx_pwrup_ch1_c    :   in std_logic;
    rx_los_low_ch1_s   :   out std_logic;
    lsm_status_ch1_s   :   out std_logic;
    rx_cdr_lol_ch1_s   :   out std_logic;
    tx_div2_mode_ch1_c   : in std_logic;
    rx_div2_mode_ch1_c   : in std_logic;
-- CH2 --
    hdinp_ch2, hdinn_ch2    :   in std_logic;
    hdoutp_ch2, hdoutn_ch2   :   out std_logic;
    sci_sel_ch2    :   in std_logic;
    rxiclk_ch2    :   in std_logic;
    txiclk_ch2    :   in std_logic;
    rx_full_clk_ch2   :   out std_logic;
    rx_half_clk_ch2   :   out std_logic;
    tx_full_clk_ch2   :   out std_logic;
    tx_half_clk_ch2   :   out std_logic;
    fpga_rxrefclk_ch2    :   in std_logic;
    txdata_ch2    :   in std_logic_vector (15 downto 0);
    tx_k_ch2    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch2    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch2    :   in std_logic_vector (1 downto 0);
    rxdata_ch2   :   out std_logic_vector (15 downto 0);
    rx_k_ch2   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch2   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch2   :   out std_logic_vector (1 downto 0);
    sb_felb_ch2_c    :   in std_logic;
    sb_felb_rst_ch2_c    :   in std_logic;
    tx_pwrup_ch2_c    :   in std_logic;
    rx_pwrup_ch2_c    :   in std_logic;
    rx_los_low_ch2_s   :   out std_logic;
    lsm_status_ch2_s   :   out std_logic;
    rx_cdr_lol_ch2_s   :   out std_logic;
    tx_div2_mode_ch2_c   : in std_logic;
    rx_div2_mode_ch2_c   : in std_logic;
-- CH3 --
    hdinp_ch3, hdinn_ch3    :   in std_logic;
    hdoutp_ch3, hdoutn_ch3   :   out std_logic;
    sci_sel_ch3    :   in std_logic;
    rxiclk_ch3    :   in std_logic;
    txiclk_ch3    :   in std_logic;
    rx_full_clk_ch3   :   out std_logic;
    rx_half_clk_ch3   :   out std_logic;
    tx_full_clk_ch3   :   out std_logic;
    tx_half_clk_ch3   :   out std_logic;
    fpga_rxrefclk_ch3    :   in std_logic;
    txdata_ch3    :   in std_logic_vector (15 downto 0);
    tx_k_ch3    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch3    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch3    :   in std_logic_vector (1 downto 0);
    rxdata_ch3   :   out std_logic_vector (15 downto 0);
    rx_k_ch3   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch3   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch3   :   out std_logic_vector (1 downto 0);
    sb_felb_ch3_c    :   in std_logic;
    sb_felb_rst_ch3_c    :   in std_logic;
    tx_pwrup_ch3_c    :   in std_logic;
    rx_pwrup_ch3_c    :   in std_logic;
    rx_los_low_ch3_s   :   out std_logic;
    lsm_status_ch3_s   :   out std_logic;
    rx_cdr_lol_ch3_s   :   out std_logic;
    tx_div2_mode_ch3_c   : in std_logic;
    rx_div2_mode_ch3_c   : in std_logic;
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    tx_sync_qd_c    :   in std_logic;
    refclk2fpga   :   out std_logic;
    rst_n      :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;


component serdes_onboard_full_ctc is
   GENERIC (USER_CONFIG_FILE    :  String := "serdes_onboard_full_ctc.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (15 downto 0);
    tx_k_ch0    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch0    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch0    :   in std_logic_vector (1 downto 0);
    rxdata_ch0   :   out std_logic_vector (15 downto 0);
    rx_k_ch0   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch0   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch0   :   out std_logic_vector (1 downto 0);
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    ctc_urun_ch0_s   :   out std_logic;
    ctc_orun_ch0_s   :   out std_logic;
    ctc_ins_ch0_s   :   out std_logic;
    ctc_del_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
    hdinp_ch1, hdinn_ch1    :   in std_logic;
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    sci_sel_ch1    :   in std_logic;
    rxiclk_ch1    :   in std_logic;
    txiclk_ch1    :   in std_logic;
    rx_full_clk_ch1   :   out std_logic;
    rx_half_clk_ch1   :   out std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    fpga_rxrefclk_ch1    :   in std_logic;
    txdata_ch1    :   in std_logic_vector (15 downto 0);
    tx_k_ch1    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch1    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch1    :   in std_logic_vector (1 downto 0);
    rxdata_ch1   :   out std_logic_vector (15 downto 0);
    rx_k_ch1   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch1   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch1   :   out std_logic_vector (1 downto 0);
    sb_felb_ch1_c    :   in std_logic;
    sb_felb_rst_ch1_c    :   in std_logic;
    tx_pwrup_ch1_c    :   in std_logic;
    rx_pwrup_ch1_c    :   in std_logic;
    rx_los_low_ch1_s   :   out std_logic;
    lsm_status_ch1_s   :   out std_logic;
    ctc_urun_ch1_s   :   out std_logic;
    ctc_orun_ch1_s   :   out std_logic;
    ctc_ins_ch1_s   :   out std_logic;
    ctc_del_ch1_s   :   out std_logic;
    rx_cdr_lol_ch1_s   :   out std_logic;
    tx_div2_mode_ch1_c   : in std_logic;
    rx_div2_mode_ch1_c   : in std_logic;
-- CH2 --
    hdinp_ch2, hdinn_ch2    :   in std_logic;
    hdoutp_ch2, hdoutn_ch2   :   out std_logic;
    sci_sel_ch2    :   in std_logic;
    rxiclk_ch2    :   in std_logic;
    txiclk_ch2    :   in std_logic;
    rx_full_clk_ch2   :   out std_logic;
    rx_half_clk_ch2   :   out std_logic;
    tx_full_clk_ch2   :   out std_logic;
    tx_half_clk_ch2   :   out std_logic;
    fpga_rxrefclk_ch2    :   in std_logic;
    txdata_ch2    :   in std_logic_vector (15 downto 0);
    tx_k_ch2    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch2    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch2    :   in std_logic_vector (1 downto 0);
    rxdata_ch2   :   out std_logic_vector (15 downto 0);
    rx_k_ch2   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch2   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch2   :   out std_logic_vector (1 downto 0);
    sb_felb_ch2_c    :   in std_logic;
    sb_felb_rst_ch2_c    :   in std_logic;
    tx_pwrup_ch2_c    :   in std_logic;
    rx_pwrup_ch2_c    :   in std_logic;
    rx_los_low_ch2_s   :   out std_logic;
    lsm_status_ch2_s   :   out std_logic;
    ctc_urun_ch2_s   :   out std_logic;
    ctc_orun_ch2_s   :   out std_logic;
    ctc_ins_ch2_s   :   out std_logic;
    ctc_del_ch2_s   :   out std_logic;
    rx_cdr_lol_ch2_s   :   out std_logic;
    tx_div2_mode_ch2_c   : in std_logic;
    rx_div2_mode_ch2_c   : in std_logic;
-- CH3 --
    hdinp_ch3, hdinn_ch3    :   in std_logic;
    hdoutp_ch3, hdoutn_ch3   :   out std_logic;
    sci_sel_ch3    :   in std_logic;
    rxiclk_ch3    :   in std_logic;
    txiclk_ch3    :   in std_logic;
    rx_full_clk_ch3   :   out std_logic;
    rx_half_clk_ch3   :   out std_logic;
    tx_full_clk_ch3   :   out std_logic;
    tx_half_clk_ch3   :   out std_logic;
    fpga_rxrefclk_ch3    :   in std_logic;
    txdata_ch3    :   in std_logic_vector (15 downto 0);
    tx_k_ch3    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch3    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch3    :   in std_logic_vector (1 downto 0);
    rxdata_ch3   :   out std_logic_vector (15 downto 0);
    rx_k_ch3   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch3   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch3   :   out std_logic_vector (1 downto 0);
    sb_felb_ch3_c    :   in std_logic;
    sb_felb_rst_ch3_c    :   in std_logic;
    tx_pwrup_ch3_c    :   in std_logic;
    rx_pwrup_ch3_c    :   in std_logic;
    rx_los_low_ch3_s   :   out std_logic;
    lsm_status_ch3_s   :   out std_logic;
    ctc_urun_ch3_s   :   out std_logic;
    ctc_orun_ch3_s   :   out std_logic;
    ctc_ins_ch3_s   :   out std_logic;
    ctc_del_ch3_s   :   out std_logic;
    rx_cdr_lol_ch3_s   :   out std_logic;
    tx_div2_mode_ch3_c   : in std_logic;
    rx_div2_mode_ch3_c   : in std_logic;
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    tx_sync_qd_c    :   in std_logic;
    refclk2fpga   :   out std_logic;
    rst_n      :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;


component serdes_sync_0 is
   GENERIC (USER_CONFIG_FILE    :  String := "serdes_sync_0.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (7 downto 0);
    tx_k_ch0    :   in std_logic;
    tx_force_disp_ch0    :   in std_logic;
    tx_disp_sel_ch0    :   in std_logic;
    rxdata_ch0   :   out std_logic_vector (7 downto 0);
    rx_k_ch0   :   out std_logic;
    rx_disp_err_ch0   :   out std_logic;
    rx_cv_err_ch0   :   out std_logic;
    rx_serdes_rst_ch0_c    :   in std_logic;
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pcs_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pcs_rst_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
-- CH2 --
-- CH3 --
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    rst_qd_c    :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;


component serdes_sync_125_0 is
   GENERIC (USER_CONFIG_FILE    :  String := "serdes_sync_125_0.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (7 downto 0);
    tx_k_ch0    :   in std_logic;
    tx_force_disp_ch0    :   in std_logic;
    tx_disp_sel_ch0    :   in std_logic;
    rxdata_ch0   :   out std_logic_vector (7 downto 0);
    rx_k_ch0   :   out std_logic;
    rx_disp_err_ch0   :   out std_logic;
    rx_cv_err_ch0   :   out std_logic;
    rx_serdes_rst_ch0_c    :   in std_logic;
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pcs_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pcs_rst_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
-- CH2 --
-- CH3 --
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    rst_qd_c    :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;


component sfp_0_200_ctc is
   GENERIC (USER_CONFIG_FILE    :  String := "sfp_0_200_ctc.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (15 downto 0);
    tx_k_ch0    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch0    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch0    :   in std_logic_vector (1 downto 0);
    rxdata_ch0   :   out std_logic_vector (15 downto 0);
    rx_k_ch0   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch0   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch0   :   out std_logic_vector (1 downto 0);
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    ctc_urun_ch0_s   :   out std_logic;
    ctc_orun_ch0_s   :   out std_logic;
    ctc_ins_ch0_s   :   out std_logic;
    ctc_del_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
-- CH2 --
-- CH3 --
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    rst_n      :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;


component sfp_0_200_int is
   generic (USER_CONFIG_FILE    :  String := "sfp_0_200_int.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (15 downto 0);
    tx_k_ch0    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch0    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch0    :   in std_logic_vector (1 downto 0);
    rxdata_ch0   :   out std_logic_vector (15 downto 0);
    rx_k_ch0   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch0   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch0   :   out std_logic_vector (1 downto 0);
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
-- CH2 --
-- CH3 --
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    rst_n      :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;


component sfp_1_125_int is
   GENERIC (USER_CONFIG_FILE    :  String := "sfp_1_125_int.txt");
 port (
------------------
-- CH0 --
-- CH1 --
    hdinp_ch1, hdinn_ch1    :   in std_logic;
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    sci_sel_ch1    :   in std_logic;
    rxiclk_ch1    :   in std_logic;
    txiclk_ch1    :   in std_logic;
    rx_full_clk_ch1   :   out std_logic;
    rx_half_clk_ch1   :   out std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    fpga_rxrefclk_ch1    :   in std_logic;
    txdata_ch1    :   in std_logic_vector (15 downto 0);
    tx_k_ch1    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch1    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch1    :   in std_logic_vector (1 downto 0);
    rxdata_ch1   :   out std_logic_vector (15 downto 0);
    rx_k_ch1   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch1   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch1   :   out std_logic_vector (1 downto 0);
    sb_felb_ch1_c    :   in std_logic;
    sb_felb_rst_ch1_c    :   in std_logic;
    tx_pwrup_ch1_c    :   in std_logic;
    rx_pwrup_ch1_c    :   in std_logic;
    rx_los_low_ch1_s   :   out std_logic;
    lsm_status_ch1_s   :   out std_logic;
    rx_cdr_lol_ch1_s   :   out std_logic;
    tx_div2_mode_ch1_c   : in std_logic;
    rx_div2_mode_ch1_c   : in std_logic;
-- CH2 --
-- CH3 --
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    rst_n      :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;


component sfp_1_200_int is
   GENERIC (USER_CONFIG_FILE    :  String := "sfp_1_200_int.txt");
 port (
------------------
-- CH0 --
-- CH1 --
    hdinp_ch1, hdinn_ch1    :   in std_logic;
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    sci_sel_ch1    :   in std_logic;
    rxiclk_ch1    :   in std_logic;
    txiclk_ch1    :   in std_logic;
    rx_full_clk_ch1   :   out std_logic;
    rx_half_clk_ch1   :   out std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    fpga_rxrefclk_ch1    :   in std_logic;
    txdata_ch1    :   in std_logic_vector (15 downto 0);
    tx_k_ch1    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch1    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch1    :   in std_logic_vector (1 downto 0);
    rxdata_ch1   :   out std_logic_vector (15 downto 0);
    rx_k_ch1   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch1   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch1   :   out std_logic_vector (1 downto 0);
    sb_felb_ch1_c    :   in std_logic;
    sb_felb_rst_ch1_c    :   in std_logic;
    tx_pwrup_ch1_c    :   in std_logic;
    rx_pwrup_ch1_c    :   in std_logic;
    rx_los_low_ch1_s   :   out std_logic;
    lsm_status_ch1_s   :   out std_logic;
    rx_cdr_lol_ch1_s   :   out std_logic;
    tx_div2_mode_ch1_c   : in std_logic;
    rx_div2_mode_ch1_c   : in std_logic;
-- CH2 --
-- CH3 --
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    rst_n      :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;


component sfp_ctc_0_200_int is
   GENERIC (USER_CONFIG_FILE    :  String := "sfp_ctc_0_200_int.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (15 downto 0);
    tx_k_ch0    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch0    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch0    :   in std_logic_vector (1 downto 0);
    rxdata_ch0   :   out std_logic_vector (15 downto 0);
    rx_k_ch0   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch0   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch0   :   out std_logic_vector (1 downto 0);
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    ctc_urun_ch0_s   :   out std_logic;
    ctc_orun_ch0_s   :   out std_logic;
    ctc_ins_ch0_s   :   out std_logic;
    ctc_del_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
-- CH2 --
-- CH3 --
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    rst_n      :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;


end package;
