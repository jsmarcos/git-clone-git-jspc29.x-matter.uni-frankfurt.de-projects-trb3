----------------------------------------------------------------------------
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
use work.trb3_components.all;
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
  signal slv_read             : std_logic_vector(10-1 downto 0);
  signal slv_write            : std_logic_vector(10-1 downto 0);
  signal slv_no_more_data     : std_logic_vector(10-1 downto 0);
  signal slv_ack              : std_logic_vector(10-1 downto 0);
  signal slv_addr             : std_logic_vector(10*16-1 downto 0);
  signal slv_data_rd          : std_logic_vector(10*32-1 downto 0);
  signal slv_data_wr          : std_logic_vector(10*32-1 downto 0);
  signal slv_unknown_addr     : std_logic_vector(10-1 downto 0);

  -- TRB Register
  signal i2c_sm_reset_o       : std_logic;   
  signal nx_ts_reset_1        : std_logic;
  signal nx_ts_reset_2        : std_logic;
  signal nx_ts_reset_o        : std_logic;
  signal i2c_reg_reset_o      : std_logic;
  
  -- SPI Interface ADC
  signal spi_sdi              : std_logic;
  signal spi_sdo              : std_logic;        

  -- Timestamp FIFO Read
  signal nx_timestamp         : std_logic_vector(31 downto 0);
  signal nx_new_timestamp     : std_logic;
  signal nx_frame_clock_o     : std_logic;
       
  -- Timestamp Decode Handlers
  signal timestamp_data       : std_logic_vector(31 downto 0);
  signal timestamp            : unsigned(13 downto 0);
  signal timestamp_channel_id : unsigned(6 downto 0);
  signal timestamp_status     : std_logic_vector(1 downto 0);
  signal timestamp_valid      : std_logic;

  signal nx_token_return      : std_logic;
  signal nx_nomore_data       : std_logic;

  -- Timestamp Process
  signal ts_data              : std_logic_vector(31 downto 0);
  signal ts_data_clk          : std_logic;
  signal data_fifo_reset      : std_logic;
  
  -- FPGA Timestamp
  signal timestamp_trigger    : unsigned(11 downto 0);
  signal nx_timestamp_sync    : std_logic;

  -- Data Buffer
  signal data_buffer_reset    : std_logic;
    
  -- Trigger Handler
  signal trigger_release      : std_logic;
  signal trigger_ack          : std_logic;
  signal timestamp_hold       : std_logic;
  signal trigger_busy         : std_logic;
  
  -- Trigger Generator
  signal trigger              : std_logic;
  signal nx_testpulse_o       : std_logic;


  -- ADC FIFO Entity
--  signal adc_fclk_i           : std_logic;
--  signal adc_dclk_i           : std_logic;
--  signal adc_sc_clk32_o       : std_logic;
--  signal adc_a_i              : std_logic;
--  signal adc_b_i              : std_logic;
--  signal adc_nx_i             : std_logic;
--  signal adc_d_i              : std_logic;
--
--  signal adc_ref_clk          : std_logic;
--  signal adc_10MHz_clock      : std_logic;
--
--  signal adc_dat_clk          : std_logic;
--  signal adc_restart          : std_logic;
--  signal adc_clk_o            : std_logic;
--
--  signal adc_data_i           : std_logic_vector(7 downto 0);
--  signal adc_dat_clk_i        : std_logic_vector(1 downto 0);
--  signal adc_fco_clk_i        : std_logic_vector(1 downto 0);
--  
--  signal adc_data_word        : std_logic_vector(95 downto 0);
--  signal adc_fco              : std_logic_vector(23 downto 0);
--  signal adc_data_valid       : std_logic_vector(1 downto 0);
  
begin

