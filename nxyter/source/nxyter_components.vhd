library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package nxyter_components is

-------------------------------------------------------------------------------
-- TRBNet interfaces
-------------------------------------------------------------------------------

  component nXyter_FEE_board
    generic (
      BOARD_ID : std_logic_vector(15 downto 0));
    port (
      CLK_IN                     : in    std_logic;
      RESET_IN                   : in    std_logic;
      CLK_NX_MAIN_IN             : in    std_logic;
      CLK_ADC_IN                 : in    std_logic;
      PLL_NX_CLK_LOCK_IN         : in    std_logic;
      PLL_ADC_DCLK_LOCK_IN       : in    std_logic;
      NX_DATA_CLK_TEST_IN        : in    std_logic;
      TRIGGER_OUT                : out   std_logic;
      I2C_SDA_INOUT              : inout std_logic;
      I2C_SCL_INOUT              : inout std_logic;
      I2C_SM_RESET_OUT           : out   std_logic;
      I2C_REG_RESET_OUT          : out   std_logic;
      SPI_SCLK_OUT               : out   std_logic;
      SPI_SDIO_INOUT             : inout std_logic;
      SPI_CSB_OUT                : out   std_logic;
      NX_DATA_CLK_IN             : in    std_logic;
      NX_TIMESTAMP_IN            : in    std_logic_vector (7 downto 0);
      NX_RESET_OUT               : out   std_logic;
      NX_TESTPULSE_OUT           : out   std_logic;
      NX_TIMESTAMP_TRIGGER_OUT   : out   std_logic;
      ADC_FCLK_IN                : in    std_logic_vector(1 downto 0);
      ADC_DCLK_IN                : in    std_logic_vector(1 downto 0);
      ADC_SAMPLE_CLK_OUT         : out   std_logic;
      ADC_A_IN                   : in    std_logic_vector(1 downto 0);
      ADC_B_IN                   : in    std_logic_vector(1 downto 0);
      ADC_NX_IN                  : in    std_logic_vector(1 downto 0);
      ADC_D_IN                   : in    std_logic_vector(1 downto 0);
      TIMING_TRIGGER_IN          : in    std_logic;
      LVL1_TRG_DATA_VALID_IN     : in    std_logic;
      LVL1_VALID_TIMING_TRG_IN   : in    std_logic;
      LVL1_VALID_NOTIMING_TRG_IN : in    std_logic;
      LVL1_INVALID_TRG_IN        : in    std_logic;
      LVL1_TRG_TYPE_IN           : in    std_logic_vector(3 downto 0);
      LVL1_TRG_NUMBER_IN         : in    std_logic_vector(15 downto 0);
      LVL1_TRG_CODE_IN           : in    std_logic_vector(7 downto 0);
      LVL1_TRG_INFORMATION_IN    : in    std_logic_vector(23 downto 0);
      LVL1_INT_TRG_NUMBER_IN     : in    std_logic_vector(15 downto 0);
      FEE_TRG_RELEASE_OUT        : out   std_logic;
      FEE_TRG_STATUSBITS_OUT     : out   std_logic_vector(31 downto 0);
      FEE_DATA_OUT               : out   std_logic_vector(31 downto 0);
      FEE_DATA_WRITE_OUT         : out   std_logic;
      FEE_DATA_FINISHED_OUT      : out   std_logic;
      FEE_DATA_ALMOST_FULL_IN    : in    std_logic;
      REGIO_ADDR_IN              : in    std_logic_vector(15 downto 0);
      REGIO_DATA_IN              : in    std_logic_vector(31 downto 0);
      REGIO_DATA_OUT             : out   std_logic_vector(31 downto 0);
      REGIO_READ_ENABLE_IN       : in    std_logic;
      REGIO_WRITE_ENABLE_IN      : in    std_logic;
      REGIO_TIMEOUT_IN           : in    std_logic;
      REGIO_DATAREADY_OUT        : out   std_logic;
      REGIO_WRITE_ACK_OUT        : out   std_logic;
      REGIO_NO_MORE_DATA_OUT     : out   std_logic;
      REGIO_UNKNOWN_ADDR_OUT     : out   std_logic;
      DEBUG_LINE_OUT             : out   std_logic_vector(15 downto 0)
      );
  end component;
  
