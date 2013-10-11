---------------------------------------------------------------------------
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

entity nXyter_FEE_board is
  generic (
    BOARD_ID : std_logic_vector(15 downto 0) := x"ffff"
    );
  port (
    CLK_IN                     : in std_logic;  
    RESET_IN                   : in std_logic;
    CLK_NX_IN                  : in std_logic;
    CLK_ADC_IN                 : in std_logic;
    TRIGGER_OUT                : out std_logic;

    -- I2C Ports                
    I2C_SDA_INOUT              : inout std_logic;   -- nXyter I2C fdata line
    I2C_SCL_INOUT              : inout std_logic;   -- nXyter I2C Clock line
    I2C_SM_RESET_OUT           : out std_logic;     -- reset nXyter I2C SMachine 
    I2C_REG_RESET_OUT          : out std_logic;     -- reset I2C registers 
                                
    -- ADC SPI                  
    SPI_SCLK_OUT               : out std_logic;
    SPI_SDIO_INOUT             : inout std_logic;
    SPI_CSB_OUT                : out std_logic;    
                                
    -- nXyter Timestamp Ports
    NX_CLK128_IN               : in std_logic;
    NX_TIMESTAMP_IN            : in std_logic_vector (7 downto 0);
    NX_RESET_OUT               : out std_logic;
    NX_TESTPULSE_OUT           : out std_logic;
                                
    -- ADC nXyter Pulse Hight Ports
    ADC_FCLK_IN                : in  std_logic_vector(1 downto 0);
    ADC_DCLK_IN                : in  std_logic_vector(1 downto 0);
    ADC_SAMPLE_CLK_OUT         : out std_logic;
    ADC_A_IN                   : in  std_logic_vector(1 downto 0);
    ADC_B_IN                   : in  std_logic_vector(1 downto 0);
    ADC_NX_IN                  : in  std_logic_vector(1 downto 0);
    ADC_D_IN                   : in  std_logic_vector(1 downto 0);        
                                
    -- Event Buffer
    --LVL1 trigger to FEE
    LVL1_TRG_DATA_VALID_IN     : in std_logic;
    LVL1_VALID_TIMING_TRG_IN   : in std_logic;
    LVL1_VALID_NOTIMING_TRG_IN : in std_logic; -- Status + Info TypE
    LVL1_INVALID_TRG_IN        : in std_logic;

    LVL1_TRG_TYPE_IN           : in std_logic_vector(3 downto 0);
    LVL1_TRG_NUMBER_IN         : in std_logic_vector(15 downto 0);
    LVL1_TRG_CODE_IN           : in std_logic_vector(7 downto 0);
    LVL1_TRG_INFORMATION_IN    : in std_logic_vector(23 downto 0);
    LVL1_INT_TRG_NUMBER_IN     : in std_logic_vector(15 downto 0);

    --Response from FEE        
    FEE_TRG_RELEASE_OUT        : out std_logic;
    FEE_TRG_STATUSBITS_OUT     : out std_logic_vector(31 downto 0);
    FEE_DATA_OUT               : out std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_OUT         : out std_logic;
    FEE_DATA_FINISHED_OUT      : out std_logic;
    FEE_DATA_ALMOST_FULL_IN    : in  std_logic;

    -- TRBNet RegIO Port for the slave bus
    REGIO_ADDR_IN              : in    std_logic_vector(15 downto 0);
    REGIO_DATA_IN              : in    std_logic_vector(31 downto 0);
    REGIO_DATA_OUT             : out   std_logic_vector(31 downto 0);
    REGIO_READ_ENABLE_IN       : in    std_logic;                    
    REGIO_WRITE_ENABLE_IN      : in    std_logic;
    REGIO_TIMEOUT_IN           : in    std_logic;
    REGIO_DATAREADY_OUT        : out   std_logic;
    REGIO_WRITE_ACK_OUT        : out   std_logic;
    REGIO_NO_MORE_DATA_OUT     : out   std_logic;
    REGIO_UNKNOWN_ADDR_OUT     : out   std_logic;
    
    -- Debug Signals
    DEBUG_LINE_OUT             : out   std_logic_vector(15 downto 0)
    );
  
end entity;


