library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all;
use work.trb3_components.all;
use work.med_sync_define.all;
use work.version.all;

entity trb3_periph_sodasource is
  generic(
    SYNC_MODE : integer range 0 to 1 := c_NO;   --use the RX clock for internal logic and transmission. Should be NO for soda tests!
    USE_125_MHZ : integer := c_NO;
    CLOCK_FREQUENCY : integer := 100;
    NUM_INTERFACES : integer := 2
    );
  port(
    --Clocks
    CLK_GPLL_LEFT  : in std_logic;  --Clock Manager 1/(2468), 125 MHz
    CLK_GPLL_RIGHT : in std_logic;  --Clock Manager 2/(2468), 200 MHz  <-- MAIN CLOCK for FPGA
    CLK_PCLK_LEFT  : in std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!
    CLK_PCLK_RIGHT : in std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!

    --Trigger
    --TRIGGER_LEFT  : in std_logic;       --left side trigger input from fan-out
    --TRIGGER_RIGHT : in std_logic;       --right side trigger input from fan-out
    --Serdes Clocks - do not use
    --CLK_SERDES_INT_LEFT  : in  std_logic;  --Clock Manager 1/(1357), off, 125 MHz possible
    --CLK_SERDES_INT_RIGHT : in  std_logic;  --Clock Manager 2/(1357), 200 MHz, only in case of problems

    --serdes I/O - connect as you like, no real use
    SERDES_ADDON_TX      : out std_logic_vector(15 downto 0);
    SERDES_ADDON_RX      : in  std_logic_vector(15 downto 0);

    --Inter-FPGA Communication
    FPGA5_COMM : inout std_logic_vector(11 downto 0);
                                                      --Bit 0/1 input, serial link RX active
                                                      --Bit 2/3 output, serial link TX active
                                                      --others yet undefined
    --Connection to AddOn
    LED_LINKOK : out std_logic_vector(6 downto 1);
    LED_RX     : out std_logic_vector(6 downto 1); 
    LED_TX     : out std_logic_vector(6 downto 1);
    SFP_MOD0   : in  std_logic_vector(6 downto 1);
    SFP_TXDIS  : out std_logic_vector(6 downto 1); 
    SFP_LOS    : in  std_logic_vector(6 downto 1);
    --SFP_MOD1   : inout std_logic_vector(6 downto 1); 
    --SFP_MOD2   : inout std_logic_vector(6 downto 1); 
    --SFP_RATESEL : out std_logic_vector(6 downto 1);
    --SFP_TXFAULT : in  std_logic_vector(6 downto 1);

    --Flash ROM & Reboot
    FLASH_CLK  : out   std_logic;
    FLASH_CS   : out   std_logic;
    FLASH_DIN  : out   std_logic;
    FLASH_DOUT : in    std_logic;
    PROGRAMN   : out   std_logic;                     --reboot FPGA

    --Misc
    TEMPSENS   : inout std_logic;       --Temperature Sensor
    CODE_LINE  : in    std_logic_vector(1 downto 0);
    LED_GREEN  : out   std_logic;
    LED_ORANGE : out   std_logic;
    LED_RED    : out   std_logic;
    LED_YELLOW : out   std_logic;
    SUPPL      : in    std_logic;       --terminated diff pair, PCLK, Pads

    --Test Connectors
    TEST_LINE : out std_logic_vector(15 downto 0)
    );


  attribute syn_useioff                  : boolean;
  --no IO-FF for LEDs relaxes timing constraints
  attribute syn_useioff of LED_GREEN     : signal is false;
  attribute syn_useioff of LED_ORANGE    : signal is false;
  attribute syn_useioff of LED_RED       : signal is false;
  attribute syn_useioff of LED_YELLOW    : signal is false;
  attribute syn_useioff of TEMPSENS      : signal is false;
  attribute syn_useioff of PROGRAMN      : signal is false;
  attribute syn_useioff of CODE_LINE     : signal is false;
  attribute syn_useioff of LED_LINKOK    : signal is false;
  attribute syn_useioff of LED_TX        : signal is false;
  attribute syn_useioff of LED_RX        : signal is false;
  attribute syn_useioff of SFP_MOD0      : signal is false;
  attribute syn_useioff of SFP_TXDIS     : signal is false;
  attribute syn_useioff of SFP_LOS       : signal is false;
  attribute syn_useioff of TEST_LINE  : signal is false;

  --important signals _with_ IO-FF
  attribute syn_useioff of FLASH_CLK  : signal is true;
  attribute syn_useioff of FLASH_CS   : signal is true;
  attribute syn_useioff of FLASH_DIN  : signal is true;
  attribute syn_useioff of FLASH_DOUT : signal is true;
  attribute syn_useioff of FPGA5_COMM : signal is true;