-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------
--   DEBUG_LINE_OUT(0)            <= CLK_IN;
--   DEBUG_LINE_OUT(1)            <= trigger_ack;
--   DEBUG_LINE_OUT(2)            <= nx_ts_reset_o;
--   DEBUG_LINE_OUT(3)            <= nx_testpulse_o;
--   DEBUG_LINE_OUT(4)            <= nx_new_timestamp;
--   DEBUG_LINE_OUT(5)            <= timestamp_valid;
--   DEBUG_LINE_OUT(6)            <= timestamp_hold;
--   DEBUG_LINE_OUT(7)            <= nx_token_return;
--   DEBUG_LINE_OUT(8)            <= nx_nomore_data;
--   DEBUG_LINE_OUT(9)            <= trigger;
--   DEBUG_LINE_OUT(10)           <= trigger_busy;
--   DEBUG_LINE_OUT(11)           <= ts_data_clk;
--   DEBUG_LINE_OUT(12)           <= data_fifo_reset;
-- 
--   DEBUG_LINE_OUT(14 downto 13) <= timestamp_status;
--   DEBUG_LINE_OUT(15)           <= slv_ack(3);
  
  --DEBUG_LINE_OUT(0)            <= CLK_IN;
  --DEBUG_LINE_OUT(1)            <= trigger;
  --DEBUG_LINE_OUT(2)            <= trigger_ack;
  --DEBUG_LINE_OUT(3)            <= trigger_busy;
  --DEBUG_LINE_OUT(4)            <= nx_new_timestamp;
  --DEBUG_LINE_OUT(5)            <= timestamp_valid;
  --DEBUG_LINE_OUT(6)            <= nx_token_return;
  --DEBUG_LINE_OUT(7)            <= nx_nomore_data;

--  DEBUG_LINE_OUT(4)            <= '0';
--  DEBUG_LINE_OUT(5)            <= '0';
--  DEBUG_LINE_OUT(6)            <= '0';
--  DEBUG_LINE_OUT(7)            <= '0';
--  
--  
--  DEBUG_LINE_OUT(8)            <= ADC_FCLK_IN;        
--  DEBUG_LINE_OUT(9)            <= ADC_DCLK_IN;        
--  DEBUG_LINE_OUT(10)           <= ADC_SC_CLK32_OUT;
--  DEBUG_LINE_OUT(11)           <= ADC_A_IN;
--  DEBUG_LINE_OUT(12)           <= ADC_B_IN;
--  DEBUG_LINE_OUT(13)           <= ADC_NX_IN;  
--  DEBUG_LINE_OUT(14)           <= ADC_D_IN;  
--  DEBUG_LINE_OUT(15)           <= '0';
  
  --DEBUG_LINE_OUT(15 downto 8) <= (others => '0');
  