architecture Behavioral of nXyter_FEE_board is

-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------
  -- Clock 256
  signal clk_250_o             : std_logic;
                               
  -- Bus Handler
  constant NUM_PORTS           : integer := 13;

  signal slv_read              : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_write             : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_no_more_data      : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_ack               : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_addr              : std_logic_vector(NUM_PORTS*16-1 downto 0);
  signal slv_data_rd           : std_logic_vector(NUM_PORTS*32-1 downto 0);
  signal slv_data_wr           : std_logic_vector(NUM_PORTS*32-1 downto 0);
  signal slv_unknown_addr      : std_logic_vector(NUM_PORTS-1 downto 0);
                               
  -- TRB Register              
  signal i2c_sm_reset_o        : std_logic;   
  signal nx_ts_reset_1         : std_logic;
  signal nx_ts_reset_2         : std_logic;
  signal nx_ts_reset_o         : std_logic;
  signal i2c_reg_reset_o       : std_logic;
                               
  -- NX Register Access        
  signal i2c_lock              : std_logic;
  signal i2c_command           : std_logic_vector(31 downto 0);
  signal i2c_command_busy      : std_logic;
  signal i2c_data              : std_logic_vector(31 downto 0);
  signal spi_lock              : std_logic;
  signal spi_command           : std_logic_vector(31 downto 0);
  signal spi_command_busy      : std_logic;
  signal spi_data              : std_logic_vector(31 downto 0);
                               
  -- SPI Interface ADC         
  signal spi_sdi               : std_logic;
  signal spi_sdo               : std_logic;        
                               
  -- Data Receiver             
  signal adc_data_valid        : std_logic;
  signal adc_new_data          : std_logic;
                               
  signal new_timestamp         : std_logic_vector(31 downto 0);
  signal new_adc_data          : std_logic_vector(11 downto 0);
  signal new_data              : std_logic;

  -- Data Delay
  signal new_timestamp_delayed : std_logic_vector(31 downto 0);
  signal new_adc_data_delayed  : std_logic_vector(11 downto 0);
  signal new_data_delayed      : std_logic;
  signal new_data_fifo_delay   : std_logic_vector(6 downto 0);

  -- Data Validate             
  signal timestamp             : std_logic_vector(13 downto 0);
  signal timestamp_channel_id  : std_logic_vector(6 downto 0);
  signal timestamp_status      : std_logic_vector(2 downto 0);
  signal adc_data              : std_logic_vector(11 downto 0);
  signal data_valid            : std_logic;
                               
  signal nx_token_return       : std_logic;
  signal nx_nomore_data        : std_logic;
                               
  -- Trigger Validate          
  signal trigger_data          : std_logic_vector(31 downto 0);
  signal trigger_data_clk      : std_logic;
  signal event_buffer_clear    : std_logic;
  signal trigger_validate_busy : std_logic;
  signal validate_nomore_data  : std_logic;
  
  signal trigger_validate_fill : std_logic;
  signal trigger_validate_bin  : std_logic_vector(6 downto 0);
  signal trigger_validate_adc  : std_logic_vector(11 downto 0);
  
  -- Event Buffer               
  signal trigger_evt_busy      : std_logic;
  signal fee_trg_statusbits_o  : std_logic_vector(31 downto 0);
  signal fee_data_o            : std_logic_vector(31 downto 0);
  signal fee_data_write_o      : std_logic;
  signal fee_data_finished_o   : std_logic;
  signal fee_almost_full_i     : std_logic;
  
  -- Trigger Handler
  signal trigger               : std_logic;
  signal timestamp_trigger     : std_logic;
  signal lvl2_trigger          : std_logic;
  signal trigger_busy          : std_logic;
  signal fast_clear            : std_logic;
  signal nxyter_offline        : std_logic;
  signal fee_trg_release_o     : std_logic;
  signal trigger_testpulse     : std_logic;

  -- FPGA Timestamp
  signal timestamp_current     : unsigned(11 downto 0);
  signal timestamp_hold        : unsigned(11 downto 0);
  signal nx_timestamp_sync     : std_logic;
  
  -- Trigger Generator
  signal trigger_intern        : std_logic;
  signal nx_testpulse_o        : std_logic;

  -- Debug Handler
  constant DEBUG_NUM_PORTS     : integer := 13;
  signal debug_line            : debug_array_t(0 to DEBUG_NUM_PORTS-1);
  
