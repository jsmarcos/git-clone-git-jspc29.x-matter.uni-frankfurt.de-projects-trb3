-----------------------------------------------------------------------------
--
--One  nXyter FEB 
--
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.adcmv3_components.all;
use work.nxyter_components.all;

entity nXyter_FEE_board is
  
  port (
    CLK_IN             : in std_logic;  
    RESET_IN           : in std_logic;  
    
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
    NX_TIMESTAMP_IN    : in std_logic_vector (7 downto 0);
    NX_RESET_OUT       : out std_logic;
    NX_CLK256A_OUT     : out std_logic;
    NX_TESTPULSE_OUT   : out std_logic;

    -- ADC nXyter Pulse Hight Ports
    ADC_FCLK_IN        : in std_logic;
    ADC_DCLK_IN        : in std_logic;
    ADC_SC_CLK32_OUT   : out std_logic;
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
  
  -- Bus Handler
  signal slv_read             : std_logic_vector(8-1 downto 0);
  signal slv_write            : std_logic_vector(8-1 downto 0);
  signal slv_busy             : std_logic_vector(8-1 downto 0);
  signal slv_ack              : std_logic_vector(8-1 downto 0);
  signal slv_addr             : std_logic_vector(8*16-1 downto 0);
  signal slv_data_rd          : std_logic_vector(8*32-1 downto 0);
  signal slv_data_wr          : std_logic_vector(8*32-1 downto 0);
  signal slv_unknown_addr     : std_logic_vector(8-1 downto 0);

  -- I2C Master
  signal i2c_sda_o            : std_logic; -- I2C SDA
  signal i2c_sda_i            : std_logic;
  signal i2c_scl_o            : std_logic; -- I2C SCL
  signal i2c_scl_i            : std_logic;

  -- SPI Interface ADC
  signal spi_sdi              : std_logic;
  signal spi_sdo              : std_logic;        

begin

-------------------------------------------------------------------------------
-- Port Maps
-------------------------------------------------------------------------------

  -- TRBNet Bus Handler
  THE_BUS_HANDLER: trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER         => 3,
      PORT_ADDRESSES      => ( 0 => x"0000", -- Control Register Handler
                               1 => x"0040", -- I2C master
                               2 => x"0100", -- Timestamp Fifo
                               -- 3 => x"d100", -- SPI data memory
                               others => x"0000"),
      PORT_ADDR_MASK      => ( 0 => 3, -- Control Register Handler
                               1 => 0, -- I2C master
                               2 => 1, -- Timestamp Fifo
                               -- 3 => 6,  -- SPI data memory
                               others => 0)
      )
    port map(
      CLK                                 => CLK_IN,
      RESET                               => RESET_IN,
      DAT_ADDR_IN                         => REGIO_ADDR_IN,
      DAT_DATA_IN                         => REGIO_DATA_IN,
      DAT_DATA_OUT                        => REGIO_DATA_OUT,
      DAT_READ_ENABLE_IN                  => REGIO_READ_ENABLE_IN,
      DAT_WRITE_ENABLE_IN                 => REGIO_WRITE_ENABLE_IN,
      DAT_TIMEOUT_IN                      => REGIO_TIMEOUT_IN,
      DAT_DATAREADY_OUT                   => REGIO_DATAREADY_OUT,
      DAT_WRITE_ACK_OUT                   => REGIO_WRITE_ACK_OUT,
      DAT_NO_MORE_DATA_OUT                => REGIO_NO_MORE_DATA_OUT,
      DAT_UNKNOWN_ADDR_OUT                => REGIO_UNKNOWN_ADDR_OUT,

      -- Control Registers
      BUS_READ_ENABLE_OUT(0)              => slv_read(0),
      BUS_WRITE_ENABLE_OUT(0)             => slv_write(0),
      BUS_DATA_OUT(0*32+31 downto 0*32)   => slv_data_wr(0*32+31 downto 0*32),
      BUS_DATA_IN(0*32+31 downto 0*32)    => slv_data_rd(0*32+31 downto 0*32),
      BUS_ADDR_OUT(0*16+2 downto 0*16)    => slv_addr(0*16+2 downto 0*16),
      BUS_ADDR_OUT(0*16+15 downto 0*16+3) => open,
      BUS_TIMEOUT_OUT(0)                  => open,
      BUS_DATAREADY_IN(0)                 => slv_ack(0),
      BUS_WRITE_ACK_IN(0)                 => slv_ack(0),
      BUS_NO_MORE_DATA_IN(0)              => slv_busy(0),
      BUS_UNKNOWN_ADDR_IN(0)              => slv_unknown_addr(0),

      -- I2C master
      BUS_READ_ENABLE_OUT(1)              => slv_read(1),
      BUS_WRITE_ENABLE_OUT(1)             => slv_write(1),
      BUS_DATA_OUT(1*32+31 downto 1*32)   => slv_data_wr(1*32+31 downto 1*32),
      BUS_DATA_IN(1*32+31 downto 1*32)    => slv_data_rd(1*32+31 downto 1*32),
      BUS_ADDR_OUT(1*16+15 downto 1*16)   => open,
      BUS_TIMEOUT_OUT(1)                  => open,
      BUS_DATAREADY_IN(1)                 => slv_ack(1),
      BUS_WRITE_ACK_IN(1)                 => slv_ack(1),
      BUS_NO_MORE_DATA_IN(1)              => slv_busy(1),
      BUS_UNKNOWN_ADDR_IN(1)              => '0',

      -- Timestamp Fifo
      BUS_READ_ENABLE_OUT(2)              => slv_read(2),
      BUS_WRITE_ENABLE_OUT(2)             => slv_write(2),
      BUS_DATA_OUT(2*32+31 downto 2*32)   => slv_data_wr(2*32+31 downto 2*32),
      BUS_DATA_IN(2*32+31 downto 2*32)    => slv_data_rd(2*32+31 downto 2*32),
--      BUS_ADDR_OUT(2*16+0 downto 2*16)    => slv_addr(2*16+0 downto 0*16),
      BUS_ADDR_OUT(2*16+0)                => slv_addr(2*16+0),
      BUS_ADDR_OUT(2*16+15 downto 2*16+1) => open,
      BUS_TIMEOUT_OUT(2)                  => open,
      BUS_DATAREADY_IN(2)                 => slv_ack(2),
      BUS_WRITE_ACK_IN(2)                 => slv_ack(2),
      BUS_NO_MORE_DATA_IN(2)              => slv_busy(2),
      BUS_UNKNOWN_ADDR_IN(2)              => slv_unknown_addr(2),

      ---- SPI control registers
      --BUS_READ_ENABLE_OUT(4)              => slv_read(4),
      --BUS_WRITE_ENABLE_OUT(4)             => slv_write(4),
      --BUS_DATA_OUT(4*32+31 downto 4*32)   => slv_data_wr(4*32+31 downto 4*32),
      --BUS_DATA_IN(4*32+31 downto 4*32)    => slv_data_rd(4*32+31 downto 4*32),
      --BUS_ADDR_OUT(4*16+15 downto 4*16)   => slv_addr(4*16+15 downto 4*16),
      --BUS_TIMEOUT_OUT(4)                  => open,
      --BUS_DATAREADY_IN(4)                 => slv_ack(4),
      --BUS_WRITE_ACK_IN(4)                 => slv_ack(4),
      --BUS_NO_MORE_DATA_IN(4)              => slv_busy(4),
      --BUS_UNKNOWN_ADDR_IN(4)              => '0',

      ---- SPI data memory
      --BUS_READ_ENABLE_OUT(5)              => slv_read(5),
      --BUS_WRITE_ENABLE_OUT(5)             => slv_write(5),
      --BUS_DATA_OUT(5*32+31 downto 5*32)   => slv_data_wr(5*32+31 downto 5*32),
      --BUS_DATA_IN(5*32+31 downto 5*32)    => slv_data_rd(5*32+31 downto 5*32),
      --BUS_ADDR_OUT(5*16+15 downto 5*16)   => slv_addr(5*16+15 downto 5*16),
      --BUS_TIMEOUT_OUT(5)                  => open,
      --BUS_DATAREADY_IN(5)                 => slv_ack(5),
      --BUS_WRITE_ACK_IN(5)                 => slv_ack(5),
      --BUS_NO_MORE_DATA_IN(5)              => slv_busy(5),
      --BUS_UNKNOWN_ADDR_IN(5)              => '0',

      ---- debug
      --STAT_DEBUG          => stat
      STAT_DEBUG          => open
      );


