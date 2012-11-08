-----------------------------------------------------------------------------
--
-- One  nXyter FEB 
--
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.nxyter_components.all;
-- ADCM use work.adcmv3_components.all;

entity nXyter_FEE_board is
  
  port (
    CLK_IN             : in std_logic;  
    RESET_IN           : in std_logic;  
    
    -- I2C Ports
    I2C_SDA_INOUT      : inout std_logic;   -- nXyter I2C fdata line
    I2C_SCL_INOUT      : inout std_logic;   -- nXyter I2C Clock line
    I2C_SM_RESET_OUT   : out std_logic;     -- reset nXyter I2C StateMachine 
    I2C_REG_RESET_OUT  : out std_logic;     -- reset I2C registers to default

    -- ADC SPI
    SPI_SCLK_OUT       : out std_logic;
    SPI_SDIO_INOUT     : inout std_logic;
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
    REGIO_UNKNOWN_ADDR_OUT  : out   std_logic;
    
    -- Debug Signals
    CLK_128_IN              : in    std_logic;
    DEBUG_LINE_OUT          : out   std_logic_vector(15 downto 0)
    );
  
end nXyter_FEE_board;


architecture Behavioral of nXyter_FEE_board is

-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------
  -- Clock 256
  signal clk_256_o            : std_logic;
  
  -- Bus Handler
  signal slv_read             : std_logic_vector(8-1 downto 0);
  signal slv_write            : std_logic_vector(8-1 downto 0);
  signal slv_no_more_data     : std_logic_vector(8-1 downto 0);
  signal slv_ack              : std_logic_vector(8-1 downto 0);
  signal slv_addr             : std_logic_vector(8*16-1 downto 0);
  signal slv_data_rd          : std_logic_vector(8*32-1 downto 0);
  signal slv_data_wr          : std_logic_vector(8*32-1 downto 0);
  signal slv_unknown_addr     : std_logic_vector(8-1 downto 0);

  -- I2C Master
-- ADCM   signal i2c_sda_o            : std_logic;
-- ADCM   signal i2c_sda_i            : std_logic;
-- ADCM   signal i2c_scl_o            : std_logic;
-- ADCM   signal i2c_scl_i            : std_logic;
  signal i2c_sm_reset_o       : std_logic;   
  signal i2c_reg_reset_o      : std_logic;
  
  -- SPI Interface ADC
  signal spi_sdi              : std_logic;
  signal spi_sdo              : std_logic;        

  -- FIFO Read
  signal nx_frame_clock_o     : std_logic;
  signal nx_frame_sync_o      : std_logic;
  
    
  -- Timestamp Handlers
  signal nx_timestamp_o       : std_logic_vector(31 downto 0);

  
begin

-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------
--   DEBUG_LINE_OUT(0)           <= CLK_IN;
--   DEBUG_LINE_OUT(1)           <= clk_256_o;
--   DEBUG_LINE_OUT(2)           <= NX_CLK128_IN;
--   DEBUG_LINE_OUT(3)           <= nx_frame_clock_o;
--   DEBUG_LINE_OUT(4)           <= nx_frame_sync_o;
--   DEBUG_LINE_OUT(7 downto 5)  <= (others => '0');
--   DEBUG_LINE_OUT(15 downto 8) <= NX_TIMESTAMP_IN;
--   DEBUG_LINE_OUT(8)            <= i2c_sda_o;
--   DEBUG_LINE_OUT(9)            <= i2c_sda_i;
--   DEBUG_LINE_OUT(10)           <= i2c_scl_o;
--   DEBUG_LINE_OUT(11)           <= i2c_scl_i;
--  DEBUG_LINE_OUT(15 downto 12) <= (others => '0');

  DEBUG_LINE_OUT(0) <= CLK_IN;
  DEBUG_LINE_OUT(1) <= I2C_SDA_INOUT;
  DEBUG_LINE_OUT(2) <= I2C_SCL_INOUT;
  
  DEBUG_LINE_OUT(7 downto 3) <= (others => '0');
  
