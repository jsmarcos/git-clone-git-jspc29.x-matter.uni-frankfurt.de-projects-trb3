library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.trb_net16_hub_func.all;
use work.version.all;


-- In full uplink mode:
-- connect CTS to SFP1 (TRB3 sends slow-control to CTS)
-- connect Slow-Control Master to SFP2 (TRB3 sends no triggers here)
-- use SFP3/4 as normal downlink (no GbE, hence subevent data is discarded!) 

entity trb3_central is
  generic(
    FULL_UPLINK : integer := c_YES;
    IS_HADES_HUB : integer := c_YES
    );
  port(
    --Clocks
    CLK_EXT                        : in  std_logic_vector(4 downto 3); --from RJ45
    CLK_GPLL_LEFT                  : in  std_logic;  --Clock Manager 2/9, 200 MHz  <-- MAIN CLOCK
    CLK_GPLL_RIGHT                 : in  std_logic;  --Clock Manager 1/9, 125 MHz  <-- for GbE
    CLK_PCLK_LEFT                  : in  std_logic;  --Clock Fan-out, 200/400 MHz 
    CLK_PCLK_RIGHT                 : in  std_logic;  --Clock Fan-out, 200/400 MHz 

    --Trigger
    TRIGGER_LEFT                   : in  std_logic;  --left side trigger input from fan-out
    TRIGGER_RIGHT                  : in  std_logic;  --right side trigger input from fan-out
    TRIGGER_EXT                    : in  std_logic_vector(4 downto 2); --additional trigger from RJ45
    TRIGGER_OUT                    : out std_logic;  --trigger to second input of fan-out
    
    --Serdes
    CLK_SERDES_INT_LEFT            : in  std_logic;  --Clock Manager 2/0, 200 MHz, only in case of problems
    CLK_SERDES_INT_RIGHT           : in  std_logic;  --Clock Manager 1/0, off, 125 MHz possible
    
    --SFP
    SFP_RX_P                       : in  std_logic_vector(16 downto 1); 
    SFP_RX_N                       : in  std_logic_vector(16 downto 1); 
    SFP_TX_P                       : out std_logic_vector(16 downto 1); 
    SFP_TX_N                       : out std_logic_vector(16 downto 1); 
    SFP_TX_FAULT                   : in  std_logic_vector(8 downto 1); --TX broken
    SFP_RATE_SEL                   : out std_logic_vector(8 downto 1); --not supported by our SFP
    SFP_LOS                        : in  std_logic_vector(8 downto 1); --Loss of signal
    SFP_MOD0                       : in  std_logic_vector(8 downto 1); --SFP present
    SFP_MOD1                       : in  std_logic_vector(8 downto 1); --I2C interface
    SFP_MOD2                       : in  std_logic_vector(8 downto 1); --I2C interface
    SFP_TXDIS                      : out std_logic_vector(8 downto 1); --disable TX
    
    --Clock and Trigger Control
    TRIGGER_SELECT                 : out std_logic;  --trigger select for fan-out. 0: external, 1: signal from FPGA5
    CLOCK_SELECT                   : out std_logic;  --clock select for fan-out. 0: 200MHz, 1: external from RJ45
    CLK_MNGR1_USER                 : inout std_logic_vector(3 downto 0); --I/O lines to clock manager 1
    CLK_MNGR2_USER                 : inout std_logic_vector(3 downto 0); --I/O lines to clock manager 1
    
    --Inter-FPGA Communication
    FPGA1_COMM                     : inout std_logic_vector(11 downto 0);
    FPGA2_COMM                     : inout std_logic_vector(11 downto 0);
    FPGA3_COMM                     : inout std_logic_vector(11 downto 0);
    FPGA4_COMM                     : inout std_logic_vector(11 downto 0); 
                                    -- on all FPGAn_COMM:  --Bit 0/1 output, serial link TX active
                                                           --Bit 2/3 input, serial link RX active
                                                           --others yet undefined
    FPGA1_TTL                      : inout std_logic_vector(3 downto 0);
    FPGA2_TTL                      : inout std_logic_vector(3 downto 0);
    FPGA3_TTL                      : inout std_logic_vector(3 downto 0);
    FPGA4_TTL                      : inout std_logic_vector(3 downto 0);
                                    --only for not timing-sensitive signals

    --Communication to small addons
    FPGA1_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 2-3: LED for SFP3/4
    FPGA2_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 2-3: LED for SFP7/8
    FPGA3_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 0-1: LED for SFP5/6 
    FPGA4_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 0-1: LED for SFP1/2
                                                                         --Bit 0-3 connected to LED by default, two on each side
                                                                         
    --Big AddOn connector
    ADDON_RESET                    : out std_logic; --reset signal to AddOn
    ADDON_TO_TRB_CLK               : in  std_logic; --Clock from AddOn, connected to PCLK input
    TRB_TO_ADDON_CLK               : out std_logic; --Clock sent to AddOn
    ADO_LV                         : inout std_logic_vector(61 downto 0);
    ADO_TTL                        : inout std_logic_vector(46 downto 0);
    FS_PE                          : inout std_logic_vector(17 downto 0);
    
    --Flash ROM & Reboot
    FLASH_CLK                      : out std_logic;
    FLASH_CS                       : out std_logic;
    FLASH_DIN                      : out std_logic;
    FLASH_DOUT                     : in  std_logic;
    PROGRAMN                       : out std_logic := '1'; --reboot FPGA
    
    --Misc
    ENPIRION_CLOCK                 : out std_logic;  --Clock for power supply, not necessary, floating
    TEMPSENS                       : inout std_logic; --Temperature Sensor
    LED_CLOCK_GREEN                : out std_logic;
    LED_CLOCK_RED                  : out std_logic;
    LED_GREEN                      : out std_logic;
    LED_ORANGE                     : out std_logic; 
    LED_RED                        : out std_logic;
    LED_TRIGGER_GREEN              : out std_logic;
    LED_TRIGGER_RED                : out std_logic; 
    LED_YELLOW                     : out std_logic;

    --Test Connectors
    TEST_LINE                      : out std_logic_vector(31 downto 0)
    );
    
    attribute syn_useioff : boolean;
    --no IO-FF for LEDs relaxes timing constraints
    attribute syn_useioff of LED_CLOCK_GREEN    : signal is false;
    attribute syn_useioff of LED_CLOCK_RED      : signal is false;
    attribute syn_useioff of LED_GREEN          : signal is false;
    attribute syn_useioff of LED_ORANGE         : signal is false;
    attribute syn_useioff of LED_RED            : signal is false;
    attribute syn_useioff of LED_TRIGGER_GREEN  : signal is false;
    attribute syn_useioff of LED_TRIGGER_RED    : signal is false;
    attribute syn_useioff of LED_YELLOW         : signal is false;
    attribute syn_useioff of FPGA1_TTL          : signal is false;
    attribute syn_useioff of FPGA2_TTL          : signal is false;
    attribute syn_useioff of FPGA3_TTL          : signal is false;
    attribute syn_useioff of FPGA4_TTL          : signal is false;
    attribute syn_useioff of SFP_TXDIS          : signal is false;
    
    --important signals _with_ IO-FF
    attribute syn_useioff of FLASH_CLK          : signal is true;
    attribute syn_useioff of FLASH_CS           : signal is true;
    attribute syn_useioff of FLASH_DIN          : signal is true;
    attribute syn_useioff of FLASH_DOUT         : signal is true;
    attribute syn_useioff of FPGA1_COMM         : signal is true;
    attribute syn_useioff of FPGA2_COMM         : signal is true;
    attribute syn_useioff of FPGA3_COMM         : signal is true;
    attribute syn_useioff of FPGA4_COMM         : signal is true;