begin

-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------
  -- DEBUG_LINE_OUT(0)           <= CLK_IN;
  -- DEBUG_LINE_OUT(15 downto 0) <= (others => '0');
  -- See Multiplexer
  
-------------------------------------------------------------------------------
-- Port Maps
-------------------------------------------------------------------------------

  THE_BUS_HANDLER: trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER         => NUM_PORTS,

      PORT_ADDRESSES      => (  0 => x"0100",    -- Control Register Handler
                                1 => x"0040",    -- I2C Master
                                2 => x"0500",    -- Data Receiver
                                3 => x"0600",    -- Data Buffer
                                4 => x"0060",    -- SPI Master
                                5 => x"0140",    -- Trigger Generator
                                6 => x"0120",    -- Data Validate
                                7 => x"0160",    -- Trigger Handler
                                8 => x"0180",    -- Trigger Validate
                                9 => x"0200",    -- NX Register Setup
                               10 => x"0800",    -- NX Histograms
                               11 => x"0020",    -- Debug Handler
                               12 => x"0130",    -- Data Delay
                                others => x"0000"
                                ),

      PORT_ADDR_MASK      => (  0 => 4,          -- Control Register Handler
                                1 => 0,          -- I2C master
                                2 => 4,          -- Data Receiver
                                3 => 3,          -- Data Buffer
                                4 => 0,          -- SPI Master
                                5 => 3,          -- Trigger Generator
                                6 => 4,          -- Data Validate
                                7 => 2,          -- Trigger Handler
                                8 => 4,          -- Trigger Validate
                                9 => 8,          -- NX Register Setup
                               10 => 9,          -- NX Histograms
                               11 => 0,          -- Debug Handler
                               12 => 1,          -- Data Delay
                                others => 0
                                ),

      PORT_MASK_ENABLE           => 1
      )
    port map(
      CLK                        => CLK_IN,
      RESET                      => RESET_IN,
                                 
      DAT_ADDR_IN                => REGIO_ADDR_IN,
      DAT_DATA_IN                => REGIO_DATA_IN,
      DAT_DATA_OUT               => REGIO_DATA_OUT,
      DAT_READ_ENABLE_IN         => REGIO_READ_ENABLE_IN,
      DAT_WRITE_ENABLE_IN        => REGIO_WRITE_ENABLE_IN,
      DAT_TIMEOUT_IN             => REGIO_TIMEOUT_IN,
      DAT_DATAREADY_OUT          => REGIO_DATAREADY_OUT,
      DAT_WRITE_ACK_OUT          => REGIO_WRITE_ACK_OUT,
      DAT_NO_MORE_DATA_OUT       => REGIO_NO_MORE_DATA_OUT,
      DAT_UNKNOWN_ADDR_OUT       => REGIO_UNKNOWN_ADDR_OUT,
                                 
      -- All NXYTER Ports      
      BUS_READ_ENABLE_OUT        => slv_read,
      BUS_WRITE_ENABLE_OUT       => slv_write,
      BUS_DATA_OUT               => slv_data_wr,
      BUS_DATA_IN                => slv_data_rd,
      BUS_ADDR_OUT               => slv_addr,
      BUS_TIMEOUT_OUT            => open,
      BUS_DATAREADY_IN           => slv_ack,
      BUS_WRITE_ACK_IN           => slv_ack,
      BUS_NO_MORE_DATA_IN        => slv_no_more_data,
      BUS_UNKNOWN_ADDR_IN        => slv_unknown_addr,

      -- DEBUG
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
      OFFLINE_OUT            => nxyter_offline,
  
      DEBUG_OUT              => debug_line(0)
      );

  nx_register_setup_1: nx_setup
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      I2C_COMMAND_OUT      => i2c_command,
      I2C_COMMAND_BUSY_IN  => i2c_command_busy,
      I2C_DATA_IN          => i2c_data,
      I2C_LOCK_OUT         => i2c_lock,
      SPI_COMMAND_OUT      => spi_command,
      SPI_COMMAND_BUSY_IN  => spi_command_busy,
      SPI_DATA_IN          => spi_data,
      SPI_LOCK_OUT         => spi_lock,
      SLV_READ_IN          => slv_read(9),
      SLV_WRITE_IN         => slv_write(9),
      SLV_DATA_OUT         => slv_data_rd(9*32+31 downto 9*32),
      SLV_DATA_IN          => slv_data_wr(9*32+31 downto 9*32),
      SLV_ADDR_IN          => slv_addr(9*16+15 downto 9*16),
      SLV_ACK_OUT          => slv_ack(9),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(9),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(9),
 
      DEBUG_OUT            => debug_line(1)
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
      INTERNAL_COMMAND_IN   => i2c_command,
      COMMAND_BUSY_OUT      => i2c_command_busy,
      I2C_DATA_OUT          => i2c_data,
      I2C_LOCK_IN           => i2c_lock,
      SLV_READ_IN           => slv_read(1),
      SLV_WRITE_IN          => slv_write(1),
      SLV_DATA_OUT          => slv_data_rd(1*32+31 downto 1*32),
      SLV_DATA_IN           => slv_data_wr(1*32+31 downto 1*32),
      SLV_ACK_OUT           => slv_ack(1), 
      SLV_NO_MORE_DATA_OUT  => slv_no_more_data(1),
      SLV_UNKNOWN_ADDR_OUT  => slv_unknown_addr(1),
  
      DEBUG_OUT             => debug_line(2)
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
      INTERNAL_COMMAND_IN  => spi_command,
      COMMAND_BUSY_OUT     => spi_command_busy,
      SPI_DATA_OUT         => spi_data,
      SPI_LOCK_IN          => spi_lock,
      SLV_READ_IN          => slv_read(4),
      SLV_WRITE_IN         => slv_write(4),
      SLV_DATA_OUT         => slv_data_rd(4*32+31 downto 4*32),
      SLV_DATA_IN          => slv_data_wr(4*32+31 downto 4*32),
      SLV_ACK_OUT          => slv_ack(4), 
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(4), 
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(4),
 
      DEBUG_OUT            => debug_line(3)
      );