-------------------------------------------------------------------------------
-- nXyter I2C Interface
-------------------------------------------------------------------------------


component nx_i2c_master
  generic (
    I2C_SPEED : unsigned(11 downto 0)
    );
  port (
    CLK_IN               : in    std_logic;
    RESET_IN             : in    std_logic;
    SDA_INOUT            : inout std_logic;
    SCL_INOUT            : inout std_logic;
    INTERNAL_COMMAND_IN  : in    std_logic_vector(31 downto 0);
    COMMAND_BUSY_OUT     : out   std_logic;
    I2C_DATA_OUT         : out   std_logic_vector(31 downto 0);
    I2C_LOCK_IN          : in    std_logic;
    SLV_READ_IN          : in    std_logic;
    SLV_WRITE_IN         : in    std_logic;
    SLV_DATA_OUT         : out   std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in    std_logic_vector(31 downto 0);
    SLV_ACK_OUT          : out   std_logic;
    SLV_NO_MORE_DATA_OUT : out   std_logic;
    SLV_UNKNOWN_ADDR_OUT : out   std_logic;
    DEBUG_OUT            : out   std_logic_vector(15 downto 0)
    );
end component;

component nx_i2c_startstop
  generic (
    I2C_SPEED : unsigned(11 downto 0)
    );
  port (
    CLK_IN            : in  std_logic;
    RESET_IN          : in  std_logic;
    START_IN          : in  std_logic;  -- Start Sequence
    SELECT_IN         : in  std_logic;  -- '1' -> Start, '0'-> Stop
    SEQUENCE_DONE_OUT : out std_logic;
    SDA_OUT           : out std_logic;
    SCL_OUT           : out std_logic;
    NREADY_OUT        : out std_logic
    );
end component;

component nx_i2c_sendbyte
  generic (
    I2C_SPEED : unsigned(11 downto 0)
    );
  port (
    CLK_IN            : in  std_logic;
    RESET_IN          : in  std_logic;
    START_IN          : in  std_logic;
    BYTE_IN           : in  std_logic_vector(7 downto 0);
    SEQUENCE_DONE_OUT : out std_logic;
    SDA_OUT           : out std_logic;
    SCL_OUT           : out std_logic;
    SDA_IN            : in  std_logic;
    SCL_IN            : in  std_logic;
    ACK_OUT           : out std_logic
    );
end component;

component nx_i2c_readbyte
  generic (
    I2C_SPEED : unsigned(11 downto 0)
    );
  port (
    CLK_IN            : in  std_logic;
    RESET_IN          : in  std_logic;
    START_IN          : in  std_logic;
    BYTE_OUT          : out std_logic_vector(7 downto 0);
    SEQUENCE_DONE_OUT : out std_logic;
    SDA_OUT           : out std_logic;
    SCL_OUT           : out std_logic;
    SDA_IN            : in  std_logic
    );
end component;

-------------------------------------------------------------------------------
-- ADC SPI Interface
-------------------------------------------------------------------------------