end entity;

architecture trb3_central_arch of trb3_central is
  attribute syn_keep : boolean;
  attribute syn_preserve : boolean;
  
  constant NUM_PORTS : integer := 5 + FULL_UPLINK*3;
  constant RESET_SFP_IN : integer := 4 + IS_HADES_HUB;
  
  signal clk_100_i   : std_logic; --clock for main logic, 100 MHz, via Clock Manager and internal PLL
  signal clk_200_i   : std_logic; --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
  signal pll_lock    : std_logic; --Internal PLL locked. E.g. used to reset all internal logic.
  signal clear_i     : std_logic;
  signal reset_i     : std_logic;
  signal GSR_N       : std_logic;
  attribute syn_keep of GSR_N : signal is true;
  attribute syn_preserve of GSR_N : signal is true;
  
  
  --Media Interface
  signal med_stat_op             : std_logic_vector (NUM_PORTS*16-1  downto 0);
  signal med_ctrl_op             : std_logic_vector (NUM_PORTS*16-1  downto 0);
  signal med_stat_debug          : std_logic_vector (NUM_PORTS*64-1  downto 0);
  signal med_ctrl_debug          : std_logic_vector (NUM_PORTS*64-1  downto 0);
  signal med_data_out            : std_logic_vector (NUM_PORTS*16-1  downto 0);
  signal med_packet_num_out      : std_logic_vector (NUM_PORTS*3-1   downto 0);
  signal med_dataready_out       : std_logic_vector (NUM_PORTS*1-1   downto 0);
  signal med_read_out            : std_logic_vector (NUM_PORTS*1-1   downto 0);
  signal med_data_in             : std_logic_vector (NUM_PORTS*16-1  downto 0);
  signal med_packet_num_in       : std_logic_vector (NUM_PORTS*3-1   downto 0);
  signal med_dataready_in        : std_logic_vector (NUM_PORTS*1-1   downto 0);
  signal med_read_in             : std_logic_vector (NUM_PORTS*1-1   downto 0);
  
  --Hub
  signal common_stat_regs        : std_logic_vector (std_COMSTATREG*32-1 downto 0);
  signal common_ctrl_regs        : std_logic_vector (std_COMCTRLREG*32-1 downto 0);
  signal my_address              : std_logic_vector (16-1 downto 0);
  signal regio_addr_out          : std_logic_vector (16-1 downto 0);
  signal regio_read_enable_out   : std_logic;
  signal regio_write_enable_out  : std_logic;
  signal regio_data_out          : std_logic_vector (32-1 downto 0);
  signal regio_data_in           : std_logic_vector (32-1 downto 0);
  signal regio_dataready_in      : std_logic;
  signal regio_no_more_data_in   : std_logic;
  signal regio_write_ack_in      : std_logic;
  signal regio_unknown_addr_in   : std_logic;
  signal regio_timeout_out       : std_logic;
  
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
  

