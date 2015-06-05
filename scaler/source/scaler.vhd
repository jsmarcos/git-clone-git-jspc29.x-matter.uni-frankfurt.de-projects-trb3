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
    CLK_NX_MAIN_IN             : in  std_logic;
    PLL_NX_CLK_LOCK_IN         : in  std_logic;
    PLL_RESET_OUT              : out std_logic;
    TRIGGER_OUT                : out std_logic;
                                
    -- Scaler Channels
    SCALER_LATCH_IN            : in  std_logic;
    SCALER_CHANNELS_IN         : in  std_logic_vector (7 downto 0);
                                
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
  
  -- Bus Handler                
  constant NUM_PORTS            : integer := 2;
  
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
  constant DEBUG_NUM_PORTS      : integer := 1;  -- 14
  signal debug_line             : debug_array_t(0 to DEBUG_NUM_PORTS-1);

  ----------------------------------------------------------------------
  -- Testing Delay
  ----------------------------------------------------------------------

  signal clock_div              : unsigned(11 downto 0);
  signal clk_pulse              : std_logic;
  
  signal scaler_counter         : unsigned(11 downto 0);
  signal input_pulse            : std_logic;
  signal INPUT                  : std_logic;

  signal debug_test             : std_logic_vector(15 downto 0);
  
  ----------------------------------------------------------------------
  -- Reset
  ----------------------------------------------------------------------
  signal reset_scaler_clk_in_ff     : std_logic;
  signal reset_scaler_clk_in_f      : std_logic;
  signal RESET_SCALER_CLK_IN        : std_logic;
  
  attribute syn_keep : boolean;
  attribute syn_keep of reset_scaler_clk_in_ff     : signal is true;
  attribute syn_keep of reset_scaler_clk_in_f      : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of reset_scaler_clk_in_ff : signal is true;
  attribute syn_preserve of reset_scaler_clk_in_f  : signal is true;
  
begin
  -----------------------------------------------------------------------------
  -- Reset Domain Transfer
  -----------------------------------------------------------------------------
  reset_scaler_clk_in_ff   <= RESET_IN when rising_edge(CLK_NX_MAIN_IN);
  reset_scaler_clk_in_f    <= reset_scaler_clk_in_ff
                              when rising_edge(CLK_NX_MAIN_IN); 
  RESET_SCALER_CLK_IN      <= reset_scaler_clk_in_f
                              when rising_edge(CLK_NX_MAIN_IN);
  
-------------------------------------------------------------------------------
-- Port Maps
-------------------------------------------------------------------------------

  THE_BUS_HANDLER: trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER         => NUM_PORTS,

      PORT_ADDRESSES      => (0 => x"0020",       -- Debug Handler
                              1 => x"0040",       -- Scaler Channel 0 
                              others => x"0000"
                              ),

      PORT_ADDR_MASK      => (0 => 0,          -- Debug Handler
                              1 => 2,          -- Scaler Channel 0 
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
        if (clock_div < x"3e8") then
          clk_pulse  <= '0';
          clock_div  <= clock_div + 1;
        else
          clk_pulse  <= '1';
          clock_div  <= (others => '0');
        end if;
      end if;
    end if;
  end process PROC_CLOCK_DIVIDER;


  scaler_channel_1: scaler_channel
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      CLK_SCALER_IN        => CLK_NX_MAIN_IN,
      RESET_SCALER_IN      => RESET_SCALER_CLK_IN,
      LATCH_IN             => clk_pulse,
      PULSE_IN             => clk_pulse,
      INHIBIT_IN           => '0',
      
      SLV_READ_IN          => slv_read(1),
      SLV_WRITE_IN         => slv_write(1),
      SLV_DATA_OUT         => slv_data_rd(1*32+31 downto 1*32),
      SLV_DATA_IN          => slv_data_wr(1*32+31 downto 1*32),
      SLV_ADDR_IN          => slv_addr(1*16+15 downto 1*16),
      SLV_ACK_OUT          => slv_ack(1),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(1),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(1),
      
      DEBUG_OUT            => debug_line(0)
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
