library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE IEEE.std_logic_UNSIGNED.ALL;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.trb_net16_hub_func.all;
use work.version.all;
use work.trb_net_gbe_components.all;
use work.med_sync_define.all;



entity trb3_central is
  generic (
    USE_ETHERNET : integer range c_NO to c_YES := c_YES;
    SYNC_MODE    : integer range c_NO to c_YES := c_YES
  );
  port(
    --Clocks
--     CLK_EXT                        : in  std_logic_vector(4 downto 3); --from RJ45
    CLK_GPLL_LEFT                  : in  std_logic;  --Clock Manager 2/9, 200 MHz  <-- MAIN CLOCK
    CLK_GPLL_RIGHT                 : in  std_logic;  --Clock Manager 1/9, 125 MHz  <-- for GbE
    CLK_PCLK_LEFT                  : in  std_logic;  --Clock Fan-out, 200/400 MHz 
    CLK_PCLK_RIGHT                 : in  std_logic;  --Clock Fan-out, 200/400 MHz 
    CLK_TEST_OUT                   : out std_logic_vector(2 downto 0);

    --Trigger
    TRIGGER_LEFT                   : in  std_logic;  --left side trigger input from fan-out
    TRIGGER_RIGHT                  : in  std_logic;  --right side trigger input from fan-out
--     TRIGGER_EXT                    : in  std_logic_vector(4 downto 2); --additional trigger from RJ45
    TRIGGER_OUT                    : out std_logic;  --trigger to second input of fan-out
    --Serdes
    CLK_SERDES_INT_LEFT            : in  std_logic;  --Clock Manager 2/0, 200 MHz, only in case of problems
    CLK_SERDES_INT_RIGHT           : in  std_logic;  --Clock Manager 1/0, off, 125 MHz possible
    
    --SFP
    SFP_RX_P                       : in  std_logic_vector(6 downto 1); 
    SFP_RX_N                       : in  std_logic_vector(6 downto 1); 
    SFP_TX_P                       : out std_logic_vector(6 downto 1); 
    SFP_TX_N                       : out std_logic_vector(6 downto 1); 
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
    TEST_LINE                      : inout std_logic_vector(31 downto 0)
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
    attribute syn_useioff of PROGRAMN           : signal is false;
    
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
  
  signal clk_100_i   : std_logic; --clock for main logic, 100 MHz, via Clock Manager and internal PLL
  signal clk_200_i   : std_logic; --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
  signal pll_lock    : std_logic; --Internal PLL locked. E.g. used to reset all internal logic.
  signal clear_i     : std_logic;
  signal reset_i     : std_logic;
  signal GSR_N       : std_logic;
  attribute syn_keep of GSR_N : signal is true;
  attribute syn_preserve of GSR_N : signal is true;

  
  --FPGA Test
  signal time_counter, time_counter2 : unsigned(31 downto 0);
  signal rx_clock : std_logic;
  signal rx_clock_100 : std_logic;
  signal rx_clock_200 : std_logic;
  signal clk_100_internal : std_logic;
  signal clk_200_internal : std_logic;
  
  --Media Interface
  signal med_stat_op             : std_logic_vector (1*16-1  downto 0);
  signal med_ctrl_op             : std_logic_vector (1*16-1  downto 0);
  signal med_stat_debug          : std_logic_vector (1*64-1  downto 0);
  signal med_ctrl_debug          : std_logic_vector (1*64-1  downto 0);
  signal med_data_out            : std_logic_vector (1*16-1  downto 0);
  signal med_packet_num_out      : std_logic_vector (1*3-1   downto 0);
  signal med_dataready_out       : std_logic_vector (1*1-1   downto 0);
  signal med_read_out            : std_logic_vector (1*1-1   downto 0);
  signal med_data_in             : std_logic_vector (1*16-1  downto 0);
  signal med_packet_num_in       : std_logic_vector (1*3-1   downto 0);
  signal med_dataready_in        : std_logic_vector (1*1-1   downto 0);
  signal med_read_in             : std_logic_vector (1*1-1   downto 0);
  
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
  
  signal spictrl_read_en         : std_logic;
  signal spictrl_write_en        : std_logic;
  signal spictrl_data_in         : std_logic_vector(31 downto 0);
  signal spictrl_addr            : std_logic;
  signal spictrl_data_out        : std_logic_vector(31 downto 0);
  signal spictrl_ack             : std_logic;
  signal spictrl_busy            : std_logic;
  signal spimem_read_en          : std_logic;
  signal spimem_write_en         : std_logic;
  signal spimem_data_in          : std_logic_vector(31 downto 0);
  signal spimem_addr             : std_logic_vector(5 downto 0);
  signal spimem_data_out         : std_logic_vector(31 downto 0);
  signal spimem_ack              : std_logic;
  signal sci1_ack      : std_logic;
  signal sci1_write    : std_logic;
  signal sci1_read     : std_logic;
  signal sci1_data_in  : std_logic_vector(7 downto 0);
  signal sci1_data_out : std_logic_vector(7 downto 0);
  signal sci1_addr     : std_logic_vector(8 downto 0);
  signal sci1_nack     : std_logic;

  signal sci2_ack      : std_logic;
  signal sci2_write    : std_logic;
  signal sci2_read     : std_logic;
  signal sci2_data_in  : std_logic_vector(7 downto 0);
  signal sci2_data_out : std_logic_vector(7 downto 0);
  signal sci2_addr     : std_logic_vector(8 downto 0);  
  signal sci2_nack     : std_logic;
  
  signal spi_bram_addr           : std_logic_vector(7 downto 0);
  signal spi_bram_wr_d           : std_logic_vector(7 downto 0);
  signal spi_bram_rd_d           : std_logic_vector(7 downto 0);
  signal spi_bram_we             : std_logic;

  signal cts_number                   : std_logic_vector(15 downto 0);
  signal cts_code                     : std_logic_vector(7 downto 0);
  signal cts_information              : std_logic_vector(7 downto 0);
  signal cts_start_readout            : std_logic;
  signal cts_readout_type             : std_logic_vector(3 downto 0);
  signal cts_data                     : std_logic_vector(31 downto 0);
  signal cts_dataready                : std_logic;
  signal cts_readout_finished         : std_logic;
  signal cts_read                     : std_logic;
  signal cts_length                   : std_logic_vector(15 downto 0);
  signal cts_status_bits              : std_logic_vector(31 downto 0);
  signal fee_data                     : std_logic_vector(15 downto 0);
  signal fee_dataready                : std_logic;
  signal fee_read                     : std_logic;
  signal fee_status_bits              : std_logic_vector(31 downto 0);
  signal fee_busy                     : std_logic;

signal stage_stat_regs              : std_logic_vector (31 downto 0);
signal stage_ctrl_regs              : std_logic_vector (31 downto 0);

signal mb_stat_reg_data_wr          : std_logic_vector(31 downto 0);
signal mb_stat_reg_data_rd          : std_logic_vector(31 downto 0);
signal mb_stat_reg_read             : std_logic;
signal mb_stat_reg_write            : std_logic;
signal mb_stat_reg_ack              : std_logic;
signal mb_ip_mem_addr               : std_logic_vector(15 downto 0); -- only [7:0] in used
signal mb_ip_mem_data_wr            : std_logic_vector(31 downto 0);
signal mb_ip_mem_data_rd            : std_logic_vector(31 downto 0);
signal mb_ip_mem_read               : std_logic;
signal mb_ip_mem_write              : std_logic;
signal mb_ip_mem_ack                : std_logic;
signal ip_cfg_mem_clk				: std_logic;
signal ip_cfg_mem_addr				: std_logic_vector(7 downto 0);
signal ip_cfg_mem_data				: std_logic_vector(31 downto 0);
signal ctrl_reg_addr                : std_logic_vector(15 downto 0);
signal gbe_stp_reg_addr             : std_logic_vector(15 downto 0);
signal gbe_stp_data                 : std_logic_vector(31 downto 0);
signal gbe_stp_reg_ack              : std_logic;
signal gbe_stp_reg_data_wr          : std_logic_vector(31 downto 0);
signal gbe_stp_reg_read             : std_logic;
signal gbe_stp_reg_write            : std_logic;
signal gbe_stp_reg_data_rd          : std_logic_vector(31 downto 0);

signal debug : std_logic_vector(63 downto 0);

signal next_reset, make_reset_via_network_q : std_logic;
signal reset_counter : std_logic_vector(11 downto 0);
signal link_ok : std_logic;

signal gsc_init_data, gsc_reply_data : std_logic_vector(15 downto 0);
signal gsc_init_read, gsc_reply_read : std_logic;
signal gsc_init_dataready, gsc_reply_dataready : std_logic;
signal gsc_init_packet_num, gsc_reply_packet_num : std_logic_vector(2 downto 0);
signal gsc_busy : std_logic;
signal mc_unique_id  : std_logic_vector(63 downto 0);
signal trb_reset_in  : std_logic;
signal reset_via_gbe : std_logic;
signal timer_ticks   : std_logic_vector(1 downto 0);
signal reset_via_gbe_delayed : std_logic_vector(2 downto 0);
signal reset_i_temp  : std_logic;
signal rx_dlm_i      : std_logic;
signal tx_dlm_i      : std_logic;

  
  attribute syn_keep of sci1_addr : signal is true;
  attribute syn_preserve of sci1_addr : signal is true;
  attribute syn_keep of spictrl_addr : signal is true;
  attribute syn_preserve of spictrl_addr : signal is true;
  attribute syn_keep of spimem_addr : signal is true;
  attribute syn_preserve of spimem_addr : signal is true;
component DCS
-- synthesis translate_off
generic
 (
DCSMODE : string :=“POS”
);
-- synthesis translate_on

port (
CLK0 :in std_logic ;
CLK1 :in std_logic ;
SEL :in std_logic ;
DCSOUT :out std_logic) ;
end component;
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
    CLK_IN          => clk_200_internal,-- raw master clock, NOT from PLL/DLL!
    SYSCLK_IN       => clk_100_i,       -- PLL/DLL remastered clock
    PLL_LOCKED_IN   => pll_lock,        -- master PLL lock signal (async)
    RESET_IN        => '0',             -- general reset signal (SYSCLK)
    TRB_RESET_IN    => trb_reset_in,    -- TRBnet reset signal (SYSCLK)
    CLEAR_OUT       => clear_i,         -- async reset out, USE WITH CARE!
    RESET_OUT       => reset_i_temp,    -- synchronous reset out (SYSCLK)
    DEBUG_OUT       => open
  );

