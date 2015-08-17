--------------------------------------------------------------------------
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
use work.scaler_components.all;

entity scaler is
  generic (
    BOARD_ID : std_logic_vector(1 downto 0) := "11"
    );
  port (
    CLK_IN                     : in  std_logic;  
    RESET_IN                   : in  std_logic;

    CLK_D1_IN                  : in  std_logic;

    TRIGGER_OUT                : out std_logic;
                                
    -- Scaler Channels
    LATCH_IN                   : in  std_logic;
    CHANNELS_IN                : in  std_logic_vector (7 downto 0);
                                
    -- Input Triggers
    TIMING_TRIGGER_IN          : in  std_logic;  
    LVL1_TRG_DATA_VALID_IN     : in  std_logic;
    LVL1_VALID_TIMING_TRG_IN   : in  std_logic;
    LVL1_VALID_NOTIMING_TRG_IN : in  std_logic; -- Status + Info TypE
    LVL1_INVALID_TRG_IN        : in  std_logic;

    LVL1_TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
    LVL1_TRG_NUMBER_IN         : in  std_logic_vector(15 downto 0);
    LVL1_TRG_CODE_IN           : in  std_logic_vector(7 downto 0);
    LVL1_TRG_INFORMATION_IN    : in  std_logic_vector(23 downto 0);
    LVL1_INT_TRG_NUMBER_IN     : in  std_logic_vector(15 downto 0);
    
    --Response from FEE        
    FEE_TRG_RELEASE_OUT        : out std_logic;
    FEE_TRG_STATUSBITS_OUT     : out std_logic_vector(31 downto 0);
    FEE_DATA_OUT               : out std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_OUT         : out std_logic;
    FEE_DATA_FINISHED_OUT      : out std_logic;
    FEE_DATA_ALMOST_FULL_IN    : in  std_logic;

    -- TRBNet RegIO Port for the slave bus
    REGIO_ADDR_IN              : in  std_logic_vector(15 downto 0);
    REGIO_DATA_IN              : in  std_logic_vector(31 downto 0);
    REGIO_DATA_OUT             : out std_logic_vector(31 downto 0);
    REGIO_READ_ENABLE_IN       : in  std_logic;                    
    REGIO_WRITE_ENABLE_IN      : in  std_logic;
    REGIO_TIMEOUT_IN           : in  std_logic;
    REGIO_DATAREADY_OUT        : out std_logic;
    REGIO_WRITE_ACK_OUT        : out std_logic;
    REGIO_NO_MORE_DATA_OUT     : out std_logic;
    REGIO_UNKNOWN_ADDR_OUT     : out std_logic;
    
    -- Debug Signals
    DEBUG_LINE_OUT             : out   std_logic_vector(15 downto 0)
    );
  
end entity;


architecture Behavioral of scaler is
  -- Data Format Version
  constant VERSION_NUMBER       : std_logic_vector(3 downto 0) := x"1";
  
