-- Hardware Dependent CBMNet PHY for the Lattice ECP3

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.trb_net_std.all;

package cbmnet_phy_pkg is
   component cbmnet_phy_ecp3 is
      generic(
         IS_SYNC_SLAVE   : integer := c_NO;       --select slave mode
         IS_SIMULATED    : integer := c_NO;
         INCL_DEBUG_AIDS : integer := c_YES;
         DETERMINISTIC_LATENCY : integer := c_YES -- if selected proper alignment of barrel shifter and word alignment is enforced (link may come up slower)
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
         CLK_RX_RESET_OUT   : out std_logic := '1';  -- set to 0, ~1us after link is recognised to be stable

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
         STAT_OP            : out std_logic_vector (15 downto 0);
         CTRL_OP            : in  std_logic_vector (15 downto 0) := (others => '0');
         DEBUG_OUT          : out std_logic_vector (511 downto 0) := (others => '0')
      );
   end component;
   
-----------------------------------------------------------------------------------------------------------------------
-- INTERNAL
-----------------------------------------------------------------------------------------------------------------------
   component CBMNET_PHY_RX_GEAR is
      generic(
         IS_SYNC_SLAVE   : integer := c_NO       --select slave mode
      );
      port (
      -- SERDES PORT
         CLK_250_IN  : in std_logic;
         PCS_READY_IN: in std_logic;
         SERDES_RESET_OUT : out std_logic;
         DATA_IN     : in  std_logic_vector( 8 downto 0);

      -- RM PORT
         RM_RESET_IN : in std_logic;
         CLK_125_OUT : out std_logic;
         RESET_OUT   : out std_logic;
         DATA_OUT    : out std_logic_vector(17 downto 0);
         
      -- DEBUG
         DEBUG_OUT   : out std_logic_vector(31 downto 0) := (others => '0')
      );
   end component;   
   
   component CBMNET_PHY_TX_GEAR is
      generic (
         IS_SYNC_SLAVE : integer range 0 to 1 := c_YES
      );
      port (
         CLK_250_IN  : in std_logic;
         CLK_125_IN  : in std_logic;
         CLK_125_OUT : out std_logic;
         
         RESET_IN    : in std_logic;

         DATA_IN     : in std_logic_vector(17 downto 0);
         DATA_OUT    : out std_logic_vector(8 downto 0);
         
         TX_READY_OUT: out std_logic;
      
         DEBUG_OUT   : out std_logic_vector(31 downto 0)
      );
   end component;  
  
   COMPONENT cbmnet_sfp1
   PORT(
      hdinp_ch0 : IN std_logic;
      hdinn_ch0 : IN std_logic;
      sci_sel_ch0 : IN std_logic;
      txiclk_ch0 : IN std_logic;
      fpga_rxrefclk_ch0 : IN std_logic;
      txdata_ch0 : IN std_logic_vector(7 downto 0);
      tx_k_ch0 : IN std_logic;
      tx_force_disp_ch0 : IN std_logic;
      tx_disp_sel_ch0 : IN std_logic;
      rx_serdes_rst_ch0_c : IN std_logic;
      sb_felb_ch0_c : IN std_logic;
      sb_felb_rst_ch0_c : IN std_logic;
      tx_pcs_rst_ch0_c : IN std_logic;
      tx_pwrup_ch0_c : IN std_logic;
      rx_pcs_rst_ch0_c : IN std_logic;
      rx_pwrup_ch0_c : IN std_logic;
      tx_div2_mode_ch0_c : IN std_logic;
      rx_div2_mode_ch0_c : IN std_logic;
      sci_wrdata : IN std_logic_vector(7 downto 0);
      sci_addr : IN std_logic_vector(5 downto 0);
      sci_sel_quad : IN std_logic;
      sci_rd : IN std_logic;
      sci_wrn : IN std_logic;
      fpga_txrefclk : IN std_logic;
      tx_serdes_rst_c : IN std_logic;
      rst_qd_c : IN std_logic;
      serdes_rst_qd_c : IN std_logic;          
      hdoutp_ch0 : OUT std_logic;
      hdoutn_ch0 : OUT std_logic;
      rx_full_clk_ch0 : OUT std_logic;
      rx_half_clk_ch0 : OUT std_logic;
      tx_full_clk_ch0 : OUT std_logic;
      tx_half_clk_ch0 : OUT std_logic;
      rxdata_ch0 : OUT std_logic_vector(7 downto 0);
      rx_k_ch0 : OUT std_logic;
      rx_disp_err_ch0 : OUT std_logic;
      rx_cv_err_ch0 : OUT std_logic;
      rx_los_low_ch0_s : OUT std_logic;
      lsm_status_ch0_s : OUT std_logic;
      rx_cdr_lol_ch0_s : OUT std_logic;
      sci_rddata : OUT std_logic_vector(7 downto 0);
      tx_pll_lol_qd_s : OUT std_logic
      );
   END COMPONENT;
   
   component cbmnet_phy_ecp3_rx_reset_fsm is
      generic (
         IS_SIMULATED : integer range 0 to 1 := c_NO
      );   
      port (
         RST_N             : in std_logic;
         RX_REFCLK         : in std_logic;
         TX_PLL_LOL_QD_S   : in std_logic;
         RX_CDR_LOL_CH_S   : in std_logic;
         RX_LOS_LOW_CH_S   : in std_logic;

         RM_RESET_IN          : in std_logic := '0';
         PROPER_BYTE_ALIGN_IN : in std_logic := '1';
         PROPER_WORD_ALIGN_IN : in std_logic := '1';

         RX_SERDES_RST_CH_C: out std_logic;
         RX_PCS_RST_CH_C   : out std_logic;
         STATE_OUT         : out std_logic_vector(3 downto 0)
      );
   end component;
   
   component cbmnet_phy_ecp3_tx_reset_fsm is
      generic (
         IS_SIMULATED : integer range 0 to 1 := c_NO
      );
      port (
         RST_N           : in std_logic;
         TX_REFCLK       : in std_logic;   
         TX_PLL_LOL_QD_S : in std_logic;
         RST_QD_C        : out std_logic;
         TX_PCS_RST_CH_C : out std_logic;
         STATE_OUT       : out std_logic_vector(3 downto 0)

      );
   end component;   
   
   function EBTB_D_ENCODE(
      constant x : integer range 0 to 31;
      constant y : integer range 0 to 7
   ) return std_logic_vector;
   
end package cbmnet_phy_pkg;

package body cbmnet_phy_pkg is
   function EBTB_D_ENCODE(constant x : integer range 0 to 31; constant y : integer range 0 to 7) return std_logic_vector
   is begin
      return STD_LOGIC_VECTOR(TO_UNSIGNED(x, 5)) & STD_LOGIC_VECTOR(TO_UNSIGNED(y, 3));
   end EBTB_D_ENCODE;
   
end package body;