-------------------------------------------------------------------------------
-- FPGA Timestamp
-------------------------------------------------------------------------------
  
  nx_fpga_timestamp_1: nx_fpga_timestamp
    port map (
      CLK_IN                => CLK_IN,
      RESET_IN              => RESET_IN,
      NX_CLK_IN             => CLK_NX_IN,
      TIMESTAMP_SYNC_IN     => nx_ts_reset_o,
      TRIGGER_IN            => timestamp_trigger,
      TIMESTAMP_CURRENT_OUT => timestamp_current,
      TIMESTAMP_HOLD_OUT    => timestamp_hold,
      NX_TIMESTAMP_SYNC_OUT => nx_timestamp_sync,
      SLV_READ_IN           => open,
      SLV_WRITE_IN          => open,
      SLV_DATA_OUT          => open,
      SLV_DATA_IN           => open,
      SLV_ACK_OUT           => open,
      SLV_NO_MORE_DATA_OUT  => open,
      SLV_UNKNOWN_ADDR_OUT  => open,
   
      DEBUG_OUT             => debug_line(4)
      );

-------------------------------------------------------------------------------
-- Trigger Handler
-------------------------------------------------------------------------------

  nx_trigger_handler_1: nx_trigger_handler
    port map (
      CLK_IN                     => CLK_IN,
      RESET_IN                   => RESET_IN,
      NXYTER_OFFLINE_IN          => nxyter_offline,

      LVL1_TRG_DATA_VALID_IN     => LVL1_TRG_DATA_VALID_IN,
      LVL1_VALID_TIMING_TRG_IN   => LVL1_VALID_TIMING_TRG_IN,
      LVL1_VALID_NOTIMING_TRG_IN => LVL1_VALID_NOTIMING_TRG_IN,
      LVL1_INVALID_TRG_IN        => LVL1_INVALID_TRG_IN,

      LVL1_TRG_TYPE_IN           => LVL1_TRG_TYPE_IN,
      LVL1_TRG_NUMBER_IN         => LVL1_TRG_NUMBER_IN,
      LVL1_TRG_CODE_IN           => LVL1_TRG_CODE_IN,
      LVL1_TRG_INFORMATION_IN    => LVL1_TRG_INFORMATION_IN,
      LVL1_INT_TRG_NUMBER_IN     => LVL1_INT_TRG_NUMBER_IN,

      FEE_TRG_RELEASE_OUT        => FEE_TRG_RELEASE_OUT,
      FEE_TRG_STATUSBITS_OUT     => FEE_TRG_STATUSBITS_OUT,

      INTERNAL_TRIGGER_IN        => trigger_intern,

      TRIGGER_VALIDATE_BUSY_IN   => trigger_validate_busy,
      LVL2_TRIGGER_BUSY_IN       => trigger_evt_busy,
      
      VALIDATE_TRIGGER_OUT       => trigger,
      TIMESTAMP_TRIGGER_OUT      => timestamp_trigger,
      LVL2_TRIGGER_OUT           => lvl2_trigger,
      EVENT_BUFFER_CLEAR_OUT     => event_buffer_clear,
      FAST_CLEAR_OUT             => fast_clear,
      TRIGGER_BUSY_OUT           => trigger_busy,

      TRIGGER_TESTPULSE_OUT      => trigger_testpulse,
      
      SLV_READ_IN                => slv_read(7),
      SLV_WRITE_IN               => slv_write(7),
      SLV_DATA_OUT               => slv_data_rd(7*32+31 downto 7*32),
      SLV_DATA_IN                => slv_data_wr(7*32+31 downto 7*32),
      SLV_ADDR_IN                => slv_addr(7*16+15 downto 7*16),
      SLV_ACK_OUT                => slv_ack(7),
      SLV_NO_MORE_DATA_OUT       => slv_no_more_data(7),
      SLV_UNKNOWN_ADDR_OUT       => slv_unknown_addr(7),

      DEBUG_OUT                  => debug_line(5)
      );