-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------

  -- Resets
  signal reset_d1_ff            : std_logic_vector(1 downto 0);
  signal RESET_D1               : std_logic;

  -- Bus Handler                
  constant NUM_PORTS            : integer := 5;
  
  signal slv_read               : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_write              : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_no_more_data       : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_ack                : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_addr               : std_logic_vector(NUM_PORTS*16-1 downto 0);
  signal slv_data_rd            : std_logic_vector(NUM_PORTS*32-1 downto 0);
  signal slv_data_wr            : std_logic_vector(NUM_PORTS*32-1 downto 0);
  signal slv_unknown_addr       : std_logic_vector(NUM_PORTS-1 downto 0);

  -- TRB Register               
  signal nx_timestamp_reset     : std_logic;
  signal nx_timestamp_reset_o   : std_logic;
  signal i2c_reg_reset_o        : std_logic;
  signal nxyter_online          : std_logic;
  
  -- NX Register Access         
  signal i2c_lock               : std_logic;
  signal i2c_command            : std_logic_vector(31 downto 0);
  signal i2c_command_busy       : std_logic;
  signal i2c_data               : std_logic_vector(31 downto 0);
  signal i2c_data_bytes         : std_logic_vector(31 downto 0);
  signal spi_lock               : std_logic;
  signal spi_command            : std_logic_vector(31 downto 0);
  signal spi_command_busy       : std_logic;
  signal spi_data               : std_logic_vector(31 downto 0);
  signal nxyter_clock_on        : std_logic;

  -- SPI Interface ADC          
  signal spi_sdi                : std_logic;
  signal spi_sdo                : std_logic;        
                                
  -- Data Receiver
  signal data_recv              : std_logic_vector(43 downto 0);
  signal data_clk_recv          : std_logic;
  signal pll_sadc_clk_lock      : std_logic;
  signal disable_adc_receiver   : std_logic;
  
  -- Data Delay                 
  signal data_delayed           : std_logic_vector(43 downto 0);
  signal data_clk_delayed       : std_logic;
  signal data_fifo_delay        : std_logic_vector(7 downto 0);

  -- Data Validate             
  signal timestamp              : std_logic_vector(13 downto 0);
  signal timestamp_channel_id   : std_logic_vector(6 downto 0);
  signal timestamp_status       : std_logic_vector(2 downto 0);
  signal adc_data               : std_logic_vector(11 downto 0);
  signal data_clk               : std_logic;
  signal adc_tr_error           : std_logic;
  signal nx_token_return        : std_logic;
  signal nx_nomore_data         : std_logic;

  -- Latch Handler
  signal reset_ctr              : std_logic;
  signal latch                  : std_logic;
  
  -- Trigger Validate           
  signal trigger_data           : std_logic_vector(31 downto 0);
  signal trigger_data_clk       : std_logic;
  signal event_buffer_clear     : std_logic;
  signal trigger_validate_busy  : std_logic;
  signal validate_nomore_data   : std_logic;
                                
  signal trigger_validate_fill   : std_logic;
  signal trigger_validate_bin    : std_logic_vector(6 downto 0);
  signal trigger_validate_adc    : std_logic_vector(11 downto 0);
  signal trigger_validate_ts     : std_logic_vector(8 downto 0);
  signal trigger_validate_pileup : std_logic;
  signal trigger_validate_ovfl   : std_logic;
  signal reset_hists             : std_logic;

  -- Event Buffer                
  signal fee_data_o_0           : std_logic_vector(31 downto 0);
  signal fee_data_write_o_0     : std_logic;
  
  signal trigger_evt_busy_0     : std_logic;
  signal evt_buffer_full        : std_logic;
  signal fee_trg_statusbits_o   : std_logic_vector(31 downto 0);
  signal fee_data_o             : std_logic_vector(31 downto 0);
  signal fee_data_write_o       : std_logic;
  signal fee_data_finished_o    : std_logic;
  signal fee_almost_full_i      : std_logic;

  -- Calib Event
  signal fee_data_o_1           : std_logic_vector(31 downto 0);
  signal fee_data_write_o_1     : std_logic;
  signal trigger_evt_busy_1     : std_logic;
  
  signal int_read               : std_logic;
  signal int_addr               : std_logic_vector(15 downto 0);
  signal int_ack                : std_logic;
  signal int_data               : std_logic_vector(31 downto 0);
  
  -- Trigger Handler            
  signal trigger                : std_logic;
  signal timestamp_trigger      : std_logic;
  signal trigger_timing         : std_logic;
  signal trigger_status         : std_logic;
  signal trigger_calibration    : std_logic;
  signal trigger_busy           : std_logic;
  signal fast_clear             : std_logic;
  signal fee_trg_release_o      : std_logic;
  
  -- Scaler Channels
  signal channel_0_counter      : std_logic_vector(47 downto 0);
  signal channel_1_counter      : std_logic_vector(47 downto 0);
  
  -- FPGA Timestamp
  signal timestamp_hold         : unsigned(11 downto 0);
  
  -- Trigger Generator
  signal internal_trigger       : std_logic;
  
  -- Error
  signal error_all              : std_logic_vector(7 downto 0);
  signal error_data_receiver    : std_logic;
  signal error_data_validate    : std_logic;
  signal error_event_buffer     : std_logic;
  
  -- Debug Handler
  constant DEBUG_NUM_PORTS      : integer := 4;  -- 14
  signal debug_line             : debug_array_t(0 to DEBUG_NUM_PORTS-1);

  ----------------------------------------------------------------------
  -- Testing Delay
  ----------------------------------------------------------------------

  signal clock_div              : unsigned(15 downto 0);
  signal clk_pulse              : std_logic;
  signal latch_i                : std_logic;
  signal latch_ff               : std_logic_vector(2 downto 0);
  
  attribute syn_keep : boolean;
  attribute syn_keep of reset_d1_ff     : signal is true;
  attribute syn_keep of latch_ff        : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of reset_d1_ff : signal is true;
  attribute syn_preserve of latch_ff    : signal is true;
  
