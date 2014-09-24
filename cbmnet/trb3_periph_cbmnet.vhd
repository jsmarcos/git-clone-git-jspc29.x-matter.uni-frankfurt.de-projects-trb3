library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;

use work.cbmnet_interface_pkg.all;
use work.cbmnet_phy_pkg.all;


entity trb3_periph_cbmnet is
   generic (
      CBM_FEE_MODE : integer := CBM_FEE_MODE_C; -- in FEE mode, logic will run on recovered clock and (for now) listen only to data received
                                     -- in Master mode, logic will run on internal clock and regularly send dlms
      INCLUDE_TRBNET : integer := INCLUDE_TRBNET_C
   );
   port(
      --Clocks
      CLK_GPLL_LEFT  : in std_logic;  --Clock Manager 1/(2468), 125 MHz
      CLK_GPLL_RIGHT : in std_logic;  --Clock Manager 2/(2468), 200 MHz  <-- MAIN CLOCK for FPGA
      CLK_PCLK_LEFT  : in std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!
      CLK_PCLK_RIGHT : in std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!

      --Trigger
      TRIGGER_LEFT  : in std_logic;       --left side trigger input from fan-out
      TRIGGER_RIGHT : in std_logic;       --right side trigger input from fan-out

      --Serdes
      CLK_SERDES_INT_LEFT  : in  std_logic;  --Clock Manager 1/(1357), off, 125 MHz possible
      CLK_SERDES_INT_RIGHT : in  std_logic;  --Clock Manager 2/(1357), 200 MHz, only in case of problems
      SERDES_INT_TX        : out std_logic_vector(3 downto 0);
      SERDES_INT_RX        : in  std_logic_vector(3 downto 0);
      SERDES_ADDON_TX      : out std_logic_vector(11 downto 0);
      SERDES_ADDON_RX      : in  std_logic_vector(11 downto 0);

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

      SFP_RATESEL: out std_logic_vector(6 downto 1); 
      SFP_TXFAULT: in  std_logic_vector(6 downto 1);

      --Flash ROM & Reboot
      FLASH_CLK  : out   std_logic;
      FLASH_CS   : out   std_logic;
      FLASH_DIN  : out   std_logic;
      FLASH_DOUT : in    std_logic;
      PROGRAMN   : out   std_logic;      --reboot FPGA

      --Misc
      TEMPSENS   : inout std_logic;       --Temperature Sensor
      CODE_LINE  : in    std_logic_vector(1 downto 0);
      LED_GREEN  : out   std_logic;
      LED_ORANGE : out   std_logic;
      LED_RED    : out   std_logic;
      LED_YELLOW : out   std_logic;
      SUPPL      : in    std_logic;       --terminated diff pair, PCLK, Pads

      --Test Connectors
      TEST_LINE : out std_logic_vector(15 downto 0); 
      --TEST_LVDS_LINE : out std_logic_vector(1 downto 0);

      -- PCS Core TODO: Suppose this is necessary only for simulation
      SD_RXD_N_IN     : in std_logic;
      SD_RXD_P_IN     : in std_logic;
      SD_TXD_N_OUT    : out std_logic;
      SD_TXD_P_OUT    : out std_logic
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
   attribute syn_useioff of LED_RX        : signal is false;
   attribute syn_useioff of LED_TX        : signal is false;

   --important signals _with_ IO-FF
   attribute syn_useioff of FLASH_CLK  : signal is true;
   attribute syn_useioff of FLASH_CS   : signal is true;
   attribute syn_useioff of FLASH_DIN  : signal is true;
   attribute syn_useioff of FLASH_DOUT : signal is true;
   attribute syn_useioff of FPGA5_COMM : signal is true;
   attribute syn_useioff of TEST_LINE  : signal is true;

   attribute nopad : string;
   attribute nopad of SD_RXD_N_IN, SD_RXD_P_IN, SD_TXD_N_OUT, SD_TXD_P_OUT : signal is "true";
   
   attribute syn_keep : boolean;
   attribute syn_keep of CLK_GPLL_LEFT, CLK_GPLL_RIGHT, CLK_PCLK_LEFT, CLK_PCLK_RIGHT, TRIGGER_LEFT, TRIGGER_RIGHT : signal is true;
   attribute syn_preserve : boolean;
   
end entity;

architecture trb3_periph_arch of trb3_periph_cbmnet is
--Constants
   constant REGIO_NUM_STAT_REGS : integer := 2;
   constant REGIO_NUM_CTRL_REGS : integer := 2;


   --Clock / Reset
   signal clk_125_i                : std_logic; -- clock reference for CBMNet serdes
   signal clk_100_i                : std_logic;  --clock for main logic, 100 MHz, via Clock Manager and internal PLL
   signal clk_200_i                : std_logic;  --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
   signal pll_lock                 : std_logic;  --Internal PLL locked. E.g. used to reset all internal logic.
   signal pll_lock1, pll_lock2     : std_logic;
   signal clear_i                  : std_logic;
   signal reset_i                  : std_logic;
   signal GSR_N                    : std_logic;

   attribute syn_keep of GSR_N     : signal is true;
   attribute syn_preserve of GSR_N : signal is true;


   signal rclk_125_i                : std_logic; -- recovered clock 
   signal rclk_250_i                : std_logic; -- recovered clock 
   
   signal rreset_i                  : std_logic; -- reset for recovered clock ~ 1us after clock becomes stable


   --Media Interface
   signal med_stat_op        : std_logic_vector (1*16-1 downto 0) := (others => '0');
   signal med_ctrl_op        : std_logic_vector (1*16-1 downto 0);
   signal med_stat_debug     : std_logic_vector (1*64-1 downto 0);
   signal med_ctrl_debug     : std_logic_vector (1*64-1 downto 0);
   signal med_data_out       : std_logic_vector (1*16-1 downto 0);
   signal med_packet_num_out : std_logic_vector (1*3-1 downto 0);
   signal med_dataready_out  : std_logic;
   signal med_read_out       : std_logic;
   signal med_data_in        : std_logic_vector (1*16-1 downto 0);
   signal med_packet_num_in  : std_logic_vector (1*3-1 downto 0);
   signal med_dataready_in   : std_logic;
   signal med_read_in        : std_logic;

   --LVL1 channel
   signal timing_trg_received_i : std_logic;
   signal trg_data_valid_i      : std_logic;
   signal trg_timing_valid_i    : std_logic;
   signal trg_notiming_valid_i  : std_logic;
   signal trg_invalid_i         : std_logic;
   signal trg_type_i            : std_logic_vector(3 downto 0);
   signal trg_number_i          : std_logic_vector(15 downto 0);
   signal trg_code_i            : std_logic_vector(7 downto 0);
   signal trg_information_i     : std_logic_vector(23 downto 0);
   signal trg_int_number_i      : std_logic_vector(15 downto 0);
   signal trg_multiple_trg_i    : std_logic;
   signal trg_timeout_detected_i: std_logic;
   signal trg_spurious_trg_i    : std_logic;
   signal trg_missing_tmg_trg_i : std_logic;
   signal trg_spike_detected_i  : std_logic;

   --Data channel
   signal fee_trg_release_i    : std_logic;
   signal fee_trg_statusbits_i : std_logic_vector(31 downto 0);
   signal fee_data_i           : std_logic_vector(31 downto 0);
   signal fee_data_write_i     : std_logic;
   signal fee_data_finished_i  : std_logic;
   signal fee_almost_full_i    : std_logic;

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

   signal debug_read_en   : std_logic;
   signal debug_write_en  : std_logic;
   signal debug_data_in   : std_logic_vector(31 downto 0);
   signal debug_addr      : std_logic_vector(5 downto 0);
   signal debug_data_out  : std_logic_vector(31 downto 0);
   signal debug_ack       : std_logic;

   signal sync_regio_read_en   : std_logic;
   signal sync_regio_write_en  : std_logic;
   signal sync_regio_status_data   : std_logic_vector(31 downto 0);
   signal sync_regio_addr      : std_logic_vector(3 downto 0);
   signal sync_regio_config_data  : std_logic_vector(31 downto 0);
   signal sync_regio_read_ack       : std_logic;
   signal sync_regio_write_ack       : std_logic;
   signal sync_regio_unknown       : std_logic;
   
   signal trb_trigger : std_logic;
   signal sync_dlm_sense : std_logic;
   signal sync_pulser : std_logic;
   
   
   signal spi_bram_addr : std_logic_vector(7 downto 0);
   signal spi_bram_wr_d : std_logic_vector(7 downto 0);
   signal spi_bram_rd_d : std_logic_vector(7 downto 0);
   signal spi_bram_we   : std_logic;

   --FPGA Test
   signal time_counter : unsigned(31 downto 0);

   -- CBMNet signals
   constant NUM_LANES : integer := 1;
   signal cbm_res_n             :  std_logic; -- Active low reset; can be changed by define
   signal cbm_link_active       :  std_logic; -- link is active and can send and receive data

   signal cbm_ctrl2send_stop    :  std_logic := '0'; -- send control interface
   signal cbm_ctrl2send_start   :  std_logic := '0';
   signal cbm_ctrl2send_end     :  std_logic := '0';
   signal cbm_ctrl2send         :  std_logic_vector(15 downto 0) := (others => '0');

   signal cbm_data2send_stop    :  std_logic_vector(NUM_LANES-1 downto 0) := (others => '0'); -- send data interface
   signal cbm_data2send_start   :  std_logic_vector(NUM_LANES-1 downto 0) := (others => '0');
   signal cbm_data2send_end     :  std_logic_vector(NUM_LANES-1 downto 0) := (others => '0');
   signal cbm_data2send         :  std_logic_vector((16*NUM_LANES)-1 downto 0) := (others => '0');

   signal cbm_data2send_start1   :  std_logic_vector(NUM_LANES-1 downto 0) := (others => '0');
   signal cbm_data2send_end1     :  std_logic_vector(NUM_LANES-1 downto 0) := (others => '0');
   signal cbm_data2send1         :  std_logic_vector((16*NUM_LANES)-1 downto 0) := (others => '0');

   signal cbm_data2send_start2   :  std_logic_vector(NUM_LANES-1 downto 0) := (others => '0');
   signal cbm_data2send_end2     :  std_logic_vector(NUM_LANES-1 downto 0) := (others => '0');
   signal cbm_data2send2         :  std_logic_vector((16*NUM_LANES)-1 downto 0) := (others => '0');

   
   signal cbm_dlm2send_va       :  std_logic := '0';                      -- send dlm interface
   signal cbm_dlm2send          :  std_logic_vector(3 downto 0) := (others => '0');

   signal cbm_dlm_rec_type      :  std_logic_vector(3 downto 0) := (others => '0');   -- receive dlm interface
   signal cbm_dlm_rec_va        :  std_logic := '0';

   signal cbm_data_rec          :  std_logic_vector((16*NUM_LANES)-1 downto 0);   -- receive data interface
   signal cbm_data_rec_start    :  std_logic_vector(NUM_LANES-1 downto 0);
   signal cbm_data_rec_end      :  std_logic_vector(NUM_LANES-1 downto 0);         
   signal cbm_data_rec_stop     :  std_logic_vector(NUM_LANES-1 downto 0) := (others =>'0');  

   signal cbm_ctrl_rec          :  std_logic_vector(15 downto 0);       -- receive control interface
   signal cbm_ctrl_rec_start    :  std_logic;
   signal cbm_ctrl_rec_end      :  std_logic;                 
   signal cbm_ctrl_rec_stop     :  std_logic;

   signal cbm_data_from_link    :  std_logic_vector((18*NUM_LANES)-1 downto 0);   -- interface from the PHY
   signal cbm_data2link         :  std_logic_vector((18*NUM_LANES)-1 downto 0);   -- interface to the PHY

   signal cbm_link_activeovr    :  std_logic := '0'; -- Overrides; set 0 by default
   signal cbm_link_readyovr     :  std_logic := '0';

   signal cbm_SERDES_ready      :  std_logic;    -- signalize when PHY ready

   signal phy_stat_op,    phy_ctrl_op    : std_logic_vector(15 downto 0) := (others => '0');
   signal phy_stat_debug, phy_ctrl_debug : std_logic_vector(63 downto 0) := (others => '0');
   
   signal phy_debug_i : std_logic_vector (511 downto 0) := (others => '0');
   signal phy_debug_i_buf : std_logic_vector (511 downto 0);
   
   signal tp_mux_i : std_logic;

-- Link Tester
   signal link_tester_ctrl_en   :std_logic;
   signal link_tester_dlm_en    :std_logic;
   signal link_tester_data_en   :std_logic;
                                           
   signal link_tester_data_stop :std_logic;
   signal link_tester_ctrl_stop :std_logic;
                                           
   signal link_tester_data_valid:std_logic;
   signal link_tester_ctrl_valid:std_logic;
   signal link_tester_dlm_valid :std_logic;


   signal link_tester_ctrl : std_logic_vector(31 downto 0) := (others => '0');
   signal link_tester_stat : std_logic_vector(31 downto 0) := (others => '0');
   
   signal dummy : std_logic;
   
   type SEND_FSM_T is (START, SEND_HEADER, SEND_PACK_NUM, SEND_LENGTH, SEND_DATA, SEND_FOOTER, AFTER_SEND_WAIT);
   signal send_fsm_i : SEND_FSM_T;
--   signal send_length_i : unsigned(4 downto 0);
   signal send_num_pack_counter_i : unsigned(15 downto 0); 
   signal send_enabled_i : std_logic := '0';
   
   signal send_wait_counter_i1 : unsigned(31 downto 0);
   signal send_wait_counter_i2 : unsigned(31 downto 0);
   signal send_wait_threshold_i : unsigned(31 downto 0);
   signal send_burst_threshold_i : unsigned(31 downto 0);
   signal send_burst_counter_i : unsigned(31 downto 0);   
   
   signal dlm_counter_i : unsigned(31 downto 0);
   signal dlm_glob_counter_i : unsigned(31 downto 0);
   
   
   -- diagnostics Lane0
   signal cbm_crc_error_cntr_flag_0     : std_logic;
   signal cbm_retrans_cntr_flag_0       : std_logic;
   signal cbm_retrans_error_cntr_flag_0 : std_logic;
   signal cbm_crc_error_cntr_0          : std_logic_vector(15 downto 0);
   signal cbm_retrans_cntr_0            : std_logic_vector(15 downto 0);
   signal cbm_retrans_error_cntr_0      : std_logic_vector(15 downto 0);
   signal cbm_crc_error_cntr_clr_0      : std_logic;
   signal cbm_retrans_cntr_clr_0        : std_logic;
   signal cbm_retrans_error_cntr_clr_0  : std_logic;

   -- diagnostics Lane1
   signal cbm_crc_error_cntr_flag_1     : std_logic;
   signal cbm_retrans_cntr_flag_1       : std_logic;
   signal cbm_retrans_error_cntr_flag_1 : std_logic;
   signal cbm_crc_error_cntr_1          : std_logic_vector(15 downto 0);
   signal cbm_retrans_cntr_1            : std_logic_vector(15 downto 0);
   signal cbm_retrans_error_cntr_1      : std_logic_vector(15 downto 0);
   signal cbm_crc_error_cntr_clr_1      : std_logic;   
   signal cbm_retrans_cntr_clr_1        : std_logic;    
   signal cbm_retrans_error_cntr_clr_1  : std_logic; 

   -- diagnostics Lane2
   signal cbm_crc_error_cntr_flag_2     : std_logic;
   signal cbm_retrans_cntr_flag_2       : std_logic;
   signal cbm_retrans_error_cntr_flag_2 : std_logic;
   signal cbm_crc_error_cntr_2          : std_logic_vector(15 downto 0);
   signal cbm_retrans_cntr_2            : std_logic_vector(15 downto 0);
   signal cbm_retrans_error_cntr_2      : std_logic_vector(15 downto 0);
   signal cbm_crc_error_cntr_clr_2      : std_logic;   
   signal cbm_retrans_cntr_clr_2        : std_logic;    
   signal cbm_retrans_error_cntr_clr_2  : std_logic; 

   -- diagnostics Lane3
   signal cbm_crc_error_cntr_flag_3     : std_logic;
   signal cbm_retrans_cntr_flag_3       : std_logic;
   signal cbm_retrans_error_cntr_flag_3 : std_logic;
   signal cbm_crc_error_cntr_3          : std_logic_vector(15 downto 0);
   signal cbm_retrans_cntr_3            : std_logic_vector(15 downto 0);
   signal cbm_retrans_error_cntr_3      : std_logic_vector(15 downto 0);
   signal cbm_crc_error_cntr_clr_3      : std_logic;   
   signal cbm_retrans_cntr_clr_3        : std_logic;    
   signal cbm_retrans_error_cntr_clr_3  : std_logic;
   
   signal cbm_debug_overrides_i : std_logic_vector(1 downto 0) := "00";
   
   signal etm_trigger_i : std_logic;
   
   
  signal hub_cts_number                   : std_logic_vector(15 downto 0);
  signal hub_cts_code                     : std_logic_vector(7 downto 0);
  signal hub_cts_information              : std_logic_vector(7 downto 0);
  signal hub_cts_start_readout            : std_logic;
  signal hub_cts_readout_type             : std_logic_vector(3 downto 0);
  signal hub_cts_readout_finished         : std_logic;
  signal hub_cts_status_bits              : std_logic_vector(31 downto 0);
  signal hub_fee_data                     : std_logic_vector(15 downto 0);
  signal hub_fee_dataready                : std_logic;
  signal hub_fee_read                     : std_logic;
  signal hub_fee_status_bits              : std_logic_vector(31 downto 0);
  signal hub_fee_busy                     : std_logic;

  signal gbe_cts_number                   : std_logic_vector(15 downto 0);
  signal gbe_cts_code                     : std_logic_vector(7 downto 0);
  signal gbe_cts_information              : std_logic_vector(7 downto 0);
  signal gbe_cts_start_readout            : std_logic;
  signal gbe_cts_readout_type             : std_logic_vector(3 downto 0);
  signal gbe_cts_readout_finished         : std_logic;
  signal gbe_cts_status_bits              : std_logic_vector(31 downto 0);
  signal gbe_fee_data                     : std_logic_vector(15 downto 0);
  signal gbe_fee_dataready                : std_logic;
  signal gbe_fee_read                     : std_logic;
  signal gbe_fee_status_bits              : std_logic_vector(31 downto 0);
  signal gbe_fee_busy                     : std_logic;  

  
  signal cbm_rdo_regio_addr_i         : std_logic_vector(15 downto 0);
  signal cbm_rdo_regio_data_status_i  : std_logic_vector(31 downto 0);
  signal cbm_rdo_regio_read_enable_i  : std_logic;
  signal cbm_rdo_regio_write_enable_i : std_logic;
  signal cbm_rdo_regio_data_ctrl_i    : std_logic_vector(31 downto 0);
  signal cbm_rdo_regio_dataready_i    : std_logic;
  signal cbm_rdo_regio_write_ack_i    : std_logic;
  signal cbm_rdo_regio_unknown_addr_i : std_logic;  
  
  signal event_id : unsigned(31 downto 0);
  signal send_length_i1 : unsigned(15 downto 0);
  signal send_length_i2 : unsigned(15 downto 0);
  signal send_counter_i : unsigned(15 downto 0);
  
  
  signal send_length_min_i  : unsigned(15 downto 0);
  signal send_length_max_i  : unsigned(15 downto 0);
  signal send_length_step_i : unsigned(15 downto 0);
  signal send_length_cnt_i  : unsigned(15 downto 0);

  signal send_real_time_i : unsigned(31 downto 0);
  signal send_real_time_buf_i : unsigned(31 downto 0);
  
  signal send_real_time125_i : unsigned(31 downto 0);
  signal send_real_time125_xfer_i : unsigned(31 downto 0);
  signal send_real_time125_buf_i : unsigned(31 downto 0);

  signal event_gap_i : unsigned(31 downto 0);
  signal event_gap_cnt_i : unsigned(31 downto 0);
  
  
  type TRB_FSM_T is (IDLE, START_READOUT, START_READOUT_WAIT, FEE_BUSY, SEND_EINF_H, SEND_EINF_L, SEND_LENGTH, SEND_SOURCE, SEND_SOURCE_WAIT, 
  SEND_PAYLOAD_SSEHDR_H, SEND_PAYLOAD_SSEHDR_L,
  SEND_PAYLOAD_RT_H, SEND_PAYLOAD_RT_L, 
  SEND_PAYLOAD_H, SEND_PAYLOAD_L, 
  COMPL_WAIT, COMPL_NOT_BUSY_WAIT, EVT_WAIT);
  signal trb_fsm_i : TRB_FSM_T;
  
  signal rdo_send_length_min_i : unsigned(31 downto 0);
  signal rdo_send_length_max_i : unsigned(31 downto 0);
  signal rdo_send_length_inc_i : unsigned(31 downto 0);
  signal rdo_send_length_cur_i : unsigned(31 downto 0);
  
  type RDO_FSM_STATES_T is (UPDATE_LENGTH, WAIT_FOR_TRIGGER, SEND_RT_100, SEND_RT_125, SEND_TESTPATTERN, COMPLETE);
  signal rdo_fsm_i : RDO_FSM_STATES_T;
  
  signal do_reboot_i : std_logic;
  
  signal cbm_do_reboot_i : std_logic;
  signal trb_crs_cbm_do_reboot_i : std_logic;
   
begin
--    RDO_PROC: process is
--    begin
--       wait until rising_edge(clk_100_i);
--       
--       if reset_i='1' then
--          rdo_fsm_i <= WAIT_FOR_TRIGGER;
--          rdo_send_length_cur_i <= rdo_send_length_min_i;
--          
--       else
--          case(rdo_fsm_i) is
--             case UPDATE_LENGTH =>
--             case WAIT_FOR_TRIGGER =>
--             case SEND_RT_100 =>
--             case SEND_RT_125 => 
--             case SEND_TESTPATTERN =>
--             case COMPLETE =>
--          end case;
--       end if;
--    end process;


   clk_125_i <= CLK_GPLL_LEFT; 

   assert(INCLUDE_TRBNET = c_YES);
    
    
---------------------------------------------------------------------------
-- CBMNet and PHY
---------------------------------------------------------------------------   
   THE_CBM_PHY: cbmnet_phy_ecp3
   generic map (IS_SYNC_SLAVE => CBM_FEE_MODE, DETERMINISTIC_LATENCY => c_YES)
   port map (
      CLK                => clk_125_i,
      RESET              => reset_i,
      CLEAR              => '0',
         
      --Internal Connection TX
      PHY_TXDATA_IN      => cbm_data2link(15 downto  0),
      PHY_TXDATA_K_IN    => cbm_data2link(17 downto 16),
      
      --Internal Connection RX
      PHY_RXDATA_OUT     => cbm_data_from_link(15 downto 0),
      PHY_RXDATA_K_OUT   => cbm_data_from_link(17 downto 16),
      
      CLK_RX_HALF_OUT    => rclk_125_i,
      CLK_RX_FULL_OUT    => rclk_250_i,
      CLK_RX_RESET_OUT   => rreset_i,

      LINK_ACTIVE_OUT    => open,
      SERDES_ready       => cbm_SERDES_ready,
      
      --SFP Connection
      SD_RXD_P_IN        => SD_RXD_P_IN,
      SD_RXD_N_IN        => SD_RXD_N_IN,
      SD_TXD_P_OUT       => SD_TXD_P_OUT,
      SD_TXD_N_OUT       => SD_TXD_N_OUT,

      SD_PRSNT_N_IN      => SFP_MOD0(1),
      SD_LOS_IN          => SFP_LOS(1),
      SD_TXDIS_OUT       => SFP_TXDIS(1),
      
      LED_RX_OUT         => LED_RX(1),
      LED_TX_OUT         => LED_TX(1),
      LED_OK_OUT         => LED_LINKOK(1),
      
      -- Status and control port
      STAT_OP            => phy_stat_op,
      CTRL_OP            => phy_ctrl_op,
      DEBUG_OUT          => phy_debug_i
   );

   TEST_LINE(2 downto 0) <= sync_pulser & sync_dlm_sense & trb_trigger;

   
   THE_SYNC_MODULE: cbmnet_sync_module port map (
   -- TRB
      TRB_CLK_IN      => clk_100_i, --  in std_logic;  
      TRB_RESET_IN    => reset_i, --  in std_logic;
      TRB_TRIGGER_OUT => trb_trigger, --  out std_logic;

      --data output for read-out
      TRB_TRIGGER_IN        => timing_trg_received_i, --  in  std_logic;
      
      TRB_RDO_VALID_DATA_TRG_IN   => trg_data_valid_i,
      TRB_RDO_VALID_NO_TIMING_IN  => trg_notiming_valid_i,
      
      TRB_RDO_DATA_OUT      => fee_data_i, --  out std_logic_vector(31 downto 0);
      TRB_RDO_WRITE_OUT     => fee_data_write_i, --  out std_logic;
      TRB_RDO_STATUSBIT_OUT => fee_trg_statusbits_i, --  out std_logic_vector(31 downto 0);
      TRB_RDO_FINISHED_OUT  => fee_data_finished_i, --  out std_logic;

      -- reg io
      TRB_REGIO_ADDR_IN(15 downto 4)      => x"000",
      TRB_REGIO_ADDR_IN(3 downto 0)       => sync_regio_addr, --  in  std_logic_vector(15 downto 0);
      TRB_REGIO_DATA_IN                   => sync_regio_config_data, --  in  std_logic_vector(31 downto 0);
      TRB_REGIO_READ_ENABLE_IN            => sync_regio_read_en, --  in  std_logic;
      TRB_REGIO_WRITE_ENABLE_IN           => sync_regio_write_en, --  in  std_logic;
      TRB_REGIO_DATA_OUT                  => sync_regio_status_data, --  out std_logic_vector(31 downto 0);
      TRB_REGIO_DATAREADY_OUT             => sync_regio_read_ack, --  out std_logic;
      TRB_REGIO_WRITE_ACK_OUT             => sync_regio_write_ack, --  out std_logic;
      TRB_REGIO_UNKNOWN_ADDR_OUT          => sync_regio_unknown, --  out std_logic;
      
   -- CBMNET
      CBM_CLK_IN            => rclk_125_i, --  in std_logic;
      CBM_CLK_250_IN        => rclk_250_i,
      CBM_LINK_ACTIVE_IN    => cbm_link_active,
      CBM_RESET_IN          => rreset_i, --  in std_logic;
      CBM_PHY_BARREL_SHIFTER_POS_IN  => x"0", --  in std_logic_vector(3 downto 0);
      
      CBM_TIMING_TRIGGER_OUT => open,
      
      -- DLM port
      CBM_DLM_REC_IN        => cbm_dlm_rec_type, --  in std_logic_vector(3 downto 0);
      CBM_DLM_REC_VALID_IN  => cbm_dlm_rec_va, --  in std_logic;
      CBM_DLM_SENSE_OUT     => sync_dlm_sense, --  out std_logic;
      CBM_PULSER_OUT        => sync_pulser, --  out std_logic; -- connect to TDC
      
      -- Ctrl port
      CBM_CTRL_DATA_IN         => cbm_ctrl_rec, --  in std_logic_vector(15 downto 0);
      CBM_CTRL_DATA_START_IN   => cbm_ctrl_rec_start, --  in std_logic;
      CBM_CTRL_DATA_END_IN     => cbm_ctrl_rec_end, --  in std_logic;
      CBM_CTRL_DATA_STOP_OUT   => cbm_ctrl_rec_stop, --  out std_logic;
      
      DEBUG_OUT       => open --  out std_logic_vector(31 downto 0)    
   );
   
   fee_trg_release_i <= fee_data_finished_i;
   
   SFP_RATESEL   <= (others => '0');
   
   --TEST_LINE(1 downto 0) <= cbm_dlm2send_va & cbm_dlm_rec_va;

--    process is
--       variable counter_v : unsigned(20 downto 0); 
--    begin
--       wait until rising_edge(rclk_125_i);
--       counter_v := counter_v + to_unsigned(1,1);
--       cbm_dlm2send_va <= '0';
--       if counter_v = 0 then
--          cbm_dlm2send_va <= '1';
--       end if;
--    end process;
--    
   
-- cbm_data2link <= "00" & x"dead";
   THE_CBM_ENDPOINT: lp_top 
   generic map (
      NUM_LANES => 1,
      TX_SLAVE  => 0
   )
   port map (
   -- Clk & Reset
      clk => rclk_125_i,
      res_n => cbm_res_n,

   -- Phy
      data_from_link => cbm_data_from_link,
      data2link => cbm_data2link,
      link_activeovr => '0', --cbm_debug_overrides_i(0),
      link_readyovr => '0', --cbm_debug_overrides_i(1),
      SERDES_ready => cbm_SERDES_ready,

   -- CBMNet Interface
      link_active => cbm_link_active,
      ctrl2send_stop => cbm_ctrl2send_stop,
      ctrl2send_start => cbm_ctrl2send_start,
      ctrl2send_end => cbm_ctrl2send_end,
      ctrl2send => cbm_ctrl2send,
      
      data2send_stop => cbm_data2send_stop,
      data2send_start => cbm_data2send_start,
      data2send_end => cbm_data2send_end,
      data2send => cbm_data2send,
      
      dlm2send_va => cbm_dlm2send_va,
      dlm2send => cbm_dlm2send,
      
      dlm_rec_type => cbm_dlm_rec_type,
      dlm_rec_va => cbm_dlm_rec_va,

      data_rec => cbm_data_rec,
      data_rec_start => cbm_data_rec_start,
      data_rec_end => cbm_data_rec_end,
      data_rec_stop => cbm_data_rec_stop,
      
      ctrl_rec => cbm_ctrl_rec,
      ctrl_rec_start => cbm_ctrl_rec_start,
      ctrl_rec_end => cbm_ctrl_rec_end,
      ctrl_rec_stop => cbm_ctrl_rec_stop,
      
      -- diagnostics Lane0
      crc_error_cntr_flag_0     => cbm_crc_error_cntr_flag_0,      --  out std_logic;
      retrans_cntr_flag_0       => cbm_retrans_cntr_flag_0,        --  out std_logic;
      retrans_error_cntr_flag_0 => cbm_retrans_error_cntr_flag_0,  --  out std_logic;
      crc_error_cntr_0          => cbm_crc_error_cntr_0,           --  out std_logic_vector(15 downto 0);
      retrans_cntr_0            => cbm_retrans_cntr_0,             --  out std_logic_vector(15 downto 0);
      retrans_error_cntr_0      => cbm_retrans_error_cntr_0,       --  out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_0      => cbm_crc_error_cntr_clr_0,       --  in std_logic;
      retrans_cntr_clr_0        => cbm_retrans_cntr_clr_0,         --  in std_logic;
      retrans_error_cntr_clr_0  => cbm_retrans_error_cntr_clr_0,   --  in std_logic;

      -- diagnostics Lane1
      crc_error_cntr_flag_1     => open, -- out std_logic;
      retrans_cntr_flag_1       => open, -- out std_logic;
      retrans_error_cntr_flag_1 => open, -- out std_logic;
      crc_error_cntr_1          => open, -- out std_logic_vector(15 downto 0);
      retrans_cntr_1            => open, -- out std_logic_vector(15 downto 0);
      retrans_error_cntr_1      => open, -- out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_1      => '0', -- in std_logic;   
      retrans_cntr_clr_1        => '0', -- in std_logic;    
      retrans_error_cntr_clr_1  => '0', -- in std_logic; 

      -- diagnostics Lane2
      crc_error_cntr_flag_2     => open, -- out std_logic;
      retrans_cntr_flag_2       => open, -- out std_logic;
      retrans_error_cntr_flag_2 => open, -- out std_logic;
      crc_error_cntr_2          => open, -- out std_logic_vector(15 downto 0);
      retrans_cntr_2            => open, -- out std_logic_vector(15 downto 0);
      retrans_error_cntr_2      => open, -- out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_2      => '0', -- in std_logic;   
      retrans_cntr_clr_2        => '0', -- in std_logic;    
      retrans_error_cntr_clr_2  => '0', -- in std_logic; 

      -- diagnostics Lane3
      crc_error_cntr_flag_3     => open, -- out std_logic;
      retrans_cntr_flag_3       => open, -- out std_logic;
      retrans_error_cntr_flag_3 => open, -- out std_logic;
      crc_error_cntr_3          => open, -- out std_logic_vector(15 downto 0);
      retrans_cntr_3            => open, -- out std_logic_vector(15 downto 0);
      retrans_error_cntr_3      => open, -- out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_3      => '0', -- in std_logic;   
      retrans_cntr_clr_3        => '0', -- in std_logic;    
      retrans_error_cntr_clr_3  => '0'  -- in std_logic
      
      
   );
   cbm_res_n <= not rreset_i when rising_edge(rclk_125_i);

   cbm_crc_error_cntr_clr_0     <= reset_i;
   cbm_retrans_cntr_clr_0       <= reset_i;
   cbm_retrans_error_cntr_clr_0 <= reset_i;
   cbm_crc_error_cntr_clr_1     <= reset_i;
   cbm_retrans_cntr_clr_1       <= reset_i;
   cbm_retrans_error_cntr_clr_1 <= reset_i;
   cbm_crc_error_cntr_clr_2     <= reset_i;
   cbm_retrans_cntr_clr_2       <= reset_i;
   cbm_retrans_error_cntr_clr_2 <= reset_i;
   cbm_crc_error_cntr_clr_3     <= reset_i;
   cbm_retrans_cntr_clr_3       <= reset_i;
   cbm_retrans_error_cntr_clr_3 <= reset_i;
   
   THE_DLM_REFLECT: dlm_reflect port map (
      clk            => rclk_125_i,       -- in std_logic;
      res_n          => cbm_res_n,        -- in std_logic;
      dlm_rec_in     => cbm_dlm_rec_type, -- in std_logic_vector(3 downto 0);
      dlm_rec_va_in  => cbm_dlm_rec_va,   -- in std_logic;
      dlm_rec_out    => open,             -- out std_logic_vector(3 downto 0);
      dlm_rec_va_out => open,             -- out std_logic;
      dlm2send_va    => cbm_dlm2send_va,  -- out std_logic;
      dlm2send       => cbm_dlm2send      -- out std_logic_vector(3 downto 0)
   );
   
   THE_CBMNET_READOUT: cbmnet_readout
   port map (
      CLK_IN   => clk_100_i, -- in std_logic;
      RESET_IN => reset_i, -- in std_logic;

      -- connect to hub
      HUB_CTS_NUMBER_IN              => hub_cts_number, -- in  std_logic_vector (15 downto 0);
      HUB_CTS_CODE_IN                => hub_cts_code, -- in  std_logic_vector (7  downto 0);
      HUB_CTS_INFORMATION_IN         => hub_cts_information, -- in  std_logic_vector (7  downto 0);
      HUB_CTS_READOUT_TYPE_IN        => hub_cts_readout_type, -- in  std_logic_vector (3  downto 0);
      HUB_CTS_START_READOUT_IN       => hub_cts_start_readout, -- in  std_logic;
      HUB_CTS_READOUT_FINISHED_OUT   => hub_cts_readout_finished, -- out std_logic;  --no more data, end transfer, send TRM
      HUB_CTS_STATUS_BITS_OUT        => hub_cts_status_bits, -- out std_logic_vector (31 downto 0);
      HUB_FEE_DATA_IN                => hub_fee_data, -- in  std_logic_vector (15 downto 0);
      HUB_FEE_DATAREADY_IN           => hub_fee_dataready, -- in  std_logic;
      HUB_FEE_READ_OUT               => hub_fee_read, -- out std_logic;  --must be high when idle, otherwise you will never get a dataready
      HUB_FEE_STATUS_BITS_IN         => hub_fee_status_bits, -- in  std_logic_vector (31 downto 0);
      HUB_FEE_BUSY_IN                => hub_fee_busy, -- in  std_logic;   

      -- connect to GbE
      GBE_CTS_NUMBER_OUT             => gbe_cts_number, -- out std_logic_vector (15 downto 0);
      GBE_CTS_CODE_OUT               => gbe_cts_code, -- out std_logic_vector (7  downto 0);
      GBE_CTS_INFORMATION_OUT        => gbe_cts_information, -- out std_logic_vector (7  downto 0);
      GBE_CTS_READOUT_TYPE_OUT       => gbe_cts_readout_type, -- out std_logic_vector (3  downto 0);
      GBE_CTS_START_READOUT_OUT      => gbe_cts_start_readout, -- out std_logic;
      GBE_CTS_READOUT_FINISHED_IN    => gbe_cts_readout_finished, -- in  std_logic;      --no more data, end transfer, send TRM
      GBE_CTS_STATUS_BITS_IN         => gbe_cts_status_bits, -- in  std_logic_vector (31 downto 0);
      GBE_FEE_DATA_OUT               => gbe_fee_data, -- out std_logic_vector (15 downto 0);
      GBE_FEE_DATAREADY_OUT          => gbe_fee_dataready, -- out std_logic;
      GBE_FEE_READ_IN                => gbe_fee_read, -- in  std_logic;  --must be high when idle, otherwise you will never get a dataready
      GBE_FEE_STATUS_BITS_OUT        => gbe_fee_status_bits, -- out std_logic_vector (31 downto 0);
      GBE_FEE_BUSY_OUT               => gbe_fee_busy, -- out std_logic;

      -- reg io
      REGIO_ADDR_IN                  => cbm_rdo_regio_addr_i, -- in  std_logic_vector(15 downto 0);
      REGIO_DATA_IN                  => cbm_rdo_regio_data_ctrl_i, -- in  std_logic_vector(31 downto 0);
      REGIO_READ_ENABLE_IN           => cbm_rdo_regio_read_enable_i, -- in  std_logic;
      REGIO_WRITE_ENABLE_IN          => cbm_rdo_regio_write_enable_i, -- in  std_logic;
      REGIO_DATA_OUT                 => cbm_rdo_regio_data_status_i, -- out std_logic_vector(31 downto 0);
      REGIO_DATAREADY_OUT            => cbm_rdo_regio_dataready_i, -- out std_logic;
      REGIO_WRITE_ACK_OUT            => cbm_rdo_regio_write_ack_i, -- out std_logic;
      REGIO_UNKNOWN_ADDR_OUT         => cbm_rdo_regio_unknown_addr_i, -- out std_logic;

   -- CBMNet
      CBMNET_CLK_IN     => rclk_125_i, -- in std_logic;
      CBMNET_RESET_IN   => rreset_i, -- in std_logic;
      CBMNET_LINK_ACTIVE_IN => cbm_link_active, -- in std_logic;

      CBMNET_DATA2SEND_STOP_IN   => cbm_data2send_stop(0), -- in std_logic;
      CBMNET_DATA2SEND_START_OUT => cbm_data2send_start1(0), -- out std_logic;
      CBMNET_DATA2SEND_END_OUT   => cbm_data2send_end1(0), -- out std_logic;
      CBMNET_DATA2SEND_DATA_OUT  => cbm_data2send1 -- out std_logic_vector(15 downto 0)   
   );
   
   gbe_fee_read <= '1';
   gbe_cts_status_bits <= x"beafc0de";
   
   process is
      variable wait_cnt_v : integer range 0 to 15 := 0;
   begin
      wait until rising_edge(clk_100_i);
      
      hub_cts_start_readout <= '1';
      HUB_FEE_BUSY <= '1';
      HUB_FEE_DATAREADY <= '0';
      
      if reset_i='1' then
         trb_fsm_i <= IDLE;
      else
         case(trb_fsm_i) is
            when IDLE =>
               hub_cts_start_readout <= '0';
               HUB_FEE_BUSY <= '0';
               if send_enabled_i = '1' then
                  trb_fsm_i <= START_READOUT;
               end if;
               
               if send_length_cnt_i < send_length_min_i then
                  send_length_cnt_i <= send_length_min_i;
               else
                  send_length_cnt_i <= send_length_cnt_i + 1;
               end if;
               
            when START_READOUT => 
               if send_length_cnt_i < send_length_min_i or send_length_cnt_i > send_length_max_i then
                  send_length_cnt_i <= send_length_min_i;
               end if;

               trb_fsm_i <= START_READOUT_WAIT;
               wait_cnt_v := 10;
               HUB_FEE_BUSY <= '0';
               event_id <= event_id + 1;
               send_real_time_buf_i <= send_real_time_i;
               
            when START_READOUT_WAIT => 
               if wait_cnt_v = 0 then
                  trb_fsm_i <= FEE_BUSY;
                  wait_cnt_v := 5;
               else
                  wait_cnt_v := wait_cnt_v - 1;
               end if;
               
               HUB_FEE_BUSY <= '0';
            
            when FEE_BUSY =>
               if wait_cnt_v = 0 then
                  trb_fsm_i <= SEND_EINF_H;
               else
                  wait_cnt_v := wait_cnt_v - 1;
               end if;
               
               HUB_FEE_BUSY <= '1';
               
            when SEND_EINF_H =>
               HUB_FEE_DATA <= x"0e" & STD_LOGIC_VECTOR(event_id(23 downto 16));
               HUB_FEE_DATAREADY <= '1';
               trb_fsm_i <= SEND_EINF_L;
            when SEND_EINF_L =>
               HUB_FEE_DATA <= std_logic_vector(event_id(15 downto 0));
               HUB_FEE_DATAREADY <= '1';
               trb_fsm_i <= SEND_LENGTH;
               
            when SEND_LENGTH =>
               HUB_FEE_DATA <= std_logic_vector(send_length_cnt_i);
               send_counter_i <= send_length_cnt_i;
               HUB_FEE_DATAREADY <= '1';
               trb_fsm_i <= SEND_SOURCE;
            when SEND_SOURCE =>
               HUB_FEE_DATA <= x"affe";
               HUB_FEE_DATAREADY <= '1';
               trb_fsm_i <= SEND_SOURCE_WAIT;

            when SEND_SOURCE_WAIT =>
               trb_fsm_i <= SEND_PAYLOAD_SSEHDR_H;

            when SEND_PAYLOAD_SSEHDR_H =>
               HUB_FEE_DATA <= std_logic_vector(send_counter_i - 1);
               HUB_FEE_DATAREADY <= '1';
               trb_fsm_i <= SEND_PAYLOAD_SSEHDR_L;
               
            when SEND_PAYLOAD_SSEHDR_L =>
               HUB_FEE_DATA <= x"4444";
               HUB_FEE_DATAREADY <= '1';
               trb_fsm_i <= SEND_PAYLOAD_H;
               send_counter_i <= send_counter_i - 1;
               
               trb_fsm_i <= SEND_PAYLOAD_RT_H;
               
            when SEND_PAYLOAD_RT_H =>
               HUB_FEE_DATA <= std_logic_vector(send_real_time_buf_i(31 downto 16));
               HUB_FEE_DATAREADY <= '1';
               trb_fsm_i <= SEND_PAYLOAD_RT_L;
               
            when SEND_PAYLOAD_RT_L =>
               HUB_FEE_DATA <= std_logic_vector(send_real_time_buf_i(15 downto 0));
               HUB_FEE_DATAREADY <= '1';
               trb_fsm_i <= SEND_PAYLOAD_H;
               send_counter_i <= send_counter_i - 1;
               
               if send_counter_i = 1 then
                  trb_fsm_i <= COMPL_WAIT;
                  wait_cnt_v := 5;
               end if;
               
            when SEND_PAYLOAD_H =>
               HUB_FEE_DATA <= x"bb" & std_logic_vector(event_id(7 downto 0));
               HUB_FEE_DATAREADY <= '1';
               trb_fsm_i <= SEND_PAYLOAD_L;
               
            when SEND_PAYLOAD_L =>
               HUB_FEE_DATA <= x"c" & std_logic_vector(send_counter_i(11 downto 0));
               HUB_FEE_DATAREADY <= '1';
               trb_fsm_i <= SEND_PAYLOAD_H;
               send_counter_i <= send_counter_i - 1;
               
               if send_counter_i = 1 then
                  trb_fsm_i <= COMPL_WAIT;
                  wait_cnt_v := 5;
               end if;
               
            when COMPL_WAIT =>
               if wait_cnt_v = 0 then
                  wait_cnt_v := 5;
                  trb_fsm_i <= COMPL_NOT_BUSY_WAIT;
               else
                  wait_cnt_v := wait_cnt_v - 1;
               end if;
               
               HUB_FEE_BUSY <= '1';

            
            when COMPL_NOT_BUSY_WAIT => 
               hub_cts_start_readout <= '0';
               if wait_cnt_v = 0 then
                  trb_fsm_i <= EVT_WAIT;
                  wait_cnt_v := 5;
               else
                  wait_cnt_v := wait_cnt_v - 1;
               end if;
               
               HUB_FEE_BUSY <= '0';
               event_gap_cnt_i <= (others => '0');
               
               
            when EVT_WAIT =>
               hub_cts_start_readout <= '0';
               HUB_FEE_BUSY <= '0';
               
               event_gap_cnt_i <= event_gap_cnt_i + 1;
               
               if event_gap_cnt_i >= UNSIGNED(event_gap_i) then
                  trb_fsm_i <= IDLE;
               end if;
               
         end case;
      end if;
   end process;
   
   proc_real_time: process is
   begin
      wait until rising_edge(clk_100_i);
      
      if reset_i='1' then
         send_real_time_i <= (others => '0');
      else
         send_real_time_i <= send_real_time_i + 1;
      end if;
   end process;
  
   proc_real_time125: process is
   begin
      wait until rising_edge(rclk_125_i);
      
      if rreset_i='1' then
         send_real_time125_i <= (others => '0');
      else
         send_real_time125_i <= send_real_time125_i +1;
      end if;
   end process;
   send_real_time125_xfer_i <= send_real_time125_i when rising_edge(clk_100_i);
  
   cbm_data2send <= cbm_data2send1; -- when tp_mux_i = '0' else cbm_data2send2;
   cbm_data2send_start <= cbm_data2send_start1; -- when tp_mux_i = '0' else cbm_data2send_start2;
   cbm_data2send_end <= cbm_data2send_end1; -- when tp_mux_i = '0' else cbm_data2send_end2;   
   
   PROC_DLM_COUNTER: process is
      variable dlm_type_v : integer range 15 downto 0;
   begin
      wait until rising_edge(rclk_125_i);
      
      if rreset_i = '1' then
         dlm_counter_i <= (others => '0');
		 dlm_glob_counter_i <= (others => '0');
      elsif cbm_dlm_rec_va = '1' then
	     dlm_glob_counter_i <= dlm_glob_counter_i + TO_UNSIGNED(1,1);
	  
         dlm_type_v := to_integer(unsigned(cbm_dlm_rec_type));
         for i in 0 to 15 loop
            if dlm_type_v = i then
               dlm_counter_i(1+i*2 downto i*2) <= dlm_counter_i(1+i*2 downto i*2) + TO_UNSIGNED(1,1);
            end if;
         end loop;
      end if;
   end process;
      
   phy_debug_i_buf <= phy_debug_i when rising_edge(clk_100_i);


   PROC_REGIO_DEBUG: process is 
      variable address : integer range 0 to 255;
   begin
      wait until rising_edge(clk_100_i);
      address := to_integer(unsigned(debug_addr));
      
      debug_data_out <= x"00000000";
      
      debug_ack <= debug_read_en or debug_write_en;
      case address is
         when 16#0# => debug_data_out <= x"0000" & phy_stat_op;
         when 16#1# => debug_data_out <= x"0000" & phy_ctrl_op;
         when 16#2# => debug_data_out <= phy_stat_debug(31 downto  0);
         when 16#3# => debug_data_out <= phy_stat_debug(63 downto 32);
         when 16#4# => debug_data_out <= phy_ctrl_debug(31 downto  0);
         when 16#5# => debug_data_out <= phy_ctrl_debug(63 downto 32);
         when 16#6# => debug_data_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(CBM_FEE_MODE, 32));
         
         when 16#0f# => debug_data_out(15 downto 0) <= send_length_i1;
         when 16#10# => debug_data_out <= event_gap_i;
         when 16#11# => debug_data_out <= event_id;
         
         when 16#12# => debug_data_out <= STD_LOGIC_VECTOR(dlm_counter_i);
         when 16#13# => debug_data_out <= STD_LOGIC_VECTOR(dlm_glob_counter_i);
         when 16#14# =>
			debug_data_out(21 downto 20) <= cbm_debug_overrides_i;
            debug_data_out(19 downto 16) <= tp_mux_i & send_enabled_i & cbm_data2send_stop & cbm_link_active;
            debug_data_out(15 downto 0) <= STD_LOGIC_VECTOR(send_num_pack_counter_i);
            
            
         when 16#15# => debug_data_out(15 downto 0) <= cbm_crc_error_cntr_0;
         when 16#16# => debug_data_out <= cbm_retrans_error_cntr_0 & cbm_retrans_cntr_0;
         when 16#17# => debug_data_out(15 downto 0) <= cbm_crc_error_cntr_1;
         when 16#18# => debug_data_out <= cbm_retrans_error_cntr_1 & cbm_retrans_cntr_1;
         when 16#19# => debug_data_out(15 downto 0) <= cbm_crc_error_cntr_2;
         when 16#1a# => debug_data_out <= cbm_retrans_error_cntr_2 & cbm_retrans_cntr_2;
         when 16#1b# => debug_data_out(15 downto 0) <= cbm_crc_error_cntr_3;
         when 16#1c# => debug_data_out <= cbm_retrans_error_cntr_3 & cbm_retrans_cntr_3;

         when 16#20# => debug_data_out <= phy_debug_i_buf(31+32*0 downto 32*0);
         when 16#21# => debug_data_out <= phy_debug_i_buf(31+32*1 downto 32*1);
         when 16#22# => debug_data_out <= phy_debug_i_buf(31+32*2 downto 32*2);
         when 16#23# => debug_data_out <= phy_debug_i_buf(31+32*3 downto 32*3);         
         when 16#24# => debug_data_out <= phy_debug_i_buf(31+32*4 downto 32*4);
         when 16#25# => debug_data_out <= phy_debug_i_buf(31+32*5 downto 32*5);
         when 16#26# => debug_data_out <= phy_debug_i_buf(31+32*6 downto 32*6);
         when 16#27# => debug_data_out <= phy_debug_i_buf(31+32*7 downto 32*7);  
         when 16#28# => debug_data_out <= phy_debug_i_buf(31+32*8 downto 32*8);
         when 16#29# => debug_data_out <= phy_debug_i_buf(31+32*9 downto 32*9);
         when 16#2a# => debug_data_out <= phy_debug_i_buf(31+32*10 downto 32*10);
         when 16#2b# => debug_data_out <= phy_debug_i_buf(31+32*11 downto 32*11);         
         when 16#2c# => debug_data_out <= phy_debug_i_buf(31+32*12 downto 32*12);
         when 16#2d# => debug_data_out <= phy_debug_i_buf(31+32*13 downto 32*13);
         when 16#2e# => debug_data_out <= phy_debug_i_buf(31+32*14 downto 32*14);
         when 16#2f# => debug_data_out <= phy_debug_i_buf(31+32*15 downto 32*15);  
         
         when 16#30# => debug_data_out <= x"0000" & STD_LOGIC_VECTOR( send_length_min_i );
         when 16#31# => debug_data_out <= x"0000" & STD_LOGIC_VECTOR(send_length_max_i );
         when 16#32# => debug_data_out <= x"0000" & STD_LOGIC_VECTOR(send_length_step_i );
         when 16#33# => debug_data_out <= send_real_time_i;
                        send_real_time125_buf_i <= send_real_time125_xfer_i;
         when 16#34# => debug_data_out <= send_real_time125_buf_i;
         
         when others => debug_ack <= '0';
      end case;
   
      if debug_write_en = '1' then
         case (address) is
            when 16#01# => phy_ctrl_op <= debug_data_in(15 downto 0);
            when 16#04# => phy_ctrl_debug(31 downto  0) <= debug_data_in;
            when 16#05# => phy_ctrl_debug(63 downto 32) <= debug_data_in;
            when 16#0f# => 
                  send_burst_threshold_i <= debug_data_in; 
                  send_length_i1 <= debug_data_in(15 downto 0);
            when 16#10# => event_gap_i <= debug_data_in;
            when 16#14# => 
				send_enabled_i <= debug_data_in(18);
				tp_mux_i <= debug_data_in(19);
				--cbm_debug_overrides_i <= debug_data_in(21 downto 20);
            
            when 16#30# => 
               if UNSIGNED(debug_data_in(15 downto 0)) > 1 then
                  send_length_min_i <= UNSIGNED(debug_data_in(15 downto 0));
               end if;
            when 16#31# =>
               if UNSIGNED(debug_data_in(15 downto 0)) < 1019 then
                  send_length_max_i <= UNSIGNED(debug_data_in(15 downto 0));
               end if;
               
            when 16#32# => 
               send_length_step_i <= UNSIGNED(debug_data_in(15 downto 0));

            when others => debug_ack <= '0';
         end case;
      end if;
      
      if reset_i='1' then
         send_length_step_i <= TO_UNSIGNED(  1, 16);
         send_length_min_i  <= TO_UNSIGNED(  2, 16);
         send_length_max_i  <= TO_UNSIGNED(200, 16);
      end if;
   end process;
   
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
      CLK_IN        => clk_200_i,        -- raw master clock, NOT from PLL/DLL!
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
      CLKOP => clk_100_i,
      CLKOK => clk_200_i,
      CLKOS => open,
      LOCK  => pll_lock1
      );
      
   pll_lock <= pll_lock1; -- and pll_lock2;

