--Media interface for Lattice ECP3 using PCS at 2.5GHz

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.med_sync_define.all;
use work.cbmnet_interface_pkg.all;
use work.cbmnet_phy_pkg.all;

entity cbmnet_phy_ecp3 is
   generic(
      IS_SYNC_SLAVE   : integer := c_NO;       --select slave mode
      INCL_DEBUG_AIDS : integer := c_YES
   );
   port(
      CLK                : in  std_logic; -- *internal* 125 MHz reference clock
      RESET              : in  std_logic; -- synchronous reset
      CLEAR              : in  std_logic; -- asynchronous reset

      --Internal Connection TX
      PHY_TXDATA_IN      : in  std_logic_vector(15 downto 0);
      PHY_TXDATA_K_IN    : in  std_logic_vector( 1 downto 0);

      --Internal Connection RX
      PHY_RXDATA_OUT     : out std_logic_vector(15 downto 0) := (others => '0');
      PHY_RXDATA_K_OUT   : out std_logic_vector( 1 downto 0) := (others => '0');

      CLK_RX_HALF_OUT    : out std_logic := '0';  -- recovered 125 MHz
      CLK_RX_FULL_OUT    : out std_logic := '0';  -- recovered 250 MHz
      CLK_RX_RESET_OUT   : out std_logic := '1';

      LINK_ACTIVE_OUT    : out std_logic; -- link is active and can send and receive data
      SERDES_ready       : out std_logic;

      --SFP Connection
      SD_RXD_P_IN        : in  std_logic := '0';
      SD_RXD_N_IN        : in  std_logic := '0';
      SD_TXD_P_OUT       : out std_logic := '0';
      SD_TXD_N_OUT       : out std_logic := '0';

      SD_PRSNT_N_IN      : in  std_logic;  -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
      SD_LOS_IN          : in  std_logic;  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
      SD_TXDIS_OUT       : out  std_logic := '0'; -- SFP disable

      LED_RX_OUT         : out std_logic;
      LED_TX_OUT         : out std_logic;
      LED_OK_OUT         : out std_logic;
      
      -- Status and control port
      STAT_OP            : out std_logic_vector (15 downto 0) := (others => '0');
      CTRL_OP            : in  std_logic_vector (15 downto 0) := (others => '0');
      DEBUG_OUT          : out std_logic_vector (127 downto 0) := (others => '0')
   );
end entity;

architecture cbmnet_phy_ecp3_arch of cbmnet_phy_ecp3 is
   -- Placer Directives
   attribute HGROUP : string;
   -- for whole architecture
   attribute HGROUP of cbmnet_phy_ecp3_arch : architecture  is "cbmnet_phy_group";
   attribute syn_sharing : string;
   attribute syn_sharing of cbmnet_phy_ecp3_arch : architecture is "off";

   constant WA_FIXATION : integer := c_YES;

-- Clocks and global resets   
   signal clk_125_local     : std_logic;  -- local 125 MHz reference clock driven by clock generators
   signal clk_125_i         : std_logic;  -- in FEE mode, driven by recovered clock, in Master mode, driven by local clock
   signal rclk_250_i        : std_logic;  -- recovered word clock
   signal rclk_125_i        : std_logic;  -- rclk_250_i divided by two. aligned s.t. the rising edge corresponds to the lower received word

   signal rst_i               : std_logic;  -- High-active reset driven by external logic
   signal rst_n_i             : std_logic;  -- Low-active version of rst_i