trb_reset_in <= med_stat_op(0*16+13) or reset_via_gbe; --_delayed(2);
reset_i <= reset_i_temp;

process begin
  wait until rising_edge(clk_100_i);
    if reset_i = '1' then
      reset_via_gbe_delayed <= "000";
    elsif timer_ticks(0) = '1' then
      reset_via_gbe_delayed <= reset_via_gbe_delayed(1 downto 0) & reset_via_gbe;
    end if;
  end process;

---------------------------------------------------------------------------
-- Clock Handling
---------------------------------------------------------------------------
THE_MAIN_PLL : pll_in200_out100
  port map(
    CLK    => CLK_GPLL_LEFT,
    CLKOP  => clk_100_internal,--clk_100_i
    CLKOK  => clk_200_internal,   --clk_200_i
    LOCK   => pll_lock
    );

--Temporary clock switch for debugging, should be not used!
  DCSInst0: DCS
    -- synthesis translate_off
    generic map (
      DCSMODE => “POS”
      );
    -- synthesis translate_on
    port map (
      SEL    => TEST_LINE(16),
      CLK0   => clk_100_internal,
      CLK1   => rx_clock_100,
      DCSOUT => clk_100_i
      );

  DCSInst1: DCS
    -- synthesis translate_off
    generic map (
      DCSMODE => “POS”
      );
    -- synthesis translate_on
    port map (
      SEL    => TEST_LINE(16),
      CLK0   => clk_200_internal,
      CLK1   => rx_clock_200,
      DCSOUT => clk_200_i
      );
      
