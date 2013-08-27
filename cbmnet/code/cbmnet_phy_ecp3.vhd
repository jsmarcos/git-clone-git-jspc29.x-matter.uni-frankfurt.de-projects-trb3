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
      CTRL_DEBUG         : in  std_logic_vector (63 downto 0) := (others => '0')
   );
end entity;

architecture cbmnet_phy_ecp3_arch of cbmnet_phy_ecp3 is
   -- Placer Directives
   attribute HGROUP : string;
   -- for whole architecture
   attribute HGROUP of cbmnet_phy_ecp3_arch : architecture  is "cbmnet_phy_group";
   attribute syn_sharing : string;
   attribute syn_sharing of cbmnet_phy_ecp3_arch : architecture is "off";

   signal clk_125_i         : std_logic;
   signal clk_125_internal  : std_logic;
   signal clk_rx_full       : std_logic;
   signal clk_rx_half       : std_logic;
   signal clk_tx_full       : std_logic;
   signal clk_tx_half       : std_logic;

   signal tx_data_i         : std_logic_vector(17 downto 0);
   signal rx_data_i         : std_logic_vector(17 downto 0);
   
   signal rx_error          : std_logic_vector(1 downto 0);

   signal rst_n             : std_logic;
   signal rst               : std_logic;
   signal rx_serdes_rst     : std_logic;
   signal tx_serdes_rst     : std_logic;
   signal tx_pcs_rst        : std_logic;
   signal rx_pcs_rst        : std_logic;
   signal rst_qd            : std_logic;
   signal serdes_rst_qd     : std_logic;
   signal sd_los_i          : std_logic;

   signal rx_los_low        : std_logic;
   signal rx_cdr_lol        : std_logic;
   signal tx_pll_lol        : std_logic;

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
   signal wa_position_rx     : std_logic_vector(15 downto 0) := x"FFFF";
   signal request_retr_i     : std_logic;
   signal start_retr_i       : std_logic;
   signal request_retr_position_i  : std_logic_vector(7 downto 0);
   signal start_retr_position_i    : std_logic_vector(7 downto 0);
   signal send_link_reset_i  : std_logic := '0';
   signal got_link_ready_i   : std_logic;

   signal stat_rx_control_i  : std_logic_vector(31 downto 0);
   signal stat_tx_control_i  : std_logic_vector(31 downto 0);
   signal debug_rx_control_i : std_logic_vector(31 downto 0);
   signal debug_tx_control_i : std_logic_vector(31 downto 0);
   signal rx_fsm_state       : std_logic_vector(3 downto 0);
   signal tx_fsm_state       : std_logic_vector(3 downto 0);
   signal debug_reg          : std_logic_vector(63 downto 0);

   type sci_ctrl is (IDLE, SCTRL, SCTRL_WAIT, SCTRL_WAIT2, SCTRL_FINISH, GET_WA, GET_WA_WAIT, GET_WA_WAIT2, GET_WA_FINISH);
   signal sci_state         : sci_ctrl;
   signal sci_timer         : unsigned(12 downto 0) := (others => '0');
   signal start_timer       : unsigned(18 downto 0) := (others => '0');

   signal led_ok                 : std_logic;
   signal led_tx, last_led_tx    : std_logic;
   signal led_rx, last_led_rx    : std_logic;
   signal timer    : unsigned(20 downto 0);

   
-- RX READY MODULE
   signal rx_ready_i : std_logic;
   signal rx_almost_ready_i : std_logic;
   signal rx_rm_ready_i : std_logic;
   signal rx_see_ready0_i : std_logic;
   signal rx_saw_ready1_i : std_logic;
   signal rx_valid_char_i : std_logic;
   signal link_init_rx_reset_i : std_logic;

   
-- TX READY MODULE   
   signal tx_ready_i : std_logic;
   signal tx_almost_ready_i : std_logic;