-- SERDES/PCS 
   -- status
   signal rx_los_low_i  : std_logic;
   signal rx_cdr_lol_i  : std_logic;
   signal tx_pll_lol_i  : std_logic;
   signal lsm_status_i : std_logic;

   signal rx_dec_error_i: std_logic;
   signal rx_error_delay : std_logic_vector(3 downto 0); -- shift register to detect a "stable error condition"
   
   -- resets
   signal rst_qd_i            : std_logic;
   signal serdes_rst_qd_i     : std_logic;
   
   signal tx_serdes_rst_i     : std_logic;
   signal tx_pcs_rst_i        : std_logic;
   
   signal rx_serdes_rst_i     : std_logic;
   signal rx_pcs_rst_i        : std_logic;

   -- data
   signal tx_data_i         : std_logic_vector(17 downto 0); -- data to send using SERDES
   signal rx_data_i         : std_logic_vector( 8 downto 0); -- received by SERDES

   -- status & control interface (and obtained info)
   signal sci_ch_i          : std_logic_vector(3 downto 0);
   signal sci_qd_i          : std_logic;
   signal sci_reg_i         : std_logic;
   signal sci_addr_i        : std_logic_vector(8 downto 0);
   signal sci_data_in_i     : std_logic_vector(7 downto 0);
   signal sci_data_out_i    : std_logic_vector(7 downto 0);
   signal sci_read_i        : std_logic;
   signal sci_write_i       : std_logic;
   signal sci_write_shift_i : std_logic_vector(2 downto 0);
   signal sci_read_shift_i  : std_logic_vector(2 downto 0);

   signal wa_position_i      : std_logic_vector(15 downto 0) := x"FFFF";
   signal barrel_shifter_misaligned_i: std_logic;
   
-- RESET FSM   
   signal rx_rst_fsm_state_i     : std_logic_vector(3 downto 0);
   signal tx_rst_fsm_state_i     : std_logic_vector(3 downto 0);
   signal tx_rst_fsm_ready_i     : std_logic;
   signal tx_rst_fsm_ready_buf_i : std_logic;
   
   signal byte_alignment_to_fsm_i : std_logic;
   signal word_alignment_to_fsm_i : std_logic;

   signal rx_rst_fsm_ready_i : std_logic;
   
-- SCI Logic to obtain the barrel shifter position
   type sci_ctrl is (IDLE, GET_WA, GET_WA_WAIT, GET_WA_WAIT2, GET_WA_FINISH);
   signal sci_state         : sci_ctrl;
   signal sci_timer         : unsigned( 7 downto 0) := (others => '0');
   signal start_timer       : unsigned(18 downto 0) := (others => '0');
   
-- GEAR
   signal gear_to_fsm_rst_i  : std_logic;
   signal gear_to_rm_rst_i   : std_logic; -- gear keeps CBMNet ready manager reset until gear locked successfully
   signal gear_to_rm_n_rst_i : std_logic; -- inverted version of above

   signal rx_data_buf_i     : std_logic_vector(17 downto 0); -- 16(+2) bit word generated by gear

-- CBMNet Ready Managers
   signal rm_rx_ready_i : std_logic;
   signal rm_rx_almost_ready_i : std_logic;
   signal rm_rx_status_for_tx_i : std_logic;
   signal rm_rx_see_ready0_i : std_logic;
   signal rm_rx_saw_ready1_i : std_logic;
   signal rm_rx_valid_char_i : std_logic;
   
   signal rm_tx_ready_i : std_logic;
   signal rm_tx_almost_ready_i : std_logic;
   
   signal rm_rx_to_gear_reset_i : std_logic;

-- LEDs
   signal led_ok_i                 : std_logic;
   signal led_tx_i, last_led_tx_i  : std_logic;
   signal led_rx_i, last_led_rx_i  : std_logic;
   signal led_timer_i              : unsigned(20 downto 0);

-- Stats
   signal stat_reconnect_counter_i : unsigned(15 downto 0); -- counts the number of RX-serdes resets since last external reset
   