end entity;

architecture trb3_periph_sodasource_arch of trb3_periph_sodasource is
  --Constants
  constant REGIO_NUM_STAT_REGS : integer := 0;
  constant REGIO_NUM_CTRL_REGS : integer := 2;

  attribute syn_keep     : boolean;
  attribute syn_preserve : boolean;

  constant USE_200_MHZ : integer := 1 - USE_125_MHZ;
  
  --Clock / Reset
  signal clk_sys_i                : std_logic;  --clock for main logic, 100 MHz, via Clock Manager and internal PLL
--   signal clk_200_i                : std_logic;  --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
  signal pll_lock                 : std_logic;  --Internal PLL locked. E.g. used to reset all internal logic.
  signal clear_i                  : std_logic;
  signal reset_i                  : std_logic;
  signal GSR_N                    : std_logic;
  attribute syn_keep of GSR_N     : signal is true;
  attribute syn_preserve of GSR_N : signal is true;
  signal clk_sys_internal         : std_logic;
  signal clk_raw_internal         : std_logic;
  signal rx_clock_half             : std_logic;
  signal rx_clock_full             : std_logic;
  signal clk_tdc                  : std_logic;
  signal time_counter, time_counter2 : unsigned(31 downto 0);
  --Media Interface
  signal med_stat_op        : std_logic_vector (NUM_INTERFACES*16-1 downto 0);
  signal med_ctrl_op        : std_logic_vector (NUM_INTERFACES*16-1 downto 0);
  signal med_stat_debug     : std_logic_vector (NUM_INTERFACES*64-1 downto 0);
  signal med_ctrl_debug     : std_logic_vector (NUM_INTERFACES*64-1 downto 0);
  signal med_data_out       : std_logic_vector (NUM_INTERFACES*16-1 downto 0);
  signal med_packet_num_out : std_logic_vector (NUM_INTERFACES* 3-1 downto 0);
  signal med_dataready_out  : std_logic_vector (NUM_INTERFACES* 1-1 downto 0);
  signal med_read_out       : std_logic_vector (NUM_INTERFACES* 1-1 downto 0);
  signal med_data_in        : std_logic_vector (NUM_INTERFACES*16-1 downto 0);
  signal med_packet_num_in  : std_logic_vector (NUM_INTERFACES* 3-1 downto 0);
  signal med_dataready_in   : std_logic_vector (NUM_INTERFACES* 1-1 downto 0);
  signal med_read_in        : std_logic_vector (NUM_INTERFACES* 1-1 downto 0);

  --Slow Control channel
  signal common_stat_reg        : std_logic_vector(std_COMSTATREG*32-1 downto 0);
  signal common_ctrl_reg        : std_logic_vector(std_COMCTRLREG*32-1 downto 0);
  signal stat_reg               : std_logic_vector(32*2**REGIO_NUM_STAT_REGS-1 downto 0);
  signal ctrl_reg               : std_logic_vector(32*2**REGIO_NUM_CTRL_REGS-1 downto 0);
  signal common_stat_reg_strobe : std_logic_vector(std_COMSTATREG-1 downto 0);
  signal common_ctrl_reg_strobe : std_logic_vector(std_COMCTRLREG-1 downto 0);
  signal stat_reg_strobe        : std_logic_vector(2**REGIO_NUM_STAT_REGS-1 downto 0);
  signal ctrl_reg_strobe        : std_logic_vector(2**REGIO_NUM_CTRL_REGS-1 downto 0);

  --RegIO
  signal my_address             : std_logic_vector (15 downto 0);
  signal regio_addr_out         : std_logic_vector (15 downto 0);
  signal regio_read_enable_out  : std_logic;
  signal regio_write_enable_out : std_logic;
  signal regio_data_out         : std_logic_vector (31 downto 0);
  signal regio_data_in          : std_logic_vector (31 downto 0);
  signal regio_dataready_in     : std_logic;
  signal regio_no_more_data_in  : std_logic;
  signal regio_write_ack_in     : std_logic;
  signal regio_unknown_addr_in  : std_logic;
  signal regio_timeout_out      : std_logic;

  --Timer
  signal global_time         : std_logic_vector(31 downto 0);
  signal local_time          : std_logic_vector(7 downto 0);
  signal time_since_last_trg : std_logic_vector(31 downto 0);
  signal timer_ticks         : std_logic_vector(1 downto 0);

  --Flash
  signal spimem_read_en          : std_logic;
  signal spimem_write_en         : std_logic;
  signal spimem_data_in          : std_logic_vector(31 downto 0);
  signal spimem_addr             : std_logic_vector(8 downto 0);
  signal spimem_data_out         : std_logic_vector(31 downto 0);
  signal spimem_dataready_out    : std_logic;
  signal spimem_no_more_data_out : std_logic;
  signal spimem_unknown_addr_out : std_logic;
  signal spimem_write_ack_out    : std_logic;

  signal sci1_ack      : std_logic;
  signal sci1_write    : std_logic;
  signal sci1_read     : std_logic;
  signal sci1_data_in  : std_logic_vector(7 downto 0);
  signal sci1_data_out : std_logic_vector(7 downto 0);
  signal sci1_addr     : std_logic_vector(8 downto 0);  
  signal sci2_ack      : std_logic;
  signal sci2_nack     : std_logic;
  signal sci2_write    : std_logic;
  signal sci2_read     : std_logic;
  signal sci2_data_in  : std_logic_vector(7 downto 0);
  signal sci2_data_out : std_logic_vector(7 downto 0);
  signal sci2_addr     : std_logic_vector(8 downto 0);  

  --TDC
  signal hit_in_i : std_logic_vector(63 downto 0);
      
  signal soda_rx_clock_half : std_logic;
  signal soda_rx_clock_full : std_logic;
  signal tx_dlm_i          : std_logic;
  signal rx_dlm_i          : std_logic;
  signal tx_dlm_word       : std_logic_vector(7 downto 0);
  signal rx_dlm_word       : std_logic_vector(7 downto 0);

