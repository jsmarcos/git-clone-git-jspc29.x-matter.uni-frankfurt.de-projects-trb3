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

  --already in trb_net_components
--   component pll_in200_out100
--     port (
--       CLK   : in  std_logic;
--       RESET : in  std_logic := '0';
--       CLKOP : out std_logic;            --100 MHz
--       CLKOK : out std_logic;            --200 MHz, bypass
--       LOCK  : out std_logic
--       );
--   end component;

  component pll_in125_out125
    port (
      CLK   : in  std_logic;
      CLKOP : out std_logic;            --125 MHz
      CLKOK : out std_logic;            --125 MHz, bypass
      LOCK  : out std_logic
      );
  end component;

  component TDC
    generic (
      CHANNEL_NUMBER : integer range 2 to 65;
      CONTROL_REG_NR : integer range 0 to 6);
    port (
      RESET                 : in  std_logic;
      CLK_TDC               : in  std_logic;
      CLK_READOUT           : in  std_logic;
      REFERENCE_TIME        : in  std_logic;
      HIT_IN                : in  std_logic_vector(CHANNEL_NUMBER-1 downto 1);
      TRG_WIN_PRE           : in  std_logic_vector(10 downto 0);
      TRG_WIN_POST          : in  std_logic_vector(10 downto 0);
      TRG_DATA_VALID_IN     : in  std_logic;
      VALID_TIMING_TRG_IN   : in  std_logic;
      VALID_NOTIMING_TRG_IN : in  std_logic;
      INVALID_TRG_IN        : in  std_logic;
      TMGTRG_TIMEOUT_IN     : in  std_logic;
      SPIKE_DETECTED_IN     : in  std_logic;
      MULTI_TMG_TRG_IN      : in  std_logic;
      SPURIOUS_TRG_IN       : in  std_logic;
      TRG_NUMBER_IN         : in  std_logic_vector(15 downto 0);
      TRG_CODE_IN           : in  std_logic_vector(7 downto 0);
      TRG_INFORMATION_IN    : in  std_logic_vector(23 downto 0);
      TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
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
      LHB_READ_EN_IN        : in  std_logic;
      LHB_WRITE_EN_IN       : in  std_logic;
      LHB_ADDR_IN           : in  std_logic_vector(6 downto 0);
      LHB_DATA_OUT          : out std_logic_vector(31 downto 0);
      LHB_DATAREADY_OUT     : out std_logic;
      LHB_UNKNOWN_ADDR_OUT  : out std_logic;
      LOGIC_ANALYSER_OUT    : out std_logic_vector(15 downto 0);
      CONTROL_REG_IN        : in  std_logic_vector(32*CONTROL_REG_NR-1 downto 0));
  end component;
  
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
      CHANNEL_ID : integer range 0 to 64);
    port (
      RESET_200               : in  std_logic;
      RESET_100               : in  std_logic;
      RESET_COUNTERS          : in  std_logic;
      CLK_200                 : in  std_logic;
      CLK_100                 : in  std_logic;
      HIT_IN                  : in  std_logic;
      TRIGGER_WIN_END_IN      : in  std_logic;
      READ_EN_IN              : in  std_logic;
      FIFO_DATA_OUT           : out std_logic_vector(35 downto 0);
      FIFO_WCNT_OUT           : out unsigned(7 downto 0);
      FIFO_EMPTY_OUT          : out std_logic;
      FIFO_FULL_OUT           : out std_logic;
      FIFO_ALMOST_FULL_OUT    : out std_logic;
      COARSE_COUNTER_IN       : in  std_logic_vector(10 downto 0);
      EPOCH_COUNTER_IN        : in  std_logic_vector(27 downto 0);
--      DATA_FINISHED_IN        : in  std_logic;
      LOST_HIT_NUMBER         : out std_logic_vector(23 downto 0);
      HIT_DETECT_NUMBER       : out std_logic_vector(23 downto 0);
      ENCODER_START_NUMBER    : out std_logic_vector(23 downto 0);
      ENCODER_FINISHED_NUMBER : out std_logic_vector(23 downto 0);
      Channel_DEBUG           : out std_logic_vector(31 downto 0));
  end component;
  
  component Channel_200
    generic (
      CHANNEL_ID : integer range 0 to 64);
    port (
      CLK_200              : in  std_logic;
      RESET_200            : in  std_logic;
      CLK_100              : in  std_logic;
      RESET_100            : in  std_logic;
      HIT_IN               : in  std_logic;
      TRIGGER_WIN_END_IN   : in  std_logic;
      EPOCH_COUNTER_IN     : in  std_logic_vector(27 downto 0);
--      DATA_FINISHED_IN     : in  std_logic;
      COARSE_COUNTER_IN    : in  std_logic_vector(10 downto 0);
      READ_EN_IN           : in  std_logic;
      FIFO_DATA_OUT        : out std_logic_vector(35 downto 0);
      FIFO_WCNT_OUT        : out unsigned(7 downto 0);
      FIFO_EMPTY_OUT       : out std_logic;
      FIFO_FULL_OUT        : out std_logic;
      FIFO_ALMOST_FULL_OUT : out std_logic;
      ENCODER_START_OUT    : out std_logic;
      ENCODER_FINISHED_OUT : out std_logic);
  end component;
  
  component Readout
    generic (
      CHANNEL_NUMBER : integer range 2 to 65);
    port (
      CLK_200                  : in  std_logic;
      RESET_200                : in  std_logic;
      CLK_100                  : in  std_logic;
      RESET_100                : in  std_logic;
      RESET_COUNTERS           : in  std_logic;
      REFERENCE_TIME           : in  std_logic;
      TRIGGER_TIME_IN          : in  std_logic_vector(38 downto 0);
      TRG_WIN_PRE              : in  std_logic_vector(10 downto 0);
      TRG_WIN_POST             : in  std_logic_vector(10 downto 0);
      DEBUG_MODE_EN_IN         : in  std_logic;
      TRIGGER_WIN_EN_IN        : in  std_logic;
      CH_DATA_IN               : in  std_logic_vector_array_36(0 to CHANNEL_NUMBER);
      CH_WCNT_IN               : in  unsigned_array_8(0 to CHANNEL_NUMBER-1);
      CH_EMPTY_IN              : in  std_logic_vector(CHANNEL_NUMBER downto 0);
      CH_FULL_IN               : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
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
      TRG_RELEASE_OUT          : out std_logic;
      TRG_STATUSBIT_OUT        : out std_logic_vector(31 downto 0);
      DATA_OUT                 : out std_logic_vector(31 downto 0);
      DATA_WRITE_OUT           : out std_logic;
      DATA_FINISHED_OUT        : out std_logic;
      READ_EN_OUT              : out std_logic_vector(CHANNEL_NUMBER-1 downto 0);
      TRIGGER_WIN_END_OUT      : out std_logic;
      STATUS_REGISTERS_BUS_OUT : out std_logic_vector_array_32(0 to 18);
      READOUT_DEBUG            : out std_logic_vector(31 downto 0));
  end component;
  
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



end package;
