library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all;
use work.trb3_components.all;
use work.version.all;



entity trb3_periph_hub is
  generic(
    SYNC_MODE : integer range 0 to 1 := c_NO   --use the RX clock for internal logic and transmission. 4 SFP links only.
    );
  port(
    --Clocks
    CLK_GPLL_LEFT  : in std_logic;      --Clock Manager 1/(2468), 125 MHz
    CLK_GPLL_RIGHT : in std_logic;  --Clock Manager 2/(2468), 200 MHz  <-- MAIN CLOCK for FPGA
    CLK_PCLK_LEFT  : in std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!
    CLK_PCLK_RIGHT : in std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!

    --Trigger
    TRIGGER_LEFT  : in std_logic;       --left side trigger input from fan-out
    TRIGGER_RIGHT : in std_logic;       --right side trigger input from fan-out

    --Serdes
    CLK_SERDES_INT_LEFT  : in  std_logic;  --Clock Manager 1/(1357), off, 125 MHz possible
    CLK_SERDES_INT_RIGHT : in  std_logic;  --Clock Manager 2/(1357), 200 MHz, only in case of problems
--     SERDES_INT_TX        : out std_logic_vector(3 downto 0);
--     SERDES_INT_RX        : in  std_logic_vector(3 downto 0);
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
    SFP_MOD1   : out std_logic_vector(6 downto 1); 
    SFP_MOD2   : inout std_logic_vector(6 downto 1); 
--     SFP_RATESEL : out std_logic_vector(6 downto 1);
--     SFP_TXFAULT : in  std_logic_vector(6 downto 1);

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
  attribute syn_useioff of TRIGGER_LEFT  : signal is false;
  attribute syn_useioff of TRIGGER_RIGHT : signal is false;
  attribute syn_useioff of LED_LINKOK    : signal is false;
  attribute syn_useioff of LED_TX        : signal is false;
  attribute syn_useioff of LED_RX        : signal is false;
  attribute syn_useioff of SFP_MOD0      : signal is false;
  attribute syn_useioff of SFP_TXDIS     : signal is false;
  attribute syn_useioff of SFP_LOS       : signal is false;

  
  --important signals _with_ IO-FF
  attribute syn_useioff of FLASH_CLK  : signal is true;
  attribute syn_useioff of FLASH_CS   : signal is true;
  attribute syn_useioff of FLASH_DIN  : signal is true;
  attribute syn_useioff of FLASH_DOUT : signal is true;
  attribute syn_useioff of FPGA5_COMM : signal is true;
  attribute syn_useioff of TEST_LINE  : signal is false;
--   attribute syn_useioff of DQLL       : signal is true;
--   attribute syn_useioff of DQUL       : signal is true;
--   attribute syn_useioff of DQLR       : signal is true;
--   attribute syn_useioff of DQUR       : signal is true;
--   attribute syn_useioff of SPARE_LINE : signal is true;


end entity;

architecture trb3_periph_hub_arch of trb3_periph_hub is
  --Constants
  constant REGIO_NUM_STAT_REGS : integer := 2;
  constant REGIO_NUM_CTRL_REGS : integer := 2;

  attribute syn_keep     : boolean;
  attribute syn_preserve : boolean;

  --Clock / Reset
  signal clk_100_i                : std_logic;  --clock for main logic, 100 MHz, via Clock Manager and internal PLL
  signal clk_200_i                : std_logic;  --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
  signal pll_lock                 : std_logic;  --Internal PLL locked. E.g. used to reset all internal logic.
  signal clear_i                  : std_logic;
  signal reset_i                  : std_logic;
  signal GSR_N                    : std_logic;
  attribute syn_keep of GSR_N     : signal is true;
  attribute syn_preserve of GSR_N : signal is true;
  signal clk_100_internal         : std_logic;
  signal clk_200_internal         : std_logic;
  signal rx_clock_100             : std_logic;
  signal rx_clock_200             : std_logic;

  --Media Interface
  signal med_stat_op        : std_logic_vector (7*16-1 downto 0);
  signal med_ctrl_op        : std_logic_vector (7*16-1 downto 0);
  signal med_stat_debug     : std_logic_vector (7*64-1 downto 0);
  signal med_ctrl_debug     : std_logic_vector (7*64-1 downto 0);
  signal med_data_out       : std_logic_vector (7*16-1 downto 0);
  signal med_packet_num_out : std_logic_vector (7*3-1 downto 0);
  signal med_dataready_out  : std_logic_vector (6 downto 0);
  signal med_read_out       : std_logic_vector (6 downto 0);
  signal med_data_in        : std_logic_vector (7*16-1 downto 0);
  signal med_packet_num_in  : std_logic_vector (7*3-1 downto 0);
  signal med_dataready_in   : std_logic_vector (6 downto 0);
  signal med_read_in        : std_logic_vector (6 downto 0);


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
  signal spictrl_read_en  : std_logic;
  signal spictrl_write_en : std_logic;
  signal spictrl_data_in  : std_logic_vector(31 downto 0);
  signal spictrl_addr     : std_logic;
  signal spictrl_data_out : std_logic_vector(31 downto 0);
  signal spictrl_ack      : std_logic;
  signal spictrl_busy     : std_logic;
  signal spimem_read_en   : std_logic;
  signal spimem_write_en  : std_logic;
  signal spimem_data_in   : std_logic_vector(31 downto 0);
  signal spimem_addr      : std_logic_vector(5 downto 0);
  signal spimem_data_out  : std_logic_vector(31 downto 0);
  signal spimem_ack       : std_logic;

  signal spi_bram_addr : std_logic_vector(7 downto 0);
  signal spi_bram_wr_d : std_logic_vector(7 downto 0);
  signal spi_bram_rd_d : std_logic_vector(7 downto 0);
  signal spi_bram_we   : std_logic;

  signal sci1_ack      : std_logic;
  signal sci1_write    : std_logic;
  signal sci1_read     : std_logic;
  signal sci1_data_in  : std_logic_vector(7 downto 0);
  signal sci1_data_out : std_logic_vector(7 downto 0);
  signal sci1_addr     : std_logic_vector(8 downto 0);

  signal sci2_ack      : std_logic;
  signal sci2_write    : std_logic;
  signal sci2_read     : std_logic;
  signal sci2_data_in  : std_logic_vector(7 downto 0);
  signal sci2_data_out : std_logic_vector(7 downto 0);
  signal sci2_addr     : std_logic_vector(8 downto 0);  

  signal i2c_ack      : std_logic;
  signal i2c_nack     : std_logic;
  signal i2c_write    : std_logic;
  signal i2c_read     : std_logic;
  signal i2c_data_in  : std_logic_vector(31 downto 0);
  signal i2c_data_out : std_logic_vector(31 downto 0);
  signal i2c_addr     : std_logic_vector(7  downto 0);  
  signal buf_SFP_MOD2_IN : std_logic_vector(6 downto 1);
  signal buf_SFP_MOD2 : std_logic_vector(6 downto 1);

  signal sed_error : std_logic;
  signal bussed_rx : CTRLBUS_RX;
  signal bussed_tx : CTRLBUS_TX;  
  
  --FPGA Test
  signal time_counter : unsigned(31 downto 0);

  -- SFP DDM
  signal busddm_rx   : CTRLBUS_RX;
  signal busddm_tx   : CTRLBUS_TX;

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
      CLK_IN        => clk_200_internal, -- raw master clock, NOT from PLL/DLL!
      SYSCLK_IN     => clk_100_i,        -- PLL/DLL remastered clock
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

  THE_MAIN_PLL : pll_in200_out100
    port map(
      CLK   => CLK_GPLL_RIGHT,
      RESET => '0',
      CLKOP => clk_100_internal,
      CLKOK => clk_200_internal,
      LOCK  => pll_lock
      );
      
gen_sync_clocks : if SYNC_MODE = c_YES generate
  clk_100_i <= rx_clock_100;
  clk_200_i <= rx_clock_200;
end generate;

gen_local_clocks : if SYNC_MODE = c_NO generate
  clk_100_i <= clk_100_internal;
  clk_200_i <= clk_200_internal;
end generate;


---------------------------------------------------------------------------
-- The TrbNet media interface (to other FPGA)
---------------------------------------------------------------------------
gen_full_media : if SYNC_MODE = c_NO generate
  THE_MEDIA_UPLINK : trb_net16_med_ecp3_sfp_4
    generic map(
      REVERSE_ORDER => c_NO,              --order of ports
      FREQUENCY     => 200                --run on 200 MHz clock
      )
    port map(
      CLK                => clk_200_i,
      SYSCLK             => clk_100_i,
      RESET              => reset_i,
      CLEAR              => clear_i,
      CLK_EN             => '1',
      --Internal Connection
      MED_DATA_IN(0*16+15 downto 0*16) => (others => '0'),
      MED_DATA_IN(1*16+15 downto 1*16) => med_data_out(0*16+15 downto 0*16),
      MED_DATA_IN(2*16+15 downto 2*16) => med_data_out(5*16+15 downto 5*16),
      MED_DATA_IN(3*16+15 downto 3*16) => med_data_out(3*16+15 downto 3*16),
      
      MED_PACKET_NUM_IN(0*3+2 downto 0*3)  => "000",
      MED_PACKET_NUM_IN(1*3+2 downto 1*3)  => med_packet_num_out(0*3+2 downto 0*3),
      MED_PACKET_NUM_IN(2*3+2 downto 2*3)  => med_packet_num_out(5*3+2 downto 5*3),
      MED_PACKET_NUM_IN(3*3+2 downto 3*3)  => med_packet_num_out(3*3+2 downto 3*3),
      
      MED_DATAREADY_IN(0) => '0',
      MED_DATAREADY_IN(1) => med_dataready_out(0),
      MED_DATAREADY_IN(2) => med_dataready_out(5),
      MED_DATAREADY_IN(3) => med_dataready_out(3),

      MED_READ_OUT(0) => open,
      MED_READ_OUT(1) => med_read_in(0),
      MED_READ_OUT(2) => med_read_in(5),
      MED_READ_OUT(3) => med_read_in(3),

      MED_DATA_OUT(0*16+15 downto 0*16) => open,
      MED_DATA_OUT(1*16+15 downto 1*16) => med_data_in(0*16+15 downto 0*16),
      MED_DATA_OUT(2*16+15 downto 2*16) => med_data_in(5*16+15 downto 5*16),
      MED_DATA_OUT(3*16+15 downto 3*16) => med_data_in(3*16+15 downto 3*16),      
      
      MED_PACKET_NUM_OUT(0*3+2 downto 0*3)  => open,
      MED_PACKET_NUM_OUT(1*3+2 downto 1*3)  => med_packet_num_in(0*3+2 downto 0*3),
      MED_PACKET_NUM_OUT(2*3+2 downto 2*3)  => med_packet_num_in(5*3+2 downto 5*3),
      MED_PACKET_NUM_OUT(3*3+2 downto 3*3)  => med_packet_num_in(3*3+2 downto 3*3),

      MED_DATAREADY_OUT(0) => open,
      MED_DATAREADY_OUT(1) => med_dataready_in(0),
      MED_DATAREADY_OUT(2) => med_dataready_in(5),
      MED_DATAREADY_OUT(3) => med_dataready_in(3),

      MED_READ_IN(0) => '1',
      MED_READ_IN(1) => med_read_out(0),
      MED_READ_IN(2) => med_read_out(5),
      MED_READ_IN(3) => med_read_out(3),      

      REFCLK2CORE_OUT    => open,
      --SFP Connection
      SD_RXD_P_IN        => SERDES_ADDON_RX(11 downto 8),
      SD_RXD_N_IN        => SERDES_ADDON_RX(15 downto 12),
      SD_TXD_P_OUT       => SERDES_ADDON_TX(11 downto 8),
      SD_TXD_N_OUT       => SERDES_ADDON_TX(15 downto 12),
      SD_REFCLK_P_IN     => open,
      SD_REFCLK_N_IN     => open,
      SD_PRSNT_N_IN(0)   => '1',
      SD_PRSNT_N_IN(1)   => FPGA5_COMM(0),
      SD_PRSNT_N_IN(2)   => SFP_MOD0(5),
      SD_PRSNT_N_IN(3)   => SFP_MOD0(3),
      SD_LOS_IN(0)   => '1',
      SD_LOS_IN(1)   => FPGA5_COMM(0),
      SD_LOS_IN(2)   => SFP_LOS(5),
      SD_LOS_IN(3)   => SFP_LOS(3),
      SD_TXDIS_OUT(0)   => open,
      SD_TXDIS_OUT(1)   => FPGA5_COMM(2),
      SD_TXDIS_OUT(2)   => SFP_TXDIS(5),
      SD_TXDIS_OUT(3)   => SFP_TXDIS(3),
      
      SCI_DATA_IN       => sci1_data_in,
      SCI_DATA_OUT      => sci1_data_out,
      SCI_ADDR          => sci1_addr,
      SCI_READ          => sci1_read,
      SCI_WRITE         => sci1_write,
      SCI_ACK           => sci1_ack,
      -- Status and control port
      
      STAT_OP(0*16+15 downto 0*16) => open,
      STAT_OP(1*16+15 downto 1*16) => med_stat_op(0*16+15 downto 0*16),
      STAT_OP(2*16+15 downto 2*16) => med_stat_op(5*16+15 downto 5*16),
      STAT_OP(3*16+15 downto 3*16) => med_stat_op(3*16+15 downto 3*16),

      CTRL_OP(0*16+15 downto 0*16) => x"0000",
      CTRL_OP(1*16+15 downto 1*16) => med_ctrl_op(0*16+15 downto 0*16),
      CTRL_OP(2*16+15 downto 2*16) => med_ctrl_op(5*16+15 downto 5*16),
      CTRL_OP(3*16+15 downto 3*16) => med_ctrl_op(3*16+15 downto 3*16),
      
      STAT_DEBUG         => open,
      CTRL_DEBUG         => (others => '0')
      );
end generate; 
 
gen_sync_media : if SYNC_MODE = c_YES generate 
  med_stat_op(3*16+15 downto 3*16) <= x"0007";
  med_stat_op(5*16+15 downto 5*16) <= x"0007";  
  
  THE_MEDIA_UPLINK : trb_net16_med_ecp3_sfp
  generic map(
      SERDES_NUM  => 1,     --number of serdes in quad
      EXT_CLOCK   => c_NO,  --use internal clock
      USE_200_MHZ => c_YES, --run on 200 MHz clock
      USE_CTC     => c_NO,
      USE_SLAVE   =>  c_YES
      )
    port map(
      CLK                => clk_200_internal,
      SYSCLK             => clk_100_i,
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
      CLK_RX_HALF_OUT    => rx_clock_100,
      CLK_RX_FULL_OUT    => rx_clock_200,
      --SFP Connection
      SD_RXD_P_IN        => SERDES_ADDON_RX(8),
      SD_RXD_N_IN        => SERDES_ADDON_RX(9),
      SD_TXD_P_OUT       => SERDES_ADDON_TX(8),
      SD_TXD_N_OUT       => SERDES_ADDON_TX(9),
      SD_REFCLK_P_IN     => open,
      SD_REFCLK_N_IN     => open,
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
end generate;
      
THE_MEDIA_DOWNLINK : trb_net16_med_ecp3_sfp_4
    generic map(
      REVERSE_ORDER => c_NO,              --order of ports
      FREQUENCY     => 200                --run on 200 MHz clock
      )
    port map(
      CLK                => clk_200_i,
      SYSCLK             => clk_100_i,
      RESET              => reset_i,
      CLEAR              => clear_i,
      CLK_EN             => '1',
      --Internal Connection
      MED_DATA_IN(0*16+15 downto 0*16) => med_data_out(1*16+15 downto 1*16),
      MED_DATA_IN(1*16+15 downto 1*16) => med_data_out(6*16+15 downto 6*16),
      MED_DATA_IN(2*16+15 downto 2*16) => med_data_out(2*16+15 downto 2*16),
      MED_DATA_IN(3*16+15 downto 3*16) => med_data_out(4*16+15 downto 4*16),
      
      MED_PACKET_NUM_IN(0*3+2 downto 0*3)  => med_packet_num_out(1*3+2 downto 1*3),
      MED_PACKET_NUM_IN(1*3+2 downto 1*3)  => med_packet_num_out(6*3+2 downto 6*3),
      MED_PACKET_NUM_IN(2*3+2 downto 2*3)  => med_packet_num_out(2*3+2 downto 2*3),
      MED_PACKET_NUM_IN(3*3+2 downto 3*3)  => med_packet_num_out(4*3+2 downto 4*3),
      
      MED_DATAREADY_IN(0) => med_dataready_out(1),
      MED_DATAREADY_IN(1) => med_dataready_out(6),
      MED_DATAREADY_IN(2) => med_dataready_out(2),
      MED_DATAREADY_IN(3) => med_dataready_out(4),

      MED_READ_OUT(0) => med_read_in(1),
      MED_READ_OUT(1) => med_read_in(6),
      MED_READ_OUT(2) => med_read_in(2),
      MED_READ_OUT(3) => med_read_in(4),

      MED_DATA_OUT(0*16+15 downto 0*16) => med_data_in(1*16+15 downto 1*16),
      MED_DATA_OUT(1*16+15 downto 1*16) => med_data_in(6*16+15 downto 6*16),
      MED_DATA_OUT(2*16+15 downto 2*16) => med_data_in(2*16+15 downto 2*16),
      MED_DATA_OUT(3*16+15 downto 3*16) => med_data_in(4*16+15 downto 4*16),      
      
      MED_PACKET_NUM_OUT(0*3+2 downto 0*3)  => med_packet_num_in(1*3+2 downto 1*3),
      MED_PACKET_NUM_OUT(1*3+2 downto 1*3)  => med_packet_num_in(6*3+2 downto 6*3),
      MED_PACKET_NUM_OUT(2*3+2 downto 2*3)  => med_packet_num_in(2*3+2 downto 2*3),
      MED_PACKET_NUM_OUT(3*3+2 downto 3*3)  => med_packet_num_in(4*3+2 downto 4*3),

      MED_DATAREADY_OUT(0) => med_dataready_in(1),
      MED_DATAREADY_OUT(1) => med_dataready_in(6),
      MED_DATAREADY_OUT(2) => med_dataready_in(2),
      MED_DATAREADY_OUT(3) => med_dataready_in(4),

      MED_READ_IN(0) => med_read_out(1),
      MED_READ_IN(1) => med_read_out(6),
      MED_READ_IN(2) => med_read_out(2),
      MED_READ_IN(3) => med_read_out(4),      

      REFCLK2CORE_OUT    => open,
      --SFP Connection
      SD_RXD_P_IN        => SERDES_ADDON_RX(3 downto 0),
      SD_RXD_N_IN        => SERDES_ADDON_RX(7 downto 4),
      SD_TXD_P_OUT       => SERDES_ADDON_TX(3 downto 0),
      SD_TXD_N_OUT       => SERDES_ADDON_TX(7 downto 4),
      SD_REFCLK_P_IN     => open,
      SD_REFCLK_N_IN     => open,
      SD_PRSNT_N_IN(0)   => SFP_MOD0(1),
      SD_PRSNT_N_IN(1)   => SFP_MOD0(6),
      SD_PRSNT_N_IN(2)   => SFP_MOD0(2),
      SD_PRSNT_N_IN(3)   => SFP_MOD0(4),
      SD_LOS_IN(0)   => SFP_LOS(1),
      SD_LOS_IN(1)   => SFP_LOS(6),
      SD_LOS_IN(2)   => SFP_LOS(2),
      SD_LOS_IN(3)   => SFP_LOS(4),
      SD_TXDIS_OUT(0)   => SFP_TXDIS(1),
      SD_TXDIS_OUT(1)   => SFP_TXDIS(6),
      SD_TXDIS_OUT(2)   => SFP_TXDIS(2),
      SD_TXDIS_OUT(3)   => SFP_TXDIS(4),

      SCI_DATA_IN       => sci2_data_in,
      SCI_DATA_OUT      => sci2_data_out,
      SCI_ADDR          => sci2_addr,
      SCI_READ          => sci2_read,
      SCI_WRITE         => sci2_write,
      SCI_ACK           => sci2_ack,      
      -- Status and control port
      
      STAT_OP(0*16+15 downto 0*16) => med_stat_op(1*16+15 downto 1*16),
      STAT_OP(1*16+15 downto 1*16) => med_stat_op(6*16+15 downto 6*16),
      STAT_OP(2*16+15 downto 2*16) => med_stat_op(2*16+15 downto 2*16),
      STAT_OP(3*16+15 downto 3*16) => med_stat_op(4*16+15 downto 4*16),

      CTRL_OP(0*16+15 downto 0*16) => med_ctrl_op(1*16+15 downto 1*16),
      CTRL_OP(1*16+15 downto 1*16) => med_ctrl_op(6*16+15 downto 6*16),
      CTRL_OP(2*16+15 downto 2*16) => med_ctrl_op(2*16+15 downto 2*16),
      CTRL_OP(3*16+15 downto 3*16) => med_ctrl_op(4*16+15 downto 4*16),
      
      STAT_DEBUG         => open,
      CTRL_DEBUG         => (others => '0')
      );

      
-------------------------------------------------------------------------------
-- SFP I2C  Digital Diagnostic Monitoring (DDM) Entity
-------------------------------------------------------------------------------
-- Generate_SFP_DDM : if INCLUDE_SFP_DDM = c_YES generate
  THE_SFP_DDM : entity work.SFP_DDM_periph_hub
    port map (
      CLK100        => clk_100_i,
      TRB_RESET     => reset_i,
      BUSDDM_RX     => busddm_rx,
      BUSDDM_TX     => busddm_tx,
      SCL_EXT       => SFP_MOD1,
      SDA_EXT       => SFP_MOD2
      );
--end generate Generate_Sfp_DDM;
                 
--THE_SFP_i2C : sfp_i2c_readout
--  generic map(
--    SFP_NUMBER => 6
--    )
--  port map(
--    CLOCK     => clk_100_i,
--    RESET     => reset_i,
    
--    BUS_DATA_IN   => i2c_data_in,
--    BUS_DATA_OUT  => i2c_data_out,
--    BUS_ADDR_IN   => i2c_addr,
--    BUS_WRITE_IN  => i2c_write,
--    BUS_READ_IN   => i2c_read,
--    BUS_ACK_OUT   => i2c_ack,
--    BUS_NACK_OUT  => i2c_nack,
    
--    SDA           => SFP_MOD2,
----     SDA_IN        => buf_SFP_MOD2_IN,
--    SCL           => SFP_MOD1
--    );
    
---------------------------------------------------------------------------
-- Hub
---------------------------------------------------------------------------

THE_HUB : trb_net16_hub_base
  generic map (
    HUB_USED_CHANNELS => (c_YES,c_YES,c_NO,c_YES),
    IBUF_SECURE_MODE  => c_YES,
    MII_NUMBER        => 7,
    MII_IS_UPLINK     => (0 => 1, others => 0),
    MII_IS_DOWNLINK   => (0 => 0, others => 1),
    MII_IS_UPLINK_ONLY=> (0 => 1, others => 0),
    INT_NUMBER        => 0,
--     INT_CHANNELS      => (0,1,3,3,3,3,3,3),
    USE_ONEWIRE       => c_YES,
    COMPILE_TIME      => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,32)),
    HARDWARE_VERSION  => x"91003200",
    INIT_ENDPOINT_ID  => x"0000",
    INIT_ADDRESS      => x"F300",
    USE_VAR_ENDPOINT_ID => c_YES,
    BROADCAST_SPECIAL_ADDR => x"45"
    )
  port map (
    CLK    => clk_100_i,
    RESET  => reset_i,
    CLK_EN => '1',

    --Media interfacces
    MED_DATAREADY_OUT(7*1-1 downto 0)   => med_dataready_out,
    MED_DATA_OUT(7*16-1 downto 0)       => med_data_out,
    MED_PACKET_NUM_OUT(7*3-1 downto 0)  => med_packet_num_out,
    MED_READ_IN(7*1-1 downto 0)         => med_read_in,
    MED_DATAREADY_IN(7*1-1 downto 0)    => med_dataready_in,
    MED_DATA_IN(7*16-1 downto 0)        => med_data_in,
    MED_PACKET_NUM_IN(7*3-1 downto 0)   => med_packet_num_in,
    MED_READ_OUT(7*1-1 downto 0)        => med_read_out,
    MED_STAT_OP(7*16-1 downto 0)        => med_stat_op,
    MED_CTRL_OP(7*16-1 downto 0)        => med_ctrl_op,

    COMMON_STAT_REGS                => common_stat_reg,
    COMMON_CTRL_REGS                => common_ctrl_reg,
    MY_ADDRESS_OUT                  => my_address,
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
-- AddOn
---------------------------------------------------------------------------
--   DQLL <= (others => '0');
--   DQUL <= (others => '0');
--   DQLR <= (others => '0');
--   DQUR <= (others => '0');

---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 6,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", 2 => x"b000", 3 => x"b200", 4 => x"d600", 5 => x"d500", others => x"0000"),
      PORT_ADDR_MASK => (0 => 1,       1 => 6,       2 => 9,       3 => 9,       4 => 1,       5 => 4,       others => 0)
      )
    port map(
      CLK   => clk_100_i,
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

      --Bus Handler (SPI CTRL)
      BUS_READ_ENABLE_OUT(0)              => spictrl_read_en,
      BUS_WRITE_ENABLE_OUT(0)             => spictrl_write_en,
      BUS_DATA_OUT(0*32+31 downto 0*32)   => spictrl_data_in,
      BUS_ADDR_OUT(0*16)                  => spictrl_addr,
      BUS_ADDR_OUT(0*16+15 downto 0*16+1) => open,
      BUS_TIMEOUT_OUT(0)                  => open,
      BUS_DATA_IN(0*32+31 downto 0*32)    => spictrl_data_out,
      BUS_DATAREADY_IN(0)                 => spictrl_ack,
      BUS_WRITE_ACK_IN(0)                 => spictrl_ack,
      BUS_NO_MORE_DATA_IN(0)              => spictrl_busy,
      BUS_UNKNOWN_ADDR_IN(0)              => '0',
      --Bus Handler (SPI Memory)
      BUS_READ_ENABLE_OUT(1)              => spimem_read_en,
      BUS_WRITE_ENABLE_OUT(1)             => spimem_write_en,
      BUS_DATA_OUT(1*32+31 downto 1*32)   => spimem_data_in,
      BUS_ADDR_OUT(1*16+5 downto 1*16)    => spimem_addr,
      BUS_ADDR_OUT(1*16+15 downto 1*16+6) => open,
      BUS_TIMEOUT_OUT(1)                  => open,
      BUS_DATA_IN(1*32+31 downto 1*32)    => spimem_data_out,
      BUS_DATAREADY_IN(1)                 => spimem_ack,
      BUS_WRITE_ACK_IN(1)                 => spimem_ack,
      BUS_NO_MORE_DATA_IN(1)              => '0',
      BUS_UNKNOWN_ADDR_IN(1)              => '0',
      --SCI first Media Interface
      BUS_READ_ENABLE_OUT(2)              => sci1_read,
      BUS_WRITE_ENABLE_OUT(2)             => sci1_write,
      BUS_DATA_OUT(2*32+7 downto 2*32)    => sci1_data_in,
      BUS_DATA_OUT(2*32+31 downto 2*32+8) => open,
      BUS_ADDR_OUT(2*16+8 downto 2*16)    => sci1_addr,
      BUS_ADDR_OUT(2*16+15 downto 2*16+9) => open,
      BUS_TIMEOUT_OUT(2)                  => open,
      BUS_DATA_IN(2*32+7 downto 2*32)     => sci1_data_out,
      BUS_DATAREADY_IN(2)                 => sci1_ack,
      BUS_WRITE_ACK_IN(2)                 => sci1_ack,
      BUS_NO_MORE_DATA_IN(2)              => '0',
      BUS_UNKNOWN_ADDR_IN(2)              => '0',
      --SCI second Media Interface
      BUS_READ_ENABLE_OUT(3)              => sci2_read,
      BUS_WRITE_ENABLE_OUT(3)             => sci2_write,
      BUS_DATA_OUT(3*32+7 downto 3*32)    => sci2_data_in,
      BUS_DATA_OUT(3*32+31 downto 3*32+8) => open,
      BUS_ADDR_OUT(3*16+8 downto 3*16)    => sci2_addr,
      BUS_ADDR_OUT(3*16+15 downto 3*16+9) => open,
      BUS_TIMEOUT_OUT(3)                  => open,
      BUS_DATA_IN(3*32+7 downto 3*32)     => sci2_data_out,
      BUS_DATAREADY_IN(3)                 => sci2_ack,
      BUS_WRITE_ACK_IN(3)                 => sci2_ack,
      BUS_NO_MORE_DATA_IN(3)              => '0',
      BUS_UNKNOWN_ADDR_IN(3)              => '0',
      --SFP DDM
      BUS_READ_ENABLE_OUT(4)              => busddm_rx.read,
      BUS_WRITE_ENABLE_OUT(4)             => busddm_rx.write,
      BUS_DATA_OUT(4*32+15 downto 4*32)   => busddm_rx.data(15 downto 0),
      BUS_ADDR_OUT(4*16+1 downto 4*16)    => busddm_rx.addr(1 downto 0),
      BUS_ADDR_OUT(4*16+15 downto 4*16+2) => open,
      BUS_TIMEOUT_OUT(4)                  => open,
      BUS_DATA_IN(4*32+31 downto 4*32)    => busddm_tx.data,
      BUS_DATAREADY_IN(4)                 => busddm_tx.ack,
      BUS_WRITE_ACK_IN(4)                 => busddm_rx.write,
      BUS_NO_MORE_DATA_IN(4)              => '0',
      BUS_UNKNOWN_ADDR_IN(4)              => '0',
      --I2C for SFP
      --BUS_READ_ENABLE_OUT(4)              => i2c_read,
      --BUS_WRITE_ENABLE_OUT(4)             => i2c_write,
      --BUS_DATA_OUT(4*32+31 downto 4*32)   => i2c_data_in,
      --BUS_ADDR_OUT(4*16+7 downto 4*16)    => i2c_addr,
      --BUS_ADDR_OUT(4*16+15 downto 4*16+9) => open,
      --BUS_TIMEOUT_OUT(4)                  => open,
      --BUS_DATA_IN(4*32+31 downto 4*32)    => i2c_data_out,
      --BUS_DATAREADY_IN(4)                 => i2c_ack,
      --BUS_WRITE_ACK_IN(4)                 => i2c_ack,
      --BUS_NO_MORE_DATA_IN(4)              => '0',
      --BUS_UNKNOWN_ADDR_IN(4)              => i2c_nack,   
      --SEU Detection
      BUS_READ_ENABLE_OUT(5)              => bussed_rx.read,
      BUS_WRITE_ENABLE_OUT(5)             => bussed_rx.write,
      BUS_DATA_OUT(5*32+31 downto 5*32)   => bussed_rx.data,
      BUS_ADDR_OUT(5*16+15 downto 5*16)   => bussed_rx.addr,
      BUS_TIMEOUT_OUT(5)                  => bussed_rx.timeout,
      BUS_DATA_IN(5*32+31 downto 5*32)    => bussed_tx.data,
      BUS_DATAREADY_IN(5)                 => bussed_tx.ack,
      BUS_WRITE_ACK_IN(5)                 => bussed_tx.ack,
      BUS_NO_MORE_DATA_IN(5)              => bussed_tx.nack,
      BUS_UNKNOWN_ADDR_IN(5)              => bussed_tx.unknown,      
      
      STAT_DEBUG => open
      );

