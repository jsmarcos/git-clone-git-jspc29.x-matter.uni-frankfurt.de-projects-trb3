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
   
   signal phy_debug_i : std_logic_vector (255 downto 0) := (others => '0');
   signal phy_debug_i_buf : std_logic_vector (255 downto 0);
   

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
   
   type SEND_FSM_T is (IDLE, WAITc, SEND);
   signal send_fsm_i : SEND_FSM_T;
   signal send_wait_counter_i : unsigned(16 downto 0);
   signal send_pack_counter_i : unsigned( 4 downto 0);
   
   signal send_num_pack_counter_i : unsigned(15 downto 0);
   
   signal dlm_counter_i : unsigned(31 downto 0);
   signal dlm_glob_counter_i : unsigned(31 downto 0);
   
begin
   clk_125_i <= CLK_GPLL_LEFT; 

   assert(INCLUDE_TRBNET = c_YES);
   
---------------------------------------------------------------------------
-- CBMNet and PHY
---------------------------------------------------------------------------   
   THE_CBM_PHY: cbmnet_phy_ecp3
   generic map (IS_SYNC_SLAVE => CBM_FEE_MODE)
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
      CLK_RX_FULL_OUT    => open,
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

   
   SFP_RATESEL   <= (others => '1');
   
   --TEST_LINE(1 downto 0) <= cbm_dlm2send_va & cbm_dlm_rec_va;

   process is
      variable counter_v : unsigned(20 downto 0); 
   begin
      wait until rising_edge(rclk_125_i);
      counter_v := counter_v + to_unsigned(1,1);
      cbm_dlm2send_va <= '0';
      if counter_v = 0 then
         cbm_dlm2send_va <= '1';
      end if;
   end process;
   
   
-- cbm_data2link <= "00" & x"dead";
   THE_CBM_ENDPOINT: lp_top 
   generic map (
      NUM_LANES => NUM_LANES,
      TX_SLAVE  => 1
   )
   port map (
   -- Clk & Reset
      clk => rclk_125_i,
      res_n => cbm_res_n,

   -- Phy
      data_from_link => cbm_data_from_link,
      data2link => cbm_data2link,
      link_activeovr => '0',
      link_readyovr => '0',
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
      ctrl_rec_stop => cbm_ctrl_rec_stop
      
   );
   cbm_res_n <= not rreset_i;
   
   
   PROC_DATA_SEND: process begin
      wait until rising_edge(rclk_125_i);
      
      send_wait_counter_i <= send_wait_counter_i + TO_UNSIGNED(1,1);
      
      if cbm_data2send_stop = "0" then
         send_pack_counter_i <= send_pack_counter_i + TO_UNSIGNED(1,1);
      end if;

      cbm_data2send <= (others => '0');
      cbm_data2send(send_pack_counter_i'HIGH downto 0)     <= STD_LOGIC_VECTOR(send_pack_counter_i);
      cbm_data2send(send_pack_counter_i'HIGH + 9 downto 9) <= STD_LOGIC_VECTOR(send_pack_counter_i);

      cbm_data2send_start <= "0";
      cbm_data2send_end <= "0";
      
      case(send_fsm_i) is
         when IDLE =>
            if cbm_link_active='1' and cbm_data2send_stop = "0" then
               send_fsm_i <= WAITc;
               send_wait_counter_i <= (others => '0');
               send_num_pack_counter_i <= send_num_pack_counter_i + TO_UNSIGNED(1, 1);
            end if;
            
         when WAITc =>
            if send_wait_counter_i(send_pack_counter_i'HIGH) = '1' then
               send_fsm_i <= SEND;
               cbm_data2send_start <= "1";
            end if;
            
         when SEND =>
            if send_wait_counter_i(send_pack_counter_i'HIGH) = '1' then
               cbm_data2send_end <= "1";
               send_fsm_i <= IDLE;
            end if;
      end case;
      
      if reset_i = '1' then
         send_fsm_i <= IDLE;
         send_num_pack_counter_i <= (others => '0');
      end if;
   end process;
   
   PROC_DLM_COUNTER: process is
      variable dlm_type_v : integer range 15 downto 0;
   begin
      wait until rising_edge(rclk_125_i);
      
      if reset_i = '1' then
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
      debug_ack <= '0';
      
      debug_ack <= debug_read_en or debug_write_en;
      case address is
         when 16#0# => debug_data_out <= x"0000" & phy_stat_op;
         when 16#1# => debug_data_out <= x"0000" & phy_ctrl_op;
         when 16#2# => debug_data_out <= phy_stat_debug(31 downto  0);
         when 16#3# => debug_data_out <= phy_stat_debug(63 downto 32);
         when 16#4# => debug_data_out <= phy_ctrl_debug(31 downto  0);
         when 16#5# => debug_data_out <= phy_ctrl_debug(63 downto 32);
         when 16#6# => debug_data_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(CBM_FEE_MODE, 32));
         
         when 16#8# => debug_data_out <= phy_debug_i_buf(31+32*0 downto 32*0);
         when 16#9# => debug_data_out <= phy_debug_i_buf(31+32*1 downto 32*1);
         when 16#a# => debug_data_out <= phy_debug_i_buf(31+32*2 downto 32*2);
         when 16#b# => debug_data_out <= phy_debug_i_buf(31+32*3 downto 32*3);         
         when 16#c# => debug_data_out <= phy_debug_i_buf(31+32*4 downto 32*4);
         when 16#d# => debug_data_out <= phy_debug_i_buf(31+32*5 downto 32*5);
         when 16#e# => debug_data_out <= phy_debug_i_buf(31+32*6 downto 32*6);
         when 16#f# => debug_data_out <= phy_debug_i_buf(31+32*7 downto 32*7);  
         
--         when 16#10# => debug_data_out <= link_tester_stat;
--        when 16#11# => debug_data_out <= link_tester_ctrl;
         
         when 16#12# => debug_data_out <= STD_LOGIC_VECTOR(dlm_counter_i);
         when 16#13# => debug_data_out <= STD_LOGIC_VECTOR(dlm_glob_counter_i);
         when 16#14# => 
            debug_data_out(19 downto 16) <= "00" & cbm_data2send_stop & cbm_link_active;
            debug_data_out(15 downto 0) <= STD_LOGIC_VECTOR(send_num_pack_counter_i);
         
         when others => debug_ack <= '0';
      end case;
   
      if debug_write_en = '1' then
         case (address) is
            when 16#1# => phy_ctrl_op <= debug_data_in(15 downto 0);
            when 16#4# => phy_ctrl_debug(31 downto  0) <= debug_data_in;
            when 16#5# => phy_ctrl_debug(63 downto 32) <= debug_data_in;
            
--            when 16#11# => link_tester_ctrl <= debug_data_in;   
            when others => debug_ack <= '0';
         end case;
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

---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 3,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", 2 => x"a000", others => x"0000"),
      PORT_ADDR_MASK => (0 => 1, 1 => 6, 2 => 6, others => 0)
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


------ DUMMY to check integrity of TEST_LINE connection
--    process is 
--       variable test_line_v : std_logic_vector(15 downto 0) := x"0001";
--    begin
--       wait until rising_edge(rclk_125_i);
--       test_line_v := test_line_v(14 downto 0) & test_line_v(15);
--       TEST_LINE <= test_line_v;
--    end process;
end architecture;