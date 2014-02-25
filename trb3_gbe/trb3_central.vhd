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
use work.config.all;
use work.trb_net_gbe_components.all;



entity trb3_central is
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
    TRIGGER_OUT2                   : out std_logic;  --trigger output on RJ45
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
  
  signal clk_sys_i   : std_logic; --clock for main logic, 100 MHz, via Clock Manager and internal PLL
  signal clk_med_i   : std_logic; --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
  signal pll_lock    : std_logic; --Internal PLL locked. E.g. used to reset all internal logic.
  signal clear_i     : std_logic;
  signal reset_i     : std_logic;
  signal GSR_N       : std_logic;
  attribute syn_keep of GSR_N : signal is true;
  attribute syn_preserve of GSR_N : signal is true;
  
  --FPGA Test
  signal rx_clock : std_logic;
  signal rx_clock_half : std_logic;
  signal rx_clock_full : std_logic;
  signal clk_sys_internal : std_logic;
  signal clk_raw_internal : std_logic;
  signal clk_gbe_internal : std_logic;
  signal clk_gbe_i        : std_logic;
  
  --Media Interface
  signal med_stat_op             : std_logic_vector (5*16-1  downto 0);
  signal med_ctrl_op             : std_logic_vector (5*16-1  downto 0);
  signal med_stat_debug          : std_logic_vector (5*64-1  downto 0);
  signal med_ctrl_debug          : std_logic_vector (5*64-1  downto 0);
  signal med_data_out            : std_logic_vector (5*16-1  downto 0);
  signal med_packet_num_out      : std_logic_vector (5*3-1   downto 0);
  signal med_dataready_out       : std_logic_vector (5*1-1   downto 0);
  signal med_read_out            : std_logic_vector (5*1-1   downto 0);
  signal med_data_in             : std_logic_vector (5*16-1  downto 0);
  signal med_packet_num_in       : std_logic_vector (5*3-1   downto 0);
  signal med_dataready_in        : std_logic_vector (5*1-1   downto 0);
  signal med_read_in             : std_logic_vector (5*1-1   downto 0);
  
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

  signal sci2_ack      : std_logic;
  signal sci2_write    : std_logic;
  signal sci2_read     : std_logic;
  signal sci2_data_in  : std_logic_vector(7 downto 0);
  signal sci2_data_out : std_logic_vector(7 downto 0);
  signal sci2_addr     : std_logic_vector(8 downto 0);  


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

signal select_tc                   : std_logic_vector(31 downto 0);
signal select_tc_data_in           : std_logic_vector(31 downto 0);
signal select_tc_write             : std_logic;
signal select_tc_read              : std_logic;
signal select_tc_ack               : std_logic;

signal trig_outputs : std_logic_vector(4 downto 0);
signal trig_inputs  : std_logic_vector(15 downto 0);
signal trig_din   : std_logic_vector(31 downto 0);
signal trig_dout  : std_logic_vector(31 downto 0);
signal trig_write : std_logic := '0';
signal trig_read  : std_logic := '0';
signal trig_ack   : std_logic := '0';
signal trig_nack  : std_logic := '0';
signal trig_addr  : std_logic_vector(15 downto 0) := (others => '0');

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
    CLK_IN          => clk_raw_internal,-- raw master clock, NOT from PLL/DLL!
    SYSCLK_IN       => clk_sys_i,       -- PLL/DLL remastered clock
    PLL_LOCKED_IN   => pll_lock,        -- master PLL lock signal (async)
    RESET_IN        => '0',             -- general reset signal (SYSCLK)
    TRB_RESET_IN    => trb_reset_in,    -- TRBnet reset signal (SYSCLK)
    CLEAR_OUT       => clear_i,         -- async reset out, USE WITH CARE!
    RESET_OUT       => reset_i_temp,    -- synchronous reset out (SYSCLK)
    DEBUG_OUT       => open
  );

trb_reset_in <= med_stat_op(4*16+13) or reset_via_gbe_delayed(2);
reset_i <= reset_i_temp;

process begin
  wait until rising_edge(clk_sys_i);
    if reset_i = '1' then
      reset_via_gbe_delayed <= "000";
    elsif timer_ticks(0) = '1' then
      reset_via_gbe_delayed <= reset_via_gbe_delayed(1 downto 0) & reset_via_gbe;
    end if;
  end process;