begin

---------------------------------------------------------------------------
-- Reset Generation
---------------------------------------------------------------------------

GSR_N   <= pll_lock;
  
THE_RESET_HANDLER : trb_net_reset_handler
  generic map(
    RESET_DELAY     => x"FEEE"
    )
  port map(
    CLEAR_IN        => '0',             -- reset input (high active, async)
    CLEAR_N_IN      => '1',             -- reset input (low active, async)
    CLK_IN          => clk_200_i,       -- raw master clock, NOT from PLL/DLL!
    SYSCLK_IN       => clk_100_i,       -- PLL/DLL remastered clock
    PLL_LOCKED_IN   => pll_lock,        -- master PLL lock signal (async)
    RESET_IN        => '0',             -- general reset signal (SYSCLK)
    TRB_RESET_IN    => med_stat_op(RESET_SFP_IN*16+13), -- TRBnet reset signal (SYSCLK)
    CLEAR_OUT       => clear_i,         -- async reset out, USE WITH CARE!
    RESET_OUT       => reset_i,         -- synchronous reset out (SYSCLK)
    DEBUG_OUT       => open
  );  

---------------------------------------------------------------------------
-- Clock Handling
---------------------------------------------------------------------------
THE_MAIN_PLL : pll_in200_out100
  port map(
    CLK    => CLK_GPLL_LEFT,
    CLKOP  => clk_100_i,
    CLKOK  => clk_200_i,
    LOCK   => pll_lock
    );