begin
---------------------------------------------------------------------------
-- Reset Generation
---------------------------------------------------------------------------

  GSR_N <= pll_lock;

  THE_RESET_HANDLER : trb_net_reset_handler
    generic map(
      RESET_DELAY => x"FEEE"
      )
    port map(
      CLEAR_IN      => '0',              -- reset input (high active, async)
      CLEAR_N_IN    => '1',              -- reset input (low active, async)
      CLK_IN        => clk_raw_internal, -- raw master clock, NOT from PLL/DLL!
      SYSCLK_IN     => clk_sys_i,        -- PLL/DLL remastered clock
      PLL_LOCKED_IN => pll_lock,         -- master PLL lock signal (async)
      RESET_IN      => '0',              -- general reset signal (SYSCLK)
      TRB_RESET_IN  => med_stat_op(13),  -- TRBnet reset signal (SYSCLK)
      CLEAR_OUT     => clear_i,          -- async reset out, USE WITH CARE!
      RESET_OUT     => reset_i,          -- synchronous reset out (SYSCLK)
      DEBUG_OUT     => open
      );  


---------------------------------------------------------------------------
-- Clock Handling
---------------------------------------------------------------------------
gen_200_PLL : if USE_125_MHZ = c_NO generate
  THE_MAIN_PLL : pll_in200_out100
    port map(
      CLK   => CLK_GPLL_RIGHT,
      CLKOP => clk_sys_internal,
      CLKOK => clk_raw_internal,
      LOCK  => pll_lock
      );
end generate;      

gen_125 : if USE_125_MHZ = c_YES generate
  clk_sys_internal <= CLK_GPLL_LEFT;
  clk_raw_internal <= CLK_GPLL_LEFT;
end generate; 

gen_sync_clocks : if SYNC_MODE = c_YES generate
  clk_sys_i <= rx_clock_half;
--   clk_200_i <= rx_clock_full;
end generate;

gen_local_clocks : if SYNC_MODE = c_NO generate
  clk_sys_i <= clk_sys_internal;
--   clk_200_i <= clk_raw_internal;
end generate;


