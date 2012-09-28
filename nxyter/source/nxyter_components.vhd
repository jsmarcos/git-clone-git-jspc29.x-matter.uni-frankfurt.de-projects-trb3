library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.ALL;

package nxyter_components is

-------------------------------------------------------------------------------
-- TRBNet interfaces
-------------------------------------------------------------------------------

component nXyter_FEE_board
  port (
    CLK_IN                 : in    std_logic_vector;
    RESET_IN               : in    std_logic_vector;

    I2C_SDA_INOUT          : inout std_logic;
    I2C_SCL_OUT            : out   std_logic;
    I2C_SM_RESET_OUT       : out   std_logic;
    I2C_REG_RESET_OUT      : out   std_logic;

    SPI_SCLK_OUT           : out   std_logic;
    SPI_SDIO_INOUT         : in    std_logic;
    SPI_CSB_OUT            : out   std_logic;

    NX_CLK128_IN           : in    std_logic;
    NX_IN                  : in    std_logic_vector (7 downto 0);
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
    REGIO_UNKNOWN_ADDR_OUT : out   std_logic);
end component;



component Gray_Decoder
  generic (
    WIDTH : integer);
  port (
    GRAY_IN    : in  std_logic_vector(WIDTH - 1 downto 0);
    BINARY_OUT : out std_logic_vector(WIDTH - 1 downto 0));
end component;

end package;