-------------------------------------------------------------------------------
-- Port Maps
-------------------------------------------------------------------------------

  pll_nx_clk256_1: pll_nx_clk256
    port map (
      CLK   => CLK_IN,
      CLKOP => clk_256_o,
      LOCK  => open
      );

  NX_CLK256A_OUT     <= clk_256_o;


  THE_BUS_HANDLER: trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER         => 9,

      PORT_ADDRESSES      => ( 0 => x"0100",    -- Control Register Handler
                               1 => x"0040",    -- I2C Master
                               2 => x"0500",    -- Timestamp Fifo
                               3 => x"0600",    -- Data Buffer
                               4 => x"0060",    -- SPI Master
                               5 => x"0140",    -- Trigger Generator
                               6 => x"0120",    -- Timestamp Decode
                               7 => x"0160",    -- Trigger Handler
                               8 => x"0180",    -- Timestamp Process
                               others => x"0000"),

      PORT_ADDR_MASK      => ( 0 => 3,          -- Control Register Handler
                               1 => 0,          -- I2C master
                               2 => 2,          -- Timestamp Fifo
                               3 => 1,          -- Data Buffer
                               4 => 0,          -- SPI Master
                               5 => 3,          -- Trigger Generator
                               6 => 4,          -- Timestamp Decode
                               7 => 1,          -- Trigger Handler
                               8 => 4,          -- Timestamp Process
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
      BUS_ADDR_OUT(2*16+1 downto 2*16)    => slv_addr(2*16+1 downto 2*16),
      BUS_ADDR_OUT(2*16+15 downto 2*16+2) => open,
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
      BUS_ADDR_OUT(3*16+0)                => slv_addr(3*16+0),
      BUS_ADDR_OUT(3*16+15 downto 3*16+1) => open,
      BUS_TIMEOUT_OUT(3)                  => open,
      BUS_DATAREADY_IN(3)                 => slv_ack(3),
      BUS_WRITE_ACK_IN(3)                 => slv_ack(3),
      BUS_NO_MORE_DATA_IN(3)              => slv_no_more_data(3),
      BUS_UNKNOWN_ADDR_IN(3)              => slv_unknown_addr(3),

      -- SPI master
      BUS_READ_ENABLE_OUT(4)              => slv_read(4),
      BUS_WRITE_ENABLE_OUT(4)             => slv_write(4),
      BUS_DATA_OUT(4*32+31 downto 4*32)   => slv_data_wr(4*32+31 downto 4*32),
      BUS_DATA_IN(4*32+31 downto 4*32)    => slv_data_rd(4*32+31 downto 4*32),
      BUS_ADDR_OUT(4*16+15 downto 4*16)   => open,
      BUS_TIMEOUT_OUT(4)                  => open,
      BUS_DATAREADY_IN(4)                 => slv_ack(4),
      BUS_WRITE_ACK_IN(4)                 => slv_ack(4),
      BUS_NO_MORE_DATA_IN(4)              => slv_no_more_data(4),
      BUS_UNKNOWN_ADDR_IN(4)              => slv_unknown_addr(4),

      -- Trigger Generator
      BUS_READ_ENABLE_OUT(5)              => slv_read(5),
      BUS_WRITE_ENABLE_OUT(5)             => slv_write(5),
      BUS_DATA_OUT(5*32+31 downto 5*32)   => slv_data_wr(5*32+31 downto 5*32),
      BUS_DATA_IN(5*32+31 downto 5*32)    => slv_data_rd(5*32+31 downto 5*32),
      BUS_ADDR_OUT(5*16+2 downto 5*16)    => slv_addr(5*16+2 downto 5*16),
      BUS_ADDR_OUT(5*16+15 downto 5*16+3) => open,
      BUS_TIMEOUT_OUT(5)                  => open,
      BUS_DATAREADY_IN(5)                 => slv_ack(5),
      BUS_WRITE_ACK_IN(5)                 => slv_ack(5),
      BUS_NO_MORE_DATA_IN(5)              => slv_no_more_data(5),
      BUS_UNKNOWN_ADDR_IN(5)              => slv_unknown_addr(5),

      -- Timestamp Decode
      BUS_READ_ENABLE_OUT(6)              => slv_read(6),
      BUS_WRITE_ENABLE_OUT(6)             => slv_write(6),
      BUS_DATA_OUT(6*32+31 downto 6*32)   => slv_data_wr(6*32+31 downto 6*32),
      BUS_DATA_IN(6*32+31 downto 6*32)    => slv_data_rd(6*32+31 downto 6*32),
      BUS_ADDR_OUT(6*16+4 downto 6*16)    => slv_addr(6*16+4 downto 6*16),
      BUS_ADDR_OUT(6*16+15 downto 6*16+5) => open,
      BUS_TIMEOUT_OUT(6)                  => open,
      BUS_DATAREADY_IN(6)                 => slv_ack(6),
      BUS_WRITE_ACK_IN(6)                 => slv_ack(6),
      BUS_NO_MORE_DATA_IN(6)              => slv_no_more_data(6),
      BUS_UNKNOWN_ADDR_IN(6)              => slv_unknown_addr(6),

      -- Trigger Handler
      BUS_READ_ENABLE_OUT(7)              => slv_read(7),
      BUS_WRITE_ENABLE_OUT(7)             => slv_write(7),
      BUS_DATA_OUT(7*32+31 downto 7*32)   => slv_data_wr(7*32+31 downto 7*32),
      BUS_DATA_IN(7*32+31 downto 7*32)    => slv_data_rd(7*32+31 downto 7*32),
      BUS_ADDR_OUT(7*16+0)                => slv_addr(7*16+0),
      BUS_ADDR_OUT(7*16+15 downto 7*16+1) => open,
      BUS_TIMEOUT_OUT(7)                  => open,
      BUS_DATAREADY_IN(7)                 => slv_ack(7),
      BUS_WRITE_ACK_IN(7)                 => slv_ack(7),
      BUS_NO_MORE_DATA_IN(7)              => slv_no_more_data(7),
      BUS_UNKNOWN_ADDR_IN(7)              => slv_unknown_addr(7),

      -- Timestamp Process
      BUS_READ_ENABLE_OUT(8)              => slv_read(8),
      BUS_WRITE_ENABLE_OUT(8)             => slv_write(8),
      BUS_DATA_OUT(8*32+31 downto 8*32)   => slv_data_wr(8*32+31 downto 8*32),
      BUS_DATA_IN(8*32+31 downto 8*32)    => slv_data_rd(8*32+31 downto 8*32),
      BUS_ADDR_OUT(8*16+3 downto 8*16)    => slv_addr(8*16+3 downto 8*16),
      BUS_ADDR_OUT(8*16+15 downto 8*16+4) => open,
      BUS_TIMEOUT_OUT(8)                  => open,
      BUS_DATAREADY_IN(8)                 => slv_ack(8),
      BUS_WRITE_ACK_IN(8)                 => slv_ack(8),
      BUS_NO_MORE_DATA_IN(8)              => slv_no_more_data(8),
      BUS_UNKNOWN_ADDR_IN(8)              => slv_unknown_addr(8),

      ---- debug
      STAT_DEBUG          => open
      );