--       
-- gen_sync_clocks : if SYNC_MODE = c_YES generate
--   clk_100_i <= rx_clock_100;
--   clk_200_i <= rx_clock_200;
-- end generate;
-- 
-- gen_local_clocks : if SYNC_MODE = c_NO generate
--   clk_100_i <= clk_100_internal;
--   clk_200_i <= clk_200_internal;
-- end generate;
-- 
-- 

---------------------------------------------------------------------------
-- The TrbNet media interface (Uplink)
---------------------------------------------------------------------------
THE_MEDIA_UPLINK : med_ecp3_sfp_sync
  generic map(
    SERDES_NUM  => 0,     --number of serdes in quad
    MASTER_CLOCK_SWITCH => 1
    )
  port map(
    CLK                => clk_200_internal, --clk_200_i,
    SYSCLK             => clk_100_i,
    RESET              => reset_i,
    CLEAR              => clear_i,
    --Internal Connection
    MED_DATA_IN        => med_data_out(15 downto 0),
    MED_PACKET_NUM_IN  => med_packet_num_out(2 downto 0),
    MED_DATAREADY_IN   => med_dataready_out(0),
    MED_READ_OUT       => med_read_in(0),
    MED_DATA_OUT       => med_data_in(15 downto 0),
    MED_PACKET_NUM_OUT => med_packet_num_in(2 downto 0),
    MED_DATAREADY_OUT  => med_dataready_in(0),
    MED_READ_IN        => med_read_out(0),
    CLK_RX_HALF_OUT    => rx_clock_100,
    CLK_RX_FULL_OUT    => rx_clock_200,
    
    IS_SLAVE           => TEST_LINE(16),
    RX_DLM             => rx_dlm_i,
    RX_DLM_WORD        => open,
    TX_DLM             => tx_dlm_i,
    TX_DLM_WORD        => x"00",
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
    SCI_NACK           => sci1_nack,
    -- Status and control port
    STAT_OP            => med_stat_op(15 downto 0),
    CTRL_OP            => med_ctrl_op(15 downto 0),
    STAT_DEBUG         => med_stat_debug(0*64+63 downto 0*64),
    CTRL_DEBUG         => (others => '0')
   );