begin
   clk_125_local <= CLK;
   CLK_RX_HALF_OUT <= rclk_125_i;
   CLK_RX_FULL_OUT <= rclk_250_i;

   SD_TXDIS_OUT <= '0';

   rst_i   <=     (CLEAR or CTRL_OP(0));
   rst_n_i <= not rst_i;

   gen_slave_clock : if IS_SYNC_SLAVE = c_YES generate
      clk_125_i        <= rclk_125_i;
   end generate;

   gen_master_clock : if IS_SYNC_SLAVE = c_NO generate
      clk_125_i        <= clk_125_local;
   end generate;

   -------------------------------------------------      
   -- Serdes
   -------------------------------------------------      
   THE_SERDES : cbmnet_sfp1
   port map(
   -- SERIAL DATA PORTS
      hdinp_ch0            => SD_RXD_P_IN,
      hdinn_ch0            => SD_RXD_N_IN,
      hdoutp_ch0           => SD_TXD_P_OUT,
      hdoutn_ch0           => SD_TXD_N_OUT,
      
   -- CLOCKS
      txiclk_ch0           => clk_125_i,
      
      rx_full_clk_ch0      => rclk_250_i,
      rx_half_clk_ch0      => open, -- recovered (and correctly aligned) 125 MHz clock is generated by gear
      
      tx_full_clk_ch0      => open,
      tx_half_clk_ch0      => open,
      
      fpga_rxrefclk_ch0    => clk_125_local,

   -- RESETS
      fpga_txrefclk        => clk_125_i,
      rst_qd_c             => rst_qd_i,
      serdes_rst_qd_c      => serdes_rst_qd_i, -- always 0
      tx_serdes_rst_c      => tx_serdes_rst_i, -- always 0
      rx_serdes_rst_ch0_c  => rx_serdes_rst_i,
      tx_pcs_rst_ch0_c     => tx_pcs_rst_i,
      rx_pcs_rst_ch0_c     => rx_pcs_rst_i,

      tx_pwrup_ch0_c       => '1',
      rx_pwrup_ch0_c       => '1',
   
   -- TX DATA PORT    
      txdata_ch0           => tx_data_i(15 downto 0),
      tx_k_ch0             => tx_data_i(17 downto 16),

      tx_force_disp_ch0    => "00",
      tx_disp_sel_ch0      => "00",
      tx_div2_mode_ch0_c   => '0',
      
   -- RX DATA PORT
      rxdata_ch0           => rx_data_i(7 downto 0),
      rx_k_ch0             => rx_data_i(8),

      rx_disp_err_ch0      => open,
      rx_cv_err_ch0        => rx_dec_error_i,
      rx_div2_mode_ch0_c   => '0',
      
   -- LOOPBACK
      sb_felb_ch0_c        => '0',
      sb_felb_rst_ch0_c    => '0',

   -- STATUS
      tx_pll_lol_qd_s      => tx_pll_lol_i,
      rx_los_low_ch0_s     => rx_los_low_i,
      rx_cdr_lol_ch0_s     => rx_cdr_lol_i,
      lsm_status_ch0_s     => lsm_status_i,
    
      SCI_WRDATA           => sci_data_in_i,
      SCI_RDDATA           => sci_data_out_i,
      SCI_ADDR             => sci_addr_i(5 downto 0),
      SCI_SEL_QUAD         => sci_qd_i,
      SCI_SEL_CH0          => sci_ch_i(0),
      SCI_RD               => sci_read_i,
      SCI_WRN              => sci_write_i
   );
   
   tx_serdes_rst_i <= '0'; --no function
   serdes_rst_qd_i <= '0'; --included in rst_qd_i
   
   -------------------------------------------------      
   -- Reset FSM & Link states
   -------------------------------------------------      
   THE_RX_FSM : cbmnet_phy_ecp3_rx_reset_fsm
   port map(
      RST_N               => rst_n_i,
      RX_REFCLK           => clk_125_local,
      TX_PLL_LOL_QD_S     => tx_pll_lol_i,
      RX_CDR_LOL_CH_S     => rx_cdr_lol_i,
      RX_LOS_LOW_CH_S     => rx_los_low_i,
      
      RM_RESET_IN         => CTRL_OP(4), --rx_reset_from_rm_i,
      PROPER_BYTE_ALIGN_IN=> byte_alignment_to_fsm_i,
      PROPER_WORD_ALIGN_IN=> word_alignment_to_fsm_i,
      
      RX_SERDES_RST_CH_C  => rx_serdes_rst_i,
      RX_PCS_RST_CH_C     => rx_pcs_rst_i,
      STATE_OUT           => rx_rst_fsm_state_i
   );
   byte_alignment_to_fsm_i <= (not barrel_shifter_misaligned_i);
   word_alignment_to_fsm_i <= not (gear_to_fsm_rst_i or AND_ALL(rx_error_delay));
   rx_error_delay <= rx_error_delay(rx_error_delay'high - 1 downto 0) & rx_dec_error_i when rising_edge(clk_125_local);
   
      
   THE_TX_FSM : tx_reset_fsm
   port map(
      RST_N           => rst_n_i,
      TX_REFCLK       => clk_125_local,
      TX_PLL_LOL_QD_S => tx_pll_lol_i,
      RST_QD_C        => rst_qd_i,
      TX_PCS_RST_CH_C => tx_pcs_rst_i,
      STATE_OUT       => tx_rst_fsm_state_i
   );
   --tx_data_i <= "01" & x"00" & CBMNET_READY_CHAR0;
   
   proc_rst_fsms_ready: process is begin
      wait until rising_edge(clk_125_local);
      rx_rst_fsm_ready_i <= '0';
      if rx_rst_fsm_state_i = x"6" then
         rx_rst_fsm_ready_i <= '1';
      end if;

      tx_rst_fsm_ready_i <= '0';
      if tx_rst_fsm_state_i = x"5" then
         tx_rst_fsm_ready_i <= '1';
      end if;
   end process;
   
   THE_GEAR: CBMNET_PHY_GEAR port map (
      -- SERDES PORT
         CLK_250_IN      => rclk_250_i,             -- in std_logic;
         PCS_READY_IN    => rx_rst_fsm_ready_i, -- in std_logic;
         SERDES_RESET_OUT=> gear_to_fsm_rst_i,    -- out std_logic;
         DATA_IN         => rx_data_i,               -- in  std_logic_vector( 8 downto 0);

      -- RM PORT
         RM_RESET_IN => rm_rx_to_gear_reset_i,      -- in std_logic;
         CLK_125_OUT => rclk_125_i,                -- out std_logic;
         RESET_OUT   => gear_to_rm_rst_i,           -- out std_logic;
         DATA_OUT    => rx_data_buf_i               -- out std_logic_vector(17 downto 0)
   );
   
   -------------------------------------------------      
   -- CBMNet Ready Modules
   -------------------------------------------------      
   THE_RX_READY: gtp_rx_ready_module 
   generic map (INCL_8B10B_DEC => c_No)
   port map (
      clk => clk_125_i,
      res_n => gear_to_rm_n_rst_i,
      ready_MGT2RM => '1',
      
      rxdata_in(17 downto 0) => rx_data_buf_i,
      rxdata_in(19 downto 18) => "00",
      tx_ready => rm_tx_ready_i,
      tx_almost_ready => rm_tx_almost_ready_i,

      ready_RM2LP => rm_rx_ready_i,

      rxdata_out  => PHY_RXDATA_OUT,
      charisk_out => PHY_RXDATA_K_OUT,
      
      almost_ready_OUT => rm_rx_almost_ready_i,
      see_ready0 => rm_rx_see_ready0_i,
      saw_ready1 => rm_rx_saw_ready1_i,
      valid_char => rm_rx_valid_char_i,
      
      reset_rx => rm_rx_to_gear_reset_i
   );
   gear_to_rm_n_rst_i <= not gear_to_rm_rst_i when rising_edge(clk_125_i);
   
   THE_TX_READY: gtp_tx_ready_module
   port map (
      clk => clk_125_i,                   -- :  in std_logic;
      res_n => tx_rst_fsm_ready_buf_i,               -- :  in std_logic;
      restart_link => CTRL_OP(14),        -- :  in std_logic;
      ready_MGT2RM => '1',     -- :  in std_logic;
      txdata_in => PHY_TXDATA_IN ,        -- :  in std_logic_vector((DATAWIDTH-1) downto 0);
      txcharisk_in => PHY_TXDATA_K_IN,    -- :  in std_logic_vector((WORDS-1) downto 0);

      see_ready0 => rm_rx_see_ready0_i,      -- :  in std_logic;
      saw_ready1 => rm_rx_saw_ready1_i,      -- :  in std_logic;
      valid_char => rm_rx_valid_char_i,      -- :  in std_logic;
      rx_rm_ready => rm_rx_status_for_tx_i,       -- :  in std_logic;

      ready_RM2LP => rm_tx_ready_i,          -- :  out std_logic;
      txdata_out => tx_data_i,            -- :  out std_logic_vector((WORDS*9)-1 downto 0);
      almost_ready => rm_tx_almost_ready_i,  -- :  out std_logic;
      gt11_reinit => open                 -- :  out std_logic   
   );
   rm_rx_status_for_tx_i <= rm_rx_almost_ready_i or rm_rx_ready_i;
   
   -- clock domain crossing from clk_125_local to clk_125_i
   PROC_SYNC_FSM_READY: process is begin
      wait until rising_edge(clk_125_i);
      
      if IS_SYNC_SLAVE = c_YES then
         tx_rst_fsm_ready_buf_i <= tx_rst_fsm_ready_i and not gear_to_rm_rst_i;
         
      else
         tx_rst_fsm_ready_buf_i <= tx_rst_fsm_ready_i;
         
      end if;
   end process;
      
   SERDES_ready <= rm_tx_ready_i and rm_rx_ready_i when rising_edge(clk_125_i);
   led_ok_i       <= SERDES_ready;
   
   
   -------------------------------------------------      
   -- SCI
   -------------------------------------------------      
   -- gives access to serdes config port from slow control and reads word alignment every ~ 40 us
   -- upon retrival the barrel shifter is checked and - if necessary - a serdes reset is issued
   PROC_SCI_CTRL: process 
      variable cnt : integer range 0 to 4 := 0;
      variable lsm_status_buf : std_logic;
   begin
      wait until rising_edge(clk_125_local);
      barrel_shifter_misaligned_i <= '0';
      
      case sci_state is
         when IDLE =>
            sci_ch_i        <= x"0";
            sci_qd_i        <= '0';
            sci_reg_i       <= '0';
            sci_read_i      <= '0';
            sci_write_i     <= '0';
            sci_timer       <= sci_timer + 1;
            if sci_timer(sci_timer'left) = '1' then
               sci_timer     <= (others => '0');
               sci_state     <= GET_WA;
            end if;      

      when GET_WA =>
            if cnt = 4 then
               cnt           := 0;
               sci_state     <= IDLE;
               
               if lsm_status_buf = '1' and wa_position_i(3 downto 0) /= x"0" then
                  barrel_shifter_misaligned_i <= '1';
               end if;
               
            else
               sci_state     <= GET_WA_WAIT;
               sci_addr_i    <= '0' & x"22";
               sci_ch_i      <= x"0";
               sci_ch_i(cnt) <= '1';
               sci_read_i    <= '1';
            end if;
            
         when GET_WA_WAIT  =>
            sci_state       <= GET_WA_WAIT2;
            
         when GET_WA_WAIT2 =>
            sci_state       <= GET_WA_FINISH;
            
         when GET_WA_FINISH =>
            wa_position_i(cnt*4+3 downto cnt*4) <= sci_data_out_i(3 downto 0);
            sci_state       <= GET_WA;    
            cnt             := cnt + 1;
         
      end case;
      
      lsm_status_buf := lsm_status_i;
   end process;

   -- RX/TX leds are on as soon as the correspondent pll is locked and data
   -- other than the idle word is transmitted
   PROC_LEDS: process is
   begin
      wait until rising_edge(CLK);

      led_rx_i <= not gear_to_rm_rst_i;
      led_tx_i <= tx_rst_fsm_ready_i;
      
      if (led_timer_i(20) = '1') or (rx_data_buf_i(17 downto 16) = "10" and rx_data_buf_i(15 downto 0) = x"fcce") then
         led_rx_i <= '0';
      end if;
      
      if (led_timer_i(20) = '1') or (tx_data_i(17 downto 16) = "10" and tx_data_i(15 downto 0) = x"fcce") then
         led_tx_i <= '0';
      end if;

      led_timer_i <= led_timer_i + 1 ;
      if led_timer_i(20) = '1' then
         led_timer_i <= (others => '0');
         last_led_rx_i <= led_rx_i ;
         last_led_tx_i <= led_tx_i;
      end if;      
   end process;
   
   LED_OK_OUT <= led_ok_i;
   LED_RX_OUT <= led_rx_i;
   LED_TX_OUT <= led_tx_i;
   
   -- Produce 1us reset pulse for external logic
   PROC_CLK_RESET: process is
      variable counter : unsigned(8 downto 0) := (others => '0');
   begin
      wait until rising_edge(rclk_125_i);
      CLK_RX_RESET_OUT <= '1';
      
      if rx_cdr_lol_i = '1' then
         counter := (others => '0');
         
      elsif counter(counter'high) = '0' then
         counter := counter + 1;
         
      else
         CLK_RX_RESET_OUT <= '0';
         
      end if;
   end process;

   
   GEN_DEBUG: if INCL_DEBUG_AIDS = c_YES generate
      proc_stat: process is
         variable last_rx_serdes_rst_i : std_logic;
      begin
         wait until rising_edge(clk_125_local);
         
         if rst_n_i = '0' then
            stat_reconnect_counter_i <= (others => '0');
         else
            if rx_serdes_rst_i = '1' and last_rx_serdes_rst_i = '0' then
               stat_reconnect_counter_i <= stat_reconnect_counter_i + TO_UNSIGNED(1,1);
            end if;
         end if;
         
         last_rx_serdes_rst_i := rx_serdes_rst_i;
      end process;
         
   
      DEBUG_OUT(19 downto  0) <= "00" & tx_data_i;
      DEBUG_OUT(23 downto 20) <= "0" & tx_pll_lol_i & rx_los_low_i & rx_cdr_lol_i;
      DEBUG_OUT(27 downto 24) <= gear_to_fsm_rst_i & barrel_shifter_misaligned_i & SD_PRSNT_N_IN & SD_LOS_IN;
      DEBUG_OUT(31 downto 28) <= rst_qd_i & rx_serdes_rst_i & tx_pcs_rst_i & rx_pcs_rst_i;
      
      DEBUG_OUT(51 downto 32) <= "00" & rx_data_buf_i;
      DEBUG_OUT(59 downto 52) <= rx_rst_fsm_state_i & tx_rst_fsm_state_i;
         
      DEBUG_OUT(63 downto 60) <= SERDES_ready & rm_rx_ready_i &  rm_tx_ready_i & rm_tx_almost_ready_i;
      DEBUG_OUT(99 downto 96) <= rm_rx_almost_ready_i & rm_rx_see_ready0_i & rm_rx_saw_ready1_i & rm_rx_valid_char_i;
      DEBUG_OUT(103 downto 100) <= wa_position_i(3 downto 0);
      DEBUG_OUT(107 downto 104) <= "00" & rm_rx_to_gear_reset_i & gear_to_rm_rst_i;
      
      DEBUG_OUT(127 downto 112) <= STD_LOGIC_VECTOR(stat_reconnect_counter_i);
      
      -- STAT_OP REGISTER
      STAT_OP(8 downto 0) <= rx_data_i;

      STAT_OP(9)  <= rclk_250_i;
      STAT_OP(10) <= clk_125_i;
      STAT_OP(11) <= rx_cdr_lol_i;
      STAT_OP(12) <= rx_los_low_i;
      STAT_OP(13) <= lsm_status_i;
      STAT_OP(14) <= rx_serdes_rst_i;
      STAT_OP(15) <= rx_pcs_rst_i;
   end generate;
end architecture;