component adc_spi_master
  generic (
    SPI_SPEED : unsigned(7 downto 0)
    );
  port (
    CLK_IN               : in    std_logic;
    RESET_IN             : in    std_logic;
    SCLK_OUT             : out   std_logic;
    SDIO_INOUT           : inout std_logic;
    CSB_OUT              : out   std_logic;
    INTERNAL_COMMAND_IN  : in    std_logic_vector(31 downto 0);
    COMMAND_BUSY_OUT     : out   std_logic;
    SPI_DATA_OUT         : out   std_logic_vector(31 downto 0);
    SPI_LOCK_IN          : in    std_logic;
    SLV_READ_IN          : in    std_logic;
    SLV_WRITE_IN         : in    std_logic;
    SLV_DATA_OUT         : out   std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in    std_logic_vector(31 downto 0);
    SLV_ACK_OUT          : out   std_logic;
    SLV_NO_MORE_DATA_OUT : out   std_logic;
    SLV_UNKNOWN_ADDR_OUT : out   std_logic;
    DEBUG_OUT            : out   std_logic_vector(15 downto 0)
    );
end component;

component adc_spi_sendbyte
  generic (
    SPI_SPEED : unsigned(7 downto 0)
    );
  port (
    CLK_IN            : in  std_logic;
    RESET_IN          : in  std_logic;
    START_IN          : in  std_logic;
    BYTE_IN           : in  std_logic_vector(7 downto 0);
    SEQUENCE_DONE_OUT : out std_logic;
    SCLK_OUT          : out std_logic;
    SDIO_OUT          : out std_logic
    );
end component;

component adc_spi_readbyte
  generic (
    SPI_SPEED : unsigned(7 downto 0)
    );
  port (
    CLK_IN            : in  std_logic;
    RESET_IN          : in  std_logic;
    START_IN          : in  std_logic;
    BYTE_OUT          : out std_logic_vector(7 downto 0);
    SEQUENCE_DONE_OUT : out std_logic;
    SDIO_IN           : in  std_logic;
    SCLK_OUT          : out std_logic
    );
end component;

-------------------------------------------------------------------------------
-- TRBNet Registers
-------------------------------------------------------------------------------

component nx_setup
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    I2C_COMMAND_OUT      : out std_logic_vector(31 downto 0);
    I2C_COMMAND_BUSY_IN  : in  std_logic;
    I2C_DATA_IN          : in  std_logic_vector(31 downto 0);
    I2C_LOCK_OUT         : out std_logic;
    I2C_ONLINE_OUT       : out std_logic;
    I2C_REG_RESET_IN     : in  std_logic;
    SPI_COMMAND_OUT      : out std_logic_vector(31 downto 0);
    SPI_COMMAND_BUSY_IN  : in  std_logic;
    SPI_DATA_IN          : in  std_logic_vector(31 downto 0);
    SPI_LOCK_OUT         : out std_logic;
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end component;

component nx_control
  port (
    CLK_IN                 : in  std_logic;
    RESET_IN               : in  std_logic;
    PLL_NX_CLK_LOCK_IN     : in  std_logic;
    PLL_ADC_DCLK_LOCK_IN   : in  std_logic;
    PLL_ADC_SCLK_LOCK_IN  : in  std_logic;
    I2C_SM_RESET_OUT       : out std_logic;
    I2C_REG_RESET_OUT      : out std_logic;
    NX_TS_RESET_OUT        : out std_logic;
    I2C_OFFLINE_IN         : in  std_logic;
    OFFLINE_OUT            : out std_logic;
    
    SLV_READ_IN            : in  std_logic;
    SLV_WRITE_IN           : in  std_logic;
    SLV_DATA_OUT           : out std_logic_vector(31 downto 0);
    SLV_DATA_IN            : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN            : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT            : out std_logic;
    SLV_NO_MORE_DATA_OUT   : out std_logic;
    SLV_UNKNOWN_ADDR_OUT   : out std_logic;
    DEBUG_OUT              : out std_logic_vector(15 downto 0)
    );
end component;

component clock10MHz
  port (
    CLK   : in  std_logic;
    CLKOP : out std_logic;
    LOCK  : out std_logic
    );
end component;