-------------------------------------------------------------------------------
-- Registers
-------------------------------------------------------------------------------
  nxyter_registers_1: nxyter_registers
    port map (
      CLK_IN                 => CLK_IN,
      RESET_IN               => RESET_IN,
                             
      SLV_READ_IN            => slv_read(0),
      SLV_WRITE_IN           => slv_write(0),
      SLV_DATA_OUT           => slv_data_rd(0*32+31 downto 0*32),
      SLV_DATA_IN            => slv_data_wr(0*32+31 downto 0*32),
      SLV_ADDR_IN            => slv_addr(0*16+15 downto 0*16),
      SLV_ACK_OUT            => slv_ack(0),
      SLV_NO_MORE_DATA_OUT   => slv_no_more_data(0),
      SLV_UNKNOWN_ADDR_OUT   => slv_unknown_addr(0),
      I2C_SM_RESET_OUT       => i2c_sm_reset_o,
      I2C_REG_RESET_OUT      => i2c_reg_reset_o,
      NX_TS_RESET_OUT        => nx_ts_reset_1,
      --DEBUG_OUT(7 downto 0)  => DEBUG_LINE_OUT(15 downto 8)
      DEBUG_OUT              => open
      );

-------------------------------------------------------------------------------
-- I2C master block for accessing the nXyter
-------------------------------------------------------------------------------

  nx_i2c_master_1: nx_i2c_master
    generic map (
      I2C_SPEED => x"3e8"
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
      -- DEBUG_OUT          => DEBUG_LINE_OUT
      DEBUG_OUT             => open
      );

