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
      IS_SYNC_SLAVE   : integer := c_YES;       --select slave mode
      DETERMINISTIC_LATENCY : integer := c_YES; -- if selected proper alignment of barrel shifter and word alignment is enforced (link may come up slower)
      IS_SIMULATED    : integer := c_NO;
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

      SERDES_ready       : out std_logic;

      --SFP Connection
      SD_RXD_P_IN        : in  std_logic := '0';
      SD_RXD_N_IN        : in  std_logic := '0';
      SD_TXD_P_OUT       : out std_logic := '0';
      SD_TXD_N_OUT       : out std_logic := '0';

      SD_PRSNT_N_IN      : in  std_logic;  -- SFP Present ('0' = SFP in place,entity '1' = no SFP mounted)
      SD_LOS_IN          : in  std_logic;  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
      SD_TXDIS_OUT       : out  std_logic := '0'; -- SFP disable

      LED_RX_OUT         : out std_logic;
      LED_TX_OUT         : out std_logic;
      LED_OK_OUT         : out std_logic;
      
      -- Status and control port
      STAT_OP            : out std_logic_vector ( 15 downto 0) := (others => '0');
      CTRL_OP            : in  std_logic_vector ( 15 downto 0) := (others => '0');
      DEBUG_OUT          : out std_logic_vector (511 downto 0) := (others => '0')
   );
   
   attribute BLOCKNET : boolean;
   attribute BLOCKNET of DEBUG_OUT : signal is true;
end entity;

architecture cbmnet_phy_ecp3_arch of cbmnet_phy_ecp3 is
   attribute syn_hier : string;
   attribute syn_hier of cbmnet_phy_ecp3_arch : architecture is "hard";

   constant WA_FIXATION : integer := c_YES;
   signal DETERMINISTIC_LATENCY_C : std_logic;

-- Clocks and global resets   
   signal clk_125_local     : std_logic;  -- local 125 MHz reference clock driven by clock generators
   signal rclk_250_i        : std_logic;  -- recovered word clock
   signal rclk_125_i        : std_logic;  -- rclk_250_i divided by two. aligned s.t. the rising edge corresponds to the lower received word
   signal clk_tx_full_i     : std_logic;  -- 250 MHz clock generated by the serdes's TX-PLL

   signal clk_tx_half_i     : std_logic;  -- 250 MHz clock generated by the serdes's TX-PLL
  
   signal rst_i               : std_logic;  -- High-active reset driven by external logic
   signal rst_n_i             : std_logic;  -- Low-active version of rst_i
   
-- SERDES/PCS 
   -- status
   signal rx_los_low_i  : std_logic;
   signal rx_cdr_lol_i  : std_logic;
   signal tx_pll_lol_i  : std_logic;
   signal lsm_status_i : std_logic;

   signal rx_dec_error_i:          std_logic;
   signal rx_dec_error_delayed_i : std_logic;
   signal rx_dec_error_250_i : std_logic_vector(1 downto 0);
   signal rx_dec_error_125_i, rx_dec_error_125_buf_i: std_logic_vector(1 downto 0);

   signal rx_error_delay : std_logic_vector(7 downto 0) := (others => '0'); -- shift register to detect a "stable error condition"
   
   -- resets
   signal rst_qd_i            : std_logic;
   signal serdes_rst_qd_i     : std_logic;
   
   signal tx_serdes_rst_i     : std_logic;
   signal tx_pcs_rst_i        : std_logic;
   
   signal rx_serdes_rst_i     : std_logic;
   signal rx_pcs_rst_i        : std_logic;

   -- data
   signal tx_data_to_serdes_i      : std_logic_vector( 8 downto 0); -- received by SERDES
   signal rx_data_from_serdes_i    : std_logic_vector( 8 downto 0); -- received by SERDES

   -- status & control interface (and obtained info)
   signal sci_ch_i          : std_logic_vector(3 downto 0);
   signal sci_qd_i          : std_logic;
   signal sci_reg_i         : std_logic;
   signal sci_addr_i        : std_logic_vector(8 downto 0);
   signal sci_data_in_i     : std_logic_vector(7 downto 0) := (others => '0');
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
   
   signal serdes_ready_i : std_logic;
   