---------------------------------------------------------------------------
-- Clock Handling
---------------------------------------------------------------------------
gen_200_PLL : if USE_125_MHZ = c_NO generate
  THE_MAIN_PLL : pll_in200_out100
    port map(
      CLK    => CLK_GPLL_LEFT,
      CLKOP  => clk_sys_internal,   --clk_sys_i
      CLKOK  => clk_raw_internal,   --clk_med_i
      LOCK   => pll_lock
      );
  clk_gbe_internal <= CLK_GPLL_RIGHT;
end generate;

gen_125 : if USE_125_MHZ = c_YES generate
  clk_sys_internal <= CLK_GPLL_RIGHT;
  clk_raw_internal <= CLK_GPLL_RIGHT;
  clk_gbe_internal <= CLK_GPLL_RIGHT;
end generate;


gen_sync_clocks : if USE_RXCLOCK = c_YES generate
  clk_sys_i <= rx_clock_half;
  clk_med_i <= rx_clock_full;
  clk_gbe_i <= clk_gbe_internal;
end generate;

gen_local_clocks : if USE_RXCLOCK = c_NO generate
  clk_sys_i <= clk_sys_internal;
  clk_med_i <= clk_raw_internal;
  clk_gbe_i <= clk_gbe_internal;
end generate;

---------------------------------------------------------------------------
-- The TrbNet media interface (Uplink)
---------------------------------------------------------------------------

