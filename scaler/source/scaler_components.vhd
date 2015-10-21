library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package scaler_components is

-------------------------------------------------------------------------------
-- TRBNet interfaces
-------------------------------------------------------------------------------
  
  component scaler
    generic (
      BOARD_ID : std_logic_vector(1 downto 0));
    port (
      CLK_IN                     : in  std_logic;
      RESET_IN                   : in  std_logic;

      CLK_D1_IN                  : in  std_logic;

      TRIGGER_OUT                : out std_logic;
      LATCH_IN                   : in  std_logic;
      CHANNELS_IN                : in  std_logic_vector (7 downto 0);
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
      REGIO_UNKNOWN_ADDR_OUT     : out std_logic;
      DEBUG_LINE_OUT             : out std_logic_vector(15 downto 0)
    );
  end component;

----------------------------------------------------------------------
-- Scaler Channel Entity
----------------------------------------------------------------------
  component scaler_channel
    port (
      CLK_IN               : in  std_logic;
      RESET_IN             : in  std_logic;
      CLK_D1_IN            : in  std_logic;
      RESET_D1_IN          : in  std_logic;
      RESET_CTR_IN         : in  std_logic; 
      LATCH_IN             : in  std_logic;
      PULSE_IN             : in  std_logic;
      INHIBIT_IN           : in  std_logic;
      COUNTER_OUT          : out std_logic_vector(47 downto 0);
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
  
----------------------------------------------------------------------
-- Latch Handler Entity
----------------------------------------------------------------------
  component latch_handler
    port (
      CLK_IN               : in  std_logic;
      RESET_IN             : in  std_logic;
      CLK_D1_IN            : in  std_logic;
      RESET_D1_IN          : in  std_logic;
      RESET_CTR_IN         : in std_logic;
      LATCH_TRIGGER_IN     : in  std_logic;
      RESET_CTR_OUT        : out std_logic;
      LATCH_OUT            : out std_logic;
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
  
-------------------------------------------------------------------------------
-- Trigger Handler
-------------------------------------------------------------------------------
  component trigger_handler
    port (
      CLK_IN                     : in  std_logic;
      RESET_IN                   : in  std_logic;
      CLK_D1_IN                  : in  std_logic;
      RESET_D1_IN                : in  std_logic;
      OFFLINE_IN                 : in  std_logic;
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
      CHANNEL_DATA_0_IN          : in  std_logic_vector(47 downto 0);
      CHANNEL_DATA_1_IN          : in  std_logic_vector(47 downto 0);
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
      I2C_DATA_BYTES_OUT   : out   std_logic_vector(31 downto 0);
      I2C_LOCK_IN          : in    std_logic;
      SLV_READ_IN          : in    std_logic;
      SLV_WRITE_IN         : in    std_logic;
      SLV_DATA_OUT         : out   std_logic_vector(31 downto 0);
      SLV_DATA_IN          : in    std_logic_vector(31 downto 0);
      SLV_ADDR_IN          : in    std_logic_vector(15 downto 0);
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
      NUM_BYTES_IN      : in  unsigned(2 downto 0);
      BYTE_OUT          : out std_logic_vector(31 downto 0);
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
      SPI_SPEED : unsigned(7 downto 0));
    port (
      CLK_IN               : in    std_logic;
      RESET_IN             : in    std_logic;
      SCLK_OUT             : out   std_logic;
      SDIO_INOUT           : inout std_logic;
      CSB_OUT              : out   std_logic;
      INTERNAL_COMMAND_IN  : in    std_logic_vector(31 downto 0);
      COMMAND_ACK_OUT      : out   std_logic;
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
-- ADC Data Handler 
-------------------------------------------------------------------------------

  component adc_ad9228
    generic (
      DEBUG_ENABLE : boolean);
    port (
      CLK_IN               : in  std_logic;
      RESET_IN             : in  std_logic;
      RESET_ADCS           : in  std_logic;
      ADC_SCLK_IN          : in  std_logic;
      ADC_SCLK_OUT         : out std_logic;
      ADC_DATA_A_IN        : in  std_logic;
      ADC_DATA_B_IN        : in  std_logic;
      ADC_DATA_C_IN        : in  std_logic;
      ADC_DATA_D_IN        : in  std_logic;
      ADC_DCLK_IN          : in  std_logic;
      ADC_FCLK_IN          : in  std_logic;
      ADC_DATA_A_OUT       : out std_logic_vector(11 downto 0);
      ADC_DATA_B_OUT       : out std_logic_vector(11 downto 0);
      ADC_DATA_C_OUT       : out std_logic_vector(11 downto 0);
      ADC_DATA_D_OUT       : out std_logic_vector(11 downto 0);
      ADC_DATA_CLK_OUT     : out std_logic;
      ADC_LOCKED_OUT       : out std_logic;
      ADC_ERROR_STATUS_OUT : out std_logic_vector(2 downto 0);
      DEBUG_IN             : in  std_logic_vector(3 downto 0);
      DEBUG_OUT            : out std_logic_vector(15 downto 0));
  end component;

-------------------------------------------------------------------------------
-- TRBNet Registers
-------------------------------------------------------------------------------

  component nx_register_setup
    port (
      CLK_IN               : in  std_logic;
      RESET_IN             : in  std_logic;
      I2C_ONLINE_IN        : in  std_logic;
      I2C_COMMAND_OUT      : out std_logic_vector(31 downto 0);
      I2C_COMMAND_BUSY_IN  : in  std_logic;
      I2C_DATA_IN          : in  std_logic_vector(31 downto 0);
      I2C_DATA_BYTES_IN    : in  std_logic_vector(31 downto 0);
      I2C_LOCK_OUT         : out std_logic;
      I2C_REG_RESET_IN     : in  std_logic;
      SPI_COMMAND_OUT      : out std_logic_vector(31 downto 0);
      SPI_COMMAND_BUSY_IN  : in  std_logic;
      SPI_DATA_IN          : in  std_logic_vector(31 downto 0);
      SPI_LOCK_OUT         : out std_logic;
      INT_READ_IN          : in  std_logic;
      INT_ADDR_IN          : in  std_logic_vector(15 downto 0);
      INT_ACK_OUT          : out std_logic;
      INT_DATA_OUT         : out std_logic_vector(31 downto 0);
      NX_CLOCK_ON_OUT      : out std_logic;
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

  component nx_status
    port (
      CLK_IN                 : in  std_logic;
      RESET_IN               : in  std_logic;
      PLL_NX_CLK_LOCK_IN     : in  std_logic;
      PLL_ADC_DCLK_LOCK_IN   : in  std_logic;
      PLL_ADC_SCLK_LOCK_IN   : in  std_logic;
      PLL_RESET_OUT          : out std_logic;
      I2C_SM_RESET_OUT       : inout std_logic;
      I2C_REG_RESET_OUT      : out std_logic;
      NX_ONLINE_OUT          : out std_logic;
      ERROR_ALL_IN           : in  std_logic_vector(7 downto 0);
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

  component nx_trigger_validate
    generic (
      BOARD_ID       : std_logic_vector(1 downto 0);
      VERSION_NUMBER : std_logic_vector(3 downto 0));
    port (
      CLK_IN                 : in  std_logic;
      RESET_IN               : in  std_logic;
      DATA_CLK_IN            : in  std_logic;
      TIMESTAMP_IN           : in  std_logic_vector(13 downto 0);
      CHANNEL_IN             : in  std_logic_vector(6 downto 0);
      TIMESTAMP_STATUS_IN    : in  std_logic_vector(2 downto 0);
      ADC_DATA_IN            : in  std_logic_vector(11 downto 0);
      NX_TOKEN_RETURN_IN     : in  std_logic;
      NX_NOMORE_DATA_IN      : in  std_logic;
      TRIGGER_IN             : in  std_logic;
      TRIGGER_CALIBRATION_IN : in  std_logic;
      TRIGGER_BUSY_IN        : in  std_logic;
      FAST_CLEAR_IN          : in  std_logic;
      TRIGGER_BUSY_OUT       : out std_logic;
      TIMESTAMP_FPGA_IN      : in  unsigned(11 downto 0);
      DATA_FIFO_DELAY_OUT    : out std_logic_vector(7 downto 0);
      DATA_OUT               : out std_logic_vector(31 downto 0);
      DATA_CLK_OUT           : out std_logic;
      NOMORE_DATA_OUT        : out std_logic;
      EVT_BUFFER_CLEAR_OUT   : out std_logic;
      EVT_BUFFER_FULL_IN     : in  std_logic;
      HISTOGRAM_RESET_OUT    : out std_logic;
      HISTOGRAM_FILL_OUT     : out std_logic;
      HISTOGRAM_BIN_OUT      : out std_logic_vector(6 downto 0);
      HISTOGRAM_ADC_OUT      : out std_logic_vector(11 downto 0);
      HISTOGRAM_TS_OUT       : out std_logic_vector(8 downto 0);
      HISTOGRAM_PILEUP_OUT   : out std_logic;
      HISTOGRAM_OVERFLOW_OUT : out std_logic;
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

  component nx_event_buffer
    generic (
      BOARD_ID : std_logic_vector(1 downto 0)
      );
    port (
      CLK_IN                  : in  std_logic;
      RESET_IN                : in  std_logic;
      RESET_DATA_BUFFER_IN    : in  std_logic;
      NXYTER_OFFLINE_IN       : in  std_logic;
      DATA_IN                 : in  std_logic_vector(31 downto 0);
      DATA_CLK_IN             : in  std_logic;
      EVT_NOMORE_DATA_IN      : in  std_logic;
      TRIGGER_IN              : in  std_logic;
      FAST_CLEAR_IN           : in  std_logic;
      TRIGGER_BUSY_OUT        : out std_logic;
      EVT_BUFFER_FULL_OUT     : out std_logic;
      FEE_DATA_OUT            : out std_logic_vector(31 downto 0);
      FEE_DATA_WRITE_OUT      : out std_logic;
      FEE_DATA_ALMOST_FULL_IN : in  std_logic;
      SLV_READ_IN             : in  std_logic;
      SLV_WRITE_IN            : in  std_logic;
      SLV_DATA_OUT            : out std_logic_vector(31 downto 0);
      SLV_DATA_IN             : in  std_logic_vector(31 downto 0);
      SLV_ADDR_IN             : in  std_logic_vector(15 downto 0);
      SLV_ACK_OUT             : out std_logic;
      SLV_NO_MORE_DATA_OUT    : out std_logic;
      SLV_UNKNOWN_ADDR_OUT    : out std_logic;
      ERROR_OUT               : out std_logic;
      DEBUG_OUT               : out std_logic_vector(15 downto 0)
      );
  end component;

  component nx_status_event
    generic (
      BOARD_ID       : std_logic_vector(1 downto 0);
      VERSION_NUMBER : std_logic_vector(3 downto 0));
    port (
      CLK_IN                  : in  std_logic;
      RESET_IN                : in  std_logic;
      NXYTER_OFFLINE_IN       : in  std_logic;
      TRIGGER_IN              : in  std_logic;
      FAST_CLEAR_IN           : in  std_logic;
      TRIGGER_BUSY_OUT        : out std_logic;
      FEE_DATA_OUT            : out std_logic_vector(31 downto 0);
      FEE_DATA_WRITE_OUT      : out std_logic;
      FEE_DATA_ALMOST_FULL_IN : in  std_logic;
      INT_READ_OUT            : out std_logic;
      INT_ADDR_OUT            : out std_logic_vector(15 downto 0);
      INT_ACK_IN              : in  std_logic;
      INT_DATA_IN             : in  std_logic_vector(31 downto 0);
      DEBUG_OUT               : out std_logic_vector(15 downto 0)
      );
  end component;

-------------------------------------------------------------------------------

  component nx_histogram
    generic (
      BUS_WIDTH  : integer
      );
    port (
      CLK_IN                 : in  std_logic;
      RESET_IN               : in  std_logic;
      NUM_AVERAGES_IN        : in  unsigned(2 downto 0);
      AVERAGE_ENABLE_IN      : in  std_logic;
      CHANNEL_ID_IN          : in  std_logic_vector(BUS_WIDTH - 1 downto 0);
      CHANNEL_DATA_IN        : in  std_logic_vector(31 downto 0);
      CHANNEL_ADD_IN         : in  std_logic;
      CHANNEL_WRITE_IN       : in  std_logic;
      CHANNEL_WRITE_BUSY_OUT : out std_logic;
      CHANNEL_ID_READ_IN     : in  std_logic_vector(BUS_WIDTH - 1 downto 0);
      CHANNEL_READ_IN        : in  std_logic;
      CHANNEL_DATA_OUT       : out std_logic_vector(31 downto 0);
      CHANNEL_DATA_VALID_OUT : out std_logic;
      CHANNEL_READ_BUSY_OUT  : out std_logic;
      DEBUG_OUT              : out std_logic_vector(15 downto 0));
  end component;

  component nx_histograms
    port (
      CLK_IN               : in  std_logic;
      RESET_IN             : in  std_logic;
      RESET_HISTS_IN       : in  std_logic;
      CHANNEL_FILL_IN      : in  std_logic;
      CHANNEL_ID_IN        : in  std_logic_vector(6 downto 0);
      CHANNEL_ADC_IN       : in  std_logic_vector(11 downto 0);
      CHANNEL_TS_IN        : in  std_logic_vector(8 downto 0);
      CHANNEL_PILEUP_IN    : in  std_logic;
      CHANNEL_OVERFLOW_IN  : in  std_logic;
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
      NUM_FF : integer range 2 to 5
      );
    port (
      CLK_IN      : in  std_logic;
      SIGNAL_A_IN : in  std_logic;
      SIGNAL_OUT  : out std_logic
      );
  end component;

  component bus_async_trans
    generic (
      BUS_WIDTH : integer range 2 to 32;
      NUM_FF    : integer range 2 to 4);
    port (
      CLK_IN      : in  std_logic;
      RESET_IN    : in  std_logic;
      SIGNAL_A_IN : in  std_logic_vector(BUS_WIDTH - 1 downto 0);
      SIGNAL_OUT  : out std_logic_vector(BUS_WIDTH - 1 downto 0)
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

  component nx_fpga_timestamp
    port (
      CLK_IN                   : in  std_logic;
      RESET_IN                 : in  std_logic;
      NX_MAIN_CLK_IN           : in  std_logic;
      TIMESTAMP_RESET_IN       : in  std_logic;
      TIMESTAMP_RESET_OUT      : out std_logic;
      TRIGGER_IN               : in  std_logic;
      TIMESTAMP_HOLD_OUT       : out unsigned(11 downto 0);
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


  component nx_trigger_generator
    port (
      CLK_IN               : in  std_logic;
      RESET_IN             : in  std_logic;
      TRIGGER_BUSY_IN      : in  std_logic;
      EXTERNAL_TRIGGER_OUT : out std_logic;
      INTERNAL_TRIGGER_OUT : out std_logic;
      DATA_IN              : in  std_logic_vector(43 downto 0);
      DATA_CLK_IN          : in  std_logic;
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

  component timer
    generic (
      CTR_WIDTH : integer range 2 to 32;
      STEP_SIZE : integer range 1 to 100
      );
    port (
      CLK_IN         : in  std_logic;
      RESET_IN       : in  std_logic;
      TIMER_START_IN : in  std_logic;
      TIMER_END_IN   : in  unsigned(CTR_WIDTH - 1 downto 0);
      TIMER_DONE_OUT : out std_logic
      );
  end component;

  component timer_static
    generic (
      CTR_WIDTH : integer range 2 to 32;
      CTR_END   : integer;
      STEP_SIZE : integer range 1 to 100
      );
    port (
      CLK_IN         : in  std_logic;
      RESET_IN       : in  std_logic;
      TIMER_START_IN : in  std_logic;
      TIMER_BUSY_OUT : out std_logic;
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

  type debug_array_t is array(integer range <>)
    of std_logic_vector(15 downto 0);

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