component fifo_ts_32to32_dc
  port (
    Data          : in  std_logic_vector(31 downto 0);
    WrClock       : in  std_logic;
    RdClock       : in  std_logic;
    WrEn          : in  std_logic;
    RdEn          : in  std_logic;
    Reset         : in  std_logic;
    RPReset       : in  std_logic;
    Q             : out std_logic_vector(31 downto 0);
    Empty         : out std_logic;
    Full          : out std_logic
    );
end component;

component fifo_44_data_delay
  port (
    Data          : in  std_logic_vector(43 downto 0);
    Clock         : in  std_logic;
    WrEn          : in  std_logic;
    RdEn          : in  std_logic;
    Reset         : in  std_logic;
    AmEmptyThresh : in  std_logic_vector(7 downto 0);
    Q             : out std_logic_vector(43 downto 0);
    Empty         : out std_logic;
    Full          : out std_logic;
    AlmostEmpty   : out std_logic
    );
end component;

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
    AlmostFull  : out  std_logic
    );
end component;

component nx_data_receiver
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    NX_DATA_CLK_TEST_IN  : in  std_logic;
    TRIGGER_IN           : in  std_logic;
    NX_TIMESTAMP_CLK_IN  : in  std_logic;
    NX_TIMESTAMP_IN      : in  std_logic_vector (7 downto 0);
    ADC_CLK_DAT_IN       : in  std_logic;
    ADC_FCLK_IN          : in  std_logic_vector(1 downto 0);
    ADC_DCLK_IN          : in  std_logic_vector(1 downto 0);
    ADC_SAMPLE_CLK_OUT   : out std_logic;
    ADC_A_IN             : in  std_logic_vector(1 downto 0);
    ADC_B_IN             : in  std_logic_vector(1 downto 0);
    ADC_NX_IN            : in  std_logic_vector(1 downto 0);
    ADC_D_IN             : in  std_logic_vector(1 downto 0);
    ADC_SCLK_LOCK_OUT    : out std_logic;
    NX_TIMESTAMP_OUT     : out std_logic_vector(31 downto 0);
    ADC_DATA_OUT         : out std_logic_vector(11 downto 0);
    NEW_DATA_OUT         : out std_logic;
    TIMESTAMP_CURRENT_IN : in  unsigned(11 downto 0);
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end component;

component nx_data_delay
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    NX_FRAME_IN          : in  std_logic_vector(31 downto 0);
    ADC_DATA_IN          : in  std_logic_vector(11 downto 0);
    NEW_DATA_IN          : in  std_logic;
    NX_FRAME_OUT         : out std_logic_vector(31 downto 0);
    ADC_DATA_OUT         : out std_logic_vector(11 downto 0);
    NEW_DATA_OUT         : out std_logic;
    FIFO_DELAY_IN        : in  std_logic_vector(7 downto 0);
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end component;

component nx_data_validate
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    NX_TIMESTAMP_IN      : in  std_logic_vector(31 downto 0);
    ADC_DATA_IN          : in  std_logic_vector(11 downto 0);
    NEW_DATA_IN          : in  std_logic;
    TIMESTAMP_OUT        : out std_logic_vector(13 downto 0);
    CHANNEL_OUT          : out std_logic_vector(6 downto 0);
    TIMESTAMP_STATUS_OUT : out std_logic_vector(2 downto 0);
    ADC_DATA_OUT         : out std_logic_vector(11 downto 0);
    DATA_VALID_OUT       : out std_logic;
    NX_TOKEN_RETURN_OUT  : out std_logic;
    NX_NOMORE_DATA_OUT   : out std_logic;
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end component;