-------------------------------------------------------------------------------
-- Registers
-------------------------------------------------------------------------------
  nxyter_registers_1: nxyter_registers
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,

      SLV_READ_IN          => slv_read(0),
      SLV_WRITE_IN         => slv_write(0),
      SLV_DATA_OUT         => slv_data_rd(0*32+31 downto 0*32),
      SLV_DATA_IN          => slv_data_wr(0*32+31 downto 0*32),
      SLV_ADDR_IN          => slv_addr(0*16+15 downto 0*16),
      SLV_ACK_OUT          => slv_ack(0),
      SLV_NO_MORE_DATA_OUT => slv_busy(0),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(0)
      );

-------------------------------------------------------------------------------
-- I2C master block for accessing the nXyter
-------------------------------------------------------------------------------
  THE_I2C_MASTER: i2c_master
    port map(
      CLK_IN          => CLK_IN,
      RESET_IN        => RESET_IN,
      -- Slave bus
      SLV_READ_IN     => slv_read(1),
      SLV_WRITE_IN    => slv_write(1),
      SLV_BUSY_OUT    => slv_busy(1),
      SLV_ACK_OUT     => slv_ack(1),
      SLV_DATA_IN     => slv_data_wr(1*32+31 downto 1*32),
      SLV_DATA_OUT    => slv_data_rd(1*32+31 downto 1*32),

      -- I2C connections
      SDA_IN          => open,
      SDA_OUT         => open,
      SCL_IN          => open,
      SCL_OUT         => open,

      -- Status lines
      STAT            => open
      );

-------------------------------------------------------------------------------
-- nXyter TimeStamp Read
-------------------------------------------------------------------------------

  nx_timestamp_fifo_read_1: nx_timestamp_fifo_read
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      NX_TIMESTAMP_CLK_IN  => NX_CLK128_IN,
      NX_TIMESTAMP_IN      => NX_TIMESTAMP_IN,
      NX_FRAME_CLOCK_OUT   => open,

      SLV_READ_IN          => slv_read(2),
      SLV_WRITE_IN         => slv_write(2),
      SLV_DATA_OUT         => slv_data_rd(2*32+31 downto 2*32),
      SLV_DATA_IN          => slv_data_wr(2*32+31 downto 2*32),
      SLV_ADDR_IN          => slv_addr(2*16+15 downto 2*16),
      SLV_ACK_OUT          => slv_ack(2),
      SLV_NO_MORE_DATA_OUT => slv_busy(2),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(2)
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