---------------------------------------------------------------------------
-- SPI / Flash
---------------------------------------------------------------------------

  THE_SPI_MASTER : spi_master
    port map(
      CLK_IN         => clk_100_i,
      RESET_IN       => reset_i,
      -- Slave bus
      BUS_READ_IN    => spictrl_read_en,
      BUS_WRITE_IN   => spictrl_write_en,
      BUS_BUSY_OUT   => spictrl_busy,
      BUS_ACK_OUT    => spictrl_ack,
      BUS_ADDR_IN(0) => spictrl_addr,
      BUS_DATA_IN    => spictrl_data_in,
      BUS_DATA_OUT   => spictrl_data_out,
      -- SPI connections
      SPI_CS_OUT     => FLASH_CS,
      SPI_SDI_IN     => FLASH_DOUT,
      SPI_SDO_OUT    => FLASH_DIN,
      SPI_SCK_OUT    => FLASH_CLK,
      -- BRAM for read/write data
      BRAM_A_OUT     => spi_bram_addr,
      BRAM_WR_D_IN   => spi_bram_wr_d,
      BRAM_RD_D_OUT  => spi_bram_rd_d,
      BRAM_WE_OUT    => spi_bram_we,
      -- Status lines
      STAT           => open
      );

-- data memory for SPI accesses
  THE_SPI_MEMORY : spi_databus_memory
    port map(
      CLK_IN        => clk_100_i,
      RESET_IN      => reset_i,
      -- Slave bus
      BUS_ADDR_IN   => spimem_addr,
      BUS_READ_IN   => spimem_read_en,
      BUS_WRITE_IN  => spimem_write_en,
      BUS_ACK_OUT   => spimem_ack,
      BUS_DATA_IN   => spimem_data_in,
      BUS_DATA_OUT  => spimem_data_out,
      -- state machine connections
      BRAM_ADDR_IN  => spi_bram_addr,
      BRAM_WR_D_OUT => spi_bram_wr_d,
      BRAM_RD_D_IN  => spi_bram_rd_d,
      BRAM_WE_IN    => spi_bram_we,
      -- Status lines
      STAT          => open
      );

