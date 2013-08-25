library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.trb_net_std.all;

package cbmnet_phy_pkg is
component cbmnet_sfp1 is
   GENERIC (USER_CONFIG_FILE    :  String := "cbmnet_sfp1.txt");
 port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (15 downto 0);
    tx_k_ch0    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch0    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch0    :   in std_logic_vector (1 downto 0);
    rxdata_ch0   :   out std_logic_vector (15 downto 0);
    rx_k_ch0   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch0   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch0   :   out std_logic_vector (1 downto 0);
    rx_serdes_rst_ch0_c    :   in std_logic;
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    --word_align_en_ch0_c    :   in std_logic;
    tx_pcs_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pcs_rst_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
-- CH2 --
-- CH3 --
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    sci_int    :   out std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    rst_qd_c    :   in std_logic;
    refclk2fpga   :   out std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;



  component cbmnet_phy_ecp3 is
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
      CLK_RX_RESET_OUT   : out std_logic := '1';  -- set to 0, ~1us after link is assumed to be stable

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
  end component;
end package cbmnet_phy_pkg;

package body cbmnet_phy_pkg is
end package body;