library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.trb_net_std.all;

package trb3_components is

  type unsigned_array_31 is array (integer range <>) of unsigned(30 downto 0);
  type unsigned_array_8 is array (integer range <>) of unsigned(7 downto 0);
  type unsigned_array_5 is array (integer range <>) of unsigned(4 downto 0);

  
component dcs
-- synthesis translate_off
  generic (
    DCSMODE : string := "POS"
    );
-- synthesis translate_on
  port (
    CLK0   :IN std_logic ;
    CLK1   :IN std_logic ;
    SEL    :IN std_logic ;
    DCSOUT :OUT std_logic
    ) ;
end component;

  
  component oddr is
    port (
      clk    : in  std_logic;
      clkout : out std_logic;
      da     : in  std_logic_vector(0 downto 0);
      db     : in  std_logic_vector(0 downto 0);
      q      : out std_logic_vector(0 downto 0));
  end component;

  component pll_in125_out125
    port (
      CLK   : in  std_logic;
      CLKOP : out std_logic;            --125 MHz
      CLKOK : out std_logic;            --125 MHz, bypass
      LOCK  : out std_logic
      );
  end component;

  component pll_in125_out20 is
    port (
      CLK   : in  std_logic;
      CLKOP : out std_logic;            -- 20 MHz
      CLKOK : out std_logic;            -- 125 MHz, bypass
      LOCK  : out std_logic);
  end component pll_in125_out20;

  component pll_in200_out100 is
    port (
      CLK   : in  std_logic;
      RESET : in  std_logic;
      CLKOP : out std_logic;            -- 100 MHz
      CLKOK : out std_logic;            -- 200 MHz, bypass
      LOCK  : out std_logic);
  end component pll_in200_out100;

  component adc_ad9222
    generic(
      CHANNELS   : integer range 4 to 4   := 4;
      DEVICES    : integer range 2 to 2   := 2;
      RESOLUTION : integer range 12 to 12 := 12
      );
    port(
      CLK        : in  std_logic;
      CLK_ADCREF : in  std_logic;
      CLK_ADCDAT : in  std_logic;
      RESTART_IN : in  std_logic;
      ADCCLK_OUT : out std_logic;
      ADC_DATA   : in  std_logic_vector(DEVICES*CHANNELS-1 downto 0);
      ADC_DCO    : in  std_logic_vector(DEVICES-1 downto 0);
      ADC_FCO    : in  std_logic_vector(DEVICES-1 downto 0);

      DATA_OUT       : out std_logic_vector(DEVICES*CHANNELS*RESOLUTION-1 downto 0);
      FCO_OUT        : out std_logic_vector(DEVICES*RESOLUTION-1 downto 0);
      DATA_VALID_OUT : out std_logic_vector(DEVICES-1 downto 0);
      DEBUG          : out std_logic_vector(31 downto 0)

      );
  end component;

  component fifo_32x512
    port (
      Data  : in  std_logic_vector(31 downto 0);
      Clock : in  std_logic;
      WrEn  : in  std_logic;
      RdEn  : in  std_logic;
      Reset : in  std_logic;
      Q     : out std_logic_vector(31 downto 0);
      Empty : out std_logic;
      Full  : out std_logic);
  end component;

  component dqsinput
    port (
      clk_0        : in  std_logic;
      clk_1        : in  std_logic;
      clkdiv_reset : in  std_logic;
      eclk         : in  std_logic;
      reset_0      : in  std_logic;
      reset_1      : in  std_logic;
      sclk         : out std_logic;
      datain_0     : in  std_logic_vector(4 downto 0);
      datain_1     : in  std_logic_vector(4 downto 0);
      q_0          : out std_logic_vector(19 downto 0);
      q_1          : out std_logic_vector(19 downto 0)
      );
  end component;

  component fifo_cdt_200
    port (
      Data    : in  std_logic_vector(59 downto 0);
      WrClock : in  std_logic;
      RdClock : in  std_logic;
      WrEn    : in  std_logic;
      RdEn    : in  std_logic;
      Reset   : in  std_logic;
      RPReset : in  std_logic;
      Q       : out std_logic_vector(59 downto 0);
      Empty   : out std_logic;
      Full    : out std_logic);
  end component;


  component med_ecp3_sfp_sync is
    generic(
      SERDES_NUM    : integer range 0 to 3 := 0;
--     MASTER_CLOCK_SWITCH : integer := c_NO;   --just for debugging, should be NO
      IS_SYNC_SLAVE : integer              := 0  --select slave mode
      );
    port(
      CLK                : in  std_logic;  -- _internal_ 200 MHz reference clock
      SYSCLK             : in  std_logic;  -- 100 MHz main clock net, synchronous to RX clock
      RESET              : in  std_logic;  -- synchronous reset
      CLEAR              : in  std_logic;  -- asynchronous reset
      --Internal Connection TX
      MED_DATA_IN        : in  std_logic_vector(c_DATA_WIDTH-1 downto 0);
      MED_PACKET_NUM_IN  : in  std_logic_vector(c_NUM_WIDTH-1 downto 0);
      MED_DATAREADY_IN   : in  std_logic;
      MED_READ_OUT       : out std_logic                                 := '0';
      --Internal Connection RX
      MED_DATA_OUT       : out std_logic_vector(c_DATA_WIDTH-1 downto 0) := (others => '0');
      MED_PACKET_NUM_OUT : out std_logic_vector(c_NUM_WIDTH-1 downto 0)  := (others => '0');
      MED_DATAREADY_OUT  : out std_logic                                 := '0';
      MED_READ_IN        : in  std_logic;
      CLK_RX_HALF_OUT    : out std_logic                                 := '0';  --received 100 MHz
      CLK_RX_FULL_OUT    : out std_logic                                 := '0';  --received 200 MHz

      --Sync operation
      RX_DLM      : out std_logic                    := '0';
      RX_DLM_WORD : out std_logic_vector(7 downto 0) := x"00";
      TX_DLM      : in  std_logic                    := '0';
      TX_DLM_WORD : in  std_logic_vector(7 downto 0) := x"00";

      --SFP Connection
      SD_RXD_P_IN    : in  std_logic;
      SD_RXD_N_IN    : in  std_logic;
      SD_TXD_P_OUT   : out std_logic;
      SD_TXD_N_OUT   : out std_logic;
      SD_REFCLK_P_IN : in  std_logic;   --not used
      SD_REFCLK_N_IN : in  std_logic;   --not used
      SD_PRSNT_N_IN  : in  std_logic;  -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
      SD_LOS_IN      : in  std_logic;  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
      SD_TXDIS_OUT   : out std_logic                      := '0';  -- SFP disable
      --Control Interface
      SCI_DATA_IN    : in  std_logic_vector(7 downto 0)   := (others => '0');
      SCI_DATA_OUT   : out std_logic_vector(7 downto 0)   := (others => '0');
      SCI_ADDR       : in  std_logic_vector(8 downto 0)   := (others => '0');
      SCI_READ       : in  std_logic                      := '0';
      SCI_WRITE      : in  std_logic                      := '0';
      SCI_ACK        : out std_logic                      := '0';
      SCI_NACK       : out std_logic                      := '0';
      -- Status and control port
      STAT_OP        : out std_logic_vector (15 downto 0);
      CTRL_OP        : in  std_logic_vector (15 downto 0) := (others => '0');
      STAT_DEBUG     : out std_logic_vector (63 downto 0);
      CTRL_DEBUG     : in  std_logic_vector (63 downto 0) := (others => '0')
      );
  end component;

  component SFP_DDM is
    port (
      CLK100       : in    std_logic;
      SLOW_CTRL_IN : in    std_logic_vector(31 downto 0);
      DATA_OUT     : out   std_logic_vector(3*32-1 downto 0);
      SCL_EXT      : out   std_logic_vector(8 downto 1);
      SDA_EXT      : inout std_logic_vector(8 downto 1));
  end component SFP_DDM;

  component input_to_trigger_logic is
    generic(
      INPUTS  : integer range 1 to 32 := 24;
      OUTPUTS : integer range 1 to 16 := 4
      );
    port(
      CLK : in std_logic;

      INPUT  : in  std_logic_vector(INPUTS-1 downto 0);
      OUTPUT : out std_logic_vector(OUTPUTS-1 downto 0);

      DATA_IN  : in  std_logic_vector(31 downto 0) := (others => '0');
      DATA_OUT : out std_logic_vector(31 downto 0);
      WRITE_IN : in  std_logic                     := '0';
      READ_IN  : in  std_logic                     := '0';
      ACK_OUT  : out std_logic;
      NACK_OUT : out std_logic;
      ADDR_IN  : in  std_logic_vector(15 downto 0) := (others => '0')

      );
  end component;

  component input_statistics is
    generic (
      INPUTS : integer range 1 to 32);
    port (
      CLK      : in  std_logic;
      INPUT    : in  std_logic_vector(INPUTS-1 downto 0);
      DATA_IN  : in  std_logic_vector(31 downto 0) := (others => '0');
      DATA_OUT : out std_logic_vector(31 downto 0);
      WRITE_IN : in  std_logic                     := '0';
      READ_IN  : in  std_logic                     := '0';
      ACK_OUT  : out std_logic;
      NACK_OUT : out std_logic;
      ADDR_IN  : in  std_logic_vector(15 downto 0) := (others => '0'));
  end component input_statistics;


  component serdes_full_ctc is
    generic (USER_CONFIG_FILE : string := "serdes_full_ctc.txt");
    port (
------------------
-- CH0 --
      hdinp_ch0, hdinn_ch0   : in  std_logic;
      hdoutp_ch0, hdoutn_ch0 : out std_logic;
      sci_sel_ch0            : in  std_logic;
      rxiclk_ch0             : in  std_logic;
      txiclk_ch0             : in  std_logic;
      rx_full_clk_ch0        : out std_logic;
      rx_half_clk_ch0        : out std_logic;
      tx_full_clk_ch0        : out std_logic;
      tx_half_clk_ch0        : out std_logic;
      fpga_rxrefclk_ch0      : in  std_logic;
      txdata_ch0             : in  std_logic_vector (15 downto 0);
      tx_k_ch0               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch0      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch0        : in  std_logic_vector (1 downto 0);
      rxdata_ch0             : out std_logic_vector (15 downto 0);
      rx_k_ch0               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch0        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch0          : out std_logic_vector (1 downto 0);
      sb_felb_ch0_c          : in  std_logic;
      sb_felb_rst_ch0_c      : in  std_logic;
      tx_pwrup_ch0_c         : in  std_logic;
      rx_pwrup_ch0_c         : in  std_logic;
      rx_los_low_ch0_s       : out std_logic;
      lsm_status_ch0_s       : out std_logic;
      ctc_urun_ch0_s         : out std_logic;
      ctc_orun_ch0_s         : out std_logic;
      ctc_ins_ch0_s          : out std_logic;
      ctc_del_ch0_s          : out std_logic;
      rx_cdr_lol_ch0_s       : out std_logic;
      tx_div2_mode_ch0_c     : in  std_logic;
      rx_div2_mode_ch0_c     : in  std_logic;
-- CH1 --
      hdinp_ch1, hdinn_ch1   : in  std_logic;
      hdoutp_ch1, hdoutn_ch1 : out std_logic;
      sci_sel_ch1            : in  std_logic;
      rxiclk_ch1             : in  std_logic;
      txiclk_ch1             : in  std_logic;
      rx_full_clk_ch1        : out std_logic;
      rx_half_clk_ch1        : out std_logic;
      tx_full_clk_ch1        : out std_logic;
      tx_half_clk_ch1        : out std_logic;
      fpga_rxrefclk_ch1      : in  std_logic;
      txdata_ch1             : in  std_logic_vector (15 downto 0);
      tx_k_ch1               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch1      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch1        : in  std_logic_vector (1 downto 0);
      rxdata_ch1             : out std_logic_vector (15 downto 0);
      rx_k_ch1               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch1        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch1          : out std_logic_vector (1 downto 0);
      sb_felb_ch1_c          : in  std_logic;
      sb_felb_rst_ch1_c      : in  std_logic;
      tx_pwrup_ch1_c         : in  std_logic;
      rx_pwrup_ch1_c         : in  std_logic;
      rx_los_low_ch1_s       : out std_logic;
      lsm_status_ch1_s       : out std_logic;
      ctc_urun_ch1_s         : out std_logic;
      ctc_orun_ch1_s         : out std_logic;
      ctc_ins_ch1_s          : out std_logic;
      ctc_del_ch1_s          : out std_logic;
      rx_cdr_lol_ch1_s       : out std_logic;
      tx_div2_mode_ch1_c     : in  std_logic;
      rx_div2_mode_ch1_c     : in  std_logic;
-- CH2 --
      hdinp_ch2, hdinn_ch2   : in  std_logic;
      hdoutp_ch2, hdoutn_ch2 : out std_logic;
      sci_sel_ch2            : in  std_logic;
      rxiclk_ch2             : in  std_logic;
      txiclk_ch2             : in  std_logic;
      rx_full_clk_ch2        : out std_logic;
      rx_half_clk_ch2        : out std_logic;
      tx_full_clk_ch2        : out std_logic;
      tx_half_clk_ch2        : out std_logic;
      fpga_rxrefclk_ch2      : in  std_logic;
      txdata_ch2             : in  std_logic_vector (15 downto 0);
      tx_k_ch2               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch2      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch2        : in  std_logic_vector (1 downto 0);
      rxdata_ch2             : out std_logic_vector (15 downto 0);
      rx_k_ch2               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch2        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch2          : out std_logic_vector (1 downto 0);
      sb_felb_ch2_c          : in  std_logic;
      sb_felb_rst_ch2_c      : in  std_logic;
      tx_pwrup_ch2_c         : in  std_logic;
      rx_pwrup_ch2_c         : in  std_logic;
      rx_los_low_ch2_s       : out std_logic;
      lsm_status_ch2_s       : out std_logic;
      ctc_urun_ch2_s         : out std_logic;
      ctc_orun_ch2_s         : out std_logic;
      ctc_ins_ch2_s          : out std_logic;
      ctc_del_ch2_s          : out std_logic;
      rx_cdr_lol_ch2_s       : out std_logic;
      tx_div2_mode_ch2_c     : in  std_logic;
      rx_div2_mode_ch2_c     : in  std_logic;
-- CH3 --
      hdinp_ch3, hdinn_ch3   : in  std_logic;
      hdoutp_ch3, hdoutn_ch3 : out std_logic;
      sci_sel_ch3            : in  std_logic;
      rxiclk_ch3             : in  std_logic;
      txiclk_ch3             : in  std_logic;
      rx_full_clk_ch3        : out std_logic;
      rx_half_clk_ch3        : out std_logic;
      tx_full_clk_ch3        : out std_logic;
      tx_half_clk_ch3        : out std_logic;
      fpga_rxrefclk_ch3      : in  std_logic;
      txdata_ch3             : in  std_logic_vector (15 downto 0);
      tx_k_ch3               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch3      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch3        : in  std_logic_vector (1 downto 0);
      rxdata_ch3             : out std_logic_vector (15 downto 0);
      rx_k_ch3               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch3        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch3          : out std_logic_vector (1 downto 0);
      sb_felb_ch3_c          : in  std_logic;
      sb_felb_rst_ch3_c      : in  std_logic;
      tx_pwrup_ch3_c         : in  std_logic;
      rx_pwrup_ch3_c         : in  std_logic;
      rx_los_low_ch3_s       : out std_logic;
      lsm_status_ch3_s       : out std_logic;
      ctc_urun_ch3_s         : out std_logic;
      ctc_orun_ch3_s         : out std_logic;
      ctc_ins_ch3_s          : out std_logic;
      ctc_del_ch3_s          : out std_logic;
      rx_cdr_lol_ch3_s       : out std_logic;
      tx_div2_mode_ch3_c     : in  std_logic;
      rx_div2_mode_ch3_c     : in  std_logic;
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      tx_sync_qd_c           : in  std_logic;
      refclk2fpga            : out std_logic;
      rst_n                  : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;

  component serdes_full_noctc is
    generic (USER_CONFIG_FILE : string := "serdes_full_noctc.txt");
    port (
------------------
-- CH0 --
      hdinp_ch0, hdinn_ch0   : in  std_logic;
      hdoutp_ch0, hdoutn_ch0 : out std_logic;
      sci_sel_ch0            : in  std_logic;
      rxiclk_ch0             : in  std_logic;
      txiclk_ch0             : in  std_logic;
      rx_full_clk_ch0        : out std_logic;
      rx_half_clk_ch0        : out std_logic;
      tx_full_clk_ch0        : out std_logic;
      tx_half_clk_ch0        : out std_logic;
      fpga_rxrefclk_ch0      : in  std_logic;
      txdata_ch0             : in  std_logic_vector (15 downto 0);
      tx_k_ch0               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch0      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch0        : in  std_logic_vector (1 downto 0);
      rxdata_ch0             : out std_logic_vector (15 downto 0);
      rx_k_ch0               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch0        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch0          : out std_logic_vector (1 downto 0);
      sb_felb_ch0_c          : in  std_logic;
      sb_felb_rst_ch0_c      : in  std_logic;
      tx_pwrup_ch0_c         : in  std_logic;
      rx_pwrup_ch0_c         : in  std_logic;
      rx_los_low_ch0_s       : out std_logic;
      lsm_status_ch0_s       : out std_logic;
      rx_cdr_lol_ch0_s       : out std_logic;
      tx_div2_mode_ch0_c     : in  std_logic;
      rx_div2_mode_ch0_c     : in  std_logic;
-- CH1 --
      hdinp_ch1, hdinn_ch1   : in  std_logic;
      hdoutp_ch1, hdoutn_ch1 : out std_logic;
      sci_sel_ch1            : in  std_logic;
      rxiclk_ch1             : in  std_logic;
      txiclk_ch1             : in  std_logic;
      rx_full_clk_ch1        : out std_logic;
      rx_half_clk_ch1        : out std_logic;
      tx_full_clk_ch1        : out std_logic;
      tx_half_clk_ch1        : out std_logic;
      fpga_rxrefclk_ch1      : in  std_logic;
      txdata_ch1             : in  std_logic_vector (15 downto 0);
      tx_k_ch1               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch1      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch1        : in  std_logic_vector (1 downto 0);
      rxdata_ch1             : out std_logic_vector (15 downto 0);
      rx_k_ch1               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch1        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch1          : out std_logic_vector (1 downto 0);
      sb_felb_ch1_c          : in  std_logic;
      sb_felb_rst_ch1_c      : in  std_logic;
      tx_pwrup_ch1_c         : in  std_logic;
      rx_pwrup_ch1_c         : in  std_logic;
      rx_los_low_ch1_s       : out std_logic;
      lsm_status_ch1_s       : out std_logic;
      rx_cdr_lol_ch1_s       : out std_logic;
      tx_div2_mode_ch1_c     : in  std_logic;
      rx_div2_mode_ch1_c     : in  std_logic;
-- CH2 --
      hdinp_ch2, hdinn_ch2   : in  std_logic;
      hdoutp_ch2, hdoutn_ch2 : out std_logic;
      sci_sel_ch2            : in  std_logic;
      rxiclk_ch2             : in  std_logic;
      txiclk_ch2             : in  std_logic;
      rx_full_clk_ch2        : out std_logic;
      rx_half_clk_ch2        : out std_logic;
      tx_full_clk_ch2        : out std_logic;
      tx_half_clk_ch2        : out std_logic;
      fpga_rxrefclk_ch2      : in  std_logic;
      txdata_ch2             : in  std_logic_vector (15 downto 0);
      tx_k_ch2               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch2      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch2        : in  std_logic_vector (1 downto 0);
      rxdata_ch2             : out std_logic_vector (15 downto 0);
      rx_k_ch2               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch2        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch2          : out std_logic_vector (1 downto 0);
      sb_felb_ch2_c          : in  std_logic;
      sb_felb_rst_ch2_c      : in  std_logic;
      tx_pwrup_ch2_c         : in  std_logic;
      rx_pwrup_ch2_c         : in  std_logic;
      rx_los_low_ch2_s       : out std_logic;
      lsm_status_ch2_s       : out std_logic;
      rx_cdr_lol_ch2_s       : out std_logic;
      tx_div2_mode_ch2_c     : in  std_logic;
      rx_div2_mode_ch2_c     : in  std_logic;
-- CH3 --
      hdinp_ch3, hdinn_ch3   : in  std_logic;
      hdoutp_ch3, hdoutn_ch3 : out std_logic;
      sci_sel_ch3            : in  std_logic;
      rxiclk_ch3             : in  std_logic;
      txiclk_ch3             : in  std_logic;
      rx_full_clk_ch3        : out std_logic;
      rx_half_clk_ch3        : out std_logic;
      tx_full_clk_ch3        : out std_logic;
      tx_half_clk_ch3        : out std_logic;
      fpga_rxrefclk_ch3      : in  std_logic;
      txdata_ch3             : in  std_logic_vector (15 downto 0);
      tx_k_ch3               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch3      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch3        : in  std_logic_vector (1 downto 0);
      rxdata_ch3             : out std_logic_vector (15 downto 0);
      rx_k_ch3               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch3        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch3          : out std_logic_vector (1 downto 0);
      sb_felb_ch3_c          : in  std_logic;
      sb_felb_rst_ch3_c      : in  std_logic;
      tx_pwrup_ch3_c         : in  std_logic;
      rx_pwrup_ch3_c         : in  std_logic;
      rx_los_low_ch3_s       : out std_logic;
      lsm_status_ch3_s       : out std_logic;
      rx_cdr_lol_ch3_s       : out std_logic;
      tx_div2_mode_ch3_c     : in  std_logic;
      rx_div2_mode_ch3_c     : in  std_logic;
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      tx_sync_qd_c           : in  std_logic;
      refclk2fpga            : out std_logic;
      rst_n                  : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;


  component serdes_onboard_full is
    generic (USER_CONFIG_FILE : string := "serdes_onboard_full.txt");
    port (
------------------
-- CH0 --
      hdinp_ch0, hdinn_ch0   : in  std_logic;
      hdoutp_ch0, hdoutn_ch0 : out std_logic;
      sci_sel_ch0            : in  std_logic;
      rxiclk_ch0             : in  std_logic;
      txiclk_ch0             : in  std_logic;
      rx_full_clk_ch0        : out std_logic;
      rx_half_clk_ch0        : out std_logic;
      tx_full_clk_ch0        : out std_logic;
      tx_half_clk_ch0        : out std_logic;
      fpga_rxrefclk_ch0      : in  std_logic;
      txdata_ch0             : in  std_logic_vector (15 downto 0);
      tx_k_ch0               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch0      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch0        : in  std_logic_vector (1 downto 0);
      rxdata_ch0             : out std_logic_vector (15 downto 0);
      rx_k_ch0               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch0        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch0          : out std_logic_vector (1 downto 0);
      sb_felb_ch0_c          : in  std_logic;
      sb_felb_rst_ch0_c      : in  std_logic;
      tx_pwrup_ch0_c         : in  std_logic;
      rx_pwrup_ch0_c         : in  std_logic;
      rx_los_low_ch0_s       : out std_logic;
      lsm_status_ch0_s       : out std_logic;
      rx_cdr_lol_ch0_s       : out std_logic;
      tx_div2_mode_ch0_c     : in  std_logic;
      rx_div2_mode_ch0_c     : in  std_logic;
-- CH1 --
      hdinp_ch1, hdinn_ch1   : in  std_logic;
      hdoutp_ch1, hdoutn_ch1 : out std_logic;
      sci_sel_ch1            : in  std_logic;
      rxiclk_ch1             : in  std_logic;
      txiclk_ch1             : in  std_logic;
      rx_full_clk_ch1        : out std_logic;
      rx_half_clk_ch1        : out std_logic;
      tx_full_clk_ch1        : out std_logic;
      tx_half_clk_ch1        : out std_logic;
      fpga_rxrefclk_ch1      : in  std_logic;
      txdata_ch1             : in  std_logic_vector (15 downto 0);
      tx_k_ch1               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch1      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch1        : in  std_logic_vector (1 downto 0);
      rxdata_ch1             : out std_logic_vector (15 downto 0);
      rx_k_ch1               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch1        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch1          : out std_logic_vector (1 downto 0);
      sb_felb_ch1_c          : in  std_logic;
      sb_felb_rst_ch1_c      : in  std_logic;
      tx_pwrup_ch1_c         : in  std_logic;
      rx_pwrup_ch1_c         : in  std_logic;
      rx_los_low_ch1_s       : out std_logic;
      lsm_status_ch1_s       : out std_logic;
      rx_cdr_lol_ch1_s       : out std_logic;
      tx_div2_mode_ch1_c     : in  std_logic;
      rx_div2_mode_ch1_c     : in  std_logic;
-- CH2 --
      hdinp_ch2, hdinn_ch2   : in  std_logic;
      hdoutp_ch2, hdoutn_ch2 : out std_logic;
      sci_sel_ch2            : in  std_logic;
      rxiclk_ch2             : in  std_logic;
      txiclk_ch2             : in  std_logic;
      rx_full_clk_ch2        : out std_logic;
      rx_half_clk_ch2        : out std_logic;
      tx_full_clk_ch2        : out std_logic;
      tx_half_clk_ch2        : out std_logic;
      fpga_rxrefclk_ch2      : in  std_logic;
      txdata_ch2             : in  std_logic_vector (15 downto 0);
      tx_k_ch2               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch2      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch2        : in  std_logic_vector (1 downto 0);
      rxdata_ch2             : out std_logic_vector (15 downto 0);
      rx_k_ch2               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch2        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch2          : out std_logic_vector (1 downto 0);
      sb_felb_ch2_c          : in  std_logic;
      sb_felb_rst_ch2_c      : in  std_logic;
      tx_pwrup_ch2_c         : in  std_logic;
      rx_pwrup_ch2_c         : in  std_logic;
      rx_los_low_ch2_s       : out std_logic;
      lsm_status_ch2_s       : out std_logic;
      rx_cdr_lol_ch2_s       : out std_logic;
      tx_div2_mode_ch2_c     : in  std_logic;
      rx_div2_mode_ch2_c     : in  std_logic;
-- CH3 --
      hdinp_ch3, hdinn_ch3   : in  std_logic;
      hdoutp_ch3, hdoutn_ch3 : out std_logic;
      sci_sel_ch3            : in  std_logic;
      rxiclk_ch3             : in  std_logic;
      txiclk_ch3             : in  std_logic;
      rx_full_clk_ch3        : out std_logic;
      rx_half_clk_ch3        : out std_logic;
      tx_full_clk_ch3        : out std_logic;
      tx_half_clk_ch3        : out std_logic;
      fpga_rxrefclk_ch3      : in  std_logic;
      txdata_ch3             : in  std_logic_vector (15 downto 0);
      tx_k_ch3               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch3      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch3        : in  std_logic_vector (1 downto 0);
      rxdata_ch3             : out std_logic_vector (15 downto 0);
      rx_k_ch3               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch3        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch3          : out std_logic_vector (1 downto 0);
      sb_felb_ch3_c          : in  std_logic;
      sb_felb_rst_ch3_c      : in  std_logic;
      tx_pwrup_ch3_c         : in  std_logic;
      rx_pwrup_ch3_c         : in  std_logic;
      rx_los_low_ch3_s       : out std_logic;
      lsm_status_ch3_s       : out std_logic;
      rx_cdr_lol_ch3_s       : out std_logic;
      tx_div2_mode_ch3_c     : in  std_logic;
      rx_div2_mode_ch3_c     : in  std_logic;
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      tx_sync_qd_c           : in  std_logic;
      refclk2fpga            : out std_logic;
      rst_n                  : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;


  component serdes_onboard_full_125 is
    generic (USER_CONFIG_FILE : string := "serdes_onboard_full_125.txt");
    port (
------------------
-- CH0 --
      hdinp_ch0, hdinn_ch0   : in  std_logic;
      hdoutp_ch0, hdoutn_ch0 : out std_logic;
      sci_sel_ch0            : in  std_logic;
      rxiclk_ch0             : in  std_logic;
      txiclk_ch0             : in  std_logic;
      rx_full_clk_ch0        : out std_logic;
      rx_half_clk_ch0        : out std_logic;
      tx_full_clk_ch0        : out std_logic;
      tx_half_clk_ch0        : out std_logic;
      fpga_rxrefclk_ch0      : in  std_logic;
      txdata_ch0             : in  std_logic_vector (15 downto 0);
      tx_k_ch0               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch0      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch0        : in  std_logic_vector (1 downto 0);
      rxdata_ch0             : out std_logic_vector (15 downto 0);
      rx_k_ch0               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch0        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch0          : out std_logic_vector (1 downto 0);
      sb_felb_ch0_c          : in  std_logic;
      sb_felb_rst_ch0_c      : in  std_logic;
      tx_pwrup_ch0_c         : in  std_logic;
      rx_pwrup_ch0_c         : in  std_logic;
      rx_los_low_ch0_s       : out std_logic;
      lsm_status_ch0_s       : out std_logic;
      rx_cdr_lol_ch0_s       : out std_logic;
      tx_div2_mode_ch0_c     : in  std_logic;
      rx_div2_mode_ch0_c     : in  std_logic;
-- CH1 --
      hdinp_ch1, hdinn_ch1   : in  std_logic;
      hdoutp_ch1, hdoutn_ch1 : out std_logic;
      sci_sel_ch1            : in  std_logic;
      rxiclk_ch1             : in  std_logic;
      txiclk_ch1             : in  std_logic;
      rx_full_clk_ch1        : out std_logic;
      rx_half_clk_ch1        : out std_logic;
      tx_full_clk_ch1        : out std_logic;
      tx_half_clk_ch1        : out std_logic;
      fpga_rxrefclk_ch1      : in  std_logic;
      txdata_ch1             : in  std_logic_vector (15 downto 0);
      tx_k_ch1               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch1      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch1        : in  std_logic_vector (1 downto 0);
      rxdata_ch1             : out std_logic_vector (15 downto 0);
      rx_k_ch1               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch1        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch1          : out std_logic_vector (1 downto 0);
      sb_felb_ch1_c          : in  std_logic;
      sb_felb_rst_ch1_c      : in  std_logic;
      tx_pwrup_ch1_c         : in  std_logic;
      rx_pwrup_ch1_c         : in  std_logic;
      rx_los_low_ch1_s       : out std_logic;
      lsm_status_ch1_s       : out std_logic;
      rx_cdr_lol_ch1_s       : out std_logic;
      tx_div2_mode_ch1_c     : in  std_logic;
      rx_div2_mode_ch1_c     : in  std_logic;
-- CH2 --
      hdinp_ch2, hdinn_ch2   : in  std_logic;
      hdoutp_ch2, hdoutn_ch2 : out std_logic;
      sci_sel_ch2            : in  std_logic;
      rxiclk_ch2             : in  std_logic;
      txiclk_ch2             : in  std_logic;
      rx_full_clk_ch2        : out std_logic;
      rx_half_clk_ch2        : out std_logic;
      tx_full_clk_ch2        : out std_logic;
      tx_half_clk_ch2        : out std_logic;
      fpga_rxrefclk_ch2      : in  std_logic;
      txdata_ch2             : in  std_logic_vector (15 downto 0);
      tx_k_ch2               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch2      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch2        : in  std_logic_vector (1 downto 0);
      rxdata_ch2             : out std_logic_vector (15 downto 0);
      rx_k_ch2               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch2        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch2          : out std_logic_vector (1 downto 0);
      sb_felb_ch2_c          : in  std_logic;
      sb_felb_rst_ch2_c      : in  std_logic;
      tx_pwrup_ch2_c         : in  std_logic;
      rx_pwrup_ch2_c         : in  std_logic;
      rx_los_low_ch2_s       : out std_logic;
      lsm_status_ch2_s       : out std_logic;
      rx_cdr_lol_ch2_s       : out std_logic;
      tx_div2_mode_ch2_c     : in  std_logic;
      rx_div2_mode_ch2_c     : in  std_logic;
-- CH3 --
      hdinp_ch3, hdinn_ch3   : in  std_logic;
      hdoutp_ch3, hdoutn_ch3 : out std_logic;
      sci_sel_ch3            : in  std_logic;
      rxiclk_ch3             : in  std_logic;
      txiclk_ch3             : in  std_logic;
      rx_full_clk_ch3        : out std_logic;
      rx_half_clk_ch3        : out std_logic;
      tx_full_clk_ch3        : out std_logic;
      tx_half_clk_ch3        : out std_logic;
      fpga_rxrefclk_ch3      : in  std_logic;
      txdata_ch3             : in  std_logic_vector (15 downto 0);
      tx_k_ch3               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch3      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch3        : in  std_logic_vector (1 downto 0);
      rxdata_ch3             : out std_logic_vector (15 downto 0);
      rx_k_ch3               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch3        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch3          : out std_logic_vector (1 downto 0);
      sb_felb_ch3_c          : in  std_logic;
      sb_felb_rst_ch3_c      : in  std_logic;
      tx_pwrup_ch3_c         : in  std_logic;
      rx_pwrup_ch3_c         : in  std_logic;
      rx_los_low_ch3_s       : out std_logic;
      lsm_status_ch3_s       : out std_logic;
      rx_cdr_lol_ch3_s       : out std_logic;
      tx_div2_mode_ch3_c     : in  std_logic;
      rx_div2_mode_ch3_c     : in  std_logic;
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      tx_sync_qd_c           : in  std_logic;
      refclk2fpga            : out std_logic;
      rst_n                  : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;


  component serdes_onboard_full_ctc is
    generic (USER_CONFIG_FILE : string := "serdes_onboard_full_ctc.txt");
    port (
------------------
-- CH0 --
      hdinp_ch0, hdinn_ch0   : in  std_logic;
      hdoutp_ch0, hdoutn_ch0 : out std_logic;
      sci_sel_ch0            : in  std_logic;
      rxiclk_ch0             : in  std_logic;
      txiclk_ch0             : in  std_logic;
      rx_full_clk_ch0        : out std_logic;
      rx_half_clk_ch0        : out std_logic;
      tx_full_clk_ch0        : out std_logic;
      tx_half_clk_ch0        : out std_logic;
      fpga_rxrefclk_ch0      : in  std_logic;
      txdata_ch0             : in  std_logic_vector (15 downto 0);
      tx_k_ch0               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch0      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch0        : in  std_logic_vector (1 downto 0);
      rxdata_ch0             : out std_logic_vector (15 downto 0);
      rx_k_ch0               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch0        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch0          : out std_logic_vector (1 downto 0);
      sb_felb_ch0_c          : in  std_logic;
      sb_felb_rst_ch0_c      : in  std_logic;
      tx_pwrup_ch0_c         : in  std_logic;
      rx_pwrup_ch0_c         : in  std_logic;
      rx_los_low_ch0_s       : out std_logic;
      lsm_status_ch0_s       : out std_logic;
      ctc_urun_ch0_s         : out std_logic;
      ctc_orun_ch0_s         : out std_logic;
      ctc_ins_ch0_s          : out std_logic;
      ctc_del_ch0_s          : out std_logic;
      rx_cdr_lol_ch0_s       : out std_logic;
      tx_div2_mode_ch0_c     : in  std_logic;
      rx_div2_mode_ch0_c     : in  std_logic;
-- CH1 --
      hdinp_ch1, hdinn_ch1   : in  std_logic;
      hdoutp_ch1, hdoutn_ch1 : out std_logic;
      sci_sel_ch1            : in  std_logic;
      rxiclk_ch1             : in  std_logic;
      txiclk_ch1             : in  std_logic;
      rx_full_clk_ch1        : out std_logic;
      rx_half_clk_ch1        : out std_logic;
      tx_full_clk_ch1        : out std_logic;
      tx_half_clk_ch1        : out std_logic;
      fpga_rxrefclk_ch1      : in  std_logic;
      txdata_ch1             : in  std_logic_vector (15 downto 0);
      tx_k_ch1               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch1      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch1        : in  std_logic_vector (1 downto 0);
      rxdata_ch1             : out std_logic_vector (15 downto 0);
      rx_k_ch1               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch1        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch1          : out std_logic_vector (1 downto 0);
      sb_felb_ch1_c          : in  std_logic;
      sb_felb_rst_ch1_c      : in  std_logic;
      tx_pwrup_ch1_c         : in  std_logic;
      rx_pwrup_ch1_c         : in  std_logic;
      rx_los_low_ch1_s       : out std_logic;
      lsm_status_ch1_s       : out std_logic;
      ctc_urun_ch1_s         : out std_logic;
      ctc_orun_ch1_s         : out std_logic;
      ctc_ins_ch1_s          : out std_logic;
      ctc_del_ch1_s          : out std_logic;
      rx_cdr_lol_ch1_s       : out std_logic;
      tx_div2_mode_ch1_c     : in  std_logic;
      rx_div2_mode_ch1_c     : in  std_logic;
-- CH2 --
      hdinp_ch2, hdinn_ch2   : in  std_logic;
      hdoutp_ch2, hdoutn_ch2 : out std_logic;
      sci_sel_ch2            : in  std_logic;
      rxiclk_ch2             : in  std_logic;
      txiclk_ch2             : in  std_logic;
      rx_full_clk_ch2        : out std_logic;
      rx_half_clk_ch2        : out std_logic;
      tx_full_clk_ch2        : out std_logic;
      tx_half_clk_ch2        : out std_logic;
      fpga_rxrefclk_ch2      : in  std_logic;
      txdata_ch2             : in  std_logic_vector (15 downto 0);
      tx_k_ch2               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch2      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch2        : in  std_logic_vector (1 downto 0);
      rxdata_ch2             : out std_logic_vector (15 downto 0);
      rx_k_ch2               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch2        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch2          : out std_logic_vector (1 downto 0);
      sb_felb_ch2_c          : in  std_logic;
      sb_felb_rst_ch2_c      : in  std_logic;
      tx_pwrup_ch2_c         : in  std_logic;
      rx_pwrup_ch2_c         : in  std_logic;
      rx_los_low_ch2_s       : out std_logic;
      lsm_status_ch2_s       : out std_logic;
      ctc_urun_ch2_s         : out std_logic;
      ctc_orun_ch2_s         : out std_logic;
      ctc_ins_ch2_s          : out std_logic;
      ctc_del_ch2_s          : out std_logic;
      rx_cdr_lol_ch2_s       : out std_logic;
      tx_div2_mode_ch2_c     : in  std_logic;
      rx_div2_mode_ch2_c     : in  std_logic;
-- CH3 --
      hdinp_ch3, hdinn_ch3   : in  std_logic;
      hdoutp_ch3, hdoutn_ch3 : out std_logic;
      sci_sel_ch3            : in  std_logic;
      rxiclk_ch3             : in  std_logic;
      txiclk_ch3             : in  std_logic;
      rx_full_clk_ch3        : out std_logic;
      rx_half_clk_ch3        : out std_logic;
      tx_full_clk_ch3        : out std_logic;
      tx_half_clk_ch3        : out std_logic;
      fpga_rxrefclk_ch3      : in  std_logic;
      txdata_ch3             : in  std_logic_vector (15 downto 0);
      tx_k_ch3               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch3      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch3        : in  std_logic_vector (1 downto 0);
      rxdata_ch3             : out std_logic_vector (15 downto 0);
      rx_k_ch3               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch3        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch3          : out std_logic_vector (1 downto 0);
      sb_felb_ch3_c          : in  std_logic;
      sb_felb_rst_ch3_c      : in  std_logic;
      tx_pwrup_ch3_c         : in  std_logic;
      rx_pwrup_ch3_c         : in  std_logic;
      rx_los_low_ch3_s       : out std_logic;
      lsm_status_ch3_s       : out std_logic;
      ctc_urun_ch3_s         : out std_logic;
      ctc_orun_ch3_s         : out std_logic;
      ctc_ins_ch3_s          : out std_logic;
      ctc_del_ch3_s          : out std_logic;
      rx_cdr_lol_ch3_s       : out std_logic;
      tx_div2_mode_ch3_c     : in  std_logic;
      rx_div2_mode_ch3_c     : in  std_logic;
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      tx_sync_qd_c           : in  std_logic;
      refclk2fpga            : out std_logic;
      rst_n                  : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;


  component serdes_sync_0 is
    generic (USER_CONFIG_FILE : string := "serdes_sync_0.txt");
    port (
------------------
-- CH0 --
      hdinp_ch0, hdinn_ch0   : in  std_logic;
      hdoutp_ch0, hdoutn_ch0 : out std_logic;
      sci_sel_ch0            : in  std_logic;
      rxiclk_ch0             : in  std_logic;
      txiclk_ch0             : in  std_logic;
      rx_full_clk_ch0        : out std_logic;
      rx_half_clk_ch0        : out std_logic;
      tx_full_clk_ch0        : out std_logic;
      tx_half_clk_ch0        : out std_logic;
      fpga_rxrefclk_ch0      : in  std_logic;
      txdata_ch0             : in  std_logic_vector (7 downto 0);
      tx_k_ch0               : in  std_logic;
      tx_force_disp_ch0      : in  std_logic;
      tx_disp_sel_ch0        : in  std_logic;
      rxdata_ch0             : out std_logic_vector (7 downto 0);
      rx_k_ch0               : out std_logic;
      rx_disp_err_ch0        : out std_logic;
      rx_cv_err_ch0          : out std_logic;
      rx_serdes_rst_ch0_c    : in  std_logic;
      sb_felb_ch0_c          : in  std_logic;
      sb_felb_rst_ch0_c      : in  std_logic;
      tx_pcs_rst_ch0_c       : in  std_logic;
      tx_pwrup_ch0_c         : in  std_logic;
      rx_pcs_rst_ch0_c       : in  std_logic;
      rx_pwrup_ch0_c         : in  std_logic;
      rx_los_low_ch0_s       : out std_logic;
      lsm_status_ch0_s       : out std_logic;
      rx_cdr_lol_ch0_s       : out std_logic;
      tx_div2_mode_ch0_c     : in  std_logic;
      rx_div2_mode_ch0_c     : in  std_logic;
-- CH1 --
-- CH2 --
-- CH3 --
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      rst_qd_c               : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;


  component serdes_sync_125_0 is
    generic (USER_CONFIG_FILE : string := "serdes_sync_125_0.txt");
    port (
------------------
-- CH0 --
      hdinp_ch0, hdinn_ch0   : in  std_logic;
      hdoutp_ch0, hdoutn_ch0 : out std_logic;
      sci_sel_ch0            : in  std_logic;
      rxiclk_ch0             : in  std_logic;
      txiclk_ch0             : in  std_logic;
      rx_full_clk_ch0        : out std_logic;
      rx_half_clk_ch0        : out std_logic;
      tx_full_clk_ch0        : out std_logic;
      tx_half_clk_ch0        : out std_logic;
      fpga_rxrefclk_ch0      : in  std_logic;
      txdata_ch0             : in  std_logic_vector (7 downto 0);
      tx_k_ch0               : in  std_logic;
      tx_force_disp_ch0      : in  std_logic;
      tx_disp_sel_ch0        : in  std_logic;
      rxdata_ch0             : out std_logic_vector (7 downto 0);
      rx_k_ch0               : out std_logic;
      rx_disp_err_ch0        : out std_logic;
      rx_cv_err_ch0          : out std_logic;
      rx_serdes_rst_ch0_c    : in  std_logic;
      sb_felb_ch0_c          : in  std_logic;
      sb_felb_rst_ch0_c      : in  std_logic;
      tx_pcs_rst_ch0_c       : in  std_logic;
      tx_pwrup_ch0_c         : in  std_logic;
      rx_pcs_rst_ch0_c       : in  std_logic;
      rx_pwrup_ch0_c         : in  std_logic;
      rx_los_low_ch0_s       : out std_logic;
      lsm_status_ch0_s       : out std_logic;
      rx_cdr_lol_ch0_s       : out std_logic;
      tx_div2_mode_ch0_c     : in  std_logic;
      rx_div2_mode_ch0_c     : in  std_logic;
-- CH1 --
-- CH2 --
-- CH3 --
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      rst_qd_c               : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;


  component sfp_0_200_ctc is
    generic (USER_CONFIG_FILE : string := "sfp_0_200_ctc.txt");
    port (
------------------
-- CH0 --
      hdinp_ch0, hdinn_ch0   : in  std_logic;
      hdoutp_ch0, hdoutn_ch0 : out std_logic;
      sci_sel_ch0            : in  std_logic;
      rxiclk_ch0             : in  std_logic;
      txiclk_ch0             : in  std_logic;
      rx_full_clk_ch0        : out std_logic;
      rx_half_clk_ch0        : out std_logic;
      tx_full_clk_ch0        : out std_logic;
      tx_half_clk_ch0        : out std_logic;
      fpga_rxrefclk_ch0      : in  std_logic;
      txdata_ch0             : in  std_logic_vector (15 downto 0);
      tx_k_ch0               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch0      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch0        : in  std_logic_vector (1 downto 0);
      rxdata_ch0             : out std_logic_vector (15 downto 0);
      rx_k_ch0               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch0        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch0          : out std_logic_vector (1 downto 0);
      sb_felb_ch0_c          : in  std_logic;
      sb_felb_rst_ch0_c      : in  std_logic;
      tx_pwrup_ch0_c         : in  std_logic;
      rx_pwrup_ch0_c         : in  std_logic;
      rx_los_low_ch0_s       : out std_logic;
      lsm_status_ch0_s       : out std_logic;
      ctc_urun_ch0_s         : out std_logic;
      ctc_orun_ch0_s         : out std_logic;
      ctc_ins_ch0_s          : out std_logic;
      ctc_del_ch0_s          : out std_logic;
      rx_cdr_lol_ch0_s       : out std_logic;
      tx_div2_mode_ch0_c     : in  std_logic;
      rx_div2_mode_ch0_c     : in  std_logic;
-- CH1 --
-- CH2 --
-- CH3 --
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      rst_n                  : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;


  component sfp_0_200_int is
    generic (USER_CONFIG_FILE : string := "sfp_0_200_int.txt");
    port (
------------------
-- CH0 --
      hdinp_ch0, hdinn_ch0   : in  std_logic;
      hdoutp_ch0, hdoutn_ch0 : out std_logic;
      sci_sel_ch0            : in  std_logic;
      rxiclk_ch0             : in  std_logic;
      txiclk_ch0             : in  std_logic;
      rx_full_clk_ch0        : out std_logic;
      rx_half_clk_ch0        : out std_logic;
      tx_full_clk_ch0        : out std_logic;
      tx_half_clk_ch0        : out std_logic;
      fpga_rxrefclk_ch0      : in  std_logic;
      txdata_ch0             : in  std_logic_vector (15 downto 0);
      tx_k_ch0               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch0      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch0        : in  std_logic_vector (1 downto 0);
      rxdata_ch0             : out std_logic_vector (15 downto 0);
      rx_k_ch0               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch0        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch0          : out std_logic_vector (1 downto 0);
      sb_felb_ch0_c          : in  std_logic;
      sb_felb_rst_ch0_c      : in  std_logic;
      tx_pwrup_ch0_c         : in  std_logic;
      rx_pwrup_ch0_c         : in  std_logic;
      rx_los_low_ch0_s       : out std_logic;
      lsm_status_ch0_s       : out std_logic;
      rx_cdr_lol_ch0_s       : out std_logic;
      tx_div2_mode_ch0_c     : in  std_logic;
      rx_div2_mode_ch0_c     : in  std_logic;
-- CH1 --
-- CH2 --
-- CH3 --
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      rst_n                  : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;


  component sfp_1_125_int is
    generic (USER_CONFIG_FILE : string := "sfp_1_125_int.txt");
    port (
------------------
-- CH0 --
-- CH1 --
      hdinp_ch1, hdinn_ch1   : in  std_logic;
      hdoutp_ch1, hdoutn_ch1 : out std_logic;
      sci_sel_ch1            : in  std_logic;
      rxiclk_ch1             : in  std_logic;
      txiclk_ch1             : in  std_logic;
      rx_full_clk_ch1        : out std_logic;
      rx_half_clk_ch1        : out std_logic;
      tx_full_clk_ch1        : out std_logic;
      tx_half_clk_ch1        : out std_logic;
      fpga_rxrefclk_ch1      : in  std_logic;
      txdata_ch1             : in  std_logic_vector (15 downto 0);
      tx_k_ch1               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch1      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch1        : in  std_logic_vector (1 downto 0);
      rxdata_ch1             : out std_logic_vector (15 downto 0);
      rx_k_ch1               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch1        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch1          : out std_logic_vector (1 downto 0);
      sb_felb_ch1_c          : in  std_logic;
      sb_felb_rst_ch1_c      : in  std_logic;
      tx_pwrup_ch1_c         : in  std_logic;
      rx_pwrup_ch1_c         : in  std_logic;
      rx_los_low_ch1_s       : out std_logic;
      lsm_status_ch1_s       : out std_logic;
      rx_cdr_lol_ch1_s       : out std_logic;
      tx_div2_mode_ch1_c     : in  std_logic;
      rx_div2_mode_ch1_c     : in  std_logic;
-- CH2 --
-- CH3 --
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      rst_n                  : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;


  component sfp_1_200_int is
    generic (USER_CONFIG_FILE : string := "sfp_1_200_int.txt");
    port (
------------------
-- CH0 --
-- CH1 --
      hdinp_ch1, hdinn_ch1   : in  std_logic;
      hdoutp_ch1, hdoutn_ch1 : out std_logic;
      sci_sel_ch1            : in  std_logic;
      rxiclk_ch1             : in  std_logic;
      txiclk_ch1             : in  std_logic;
      rx_full_clk_ch1        : out std_logic;
      rx_half_clk_ch1        : out std_logic;
      tx_full_clk_ch1        : out std_logic;
      tx_half_clk_ch1        : out std_logic;
      fpga_rxrefclk_ch1      : in  std_logic;
      txdata_ch1             : in  std_logic_vector (15 downto 0);
      tx_k_ch1               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch1      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch1        : in  std_logic_vector (1 downto 0);
      rxdata_ch1             : out std_logic_vector (15 downto 0);
      rx_k_ch1               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch1        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch1          : out std_logic_vector (1 downto 0);
      sb_felb_ch1_c          : in  std_logic;
      sb_felb_rst_ch1_c      : in  std_logic;
      tx_pwrup_ch1_c         : in  std_logic;
      rx_pwrup_ch1_c         : in  std_logic;
      rx_los_low_ch1_s       : out std_logic;
      lsm_status_ch1_s       : out std_logic;
      rx_cdr_lol_ch1_s       : out std_logic;
      tx_div2_mode_ch1_c     : in  std_logic;
      rx_div2_mode_ch1_c     : in  std_logic;
-- CH2 --
-- CH3 --
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      rst_n                  : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;


  component sfp_ctc_0_200_int is
    generic (USER_CONFIG_FILE : string := "sfp_ctc_0_200_int.txt");
    port (
------------------
-- CH0 --
      hdinp_ch0, hdinn_ch0   : in  std_logic;
      hdoutp_ch0, hdoutn_ch0 : out std_logic;
      sci_sel_ch0            : in  std_logic;
      rxiclk_ch0             : in  std_logic;
      txiclk_ch0             : in  std_logic;
      rx_full_clk_ch0        : out std_logic;
      rx_half_clk_ch0        : out std_logic;
      tx_full_clk_ch0        : out std_logic;
      tx_half_clk_ch0        : out std_logic;
      fpga_rxrefclk_ch0      : in  std_logic;
      txdata_ch0             : in  std_logic_vector (15 downto 0);
      tx_k_ch0               : in  std_logic_vector (1 downto 0);
      tx_force_disp_ch0      : in  std_logic_vector (1 downto 0);
      tx_disp_sel_ch0        : in  std_logic_vector (1 downto 0);
      rxdata_ch0             : out std_logic_vector (15 downto 0);
      rx_k_ch0               : out std_logic_vector (1 downto 0);
      rx_disp_err_ch0        : out std_logic_vector (1 downto 0);
      rx_cv_err_ch0          : out std_logic_vector (1 downto 0);
      sb_felb_ch0_c          : in  std_logic;
      sb_felb_rst_ch0_c      : in  std_logic;
      tx_pwrup_ch0_c         : in  std_logic;
      rx_pwrup_ch0_c         : in  std_logic;
      rx_los_low_ch0_s       : out std_logic;
      lsm_status_ch0_s       : out std_logic;
      ctc_urun_ch0_s         : out std_logic;
      ctc_orun_ch0_s         : out std_logic;
      ctc_ins_ch0_s          : out std_logic;
      ctc_del_ch0_s          : out std_logic;
      rx_cdr_lol_ch0_s       : out std_logic;
      tx_div2_mode_ch0_c     : in  std_logic;
      rx_div2_mode_ch0_c     : in  std_logic;
-- CH1 --
-- CH2 --
-- CH3 --
---- Miscillaneous ports
      sci_wrdata             : in  std_logic_vector (7 downto 0);
      sci_addr               : in  std_logic_vector (5 downto 0);
      sci_rddata             : out std_logic_vector (7 downto 0);
      sci_sel_quad           : in  std_logic;
      sci_rd                 : in  std_logic;
      sci_wrn                : in  std_logic;
      fpga_txrefclk          : in  std_logic;
      tx_serdes_rst_c        : in  std_logic;
      tx_pll_lol_qd_s        : out std_logic;
      rst_n                  : in  std_logic;
      serdes_rst_qd_c        : in  std_logic);

  end component;

  component trigger_clock_manager is
    port (
      TRB_CLK_IN : in std_logic;
      INT_CLK_IN : in std_logic;  -- dont care which clock, but not faster than TRB_CLK_IN

      RESET_IN : in std_logic;

      -- only single register, so no address
      REGIO_ADDRESS_IN          : in  std_logic_vector(1 downto 0);
      REGIO_DATA_IN             : in  std_logic_vector(31 downto 0);
      REGIO_READ_ENABLE_IN      : in  std_logic;
      REGIO_WRITE_ENABLE_IN     : in  std_logic;
      REGIO_DATA_OUT            : out std_logic_vector(31 downto 0);
      REGIO_DATAREADY_OUT       : out std_logic;
      REGIO_WRITE_ACK_OUT       : out std_logic;
      REGIO_UNKNOWN_ADDRESS_OUT : out std_logic;

      RESET_OUT     : out std_logic;
      TC_SELECT_OUT : out std_logic_vector(31 downto 0)
      );
  end component;
end package;
