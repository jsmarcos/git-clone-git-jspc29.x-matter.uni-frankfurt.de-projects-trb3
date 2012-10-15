library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


package nxyter_components is

-------------------------------------------------------------------------------
-- TRBNet interfaces
-------------------------------------------------------------------------------

component nXyter_FEE_board
  port (
    CLK_IN                 : in    std_logic;
    RESET_IN               : in    std_logic;

    I2C_SDA_INOUT          : inout std_logic;
    I2C_SCL_OUT            : out   std_logic;
    I2C_SM_RESET_OUT       : out   std_logic;
    I2C_REG_RESET_OUT      : out   std_logic;

    SPI_SCLK_OUT           : out   std_logic;
    SPI_SDIO_INOUT         : in    std_logic;
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
    REGIO_UNKNOWN_ADDR_OUT : out   std_logic
    );
end component;

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
    SLV_UNKNOWN_ADDR_OUT : out std_logic
    );
end component;

component fifo_dc_8to32
  port (
    Data    : in  std_logic_vector(7 downto 0);
    WrClock : in  std_logic;
    RdClock : in  std_logic;
    WrEn    : in  std_logic;
    RdEn    : in  std_logic;
    Reset   : in  std_logic;
    RPReset : in  std_logic;
    Q       : out std_logic_vector(31 downto 0);
    Empty   : out std_logic;
    Full    : out std_logic);
end component;

component nx_timestamp_fifo_read
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    NX_TIMESTAMP_CLK_IN  : in std_logic;
    NX_TIMESTAMP_IN      : in std_logic_vector (7 downto 0);
    NX_FRAME_CLOCK_OUT   : out std_logic; 
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
    WIDTH : integer);
  port (
    CLK_IN     : in  std_logic;
    RESET_IN   : in  std_logic;
    GRAY_IN    : in  std_logic_vector(WIDTH - 1 downto 0);
    BINARY_OUT : out std_logic_vector(WIDTH - 1 downto 0));
end component;


component Gray_Encoder
  generic (
    WIDTH : integer);
  port (
    CLK_IN    : in  std_logic;
    RESET_IN  : in  std_logic;
    BINARY_IN : in  std_logic_vector(WIDTH - 1 downto 0);
    GRAY_OUT  : out std_logic_vector(WIDTH - 1 downto 0));
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