begin
  
  -----------------------------------------------------------------------------
  -- Reset Domain Transfer
  -----------------------------------------------------------------------------

  reset_d1_ff(1) <= RESET_IN       when rising_edge(CLK_D1_IN);
  reset_d1_ff(0) <= reset_d1_ff(1) when rising_edge(CLK_D1_IN);
  RESET_D1       <= reset_d1_ff(0);
  
  ----------------------------------------------------------------------------
  -- Port Maps
  ----------------------------------------------------------------------------

  THE_BUS_HANDLER: trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER         => NUM_PORTS,

      PORT_ADDRESSES      => (0 => x"0200",       -- Debug Multiplexer
                              1 => x"0180",       -- Latch Handler
                              2 => x"0160",       -- Trigger Handler

                              3 => x"0000",       -- Scaler Channel 0
                              4 => x"0020",       -- Scaler Channel 1
                              
                              --2 => x"0040",       -- Scaler Channel 2
                              --3 => x"0060",       -- Scaler Channel 3
                              --4 => x"0080",       -- Scaler Channel 4
                              --5 => x"00a0",       -- Scaler Channel 5
                              --6 => x"00c0",       -- Scaler Channel 6
                              --7 => x"00e0",       -- Scaler Channel 7
                                                      
                              others => x"0000"
                              ),

      PORT_ADDR_MASK      => (0 => 0,          -- Debug Multiplexer
                              1 => 4,          -- Latch Handler
                              2 => 4,          -- Trigger Handler

                              3 => 2,          -- Scaler Channel 0
                              4 => 2,          -- Scaler Channel 1

                              --2 => 2,          -- Scaler Channel 2
                              --3 => 2,          -- Scaler Channel 3
                              --4 => 2,          -- Scaler Channel 4
                              --5 => 2,          -- Scaler Channel 5
                              --6 => 2,          -- Scaler Channel 6
                              --7 => 2,          -- Scaler Channel 7
              
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
      STAT_DEBUG                 => open
      );

-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------

  --DEBUG_LINE_OUT(15 downto 0) <= (others => '0');
  -- See Multiplexer
  
  PROC_CLOCK_DIVIDER: process(CLK_IN)
  begin 
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        clock_div    <= (others => '0');
        clk_pulse    <= '0';
      else
        if (clock_div < x"64") then   -- 1mus
          clk_pulse  <= '0';          
          clock_div  <= clock_div + 1;
        else
          clk_pulse  <= '1';
          clock_div  <= x"0001";
        end if;
      end if;
    end if;
  end process PROC_CLOCK_DIVIDER;