-- SCI Logic to obtain the barrel shifter position
   type sci_ctrl is (IDLE, GET_WA, GET_WA_WAIT, GET_WA_WAIT2, GET_WA_FINISH);
   signal sci_state         : sci_ctrl;
   signal sci_timer         : unsigned( 7 downto 0) := (others => '0');
   signal start_timer       : unsigned(18 downto 0) := (others => '0');
   
-- GEAR
   signal gear_to_fsm_rst_i  : std_logic;
   signal gear_to_rm_rst_i   : std_logic; -- gear keeps CBMNet ready manager reset until gear locked successfully
   signal gear_to_rm_n_rst_i : std_logic; -- inverted version of above

   signal rx_data_from_gear_i     : std_logic_vector(17 downto 0); -- 16(+2) bit word generated by gear
   
   signal rx_data_i     : std_logic_vector(17 downto 0); -- in the front end this signal is identical to rx_data_from_gear_i
                                                         -- otherwise a clock domain crossing from rclk_125_i to clk_125_local is
                                                         -- necessary. this signal will not exhibit a deterministic latency !!!!!!
                                                         -- (however, this is no problem, as the clock master will not receive DLMs)

   signal rx_data_debug_i : std_logic_vector(17 downto 0);                                        
                                                         
   signal tx_data_i     : std_logic_vector(17 downto 0); -- 16(+2) bit word generated fed to gear
   signal tx_gear_reset_i : std_logic;
   signal tx_gear_allow_relock_i : std_logic;
   
   signal tx_gear_ready_i : std_logic;
   
   signal rx_gear_debug_i : std_logic_vector(31 downto 0);
   signal tx_gear_debug_i : std_logic_vector(31 downto 0);
   
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
   
   signal rm_rx_data_buf_i : std_logic_vector(17 downto 0);
   
   signal rm_rx_ebtb_code_err_cntr_clr_i  : std_logic;
   signal rm_rx_ebtb_disp_err_cntr_clr_i  : std_logic;
   signal rm_rx_ebtb_code_err_cntr_i      : std_logic_vector(15 downto 0);
   signal rm_rx_ebtb_disp_err_cntr_i      : std_logic_vector(15 downto 0);
   signal rm_rx_ebtb_code_err_cntr_flag_i : std_logic;
   signal rm_rx_ebtb_disp_err_cntr_flag_i : std_logic;
   
   signal rm_tx_to_rx_reinit_i : std_logic;
   
   signal rm_rx_see_reinit : std_logic;
   signal rm_rx_ebtb_detect_i : std_logic;
   signal rm_tx_link_lost_i : std_logic;
   
   signal rm_tx_pcs_startup_cntr_clr  : std_logic;
   signal rm_tx_pcs_startup_cntr      : std_logic_vector(15 downto 0);       -- Counts for link startups
   signal rm_tx_pcs_startup_cntr_flag : std_logic;   
   
   signal rm_rx_rxpcs_ready_i : std_logic;

-- LEDs
   signal led_ok_i                 : std_logic;
   signal led_tx_i, last_led_tx_i  : std_logic;
   signal led_rx_i, last_led_rx_i  : std_logic;
   signal led_timer_i              : unsigned(20 downto 0);