component nx_trigger_validate
  generic (
    BOARD_ID : std_logic_vector(15 downto 0)
    );
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    DATA_CLK_IN          : in  std_logic;
    TIMESTAMP_IN         : in  std_logic_vector(13 downto 0);
    CHANNEL_IN           : in  std_logic_vector(6 downto 0);
    TIMESTAMP_STATUS_IN  : in  std_logic_vector(2 downto 0);
    ADC_DATA_IN          : in  std_logic_vector(11 downto 0);
    NX_TOKEN_RETURN_IN   : in  std_logic;
    NX_NOMORE_DATA_IN    : in  std_logic;
    TRIGGER_IN           : in  std_logic;
    TRIGGER_BUSY_IN      : in  std_logic;
    FAST_CLEAR_IN        : in  std_logic;
    TRIGGER_BUSY_OUT     : out std_logic;
    TIMESTAMP_FPGA_IN    : in  unsigned(11 downto 0);
    DATA_FIFO_DELAY_OUT  : out std_logic_vector(7 downto 0);
    DATA_OUT             : out std_logic_vector(31 downto 0);
    DATA_CLK_OUT         : out std_logic;
    NOMORE_DATA_OUT      : out std_logic;
    EVT_BUFFER_CLEAR_OUT : out std_logic;
    EVT_BUFFER_FULL_IN   : in  std_logic;
    HISTOGRAM_FILL_OUT   : out std_logic;
    HISTOGRAM_BIN_OUT    : out std_logic_vector(6 downto 0);
    HISTOGRAM_ADC_OUT    : out std_logic_vector(11 downto 0);
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end component;

component nx_event_buffer
  generic (
    BOARD_ID : std_logic_vector(15 downto 0)
    );
  port (
    CLK_IN                  : in  std_logic;
    RESET_IN                : in  std_logic;
    RESET_DATA_BUFFER_IN    : in  std_logic;
    NXYTER_OFFLINE_IN       : in  std_logic;
    DATA_IN                 : in  std_logic_vector(31 downto 0);
    DATA_CLK_IN             : in  std_logic;
    EVT_NOMORE_DATA_IN      : in  std_logic;
    LVL2_TRIGGER_IN         : in  std_logic;
    FAST_CLEAR_IN           : in  std_logic;
    TRIGGER_BUSY_OUT        : out std_logic;
    EVT_BUFFER_FULL_OUT     : out std_logic;
    FEE_DATA_OUT            : out std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_OUT      : out std_logic;
    FEE_DATA_FINISHED_OUT   : out std_logic;
    FEE_DATA_ALMOST_FULL_IN : in  std_logic;
    SLV_READ_IN             : in  std_logic;
    SLV_WRITE_IN            : in  std_logic;
    SLV_DATA_OUT            : out std_logic_vector(31 downto 0);
    SLV_DATA_IN             : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN             : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT             : out std_logic;
    SLV_NO_MORE_DATA_OUT    : out std_logic;
    SLV_UNKNOWN_ADDR_OUT    : out std_logic;
    DEBUG_OUT               : out std_logic_vector(15 downto 0)
    );
end component;

-------------------------------------------------------------------------------

component nx_histograms
  generic (
    BUS_WIDTH    : integer;
    ENABLE       : boolean
    );
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    RESET_HISTS_IN       : in  std_logic;
    CHANNEL_STAT_FILL_IN : in  std_logic;
    CHANNEL_ID_IN        : in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    CHANNEL_ADC_IN       : in  std_logic_vector(11 downto 0);
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    DEBUG_OUT            : out std_logic_vector(15 downto 0));
end component;

component ram_dp_128x32
  port (
    WrAddress   : in  std_logic_vector(6 downto 0);
    RdAddress   : in  std_logic_vector(6 downto 0);
    Data        : in  std_logic_vector(31 downto 0);
    WE          : in  std_logic;
    RdClock     : in  std_logic;
    RdClockEn   : in  std_logic;
    Reset       : in  std_logic;
    WrClock     : in  std_logic;
    WrClockEn   : in  std_logic;
    Q           : out std_logic_vector(31 downto 0)
    );
end component;

-------------------------------------------------------------------------------

component level_to_pulse
  port (
    CLK_IN         : in  std_logic;
    RESET_IN       : in  std_logic;
    LEVEL_IN       : in  std_logic;
    PULSE_OUT      : out std_logic
    );