---------------------------------------------------------------------------
-- The TrbNet media interface (Uplink)
---------------------------------------------------------------------------
gen_single : if FULL_UPLINK = c_NO generate
  THE_MEDIA_UPLINK : trb_net16_med_ecp3_sfp
    generic map(
      SERDES_NUM  => 0,     --number of serdes in quad
      EXT_CLOCK   => c_NO,  --use internal clock
      USE_200_MHZ => c_YES,  --run on 200 MHz clock
      USE_CTC     => c_YES
      )
    port map(
      CLK                => clk_200_i,
      SYSCLK             => clk_100_i,
      RESET              => reset_i,
      CLEAR              => clear_i,
      CLK_EN             => '1',
      --Internal Connection
      MED_DATA_IN        => med_data_out(79 downto 64),
      MED_PACKET_NUM_IN  => med_packet_num_out(14 downto 12),
      MED_DATAREADY_IN   => med_dataready_out(4),
      MED_READ_OUT       => med_read_in(4),
      MED_DATA_OUT       => med_data_in(79 downto 64),
      MED_PACKET_NUM_OUT => med_packet_num_in(14 downto 12),
      MED_DATAREADY_OUT  => med_dataready_in(4),
      MED_READ_IN        => med_read_out(4),
      REFCLK2CORE_OUT    => open,
      --SFP Connection
      SD_RXD_P_IN        => SFP_RX_P(1),
      SD_RXD_N_IN        => SFP_RX_N(1),
      SD_TXD_P_OUT       => SFP_TX_P(1),
      SD_TXD_N_OUT       => SFP_TX_N(1),
      SD_REFCLK_P_IN     => open,
      SD_REFCLK_N_IN     => open,
      SD_PRSNT_N_IN      => SFP_MOD0(1),
      SD_LOS_IN          => SFP_LOS(1),
      SD_TXDIS_OUT       => SFP_TXDIS(1),
      
        
      SCI_DATA_IN        => sci1_data_in,
      SCI_DATA_OUT       => sci1_data_out,
      SCI_ADDR           => sci1_addr,
      SCI_READ           => sci1_read,
      SCI_WRITE          => sci1_write,
      SCI_ACK            => sci1_ack,     
      -- Status and control port
      STAT_OP            => med_stat_op(79 downto 64),
      CTRL_OP            => med_ctrl_op(79 downto 64),
      STAT_DEBUG         => med_stat_debug(4*64+63 downto 4*64),
      CTRL_DEBUG         => (others => '0')
    );
  SFP_TXDIS(8 downto 2) <= (others => '1');
end generate;

gen_full : if FULL_UPLINK = c_YES generate
  THE_MEDIA_UPLINK : entity work.trb_net16_med_ecp3_sfp_4
    generic map(
      REVERSE_ORDER => c_NO,              --order of ports
      FREQUENCY     => 200,               --run on 200 MHz clock
      USE_CTC       => c_YES
      )
    port map(
      CLK                => clk_200_i,
      SYSCLK             => clk_100_i,
      RESET              => reset_i,
      CLEAR              => clear_i,
      CLK_EN             => '1',
      --Internal Connection
      MED_DATA_IN => med_data_out(127 downto 64),
      MED_PACKET_NUM_IN   => med_packet_num_out(23 downto 12),
      MED_DATAREADY_IN    => med_dataready_out(7 downto 4),
      MED_READ_OUT        => med_read_in(7 downto 4),
      MED_DATA_OUT        => med_data_in(127 downto 64),
      MED_PACKET_NUM_OUT  => med_packet_num_in(23 downto 12),
      MED_DATAREADY_OUT   => med_dataready_in(7 downto 4),
      MED_READ_IN         => med_read_out(7 downto 4),

      REFCLK2CORE_OUT    => open,
      --SFP Connection
      SD_RXD_P_IN        => SFP_RX_P(8 downto 5),
      SD_RXD_N_IN        => SFP_RX_N(8 downto 5),
      SD_TXD_P_OUT       => SFP_TX_P(8 downto 5),
      SD_TXD_N_OUT       => SFP_TX_N(8 downto 5),
      SD_REFCLK_P_IN     => '0',
      SD_REFCLK_N_IN     => '0',
      SD_PRSNT_N_IN      => SFP_MOD0(4 downto 1),
      SD_LOS_IN          => SFP_LOS(4 downto 1),
      SD_TXDIS_OUT       => SFP_TXDIS(4 downto 1),
      
      SCI_DATA_IN       => sci1_data_in,
      SCI_DATA_OUT      => sci1_data_out,
      SCI_ADDR          => sci1_addr,
      SCI_READ          => sci1_read,
      SCI_WRITE         => sci1_write,
      SCI_ACK           => sci1_ack,
      -- Status and control port
      
      STAT_OP => med_stat_op(7*16+15 downto 4*16),
      CTRL_OP => med_ctrl_op(7*16+15 downto 4*16),
      
      STAT_DEBUG         => open,
      CTRL_DEBUG         => (others => '0')
      );
  SFP_TXDIS(7 downto 5) <= (others => '1');      
end generate; 



