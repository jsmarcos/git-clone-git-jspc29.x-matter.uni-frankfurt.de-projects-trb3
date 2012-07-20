library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.trb_net_std.all;

package trb3_components is



component pll_in200_out100
  port (
    CLK: in std_logic; 
    CLKOP: out std_logic; --100 MHz
    CLKOK: out std_logic; --200 MHz, bypass
    LOCK: out std_logic
    );
  end component;

component pll_in125_out125
  port (
    CLK: in std_logic; 
    CLKOP: out std_logic; --125 MHz
    CLKOK: out std_logic; --125 MHz, bypass
    LOCK: out std_logic
    );
  end component;

component TDC
  generic (
    CHANNEL_NUMBER : integer range 0 to 64;
    STATUS_REG_NR  : integer range 0 to 6;
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
    TDC_DEBUG             : out std_logic_vector(32*2**STATUS_REG_NR-1 downto 0);
    LOGIC_ANALYSER_OUT    : out std_logic_vector(15 downto 0);
    CONTROL_REG_IN        : in  std_logic_vector(32*2**CONTROL_REG_NR-1 downto 0));
end component;

component Reference_Channel
  generic (
    CHANNEL_ID : integer range 0 to 0);
  port (
    RESET_WR             : in  std_logic;
    RESET_RD             : in  std_logic;
    CLK_WR               : in  std_logic;
    CLK_RD               : in  std_logic;
    HIT_IN               : in  std_logic;
    READ_EN_IN           : in  std_logic;
    VALID_TMG_TRG_IN     : in  std_logic;
    SPIKE_DETECTED_IN    : in  std_logic;
    MULTI_TMG_TRG_IN     : in  std_logic;
    FIFO_DATA_OUT        : out std_logic_vector(31 downto 0);
    FIFO_EMPTY_OUT       : out std_logic;
    FIFO_FULL_OUT        : out std_logic;
    FIFO_ALMOST_FULL_OUT : out std_logic;
    COARSE_COUNTER_IN    : in  std_logic_vector(10 downto 0);
    TRIGGER_TIME_OUT     : out std_logic_vector(10 downto 0);
    REF_DEBUG_OUT        : out std_logic_vector(31 downto 0));
end component;

component Channel
  generic (
    CHANNEL_ID : integer range 1 to 65);
  port (
    RESET_WR             : in  std_logic;
    RESET_RD             : in  std_logic;
    CLK_WR               : in  std_logic;
    CLK_RD               : in  std_logic;
    HIT_IN               : in  std_logic;
    READ_EN_IN           : in  std_logic;
    FIFO_DATA_OUT        : out std_logic_vector(31 downto 0);
    FIFO_EMPTY_OUT       : out std_logic;
    FIFO_FULL_OUT        : out std_logic;
    FIFO_ALMOST_FULL_OUT : out std_logic;
    COARSE_COUNTER_IN    : in  std_logic_vector(10 downto 0);
    LOST_HIT_NUMBER      : out std_logic_vector(23 downto 0);
    HIT_DETECT_NUMBER    : out std_logic_vector(23 downto 0);
    ENCODER_START_NUMBER : out std_logic_vector(23 downto 0);
    FIFO_WR_NUMBER       : out std_logic_vector(23 downto 0);
    Channel_DEBUG_01     : out std_logic_vector(31 downto 0));
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

component Encoder_304_Bit
  port (
    RESET           : in  std_logic;
    CLK             : in  std_logic;
    START_IN        : in  std_logic;
    THERMOCODE_IN   : in  std_logic_vector(303 downto 0);
    FINISHED_OUT    : out std_logic;
    BINARY_CODE_OUT : out std_logic_vector(9 downto 0);
    ENCODER_DEBUG   : out std_logic_vector(31 downto 0));
end component;

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

component ROM_Encoder
  port (
    Address    : in  std_logic_vector(9 downto 0);
    OutClock   : in  std_logic;
    OutClockEn : in  std_logic;
    Reset      : in  std_logic;
    Q          : out std_logic_vector(7 downto 0));
end component;

component ROM_FIFO
  port (
    Address    : in  std_logic_vector(7 downto 0);
    OutClock   : in  std_logic;
    OutClockEn : in  std_logic;
    Reset      : in  std_logic;
    Q          : out std_logic_vector(3 downto 0));
end component;

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
  
end package;