-------------------------------------------------------------------------------
-- Port Maps
-------------------------------------------------------------------------------



  -- pll_nx_clk256_1: pll_nx_clk256
  --   port map (
  --     CLK   => CLK_IN,
  --     CLKOP => clk_256_o,
  --     LOCK  => open
  --     );

  -- pll_25_1: pll_25
  --   port map (
  --     CLK   => CLK_IN,
  --     CLKOP => clk_256_o,
  --     LOCK  => open
  --     );
  clk_256_o      <= CLK_128_IN;

  NX_RESET_OUT       <= '0';
  NX_CLK256A_OUT     <= clk_256_o;
  NX_TESTPULSE_OUT   <= '0';

  -- TRBNet Bus Handler
  THE_BUS_HANDLER: trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER         => 4,
      PORT_ADDRESSES      => ( 0 => x"0000",    -- Control Register Handler
                               1 => x"0040",    -- I2C master
                               2 => x"0100",    -- Timestamp Fifo
                               3 => x"0200",    -- Data Buffer
                               -- 3 => x"d100",   -- SPI data memory
                               others => x"0000"),
      PORT_ADDR_MASK      => ( 0 => 3,          -- Control Register Handler
                               1 => 0,          -- I2C master
                               2 => 1,          -- Timestamp Fifo
                               3 => 1,          -- Data Buffer
                               -- 3 => 6,         -- SPI data memory
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
      BUS_NO_MORE_DATA_IN(0)              => slv_no_more_data(0),
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
      BUS_NO_MORE_DATA_IN(1)              => slv_no_more_data(1),
      BUS_UNKNOWN_ADDR_IN(1)              => slv_unknown_addr(1),

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
      BUS_NO_MORE_DATA_IN(2)              => slv_no_more_data(2),
      BUS_UNKNOWN_ADDR_IN(2)              => slv_unknown_addr(2),

      -- DataBuffer
      BUS_READ_ENABLE_OUT(3)              => slv_read(3),
      BUS_WRITE_ENABLE_OUT(3)             => slv_write(3),
      BUS_DATA_OUT(3*32+31 downto 3*32)   => slv_data_wr(3*32+31 downto 3*32),
      BUS_DATA_IN(3*32+31 downto 3*32)    => slv_data_rd(3*32+31 downto 3*32),
--      BUS_ADDR_OUT(3*16+0 downto 2*16)    => slv_addr(3*16+0 downto 0*16),
      BUS_ADDR_OUT(3*16+0)                => slv_addr(3*16+0),
      BUS_ADDR_OUT(3*16+15 downto 3*16+1) => open,
      BUS_TIMEOUT_OUT(3)                  => open,
      BUS_DATAREADY_IN(3)                 => slv_ack(3),
      BUS_WRITE_ACK_IN(3)                 => slv_ack(3),
      BUS_NO_MORE_DATA_IN(3)              => slv_no_more_data(3),
      BUS_UNKNOWN_ADDR_IN(3)              => slv_unknown_addr(3),
      
      ---- SPI control registers
      --BUS_READ_ENABLE_OUT(4)              => slv_read(4),
      --BUS_WRITE_ENABLE_OUT(4)             => slv_write(4),
      --BUS_DATA_OUT(4*32+31 downto 4*32)   => slv_data_wr(4*32+31 downto 4*32),
      --BUS_DATA_IN(4*32+31 downto 4*32)    => slv_data_rd(4*32+31 downto 4*32),
      --BUS_ADDR_OUT(4*16+15 downto 4*16)   => slv_addr(4*16+15 downto 4*16),
      --BUS_TIMEOUT_OUT(4)                  => open,
      --BUS_DATAREADY_IN(4)                 => slv_ack(4),
      --BUS_WRITE_ACK_IN(4)                 => slv_ack(4),
      --BUS_NO_MORE_DATA_IN(4)              => slv_no_more_data(4),
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
      --BUS_NO_MORE_DATA_IN(5)              => slv_no_more_data(5),
      --BUS_UNKNOWN_ADDR_IN(5)              => '0',

      ---- debug
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
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(0),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(0),

      DEBUG_OUT            => open
      );

-------------------------------------------------------------------------------
-- I2C master block for accessing the nXyter
-------------------------------------------------------------------------------
  nx_i2c_master_1: nx_i2c_master
    generic map (
      i2c_speed => x"3e8"
      )
    port map (
      CLK_IN                => CLK_IN,
      RESET_IN              => RESET_IN,
      SDA_INOUT             => I2C_SDA_INOUT,
      SCL_INOUT             => I2C_SCL_INOUT,
      SLV_READ_IN           => slv_read(1),
      SLV_WRITE_IN          => slv_write(1),
      SLV_DATA_OUT          => slv_data_rd(1*32+31 downto 1*32),
      SLV_DATA_IN           => slv_data_wr(1*32+31 downto 1*32),
      SLV_ACK_OUT           => slv_ack(1), 
      SLV_NO_MORE_DATA_OUT  => slv_no_more_data(1),
      SLV_UNKNOWN_ADDR_OUT  => slv_unknown_addr(1),
      DEBUG_OUT(7 downto 0) => DEBUG_LINE_OUT(15 downto 8)
      );