---------------------------------------------------------------------------
-- The TrbNet media interface (to other FPGA)
---------------------------------------------------------------------------
  THE_MEDIA_UPLINK : trb_net16_med_ecp3_sfp
    generic map(
      SERDES_NUM  => 1,     --number of serdes in quad
      EXT_CLOCK   => c_NO,  --use internal clock
      USE_200_MHZ => USE_200_MHZ, --run on 200 MHz clock
      USE_125_MHZ => USE_125_MHZ,
      USE_CTC     => c_NO,
      USE_SLAVE   => SYNC_MODE
      )      
    port map(
      CLK                => clk_raw_internal,
      SYSCLK             => clk_sys_i,
      RESET              => reset_i,
      CLEAR              => clear_i,
      CLK_EN             => '1',
      --Internal Connection
      MED_DATA_IN        => med_data_out(15 downto 0),
      MED_PACKET_NUM_IN  => med_packet_num_out(2 downto 0),
      MED_DATAREADY_IN   => med_dataready_out(0),
      MED_READ_OUT       => med_read_in(0),
      MED_DATA_OUT       => med_data_in(15 downto 0),
      MED_PACKET_NUM_OUT => med_packet_num_in(2 downto 0),
      MED_DATAREADY_OUT  => med_dataready_in(0),
      MED_READ_IN        => med_read_out(0),
      REFCLK2CORE_OUT    => open,
      CLK_RX_HALF_OUT    => rx_clock_half,
      CLK_RX_FULL_OUT    => rx_clock_full,
      
      --SFP Connection
      SD_RXD_P_IN        => SERDES_ADDON_RX(2),
      SD_RXD_N_IN        => SERDES_ADDON_RX(3),
      SD_TXD_P_OUT       => SERDES_ADDON_TX(2),
      SD_TXD_N_OUT       => SERDES_ADDON_TX(3),
      SD_REFCLK_P_IN     => '0',
      SD_REFCLK_N_IN     => '0',
      SD_PRSNT_N_IN      => FPGA5_COMM(0),
      SD_LOS_IN          => FPGA5_COMM(0),
      SD_TXDIS_OUT       => FPGA5_COMM(2),
      
      SCI_DATA_IN        => sci1_data_in,
      SCI_DATA_OUT       => sci1_data_out,
      SCI_ADDR           => sci1_addr,
      SCI_READ           => sci1_read,
      SCI_WRITE          => sci1_write,
      SCI_ACK            => sci1_ack,        
      -- Status and control port
      STAT_OP            => med_stat_op(15 downto 0),
      CTRL_OP            => med_ctrl_op(15 downto 0),
      STAT_DEBUG         => med_stat_debug(63 downto 0),
      CTRL_DEBUG         => (others => '0')
      );


