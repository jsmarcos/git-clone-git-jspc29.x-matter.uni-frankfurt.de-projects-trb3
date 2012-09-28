library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.ALL;

package adcmv3_components is

-------------------------------------------------------------------------------
-- Components by Michael Boehmer 
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- TRBNet interfaces
-------------------------------------------------------------------------------
component slave_bus
  port (
    CLK_IN                 : in  std_logic;
    RESET_IN               : in  std_logic;
    REGIO_ADDR_IN          : in  std_logic_vector(15 downto 0);
    REGIO_DATA_IN          : in  std_logic_vector(31 downto 0);
    REGIO_DATA_OUT         : out std_logic_vector(31 downto 0);
    REGIO_READ_ENABLE_IN   : in  std_logic;
    REGIO_WRITE_ENABLE_IN  : in  std_logic;
    REGIO_TIMEOUT_IN       : in  std_logic;
    REGIO_DATAREADY_OUT    : out std_logic;
    REGIO_WRITE_ACK_OUT    : out std_logic;
    REGIO_NO_MORE_DATA_OUT : out std_logic;
    REGIO_UNKNOWN_ADDR_OUT : out std_logic;
    SDA_IN                 : in  std_logic;
    SDA_OUT                : out std_logic;
    SCL_IN                 : in  std_logic;
    SCL_OUT                : out std_logic;
    SPI_CS_OUT             : out std_logic;
    SPI_SCK_OUT            : out std_logic;
    SPI_SDI_IN             : in  std_logic;
    SPI_SDO_OUT            : out std_logic);
end component slave_bus;


component slv_register
  generic (
    RESET_VALUE : std_logic_vector(31 downto 0));
  port (
    CLK_IN       : in  std_logic;
    RESET_IN     : in  std_logic;
    BUSY_IN      : in  std_logic;
    SLV_READ_IN  : in  std_logic;
    SLV_WRITE_IN : in  std_logic;
    SLV_BUSY_OUT : out std_logic;
    SLV_ACK_OUT  : out std_logic;
    SLV_DATA_IN  : in  std_logic_vector(31 downto 0);
    SLV_DATA_OUT : out std_logic_vector(31 downto 0);
    REG_DATA_IN  : in  std_logic_vector(31 downto 0);
    REG_DATA_OUT : out std_logic_vector(31 downto 0);
    STAT         : out std_logic_vector(31 downto 0));
end component slv_register;


component slv_ped_thr_mem
  port (
    CLK_IN       : in  std_logic;
    RESET_IN     : in  std_logic;
    SLV_ADDR_IN  : in  std_logic_vector(10 downto 0);
    SLV_READ_IN  : in  std_logic;
    SLV_WRITE_IN : in  std_logic;
    SLV_ACK_OUT  : out std_logic;
    SLV_DATA_IN  : in  std_logic_vector(31 downto 0);
    SLV_DATA_OUT : out std_logic_vector(31 downto 0);
    BACKPLANE_IN : in  std_logic_vector(2 downto 0);
    MEM_CLK_IN   : in  std_logic;
    MEM_ADDR_IN  : in  std_logic_vector(6 downto 0);
    MEM_0_D_OUT  : out std_logic_vector(17 downto 0);
    MEM_1_D_OUT  : out std_logic_vector(17 downto 0);
    MEM_2_D_OUT  : out std_logic_vector(17 downto 0);
    MEM_3_D_OUT  : out std_logic_vector(17 downto 0);
    MEM_4_D_OUT  : out std_logic_vector(17 downto 0);
    MEM_5_D_OUT  : out std_logic_vector(17 downto 0);
    MEM_6_D_OUT  : out std_logic_vector(17 downto 0);
    MEM_7_D_OUT  : out std_logic_vector(17 downto 0);
    MEM_8_D_OUT  : out std_logic_vector(17 downto 0);
    MEM_9_D_OUT  : out std_logic_vector(17 downto 0);
    MEM_10_D_OUT : out std_logic_vector(17 downto 0);
    MEM_11_D_OUT : out std_logic_vector(17 downto 0);
    MEM_12_D_OUT : out std_logic_vector(17 downto 0);
    MEM_13_D_OUT : out std_logic_vector(17 downto 0);
    MEM_14_D_OUT : out std_logic_vector(17 downto 0);
    MEM_15_D_OUT : out std_logic_vector(17 downto 0);
    STAT         : out std_logic_vector(31 downto 0));
