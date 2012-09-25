-----------------------------------------------------------------------------
--
--One  nXyter FEB 
--
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nXyter_FEE_BOARD is
  
  port (
    CLK : in std_logic_vector;          -- Clock
    RESET : in std_logic_vector;        -- RESET

    -- ADC
    ADC_FCLK_IN    : in std_logic;
    ADC_DCLK_IN    : in std_logic;

    SC_CLK32_IN    : in std_logic;
    
    ADC_A_IN       : in std_logic;
    ADC_B_IN       : in std_logic;
    ADC_NX_IN      : in std_logic;
    ADC_D_IN       : in std_logic;        

    -- ADC SPI
    CBS_OUT        : out std_logic;
    SDIO_MUX_OUT   : out std_logic;
    SCLK_OUT       : out std_logic;
    
    -- nXyter
    NX_CLK128_IN   : in std_logic;
    NX_IN          : in std_logic_vector (7 downto 0);
    RESET_OUT      : out std_logic;
    CLK256A_OUT    : out std_logic;
    TESTPULSE_OUT  : out std_logic;

    -- I2C
    SDA_MUX_OUT    : out std_logic;
    SCI_OUT        : out std_logic;
    I2C_RESET_OUT  : out std_logic
    REG_RESET      : out std_logic
    
end nXyter_FEE_BOARD;