---------------------------------------------------------------------------
-- Endpoint
---------------------------------------------------------------------------
--   THE_ENDPOINT : trb_net16_endpoint_hades_full_handler
--     generic map(
--       REGIO_NUM_STAT_REGS       => REGIO_NUM_STAT_REGS,  --4,    --16 stat reg
--       REGIO_NUM_CTRL_REGS       => REGIO_NUM_CTRL_REGS,  --3,    --8 cotrol reg
--       ADDRESS_MASK              => x"FFFF",
--       BROADCAST_BITMASK         => x"FF",
--       BROADCAST_SPECIAL_ADDR    => x"45",
--       REGIO_COMPILE_TIME        => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME, 32)),
--       REGIO_HARDWARE_VERSION    => x"91000000",
--       REGIO_INIT_ADDRESS        => x"f306",
--       REGIO_USE_VAR_ENDPOINT_ID => c_YES,
--       CLOCK_FREQUENCY           => 100,
--       TIMING_TRIGGER_RAW        => c_YES,
--       --Configure data handler
--       DATA_INTERFACE_NUMBER     => 1,
--       DATA_BUFFER_DEPTH         => 9,  --13
--       DATA_BUFFER_WIDTH         => 32,
--       DATA_BUFFER_FULL_THRESH   => 256,
--       TRG_RELEASE_AFTER_DATA    => c_YES,
--       HEADER_BUFFER_DEPTH       => 9,
--       HEADER_BUFFER_FULL_THRESH => 256
--       )
--     port map(
--       CLK                => clk_sys_i,
--       RESET              => reset_i,
--       CLK_EN             => '1',
--       MED_DATAREADY_OUT  => med_dataready_out,
--       MED_DATA_OUT       => med_data_out,
--       MED_PACKET_NUM_OUT => med_packet_num_out,
--       MED_READ_IN        => med_read_in,
--       MED_DATAREADY_IN   => med_dataready_in,
--       MED_DATA_IN        => med_data_in,
--       MED_PACKET_NUM_IN  => med_packet_num_in,
--       MED_READ_OUT       => med_read_out,
--       MED_STAT_OP_IN     => med_stat_op,
--       MED_CTRL_OP_OUT    => med_ctrl_op,
-- 
--       --Timing trigger in
--       TRG_TIMING_TRG_RECEIVED_IN  => '0',
--       --LVL1 trigger to FEE
--       LVL1_TRG_DATA_VALID_OUT     => open,
--       LVL1_VALID_TIMING_TRG_OUT   => open,
--       LVL1_VALID_NOTIMING_TRG_OUT => open,
--       LVL1_INVALID_TRG_OUT        => open,
-- 
--       LVL1_TRG_TYPE_OUT        => open,
--       LVL1_TRG_NUMBER_OUT      => open,
--       LVL1_TRG_CODE_OUT        => open,
--       LVL1_TRG_INFORMATION_OUT => open,
--       LVL1_INT_TRG_NUMBER_OUT  => open,
-- 
--       --Information about trigger handler errors
--       TRG_MULTIPLE_TRG_OUT     => open,
--       TRG_TIMEOUT_DETECTED_OUT => open,
--       TRG_SPURIOUS_TRG_OUT     => open,
--       TRG_MISSING_TMG_TRG_OUT  => open,
--       TRG_SPIKE_DETECTED_OUT   => open,
-- 
--       --Response from FEE
--       FEE_TRG_RELEASE_IN(0)       => '1',
--       FEE_TRG_STATUSBITS_IN       => (others => '0'),
--       FEE_DATA_IN                 => (others => '0'),
--       FEE_DATA_WRITE_IN(0)        => '0',
--       FEE_DATA_FINISHED_IN(0)     => '1',
--       FEE_DATA_ALMOST_FULL_OUT(0) => open,
-- 
--       -- Slow Control Data Port
--       REGIO_COMMON_STAT_REG_IN           => common_stat_reg,  --0x00
--       REGIO_COMMON_CTRL_REG_OUT          => common_ctrl_reg,  --0x20
--       REGIO_COMMON_STAT_STROBE_OUT       => common_stat_reg_strobe,
--       REGIO_COMMON_CTRL_STROBE_OUT       => common_ctrl_reg_strobe,
--       REGIO_STAT_REG_IN                  => stat_reg,         --start 0x80
--       REGIO_CTRL_REG_OUT                 => ctrl_reg,         --start 0xc0
--       REGIO_STAT_STROBE_OUT              => stat_reg_strobe,
--       REGIO_CTRL_STROBE_OUT              => ctrl_reg_strobe,
--       REGIO_VAR_ENDPOINT_ID(1 downto 0)  => CODE_LINE,
--       REGIO_VAR_ENDPOINT_ID(15 downto 2) => (others => '0'),
-- 
--       BUS_ADDR_OUT         => regio_addr_out,
--       BUS_READ_ENABLE_OUT  => regio_read_enable_out,
--       BUS_WRITE_ENABLE_OUT => regio_write_enable_out,
--       BUS_DATA_OUT         => regio_data_out,
--       BUS_DATA_IN          => regio_data_in,
--       BUS_DATAREADY_IN     => regio_dataready_in,
--       BUS_NO_MORE_DATA_IN  => regio_no_more_data_in,
--       BUS_WRITE_ACK_IN     => regio_write_ack_in,
--       BUS_UNKNOWN_ADDR_IN  => regio_unknown_addr_in,
--       BUS_TIMEOUT_OUT      => regio_timeout_out,
--       ONEWIRE_INOUT        => TEMPSENS,
--       ONEWIRE_MONITOR_OUT  => open,
-- 
--       TIME_GLOBAL_OUT         => global_time,
--       TIME_LOCAL_OUT          => local_time,
--       TIME_SINCE_LAST_TRG_OUT => time_since_last_trg,
--       TIME_TICKS_OUT          => timer_ticks,
-- 
--       STAT_DEBUG_IPU              => open,
--       STAT_DEBUG_1                => open,
--       STAT_DEBUG_2                => open,
--       STAT_DEBUG_DATA_HANDLER_OUT => open,
--       STAT_DEBUG_IPU_HANDLER_OUT  => open,
--       STAT_TRIGGER_OUT            => open,
--       CTRL_MPLEX                  => (others => '0'),
--       IOBUF_CTRL_GEN              => (others => '0'),
--       STAT_ONEWIRE                => open,
--       STAT_ADDR_DEBUG             => open,
--       DEBUG_LVL1_HANDLER_OUT      => open
--       );