---------------------------------------------------------------------------
-- The TrbNet media interface (to other FPGA)
---------------------------------------------------------------------------
THE_MEDIA_ONBOARD : trb_net16_med_ecp3_sfp_4_onboard
  port map(
    CLK                => clk_200_i,
    SYSCLK             => clk_100_i,
    RESET              => reset_i,
    CLEAR              => clear_i,
    CLK_EN             => '1',
    --Internal Connection
    MED_DATA_IN        => med_data_out(63 downto 0),
    MED_PACKET_NUM_IN  => med_packet_num_out(11 downto 0),
    MED_DATAREADY_IN   => med_dataready_out(3 downto 0),
    MED_READ_OUT       => med_read_in(3 downto 0),
    MED_DATA_OUT       => med_data_in(63 downto 0),
    MED_PACKET_NUM_OUT => med_packet_num_in(11 downto 0),
    MED_DATAREADY_OUT  => med_dataready_in(3 downto 0),
    MED_READ_IN        => med_read_out(3 downto 0),
    REFCLK2CORE_OUT    => open,
    --SFP Connection
    SD_RXD_P_IN        => SFP_RX_P(12 downto 9),
    SD_RXD_N_IN        => SFP_RX_N(12 downto 9),
    SD_TXD_P_OUT       => SFP_TX_P(12 downto 9),
    SD_TXD_N_OUT       => SFP_TX_N(12 downto 9),
    SD_REFCLK_P_IN     => open,
    SD_REFCLK_N_IN     => open,
    SD_PRSNT_N_IN(0)   => FPGA1_COMM(2),
    SD_PRSNT_N_IN(1)   => FPGA2_COMM(2),
    SD_PRSNT_N_IN(2)   => FPGA3_COMM(2),
    SD_PRSNT_N_IN(3)   => FPGA4_COMM(2),
    SD_LOS_IN(0)       => FPGA1_COMM(2),
    SD_LOS_IN(1)       => FPGA2_COMM(2),
    SD_LOS_IN(2)       => FPGA3_COMM(2),
    SD_LOS_IN(3)       => FPGA4_COMM(2),
    SD_TXDIS_OUT(0)    => FPGA1_COMM(0),
    SD_TXDIS_OUT(1)    => FPGA2_COMM(0),
    SD_TXDIS_OUT(2)    => FPGA3_COMM(0),
    SD_TXDIS_OUT(3)    => FPGA4_COMM(0),
    -- Status and control port
    STAT_OP            => med_stat_op(63 downto 0),
    CTRL_OP            => med_ctrl_op(63 downto 0),
    STAT_DEBUG         => med_stat_debug(3*64+63 downto 0*64),
    CTRL_DEBUG         => (others => '0')
   );


---------------------------------------------------------------------------
-- The TrbNet Hub
---------------------------------------------------------------------------

THE_HUB : trb_net16_hub_base
  generic map (
    HUB_USED_CHANNELS => (c_YES,c_YES,c_NO,c_YES),
    IBUF_SECURE_MODE  => c_YES,
    MII_NUMBER        => NUM_PORTS,
    MII_IS_UPLINK     => (0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0),
    MII_IS_DOWNLINK   => (1,1,1,1,1,0,1,1,0,0,0,0,0,0,0,0,0),
    MII_IS_UPLINK_ONLY=> (0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0),
    INT_NUMBER        => 0,
    INT_CHANNELS      => (others => 0),
    USE_ONEWIRE       => c_YES,
    COMPILE_TIME      => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,32)),
    HARDWARE_VERSION  => x"90000000",
    INIT_ENDPOINT_ID  => x"0005",
    INIT_ADDRESS      => x"F305",
    BROADCAST_SPECIAL_ADDR => x"40"
    )
  port map (
    CLK    => clk_100_i,
    RESET  => reset_i,
    CLK_EN => '1',

    --Media interfacces
    MED_DATAREADY_OUT(NUM_PORTS*1-1 downto 0)   => med_dataready_out,
    MED_DATA_OUT(NUM_PORTS*16-1 downto 0)       => med_data_out,
    MED_PACKET_NUM_OUT(NUM_PORTS*3-1 downto 0)  => med_packet_num_out,
    MED_READ_IN(NUM_PORTS*1-1 downto 0)         => med_read_in,
    MED_DATAREADY_IN(NUM_PORTS*1-1 downto 0)    => med_dataready_in,
    MED_DATA_IN(NUM_PORTS*16-1 downto 0)        => med_data_in,
    MED_PACKET_NUM_IN(NUM_PORTS*3-1 downto 0)   => med_packet_num_in,
    MED_READ_OUT(NUM_PORTS*1-1 downto 0)        => med_read_out,
    MED_STAT_OP(NUM_PORTS*16-1 downto 0)        => med_stat_op,
    MED_CTRL_OP(NUM_PORTS*16-1 downto 0)        => med_ctrl_op,

    COMMON_STAT_REGS                => common_stat_regs,
    COMMON_CTRL_REGS                => common_ctrl_regs,
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
    PORT_NUMBER    => 2,
    PORT_ADDRESSES => (0 => x"d000", 1 => x"b000", others => x"0000"),
    PORT_ADDR_MASK => (0 => 9,       1 => 9,       others => 0)
    )
  port map(
    CLK                   => clk_100_i,
    RESET                 => reset_i,

    DAT_ADDR_IN           => regio_addr_out,
    DAT_DATA_IN           => regio_data_out,
    DAT_DATA_OUT          => regio_data_in,
    DAT_READ_ENABLE_IN    => regio_read_enable_out,
    DAT_WRITE_ENABLE_IN   => regio_write_enable_out,
    DAT_TIMEOUT_IN        => regio_timeout_out,
    DAT_DATAREADY_OUT     => regio_dataready_in,
    DAT_WRITE_ACK_OUT     => regio_write_ack_in,
    DAT_NO_MORE_DATA_OUT  => regio_no_more_data_in,
    DAT_UNKNOWN_ADDR_OUT  => regio_unknown_addr_in,

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
     
    STAT_DEBUG  => open
    );