end component;

component pulse_to_level
  generic (
    NUM_CYCLES : integer range 2 to 15
    );
  port (
    CLK_IN    : in  std_logic;
    RESET_IN  : in  std_logic;
    PULSE_IN  : in  std_logic;
    LEVEL_OUT : out std_logic
    );
end component;

component signal_async_to_pulse
  generic (
    NUM_FF : integer range 2 to 4
    );
  port (
    CLK_IN     : in  std_logic;
    RESET_IN   : in  std_logic;
    PULSE_A_IN : in  std_logic;
    PULSE_OUT  : out std_logic
    );
end component;

component signal_async_trans
  generic (
    NUM_FF : integer range 2 to 4
    );
  port (
    CLK_IN      : in  std_logic;
    RESET_IN    : in  std_logic;
    SIGNAL_A_IN : in  std_logic;
    SIGNAL_OUT  : out std_logic
    );
end component;

component pulse_dtrans
  generic (
    CLK_RATIO : integer range 2 to 15
    );
  port (
    CLK_A_IN    : in  std_logic;
    RESET_A_IN  : in  std_logic;
    PULSE_A_IN  : in  std_logic;
    CLK_B_IN    : in  std_logic;
    RESET_B_IN  : in  std_logic;
    PULSE_B_OUT : out std_logic
    );
end component;

component Gray_Decoder
  generic (
    WIDTH : integer range 2 to 32
    );
  port (
    CLK_IN     : in  std_logic;
    RESET_IN   : in  std_logic;
    GRAY_IN    : in  std_logic_vector(WIDTH - 1 downto 0);
    BINARY_OUT : out std_logic_vector(WIDTH - 1 downto 0)
    );
end component;

component Gray_Encoder
  generic (
    WIDTH : integer range 2 to 32
    );
  port (
    CLK_IN    : in  std_logic;
    RESET_IN  : in  std_logic;
    BINARY_IN : in  std_logic_vector(WIDTH - 1 downto 0);
    GRAY_OUT  : out std_logic_vector(WIDTH - 1 downto 0)
    );
end component;

component pulse_delay
  generic (
    DELAY : integer range 2 to 16777216);
  port (
    CLK_IN    : in  std_logic;
    RESET_IN  : in  std_logic;
    PULSE_IN  : in  std_logic;
    PULSE_OUT : out std_logic
    );
end component;

-------------------------------------------------------------------------------
-- PLLs
-------------------------------------------------------------------------------

component pll_nx_clk250
  port (
    CLK   : in  std_logic;
    CLKOP : out std_logic;
    CLKOK : out std_logic;
    LOCK  : out std_logic
    );
end component;

component pll_adc_clk
  port (
    CLK   : in  std_logic;
    CLKOP : out std_logic;
    LOCK  : out std_logic
    );
end component;

component pll_adc_sampling_clk
  port (
    CLK       : in  std_logic;
    RESET     : in  std_logic;
    FINEDELB0 : in  std_logic;
    FINEDELB1 : in  std_logic;
    FINEDELB2 : in  std_logic;
    FINEDELB3 : in  std_logic;
    DPHASE0   : in  std_logic;
    DPHASE1   : in  std_logic;
    DPHASE2   : in  std_logic;
    DPHASE3   : in  std_logic;
    CLKOP     : out std_logic;
    CLKOS     : out std_logic;
    LOCK      : out std_logic
    );
end component;

