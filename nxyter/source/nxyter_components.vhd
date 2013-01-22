library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package nxyter_components is

-------------------------------------------------------------------------------
-- TRBNet interfaces
-------------------------------------------------------------------------------

component nXyter_FEE_board
  port (
    CLK_IN                 : in    std_logic;
    RESET_IN               : in    std_logic;

    I2C_SDA_INOUT          : inout std_logic;
    I2C_SCL_INOUT          : inout std_logic;
    I2C_SM_RESET_OUT       : out   std_logic;
    I2C_REG_RESET_OUT      : out   std_logic;

    SPI_SCLK_OUT           : out   std_logic;
    SPI_SDIO_INOUT         : inout std_logic;
    SPI_CSB_OUT            : out   std_logic;

    NX_CLK128_IN           : in    std_logic;
    NX_TIMESTAMP_IN        : in    std_logic_vector (7 downto 0);
    NX_RESET_OUT           : out   std_logic;
    NX_CLK256A_OUT         : out   std_logic;
    NX_TESTPULSE_OUT       : out   std_logic;

    ADC_FCLK_IN            : in    std_logic;
    ADC_DCLK_IN            : in    std_logic;
    ADC_SC_CLK32_OUT       : out   std_logic;
    ADC_A_IN               : in    std_logic;
    ADC_B_IN               : in    std_logic;
    ADC_NX_IN              : in    std_logic;
    ADC_D_IN               : in    std_logic;

    REGIO_ADDR_IN          : in    std_logic_vector(15 downto 0);
    REGIO_DATA_IN          : in    std_logic_vector(31 downto 0);
    REGIO_DATA_OUT         : out   std_logic_vector(31 downto 0);
    REGIO_READ_ENABLE_IN   : in    std_logic;
    REGIO_WRITE_ENABLE_IN  : in    std_logic;
    REGIO_TIMEOUT_IN       : in    std_logic;
    REGIO_DATAREADY_OUT    : out   std_logic;
    REGIO_WRITE_ACK_OUT    : out   std_logic;
    REGIO_NO_MORE_DATA_OUT : out   std_logic;
    REGIO_UNKNOWN_ADDR_OUT : out   std_logic;

    CLK_128_IN             : in    std_logic;
    DEBUG_LINE_OUT         : out   std_logic_vector(15 downto 0)
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

component nxyter_registers
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    I2C_SM_RESET_OUT     : out std_logic;
    I2C_REG_RESET_OUT    : out std_logic;
    NX_TS_RESET_OUT      : out std_logic;
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end component;

component fifo_dc_9to36
  port (
    Data    : in  std_logic_vector(8 downto 0);
    WrClock : in  std_logic;
    RdClock : in  std_logic;
    WrEn    : in  std_logic;
    RdEn    : in  std_logic;
    Reset   : in  std_logic;
    RPReset : in  std_logic;
    Q       : out std_logic_vector(35 downto 0);
    Empty   : out std_logic;
    Full    : out std_logic
    );
end component;

component nx_timestamp_fifo_read
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    NX_TIMESTAMP_CLK_IN  : in  std_logic;

    NX_TIMESTAMP_IN      : in  std_logic_vector (7 downto 0);
    NX_FRAME_CLOCK_OUT   : out std_logic;
    NX_TIMESTAMP_OUT     : out std_logic_vector(31 downto 0);
    NX_NEW_TIMESTAMP_OUT : out std_logic;

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

component level_to_pulse
  port (
    CLK_IN         : in  std_logic;
    RESET_IN       : in  std_logic;
    LEVEL_IN       : in  std_logic;
    PULSE_OUT      : out std_logic
    );
end component;

component Gray_Decoder
  generic (
    WIDTH : integer
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
    WIDTH : integer
    );
  port (
    CLK_IN    : in  std_logic;
    RESET_IN  : in  std_logic;
    BINARY_IN : in  std_logic_vector(WIDTH - 1 downto 0);
    GRAY_OUT  : out std_logic_vector(WIDTH - 1 downto 0)
    );
end component;

component fifo_32_data
  port (
    Data  : in  std_logic_vector(31 downto 0);
    Clock : in  std_logic;
    WrEn  : in  std_logic;
    RdEn  : in  std_logic;
    Reset : in  std_logic;
    Q     : out std_logic_vector(31 downto 0);
    Empty : out std_logic;
    Full  : out std_logic
    );
end component;

component nx_data_buffer
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    DATA_IN              : in  std_logic_vector(31 downto 0);
    NEW_DATA_IN          : in  std_logic;
    FIFO_WRITE_ENABLE_IN : in  std_logic;
    FIFO_READ_ENABLE_IN  : in  std_logic;
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

component nx_timestamp_decode
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    NX_NEW_TIMESTAMP_IN  : in  std_logic;
    NX_TIMESTAMP_IN      : in  std_logic_vector(31 downto 0);
    TIMESTAMP_REF_IN     : in  unsigned(11 downto 0);
    TIMESTAMP_DATA_OUT   : out std_logic_vector(31 downto 0);
    TIMESTAMP_VALID_OUT  : out std_logic;
    NX_TOKEN_RETURN      : out std_logic;
    NX_NOMORE_DATA       : out std_logic;
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


component pll_nx_clk256
  port (
    CLK   : in  std_logic;
    CLKOP : out std_logic;
    LOCK  : out std_logic);
end component;

component nx_fpga_timestamp
  port (
    CLK_IN                : in  std_logic;
    RESET_IN              : in  std_logic;
    TIMESTAMP_SYNC_IN     : in  std_logic;
    TRIGGER_IN            : in  std_logic;
    TIMESTAMP_OUT         : out unsigned(11 downto 0);
    NX_TIMESTAMP_SYNC_OUT : in  std_logic;
    SLV_READ_IN           : in  std_logic;
    SLV_WRITE_IN          : in  std_logic;
    SLV_DATA_OUT          : out std_logic_vector(31 downto 0);
    SLV_DATA_IN           : in  std_logic_vector(31 downto 0);
    SLV_ACK_OUT           : out std_logic;
    SLV_NO_MORE_DATA_OUT  : out std_logic;
    SLV_UNKNOWN_ADDR_OUT  : out std_logic;
    DEBUG_OUT             : out std_logic_vector(15 downto 0)
    );
end component;

component nx_trigger_generator
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    TRIGGER_OUT          : out std_logic;
    TS_RESET_OUT         : out std_logic;
    TESTPULSE_OUT        : out std_logic;
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

component nx_trigger_handler
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    TRIGGER_IN           : in  std_logic;
    TRIGGER_RELEASE_IN   : in  std_logic;
    TRIGGER_OUT          : out std_logic;
    TIMESTAMP_HOLD_OUT   : out std_logic;
    TRIGGER_BUSY_OUT     : out std_logic;
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
-- Misc Tools
-------------------------------------------------------------------------------

component nx_timer
  generic (
    CTR_WIDTH : integer
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

end package;