-- Stats
   signal stat_reconnect_counter_i : unsigned(15 downto 0); -- counts the number of RX-serdes resets since last external reset
   signal stat_last_reconnect_duration_i : unsigned(31 downto 0);
   signal stat_decode_error_counter_i : unsigned(31 downto 0);
   
   
   signal stat_wa_int_i : std_logic_vector(15 downto 0) := (others => '0');
   
   signal tx_data_debug_i : std_logic_vector(17 downto 0);
   signal tx_data_debug_state_i : std_logic;
   
   signal low_level_rx_see_dlm0     : std_logic;
   signal low_level_tx_see_dlm0     : std_logic;
   signal low_level_tx_see_dlm0_125 : std_logic;
   
   signal stat_dlm_counter_i : unsigned(15 downto 0);
   signal stat_init_ack_counter_i : unsigned(15 downto 0);
   
   signal test_line_i : std_logic_vector(15 downto 0) := x"0001";
   
   signal rx_stab_i, tx_stab_i : unsigned(15 downto 0);
   
   signal rx_data_sp_i0, rx_data_sp_i1, rx_data_sp_i2, rx_data_sp_i3 : std_logic_vector(17 downto 0);
   
   signal tx_data_sp_i0, tx_data_sp_i1, tx_data_sp_i2, tx_data_sp_i3 : std_logic_vector(17 downto 0);
   signal tx_data_sp_i4, tx_data_sp_i5, tx_data_sp_i6, tx_data_sp_i7 : std_logic_vector(17 downto 0);
   signal tx_data_sp_i8, tx_data_sp_i9, tx_data_sp_i10,tx_data_sp_i11: std_logic_vector(17 downto 0);
   
   signal dlm_counter_i : unsigned(15 downto 0) := x"0000";
   signal detect_dlm_125_i, detect_dlm_250_i : std_logic := '0';
   
   --signal see_dlm_lb_i, see_dlm_lb_buf_i : std_logic_vector(15 downto 0) := (others => '0');
   --signal see_dlm_lb_aggr_i, see_dlm_hb_i, see_dlm_hb_buf_i : std_logic;
   --signal stat_sync_dlm_counter_i, stat_sync_dlm_inv_counter_i : unsigned(7 downto 0);
   