begin
   clk_125_internal <= CLK;
   CLK_RX_HALF_OUT <= clk_rx_half;
   CLK_RX_FULL_OUT <= clk_rx_full;

   SD_TXDIS_OUT <= '0';

   rst_n <= not (CLEAR or sd_los_i);
   rst   <=     (CLEAR or sd_los_i);


   gen_slave_clock : if IS_SYNC_SLAVE = c_YES generate
      clk_125_i        <= clk_rx_full;
   end generate;

   gen_master_clock : if IS_SYNC_SLAVE = c_NO generate
      clk_125_i        <= clk_125_internal;
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
      rxiclk_ch0           => clk_125_i,
      txiclk_ch0           => clk_125_i,
      rx_full_clk_ch0      => clk_rx_full,
      rx_half_clk_ch0      => clk_rx_half,
      tx_full_clk_ch0      => clk_tx_full,
      tx_half_clk_ch0      => clk_tx_half,
      fpga_rxrefclk_ch0    => clk_125_internal,

   -- RESETS
      fpga_txrefclk        => clk_125_i,
      rst_qd_c             => rst_qd,
      serdes_rst_qd_c      => serdes_rst_qd,
      tx_serdes_rst_c      => tx_serdes_rst,
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
      rxdata_ch0           => rx_data_i(15 downto 0),
      rx_k_ch0             => rx_data_i(17 downto 16),

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
      
   -------------------------------------------------      
   -- Reset FSM & Link states
   -------------------------------------------------      
   THE_RX_FSM : rx_reset_fsm
   port map(
      RST_N               => rst_n,
      RX_REFCLK           => clk_125_i,
      TX_PLL_LOL_QD_S     => tx_pll_lol,
      RX_SERDES_RST_CH_C  => rx_serdes_rst,
      RX_CDR_LOL_CH_S     => rx_cdr_lol,
      RX_LOS_LOW_CH_S     => rx_los_low,
      RX_PCS_RST_CH_C     => rx_pcs_rst,
      WA_POSITION         => wa_position_rx(3 downto 0),
      STATE_OUT           => rx_fsm_state
   );
      
   THE_TX_FSM : tx_reset_fsm
   port map(
      RST_N           => rst_n,
      TX_REFCLK       => clk_125_internal,
      TX_PLL_LOL_QD_S => tx_pll_lol,
      RST_QD_C        => rst_qd,
      TX_PCS_RST_CH_C => tx_pcs_rst,
      STATE_OUT       => tx_fsm_state
   );

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
      
   -- Master does not do bit-locking  
   SYNC_WA_POSITION : process begin
      wait until rising_edge(clk_125_i);
      if IS_SYNC_SLAVE = 1 then
         wa_position_rx <= wa_position;
      else
         wa_position_rx <= x"0000";
      end if;
   end process;

   -------------------------------------------------      
   -- CBMNet Link Init
   -------------------------------------------------      
   THE_RX_READY: gtp_rx_ready_module 
   generic map (INCL_8B10B_DEC => 0)
   port map (
      clk => clk_125_i,
      res_n => rst_n,
      ready_MGT2RM => '1',
      
      rxdata_in(17 downto 0) => rx_data_i,
      rxdata_in(19 downto 18) => "00",
      tx_ready => tx_ready_i,
      tx_almost_ready => tx_almost_ready_i,

      ready_RM2LP => rx_ready_i,

      rxdata_out => PHY_RXDATA_OUT,
      charisk_out => PHY_RXDATA_K_OUT,
      
      almost_ready_OUT => rx_almost_ready_i,
      see_ready0 => rx_see_ready0_i,
      saw_ready1 => rx_saw_ready1_i,
      valid_char => rx_valid_char_i,
      
      reset_rx => link_init_rx_reset_i
   );

   THE_TX_READY: gtp_tx_ready_module
   port map (
      clk => clk_125_i,                   -- :  in std_logic;
      res_n => rst_n,                     -- :  in std_logic;
      restart_link => '0',                -- :  in std_logic;
      ready_MGT2RM => '1',                -- :  in std_logic;
      txdata_in => PHY_TXDATA_IN ,        -- :  in std_logic_vector((DATAWIDTH-1) downto 0);
      txcharisk_in => PHY_TXDATA_K_IN,    -- :  in std_logic_vector((WORDS-1) downto 0);

      see_ready0 => rx_see_ready0_i,      -- :  in std_logic;
      saw_ready1 => rx_see_ready0_i,      -- :  in std_logic;
      valid_char => rx_valid_char_i,      -- :  in std_logic;
      rx_rm_ready => rx_rm_ready_i,       -- :  in std_logic;

      ready_RM2LP => tx_ready_i,          -- :  out std_logic;
      txdata_out => tx_data_i,            -- :  out std_logic_vector((WORDS*9)-1 downto 0);
      almost_ready => tx_almost_ready_i,  -- :  out std_logic;
      gt11_reinit => open                 -- :  out std_logic   
   );
   
   rx_rm_ready_i <= rx_almost_ready_i or rx_ready_i;
   
   SERDES_ready <= tx_ready_i and rx_ready_i when rising_edge(clk_125_i);
   led_ok       <= SERDES_ready;
   
   -------------------------------------------------      
   -- SCI
   -------------------------------------------------      
   --gives access to serdes config port from slow control and reads word alignment every ~ 40 us
   PROC_SCI_CTRL: process 
      variable cnt : integer range 0 to 4 := 0;
   begin
   wait until rising_edge(CLK);
   SCI_ACK <= '0';
   case sci_state is
      when IDLE =>
         sci_ch_i        <= x"0";
         sci_qd_i        <= '0';
         sci_reg_i       <= '0';
         sci_read_i      <= '0';
         sci_write_i     <= '0';
         sci_timer       <= sci_timer + 1;
         if SCI_READ = '1' or SCI_WRITE = '1' then
         sci_ch_i(0)   <= not SCI_ADDR(6) and not SCI_ADDR(7) and not SCI_ADDR(8);
         sci_ch_i(1)   <=     SCI_ADDR(6) and not SCI_ADDR(7) and not SCI_ADDR(8);
         sci_ch_i(2)   <= not SCI_ADDR(6) and     SCI_ADDR(7) and not SCI_ADDR(8);
         sci_ch_i(3)   <=     SCI_ADDR(6) and     SCI_ADDR(7) and not SCI_ADDR(8);
         sci_qd_i      <= not SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8);
         sci_reg_i     <=     SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8);
         sci_addr_i    <= SCI_ADDR;
         sci_data_in_i <= SCI_DATA_IN;
         sci_read_i    <= SCI_READ  and not (SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8));
         sci_write_i   <= SCI_WRITE and not (SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8));
         sci_state     <= SCTRL;
         elsif sci_timer(sci_timer'left) = '1' then
         sci_timer     <= (others => '0');
         sci_state     <= GET_WA;
         end if;      
      when SCTRL =>
         if sci_reg_i = '1' then
         SCI_DATA_OUT  <= debug_reg(8*(to_integer(unsigned(SCI_ADDR(3 downto 0))))+7 downto 8*(to_integer(unsigned(SCI_ADDR(3 downto 0)))));
         SCI_ACK       <= '1';
         sci_write_i   <= '0';
         sci_read_i    <= '0';
         sci_state     <= IDLE;
         else
         sci_state     <= SCTRL_WAIT;
         end if;
      when SCTRL_WAIT   =>
         sci_state       <= SCTRL_WAIT2;
      when SCTRL_WAIT2  =>
         sci_state       <= SCTRL_FINISH;
      when SCTRL_FINISH =>
         SCI_DATA_OUT    <= sci_data_out_i;
         SCI_ACK         <= '1';
         sci_write_i     <= '0';
         sci_read_i      <= '0';
         sci_state       <= IDLE;
      
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
         wa_position(cnt*4+3 downto cnt*4) <= sci_data_out_i(3 downto 0);
         sci_state       <= GET_WA;    
         cnt             := cnt + 1;
   end case;
   
   if (SCI_READ = '1' or SCI_WRITE = '1') and sci_state /= IDLE then
      SCI_NACK <= '1';
   else
      SCI_NACK <= '0';
   end if;
   
   end process;

   -- RX/TX leds are on as soon as the correspondent pll is locked and data
   -- other than the idle word is transmitted
   PROC_RX_TX_LEDS: process is
   begin
      wait until rising_edge(CLK);

      led_rx <= not rx_cdr_lol;
      led_tx <= not tx_pll_lol;
      
      if (timer(20) = '1') or (rx_data_i(17 downto 16) = "10" and rx_data_i(15 downto 0) = x"fcce") then
         led_rx <= '0';
      end if;
      
      if (timer(20) = '1') or (tx_data_i(17 downto 16) = "10" and tx_data_i(15 downto 0) = x"fcce") then
         led_tx <= '0';
      end if;
   end process;
   
   ROC_TIMER : process begin
   wait until rising_edge(CLK);
   timer <= timer + 1 ;
   if timer(20) = '1' then
      timer <= (others => '0');
      last_led_rx <= led_rx ;
      last_led_tx <= led_tx;
   end if;
   end process;

   -------------------------------------------------      
   -- Debug Registers
   -------------------------------------------------            
   debug_reg(2 downto 0)   <= rx_fsm_state(2 downto 0);
   debug_reg(3)            <= rx_serdes_rst;
   debug_reg(4)            <= CLEAR;
   debug_reg(5)            <= '1';
   debug_reg(6)            <= rx_los_low;
   debug_reg(7)            <= rx_cdr_lol;

   debug_reg(8)            <= RESET;
   debug_reg(9)            <= tx_pll_lol;
   debug_reg(10)           <= '1';
   debug_reg(11)           <= CTRL_OP(15);
   debug_reg(12)           <= '0';
   debug_reg(13)           <= send_link_reset_i;
   debug_reg(14)           <= sd_los_i;
   debug_reg(15)           <= rx_pcs_rst;
   -- debug_reg(31 downto 24) <= tx_data;

   debug_reg(16)           <= '0';
   debug_reg(17)           <= '1';
   debug_reg(18)           <= RESET;
   debug_reg(19)           <= CLEAR;
   debug_reg(31 downto 20) <= debug_rx_control_i(4) & debug_rx_control_i(2 downto 0) & debug_rx_control_i(15 downto 8);

   debug_reg(35 downto 32) <= wa_position(3 downto 0);
   debug_reg(36)           <= debug_tx_control_i(6);
   debug_reg(39 downto 37) <= "000";
   debug_reg(63 downto 40) <= debug_rx_control_i(23 downto 0);

         
   STAT_DEBUG <= debug_reg;

   sd_los_i <= SD_LOS_IN when rising_edge(CLK);

   
-- STAT_OP REGISTER   
   STAT_OP(0) <= led_ok;
   STAT_OP(1) <= led_tx or last_led_tx;
   STAT_OP(2) <= led_rx or last_led_rx;
   STAT_OP(3) <= send_link_reset_i when rising_edge(CLK);
   STAT_OP( 7 downto 4) <= tx_fsm_state;
   STAT_OP(11 downto 8) <= rx_fsm_state;
   STAT_OP(15 downto 12) <= (others => '0');
end architecture;