--   GEN_TRBNET: if INCLUDE_TRBNET = c_YES generate
---------------------------------------------------------------------------
-- The TrbNet media interface (to other FPGA)
---------------------------------------------------------------------------
  THE_MEDIA_UPLINK : trb_net16_med_ecp3_sfp
    generic map(
      SERDES_NUM  => 1,                 --number of serdes in quad
      EXT_CLOCK   => c_NO,              --use internal clock
      USE_200_MHZ => c_YES,             --run on 200 MHz clock
      USE_125_MHZ => c_NO,
      USE_CTC     => c_NO
      )
    port map(
      CLK                => clk_200_i,
      SYSCLK             => clk_100_i,
      RESET              => reset_i,
      CLEAR              => clear_i,
      CLK_EN             => '1',
      --Internal Connection
      MED_DATA_IN        => med_data_out,
      MED_PACKET_NUM_IN  => med_packet_num_out,
      MED_DATAREADY_IN   => med_dataready_out,
      MED_READ_OUT       => med_read_in,
      MED_DATA_OUT       => med_data_in,
      MED_PACKET_NUM_OUT => med_packet_num_in,
      MED_DATAREADY_OUT  => med_dataready_in,
      MED_READ_IN        => med_read_out,
      REFCLK2CORE_OUT    => open,
      --SFP Connection
      SD_RXD_P_IN        => SERDES_INT_RX(2),
      SD_RXD_N_IN        => SERDES_INT_RX(3),
      SD_TXD_P_OUT       => SERDES_INT_TX(2),
      SD_TXD_N_OUT       => SERDES_INT_TX(3),
      SD_REFCLK_P_IN     => open,
      SD_REFCLK_N_IN     => open,
      SD_PRSNT_N_IN      => FPGA5_COMM(0),
      SD_LOS_IN          => FPGA5_COMM(0),
      SD_TXDIS_OUT       => FPGA5_COMM(2),
      -- Status and control port
      STAT_OP            => med_stat_op,
      CTRL_OP            => med_ctrl_op,
      STAT_DEBUG         => med_stat_debug,
      CTRL_DEBUG         => (others => '0'),
      
      sci_ack => open,
      clk_rx_full_out => open,
      clk_rx_half_out => open
      );