begin
   assert IS_SYNC_SLAVE = c_YES 
      report "Support of clock master PHY is not tested anymore and probably broken"
      severity failure;
	  
   DETERMINISTIC_LATENCY_C <= '1' when DETERMINISTIC_LATENCY = c_YES else '0';

   clk_125_local <= CLK;
   CLK_RX_HALF_OUT <= rclk_125_i;
   CLK_RX_FULL_OUT <= rclk_250_i;

   SD_TXDIS_OUT <= '0';

   rst_i   <=     (CLEAR or CTRL_OP(0));
   rst_n_i <= not rst_i;

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
      rx_full_clk_ch0      => rclk_250_i,
      rx_half_clk_ch0      => open, -- recovered (and correctly aligned) 125 MHz clock is generated by gear
      
      tx_full_clk_ch0      => clk_tx_full_i,
      tx_half_clk_ch0      => open,
      
      fpga_rxrefclk_ch0    => clk_125_local,
      fpga_txrefclk        => rclk_125_i,
      txiclk_ch0           => rclk_250_i,

   -- RESETS
      rst_qd_c             => rst_qd_i,
      serdes_rst_qd_c      => serdes_rst_qd_i, -- always 0
      tx_serdes_rst_c      => tx_serdes_rst_i, -- always 0
      rx_serdes_rst_ch0_c  => rx_serdes_rst_i,
      tx_pcs_rst_ch0_c     => tx_pcs_rst_i,
      rx_pcs_rst_ch0_c     => rx_pcs_rst_i,

      tx_pwrup_ch0_c       => '1',
      rx_pwrup_ch0_c       => '1',
   
   -- TX DATA PORT    
      txdata_ch0           => tx_data_to_serdes_i(7 downto 0),
      tx_k_ch0             => tx_data_to_serdes_i(8),

      tx_force_disp_ch0    => '0',
      tx_disp_sel_ch0      => '0',
      tx_div2_mode_ch0_c   => '0',
      
   -- RX DATA PORT
      rxdata_ch0           => rx_data_from_serdes_i(7 downto 0),
      rx_k_ch0             => rx_data_from_serdes_i(8),

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
   
   THE_RX_GEAR: CBMNET_PHY_RX_GEAR 
   generic map (
      IS_SYNC_SLAVE => IS_SYNC_SLAVE
   ) port map (
   -- SERDES PORT
      CLK_250_IN      => rclk_250_i,             -- in std_logic;
      PCS_READY_IN    => rx_rst_fsm_ready_i, -- in std_logic;
      SERDES_RESET_OUT=> gear_to_fsm_rst_i,    -- out std_logic;
      DATA_IN         => rx_data_from_serdes_i,               -- in  std_logic_vector( 8 downto 0);

   -- RM PORT
      RM_RESET_IN => rm_rx_to_gear_reset_i,     -- in std_logic;
      CLK_125_OUT => rclk_125_i,                -- out std_logic;
      RESET_OUT   => gear_to_rm_rst_i,          -- out std_logic;
      DATA_OUT    => rx_data_i,       -- out std_logic_vector(17 downto 0)
      
      DEBUG_OUT   => rx_gear_debug_i
   );
   
   THE_TX_GEAR: CBMNET_PHY_TX_GEAR
   generic map (IS_SYNC_SLAVE => IS_SYNC_SLAVE)
   port map (
      CLK_250_IN  => clk_tx_full_i,     -- in std_logic;
      CLK_125_IN  => rclk_125_i, -- in std_logic;
      CLK_125_OUT => clk_tx_half_i,
      
      RESET_IN    => tx_gear_reset_i, -- in std_logic;
      ALLOW_RELOCK_IN => tx_gear_allow_relock_i, -- in std_logic
      
      TX_READY_OUT => tx_gear_ready_i,
      
      DATA_IN     => tx_data_i, -- in std_logic_vector(17 downto 0)
      DATA_OUT    => tx_data_to_serdes_i -- out std_logic_vector(8 downto 0);
   );
   tx_gear_reset_i <= not tx_rst_fsm_ready_i;
   tx_gear_allow_relock_i <= '0';

   
   
   tx_serdes_rst_i <= '0'; --no function
   serdes_rst_qd_i <= '0'; --included in rst_qd_i
   
   -------------------------------------------------      
   -- Reset FSM & Link states
   -------------------------------------------------      
   THE_RX_FSM : cbmnet_phy_ecp3_rx_reset_fsm
   generic map (
      IS_SIMULATED => IS_SIMULATED
   )
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
   byte_alignment_to_fsm_i <= not (DETERMINISTIC_LATENCY_C and barrel_shifter_misaligned_i) or CTRL_OP(3);
   word_alignment_to_fsm_i <= not (gear_to_fsm_rst_i or AND_ALL(rx_error_delay)) or CTRL_OP(5);
   
   