---------------------------------------------------------------------------
-- Reboot FPGA
---------------------------------------------------------------------------
  THE_FPGA_REBOOT : fpga_reboot
    port map(
      CLK       => clk_100_i,
      RESET     => reset_i,
      DO_REBOOT => common_ctrl_reg(15),
      PROGRAMN  => PROGRAMN
      );

---------------------------------------------------------------------------
-- SED Detection
---------------------------------------------------------------------------
  THE_SED : entity work.sedcheck
    port map(
      CLK       => clk_100_i,
      ERROR_OUT => sed_error,
      BUS_RX    => bussed_rx,
      BUS_TX    => bussed_tx
      );  
  

---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  LED_GREEN  <= not med_stat_op(9);
  LED_ORANGE <= not med_stat_op(10);
  LED_RED    <= not time_counter(26);
  LED_YELLOW <= not med_stat_op(11);


  gen_LED : for i in 1 to 6 generate
    LED_LINKOK(i) <= not med_stat_op(i*16+9);
    LED_RX(i)     <= not med_stat_op(i*16+10);
    LED_TX(i)     <= not med_stat_op(i*16+11);
  end generate;
  

---------------------------------------------------------------------------
-- Test Connector
---------------------------------------------------------------------------    
  TEST_LINE(7 downto 0)   <= med_data_in(7 downto 0);
  TEST_LINE(8)            <= med_dataready_in(0);
  TEST_LINE(9)            <= med_dataready_out(0);
  TEST_LINE(10)           <= stat_reg_strobe(0);
  TEST_LINE(15 downto 11) <= (others => '0');


  
end architecture;