component nx_fpga_timestamp
  port (
    CLK_IN                   : in  std_logic;
    RESET_IN                 : in  std_logic;
    NX_MAIN_CLK_IN           : in  std_logic;
    TIMESTAMP_SYNC_IN        : in  std_logic;
    TRIGGER_IN               : in  std_logic;
    TIMESTAMP_CURRENT_OUT    : out unsigned(11 downto 0);
    TIMESTAMP_HOLD_OUT       : out unsigned(11 downto 0);
    TIMESTAMP_SYNCED_OUT     : out std_logic;
    TIMESTAMP_TRIGGER_OUT    : out std_logic;
    SLV_READ_IN              : in  std_logic;
    SLV_WRITE_IN             : in  std_logic;
    SLV_DATA_OUT             : out std_logic_vector(31 downto 0);
    SLV_DATA_IN              : in  std_logic_vector(31 downto 0);
    SLV_ACK_OUT              : out std_logic;
    SLV_NO_MORE_DATA_OUT     : out std_logic;
    SLV_UNKNOWN_ADDR_OUT     : out std_logic;
    DEBUG_OUT                : out std_logic_vector(15 downto 0)
    );
end component;

component nx_trigger_handler
  port (
    CLK_IN                     : in  std_logic;
    RESET_IN                   : in  std_logic;
    NX_MAIN_CLK_IN             : in  std_logic;
    NXYTER_OFFLINE_IN          : in  std_logic;
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
    FEE_TRG_RELEASE_OUT        : out std_logic;
    FEE_TRG_STATUSBITS_OUT     : out std_logic_vector(31 downto 0);
    INTERNAL_TRIGGER_IN        : in  std_logic;
    TRIGGER_VALIDATE_BUSY_IN   : in  std_logic;
    LVL2_TRIGGER_BUSY_IN       : in  std_logic;
    VALIDATE_TRIGGER_OUT       : out std_logic;
    TIMESTAMP_TRIGGER_OUT      : out std_logic;
    LVL2_TRIGGER_OUT           : out std_logic;
    FAST_CLEAR_OUT             : out std_logic;
    TRIGGER_BUSY_OUT           : out std_logic;
    TRIGGER_TESTPULSE_OUT      : out std_logic;
    SLV_READ_IN                : in  std_logic;
    SLV_WRITE_IN               : in  std_logic;
    SLV_DATA_OUT               : out std_logic_vector(31 downto 0);
    SLV_DATA_IN                : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN                : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT                : out std_logic;
    SLV_NO_MORE_DATA_OUT       : out std_logic;
    SLV_UNKNOWN_ADDR_OUT       : out std_logic;
    DEBUG_OUT                  : out std_logic_vector(15 downto 0)
    );
end component;

component nx_trigger_generator
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    NX_MAIN_CLK_IN       : in  std_logic;
    TRIGGER_IN           : in  std_logic;
    TRIGGER_OUT          : out std_logic;
    TS_RESET_OUT         : out std_logic;
    TESTPULSE_OUT        : out std_logic;
    TEST_IN              : in  std_logic_vector(31 downto 0);
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end component;

-------------------------------------------------------------------------------
-- Misc Tools
-------------------------------------------------------------------------------

component nx_timer
  generic (
    CTR_WIDTH : integer range 2 to 32;
    STEP_SIZE : integer
    );
  port (
    CLK_IN         : in  std_logic;
    RESET_IN       : in  std_logic;
    TIMER_START_IN : in  unsigned(CTR_WIDTH - 1 downto 0);
    TIMER_DONE_OUT : out std_logic
    );
end component;

-------------------------------------------------------------------------------
-- Simulations
-------------------------------------------------------------------------------

component nxyter_timestamp_sim
  port (
    CLK_IN        : in  std_logic;
    RESET_IN      : in  std_logic;
    TIMESTAMP_OUT : out std_logic_vector(7 downto 0);
    CLK128_OUT    : out std_logic
    );
end component;

type debug_array_t is array(integer range <>) of std_logic_vector(15 downto 0);

component debug_multiplexer
  generic (
    NUM_PORTS : integer range 1 to 32
    );
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    DEBUG_LINE_IN        : in  debug_array_t(0 to NUM_PORTS-1);
    DEBUG_LINE_OUT       : out std_logic_vector(15 downto 0);
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic
    );
end component;

end package;