SFP_TXDIS(7 downto 2) <= (others => '1');
--SFP_TXDIS(8 downto 6) <= (others => '1');


tx_dlm_i <= common_ctrl_regs(31);


-- Be careful when setting the MII_NUMBER and MII_IS_* generics!
-- for MII_NUMBER=5 (4 downlinks, 1 uplink):
-- port 0,1,2,3: downlinks to other FPGA
-- port 4: LVL1/Data channel on uplink to CTS, but internal endpoint on SCTRL
-- port 5: SCTRL channel on uplink to CTS
-- port 6: SCTRL channel from GbE interface

gen_ethernet_hub : if USE_ETHERNET = c_YES generate

  THE_HUB: trb_net16_hub_streaming_port_sctrl
  generic map( 
	  --HUB_USED_CHANNELS   => (c_YES,c_YES,c_NO,c_YES),
	  --IBUF_SECURE_MODE    => c_YES,
	  INIT_ADDRESS        => x"F305",
	  MII_NUMBER          => 2,
    
	  MII_IS_UPLINK       => (0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0),
	  MII_IS_DOWNLINK     => (1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
	  MII_IS_UPLINK_ONLY  => (0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0),

	  USE_ONEWIRE         => c_YES,
	  HARDWARE_VERSION    => x"90000E35",
	  INIT_ENDPOINT_ID    => x"0005",
	  COMPILE_TIME        => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,32))
  )
  port map( 
	  CLK                     => clk_100_i,
	  RESET                   => reset_i,
	  CLK_EN                  => '1',

	  --Media interfacces
	  MED_DATAREADY_OUT(2*1-1 downto 1)   => med_dataready_out,
	  MED_DATA_OUT(2*16-1 downto 16)      => med_data_out,
	  MED_PACKET_NUM_OUT(2*3-1 downto 3)  => med_packet_num_out,
	  MED_READ_IN(2*1-1 downto 1)         => med_read_in,
	  MED_DATAREADY_IN(2*1-1 downto 1)    => med_dataready_in,
	  MED_DATA_IN(2*16-1 downto 16)       => med_data_in,
	  MED_PACKET_NUM_IN(2*3-1 downto 3)   => med_packet_num_in,
	  MED_READ_OUT(2*1-1 downto 1)        => med_read_out,
	  MED_STAT_OP(2*16-1 downto 16)       => med_stat_op,
	  MED_CTRL_OP(2*16-1 downto 16)       => med_ctrl_op,
	  MED_STAT_OP(15 downto 0)            => x"0007",

	  --Event information coming from CTSCTS_READOUT_TYPE_OUT
	  CTS_NUMBER_OUT          => cts_number,
	  CTS_CODE_OUT            => cts_code,
	  CTS_INFORMATION_OUT     => cts_information,
	  CTS_READOUT_TYPE_OUT    => cts_readout_type,
	  CTS_START_READOUT_OUT   => cts_start_readout,
	  --Information   sent to CTS
	  --status data, equipped with DHDR
	  CTS_DATA_IN             => cts_data,
	  CTS_DATAREADY_IN        => cts_dataready,
	  CTS_READOUT_FINISHED_IN => cts_readout_finished,
	  CTS_READ_OUT            => cts_read,
	  CTS_LENGTH_IN           => cts_length,
	  CTS_STATUS_BITS_IN      => cts_status_bits,
	  -- Data from Frontends
	  FEE_DATA_OUT            => fee_data,
	  FEE_DATAREADY_OUT       => fee_dataready,
	  FEE_READ_IN             => fee_read,
	  FEE_STATUS_BITS_OUT     => fee_status_bits,
	  FEE_BUSY_OUT            => fee_busy,
	  MY_ADDRESS_IN           => my_address,
	  COMMON_STAT_REGS        => common_stat_regs, --open,
	  COMMON_CTRL_REGS        => common_ctrl_regs, --open,
	  ONEWIRE                 => TEMPSENS,
	  ONEWIRE_MONITOR_IN      => open,
	  MY_ADDRESS_OUT          => my_address,
    TIMER_TICKS_OUT         => timer_ticks,
    UNIQUE_ID_OUT           => mc_unique_id,
    EXTERNAL_SEND_RESET     => reset_via_gbe,
    
	  REGIO_ADDR_OUT          => regio_addr_out,
	  REGIO_READ_ENABLE_OUT   => regio_read_enable_out,
	  REGIO_WRITE_ENABLE_OUT  => regio_write_enable_out,
	  REGIO_DATA_OUT          => regio_data_out,
	  REGIO_DATA_IN           => regio_data_in,
	  REGIO_DATAREADY_IN      => regio_dataready_in,
	  REGIO_NO_MORE_DATA_IN   => regio_no_more_data_in,
	  REGIO_WRITE_ACK_IN      => regio_write_ack_in,
	  REGIO_UNKNOWN_ADDR_IN   => regio_unknown_addr_in,
	  REGIO_TIMEOUT_OUT       => regio_timeout_out,

    --Gbe Sctrl Input
    GSC_INIT_DATAREADY_IN        => gsc_init_dataready,
    GSC_INIT_DATA_IN             => gsc_init_data,
    GSC_INIT_PACKET_NUM_IN       => gsc_init_packet_num,
    GSC_INIT_READ_OUT            => gsc_init_read,
    GSC_REPLY_DATAREADY_OUT      => gsc_reply_dataready,
    GSC_REPLY_DATA_OUT           => gsc_reply_data,
    GSC_REPLY_PACKET_NUM_OUT     => gsc_reply_packet_num,
    GSC_REPLY_READ_IN            => gsc_reply_read,
    GSC_BUSY_OUT                 => gsc_busy,

  --status and control ports
    HUB_STAT_CHANNEL             => open,
    HUB_STAT_GEN                 => open,
    MPLEX_CTRL                   => (others => '0'),
    MPLEX_STAT                   => open,
    STAT_REGS                    => open,
    STAT_CTRL_REGS               => open,

	  --Fixed status and control ports
	  STAT_DEBUG              => open,
	  CTRL_DEBUG              => (others => '0')
  );

  ---------------------------------------------------------------------
  -- The GbE machine for blasting out data from TRBnet
  ---------------------------------------------------------------------

  GBE: trb_net16_gbe_buf
  generic map( 
	  DO_SIMULATION               => c_NO,
	  USE_125MHZ_EXTCLK           => c_NO
  )
  port map( 
	  CLK                         => clk_100_i,
	  TEST_CLK                    => '0',
	  CLK_125_IN                  => CLK_GPLL_RIGHT,
	  RESET                       => reset_i,
	  GSR_N                       => gsr_n,
	  --Debug
	  STAGE_STAT_REGS_OUT         => open, --stage_stat_regs, -- should be come STATUS or similar
	  STAGE_CTRL_REGS_IN          => stage_ctrl_regs, -- OBSELETE!
	  ----gk 22.04.10 not used any more, ip_configurator moved inside
	  ---configuration interface
	  IP_CFG_START_IN              => stage_ctrl_regs(15),
	  IP_CFG_BANK_SEL_IN           => stage_ctrl_regs(11 downto 8),
	  IP_CFG_DONE_OUT              => open,
	  IP_CFG_MEM_ADDR_OUT          => ip_cfg_mem_addr,
	  IP_CFG_MEM_DATA_IN           => ip_cfg_mem_data,
	  IP_CFG_MEM_CLK_OUT           => ip_cfg_mem_clk,
	  MR_RESET_IN                  => stage_ctrl_regs(3),
	  MR_MODE_IN                   => stage_ctrl_regs(1),
	  MR_RESTART_IN                => stage_ctrl_regs(0),
	  ---gk 29.03.10
	  --interface to ip_configurator memory
	  SLV_ADDR_IN                  => mb_ip_mem_addr(7 downto 0),
	  SLV_READ_IN                  => mb_ip_mem_read,
	  SLV_WRITE_IN                 => mb_ip_mem_write,
	  SLV_BUSY_OUT                 => open,
	  SLV_ACK_OUT                  => mb_ip_mem_ack,
	  SLV_DATA_IN                  => mb_ip_mem_data_wr,
	  SLV_DATA_OUT                 => mb_ip_mem_data_rd,
	  --gk 26.04.10
	  ---gk 22.04.10
	  ---registers setup interface
	  BUS_ADDR_IN                 => gbe_stp_reg_addr(7 downto 0), --ctrl_reg_addr(7 downto 0),
	  BUS_DATA_IN                 => gbe_stp_reg_data_wr, --stage_ctrl_regs,
	  BUS_DATA_OUT                => gbe_stp_reg_data_rd,
	  BUS_WRITE_EN_IN             => gbe_stp_reg_write,
	  BUS_READ_EN_IN              => gbe_stp_reg_read,
	  BUS_ACK_OUT                 => gbe_stp_reg_ack,
	  --gk 23.04.10
	  LED_PACKET_SENT_OUT         => open, --buf_SFP_LED_ORANGE(17),
	  LED_AN_DONE_N_OUT           => link_ok, --buf_SFP_LED_GREEN(17),
	    --CTS interface
	    CTS_NUMBER_IN               => cts_number,
	    CTS_CODE_IN                 => cts_code,
	    CTS_INFORMATION_IN          => cts_information,
	    CTS_READOUT_TYPE_IN         => cts_readout_type,
	    CTS_START_READOUT_IN        => cts_start_readout,
	    CTS_DATA_OUT                => cts_data,
	    CTS_DATAREADY_OUT           => cts_dataready,
	    CTS_READOUT_FINISHED_OUT    => cts_readout_finished,
	    CTS_READ_IN                 => cts_read,
	    CTS_LENGTH_OUT              => cts_length,
	    CTS_ERROR_PATTERN_OUT       => cts_status_bits,
	    --Data payload interface
	    FEE_DATA_IN                 => fee_data,
	    FEE_DATAREADY_IN            => fee_dataready,
	    FEE_READ_OUT                => fee_read,
	    FEE_STATUS_BITS_IN          => fee_status_bits,
	    FEE_BUSY_IN                 => fee_busy,
	  --SFP   Connection
	  SFP_RXD_P_IN                => SFP_RX_P(6), --these ports are don't care
	  SFP_RXD_N_IN                => SFP_RX_N(6),
	  SFP_TXD_P_OUT               => SFP_TX_P(6),
	  SFP_TXD_N_OUT               => SFP_TX_N(6),
	  SFP_REFCLK_P_IN             => open, --SFP_REFCLKP(2),
	  SFP_REFCLK_N_IN             => open, --SFP_REFCLKN(2),
	  SFP_PRSNT_N_IN              => SFP_MOD0(8), -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
	  SFP_LOS_IN                  => SFP_LOS(8), -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
	  SFP_TXDIS_OUT               => SFP_TXDIS(8),  -- SFP disable

    -- interface between main_controller and hub logic
    MC_UNIQUE_ID_IN          => mc_unique_id,
    GSC_CLK_IN               => clk_100_i,
    GSC_INIT_DATAREADY_OUT   => gsc_init_dataready,
    GSC_INIT_DATA_OUT        => gsc_init_data,
    GSC_INIT_PACKET_NUM_OUT  => gsc_init_packet_num,
    GSC_INIT_READ_IN         => gsc_init_read,
    GSC_REPLY_DATAREADY_IN   => gsc_reply_dataready,
    GSC_REPLY_DATA_IN        => gsc_reply_data,
    GSC_REPLY_PACKET_NUM_IN  => gsc_reply_packet_num,
    GSC_REPLY_READ_OUT       => gsc_reply_read,
    GSC_BUSY_IN              => gsc_busy,

    MAKE_RESET_OUT           => reset_via_gbe,

	  --for simulation of receiving part only
	  MAC_RX_EOF_IN		=> '0',
	  MAC_RXD_IN		=> "00000000",
	  MAC_RX_EN_IN		=> '0',

	  ANALYZER_DEBUG_OUT          => debug
  );