--  latch_ff(2)  <= CHANNELS_IN(1) when rising_edge(CLK_D1_IN);
--  latch_ff(1)  <= latch_ff(2) when rising_edge(CLK_D1_IN);
--  latch_ff(0)  <= latch_ff(1) when rising_edge(CLK_D1_IN);
--  latch_i      <= '1' when latch_ff(1 downto 0) = "10" else '0';
  
  latch_handler_1: latch_handler
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      CLK_D1_IN            => CLK_D1_IN,
      RESET_D1_IN          => RESET_D1,
      RESET_CTR_IN         => CHANNELS_IN(7),
      LATCH_TRIGGER_IN     => TIMING_TRIGGER_IN,
      RESET_CTR_OUT        => reset_ctr,
      LATCH_OUT            => latch,
      SLV_READ_IN          => slv_read(1),
      SLV_WRITE_IN         => slv_write(1),
      SLV_DATA_OUT         => slv_data_rd(1*32+31 downto 1*32),
      SLV_DATA_IN          => slv_data_wr(1*32+31 downto 1*32),
      SLV_ADDR_IN          => slv_addr(1*16+15 downto 1*16),
      SLV_ACK_OUT          => slv_ack(1),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(1),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(1),              
      DEBUG_OUT            => debug_line(1)
      );

  
  scaler_channel_0: scaler_channel
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      CLK_D1_IN            => CLK_D1_IN,
      RESET_D1_IN          => RESET_D1,

      RESET_CTR_IN         => reset_ctr,
      LATCH_IN             => latch,
      PULSE_IN             => CHANNELS_IN(0),
      INHIBIT_IN           => '0',

      COUNTER_OUT          => channel_0_counter,
      
      SLV_READ_IN          => slv_read(3),
      SLV_WRITE_IN         => slv_write(3),
      SLV_DATA_OUT         => slv_data_rd(3*32+31 downto 3*32),
      SLV_DATA_IN          => slv_data_wr(3*32+31 downto 3*32),
      SLV_ADDR_IN          => slv_addr(3*16+15 downto 3*16),
      SLV_ACK_OUT          => slv_ack(3),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(3),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(3),              
      
      DEBUG_OUT            => debug_line(2)
      );

  scaler_channel_1: scaler_channel
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      CLK_D1_IN            => CLK_D1_IN,
      RESET_D1_IN          => RESET_D1,

      RESET_CTR_IN         => reset_ctr,
      LATCH_IN             => latch,
      PULSE_IN             => CHANNELS_IN(1),
      INHIBIT_IN           => '0',

      COUNTER_OUT          => channel_1_counter,
      
      SLV_READ_IN          => slv_read(4),
      SLV_WRITE_IN         => slv_write(4),
      SLV_DATA_OUT         => slv_data_rd(4*32+31 downto 4*32),
      SLV_DATA_IN          => slv_data_wr(4*32+31 downto 4*32),
      SLV_ADDR_IN          => slv_addr(4*16+15 downto 4*16),
      SLV_ACK_OUT          => slv_ack(4),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(4),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(4),              
      
      DEBUG_OUT            => debug_line(3)
      );


  trigger_handler_1: trigger_handler
    port map (
      CLK_IN                     => CLK_IN,
      RESET_IN                   => RESET_IN,
      CLK_D1_IN                  => CLK_D1_IN,
      RESET_D1_IN                => RESET_D1, 
      OFFLINE_IN                 => not nxyter_online,

      TIMING_TRIGGER_IN          => TIMING_TRIGGER_IN,
      LVL1_TRG_DATA_VALID_IN     => LVL1_TRG_DATA_VALID_IN,
      LVL1_VALID_TIMING_TRG_IN   => LVL1_VALID_TIMING_TRG_IN,
      LVL1_VALID_NOTIMING_TRG_IN => LVL1_VALID_NOTIMING_TRG_IN,
      LVL1_INVALID_TRG_IN        => LVL1_INVALID_TRG_IN,

      LVL1_TRG_TYPE_IN           => LVL1_TRG_TYPE_IN,
      LVL1_TRG_NUMBER_IN         => LVL1_TRG_NUMBER_IN,
      LVL1_TRG_CODE_IN           => LVL1_TRG_CODE_IN,
      LVL1_TRG_INFORMATION_IN    => LVL1_TRG_INFORMATION_IN,
      LVL1_INT_TRG_NUMBER_IN     => LVL1_INT_TRG_NUMBER_IN,

      FEE_DATA_OUT               => FEE_DATA_OUT,
      FEE_DATA_WRITE_OUT         => FEE_DATA_WRITE_OUT,
      FEE_DATA_FINISHED_OUT      => FEE_DATA_FINISHED_OUT,
      FEE_TRG_RELEASE_OUT        => FEE_TRG_RELEASE_OUT,
      FEE_TRG_STATUSBITS_OUT     => FEE_TRG_STATUSBITS_OUT,

      CHANNEL_DATA_0_IN          => channel_0_counter,
      CHANNEL_DATA_1_IN          => channel_1_counter,

      SLV_READ_IN                => slv_read(2),
      SLV_WRITE_IN               => slv_write(2),
      SLV_DATA_OUT               => slv_data_rd(2*32+31 downto 2*32),
      SLV_DATA_IN                => slv_data_wr(2*32+31 downto 2*32),
      SLV_ADDR_IN                => slv_addr(2*16+15 downto 2*16),
      SLV_ACK_OUT                => slv_ack(2),
      SLV_NO_MORE_DATA_OUT       => slv_no_more_data(2),
      SLV_UNKNOWN_ADDR_OUT       => slv_unknown_addr(2),

      DEBUG_OUT                  => debug_line(0)
      );


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
      SLV_READ_IN          => slv_read(0),
      SLV_WRITE_IN         => slv_write(0),
      SLV_DATA_OUT         => slv_data_rd(0*32+31 downto 0*32),
      SLV_DATA_IN          => slv_data_wr(0*32+31 downto 0*32),
      SLV_ADDR_IN          => slv_addr(0*16+15 downto 0*16),
      SLV_ACK_OUT          => slv_ack(0),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(0),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(0)
      );

-------------------------------------------------------------------------------
-- END
-------------------------------------------------------------------------------

end Behavioral;