-------------------------------------------------------------------------------
-- NX Trigger Generator
-------------------------------------------------------------------------------

  nx_trigger_generator_1: nx_trigger_generator
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      TRIGGER_IN           => trigger_testpulse,
      TRIGGER_OUT          => trigger_intern,
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
     
      DEBUG_OUT            => debug_line(6)
      );

-------------------------------------------------------------------------------
-- nXyter Data Receiver
-------------------------------------------------------------------------------

  nx_data_receiver_1: nx_data_receiver
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      TRIGGER_IN           => lvl2_trigger,

      NX_TIMESTAMP_CLK_IN  => NX_CLK128_IN,
      NX_TIMESTAMP_IN      => NX_TIMESTAMP_IN,
      
      ADC_CLK_DAT_IN       => CLK_ADC_IN,
      ADC_FCLK_IN          => ADC_FCLK_IN,
      ADC_DCLK_IN          => ADC_DCLK_IN, 
      ADC_SAMPLE_CLK_OUT   => ADC_SAMPLE_CLK_OUT,
      ADC_A_IN             => ADC_A_IN,
      ADC_B_IN             => ADC_B_IN,
      ADC_NX_IN            => ADC_NX_IN, 
      ADC_D_IN             => ADC_D_IN,

      NX_TIMESTAMP_OUT     => new_timestamp,
      ADC_DATA_OUT         => new_adc_data,
      NEW_DATA_OUT         => new_data,

      TIMESTAMP_CURRENT_IN => timestamp_current,
      
      SLV_READ_IN          => slv_read(2),                      
      SLV_WRITE_IN         => slv_write(2),                     
      SLV_DATA_OUT         => slv_data_rd(2*32+31 downto 2*32), 
      SLV_DATA_IN          => slv_data_wr(2*32+31 downto 2*32), 
      SLV_ADDR_IN          => slv_addr(2*16+15 downto 2*16),    
      SLV_ACK_OUT          => slv_ack(2),                       
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(2),              
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(2),              
      DEBUG_OUT            => debug_line(7)
      );