end generate;
-- 
---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
THE_BUS_HANDLER : trb_net16_regio_bus_handler
  generic map(
    PORT_NUMBER    => 5,
    PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", 2 => x"8100", 3 => x"8300", 4 => x"b000", 5 => x"b200", others => x"0000"),
    PORT_ADDR_MASK => (0 => 1,       1 => 6,       2 => 8,       3 => 8,       4 => 9,       5 => 9,       others => 0)
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

    -- third one - IP config memory
    BUS_ADDR_OUT(3*16-1 downto 2*16) => mb_ip_mem_addr,
    BUS_DATA_OUT(3*32-1 downto 2*32) => mb_ip_mem_data_wr,
    BUS_READ_ENABLE_OUT(2)           => mb_ip_mem_read,
    BUS_WRITE_ENABLE_OUT(2)          => mb_ip_mem_write,
    BUS_TIMEOUT_OUT(2)               => open,
    BUS_DATA_IN(3*32-1 downto 2*32)  => mb_ip_mem_data_rd,
    BUS_DATAREADY_IN(2)              => mb_ip_mem_ack,
    BUS_WRITE_ACK_IN(2)              => mb_ip_mem_ack,
    BUS_NO_MORE_DATA_IN(2)           => '0',
    BUS_UNKNOWN_ADDR_IN(2)           => '0',

    -- gk 22.04.10
    -- gbe setup
    BUS_ADDR_OUT(4*16-1 downto 3*16) => gbe_stp_reg_addr,
    BUS_DATA_OUT(4*32-1 downto 3*32) => gbe_stp_reg_data_wr,
    BUS_READ_ENABLE_OUT(3)           => gbe_stp_reg_read,
    BUS_WRITE_ENABLE_OUT(3)          => gbe_stp_reg_write,
    BUS_TIMEOUT_OUT(3)               => open,
    BUS_DATA_IN(4*32-1 downto 3*32)  => gbe_stp_reg_data_rd,
    BUS_DATAREADY_IN(3)              => gbe_stp_reg_ack,
    BUS_WRITE_ACK_IN(3)              => gbe_stp_reg_ack,
    BUS_NO_MORE_DATA_IN(3)           => '0',
    BUS_UNKNOWN_ADDR_IN(3)           => '0',
	
    --SCI first Media Interface
    BUS_READ_ENABLE_OUT(4)              => sci1_read,
    BUS_WRITE_ENABLE_OUT(4)             => sci1_write,
    BUS_DATA_OUT(4*32+7 downto 4*32)    => sci1_data_in,
    BUS_DATA_OUT(4*32+31 downto 4*32+8) => open,
    BUS_ADDR_OUT(4*16+8 downto 4*16)    => sci1_addr,
    BUS_ADDR_OUT(4*16+15 downto 4*16+9) => open,
    BUS_TIMEOUT_OUT(4)                  => open,
    BUS_DATA_IN(4*32+7 downto 4*32)     => sci1_data_out,
    BUS_DATAREADY_IN(4)                 => sci1_ack,
    BUS_WRITE_ACK_IN(4)                 => sci1_ack,
    BUS_NO_MORE_DATA_IN(4)              => sci1_nack,
    BUS_UNKNOWN_ADDR_IN(4)              => '0',
--     --SCI second Media Interface
--     BUS_READ_ENABLE_OUT(5)              => sci2_read,
--     BUS_WRITE_ENABLE_OUT(5)             => sci2_write,
--     BUS_DATA_OUT(5*32+7 downto 5*32)    => sci2_data_in,
--     BUS_DATA_OUT(5*32+31 downto 5*32+8) => open,
--     BUS_ADDR_OUT(5*16+8 downto 5*16)    => sci2_addr,
--     BUS_ADDR_OUT(5*16+15 downto 5*16+9) => open,
--     BUS_TIMEOUT_OUT(5)                  => open,
--     BUS_DATA_IN(5*32+7 downto 5*32)     => sci2_data_out,
--     BUS_DATAREADY_IN(5)                 => sci2_ack,
--     BUS_WRITE_ACK_IN(5)                 => sci2_ack,
--     BUS_NO_MORE_DATA_IN(5)              => sci2_nack,
--     BUS_UNKNOWN_ADDR_IN(5)              => '0',
    
    STAT_DEBUG  => open
    );