---------------------------------------------------------------------------
-- SPI / Flash
---------------------------------------------------------------------------

THE_SPI_RELOAD : entity work.spi_flash_and_fpga_reload
  port map(
    CLK_IN               => clk_100_i,
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
    
    DO_REBOOT_IN         => common_ctrl_regs(15),     
    PROGRAMN             => PROGRAMN,
    
    SPI_CS_OUT           => FLASH_CS,
    SPI_SCK_OUT          => FLASH_CLK,
    SPI_SDO_OUT          => FLASH_DIN,
    SPI_SDI_IN           => FLASH_DOUT
    );


    
---------------------------------------------------------------------------
-- Clock and Trigger Configuration
---------------------------------------------------------------------------
  TRIGGER_SELECT <= '0'; --always external trigger source
  CLOCK_SELECT   <= '0'; --use on-board oscillator
  CLK_MNGR1_USER <= (others => '0');
  CLK_MNGR2_USER <= (others => '0'); 

  TRIGGER_OUT    <= '0';

---------------------------------------------------------------------------
-- FPGA communication
---------------------------------------------------------------------------
--   FPGA1_COMM <= (others => 'Z');
--   FPGA2_COMM <= (others => 'Z');
--   FPGA3_COMM <= (others => 'Z');
--   FPGA4_COMM <= (others => 'Z');

  FPGA1_TTL <= (others => 'Z');
  FPGA2_TTL <= (others => 'Z');
  FPGA3_TTL <= (others => 'Z');
  FPGA4_TTL <= (others => 'Z');

  FPGA1_CONNECTOR <= (others => 'Z');
  FPGA2_CONNECTOR <= (others => 'Z');
  FPGA3_CONNECTOR <= (others => 'Z');
  FPGA4_CONNECTOR <= (others => 'Z');


---------------------------------------------------------------------------
-- Big AddOn Connector
---------------------------------------------------------------------------
  ADDON_RESET      <= '1';
  TRB_TO_ADDON_CLK <= '0';
  ADO_LV           <= (others => 'Z');
  ADO_TTL          <= (others => 'Z');
  FS_PE            <= (others => 'Z');


---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  LED_CLOCK_GREEN                <= '0';
  LED_CLOCK_RED                  <= '1';
  LED_GREEN                      <= not med_stat_op(9);
  LED_YELLOW                     <= not med_stat_op(10);
  LED_ORANGE                     <= not med_stat_op(11); 
  LED_RED                        <= '1';
  LED_TRIGGER_GREEN              <= not med_stat_op(4*16+9);
  LED_TRIGGER_RED                <= not (med_stat_op(4*16+11) or med_stat_op(4*16+10));


---------------------------------------------------------------------------
-- Test Connector
---------------------------------------------------------------------------    

  TEST_LINE(7 downto 0)   <= med_data_in(7 downto 0);
  TEST_LINE(8)            <= med_dataready_in(0);
  TEST_LINE(9)            <= med_dataready_out(0);

  
  TEST_LINE(31 downto 10) <= (others => '0');


end architecture;