---------------------------------------------------------------------------
-- Hub
---------------------------------------------------------------------------

THE_HUB : trb_net16_hub_base
  generic map (
    HUB_USED_CHANNELS => (c_NO,c_NO,c_NO,c_YES),
    IBUF_SECURE_MODE  => c_YES,
    MII_NUMBER        => NUM_INTERFACES,
    MII_IS_UPLINK     => (0 => 1, others => 0),
    MII_IS_DOWNLINK   => (0 => 0, others => 1),
    MII_IS_UPLINK_ONLY=> (0 => 1, others => 0),
    INT_NUMBER        => 0,
    USE_ONEWIRE       => c_YES,
    COMPILE_TIME      => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,32)),
    HARDWARE_VERSION  => x"91003200",
    INIT_ENDPOINT_ID  => x"0000",
    INIT_ADDRESS      => x"F355",
    USE_VAR_ENDPOINT_ID => c_YES,
    BROADCAST_SPECIAL_ADDR => x"45",
    CLOCK_FREQUENCY   => CLOCK_FREQUENCY
    )
  port map (
    CLK    => clk_sys_i,
    RESET  => reset_i,
    CLK_EN => '1',

    --Media interfacces
    MED_DATAREADY_OUT(NUM_INTERFACES*1-1 downto 0)   => med_dataready_out,
    MED_DATA_OUT(NUM_INTERFACES*16-1 downto 0)       => med_data_out,
    MED_PACKET_NUM_OUT(NUM_INTERFACES*3-1 downto 0)  => med_packet_num_out,
    MED_READ_IN(NUM_INTERFACES*1-1 downto 0)         => med_read_in,
    MED_DATAREADY_IN(NUM_INTERFACES*1-1 downto 0)    => med_dataready_in,
    MED_DATA_IN(NUM_INTERFACES*16-1 downto 0)        => med_data_in,
    MED_PACKET_NUM_IN(NUM_INTERFACES*3-1 downto 0)   => med_packet_num_in,
    MED_READ_OUT(NUM_INTERFACES*1-1 downto 0)        => med_read_out,
    MED_STAT_OP(NUM_INTERFACES*16-1 downto 0)        => med_stat_op,
    MED_CTRL_OP(NUM_INTERFACES*16-1 downto 0)        => med_ctrl_op,

    COMMON_STAT_REGS                => common_stat_reg,
    COMMON_CTRL_REGS                => common_ctrl_reg,
    MY_ADDRESS_OUT                  => open,
    --REGIO INTERFACE
    REGIO_ADDR_OUT                  => regio_addr_out,
    REGIO_READ_ENABLE_OUT           => regio_read_enable_out,
    REGIO_WRITE_ENABLE_OUT          => regio_write_enable_out,
    REGIO_DATA_OUT                  => regio_data_out,
    REGIO_DATA_IN                   => regio_data_in,
    REGIO_DATAREADY_IN              => regio_dataready_in,
    REGIO_NO_MORE_DATA_IN           => regio_no_more_data_in,
    REGIO_WRITE_ACK_IN              => regio_write_ack_in,
    REGIO_UNKNOWN_ADDR_IN           => regio_unknown_addr_in,
    REGIO_TIMEOUT_OUT               => regio_timeout_out,
    REGIO_VAR_ENDPOINT_ID(1 downto 0) => CODE_LINE,
    REGIO_VAR_ENDPOINT_ID(15 downto 2) => (others => '0'),
    ONEWIRE                         => TEMPSENS,
    ONEWIRE_MONITOR_OUT             => open,
    --Status ports (for debugging)
    MPLEX_CTRL            => (others => '0'),
    CTRL_DEBUG            => (others => '0'),
    STAT_DEBUG            => open
    );