-------------------------------------------------------------------------------
-- NX and ADC Data Delay FIFO
-------------------------------------------------------------------------------
  nx_data_delay_1: nx_data_delay
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,

      NX_FRAME_IN          => new_timestamp,
      ADC_DATA_IN          => new_adc_data,
      NEW_DATA_IN          => new_data,
      NX_FRAME_OUT         => new_timestamp_delayed,
      ADC_DATA_OUT         => new_adc_data_delayed,
      NEW_DATA_OUT         => new_data_delayed,
      FIFO_DELAY_IN        => new_data_fifo_delay,  
      
      SLV_READ_IN          => slv_read(12), 
      SLV_WRITE_IN         => slv_write(12), 
      SLV_DATA_OUT         => slv_data_rd(12*32+31 downto 12*32),
      SLV_DATA_IN          => slv_data_wr(12*32+31 downto 12*32),
      SLV_ADDR_IN          => slv_addr(12*16+15 downto 12*16),
      SLV_ACK_OUT          => slv_ack(12),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(12),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(12),

      DEBUG_OUT            => debug_line(8)
      );
  
-------------------------------------------------------------------------------
-- Timestamp Decoder and Valid Data Filter
-------------------------------------------------------------------------------

  nx_data_validate_1: nx_data_validate
    port map (
      CLK_IN                => CLK_IN,
      RESET_IN              => RESET_IN,
      
      NX_TIMESTAMP_IN       => new_timestamp_delayed,
      ADC_DATA_IN           => new_adc_data_delayed,
      NEW_DATA_IN           => new_data_delayed,

      TIMESTAMP_OUT         => timestamp,
      CHANNEL_OUT           => timestamp_channel_id,
      TIMESTAMP_STATUS_OUT  => timestamp_status,
      ADC_DATA_OUT          => adc_data,
      DATA_VALID_OUT        => data_valid,
      
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

      DEBUG_OUT             => debug_line(9)
      );

-------------------------------------------------------------------------------
-- NX Trigger Validate
-------------------------------------------------------------------------------

  nx_trigger_validate_1: nx_trigger_validate
    generic map (
      BOARD_ID => BOARD_ID
      )
    port map (
      CLK_IN                 => CLK_IN,
      RESET_IN               => RESET_IN,
      
      DATA_CLK_IN            => data_valid,
      TIMESTAMP_IN           => timestamp,
      CHANNEL_IN             => timestamp_channel_id,
      TIMESTAMP_STATUS_IN    => timestamp_status,
      ADC_DATA_IN            => adc_data,
      NX_TOKEN_RETURN_IN     => nx_token_return,
      NX_NOMORE_DATA_IN      => nx_nomore_data,

      TRIGGER_IN             => trigger,
      FAST_CLEAR_IN          => fast_clear,
      TRIGGER_BUSY_OUT       => trigger_validate_busy,
      TIMESTAMP_REF_IN       => timestamp_hold,
      DATA_FIFO_DELAY_OUT    => new_data_fifo_delay,
      
      DATA_OUT               => trigger_data,
      DATA_CLK_OUT           => trigger_data_clk,
      NOMORE_DATA_OUT        => validate_nomore_data,

      HISTOGRAM_FILL_OUT     => trigger_validate_fill,
      HISTOGRAM_BIN_OUT      => trigger_validate_bin,
      HISTOGRAM_ADC_OUT      => trigger_validate_adc,
      
      SLV_READ_IN            => slv_read(8),
      SLV_WRITE_IN           => slv_write(8),
      SLV_DATA_OUT           => slv_data_rd(8*32+31 downto 8*32),
      SLV_DATA_IN            => slv_data_wr(8*32+31 downto 8*32),
      SLV_ADDR_IN            => slv_addr(8*16+15 downto 8*16),
      SLV_ACK_OUT            => slv_ack(8),
      SLV_NO_MORE_DATA_OUT   => slv_no_more_data(8),
      SLV_UNKNOWN_ADDR_OUT   => slv_unknown_addr(8),

      DEBUG_OUT              => debug_line(10)
      );

