library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE IEEE.std_logic_UNSIGNED.ALL;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
--use work.trb_net16_hub_func.all;
--use work.version.all;



entity trb3_central is
  generic (
    USE_ETHERNET : integer range 0 to 1 := 1
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
    FLASH_CIN                      : out std_logic;
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
    attribute syn_useioff of FLASH_CIN          : signal is true;
    attribute syn_useioff of FLASH_DOUT         : signal is true;
    attribute syn_useioff of FPGA1_COMM         : signal is true;
    attribute syn_useioff of FPGA2_COMM         : signal is true;
    attribute syn_useioff of FPGA3_COMM         : signal is true;
    attribute syn_useioff of FPGA4_COMM         : signal is true;


end entity;

architecture trb3_central_arch of trb3_central is
  attribute syn_keep : boolean;
  attribute syn_preserve : boolean;
  
  component pll_in200_out100 is
port (
  CLK: in std_logic;
  CLKOP: out std_logic;
  CLKOK: out std_logic;
  LOCK: out std_logic
  );
end component;


component serdes is
   GENERIC (USER_CONFIG_FILE    :  String := "serdes.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (7 downto 0);
    tx_k_ch0    :   in std_logic;
    xmit_ch0    :   in std_logic;
    tx_disp_correct_ch0    :   in std_logic;
    rxdata_ch0   :   out std_logic_vector (7 downto 0);
    rx_k_ch0   :   out std_logic;
    rx_disp_err_ch0   :   out std_logic;
    rx_cv_err_ch0   :   out std_logic;
    rx_serdes_rst_ch0_c    :   in std_logic;
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pcs_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pcs_rst_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
-- CH1 --
    hdinp_ch1, hdinn_ch1    :   in std_logic;
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    rxiclk_ch1    :   in std_logic;
    txiclk_ch1    :   in std_logic;
    rx_full_clk_ch1   :   out std_logic;
    rx_half_clk_ch1   :   out std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    fpga_rxrefclk_ch1    :   in std_logic;
    txdata_ch1    :   in std_logic_vector (7 downto 0);
    tx_k_ch1    :   in std_logic;
    xmit_ch1    :   in std_logic;
    tx_disp_correct_ch1    :   in std_logic;
    rxdata_ch1   :   out std_logic_vector (7 downto 0);
    rx_k_ch1   :   out std_logic;
    rx_disp_err_ch1   :   out std_logic;
    rx_cv_err_ch1   :   out std_logic;
    rx_serdes_rst_ch1_c    :   in std_logic;
    sb_felb_ch1_c    :   in std_logic;
    sb_felb_rst_ch1_c    :   in std_logic;
    tx_pcs_rst_ch1_c    :   in std_logic;
    tx_pwrup_ch1_c    :   in std_logic;
    rx_pcs_rst_ch1_c    :   in std_logic;
    rx_pwrup_ch1_c    :   in std_logic;
    rx_los_low_ch1_s   :   out std_logic;
    lsm_status_ch1_s   :   out std_logic;
    rx_cdr_lol_ch1_s   :   out std_logic;
-- CH2 --
-- CH3 --
---- Miscillaneous ports
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    tx_sync_qd_c    :   in std_logic;
    rst_qd_c    :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;

component sgmii33 port (
	rst_n                  : in std_logic;
	signal_detect          : in std_logic;
	gbe_mode               : in std_logic;
	sgmii_mode             : in std_logic;
	--force_isolate          : in std_logic;
	--force_loopback         : in std_logic;
	--force_unidir           : in std_logic;
	operational_rate       : in std_logic_vector(1 downto 0);
	debug_link_timer_short : in std_logic;
	rx_compensation_err    : out std_logic;
	--ctc_drop_flag          : out std_logic;
	--ctc_add_flag           : out std_logic;
	--an_link_ok             : out std_logic;
	tx_clk_125             : in std_logic;                    
        tx_clock_enable_source : out std_logic;
        tx_clock_enable_sink   : in std_logic;          
	tx_d                   : in std_logic_vector(7 downto 0); 
	tx_en                  : in std_logic;       
	tx_er                  : in std_logic;       
	rx_clk_125             : in std_logic; 
        rx_clock_enable_source : out std_logic;
        rx_clock_enable_sink   : in std_logic;          
	rx_d                   : out std_logic_vector(7 downto 0);       
	rx_dv                  : out std_logic;  
	rx_er                  : out std_logic; 
	col                    : out std_logic;  
	crs                    : out std_logic;  
	tx_data                : out std_logic_vector(7 downto 0);  
	tx_kcntl               : out std_logic; 
	tx_disparity_cntl      : out std_logic; 
	--xmit_autoneg           : out std_logic; 
	serdes_recovered_clk   : in std_logic; 
	rx_data                : in std_logic_vector(7 downto 0);  
	rx_even                : in std_logic;  
	rx_kcntl               : in std_logic; 
	rx_disp_err            : in std_logic; 
	rx_cv_err              : in std_logic; 
	rx_err_decode_mode     : in std_logic; 
	mr_an_complete         : out std_logic; 
	mr_page_rx             : out std_logic; 
	mr_lp_adv_ability      : out std_logic_vector(15 downto 0); 
	mr_main_reset          : in std_logic; 
	mr_an_enable           : in std_logic; 
	mr_restart_an          : in std_logic; 
	mr_adv_ability         : in std_logic_vector(15 downto 0)
   );
end component;

component pll is
    port (
        CLK: in std_logic; 
        CLKOP: out std_logic; 
        LOCK: out std_logic);
end component;


component reset_controller_pcs port (
	rst_n                 : in std_logic;
	clk                   : in std_logic;
	tx_plol               : in std_logic; 
	rx_cdr_lol            : in std_logic; 
        quad_rst_out          : out std_logic; 
        tx_pcs_rst_out        : out std_logic; 
        rx_pcs_rst_out        : out std_logic
   );
end component;
component reset_controller_cdr port (
	rst_n                 : in std_logic;
	clk                   : in std_logic;
	cdr_lol               : in std_logic; 
        cdr_rst_out           : out std_logic
   );
end component;

component rate_resolution port (
	gbe_mode               : in std_logic;
	sgmii_mode             : in std_logic;
	an_enable              : in std_logic; 
	advertised_rate        : in std_logic_vector(1 downto 0);
	link_partner_rate      : in std_logic_vector(1 downto 0);
	non_an_rate            : in std_logic_vector(1 downto 0);
	operational_rate       : out std_logic_vector(1 downto 0)  
   );
end component;

component register_interface_hb port (
	rst_n                  : in std_logic;
	hclk                   : in std_logic;
	gbe_mode               : in std_logic;
	sgmii_mode             : in std_logic;
	hcs_n                  : in std_logic;
	hwrite_n               : in std_logic;
	haddr                  : in std_logic_vector(3 downto 0);
	hdatain                : in std_logic_vector(7 downto 0);
	hdataout               : out std_logic_vector(7 downto 0);   
	hready_n               : out std_logic;
	mr_an_complete         : in std_logic; 
	mr_page_rx             : in std_logic; 
	mr_lp_adv_ability      : in std_logic_vector(15 downto 0); 
	mr_main_reset          : out std_logic; 
	mr_an_enable           : out std_logic; 
	mr_restart_an          : out std_logic; 
	mr_adv_ability         : out std_logic_vector(15 downto 0) 
   );
end component;

  signal clk_100_i   : std_logic; --clock for main logic, 100 MHz, via Clock Manager and internal PLL
  signal clk_200_i   : std_logic; --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
  signal pll_lock    : std_logic; --Internal PLL locked. E.g. used to reset all internal logic.
  signal clear_i     : std_logic;
  signal reset_i     : std_logic;
  signal GSR_N       : std_logic;
  attribute syn_keep of GSR_N : signal is true;
  attribute syn_preserve of GSR_N : signal is true;
  
  --FPGA Test
  signal time_counter : unsigned(31 downto 0);
  
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
  --signal common_stat_regs        : std_logic_vector (std_COMSTATREG*32-1 downto 0);
  --signal common_ctrl_regs        : std_logic_vector (std_COMCTRLREG*32-1 downto 0);
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

signal ip_cfg_mem_clk				: std_logic;
signal ip_cfg_mem_addr				: std_logic_vector(7 downto 0);
signal ip_cfg_mem_data				: std_logic_vector(31 downto 0);

signal rx_full_clk, tx_k, rx_k, signal_detected, los : std_logic;
signal txd, rxd : std_logic_vector(7 downto 0);

signal tx_clk_en, rx_clk_en, an_link_ok, an_complete, sd_tx_kcntl, sd_tx_disp_cntl, sd_rx_kcntl, sd_rx_cv, sd_rx_disp_er, restart_an, restart_an_lock : std_logic;	
signal pcs_tx_en, pcs_tx_er, pcs_rx_dv, pcs_rx_er : std_logic;
signal sd_rxd, sd_txd, pcs_rxd, pcs_txd : std_logic_vector(7 downto 0);
signal counter : std_logic_vector(31 downto 0);
signal rst_n, tx_pll_lol, rx_pcs_rst, quad_rst, rx_cdr_lol, rx_serdes_rst, lane_rst, user_rst : std_logic;
signal tx_pcs_rst : std_logic;
signal clk_125_i, xmit, tx_full_clk : std_logic;
signal pcs_col, pcs_crs, mac_rx_dv : std_logic;
signal mac_rxd : std_logic_vector(7 downto 0);

signal mr_an_enable, mr_restart_an, mr_main_reset, mr_page_rx : std_logic;
signal mr_lp_adv_ability, mr_adv_ability : std_logic_vector(15 downto 0);
signal operational_rate : std_logic_vector(1 downto 0);

signal hdinp0a, hdinn0a, hdoutp0a, hdoutn0a, pcs_rx_dva, pcs_rx_era, tx_clk_ena, rx_clk_ena, rx_full_clka, tx_pll_lola, sd_tx_kcntla, sd_tx_disp_cntla, sd_rx_kcntla, sd_rx_disp_era, sd_rx_cva, losa, signal_detecteda, rx_cdr_lola, tx_pcs_rsta, rx_pcs_rsta, quad_rsta, rx_serdes_rsta : std_logic;
signal sd_txda, sd_rxda, pcs_rxda : std_logic_vector(7 downto 0);

signal powerup, compensation_err : std_logic;

  attribute syn_keep of compensation_err : signal is true;
  attribute syn_preserve of compensation_err : signal is true;

  attribute syn_keep of signal_detected : signal is true;
  attribute syn_preserve of signal_detected : signal is true;
  
  attribute syn_keep of los : signal is true;
  attribute syn_preserve of los : signal is true;

  attribute syn_keep of an_link_ok : signal is true;
  attribute syn_preserve of an_link_ok : signal is true;

  attribute syn_keep of an_complete : signal is true;
  attribute syn_preserve of an_complete : signal is true;

  attribute syn_keep of restart_an : signal is true;
  attribute syn_preserve of restart_an : signal is true;

signal hdinp0, hdinn0, hdoutp0, hdoutn0 : std_logic;

attribute NOPAD : boolean;
attribute NOPAD of hdinp0  : signal is true;
attribute NOPAD of hdinn0  : signal is true;
attribute NOPAD of hdoutp0 : signal is true;
attribute NOPAD of hdoutn0 : signal is true;
attribute NOPAD of hdinp0a  : signal is true;
attribute NOPAD of hdinn0a  : signal is true;
attribute NOPAD of hdoutp0a : signal is true;
attribute NOPAD of hdoutn0a : signal is true;


  
begin


hdinp0 <= SFP_RX_P(6);
hdinn0 <= SFP_RX_N(6);
SFP_TX_P(6) <= hdoutp0;
SFP_TX_N(6) <= hdoutn0;

hdinp0a <= SFP_RX_P(5);
hdinn0a <= SFP_RX_N(5);
SFP_TX_P(5) <= hdoutp0a;
SFP_TX_N(5) <= hdoutn0a;



SERDES_INST : serdes
 port map(
------------------
-- CH0 --
     hdinp_ch0 => hdinp0a,
 	hdinn_ch0 => hdinn0a,
    hdoutp_ch0 => hdoutp0a,
	hdoutn_ch0 => hdoutn0a,

    rxiclk_ch0 => rx_full_clka,
    txiclk_ch0 => clk_125_i,
    rx_full_clk_ch0 => rx_full_clka,
    rx_half_clk_ch0 => open,
    tx_full_clk_ch0 => open,
    tx_half_clk_ch0 => open,
    fpga_rxrefclk_ch0 => clk_125_i,

    txdata_ch0 => sd_txda,
    tx_k_ch0 => sd_tx_kcntla,
    xmit_ch0 => '0', --xmit,
    tx_disp_correct_ch0 => sd_tx_disp_cntla,

    rxdata_ch0 => sd_rxda,
    rx_k_ch0 => sd_rx_kcntla,
    rx_disp_err_ch0 => sd_rx_disp_era,
    rx_cv_err_ch0 => sd_rx_cva,

    sb_felb_ch0_c => '0',
    sb_felb_rst_ch0_c => '0',

    tx_pwrup_ch0_c => '1',
    rx_pwrup_ch0_c => '1',

    rx_los_low_ch0_s => losa,
    lsm_status_ch0_s => signal_detecteda,
    rx_cdr_lol_ch0_s => rx_cdr_lola,

        tx_pcs_rst_ch0_c      => tx_pcs_rsta,
        rx_pcs_rst_ch0_c      => rx_pcs_rsta,
        --rst_qd_c              => quad_rsta,
	rx_serdes_rst_ch0_c => rx_serdes_rsta,
-- CH1 --
       hdinp_ch1 => hdinp0,
	hdinn_ch1 => hdinn0,
    hdoutp_ch1 => hdoutp0,
	hdoutn_ch1 => hdoutn0,

    rxiclk_ch1 => rx_full_clk,
    txiclk_ch1 => clk_125_i,
    rx_full_clk_ch1 => rx_full_clk,
    rx_half_clk_ch1 => open,
    tx_full_clk_ch1 => tx_full_clk,
    tx_half_clk_ch1 => open,
    fpga_rxrefclk_ch1 => clk_125_i,

    txdata_ch1 => sd_txd,
    tx_k_ch1 => sd_tx_kcntl,
    xmit_ch1 => '0', --xmit,
    tx_disp_correct_ch1 => sd_tx_disp_cntl,

    rxdata_ch1 => sd_rxd,
    rx_k_ch1 => sd_rx_kcntl,
    rx_disp_err_ch1 => sd_rx_disp_er,
    rx_cv_err_ch1 => sd_rx_cv,

    sb_felb_ch1_c => '0',
    sb_felb_rst_ch1_c => '0',

    tx_pwrup_ch1_c => '1',
    rx_pwrup_ch1_c => '1',

    rx_los_low_ch1_s => los,
    lsm_status_ch1_s => signal_detected,
    rx_cdr_lol_ch1_s => rx_cdr_lol,

        tx_pcs_rst_ch1_c      => tx_pcs_rst,
        rx_pcs_rst_ch1_c      => rx_pcs_rst,
	rx_serdes_rst_ch1_c => rx_serdes_rst,
-- CH2 --
-- CH3 --
---- Miscillaneous ports
    fpga_txrefclk => clk_125_i,
    tx_serdes_rst_c   => '0',
    tx_pll_lol_qd_s  => tx_pll_lol,
    tx_sync_qd_c   => '0',
    rst_qd_c    => quad_rst,
    serdes_rst_qd_c  => '0');

SGMII2_INST : sgmii33 port map (
	rst_n                  => GSR_N,
	signal_detect          => signal_detecteda,
	gbe_mode               => '1',
	sgmii_mode             => '0',
	operational_rate       => operational_rate,
	debug_link_timer_short => '0',
	rx_compensation_err    => open,
	tx_clk_125             => clk_125_i,
        tx_clock_enable_source => tx_clk_ena,
        tx_clock_enable_sink   => tx_clk_ena,
	tx_d                   => pcs_rxda,
	tx_en                  => pcs_rx_dva, 
	tx_er                  => pcs_rx_era, 
	rx_clk_125             => clk_125_i,
        rx_clock_enable_source => rx_clk_ena,
        rx_clock_enable_sink   => rx_clk_ena,         
	rx_d                   => pcs_rxda,
	rx_dv                  => pcs_rx_dva,
	rx_er                  => pcs_rx_era, 
	col                    => open,
	crs                    => open,
	tx_data                => sd_txda,
	tx_kcntl               => sd_tx_kcntla,
	tx_disparity_cntl      => sd_tx_disp_cntla,
	serdes_recovered_clk   => rx_full_clka,
	rx_data                => sd_rxda,
	rx_even                => '0',
	rx_kcntl               => sd_rx_kcntla,
	rx_disp_err            => sd_rx_disp_era,
	rx_cv_err              => sd_rx_cva,
	rx_err_decode_mode     => '0',
	mr_an_complete         => open,
	mr_page_rx             => open,
	mr_lp_adv_ability      => open,
	mr_main_reset          => mr_main_reset, --reset_i,
	mr_an_enable           => '1', --'1',
	mr_restart_an          => mr_restart_an,
	mr_adv_ability         => mr_adv_ability --x"0020"
   );

SGMII_INST : sgmii33 port map (
	rst_n                  => GSR_N,
	signal_detect          => signal_detected,
	gbe_mode               => '1',
	sgmii_mode             => '0',
	operational_rate       => operational_rate,
	debug_link_timer_short => '0',
	rx_compensation_err    => compensation_err,
	tx_clk_125             => clk_125_i,
        tx_clock_enable_source => tx_clk_en,
        tx_clock_enable_sink   => tx_clk_en,
	tx_d                   => pcs_rxd, --pcs_txd,
	tx_en                  => pcs_rx_dv, --pcs_tx_en, 
	tx_er                  => pcs_rx_er, --pcs_tx_er, 
	rx_clk_125             => clk_125_i,
        rx_clock_enable_source => rx_clk_en,
        rx_clock_enable_sink   => rx_clk_en,         
	rx_d                   => pcs_rxd,
	rx_dv                  => pcs_rx_dv,
	rx_er                  => pcs_rx_er, 
	col                    => pcs_col,
	crs                    => pcs_crs,
	tx_data                => sd_txd,
	tx_kcntl               => sd_tx_kcntl,
	tx_disparity_cntl      => sd_tx_disp_cntl,
	serdes_recovered_clk   => rx_full_clk,
	rx_data                => sd_rxd,
	rx_even                => '0',
	rx_kcntl               => sd_rx_kcntl,
	rx_disp_err            => sd_rx_disp_er,
	rx_cv_err              => sd_rx_cv,
	rx_err_decode_mode     => '0',
	mr_an_complete         => an_complete,
	mr_page_rx             => mr_page_rx,
	mr_lp_adv_ability      => mr_lp_adv_ability,
	mr_main_reset          => mr_main_reset, --reset_i,
	mr_an_enable           => '1', --'1',
	mr_restart_an          => mr_restart_an,
	mr_adv_ability         => mr_adv_ability --x"0020"
   );


rst_n <= not reset_i;

u0_reset_controller_pcs : reset_controller_pcs port map(
	rst_n           => rst_n,
	clk             => clk_125_i,
	tx_plol         => tx_pll_lol,
	rx_cdr_lol      => rx_cdr_lol,
	quad_rst_out    => quad_rst,
	tx_pcs_rst_out  => tx_pcs_rst,
	rx_pcs_rst_out  => rx_pcs_rst
);

u0_reset_controller_cdr : reset_controller_cdr port map(
	rst_n           => rst_n,
	clk             => clk_125_i,
	cdr_lol         => rx_cdr_lol,
	cdr_rst_out     => rx_serdes_rst
);

u0_rate_resolution : rate_resolution port map(
	gbe_mode          => '1',
	sgmii_mode        => '0',
	an_enable         => '1',
	advertised_rate   => mr_adv_ability(11 downto 10),
	link_partner_rate => mr_lp_adv_ability(11 downto 10),
	non_an_rate       => "10", -- 1Gbps is rate when auto-negotiation disabled
                          
	operational_rate  => operational_rate
);

u0_ri : register_interface_hb port map(
	-- Control Signals
	rst_n      => rst_n,
	hclk       => clk_125_i,
	gbe_mode   => '1',
	sgmii_mode => '0',
                   
	-- Host Bus
	hcs_n      => '1',
	hwrite_n   => '1',
	haddr      => (others => '0'),
	hdatain    => (others => '0'),
                   
	hdataout   => open,
	hready_n   => open,

	-- Register Outputs
	mr_an_enable   => mr_an_enable,
	mr_restart_an  => mr_restart_an,
	mr_main_reset      => mr_main_reset,
	mr_adv_ability => mr_adv_ability,

	-- Register Inputs
	mr_an_complete     => an_complete,
	mr_page_rx         => mr_page_rx,
	mr_lp_adv_ability  => mr_lp_adv_ability
	);



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
    CLK_IN          => clk_125_i, --clk_200_i,       -- raw master clock, NOT from PLL/DLL!
    SYSCLK_IN       => clk_125_i, --clk_100_i,       -- PLL/DLL remastered clock
    PLL_LOCKED_IN   => pll_lock,        -- master PLL lock signal (async)
    RESET_IN        => '0',             -- general reset signal (SYSCLK)
    TRB_RESET_IN    => '0', --med_stat_op(4*16+13), -- TRBnet reset signal (SYSCLK)
    CLEAR_OUT       => clear_i,         -- async reset out, USE WITH CARE!
    RESET_OUT       => reset_i,         -- synchronous reset out (SYSCLK)
    DEBUG_OUT       => open
  );  

---------------------------------------------------------------------------
-- Clock Handling
---------------------------------------------------------------------------
-- THE_MAIN_PLL : pll_in200_out100
--   port map(
--     CLK    => CLK_GPLL_LEFT,
--     CLKOP  => clk_100_i,
--     CLKOK  => clk_200_i,
--     LOCK   => pll_lock
--     );

PLL_INST : pll
    port map(
        CLK => CLK_GPLL_RIGHT,
        CLKOP => clk_125_i,
        LOCK => pll_lock
);


SFP_TXDIS(4 downto 1) <= (others => '1');
SFP_TXDIS(8 downto 7) <= (others => '1');
SFP_TXDIS(6) <= '0';
SFP_TXDIS(5) <= '0';


    
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
  --LED_CLOCK_GREEN                <= '0';
  --LED_CLOCK_RED                  <= '1';
  --LED_GREEN                      <= not med_stat_op(9);
  --LED_YELLOW                     <= not med_stat_op(10);
  --LED_ORANGE                     <= not med_stat_op(11); 
  --LED_RED                        <= '1';
  --LED_TRIGGER_GREEN              <= not med_stat_op(4*16+9);
  --LED_TRIGGER_RED                <= not (med_stat_op(4*16+11) or med_stat_op(4*16+10));

  LED_GREEN                      <= compensation_err;
  LED_ORANGE                     <= not an_complete;
  LED_RED                        <= not restart_an;
  LED_YELLOW                     <= signal_detected;
---------------------------------------------------------------------------
-- Test Connector
---------------------------------------------------------------------------    

  TEST_LINE(7 downto 0)   <= med_data_in(7 downto 0);
  TEST_LINE(8)            <= med_dataready_in(0);
  TEST_LINE(9)            <= med_dataready_out(0);

  
  TEST_LINE(31 downto 10) <= (others => '0');

end architecture;