---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 3,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"b000", 2 => x"b800", others => x"0000"),
      PORT_ADDR_MASK => (0 => 9,       1 => 9,       2 => 9,       others => 0)
      )
    port map(
      CLK   => clk_sys_i,
      RESET => reset_i,

      DAT_ADDR_IN          => regio_addr_out,
      DAT_DATA_IN          => regio_data_out,
      DAT_DATA_OUT         => regio_data_in,
      DAT_READ_ENABLE_IN   => regio_read_enable_out,
      DAT_WRITE_ENABLE_IN  => regio_write_enable_out,
      DAT_TIMEOUT_IN       => regio_timeout_out,
      DAT_DATAREADY_OUT    => regio_dataready_in,
      DAT_WRITE_ACK_OUT    => regio_write_ack_in,
      DAT_NO_MORE_DATA_OUT => regio_no_more_data_in,
      DAT_UNKNOWN_ADDR_OUT => regio_unknown_addr_in,

    --Bus Handler (SPI Memory)
      BUS_READ_ENABLE_OUT(0)              => spimem_read_en,
      BUS_WRITE_ENABLE_OUT(0)             => spimem_write_en,
      BUS_DATA_OUT(0*32+31 downto 0*32)   => spimem_data_in,
      BUS_ADDR_OUT(0*16+8 downto 0*16)    => spimem_addr,
      BUS_ADDR_OUT(0*16+15 downto 0*16+9) => open,
      BUS_TIMEOUT_OUT(0)                  => open,
      BUS_DATA_IN(0*32+31 downto 0*32)    => spimem_data_out,
      BUS_DATAREADY_IN(0)                 => spimem_dataready_out,
      BUS_WRITE_ACK_IN(0)                 => spimem_write_ack_out,
      BUS_NO_MORE_DATA_IN(0)              => spimem_no_more_data_out,
      BUS_UNKNOWN_ADDR_IN(0)              => spimem_unknown_addr_out,


      --SCI first Media Interface
      BUS_READ_ENABLE_OUT(1)              => sci1_read,
      BUS_WRITE_ENABLE_OUT(1)             => sci1_write,
      BUS_DATA_OUT(1*32+7 downto 1*32)    => sci1_data_in,
      BUS_DATA_OUT(1*32+31 downto 1*32+8) => open,
      BUS_ADDR_OUT(1*16+8 downto 1*16)    => sci1_addr,
      BUS_ADDR_OUT(1*16+15 downto 1*16+9) => open,
      BUS_TIMEOUT_OUT(1)                  => open,
      BUS_DATA_IN(1*32+7 downto 1*32)     => sci1_data_out,
      BUS_DATAREADY_IN(1)                 => sci1_ack,
      BUS_WRITE_ACK_IN(1)                 => sci1_ack,
      BUS_NO_MORE_DATA_IN(1)              => '0',
      BUS_UNKNOWN_ADDR_IN(1)              => '0',
      --SCI soda test Media Interface
      BUS_READ_ENABLE_OUT(2)              => sci2_read,
      BUS_WRITE_ENABLE_OUT(2)             => sci2_write,
      BUS_DATA_OUT(2*32+7 downto 2*32)    => sci2_data_in,
      BUS_DATA_OUT(2*32+31 downto 2*32+8) => open,
      BUS_ADDR_OUT(2*16+8 downto 2*16)    => sci2_addr,
      BUS_ADDR_OUT(2*16+15 downto 2*16+9) => open,
      BUS_TIMEOUT_OUT(2)                  => open,
      BUS_DATA_IN(2*32+7 downto 2*32)     => sci2_data_out,
      BUS_DATAREADY_IN(2)                 => sci2_ack,
      BUS_WRITE_ACK_IN(2)                 => sci2_ack,
      BUS_NO_MORE_DATA_IN(2)              => '0',
      BUS_UNKNOWN_ADDR_IN(2)              => sci2_nack,
      STAT_DEBUG => open
      );

---------------------------------------------------------------------------
-- SPI / Flash
---------------------------------------------------------------------------

