-----------------------------------------------------------------------------
--
--One  nXyter FEB 
--
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.adcmv3_components.all;

entity nXyter_FEE_board is
  
  port (
    CLK_IN             : in std_logic_vector;  
    RESET_IN           : in std_logic_vector;  
    
    -- I2C Ports
    I2C_SDA_INOUT      : inout std_logic;   -- nXyter I2C fdata line
    I2C_SCL_OUT        : out std_logic;     -- nXyter I2C Clock line

    I2C_SM_RESET_OUT   : out std_logic;     -- reset nXyter I2C StateMachine 
    I2C_REG_RESET_OUT  : out std_logic;     -- reset I2C registers to default

    -- ADC SPI
    SPI_SCLK_OUT       : out std_logic;
    SPI_SDIO_INOUT     : in std_logic;
    SPI_CSB_OUT        : out std_logic;    

    -- nXyter Timestamp Ports
    NX_CLK128_IN       : in std_logic;
    NX_IN              : in std_logic_vector (7 downto 0);
    NX_RESET_OUT       : out std_logic;
    NX_CLK256A_OUT     : out std_logic;
    NX_TESTPULSE_OUT   : out std_logic;

    -- ADC nXyter Pulse Hight Ports
    ADC_FCLK_IN        : in std_logic;
    ADC_DCLK_IN        : in std_logic;
    ADC_SC_CLK32_IN    : in std_logic;
    ADC_A_IN           : in std_logic;
    ADC_B_IN           : in std_logic;
    ADC_NX_IN          : in std_logic;
    ADC_D_IN           : in std_logic;        
    
    -- TRBNet RegIO Port for the slave bus
    REGIO_ADDR_IN           : in    std_logic_vector(15 downto 0);
    REGIO_DATA_IN           : in    std_logic_vector(31 downto 0);
    REGIO_DATA_OUT          : out   std_logic_vector(31 downto 0);
    REGIO_READ_ENABLE_IN    : in    std_logic;                    
    REGIO_WRITE_ENABLE_IN   : in    std_logic;
    REGIO_TIMEOUT_IN        : in    std_logic;
    REGIO_DATAREADY_OUT     : out   std_logic;
    REGIO_WRITE_ACK_OUT     : out   std_logic;
    REGIO_NO_MORE_DATA_OUT  : out   std_logic;
    REGIO_UNKNOWN_ADDR_OUT  : out   std_logic
    );
  
end nXyter_FEE_board;


architecture Behavioral of nXyter_FEE_board is

-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------
  
  -- nXyter related signals
  signal i2c_sda_o                : std_logic; -- I2C SDA
  signal i2c_sda_i                : std_logic;
  signal i2c_scl_o                : std_logic; -- I2C SCL
  signal i2c_scl_i                : std_logic;

  signal spi_sdi                  : std_logic;
  signal spi_sdo                  : std_logic;        



begin

-------------------------------------------------------------------------------
-- Port Maps
-------------------------------------------------------------------------------
  
  -- slave bus signals
  THE_SLAVE_BUS_1: slave_bus
    port map (
      CLK_IN                 => CLK_IN,
      RESET_IN               => RESET_IN,
      
      REGIO_ADDR_IN          => REGIO_ADDR_IN,
      REGIO_DATA_IN          => REGIO_DATA_IN,
      REGIO_DATA_OUT         => REGIO_DATA_OUT,
      REGIO_READ_ENABLE_IN   => REGIO_READ_ENABLE_IN,
      REGIO_WRITE_ENABLE_IN  => REGIO_WRITE_ENABLE_IN,
      REGIO_TIMEOUT_IN       => REGIO_TIMEOUT_IN,
      REGIO_DATAREADY_OUT    => REGIO_DATAREADY_OUT,
      REGIO_WRITE_ACK_OUT    => REGIO_WRITE_ACK_OUT,
      REGIO_NO_MORE_DATA_OUT => REGIO_NO_MORE_DATA_OUT,
      REGIO_UNKNOWN_ADDR_OUT => REGIO_UNKNOWN_ADDR_OUT,

      SDA_IN                 => i2c_sda_i,
      SDA_OUT                => i2c_sda_o,
      SCL_IN                 => i2c_scl_i,
      SCL_OUT                => i2c_scl_o,

      SPI_CS_OUT             => SPI_CSB_OUT,
      SPI_SCK_OUT            => SPI_SCLK_OUT,
      SPI_SDI_IN             => spi_sdi,
      SPI_SDO_OUT            => spi_sdo
      );

  -----------------------------------------------------------------------------
  -- nXyter Signals
  -----------------------------------------------------------------------------
 
  -----------------------------------------------------------------------------
  -- I2C Signals
  -----------------------------------------------------------------------------

  -- SDA line output
  I2C_SDA_INOUT <= '0' when (i2c_sda_o = '0') else 'Z';

  -- SDA line input (wired OR negative logic)
  -- i2c_sda_i <= i2c_sda;

  -- SCL line output
  I2C_SCL_OUT <= '0' when (i2c_scl_o = '0') else 'Z';

  -- SCL line input (wired OR negative logic)
  -- i2c_scl_i <= i2c_scl;

-------------------------------------------------------------------------------
-- END
-------------------------------------------------------------------------------

end Behavioral;