-------------------------------------------------------------------------------
-- SPI master block to access the ADC
-------------------------------------------------------------------------------
  
  adc_spi_master_1: adc_spi_master
    generic map (
      SPI_SPEED => x"32"
      )
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      SCLK_OUT             => SPI_SCLK_OUT,
      SDIO_INOUT           => SPI_SDIO_INOUT,
      CSB_OUT              => SPI_CSB_OUT,
      SLV_READ_IN          => slv_read(4),
      SLV_WRITE_IN         => slv_write(4),
      SLV_DATA_OUT         => slv_data_rd(4*32+31 downto 4*32),
      SLV_DATA_IN          => slv_data_wr(4*32+31 downto 4*32),
      SLV_ACK_OUT          => slv_ack(4), 
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(4), 
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(4),
      -- DEBUG_OUT            => DEBUG_LINE_OUT
      DEBUG_OUT            => open
      );

-------------------------------------------------------------------------------
-- FPGA Timestamp
-------------------------------------------------------------------------------
  
  nx_fpga_timestamp_1: nx_fpga_timestamp
    port map (
      CLK_IN                => clk_256_o,
      RESET_IN              => RESET_IN,
      TIMESTAMP_SYNC_IN     => nx_ts_reset_o,
      TRIGGER_IN            => timestamp_hold,
      TIMESTAMP_OUT         => timestamp_trigger,
      NX_TIMESTAMP_SYNC_OUT => nx_timestamp_sync,
      SLV_READ_IN           => open,
      SLV_WRITE_IN          => open,
      SLV_DATA_OUT          => open,
      SLV_DATA_IN           => open,
      SLV_ACK_OUT           => open,
      SLV_NO_MORE_DATA_OUT  => open,
      SLV_UNKNOWN_ADDR_OUT  => open,
      -- DEBUG_OUT             => DEBUG_LINE_OUT
      DEBUG_OUT             => open
      );

-------------------------------------------------------------------------------
-- Trigger Handler
-------------------------------------------------------------------------------

  nx_trigger_handler_1: nx_trigger_handler
    port map (
      CLK_IN                => CLK_IN,
      RESET_IN              => RESET_IN,
      TRIGGER_IN            => trigger,
      TRIGGER_RELEASE_IN    => not trigger_release,
      TRIGGER_OUT           => trigger_ack,
      TIMESTAMP_HOLD_OUT    => timestamp_hold,
      TRIGGER_BUSY_OUT      => trigger_busy,
      SLV_READ_IN           => slv_read(7),
      SLV_WRITE_IN          => slv_write(7),
      SLV_DATA_OUT          => slv_data_rd(7*32+31 downto 7*32),
      SLV_DATA_IN           => slv_data_wr(7*32+31 downto 7*32),
      SLV_ADDR_IN           => slv_addr(7*16+15 downto 7*16),
      SLV_ACK_OUT           => slv_ack(7),
      SLV_NO_MORE_DATA_OUT  => slv_no_more_data(7),
      SLV_UNKNOWN_ADDR_OUT  => slv_unknown_addr(7),
      -- DEBUG_OUT           => DEBUG_LINE_OUT
      DEBUG_OUT             => open
      );
  
-------------------------------------------------------------------------------
-- NX Trigger Generator
-------------------------------------------------------------------------------

  nx_trigger_generator_1: nx_trigger_generator
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      TRIGGER_OUT          => trigger,
      TS_RESET_OUT         => nx_ts_reset_2,
      TESTPULSE_OUT        => nx_testpulse_o,
      SLV_READ_IN          => slv_read(5),
      SLV_WRITE_IN         => slv_write(5),
      SLV_DATA_OUT         => slv_data_rd(5*32+31 downto 5*32),
      SLV_DATA_IN          => slv_data_wr(5*32+31 downto 5*32),
      SLV_ADDR_IN          => slv_addr(5*16+15 downto 5*16),
      SLV_ACK_OUT          => slv_ack(5),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(5),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(5),
      -- DEBUG_OUT            => DEBUG_LINE_OUT
      DEBUG_OUT            => open
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
      NX_FRAME_CLOCK_OUT   => nx_frame_clock_o,
      NX_TIMESTAMP_OUT     => nx_timestamp,
      NX_NEW_TIMESTAMP_OUT => nx_new_timestamp,
      SLV_READ_IN          => slv_read(2),
      SLV_WRITE_IN         => slv_write(2),
      SLV_DATA_OUT         => slv_data_rd(2*32+31 downto 2*32),
      SLV_DATA_IN          => slv_data_wr(2*32+31 downto 2*32),
      SLV_ADDR_IN          => slv_addr(2*16+15 downto 2*16),
      SLV_ACK_OUT          => slv_ack(2),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(2),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(2),

      -- DEBUG_OUT            => DEBUG_LINE_OUT
      DEBUG_OUT            => open
      );