end component slv_ped_thr_mem;

-------------------------------------------------------------------------------
-- I2C INterfaces
-------------------------------------------------------------------------------

component i2c_master
  port (
    CLK_IN       : in  std_logic;
    RESET_IN     : in  std_logic;
    SLV_READ_IN  : in  std_logic;
    SLV_WRITE_IN : in  std_logic;
    SLV_BUSY_OUT : out std_logic;
    SLV_ACK_OUT  : out std_logic;
    SLV_DATA_IN  : in  std_logic_vector(31 downto 0);
    SLV_DATA_OUT : out std_logic_vector(31 downto 0);
    SDA_IN       : in  std_logic;
    SDA_OUT      : out std_logic;
    SCL_IN       : in  std_logic;
    SCL_OUT      : out std_logic;
    STAT         : out std_logic_vector(31 downto 0));
end component i2c_master;


component I2C_GSTART
  port (
    CLK_IN       : in  std_logic;
    RESET_IN     : in  std_logic;
    START_IN     : in  std_logic;
    DOSTART_IN   : in  std_logic;
    I2C_SPEED_IN : in  std_logic_vector(7 downto 0);
    SDONE_OUT    : out std_logic;
    SOK_OUT      : out std_logic;
    SDA_IN       : in  std_logic;
    SCL_IN       : in  std_logic;
    R_SCL_OUT    : out std_logic;
    S_SCL_OUT    : out std_logic;
    R_SDA_OUT    : out std_logic;
    S_SDA_OUT    : out std_logic;
    BSM_OUT      : out std_logic_vector(3 downto 0));
end component I2C_GSTART;


component i2c_sendb
  port (
    CLK_IN       : in  std_logic;
    RESET_IN     : in  std_logic;
    DOBYTE_IN    : in  std_logic;
    I2C_SPEED_IN : in  std_logic_vector(7 downto 0);
    I2C_BYTE_IN  : in  std_logic_vector(8 downto 0);
    I2C_BACK_OUT : out std_logic_vector(8 downto 0);
    SDA_IN       : in  std_logic;
    R_SDA_OUT    : out std_logic;
    S_SDA_OUT    : out std_logic;
    R_SCL_OUT    : out std_logic;
    S_SCL_OUT    : out std_logic;
    BDONE_OUT    : out std_logic;
    BOK_OUT      : out std_logic;
    BSM_OUT      : out std_logic_vector(3 downto 0));
end component i2c_sendb;


component i2c_slim
  port (
    CLK_IN       : in  std_logic;
    RESET_IN     : in  std_logic;
    I2C_GO_IN    : in  std_logic;
    ACTION_IN    : in  std_logic;
    I2C_SPEED_IN : in  std_logic_vector(5 downto 0);
    I2C_ADR_IN   : in  std_logic_vector(7 downto 0);
    I2C_CMD_IN   : in  std_logic_vector(7 downto 0);
    I2C_DW_IN    : in  std_logic_vector(7 downto 0);
    I2C_DR_OUT   : out std_logic_vector(7 downto 0);
    STATUS_OUT   : out std_logic_vector(7 downto 0);
    I2C_BUSY_OUT : out std_logic;
    SDA_IN       : in  std_logic;
    SDA_OUT      : out std_logic;
    SCL_IN       : in  std_logic;
    SCL_OUT      : out std_logic;
    STAT         : out std_logic_vector(31 downto 0));
end component i2c_slim;

end package;