---------------------------------------------------------------------------
-- SPI / Flash
---------------------------------------------------------------------------

THE_SPI_MASTER: spi_master
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
THE_SPI_MEMORY: spi_databus_memory
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
    DO_REBOOT => common_ctrl_regs(15),
    PROGRAMN  => PROGRAMN
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
  LED_CLOCK_GREEN                <= TEST_LINE(16);
  LED_CLOCK_RED                  <= not TEST_LINE(16);
--   LED_GREEN                      <= not med_stat_op(9);
--   LED_YELLOW                     <= not med_stat_op(10);
--   LED_ORANGE                     <= not med_stat_op(11); 
--   LED_RED                        <= '1';
  LED_TRIGGER_GREEN              <= not med_stat_op(0*16+9);
  LED_TRIGGER_RED                <= not (med_stat_op(0*16+11) or med_stat_op(0*16+10));


--LED_GREEN <= time_counter(27);
--LED_ORANGE <= time_counter2(27);
--LED_RED <= debug(2);
--LED_YELLOW <= debug(3);

LED_GREEN  <= debug(0);
LED_ORANGE <= debug(1);
LED_RED    <= debug(2);
LED_YELLOW <= link_ok; --debug(3);


---------------------------------------------------------------------------
-- Test Connector
---------------------------------------------------------------------------    


  
  TEST_LINE(15 downto 0)  <= med_stat_debug(15 downto 0);
  TEST_LINE(16)           <= 'Z';
  TEST_LINE(31 downto 17) <= med_stat_debug(31 downto 17);
  
  CLK_TEST_OUT <= clk_100_internal & med_stat_debug(36) & rx_dlm_i;
  

--   FPGA1_CONNECTOR(0) <= '0';
  FPGA2_CONNECTOR(0) <= time_counter(0);
--   FPGA3_CONNECTOR(0) <= '0';
--   FPGA4_CONNECTOR(0) <= '0';
  
  
---------------------------------------------------------------------------
-- Test Circuits
---------------------------------------------------------------------------
  process
    begin
      wait until rising_edge(clk_100_internal);
      time_counter <= time_counter + 1;
    end process;


end architecture;