-------------------------------------------------------------------------------
-- Timestamp Decoder and Valid Data Filter
-------------------------------------------------------------------------------

  nx_timestamp_decode_1: nx_timestamp_decode
    port map (
      CLK_IN                => CLK_IN,
      RESET_IN              => RESET_IN,
      NX_NEW_TIMESTAMP_IN   => nx_new_timestamp,
      NX_TIMESTAMP_IN       => nx_timestamp,

      TIMESTAMP_OUT         => timestamp,
      CHANNEL_OUT           => timestamp_channel_id,
      TIMESTAMP_STATUS_OUT  => timestamp_status,
      TIMESTAMP_VALID_OUT   => timestamp_valid,
      NX_TOKEN_RETURN_OUT   => nx_token_return,
      NX_NOMORE_DATA_OUT    => nx_nomore_data,
      
      SLV_READ_IN           => slv_read(6),
      SLV_WRITE_IN          => slv_write(6),
      SLV_DATA_OUT          => slv_data_rd(6*32+31 downto 6*32),
      SLV_DATA_IN           => slv_data_wr(6*32+31 downto 6*32),
      SLV_ADDR_IN           => slv_addr(6*16+15 downto 6*16),
      SLV_ACK_OUT           => slv_ack(6),
      SLV_NO_MORE_DATA_OUT  => slv_no_more_data(6),
      SLV_UNKNOWN_ADDR_OUT  => slv_unknown_addr(6),
      --DEBUG_OUT            => DEBUG_OUT
      DEBUG_OUT           => open
      );

-------------------------------------------------------------------------------
-- NX Timestamp Process
-------------------------------------------------------------------------------

  nx_timestamp_process_1: nx_timestamp_process
    port map (
      CLK_IN                 => CLK_IN,
      RESET_IN               => RESET_IN,

      TIMESTAMP_CLK_IN       => timestamp_valid,
      NX_TOKEN_RETURN_IN     => nx_token_return,
      NX_NOMORE_DATA_IN      => nx_nomore_data,
      TIMESTAMP_IN           => timestamp,
      CHANNEL_IN             => timestamp_channel_id,
      TIMESTAMP_STATUS_IN    => timestamp_status,
      TIMESTAMP_REF_IN       => timestamp_trigger,
      TRIGGER_IN             => trigger_ack,

      PROCESS_BUSY_OUT       => trigger_release,
      DATA_OUT               => ts_data,
      DATA_CLK_OUT           => ts_data_clk,
      DATA_FIFO_RESET_OUT    => data_fifo_reset,

      SLV_READ_IN            => slv_read(8),
      SLV_WRITE_IN           => slv_write(8),
      SLV_DATA_OUT           => slv_data_rd(8*32+31 downto 8*32),
      SLV_DATA_IN            => slv_data_wr(8*32+31 downto 8*32),
      SLV_ADDR_IN            => slv_addr(8*16+15 downto 8*16),
      SLV_ACK_OUT            => slv_ack(8),
      SLV_NO_MORE_DATA_OUT   => slv_no_more_data(8),
      SLV_UNKNOWN_ADDR_OUT   => slv_unknown_addr(8),
      -- DEBUG_OUT(7 downto 0)  => DEBUG_LINE_OUT(15 downto 8),
      -- DEBUG_OUT(15 downto 8) => open
      DEBUG_OUT(15 downto 0) => open
      );

