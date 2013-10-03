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
      IS_SYNC_SLAVE   : integer := c_NO       --select slave mode
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

      --Control Interface
      SCI_DATA_IN        : in  std_logic_vector(7 downto 0) := (others => '0');
      SCI_DATA_OUT       : out std_logic_vector(7 downto 0) := (others => '0');
      SCI_ADDR           : in  std_logic_vector(8 downto 0) := (others => '0');
      SCI_READ           : in  std_logic := '0';
      SCI_WRITE          : in  std_logic := '0';
      SCI_ACK            : out std_logic := '0';
      SCI_NACK           : out std_logic := '0';

      -- Status and control port
      STAT_OP            : out std_logic_vector (15 downto 0);
      CTRL_OP            : in  std_logic_vector (15 downto 0) := (others => '0');
      STAT_DEBUG         : out std_logic_vector (63 downto 0);
      CTRL_DEBUG         : in  std_logic_vector (63 downto 0) := (others => '0');
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
   
   signal clk_125_i         : std_logic;
   signal clk_125_local  : std_logic;
   signal clk_rx_full       : std_logic;
   signal clk_rx_half       : std_logic;

   signal tx_data_i         : std_logic_vector(17 downto 0);
   
   signal rx_data_i         : std_logic_vector(8 downto 0);
   signal rx_data_buf_i     : std_logic_vector(17 downto 0);
   
   signal rx_error          : std_logic;

   signal rst_n             : std_logic;
   signal rst               : std_logic;
   signal tx_serdes_rst     : std_logic;
   signal tx_pcs_rst        : std_logic;
   signal rst_qd            : std_logic;
   signal serdes_rst_qd     : std_logic;
   signal sd_los_i          : std_logic;

   signal rx_pcs_rst        : std_logic;
   signal rx_serdes_rst     : std_logic;
   signal rx_reset_from_rm_i: std_logic;
   
   signal rx_los_low        : std_logic;
   signal rx_cdr_lol        : std_logic;
   signal tx_pll_lol        : std_logic;
   
   signal serdes_ready_i    : std_logic;
   signal serdes_rx_ready_i : std_logic;
   signal serdes_tx_ready_i : std_logic;

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

   signal wa_position        : std_logic_vector(15 downto 0) := x"FFFF";
   
   signal rx_fsm_state       : std_logic_vector(3 downto 0);
   signal tx_fsm_state       : std_logic_vector(3 downto 0);
   signal tx_rst_fsm_ready_i  : std_logic;
   signal tx_rst_fsm_ready_buf_i  : std_logic;
   

   type sci_ctrl is (IDLE, GET_WA, GET_WA_WAIT, GET_WA_WAIT2, GET_WA_FINISH);
   signal sci_state         : sci_ctrl;
   signal sci_timer         : unsigned( 4 downto 0) := (others => '0');
   signal start_timer       : unsigned(18 downto 0) := (others => '0');

   signal led_ok                 : std_logic;
   signal led_tx, last_led_tx    : std_logic;
   signal led_rx, last_led_rx    : std_logic;
   signal led_timer              : unsigned(20 downto 0);

   signal proper_byte_align_i : std_logic;
   signal byte_alignment_to_fsm_i : std_logic;
   
   signal gear_to_serder_rst_i : std_logic;
   signal word_alignment_to_fsm_i : std_logic;
   
   signal rx_rm_to_gear_reset_i : std_logic;
   
   signal rx_rst_fsm_ready_i : std_logic;
   signal rx_serdes_ready_for_gear_i : std_logic;
   
   signal lsm_status_i : std_logic;
   
   signal rx_error_delay : std_logic_vector(3 downto 0);
   
-- RX READY MODULE
   signal rx_ready_i : std_logic;
   signal rx_almost_ready_i : std_logic;
   signal rx_rm_ready_i : std_logic;
   signal rx_see_ready0_i : std_logic;
   signal rx_saw_ready1_i : std_logic;
   signal rx_valid_char_i : std_logic;
   signal link_init_rx_reset_i : std_logic;
   
   signal rx_rm_rst_n, tx_rm_rst_n :std_logic;
   
   signal dummy_output_i : std_logic_vector(8 downto 0);
   
   signal gear_to_rm_rst_i : std_logic;
   signal gear_to_rm_n_rst_i : std_logic;
   
-- TX READY MODULE   
   signal tx_ready_i : std_logic;
   signal tx_almost_ready_i : std_logic;