---------------------------------------------------------------------------
-- Endpoint
---------------------------------------------------------------------------
  THE_ENDPOINT : trb_net16_endpoint_hades_full_handler
    generic map(
      REGIO_NUM_STAT_REGS       => REGIO_NUM_STAT_REGS,  --4,    --16 stat reg
      REGIO_NUM_CTRL_REGS       => REGIO_NUM_CTRL_REGS,  --3,    --8 cotrol reg
      ADDRESS_MASK              => x"FFFF",
      BROADCAST_BITMASK         => x"FF",
      BROADCAST_SPECIAL_ADDR    => x"45",
      REGIO_COMPILE_TIME        => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME, 32)),
      REGIO_HARDWARE_VERSION    => x"91000001",
      REGIO_INIT_ADDRESS        => x"f301",
      REGIO_USE_VAR_ENDPOINT_ID => c_YES,
      CLOCK_FREQUENCY           => 100,
      TIMING_TRIGGER_RAW        => c_YES,
      --Configure data handler
      DATA_INTERFACE_NUMBER     => 1,
      DATA_BUFFER_DEPTH         => 13,         --13
      DATA_BUFFER_WIDTH         => 32,
      DATA_BUFFER_FULL_THRESH   => 2**13-800,  --2**13-1024
      TRG_RELEASE_AFTER_DATA    => c_YES,
      HEADER_BUFFER_DEPTH       => 9,
      HEADER_BUFFER_FULL_THRESH => 2**9-16
      )
    port map(
      CLK                => clk_100_i,
      RESET              => reset_i,
      CLK_EN             => '1',
      MED_DATAREADY_OUT  => med_dataready_out,  -- open, --
      MED_DATA_OUT       => med_data_out,  -- open, --
      MED_PACKET_NUM_OUT => med_packet_num_out,  -- open, --
      MED_READ_IN        => med_read_in,
      MED_DATAREADY_IN   => med_dataready_in,
      MED_DATA_IN        => med_data_in,
      MED_PACKET_NUM_IN  => med_packet_num_in,
      MED_READ_OUT       => med_read_out,  -- open, --
      MED_STAT_OP_IN     => med_stat_op,
      MED_CTRL_OP_OUT    => med_ctrl_op,

      --Timing trigger in
      TRG_TIMING_TRG_RECEIVED_IN  => timing_trg_received_i,
      --LVL1 trigger to FEE
      LVL1_TRG_DATA_VALID_OUT     => trg_data_valid_i,
      LVL1_VALID_TIMING_TRG_OUT   => trg_timing_valid_i,
      LVL1_VALID_NOTIMING_TRG_OUT => trg_notiming_valid_i,
      LVL1_INVALID_TRG_OUT        => trg_invalid_i,

      LVL1_TRG_TYPE_OUT        => trg_type_i,
      LVL1_TRG_NUMBER_OUT      => trg_number_i,
      LVL1_TRG_CODE_OUT        => trg_code_i,
      LVL1_TRG_INFORMATION_OUT => trg_information_i,
      LVL1_INT_TRG_NUMBER_OUT  => trg_int_number_i,

      --Information about trigger handler errors
      TRG_MULTIPLE_TRG_OUT         => trg_multiple_trg_i,
      TRG_TIMEOUT_DETECTED_OUT     => trg_timeout_detected_i,
      TRG_SPURIOUS_TRG_OUT         => trg_spurious_trg_i,
      TRG_MISSING_TMG_TRG_OUT      => trg_missing_tmg_trg_i,
      TRG_SPIKE_DETECTED_OUT       => trg_spike_detected_i,
      
      --Response from FEE
      FEE_TRG_RELEASE_IN(0)       => fee_trg_release_i,
      FEE_TRG_STATUSBITS_IN       => fee_trg_statusbits_i,
      FEE_DATA_IN                 => fee_data_i,
      FEE_DATA_WRITE_IN(0)        => fee_data_write_i,
      FEE_DATA_FINISHED_IN(0)     => fee_data_finished_i,
      FEE_DATA_ALMOST_FULL_OUT(0) => fee_almost_full_i,

      -- Slow Control Data Port
      REGIO_COMMON_STAT_REG_IN           => common_stat_reg,  --0x00
      REGIO_COMMON_CTRL_REG_OUT          => common_ctrl_reg,  --0x20
      REGIO_COMMON_STAT_STROBE_OUT       => common_stat_reg_strobe,
      REGIO_COMMON_CTRL_STROBE_OUT       => common_ctrl_reg_strobe,
      REGIO_STAT_REG_IN                  => stat_reg,         --start 0x80
      REGIO_CTRL_REG_OUT                 => ctrl_reg,         --start 0xc0
      REGIO_STAT_STROBE_OUT              => stat_reg_strobe,
      REGIO_CTRL_STROBE_OUT              => ctrl_reg_strobe,
      REGIO_VAR_ENDPOINT_ID(1 downto 0)  => CODE_LINE,
      REGIO_VAR_ENDPOINT_ID(15 downto 2) => (others => '0'),

      BUS_ADDR_OUT         => regio_addr_out,
      BUS_READ_ENABLE_OUT  => regio_read_enable_out,
      BUS_WRITE_ENABLE_OUT => regio_write_enable_out,
      BUS_DATA_OUT         => regio_data_out,
      BUS_DATA_IN          => regio_data_in,
      BUS_DATAREADY_IN     => regio_dataready_in,
      BUS_NO_MORE_DATA_IN  => regio_no_more_data_in,
      BUS_WRITE_ACK_IN     => regio_write_ack_in,
      BUS_UNKNOWN_ADDR_IN  => regio_unknown_addr_in,
      BUS_TIMEOUT_OUT      => regio_timeout_out,
      ONEWIRE_INOUT        => TEMPSENS,
      ONEWIRE_MONITOR_OUT  => open,

      TIME_GLOBAL_OUT         => global_time,
      TIME_LOCAL_OUT          => local_time,
      TIME_SINCE_LAST_TRG_OUT => time_since_last_trg,
      TIME_TICKS_OUT          => timer_ticks,

      STAT_DEBUG_IPU              => open,
      STAT_DEBUG_1                => open,
      STAT_DEBUG_2                => open,
      STAT_DEBUG_DATA_HANDLER_OUT => open,
      STAT_DEBUG_IPU_HANDLER_OUT  => open,
      STAT_TRIGGER_OUT            => open,
      CTRL_MPLEX                  => (others => '0'),
      IOBUF_CTRL_GEN              => (others => '0'),
      STAT_ONEWIRE                => open,
      STAT_ADDR_DEBUG             => open,
      DEBUG_LVL1_HANDLER_OUT      => open
      );

      timing_trg_received_i <= TRIGGER_LEFT;