-- ADCM   i2c_master_1: i2c_master
-- ADCM     port map (
-- ADCM       CLK_IN       => CLK_IN,
-- ADCM       RESET_IN     => RESET_IN,
-- ADCM       SLV_READ_IN  => slv_read(1),
-- ADCM       SLV_WRITE_IN => slv_write(1),
-- ADCM       SLV_BUSY_OUT => open,
-- ADCM       SLV_ACK_OUT  => slv_ack(1),
-- ADCM       SLV_DATA_IN  => slv_data_wr(1*32+31 downto 1*32),
-- ADCM       SLV_DATA_OUT => slv_data_rd(1*32+31 downto 1*32),
-- ADCM       SDA_IN       => i2c_sda_i,
-- ADCM       SDA_OUT      => i2c_sda_o,
-- ADCM       SCL_IN       => i2c_scl_i,
-- ADCM       SCL_OUT      => i2c_scl_o,
-- ADCM       STAT         => open
-- ADCM       );
-- ADCM 
-- ADCM   -- I2c Outputs
-- ADCM   I2C_SDA_INOUT <= '0' when (i2c_sda_o = '0') else 'Z';
-- ADCM   i2c_sda_i     <= I2C_SDA_INOUT;
-- ADCM   I2C_SCL_INOUT <= '0' when (i2c_scl_o = '0') else 'Z';
-- ADCM   i2c_scl_i     <= I2C_SCL_INOUT;
  
  i2c_sm_reset_o    <= not '0';
  i2c_reg_reset_o   <= not '0';
  
-------------------------------------------------------------------------------
-- nXyter TimeStamp Read
-------------------------------------------------------------------------------

  nx_timestamp_fifo_read_1: nx_timestamp_fifo_read
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,

      NX_TIMESTAMP_CLK_IN  => NX_CLK128_IN,
      NX_TIMESTAMP_IN      => NX_TIMESTAMP_IN,
      NX_FRAME_CLOCK_OUT   => nx_frame_clock_o,
      NX_FRAME_SYNC_OUT    => nx_frame_sync_o,
      NX_TIMESTAMP_OUT     => nx_timestamp_o,
      
      SLV_READ_IN          => slv_read(2),
      SLV_WRITE_IN         => slv_write(2),
      SLV_DATA_OUT         => slv_data_rd(2*32+31 downto 2*32),
      SLV_DATA_IN          => slv_data_wr(2*32+31 downto 2*32),
      SLV_ADDR_IN          => slv_addr(2*16+15 downto 2*16),
      SLV_ACK_OUT          => slv_ack(2),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(2),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(2),

--      DEBUG_OUT           => DEBUG_LINE_OUT(7 downto 0)
      DEBUG_OUT           => open
      );

-------------------------------------------------------------------------------
-- Data Buffer FIFO
-------------------------------------------------------------------------------
  nx_data_buffer_1: nx_data_buffer
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,

      FIFO_DATA_IN         => nx_timestamp_o,
      FIFO_WRITE_ENABLE_IN => '1',
      FIFO_READ_ENABLE_IN  => '1',
      
      SLV_READ_IN          => slv_read(3),
      SLV_WRITE_IN         => slv_write(3),
      SLV_DATA_OUT         => slv_data_rd(3*32+31 downto 3*32),
      SLV_DATA_IN          => slv_data_wr(3*32+31 downto 3*32),
      SLV_ADDR_IN          => slv_addr(3*16+15 downto 3*16),
      SLV_ACK_OUT          => slv_ack(3),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(3),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(3)
      );


-------------------------------------------------------------------------------
-- nXyter Signals
-------------------------------------------------------------------------------
  
-------------------------------------------------------------------------------
-- I2C Signals
-------------------------------------------------------------------------------

  I2C_SM_RESET_OUT  <= i2c_sm_reset_o;
  I2C_REG_RESET_OUT <= i2c_reg_reset_o;

-------------------------------------------------------------------------------
-- END
-------------------------------------------------------------------------------

end Behavioral;