--   -- decode error
  rx_dec_error_delayed_i <= rx_dec_error_i when rising_edge(rclk_250_i);
  rx_dec_error_250_i <= rx_dec_error_i & rx_dec_error_delayed_i when rising_edge(rclk_250_i);
  
  rx_dec_error_125_i     <= rx_dec_error_250_i when rising_edge(clk_125_local);
  rx_dec_error_125_buf_i <= rx_dec_error_125_i when rising_edge(clk_125_local);
  
  rx_error_delay <= rx_error_delay(rx_error_delay'high - 2 downto 0) & rx_dec_error_125_buf_i when rising_edge(clk_125_local);
--   process is 
--   begin
--      wait until rising_edge(rclk_125_i);
--      if RESET='1' then
--         stat_decode_error_counter_i <= (others => '0');
--      elsif rx_dec_error_125_buf_i = "11" then
--         stat_decode_error_counter_i <= stat_decode_error_counter_i + 2;
--      elsif rx_dec_error_125_buf_i = "10" or rx_dec_error_125_buf_i = "01" then
--         stat_decode_error_counter_i <= stat_decode_error_counter_i + 1;
--      end if;
--   end process;
   
      
   THE_TX_FSM : cbmnet_phy_ecp3_tx_reset_fsm
   generic map (
      IS_SIMULATED => IS_SIMULATED
   )
   port map(
      RST_N           => rst_n_i,
      TX_REFCLK       => clk_125_local,
      TX_PLL_LOL_QD_S => tx_pll_lol_i,
      RST_QD_C        => rst_qd_i,
      TX_PCS_RST_CH_C => tx_pcs_rst_i,
      STATE_OUT       => tx_rst_fsm_state_i
   );
   
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
         
   -------------------------------------------------      
   -- CBMNet Ready Modules
   -------------------------------------------------      
   THE_RX_READY: cn_rx_pcs_wrapper
   generic map (
      SIMULATION => 0,
      USE_BS => 0,
      SYNC_SIGNALS => 1,
      INCL_8B10B_DEC => 0
   )
   port map (   
      rx_clk                  => rclk_125_i,            -- in std_logic;
      res_n_rx                => gear_to_rm_n_rst_i,    -- in std_logic;
      rxpcs_reinit            => rm_tx_to_rx_reinit_i,  -- in std_logic;                     -- Reinit RXPCS 
      rxdata_in(17 downto 0)  => rx_data_i,
      rxdata_in(19 downto 18) => "00",
      reset_rx_cdr            => rm_rx_to_gear_reset_i, -- out std_logic;                    -- Reset RX CDR to align
      rxpcs_almost_ready      => rm_rx_almost_ready_i,  -- out std_logic;                    -- Ready1 detected, only waiting for break
      rxpcs_ready             => rm_rx_rxpcs_ready_i,   -- out std_logic;                    -- RXPCS initialization done
      see_reinit              => rm_rx_see_reinit,      -- out std_logic;                    -- Initialization pattern detected although ready
      bs_position             => open,                  -- out std_logic_vector(4 downto 0); -- Number of bit-shifts necessary for word-alignment
      rxdata_out              => rm_rx_data_buf_i,      -- out std_logic_vector(17 downto 0);
      ebtb_detect             => rm_rx_ebtb_detect_i,   -- out std_logic;                    -- Depends on the FSM state, alignment done
      
      --diagnostics
      ebtb_code_err_cntr_clr  => '0', -- in std_logic;
      ebtb_disp_err_cntr_clr  => '0', -- in std_logic;
      ebtb_code_err_cntr      => open,     -- out std_logic_vector(15 downto 0); -- Counts for code errors if ebtb_detect is true
      ebtb_disp_err_cntr      => open,     -- out std_logic_vector(15 downto 0); -- Counts for disparity errors if ebtb_detect is true
      ebtb_code_err_cntr_flag => open,-- out std_logic;
      ebtb_disp_err_cntr_flag => open -- out std_logic
   );

   PHY_RXDATA_OUT   <= rx_data_i(15 downto 0);
   PHY_RXDATA_K_OUT <= rx_data_i(17 downto 16);
   gear_to_rm_n_rst_i <= not gear_to_rm_rst_i when rising_edge(rclk_125_i);
   
   
   THE_TX_READY: cn_tx_pcs_wrapper 
   generic map (
      REVERSE_OUTPUT => 0, --integer range 0 to 1 := 1;
      LINK_MASTER    => 0, --integer range 0 to 1 := 1;
      SYNC_SIGNALS   => 1, --integer range 0 to 1 := 1;

      INCL_8B10B_ENC => 0  --integer range 0 to 1 := 1
   ) port map (
      tx_clk                 => rclk_125_i,               --in std_logic;
      res_n_tx               => tx_rst_fsm_ready_buf_i,  --in std_logic;
      pcs_restart            => CTRL_OP(14),             --in std_logic;          -- restart pcs layer
      pma_ready              => tx_gear_ready_i,         --in std_logic;
      ebtb_detect            => rm_rx_ebtb_detect_i,     --in std_logic;            -- alignment done and valid 8b10b stream detected
      see_reinit             => rm_rx_see_reinit,        --in std_logic;
      rxpcs_almost_ready     => rm_rx_almost_ready_i,    --in std_logic;
      txdata_in(15 downto 0) => PHY_TXDATA_IN,           --in std_logic_vector(17 downto 0);
      txdata_in(17 downto 16)=> PHY_TXDATA_K_IN,

      rx_bitdelay_done        => '1',                    --in std_logic;
      
      txpcs_ready            => rm_tx_ready_i,           --out std_logic;
      link_lost              => rm_tx_link_lost_i,       --out std_logic;
      reset_out              => open,                    --out std_logic;
      rxpcs_reinit           => rm_tx_to_rx_reinit_i,    --out std_logic;           -- Reinit the RXPCS FSM
      txdata_out             => tx_data_i,               --out std_logic_vector(17 downto 0);             -- tx data to transceiver
      txdata_out_coded       => open,                    --out std_logic_vector(19 downto 0);       -- tx data to transceiver already 8b10b coded
      
      --diagnostics
      pcs_startup_cntr_clr   => rm_tx_pcs_startup_cntr_clr,  --in std_logic;
      pcs_startup_cntr       => rm_tx_pcs_startup_cntr,      --out std_logic_vector(15 downto 0);       -- Counts for link startups
      pcs_startup_cntr_flag  => rm_tx_pcs_startup_cntr_flag  --out std_logic;
   );

   
   rm_rx_status_for_tx_i <= rm_rx_almost_ready_i or rm_rx_ready_i;
   
   -- clock domain crossing from clk_125_local to rclk_125_i
   PROC_SYNC_FSM_READY: process is begin
      wait until rising_edge(rclk_125_i);
      
      if IS_SYNC_SLAVE = c_YES then
         tx_rst_fsm_ready_buf_i <= tx_rst_fsm_ready_i and not gear_to_rm_rst_i;
         
      else
         tx_rst_fsm_ready_buf_i <= tx_rst_fsm_ready_i;
         
      end if;
   end process;
      
   serdes_ready_i <= rm_tx_ready_i and rm_rx_rxpcs_ready_i when rising_edge(rclk_125_i);
   led_ok_i       <= serdes_ready_i;
   SERDES_ready   <= serdes_ready_i;
   
   -------------------------------------------------      
   -- SCI
   -------------------------------------------------      
   -- gives access to serdes config port from slow control and reads word alignment every ~ 40 us
   -- upon retrival the barrel shifter is checked and - if necessary - a serdes reset is issued
   PROC_SCI_CTRL: process 
      variable cnt : integer range 0 to 4 := 0;
   begin
      wait until rising_edge(clk_125_local);
     
      case sci_state is
         when IDLE =>
            sci_ch_i        <= x"0";
            sci_qd_i        <= '0';
            sci_reg_i       <= '0';
            sci_read_i      <= '0';
            sci_write_i     <= '0';
            sci_timer       <= sci_timer + 1;
            if sci_timer(sci_timer'left) = '1' and rx_rst_fsm_ready_i = '1' then
               sci_timer     <= (others => '0');
               sci_state     <= GET_WA;
            end if;      

      when GET_WA =>
            if cnt = 4 then
               cnt           := 0;
               sci_state     <= IDLE;
               
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
   end process;
   
   process is begin
      wait until rising_edge(clk_125_local);
      barrel_shifter_misaligned_i <= '0';
      if lsm_status_i = '1' and  wa_position_i(3 downto 0) /= x"0" then
         barrel_shifter_misaligned_i <= '1';
      end if;
   end process;
   
   -- Produce 1us reset pulse for external logic
   PROC_CLK_RESET: process is
      variable counter : unsigned(8 downto 0) := (others => '0');
   begin
      wait until rising_edge(rclk_125_i);
      CLK_RX_RESET_OUT <= '1';
      
      if serdes_ready_i = '0' then
         counter := (others => '0');
         
      elsif counter(counter'high) = '0' then
         counter := counter + 1;
         
      else
         CLK_RX_RESET_OUT <= '0';
         
      end if;
   end process;
   
   LED_RX_OUT <= '0' when rx_data_i /= "10" & x"fcc3" and  rx_data_i /= "00" & x"0000" else '1';
   LED_TX_OUT <= '0' when tx_data_i /= "10" & x"fcc3" and  tx_data_i /= "00" & x"0000" else '1';
   LED_OK_OUT <= serdes_ready_i;
   
   GEN_DEBUG: if INCL_DEBUG_AIDS = c_YES generate
      proc_stat: process is
         variable last_rx_serdes_rst_i : std_logic;
      begin
         wait until rising_edge(clk_125_local);
         
         if rst_n_i = '0' then
            stat_reconnect_counter_i <= (others => '0');
            stat_last_reconnect_duration_i <= (others => '0');
            stat_wa_int_i <= (others => '0');
         else
            if rx_serdes_rst_i = '1' and last_rx_serdes_rst_i = '0' then
               stat_reconnect_counter_i <= stat_reconnect_counter_i + TO_UNSIGNED(1,1);
            end if;
            
            if serdes_ready_i = '0' then
               stat_last_reconnect_duration_i <= stat_last_reconnect_duration_i + TO_UNSIGNED(1,1);
            end if;
            
            stat_wa_int_i <= stat_wa_int_i or wa_position_i;
         end if;
         
         last_rx_serdes_rst_i := rx_serdes_rst_i;
      end process;
      
      process is
         variable rx_v, tx_v : std_logic_vector(17 downto 0);
      begin
         wait until rising_edge(rclk_125_i);

         rx_stab_i <= rx_stab_i + 1; 
         if reset = '1' or rx_v /= rx_data_i then
            rx_stab_i <= (others => '0');
         end if;

         tx_stab_i <= tx_stab_i + 1;
         if reset = '1' or tx_v /= tx_data_i then 
            tx_stab_i <= (others => '0');
         end if;                  

         rx_v := rx_data_i;
         tx_v := tx_data_i;
      end process;
      
      PROC_SENSE_DLMS: process begin
         wait until rising_edge(rclk_125_i);

         if serdes_ready_i = '0' then
            stat_dlm_counter_i <= (others => '0');
         elsif rx_data_i(17) = '1' and rx_data_i(15 downto 8) = K277 then
            stat_dlm_counter_i <= stat_dlm_counter_i + TO_UNSIGNED(1,1);
         end if;
      end process;

      PROC_DEBUG_SYNC: process begin
         wait until rising_edge(rclk_125_i);
      
-- DEBUG_OUT_BEGIN      
         DEBUG_OUT(19 downto  0) <= "00" & tx_data_i(17 downto 0);
         DEBUG_OUT(23 downto 20) <= "0" & tx_pll_lol_i & rx_los_low_i & rx_cdr_lol_i;

         DEBUG_OUT(27 downto 24) <= gear_to_fsm_rst_i & barrel_shifter_misaligned_i & SD_PRSNT_N_IN & SD_LOS_IN;
         DEBUG_OUT(31 downto 28) <= rst_qd_i & rx_serdes_rst_i & tx_pcs_rst_i & rx_pcs_rst_i;

         DEBUG_OUT( 51 downto 32) <= "00" & rx_data_i(17 downto 0);
         DEBUG_OUT( 59 downto 52) <= rx_rst_fsm_state_i(3 downto 0) & tx_rst_fsm_state_i(3 downto 0);
            
         DEBUG_OUT( 63 downto 60) <= serdes_ready_i & rm_rx_ready_i &  rm_tx_ready_i & rm_tx_almost_ready_i;

         DEBUG_OUT( 79 downto 64) <= rx_gear_debug_i(15 downto 0);
         DEBUG_OUT( 95 downto 80) <= tx_gear_debug_i(15 downto 0);

         DEBUG_OUT( 99 downto 96) <= rm_rx_almost_ready_i & rm_rx_rxpcs_ready_i & rm_rx_see_reinit & rm_rx_ebtb_detect_i;
         DEBUG_OUT(103 downto 100) <= wa_position_i(3 downto 0);
         DEBUG_OUT(107 downto 104) <= word_alignment_to_fsm_i & byte_alignment_to_fsm_i & rm_rx_to_gear_reset_i & gear_to_rm_rst_i;

         DEBUG_OUT(123 downto 108) <= tx_stab_i(15 downto 0);

         DEBUG_OUT(139 downto 124) <= rx_stab_i(15 downto 0);
         DEBUG_OUT(147 downto 140) <= stat_init_ack_counter_i(7 downto 0);
         DEBUG_OUT(179 downto 148) <= stat_last_reconnect_duration_i(31 downto 0);

         DEBUG_OUT(195 downto 180) <= stat_reconnect_counter_i(15 downto 0);
         DEBUG_OUT(211 downto 196) <= stat_dlm_counter_i(15 downto 0);
         DEBUG_OUT(243 downto 212) <= rm_rx_ebtb_code_err_cntr_i(15 downto 0) & rm_rx_ebtb_disp_err_cntr_i(15 downto 0);

         DEBUG_OUT(315 downto 244) <= rx_data_sp_i3(17 downto 0) & rx_data_sp_i2(17 downto 0) & rx_data_sp_i1(17 downto 0) & rx_data_sp_i0(17 downto 0);
         DEBUG_OUT(331 downto 316) <= dlm_counter_i(15 downto 0);


         DEBUG_OUT(403 downto 332) <= tx_data_sp_i3(17 downto 0) & tx_data_sp_i2(17 downto 0) & tx_data_sp_i1(17 downto 0) & tx_data_sp_i0(17 downto 0);
         DEBUG_OUT(421 downto 404) <= PHY_TXDATA_K_IN(1 downto 0) & PHY_TXDATA_IN(15 downto 0);
         DEBUG_OUT(511 downto 422) <= tx_data_sp_i8(17 downto 0) & tx_data_sp_i7(17 downto 0) & tx_data_sp_i6(17 downto 0) & tx_data_sp_i5(17 downto 0) & tx_data_sp_i4(17 downto 0);
-- DEBUG_OUT_END
      end process;
   
      process is
      begin
         wait until rising_edge(rclk_125_i);
         if rx_data_i /= "10" & x"fcc3" and  rx_data_i /= "00" & x"0000" then
            rx_data_sp_i0 <= rx_data_i;
            rx_data_sp_i1 <= rx_data_sp_i0;
            rx_data_sp_i2 <= rx_data_sp_i1;
            rx_data_sp_i3 <= rx_data_sp_i2;
         end if;
      end process;

      
      process is
      begin
         wait until rising_edge(rclk_125_i);
         if tx_data_i /= "10" & x"fcc3" and tx_data_i(17 downto 16) /= "00" then
            tx_data_sp_i0 <= tx_data_i;
            tx_data_sp_i1 <= tx_data_sp_i0;
            tx_data_sp_i2 <= tx_data_sp_i1;
            tx_data_sp_i3 <= tx_data_sp_i2;
            tx_data_sp_i4 <= tx_data_sp_i3;
            tx_data_sp_i5 <= tx_data_sp_i4;
            tx_data_sp_i6 <= tx_data_sp_i5;
            tx_data_sp_i7 <= tx_data_sp_i6;
            tx_data_sp_i8 <= tx_data_sp_i7;
            tx_data_sp_i9 <= tx_data_sp_i8;
            tx_data_sp_i10 <= tx_data_sp_i9;
            tx_data_sp_i11 <= tx_data_sp_i10;
         end if;
      end process;

      
      process is 
      begin
         wait until rising_edge(rclk_125_i);
         
         STAT_OP(0)<= '0';
         if rx_data_i = "10" & K277 & EBTB_D_ENCODE(14,6) then
            STAT_OP(0) <= '1';
         end if;
      end process;
   end generate;
end architecture;