---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 5,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", 2 => x"a000", 3=>x"a800", 4=>x"a900", others => x"0000"),
      PORT_ADDR_MASK => (0 => 1,       1 => 6,       2 => 6,       3=>6,       4=>4, others => 0)
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

      --Bus Handler (SPI CTRL)
      BUS_READ_ENABLE_OUT(2)              => debug_read_en,
      BUS_WRITE_ENABLE_OUT(2)             => debug_write_en,
      BUS_DATA_OUT(2*32+31 downto 2*32)   => debug_data_in,
      BUS_ADDR_OUT(2*16+5 downto 2*16)    => debug_addr,
      BUS_ADDR_OUT(2*16+15 downto 2*16+6) => open,
      BUS_TIMEOUT_OUT(2)                  => open,
      BUS_DATA_IN(2*32+31 downto 2*32)    => debug_data_out,
      BUS_DATAREADY_IN(2)                 => debug_ack,
      BUS_WRITE_ACK_IN(2)                 => debug_ack,
      BUS_NO_MORE_DATA_IN(2)              => '0',
      BUS_UNKNOWN_ADDR_IN(2)              => '0',

    --CBMNet (read-out)
    BUS_READ_ENABLE_OUT(3)              => cbm_rdo_regio_read_enable_i,
    BUS_WRITE_ENABLE_OUT(3)             => cbm_rdo_regio_write_enable_i,
    BUS_DATA_OUT(3*32+31 downto 3*32)  => cbm_rdo_regio_data_ctrl_i,
    BUS_ADDR_OUT(3*16+15 downto 3*16)  => cbm_rdo_regio_addr_i,
    BUS_TIMEOUT_OUT(3)                  => open,
    BUS_DATA_IN(3*32+31 downto 3*32)   => cbm_rdo_regio_data_status_i,
    BUS_DATAREADY_IN(3)                 => cbm_rdo_regio_dataready_i,
    BUS_WRITE_ACK_IN(3)                 => cbm_rdo_regio_write_ack_i,
    BUS_NO_MORE_DATA_IN(3)              => '0',
    BUS_UNKNOWN_ADDR_IN(3)              => cbm_rdo_regio_unknown_addr_i,        

      --CBMNet (read-out)
      BUS_READ_ENABLE_OUT(4)              => sync_regio_read_en,
      BUS_WRITE_ENABLE_OUT(4)             => sync_regio_write_en,
      BUS_DATA_OUT(4*32+31 downto 4*32)   => sync_regio_config_data,
      BUS_ADDR_OUT(4*16+3 downto 4*16)    => sync_regio_addr,
      BUS_ADDR_OUT(4*16+15 downto 4*16+4) => open,
      BUS_TIMEOUT_OUT(3)                  => open,
      BUS_DATA_IN(4*32+31 downto 4*32)    => sync_regio_status_data,
      BUS_DATAREADY_IN(4)                 => sync_regio_read_ack,
      BUS_WRITE_ACK_IN(4)                 => sync_regio_write_ack,
      BUS_NO_MORE_DATA_IN(4)              => '0',
      BUS_UNKNOWN_ADDR_IN(4)              => sync_regio_unknown,        
    
    
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
-- LED
---------------------------------------------------------------------------
  LED_GREEN  <= not med_stat_op(9);
  LED_ORANGE <= not med_stat_op(10);
  LED_RED    <= not time_counter(26);
  LED_YELLOW <= not med_stat_op(11);

--   end generate;


end architecture;