THE_SPI_RELOAD : entity work.spi_flash_and_fpga_reload
  port map(
    CLK_IN               => clk_sys_i,
    RESET_IN             => reset_i,
    
    BUS_ADDR_IN          => spimem_addr,
    BUS_READ_IN          => spimem_read_en,
    BUS_WRITE_IN         => spimem_write_en,
    BUS_DATAREADY_OUT    => spimem_dataready_out,
    BUS_WRITE_ACK_OUT    => spimem_write_ack_out,
    BUS_UNKNOWN_ADDR_OUT => spimem_unknown_addr_out,
    BUS_NO_MORE_DATA_OUT => spimem_no_more_data_out,
    BUS_DATA_IN          => spimem_data_in,
    BUS_DATA_OUT         => spimem_data_out,
    
    DO_REBOOT_IN         => common_ctrl_reg(15),     
    PROGRAMN             => PROGRAMN,
    
    SPI_CS_OUT           => FLASH_CS,
    SPI_SCK_OUT          => FLASH_CLK,
    SPI_SDO_OUT          => FLASH_DIN,
    SPI_SDI_IN           => FLASH_DOUT
    );

      
---------------------------------------------------------------------------
-- The synchronous interface for Soda tests
---------------------------------------------------------------------------      

THE_SODA_SOURCE : entity work.med_ecp3_sfp_sync
  generic map(
    SERDES_NUM  => 0,    --number of serdes in quad
    IS_SYNC_SLAVE => c_NO
    )
  port map(
    CLK                => clk_raw_internal, --clk_200_i,
    SYSCLK             => clk_sys_i,
    RESET              => reset_i,
    CLEAR              => clear_i,
    --Internal Connection for TrbNet data -> not used a.t.m.
    MED_DATA_IN        => med_data_out(31 downto 16),
    MED_PACKET_NUM_IN  => med_packet_num_out(5 downto 3),
    MED_DATAREADY_IN   => med_dataready_out(1),
    MED_READ_OUT       => med_read_in(1),
    MED_DATA_OUT       => med_data_in(31 downto 16),
    MED_PACKET_NUM_OUT => med_packet_num_in(5 downto 3),
    MED_DATAREADY_OUT  => med_dataready_in(1),
    MED_READ_IN        => med_read_out(1),
    CLK_RX_HALF_OUT    => soda_rx_clock_half,
    CLK_RX_FULL_OUT    => soda_rx_clock_full,
    
    RX_DLM             => rx_dlm_i,
    RX_DLM_WORD        => rx_dlm_word,
    TX_DLM             => tx_dlm_i,
    TX_DLM_WORD        => tx_dlm_word,
    --SFP Connection
    SD_RXD_P_IN        => SERDES_ADDON_RX(0),
    SD_RXD_N_IN        => SERDES_ADDON_RX(1),
    SD_TXD_P_OUT       => SERDES_ADDON_TX(0),
    SD_TXD_N_OUT       => SERDES_ADDON_TX(1),
    SD_REFCLK_P_IN     => '0',
    SD_REFCLK_N_IN     => '0',
    SD_PRSNT_N_IN      => SFP_MOD0(1),
    SD_LOS_IN          => SFP_LOS(1),
    SD_TXDIS_OUT       => SFP_TXDIS(1),
    
    SCI_DATA_IN        => sci2_data_in,
    SCI_DATA_OUT       => sci2_data_out,
    SCI_ADDR           => sci2_addr,
    SCI_READ           => sci2_read,
    SCI_WRITE          => sci2_write,
    SCI_ACK            => sci2_ack,  
    SCI_NACK           => sci2_nack,
    -- Status and control port
    STAT_OP            => med_stat_op(31 downto 16),
    CTRL_OP            => med_ctrl_op(31 downto 16),
    STAT_DEBUG         => open,
    CTRL_DEBUG         => (others => '0')
   );      

   
---------------------------------------------------------------------------
-- The Soda Source
---------------------------------------------------------------------------         
  tx_dlm_i <= '0';
  tx_dlm_word <= x"00";
   
   
---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  LED_ORANGE <= not reset_i when rising_edge(clk_sys_internal);
  LED_YELLOW <= '1';
  LED_GREEN  <= not med_stat_op(9);
  LED_RED    <= not (med_stat_op(10) or med_stat_op(11));

---------------------------------------------------------------------------
-- Test Connector
---------------------------------------------------------------------------    
--  TEST_LINE(15 downto 0) <= (others => '0');
---------------------------------------------------------------------------
-- Test Circuits
---------------------------------------------------------------------------
  process
    begin
      wait until rising_edge(clk_sys_internal);
      time_counter <= time_counter + 1;
    end process;




end architecture;