begin
   clk_125_local <= CLK;
   CLK_RX_HALF_OUT <= clk_rx_half;
   CLK_RX_FULL_OUT <= clk_rx_full;

   SD_TXDIS_OUT <= '0';

   rst   <=     (CLEAR or CTRL_OP(0));
   rst_n <= not rst;

   gen_slave_clock : if IS_SYNC_SLAVE = c_YES generate
      clk_125_i        <= clk_rx_half;
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
      --rxiclk_ch0           => clk_125_i,
      txiclk_ch0           => clk_125_i,
      
      rx_full_clk_ch0      => clk_rx_full,
   --   rx_half_clk_ch0      => clk_rx_half,
      
      tx_full_clk_ch0      => open,
      tx_half_clk_ch0      => open,
      
      fpga_rxrefclk_ch0    => clk_125_local,

   -- RESETS
      fpga_txrefclk        => clk_125_i,
      rst_qd_c             => rst_qd,
      serdes_rst_qd_c      => serdes_rst_qd, -- always 0
      tx_serdes_rst_c      => tx_serdes_rst, -- always 0
      rx_serdes_rst_ch0_c  => rx_serdes_rst,
      tx_pcs_rst_ch0_c     => tx_pcs_rst,
      rx_pcs_rst_ch0_c     => rx_pcs_rst,

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
      rx_cv_err_ch0        => rx_error,
      rx_div2_mode_ch0_c   => '0',
      
   -- LOOPBACK
      sb_felb_ch0_c        => '0',
      sb_felb_rst_ch0_c    => '0',

   -- STATUS
      tx_pll_lol_qd_s      => tx_pll_lol,
      rx_los_low_ch0_s     => rx_los_low,
      rx_cdr_lol_ch0_s     => rx_cdr_lol,
      lsm_status_ch0_s     => lsm_status_i,
    
      SCI_WRDATA           => sci_data_in_i,
      SCI_RDDATA           => sci_data_out_i,
      SCI_ADDR             => sci_addr_i(5 downto 0),
      SCI_SEL_QUAD         => sci_qd_i,
      SCI_SEL_CH0          => sci_ch_i(0),
      SCI_RD               => sci_read_i,
      SCI_WRN              => sci_write_i
   );
   
   tx_serdes_rst <= '0'; --no function
   serdes_rst_qd <= '0'; --included in rst_qd
   
   DEBUG_OUT(19 downto  0) <= "00" & tx_data_i;
   DEBUG_OUT(23 downto 20) <= "0" & tx_pll_lol & rx_los_low & rx_cdr_lol;
   DEBUG_OUT(27 downto 24) <= gear_to_serder_rst_i & proper_byte_align_i & SD_PRSNT_N_IN & SD_LOS_IN;
   DEBUG_OUT(31 downto 28) <= rst_qd & rx_serdes_rst & tx_pcs_rst & rx_pcs_rst;
   
   DEBUG_OUT(51 downto 32) <= "00" & rx_data_buf_i;
   DEBUG_OUT(59 downto 52) <= rx_fsm_state & tx_fsm_state;
      
   DEBUG_OUT(63 downto 60) <= SERDES_ready & rx_ready_i &  tx_ready_i & tx_almost_ready_i;
   DEBUG_OUT(99 downto 96) <= rx_almost_ready_i & rx_see_ready0_i & rx_saw_ready1_i & rx_valid_char_i;
   DEBUG_OUT(103 downto 100) <= wa_position(3 downto 0);
   DEBUG_OUT(107 downto 104) <= "00" & rx_rm_to_gear_reset_i & gear_to_rm_rst_i;
      
   -------------------------------------------------      
   -- Reset FSM & Link states
   -------------------------------------------------      
   THE_RX_FSM : cbmnet_phy_ecp3_rx_reset_fsm
   port map(
      RST_N               => rst_n,
      RX_REFCLK           => clk_125_local,
      TX_PLL_LOL_QD_S     => tx_pll_lol,
      RX_CDR_LOL_CH_S     => rx_cdr_lol,
      RX_LOS_LOW_CH_S     => rx_los_low,
      
      RM_RESET_IN         => CTRL_OP(4), --rx_reset_from_rm_i,
      PROPER_BYTE_ALIGN_IN=> byte_alignment_to_fsm_i,
      PROPER_WORD_ALIGN_IN=> word_alignment_to_fsm_i,
      
      RX_SERDES_RST_CH_C  => rx_serdes_rst,
      RX_PCS_RST_CH_C     => rx_pcs_rst,
      STATE_OUT           => rx_fsm_state
   );
   byte_alignment_to_fsm_i <=  proper_byte_align_i or CTRL_OP(1);
   word_alignment_to_fsm_i <= not (gear_to_serder_rst_i or AND_ALL(rx_error_delay)) or CTRL_OP(2);
   rx_error_delay <= rx_error_delay(rx_error_delay'high - 1 downto 0) & rx_error when rising_edge(clk_125_local);
   
      
   THE_TX_FSM : tx_reset_fsm
   port map(
      RST_N           => rst_n,
      TX_REFCLK       => clk_125_local,
      TX_PLL_LOL_QD_S => tx_pll_lol,
      RST_QD_C        => rst_qd,
      TX_PCS_RST_CH_C => tx_pcs_rst,
      STATE_OUT       => tx_fsm_state
   );
   --tx_data_i <= "01" & x"00" & CBMNET_READY_CHAR0;
   
   proc_rst_fsms_ready: process is begin
      wait until rising_edge(clk_125_local);
      rx_rst_fsm_ready_i <= '0';
      if rx_fsm_state = x"6" then
         rx_rst_fsm_ready_i <= '1';
      end if;

      tx_rst_fsm_ready_i <= '0';
      if tx_fsm_state = x"5" then
         tx_rst_fsm_ready_i <= '1';
      end if;
   end process;
   
   THE_GEAR: CBMNET_PHY_GEAR port map (
      -- SERDES PORT
         CLK_250_IN      => clk_rx_full,             -- in std_logic;
         PCS_READY_IN    => rx_serdes_ready_for_gear_i, -- in std_logic;
         SERDES_RESET_OUT=> gear_to_serder_rst_i,    -- out std_logic;
         DATA_IN         => rx_data_i,               -- in  std_logic_vector( 8 downto 0);

      -- RM PORT
         RM_RESET_IN => rx_rm_to_gear_reset_i,      -- in std_logic;
         CLK_125_OUT => clk_rx_half,                -- out std_logic;
         RESET_OUT   => gear_to_rm_rst_i,           -- out std_logic;
         DATA_OUT    => rx_data_buf_i               -- out std_logic_vector(17 downto 0)
   );
   rx_serdes_ready_for_gear_i <= (rx_rst_fsm_ready_i and proper_byte_align_i) or CTRL_OP(5);
   rx_rm_to_gear_reset_i <= rx_reset_from_rm_i and not CTRL_OP(6);
   
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
      tx_ready => tx_ready_i,
      tx_almost_ready => tx_almost_ready_i,

      ready_RM2LP => rx_ready_i,

      rxdata_out  => PHY_RXDATA_OUT,
      charisk_out => PHY_RXDATA_K_OUT,
      
      almost_ready_OUT => rx_almost_ready_i,
      see_ready0 => rx_see_ready0_i,
      saw_ready1 => rx_saw_ready1_i,
      valid_char => rx_valid_char_i,
      
      reset_rx => rx_reset_from_rm_i
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

      see_ready0 => rx_see_ready0_i,      -- :  in std_logic;
      saw_ready1 => rx_saw_ready1_i,      -- :  in std_logic;
      valid_char => rx_valid_char_i,      -- :  in std_logic;
      rx_rm_ready => rx_rm_ready_i,       -- :  in std_logic;

      ready_RM2LP => tx_ready_i,          -- :  out std_logic;
      txdata_out => tx_data_i,            -- :  out std_logic_vector((WORDS*9)-1 downto 0);
      almost_ready => tx_almost_ready_i,  -- :  out std_logic;
      gt11_reinit => open                 -- :  out std_logic   
   );
   
   process is begin
      wait until rising_edge(clk_125_i);
      
      if IS_SYNC_SLAVE = c_YES then
         tx_rst_fsm_ready_buf_i <= tx_rst_fsm_ready_i and not gear_to_rm_rst_i;
         
      else
         tx_rst_fsm_ready_buf_i <= tx_rst_fsm_ready_i;
         
      end if;
   end process;
      
      
   rx_rm_ready_i <= rx_almost_ready_i or rx_ready_i;
   
   SERDES_ready <= tx_ready_i and rx_ready_i when rising_edge(clk_125_i);
   led_ok       <= SERDES_ready;
   
   
   -------------------------------------------------      
   -- SCI
   -------------------------------------------------      
   --gives access to serdes config port from slow control and reads word alignment every ~ 40 us
   PROC_SCI_CTRL: process 
      variable cnt : integer range 0 to 4 := 0;
      variable lsm_status_buf : std_logic;
   begin
      wait until rising_edge(CLK);
      SCI_ACK <= '0';
      proper_byte_align_i <= '1';
      
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
               
               if lsm_status_buf = '1' and wa_position(3 downto 0) /= x"0" then
                  proper_byte_align_i <= '0';
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
            wa_position(cnt*4+3 downto cnt*4) <= sci_data_out_i(3 downto 0);
            sci_state       <= GET_WA;    
            cnt             := cnt + 1;
         
      end case;
      
      if (SCI_READ = '1' or SCI_WRITE = '1') and sci_state /= IDLE then
         SCI_NACK <= '1';
      else
         SCI_NACK <= '0';
      end if;
      
      lsm_status_buf := lsm_status_i;
   end process;

   -- RX/TX leds are on as soon as the correspondent pll is locked and data
   -- other than the idle word is transmitted
   PROC_LEDS: process is
   begin
      wait until rising_edge(CLK);

      led_rx <= not rx_cdr_lol;
      led_tx <= not tx_pll_lol;
      
      if (led_timer(20) = '1') or (rx_data_buf_i(17 downto 16) = "10" and rx_data_buf_i(15 downto 0) = x"fcce") then
         led_rx <= '0';
      end if;
      
      if (led_timer(20) = '1') or (tx_data_i(17 downto 16) = "10" and tx_data_i(15 downto 0) = x"fcce") then
         led_tx <= '0';
      end if;

      led_timer <= led_timer + 1 ;
      if led_timer(20) = '1' then
         led_timer <= (others => '0');
         last_led_rx <= led_rx ;
         last_led_tx <= led_tx;
      end if;      
   end process;
   
   PROC_CLK_RESET: process is
      variable counter : unsigned(8 downto 0) := (others => '0');
   begin
      wait until rising_edge(clk_rx_half);
      CLK_RX_RESET_OUT <= '1';
      
      if rx_cdr_lol = '1' then
         counter := (others => '0');
         
      elsif counter(counter'high) = '0' then
         counter := counter + 1;
         
      else
         CLK_RX_RESET_OUT <= '0';
         
      end if;
   end process;
   
-- STAT_OP REGISTER
STAT_OP(8 downto 0) <= rx_data_i when CTRL_OP(8) = '0' else dummy_output_i;

STAT_OP(9)  <= clk_rx_full;
STAT_OP(10) <= clk_125_i;
STAT_OP(11) <= rx_cdr_lol;
STAT_OP(12) <= rx_los_low;
STAT_OP(13) <= lsm_status_i;
STAT_OP(14) <= rx_serdes_rst;
STAT_OP(15) <= rx_pcs_rst;

dummy_output_i(3 downto 0) <= wa_position(3 downto 0);

dummy_output_i(4) <= rx_rst_fsm_ready_i;
dummy_output_i(5) <= tx_pll_lol;
dummy_output_i(6) <= tx_pcs_rst;
dummy_output_i(7) <= rx_serdes_ready_for_gear_i;
dummy_output_i(8) <= serdes_rx_ready_i;


-- STAT_OP(0) <= clk_125_i;
-- STAT_OP(1) <= rst;
-- STAT_OP(2) <= rx_serdes_rst;
-- STAT_OP(3) <= rx_pcs_rst;
-- 
-- STAT_OP(4) <= tx_pcs_rst;
-- STAT_OP(5) <= rst_qd;
-- STAT_OP(6) <= tx_pll_lol;
-- STAT_OP(7) <= rx_cdr_lol;
-- 
-- STAT_OP(8) <= rx_los_low;
-- STAT_OP(9) <= rx_rst_fsm_ready_i;
-- STAT_OP(10) <= proper_byte_align_i;
-- STAT_OP(11) <= gear_to_serder_rst_i;
-- 
-- STAT_OP(12) <= serdes_rx_ready_i;
-- STAT_OP(13) <= wa_position(0);
-- STAT_OP(14) <= wa_position(1);
-- STAT_OP(15) <= wa_position(2);


--    STAT_OP(3) <= rx_valid_char_i;
--    STAT_OP(4) <= rx_see_ready0_i;
--    STAT_OP(5) <= rx_saw_ready1_i;
--    STAT_OP(6) <= rx_almost_ready_i;
--    STAT_OP(7) <= rx_ready_i;
--    STAT_OP(8) <= rx_reset_from_rm_i;
--    STAT_OP(9) <= tx_almost_ready_i;
--    STAT_OP(10) <= tx_ready_i;
--    STAT_OP(11) <= serdes_tx_ready_i;
--    STAT_OP(12) <= proper_byte_align_i;
--    STAT_OP(13) <= proper_word_align_i;
end architecture;