-------------------------------------------------------------------------------
-- Data Buffer FIFO
-------------------------------------------------------------------------------

  nx_data_buffer_1: nx_data_buffer
    port map (
      CLK_IN                => CLK_IN,
      RESET_IN              => data_buffer_reset,
      DATA_IN               => ts_data,
      DATA_CLK_IN           => ts_data_clk,
      
      SLV_READ_IN           => slv_read(3),
      SLV_WRITE_IN          => slv_write(3),
      SLV_DATA_OUT          => slv_data_rd(3*32+31 downto 3*32),
      SLV_DATA_IN           => slv_data_wr(3*32+31 downto 3*32),
      SLV_ADDR_IN           => slv_addr(3*16+15 downto 3*16),
      SLV_ACK_OUT           => slv_ack(3),
      SLV_NO_MORE_DATA_OUT  => slv_no_more_data(3),
      SLV_UNKNOWN_ADDR_OUT  => slv_unknown_addr(3),

      --DEBUG_OUT            => DEBUG_LINE_OUT
      DEBUG_OUT            => open
      );

  data_buffer_reset <= RESET_IN or data_fifo_reset;

-------------------------------------------------------------------------------
-- ADC 9228 Handler
-------------------------------------------------------------------------------

--   adc_ad9222_1: entity work.adc_ad9222
--     generic map (
--       CHANNELS => 4,
--       DEVICES  => 1,
--       RESOLUTION => 12
--       )
--     port map (
--       CLK                        => CLK_IN,
--       CLK_ADCREF                 => nx_frame_clock_o,  -- adc_ref_clk,
--       CLK_ADCDAT                 => nx_frame_clock_o, -- adc_dat_clk,
--       RESTART_IN                 => '0', -- adc_restart,
--       ADCCLK_OUT                 => ADC_SC_CLK32_OUT, -- adc_sc_clk32_o,
--       ADC_DATA(0)                => ADC_A_IN, -- adc_data_i,
--       ADC_DATA(1)                => ADC_B_IN, -- adc_data_i,
--       ADC_DATA(2)                => ADC_NX_IN, -- adc_data_i,
--       ADC_DATA(3)                => ADC_D_IN, -- adc_data_i,
--       ADC_DCO(0)                 => ADC_DCLK_IN, -- adc_dat_clk_i,
--       ADC_FCO(0)                 => ADC_FCLK_IN, -- adc_fco_clk_i,
--       DATA_OUT(0)                => DEBUG_LINE_OUT(0), -- adc_data_word,
--       FCO_OUT(0)                 => DEBUG_LINE_OUT(1), -- adc_fco,
--       DATA_VALID_OUT(0)          => DEBUG_LINE_OUT(2), -- adc_data_valid,
--       DEBUG                      => open
--       );

-------------------------------------------------------------------------------
-- nXyter Signals
-------------------------------------------------------------------------------
  nx_ts_reset_o     <= nx_ts_reset_1 or nx_ts_reset_2; 
  NX_RESET_OUT      <= not nx_ts_reset_o;
  NX_TESTPULSE_OUT  <= nx_testpulse_o;

-------------------------------------------------------------------------------
-- ADC Signals
-------------------------------------------------------------------------------


  
-------------------------------------------------------------------------------
-- I2C Signals
-------------------------------------------------------------------------------

  I2C_SM_RESET_OUT  <= not i2c_sm_reset_o;
  I2C_REG_RESET_OUT <= not i2c_reg_reset_o;
  
-------------------------------------------------------------------------------
-- END
-------------------------------------------------------------------------------

end Behavioral;
