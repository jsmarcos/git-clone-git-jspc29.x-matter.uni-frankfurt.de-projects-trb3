library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package adcmv3_components is

-------------------------------------------------------------------------------
-- Components by Michael Boehmer 
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- TRBNet interfaces
-------------------------------------------------------------------------------

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
    MEM_CLK_IN   : in  std_logic;
    MEM_ADDR_IN  : in  std_logic_vector(6 downto 0);
    MEM_0_D_OUT  : out std_logic_vector(17 downto 0);
    STAT         : out std_logic_vector(31 downto 0));
end component;

component ped_thr_true
  port (
    DataInA  : in  std_logic_vector(17 downto 0);
    DataInB  : in  std_logic_vector(17 downto 0);
    AddressA : in  std_logic_vector(6 downto 0);
    AddressB : in  std_logic_vector(6 downto 0);
    ClockA   : in  std_logic;
    ClockB   : in  std_logic;
    ClockEnA : in  std_logic;
    ClockEnB : in  std_logic;
    WrA      : in  std_logic;
    WrB      : in  std_logic;
    ResetA   : in  std_logic;
    ResetB   : in  std_logic;
    QA       : out std_logic_vector(17 downto 0);
    QB       : out std_logic_vector(17 downto 0));
end component;

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
    STAT         : out std_logic_vector(31 downto 0)
    );
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
    I2C_SPEED_IN : in  std_logic_vector(8 downto 0);
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
    I2C_SPEED_IN : in  std_logic_vector(8 downto 0);
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