gen_uplink : if USE_125_MHZ = c_NO generate
  THE_MEDIA_UPLINK : trb_net16_med_ecp3_sfp
    generic map(
      SERDES_NUM  => 0,     --number of serdes in quad
      EXT_CLOCK   => c_NO,  --use internal clock
      USE_200_MHZ => c_YES, --run on 200 MHz clock
      USE_CTC     => c_YES,
      USE_SLAVE   =>  c_NO
      )
    port map(
      CLK                => clk_raw_internal, --clk_med_i,
      SYSCLK             => clk_sys_i,
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
      CLK_RX_HALF_OUT    => open,
      CLK_RX_FULL_OUT    => open,
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
  SFP_TXDIS(7 downto 2) <= (others => '1');
end generate;

gen_no_uplink : if USE_125_MHZ = c_YES generate
  SFP_TXDIS(7 downto 1) <= (others => '1');
  med_stat_op(66 downto 64) <= (others => '1');
  sci1_ack <= '1';
end generate;


---------------------------------------------------------------------------
-- The TrbNet media interface (to other FPGA)
---------------------------------------------------------------------------
THE_MEDIA_ONBOARD : trb_net16_med_ecp3_sfp_4
  generic map(
    FREQUENCY          => MEDIA_FREQUENCY
    )
  port map(
    CLK                => clk_med_i,
    SYSCLK             => clk_sys_i,
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
    SD_RXD_P_IN        => SFP_RX_P(5 downto 2),
    SD_RXD_N_IN        => SFP_RX_N(5 downto 2),
    SD_TXD_P_OUT       => SFP_TX_P(5 downto 2),
    SD_TXD_N_OUT       => SFP_TX_N(5 downto 2),
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
    
    SCI_DATA_IN       => sci2_data_in,
    SCI_DATA_OUT      => sci2_data_out,
    SCI_ADDR          => sci2_addr,
    SCI_READ          => sci2_read,
    SCI_WRITE         => sci2_write,
    SCI_ACK           => sci2_ack,    
    -- Status and control port
    STAT_OP            => med_stat_op(63 downto 0),
    CTRL_OP            => med_ctrl_op(63 downto 0),
    STAT_DEBUG         => med_stat_debug(3*64+63 downto 0*64),
    CTRL_DEBUG         => (others => '0')
   );



---------------------------------------------------------------------------
-- The TrbNet Hub
---------------------------------------------------------------------------
gen_normal_hub : if USE_ETHERNET = c_NO generate

  THE_HUB : trb_net16_hub_base
    generic map (
      MII_NUMBER             => INTERFACE_NUM,
      MII_IS_UPLINK          => IS_UPLINK,
      MII_IS_DOWNLINK        => IS_DOWNLINK,
      MII_IS_UPLINK_ONLY     => IS_UPLINK_ONLY, 
      INT_NUMBER             => INTERNAL_NUM,
      INT_CHANNELS           => INTERNAL_CHANNELS,
      HARDWARE_VERSION       => HARDWARE_INFO,
      HUB_USED_CHANNELS      => USED_CHANNELS,      
      INIT_ENDPOINT_ID       => INIT_ENDPOINT_ID,
      INIT_ADDRESS           => INIT_ADDRESS,
      CLOCK_FREQUENCY        => CLOCK_FREQUENCY,
      BROADCAST_SPECIAL_ADDR => BROADCAST_SPECIAL_ADDR
      )
    port map (
      CLK    => clk_sys_i,
      RESET  => reset_i,
      CLK_EN => '1',

      --Media interfacces
      MED_DATAREADY_OUT(5*1-1 downto 0)   => med_dataready_out,
      MED_DATA_OUT(5*16-1 downto 0)       => med_data_out,
      MED_PACKET_NUM_OUT(5*3-1 downto 0)  => med_packet_num_out,
      MED_READ_IN(5*1-1 downto 0)         => med_read_in,
      MED_DATAREADY_IN(5*1-1 downto 0)    => med_dataready_in,
      MED_DATA_IN(5*16-1 downto 0)        => med_data_in,
      MED_PACKET_NUM_IN(5*3-1 downto 0)   => med_packet_num_in,
      MED_READ_OUT(5*1-1 downto 0)        => med_read_out,
      MED_STAT_OP(5*16-1 downto 0)        => med_stat_op,
      MED_CTRL_OP(5*16-1 downto 0)        => med_ctrl_op,

      COMMON_STAT_REGS                => common_stat_regs,
      COMMON_CTRL_REGS                => common_ctrl_regs,
      MY_ADDRESS_OUT                  => my_address,
      TIMER_TICKS_OUT                 => timer_ticks,

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
      
  reset_via_gbe <= '0';    
end generate;

gen_ethernet_hub : if USE_ETHERNET = c_YES generate


  THE_HUB: trb_net16_hub_streaming_port_sctrl
  generic map( 
	  HUB_USED_CHANNELS   => USED_CHANNELS,
	  INIT_ADDRESS        => INIT_ADDRESS,
	  MII_NUMBER          => INTERFACE_NUM,
	  MII_IS_UPLINK       => IS_UPLINK,
	  MII_IS_DOWNLINK     => IS_DOWNLINK,
	  MII_IS_UPLINK_ONLY  => IS_UPLINK_ONLY,
	  USE_ONEWIRE         => c_YES,
	  HARDWARE_VERSION    => HARDWARE_INFO,
	  INIT_ENDPOINT_ID    => x"0005",
	  CLOCK_FREQUENCY     => CLOCK_FREQUENCY,
	  BROADCAST_SPECIAL_ADDR => BROADCAST_SPECIAL_ADDR
    )
  port map( 
	  CLK                     => clk_sys_i,
	  RESET                   => reset_i,
	  CLK_EN                  => '1',

	  --Media interfacces
	  MED_DATAREADY_OUT(5*1-1 downto 0)   => med_dataready_out,
	  MED_DATA_OUT(5*16-1 downto 0)       => med_data_out,
	  MED_PACKET_NUM_OUT(5*3-1 downto 0)  => med_packet_num_out,
	  MED_READ_IN(5*1-1 downto 0)         => med_read_in,
	  MED_DATAREADY_IN(5*1-1 downto 0)    => med_dataready_in,
	  MED_DATA_IN(5*16-1 downto 0)        => med_data_in,
	  MED_PACKET_NUM_IN(5*3-1 downto 0)   => med_packet_num_in,
	  MED_READ_OUT(5*1-1 downto 0)        => med_read_out,
	  MED_STAT_OP(5*16-1 downto 0)        => med_stat_op,
	  MED_CTRL_OP(5*16-1 downto 0)        => med_ctrl_op,

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
	  CLK                         => clk_sys_i,
	  TEST_CLK                    => '0',
	  CLK_125_IN                  => clk_gbe_internal,
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
    GSC_CLK_IN               => clk_sys_i,
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

---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
THE_BUS_HANDLER : trb_net16_regio_bus_handler
  generic map(
    PORT_NUMBER    => 7,
    PORT_ADDRESSES => (0 => x"d000", 1 => x"8100", 2 => x"8300", 3 => x"b000", 4 => x"b200", 5 => x"d300", 6 => x"cf00", others => x"0000"),
    PORT_ADDR_MASK => (0 => 9,       1 => 8,       2 => 8,       3 => 9,       4 => 9,       5 => 0,       6 => 6,       others => 0)
    )
  port map(
    CLK                   => clk_sys_i,
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

    -- third one - IP config memory
    BUS_ADDR_OUT(1*16+15 downto 1*16) => mb_ip_mem_addr,
    BUS_DATA_OUT(1*32+31 downto 1*32) => mb_ip_mem_data_wr,
    BUS_READ_ENABLE_OUT(1)            => mb_ip_mem_read,
    BUS_WRITE_ENABLE_OUT(1)           => mb_ip_mem_write,
    BUS_TIMEOUT_OUT(1)                => open,
    BUS_DATA_IN(1*32+31 downto 1*32)  => mb_ip_mem_data_rd,
    BUS_DATAREADY_IN(1)               => mb_ip_mem_ack,
    BUS_WRITE_ACK_IN(1)               => mb_ip_mem_ack,
    BUS_NO_MORE_DATA_IN(1)            => '0',
    BUS_UNKNOWN_ADDR_IN(1)            => '0',

    -- gbe setup
    BUS_ADDR_OUT(2*16+15 downto 2*16) => gbe_stp_reg_addr,
    BUS_DATA_OUT(2*32+31 downto 2*32) => gbe_stp_reg_data_wr,
    BUS_READ_ENABLE_OUT(2)            => gbe_stp_reg_read,
    BUS_WRITE_ENABLE_OUT(2)           => gbe_stp_reg_write,
    BUS_TIMEOUT_OUT(2)                => open,
    BUS_DATA_IN(2*32+31 downto 2*32)  => gbe_stp_reg_data_rd,
    BUS_DATAREADY_IN(2)               => gbe_stp_reg_ack,
    BUS_WRITE_ACK_IN(2)               => gbe_stp_reg_ack,
    BUS_NO_MORE_DATA_IN(2)            => '0',
    BUS_UNKNOWN_ADDR_IN(2)            => '0',
	
    --SCI first Media Interface
    BUS_READ_ENABLE_OUT(3)              => sci1_read,
    BUS_WRITE_ENABLE_OUT(3)             => sci1_write,
    BUS_DATA_OUT(3*32+7 downto 3*32)    => sci1_data_in,
    BUS_DATA_OUT(3*32+31 downto 3*32+8) => open,
    BUS_ADDR_OUT(3*16+8 downto 3*16)    => sci1_addr,
    BUS_ADDR_OUT(3*16+15 downto 3*16+9) => open,
    BUS_TIMEOUT_OUT(3)                  => open,
    BUS_DATA_IN(3*32+7 downto 3*32)     => sci1_data_out,
    BUS_DATAREADY_IN(3)                 => sci1_ack,
    BUS_WRITE_ACK_IN(3)                 => sci1_ack,
    BUS_NO_MORE_DATA_IN(3)              => '0',
    BUS_UNKNOWN_ADDR_IN(3)              => '0',
    --SCI second Media Interface
    BUS_READ_ENABLE_OUT(4)              => sci2_read,
    BUS_WRITE_ENABLE_OUT(4)             => sci2_write,
    BUS_DATA_OUT(4*32+7 downto 4*32)    => sci2_data_in,
    BUS_DATA_OUT(4*32+31 downto 4*32+8) => open,
    BUS_ADDR_OUT(4*16+8 downto 4*16)    => sci2_addr,
    BUS_ADDR_OUT(4*16+15 downto 4*16+9) => open,
    BUS_TIMEOUT_OUT(4)                  => open,
    BUS_DATA_IN(4*32+7 downto 4*32)     => sci2_data_out,
    BUS_DATAREADY_IN(4)                 => sci2_ack,
    BUS_WRITE_ACK_IN(4)                 => sci2_ack,
    BUS_NO_MORE_DATA_IN(4)              => '0',
    BUS_UNKNOWN_ADDR_IN(4)              => '0',

    -- Trigger and Clock Manager Settings
    BUS_ADDR_OUT(6*16-1 downto 5*16) => open,
    BUS_DATA_OUT(6*32-1 downto 5*32) => select_tc_data_in,
    BUS_READ_ENABLE_OUT(5)           => select_tc_read,
    BUS_WRITE_ENABLE_OUT(5)          => select_tc_write,
    BUS_TIMEOUT_OUT(5)               => open,
    BUS_DATA_IN(6*32-1 downto 5*32)  => select_tc,
    BUS_DATAREADY_IN(5)              => select_tc_ack,
    BUS_WRITE_ACK_IN(5)              => select_tc_ack,
    BUS_NO_MORE_DATA_IN(5)           => '0',
    BUS_UNKNOWN_ADDR_IN(5)           => '0',   
    
    --Trigger logic registers
    BUS_READ_ENABLE_OUT(6)              => trig_read,
    BUS_WRITE_ENABLE_OUT(6)             => trig_write,
    BUS_DATA_OUT(6*32+31 downto 6*32)   => trig_din,
    BUS_ADDR_OUT(6*16+15 downto 6*16)   => trig_addr,
    BUS_TIMEOUT_OUT(6)                  => open,
    BUS_DATA_IN(6*32+31 downto 6*32)    => trig_dout,
    BUS_DATAREADY_IN(6)                 => trig_ack,
    BUS_WRITE_ACK_IN(6)                 => trig_ack,
    BUS_NO_MORE_DATA_IN(6)              => '0',
    BUS_UNKNOWN_ADDR_IN(6)              => trig_nack,    
    STAT_DEBUG  => open
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
    
    DO_REBOOT_IN         => common_ctrl_regs(15),     
    PROGRAMN             => PROGRAMN,
    
    SPI_CS_OUT           => FLASH_CS,
    SPI_SCK_OUT          => FLASH_CLK,
    SPI_SDO_OUT          => FLASH_DIN,
    SPI_SDI_IN           => FLASH_DOUT
    );

---------------------------------------------------------------------------
-- Trigger logic
---------------------------------------------------------------------------
  THE_TRIG_LOGIC : input_to_trigger_logic
    generic map(
      INPUTS    => 16,
      OUTPUTS   => 5
      )
    port map(
      CLK       => clk_sys_i,
      
      INPUT     => trig_inputs,
      OUTPUT    => trig_outputs,

      DATA_IN   => trig_din,  
      DATA_OUT  => trig_dout, 
      WRITE_IN  => trig_write,
      READ_IN   => trig_read,
      ACK_OUT   => trig_ack,  
      NACK_OUT  => trig_nack, 
      ADDR_IN   => trig_addr
      );

TRIGGER_OUT2 <= trig_outputs(0);       
trig_inputs <= FPGA4_COMM(10 downto 7) & FPGA3_COMM(10 downto 7) & FPGA2_COMM(10 downto 7) & FPGA1_COMM(10 downto 7); 



---------------------------------------------------------------------------
-- Clock and Trigger Configuration
---------------------------------------------------------------------------

process begin
  wait until rising_edge(clk_sys_i);
  if reset_i = '1' then
    select_tc <= x"00000000"; --always external trigger source
  elsif select_tc_write = '1' then
    select_tc <= select_tc_data_in;
  end if;
  select_tc_ack <= select_tc_read or select_tc_write;
end process;

  TRIGGER_SELECT <= select_tc(0);
  CLOCK_SELECT   <= select_tc(8); --use on-board oscillator
  CLK_MNGR1_USER <= select_tc(19 downto 16);
  CLK_MNGR2_USER <= select_tc(27 downto 24); 

   

  TRIGGER_OUT    <= '0';

---------------------------------------------------------------------------
-- FPGA communication
---------------------------------------------------------------------------

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
  LED_TRIGGER_GREEN              <= not med_stat_op(4*16+9);
  LED_TRIGGER_RED                <= not (med_stat_op(4*16+11) or med_stat_op(4*16+10));

  LED_GREEN <= debug(0);
  LED_ORANGE <= debug(1);
  LED_RED <= debug(2);
  LED_YELLOW <= link_ok; --debug(3);


---------------------------------------------------------------------------
-- Test Connector
---------------------------------------------------------------------------    

  TEST_LINE(7 downto 0)   <= med_data_in(7 downto 0);
  TEST_LINE(8)            <= med_dataready_in(0);
  TEST_LINE(9)            <= med_dataready_out(0);

  
  TEST_LINE(31 downto 10) <= (others => '0');

  CLK_TEST_OUT <= clk_med_i & '0' & clk_sys_i;
  
  



end architecture;