-------------------------------------------------------------------------------
-- Data Buffer FIFO
-------------------------------------------------------------------------------

  nx_event_buffer_1: nx_event_buffer
    generic map (
      BOARD_ID => BOARD_ID
      )
    port map (
      CLK_IN                     => CLK_IN,
      RESET_IN                   => RESET_IN,
      RESET_DATA_BUFFER_IN       => event_buffer_clear,
      NXYTER_OFFLINE_IN          => nxyter_offline,

      DATA_IN                    => trigger_data,
      DATA_CLK_IN                => trigger_data_clk,
      EVT_NOMORE_DATA_IN         => validate_nomore_data,

      LVL2_TRIGGER_IN            => lvl2_trigger,
      FAST_CLEAR_IN              => fast_clear,
      TRIGGER_BUSY_OUT           => trigger_evt_busy,

      FEE_DATA_OUT               => FEE_DATA_OUT,
      FEE_DATA_WRITE_OUT         => FEE_DATA_WRITE_OUT,
      FEE_DATA_FINISHED_OUT      => FEE_DATA_FINISHED_OUT,
      FEE_DATA_ALMOST_FULL_IN    => FEE_DATA_ALMOST_FULL_IN,

      SLV_READ_IN                => slv_read(3),
      SLV_WRITE_IN               => slv_write(3),
      SLV_DATA_OUT               => slv_data_rd(3*32+31 downto 3*32),
      SLV_DATA_IN                => slv_data_wr(3*32+31 downto 3*32),
      SLV_ADDR_IN                => slv_addr(3*16+15 downto 3*16),
      SLV_ACK_OUT                => slv_ack(3),
      SLV_NO_MORE_DATA_OUT       => slv_no_more_data(3),
      SLV_UNKNOWN_ADDR_OUT       => slv_unknown_addr(3),

      DEBUG_OUT                  =>  debug_line(11)
      );

  nx_histograms_1: nx_histograms
    generic map (
      BUS_WIDTH  => 7,
      ENABLE     => 1
      )
    port map (
      CLK_IN                      => CLK_IN,
      RESET_IN                    => RESET_IN,
                                  
      RESET_HISTS_IN              => '0',
      CHANNEL_STAT_FILL_IN        => trigger_validate_fill,
      CHANNEL_ID_IN               => trigger_validate_bin,
      CHANNEL_ADC_IN              => trigger_validate_adc,
      
      SLV_READ_IN                 => slv_read(10),
      SLV_WRITE_IN                => slv_write(10),
      SLV_DATA_OUT                => slv_data_rd(10*32+31 downto 10*32),
      SLV_DATA_IN                 => slv_data_wr(10*32+31 downto 10*32),
      SLV_ADDR_IN                 => slv_addr(10*16+15 downto 10*16),
      SLV_ACK_OUT                 => slv_ack(10),
      SLV_NO_MORE_DATA_OUT        => slv_no_more_data(10),
      SLV_UNKNOWN_ADDR_OUT        => slv_unknown_addr(10),

      DEBUG_OUT                   => debug_line(12)
      );
  
-------------------------------------------------------------------------------
-- nXyter Signals
-------------------------------------------------------------------------------
  nx_ts_reset_o     <= nx_ts_reset_1 or nx_ts_reset_2; 
  NX_RESET_OUT      <= not nx_ts_reset_o;
  NX_TESTPULSE_OUT  <= nx_testpulse_o;

-------------------------------------------------------------------------------
-- I2C Signals
-------------------------------------------------------------------------------

  I2C_SM_RESET_OUT  <= not i2c_sm_reset_o;
  I2C_REG_RESET_OUT <= not i2c_reg_reset_o;


-------------------------------------------------------------------------------
-- DEBUG Line Select
-------------------------------------------------------------------------------
  debug_multiplexer_1: debug_multiplexer
    generic map (
      NUM_PORTS => DEBUG_NUM_PORTS
      )
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      DEBUG_LINE_IN        => debug_line,
      DEBUG_LINE_OUT       => DEBUG_LINE_OUT,
      SLV_READ_IN          => slv_read(11),
      SLV_WRITE_IN         => slv_write(11),
      SLV_DATA_OUT         => slv_data_rd(11*32+31 downto 11*32),
      SLV_DATA_IN          => slv_data_wr(11*32+31 downto 11*32),
      SLV_ADDR_IN          => slv_addr(11*16+15 downto 11*16),
      SLV_ACK_OUT          => slv_ack(11),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(11),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(11)
      );
  
-------------------------------------------------------------------------------
-- END
-------------------------------------------------------------------------------

end Behavioral;
