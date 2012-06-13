LIBRARY ieee;
use ieee.std_logic_1164.all;
USE IEEE.numeric_std.ALL;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
-- use work.trb_net16_hub_func.all;
use work.version.all;

entity cts_fpga2 is
  port(
    --Clocks
    CLK_100_IN          : in  std_logic;
    CLK_125_IN          : in  std_logic;
    --Resets
    RESET_FPGA_2        : in  std_logic;
    ADDON_RESET         : in  std_logic;
    --To Other FPGAs
    ADO_LV              : inout std_logic_vector(61 downto 0);
    FFC                 : inout std_logic_vector(22 downto 0);
    --LED
    LED_GBE_OK          : out std_logic;
    LED_GBE_RX          : out std_logic;
    LED_GBE_TX          : out std_logic;
    LED_TRB_OK          : out std_logic;
    LED_TRB_RX          : out std_logic;
    LED_TRB_TX          : out std_logic;
    LED_RED             : out std_logic;
    LED_YELLOW          : out std_logic;
    LED_GREEN           : out std_logic;
    LED_ORANGE          : out std_logic;
    --SFP
    SFP_DATA_TX         : out   std_logic_vector(3 downto 0); --dummy serdes connection
    SFP_DATA_RX         : in    std_logic_vector(3 downto 0); --dummy serdes connection
    GBE_LOS             : in    std_logic;
    GBE_MOD             : inout std_logic_vector(2 downto 0);
    GBE_TX_DIS          : out   std_logic;
    TRB_LOS             : in    std_logic;
    TRB_MOD             : inout std_logic_vector(2 downto 0);
    TRB_TX_DIS          : out   std_logic;
    --Flash
    SPI_CLK_OUT         : out std_logic;
    SPI_CS_OUT          : out std_logic;
    SPI_SI_OUT          : out std_logic;
    SPI_SO_IN           : in  std_logic;
    PROGRAMN_OUT        : out std_logic;
    --RAM
    RAM_ADSCB           : out std_logic;
    RAM_ADSPB           : out std_logic;
    RAM_ADVB            : out std_logic;
    RAM_CE_2            : out std_logic;
    RAM_CEB             : out std_logic;
    RAM_CLK             : out std_logic;
    RAM_GWB             : out std_logic;
    RAM_OEB             : out std_logic;
    RAM_A               : out std_logic_vector(19 downto 0);
    RAM_DQ              : inout std_logic_vector(18 downto 1);
    --Others
    ONEWIRE_MONITOR_OUT : out std_logic;
    TEMPSENS            : inout std_logic;
    --Debug
    TEST_LINE           : out std_logic_vector(15 downto 0)
    );

  attribute syn_useioff : boolean;
  attribute syn_useioff of FFC                  : signal is true;
  attribute syn_useioff of SPI_CLK_OUT          : signal is true;
  attribute syn_useioff of SPI_CS_OUT           : signal is true;
  attribute syn_useioff of SPI_SO_IN            : signal is true;
  attribute syn_useioff of SPI_SI_OUT           : signal is true;
  attribute syn_useioff of ADO_LV               : signal is true;
  attribute syn_useioff of RAM_A                : signal is true;
  attribute syn_useioff of RAM_DQ               : signal is true;
  attribute syn_useioff of RAM_ADSCB            : signal is true;
  attribute syn_useioff of RAM_ADSPB            : signal is true;
  attribute syn_useioff of RAM_ADVB             : signal is true;
  attribute syn_useioff of RAM_CE_2             : signal is true;
  attribute syn_useioff of RAM_CEB              : signal is true;
  attribute syn_useioff of RAM_CLK              : signal is true;
  attribute syn_useioff of RAM_GWB              : signal is true;
  attribute syn_useioff of RAM_OEB              : signal is true;

  attribute syn_useioff of PROGRAMN_OUT         : signal is false;
  attribute syn_useioff of LED_GBE_OK           : signal is false;
  attribute syn_useioff of LED_GBE_RX           : signal is false;
  attribute syn_useioff of LED_GBE_TX           : signal is false;
  attribute syn_useioff of LED_TRB_OK           : signal is false;
  attribute syn_useioff of LED_TRB_RX           : signal is false;
  attribute syn_useioff of LED_TRB_TX           : signal is false;
  attribute syn_useioff of LED_RED              : signal is false;
  attribute syn_useioff of LED_YELLOW           : signal is false;
  attribute syn_useioff of LED_GREEN            : signal is false;
  attribute syn_useioff of LED_ORANGE           : signal is false;
  attribute syn_useioff of TRB_LOS              : signal is false;
  attribute syn_useioff of TRB_MOD              : signal is false;
  attribute syn_useioff of TRB_TX_DIS           : signal is false;
  attribute syn_useioff of GBE_LOS              : signal is false;
  attribute syn_useioff of GBE_MOD              : signal is false;
  attribute syn_useioff of GBE_TX_DIS           : signal is false;
  attribute syn_useioff of ONEWIRE_MONITOR_OUT  : signal is false;
  attribute syn_useioff of TEMPSENS             : signal is false;


end entity;


architecture cts_fpga2_arch of cts_fpga2 is

--Number of stat & ctrl registers on both endpoints. Number of Regs is 2**value
  constant RDO_NUM_STAT_REGS     : integer := 2;
  constant RDO_NUM_CTRL_REGS     : integer := 2;
  constant CTS_NUM_STAT_REGS     : integer := 2;
  constant CTS_NUM_CTRL_REGS     : integer := 2;

--Clock & Reset
  signal clk_en                  : std_logic;
  signal make_reset_via_network  : std_logic;
  signal clk_100                 : std_logic;
  signal pll_locked              : std_logic;
  signal reset_async             : std_logic;
  signal reset_i                 : std_logic;
  signal delayed_restart_fpga    : std_logic;
  signal restart_fpga_counter    : unsigned(11 downto 0);

--Media Interfaces
  signal rdo_med_data_in         : std_logic_vector (16-1 downto 0);
  signal rdo_med_packet_num_in   : std_logic_vector (3-1  downto 0);
  signal rdo_med_dataready_in    : std_logic;
  signal rdo_med_read_in         : std_logic;
  signal rdo_med_data_out        : std_logic_vector (16-1 downto 0);
  signal rdo_med_packet_num_out  : std_logic_vector (3-1  downto 0);
  signal rdo_med_dataready_out   : std_logic;
  signal rdo_med_read_out        : std_logic;
  signal rdo_med_stat_op         : std_logic_vector (16-1 downto 0);
  signal rdo_med_ctrl_op         : std_logic_vector (16-1 downto 0);
  signal rdo_med_stat_debug      : std_logic_vector (64-1 downto 0);
  signal cts_med_data_in         : std_logic_vector (16-1 downto 0);
  signal cts_med_packet_num_in   : std_logic_vector (3-1  downto 0);
  signal cts_med_dataready_in    : std_logic;
  signal cts_med_read_in         : std_logic;
  signal cts_med_data_out        : std_logic_vector (16-1 downto 0);
  signal cts_med_packet_num_out  : std_logic_vector (3-1  downto 0);
  signal cts_med_dataready_out   : std_logic;
  signal cts_med_read_out        : std_logic;
  signal cts_med_stat_op         : std_logic_vector (16-1 downto 0);
  signal cts_med_ctrl_op         : std_logic_vector (16-1 downto 0);
  signal cts_med_stat_debug      : std_logic_vector (64-1 downto 0);

--Trigger Port for Readout requests
  signal rdo_trg_feedback_i      : std_logic;
  signal rdo_trg_data_valid      : std_logic;
  signal rdo_trg_valid_timing    : std_logic;
  signal rdo_trg_valid_notiming  : std_logic;
  signal rdo_trg_invalid         : std_logic;
  signal rdo_trg_type            : std_logic_vector (3  downto 0);
  signal rdo_trg_number          : std_logic_vector (15 downto 0);
  signal rdo_trg_code            : std_logic_vector (7  downto 0);
  signal rdo_trg_information     : std_logic_vector (23 downto 0);
  signal rdo_trg_int_trg_number  : std_logic_vector (15 downto 0);
  signal rdo_fee_trg_release     : std_logic;
  signal rdo_fee_trg_statusbits  : std_logic_vector (31 downto 0);

--Data Port for Readout
  signal rdo_fee_data            : std_logic_vector (31 downto 0);
  signal rdo_fee_data_write      : std_logic;
  signal rdo_fee_data_finished   : std_logic;
  signal rdo_fee_data_almost_full: std_logic;

--RegIO Registers on Readout endpoint
  signal rdo_regio_common_stat_reg_i       : std_logic_vector(std_COMSTATREG*32-1 downto 0);
  signal rdo_regio_common_ctrl_reg_i       : std_logic_vector(std_COMCTRLREG*32-1 downto 0);
  signal rdo_regio_common_stat_strobe_i    : std_logic_vector(std_COMSTATREG-1 downto 0);
  signal rdo_regio_common_ctrl_strobe_i    : std_logic_vector(std_COMCTRLREG-1 downto 0);
  signal rdo_regio_stat_reg_i              : std_logic_vector(2**(RDO_NUM_STAT_REGS)*32-1 downto 0);
  signal rdo_regio_ctrl_reg_i              : std_logic_vector(2**(RDO_NUM_CTRL_REGS)*32-1 downto 0);
  signal rdo_regio_stat_strobe_i           : std_logic_vector(2**(RDO_NUM_STAT_REGS)-1 downto 0);
  signal rdo_regio_ctrl_strobe_i           : std_logic_vector(2**(RDO_NUM_CTRL_REGS)-1 downto 0);

--Regio Data Bus on Readout endpoint
  signal rdo_regio_addr_out                : std_logic_vector(15 downto 0);
  signal rdo_regio_read_enable_out         : std_logic;
  signal rdo_regio_write_enable_out        : std_logic;
  signal rdo_regio_data_out                : std_logic_vector(31 downto 0);
  signal rdo_regio_data_in                 : std_logic_vector(31 downto 0);
  signal rdo_regio_dataready_in            : std_logic;
  signal rdo_regio_no_more_data_in         : std_logic;
  signal rdo_regio_write_ack_in            : std_logic;
  signal rdo_regio_unknown_addr_in         : std_logic;
  signal rdo_regio_timeout_out             : std_logic;
  signal cts_regio_onewire_monitor_i       : std_logic;

--Time signals from Readout endpoint
  signal rdo_global_time         : std_logic_vector(31 downto 0);
  signal rdo_local_time          : std_logic_vector(7  downto 0);
  signal rdo_time_since_last_trg : std_logic_vector(31 downto 0);
  signal rdo_timer_ticks         : std_logic_vector(1  downto 0);

  signal cts_trg_send_i          : std_logic;
  signal cts_trg_type_i          : std_logic_vector(3  downto 0);
  signal cts_trg_number_i        : std_logic_vector(15 downto 0);
  signal cts_trg_information_i   : std_logic_vector(23 downto 0);
  signal cts_trg_rnd_code_i      : std_logic_vector(7  downto 0);
  signal cts_trg_statusbits_i    : std_logic_vector(31 downto 0);
  signal cts_trg_busy_i          : std_logic;

  signal cts_ipu_send_i          : std_logic;
  signal cts_ipu_type_i          : std_logic_vector(3  downto 0);
  signal cts_ipu_number_i        : std_logic_vector(15 downto 0);
  signal cts_ipu_information_i   : std_logic_vector(7  downto 0);
  signal cts_ipu_rnd_code_i      : std_logic_vector(7  downto 0);

  signal cts_ipu_data_i          : std_logic_vector(31 downto 0);
  signal cts_ipu_dataready_i     : std_logic;
  signal cts_ipu_read_i          : std_logic;
  signal cts_ipu_statusbits_i    : std_logic_vector(31 downto 0);
  signal cts_ipu_busy_i          : std_logic;

--Regio Data Bus on CTS endpoint
  signal cts_common_stat_reg_i             : std_logic_vector(std_COMSTATREG*32-1 downto 0);
  signal cts_common_ctrl_reg_i             : std_logic_vector(std_COMCTRLREG*32-1 downto 0);
  signal cts_common_stat_strobe_i          : std_logic_vector(std_COMSTATREG-1 downto 0);
  signal cts_common_ctrl_strobe_i          : std_logic_vector(std_COMCTRLREG-1 downto 0);
  signal cts_stat_reg_i                    : std_logic_vector(2**(RDO_NUM_STAT_REGS)*32-1 downto 0);
  signal cts_ctrl_reg_i                    : std_logic_vector(2**(RDO_NUM_CTRL_REGS)*32-1 downto 0);
  signal cts_stat_strobe_i                 : std_logic_vector(2**(RDO_NUM_STAT_REGS)-1 downto 0);
  signal cts_ctrl_strobe_i                 : std_logic_vector(2**(RDO_NUM_CTRL_REGS)-1 downto 0);
  signal cts_regio_addr_i                  : std_logic_vector(15 downto 0);
  signal cts_regio_read_i                  : std_logic;
  signal cts_regio_write_i                 : std_logic;
  signal cts_regio_data_out_i              : std_logic_vector(31 downto 0);
  signal cts_regio_data_in_i               : std_logic_vector(31 downto 0);
  signal cts_regio_dataready_i             : std_logic;
  signal cts_regio_no_more_data_i          : std_logic;
  signal cts_regio_write_ack_i             : std_logic;
  signal cts_regio_unknown_addr_i          : std_logic;
  signal cts_regio_timeout_i               : std_logic;

--Time signals from CTS endpoint
  signal cts_global_time_i       : std_logic_vector(31 downto 0);
  signal cts_local_time_i        : std_logic_vector(7  downto 0);
  signal cts_timer_ticks_i       : std_logic_vector(1  downto 0);

--SPI for flash programming
  signal spictrl_read_en         : std_logic;
  signal spictrl_write_en        : std_logic;
  signal spictrl_data_in         : std_logic_vector (31 downto 0);
  signal spictrl_addr            : std_logic;
  signal spictrl_data_out        : std_logic_vector (31 downto 0);
  signal spictrl_ack             : std_logic;
  signal spictrl_busy            : std_logic;
  signal spimem_read_en          : std_logic;
  signal spimem_write_en         : std_logic;
  signal spimem_data_in          : std_logic_vector (31 downto 0);
  signal spimem_addr             : std_logic_vector (5 downto 0);
  signal spimem_data_out         : std_logic_vector (31 downto 0);
  signal spimem_ack              : std_logic;
  signal spi_bram_addr           : std_logic_vector (7 downto 0);
  signal spi_bram_wr_d           : std_logic_vector (7 downto 0);
  signal spi_bram_rd_d           : std_logic_vector (7 downto 0);
  signal spi_bram_we             : std_logic;



begin

---------------------------------------------------------------------------
-- Clock & Reset state machine
---------------------------------------------------------------------------
  clk_en                 <= '1';
  make_reset_via_network <= rdo_med_stat_op(13) or cts_med_stat_op(13);

  THE_PLL : pll_in100_out100
    port map(
      CLK      => CLK_100_IN,
      CLKOP    => clk_100,
      LOCK     => pll_locked
      );


  THE_RESET_HANDLER : trb_net_reset_handler
    generic map(
      RESET_DELAY     => x"0EEE"
      )
    port map(
      CLEAR_IN        => '0',            -- reset input (high active, async)
      CLEAR_N_IN      => '1',            -- reset input (low active, async)
      CLK_IN          => CLK_100_IN,     -- raw master clock, NOT from PLL/DLL!
      SYSCLK_IN       => clk_100,        -- PLL/DLL remastered clock
      PLL_LOCKED_IN   => pll_locked,     -- master PLL lock signal (async)
      RESET_IN        => '0',            -- general reset signal (SYSCLK)
      TRB_RESET_IN    => make_reset_via_network, -- TRBnet reset signal (SYSCLK)
      CLEAR_OUT       => reset_async,    -- async reset out, USE WITH CARE!
      RESET_OUT       => reset_i,    -- synchronous reset out (SYSCLK)
      DEBUG_OUT       => open
    );

---------------------------------------------------------------------------
--  Media Interface
---------------------------------------------------------------------------
  --Link to send IPU data & for slow control
  THE_MEDIA_INTERFACE_0 : trb_net16_med_ecp_sfp_gbe
    generic map(
      SERDES_NUM => 0,
      EXT_CLOCK  => c_NO
      )
    port map(
      CLK                      => CLK_100_IN,
      SYSCLK                   => clk_100,
      RESET                    => reset_i,
      CLEAR                    => reset_async,
      CLK_EN                   => clk_en,
      --Internal Connection
      MED_DATA_IN              => rdo_med_data_out,
      MED_PACKET_NUM_IN        => rdo_med_packet_num_out,
      MED_DATAREADY_IN         => rdo_med_dataready_out,
      MED_READ_OUT             => rdo_med_read_in,
      MED_DATA_OUT             => rdo_med_data_in,
      MED_PACKET_NUM_OUT       => rdo_med_packet_num_in,
      MED_DATAREADY_OUT        => rdo_med_dataready_in,
      MED_READ_IN              => rdo_med_read_out,
      REFCLK2CORE_OUT          => open,
      --SFP Connection
      SD_RXD_P_IN              => SFP_DATA_RX(0),
      SD_RXD_N_IN              => SFP_DATA_RX(1),
      SD_TXD_P_OUT             => SFP_DATA_TX(0),
      SD_TXD_N_OUT             => SFP_DATA_TX(1),
      SD_REFCLK_P_IN           => '0',
      SD_REFCLK_N_IN           => '0',
      SD_PRSNT_N_IN            => GBE_MOD(0),
      SD_LOS_IN                => GBE_LOS,
      SD_TXDIS_OUT             => GBE_TX_DIS,
      -- Status and control port
      STAT_OP                  => rdo_med_stat_op,
      CTRL_OP                  => rdo_med_ctrl_op,
      STAT_DEBUG               => open,
      CTRL_DEBUG               => (others => '0')
    );

  --Link to send triggers & readout requests
  THE_MEDIA_INTERFACE_1 : trb_net16_med_ecp_sfp_gbe
    generic map(
      SERDES_NUM => 0,
      EXT_CLOCK  => c_NO
      )
    port map(
      CLK                      => CLK_100_IN,
      SYSCLK                   => clk_100,
      RESET                    => reset_i,
      CLEAR                    => reset_async,
      CLK_EN                   => clk_en,
      --Internal Connection
      MED_DATA_IN              => cts_med_data_out,
      MED_PACKET_NUM_IN        => cts_med_packet_num_out,
      MED_DATAREADY_IN         => cts_med_dataready_out,
      MED_READ_OUT             => cts_med_read_in,
      MED_DATA_OUT             => cts_med_data_in,
      MED_PACKET_NUM_OUT       => cts_med_packet_num_in,
      MED_DATAREADY_OUT        => cts_med_dataready_in,
      MED_READ_IN              => cts_med_read_out,
      REFCLK2CORE_OUT          => open,
      --SFP Connection
      SD_RXD_P_IN              => SFP_DATA_RX(2),
      SD_RXD_N_IN              => SFP_DATA_RX(3),
      SD_TXD_P_OUT             => SFP_DATA_TX(2),
      SD_TXD_N_OUT             => SFP_DATA_TX(3),
      SD_REFCLK_P_IN           => '0',
      SD_REFCLK_N_IN           => '0',
      SD_PRSNT_N_IN            => TRB_MOD(0),
      SD_LOS_IN                => TRB_LOS,
      SD_TXDIS_OUT             => TRB_TX_DIS,
      -- Status and control port
      STAT_OP                  => cts_med_stat_op,
      CTRL_OP                  => cts_med_ctrl_op,
      STAT_DEBUG               => open,
      CTRL_DEBUG               => (others => '0')
    );

---------------------------------------------------------------------------
-- TrbNet Endpoint
---------------------------------------------------------------------------


--the standard endpoint to send data
  THE_DATA_ENDPOINT: trb_net16_endpoint_hades_full_handler
    generic map(
      REGIO_NUM_STAT_REGS        => RDO_NUM_STAT_REGS,
      REGIO_NUM_CTRL_REGS        => RDO_NUM_CTRL_REGS,
      ADDRESS_MASK               => x"FFFF",
      BROADCAST_BITMASK          => x"FF",
      REGIO_INIT_ADDRESS         => x"FC02",
      REGIO_COMPILE_TIME         => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,32)),
      REGIO_INIT_ENDPOINT_ID     => x"0002",
      REGIO_COMPILE_VERSION      => x"0000",
      REGIO_HARDWARE_VERSION     => x"52000000",
      REGIO_USE_1WIRE_INTERFACE  => c_YES,
      TIMING_TRIGGER_RAW         => c_NO,
      CLOCK_FREQUENCY            => 100,
      DATA_INTERFACE_NUMBER      => 1,
      DATA_BUFFER_DEPTH          => 11,
      DATA_BUFFER_WIDTH          => 32,
      DATA_BUFFER_FULL_THRESH    => 2**11-128,
      TRG_RELEASE_AFTER_DATA     => c_YES,
      HEADER_BUFFER_DEPTH        => 9,
      HEADER_BUFFER_FULL_THRESH  => 2**9-10
      )
    port map(
      CLK                        => clk_100,
      RESET                      => reset_i,
      CLK_EN                     => clk_en,

      MED_DATAREADY_OUT          => rdo_med_dataready_out,
      MED_DATA_OUT               => rdo_med_data_out,
      MED_PACKET_NUM_OUT         => rdo_med_packet_num_out,
      MED_READ_IN                => rdo_med_read_in,
      MED_DATAREADY_IN           => rdo_med_dataready_in,
      MED_DATA_IN                => rdo_med_data_in,
      MED_PACKET_NUM_IN          => rdo_med_packet_num_in,
      MED_READ_OUT               => rdo_med_read_out,
      MED_STAT_OP_IN             => rdo_med_stat_op,
      MED_CTRL_OP_OUT            => rdo_med_ctrl_op,

      -- LVL1 trigger APL
      TRG_TIMING_TRG_RECEIVED_IN => rdo_trg_feedback_i, --has to be set for one clock cycle when trigger is sent
                                                        --on other interface
      LVL1_TRG_DATA_VALID_OUT    => rdo_trg_data_valid,
      LVL1_VALID_TIMING_TRG_OUT  => rdo_trg_valid_timing,
      LVL1_VALID_NOTIMING_TRG_OUT=> rdo_trg_valid_notiming,
      LVL1_INVALID_TRG_OUT       => rdo_trg_invalid,
      LVL1_TRG_TYPE_OUT          => rdo_trg_type,
      LVL1_TRG_NUMBER_OUT        => rdo_trg_number,
      LVL1_TRG_CODE_OUT          => rdo_trg_code,
      LVL1_TRG_INFORMATION_OUT   => rdo_trg_information,
      LVL1_INT_TRG_NUMBER_OUT    => rdo_trg_int_trg_number,

      -- FEE Port
      FEE_TRG_RELEASE_IN(0)      => rdo_fee_trg_release,
      FEE_TRG_STATUSBITS_IN      => rdo_fee_trg_statusbits,
      FEE_DATA_IN                => rdo_fee_data,
      FEE_DATA_WRITE_IN(0)       => rdo_fee_data_write,
      FEE_DATA_FINISHED_IN(0)    => rdo_fee_data_finished,
      FEE_DATA_ALMOST_FULL_OUT(0)=> rdo_fee_data_almost_full,


      -- Slow Control Data Port - stat & ctrl of board and readout logic
      REGIO_COMMON_STAT_REG_IN     => rdo_regio_common_stat_reg_i,
      REGIO_COMMON_CTRL_REG_OUT    => rdo_regio_common_ctrl_reg_i,
      REGIO_COMMON_STAT_STROBE_OUT => rdo_regio_common_stat_strobe_i,
      REGIO_COMMON_CTRL_STROBE_OUT => rdo_regio_common_ctrl_strobe_i,

      REGIO_STAT_REG_IN          => rdo_regio_stat_reg_i,
      REGIO_CTRL_REG_OUT         => rdo_regio_ctrl_reg_i,
      REGIO_STAT_STROBE_OUT      => rdo_regio_stat_strobe_i,
      REGIO_CTRL_STROBE_OUT      => rdo_regio_ctrl_strobe_i,

      --Data interface used to configure Board, Flash & Readout
      BUS_ADDR_OUT               => rdo_regio_addr_out,
      BUS_READ_ENABLE_OUT        => rdo_regio_read_enable_out,
      BUS_WRITE_ENABLE_OUT       => rdo_regio_write_enable_out,
      BUS_DATA_OUT               => rdo_regio_data_out,
      BUS_DATA_IN                => rdo_regio_data_in,
      BUS_DATAREADY_IN           => rdo_regio_dataready_in,
      BUS_NO_MORE_DATA_IN        => rdo_regio_no_more_data_in,
      BUS_WRITE_ACK_IN           => rdo_regio_write_ack_in,
      BUS_UNKNOWN_ADDR_IN        => rdo_regio_unknown_addr_in,
      BUS_TIMEOUT_OUT            => rdo_regio_timeout_out,
      ONEWIRE_INOUT              => TEMPSENS,
      ONEWIRE_MONITOR_OUT        => cts_regio_onewire_monitor_i,
      ONEWIRE_MONITOR_IN         => '0',

      TIME_GLOBAL_OUT            => rdo_global_time,
      TIME_LOCAL_OUT             => rdo_local_time,
      TIME_SINCE_LAST_TRG_OUT    => rdo_time_since_last_trg,
      TIME_TICKS_OUT             => rdo_timer_ticks
      );


--The endpoint for the CTS to send triggers
  THE_CTS_ENDPOINT : trb_net16_endpoint_hades_cts
    generic map(
      REGIO_NUM_STAT_REGS      => CTS_NUM_STAT_REGS, --log2 of number of status registers
      REGIO_NUM_CTRL_REGS      => CTS_NUM_CTRL_REGS, --log2 of number of ctrl registers
      --standard values for output registers
      REGIO_INIT_CTRL_REGS     => (others => '0'),
      --set to 0 for unused ctrl registers to save resources
      REGIO_USED_CTRL_REGS     => (others => '1'),
      --set to 0 for each unused bit in a register
      REGIO_USED_CTRL_BITMASK  => (others => '1'),
      REGIO_USE_DAT_PORT       => c_YES,  --internal data port
      REGIO_INIT_ADDRESS       => x"FC03",
      REGIO_INIT_BOARD_INFO    => x"0000_0000",
      REGIO_INIT_ENDPOINT_ID   => x"0003",
      REGIO_COMPILE_TIME       => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,32)),
      REGIO_COMPILE_VERSION    => x"0001",
      REGIO_HARDWARE_VERSION   => x"52000001",
      REGIO_USE_1WIRE_INTERFACE=> c_MONITOR,
      CLOCK_FREQUENCY          => 100
      )
    port map(
      CLK                        => clk_100,
      RESET                      => reset_i,
      CLK_EN                     => clk_en,

      MED_DATAREADY_OUT          => cts_med_dataready_out,
      MED_DATA_OUT               => cts_med_data_out,
      MED_PACKET_NUM_OUT         => cts_med_packet_num_out,
      MED_READ_IN                => cts_med_read_in,
      MED_DATAREADY_IN           => cts_med_dataready_in,
      MED_DATA_IN                => cts_med_data_in,
      MED_PACKET_NUM_IN          => cts_med_packet_num_in,
      MED_READ_OUT               => cts_med_read_out,
      MED_STAT_OP_IN             => cts_med_stat_op,
      MED_CTRL_OP_OUT            => cts_med_ctrl_op,

      --LVL1 trigger
      TRG_SEND_IN                => cts_trg_send_i,
      TRG_TYPE_IN                => cts_trg_type_i,
      TRG_NUMBER_IN              => cts_trg_number_i,
      TRG_INFORMATION_IN         => cts_trg_information_i,
      TRG_RND_CODE_IN            => cts_trg_rnd_code_i,
      TRG_STATUS_BITS_OUT        => cts_trg_statusbits_i,
      TRG_BUSY_OUT               => cts_trg_busy_i,

      --IPU Request
      IPU_SEND_IN                => cts_ipu_send_i,
      IPU_TYPE_IN                => cts_ipu_type_i,
      IPU_NUMBER_IN              => cts_ipu_number_i,
      IPU_INFORMATION_IN         => cts_ipu_information_i,
      IPU_RND_CODE_IN            => cts_ipu_rnd_code_i,
      -- Receiver port
      IPU_DATA_OUT               => cts_ipu_data_i,
      IPU_DATAREADY_OUT          => cts_ipu_dataready_i,
      IPU_READ_IN                => cts_ipu_read_i,
      IPU_STATUS_BITS_OUT        => cts_ipu_statusbits_i,
      IPU_BUSY_OUT               => cts_ipu_busy_i,

      -- Slow Control Data Port - registers for CTS logic
      REGIO_COMMON_STAT_REG_IN   => cts_common_stat_reg_i,
      REGIO_COMMON_CTRL_REG_OUT  => cts_common_ctrl_reg_i,
      REGIO_REGISTERS_IN         => cts_stat_reg_i,
      REGIO_REGISTERS_OUT        => cts_ctrl_reg_i,
      COMMON_STAT_REG_STROBE     => cts_common_stat_strobe_i,
      COMMON_CTRL_REG_STROBE     => cts_common_ctrl_strobe_i,
      STAT_REG_STROBE            => cts_stat_strobe_i,
      CTRL_REG_STROBE            => cts_ctrl_strobe_i,
      --Internal Data Port for CTS configuration
      REGIO_ADDR_OUT             => cts_regio_addr_i,
      REGIO_READ_ENABLE_OUT      => cts_regio_read_i,
      REGIO_WRITE_ENABLE_OUT     => cts_regio_write_i,
      REGIO_DATA_OUT             => cts_regio_data_out_i,
      REGIO_DATA_IN              => cts_regio_data_in_i,
      REGIO_DATAREADY_IN         => cts_regio_dataready_i,
      REGIO_NO_MORE_DATA_IN      => cts_regio_no_more_data_i,
      REGIO_WRITE_ACK_IN         => cts_regio_write_ack_i,
      REGIO_UNKNOWN_ADDR_IN      => cts_regio_unknown_addr_i,
      REGIO_TIMEOUT_OUT          => cts_regio_timeout_i,
      REGIO_ONEWIRE_INOUT        => open,
      REGIO_ONEWIRE_MONITOR_OUT  => open,
      REGIO_ONEWIRE_MONITOR_IN   => cts_regio_onewire_monitor_i,
      TRIGGER_MONITOR_IN         => '0',
      GLOBAL_TIME_OUT            => cts_global_time_i,
      LOCAL_TIME_OUT             => cts_local_time_i,
      TIME_SINCE_LAST_TRG_OUT    => open,
      TIMER_TICKS_OUT            => cts_timer_ticks_i,
      STAT_DEBUG_1               => open,
      STAT_DEBUG_2               => open
      );

---------------------------------------------------------------------------
-- Bus Handler on readout/slowcontrol endpoint
---------------------------------------------------------------------------
--  D000         spi status register
--  D001         spi ctrl register
--  D100 - D13F  spi memory

  THE_RDO_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 2,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", others => x"0000"),
      PORT_ADDR_MASK => (0 => 1,       1 => 6,       others => 0)
      )
    port map(
      CLK                   => clk_100,
      RESET                 => reset_i,

      DAT_ADDR_IN           => rdo_regio_addr_out,
      DAT_DATA_IN           => rdo_regio_data_out,
      DAT_DATA_OUT          => rdo_regio_data_in,
      DAT_READ_ENABLE_IN    => rdo_regio_read_enable_out,
      DAT_WRITE_ENABLE_IN   => rdo_regio_write_enable_out,
      DAT_TIMEOUT_IN        => rdo_regio_timeout_out,
      DAT_DATAREADY_OUT     => rdo_regio_dataready_in,
      DAT_WRITE_ACK_OUT     => rdo_regio_write_ack_in,
      DAT_NO_MORE_DATA_OUT  => rdo_regio_no_more_data_in,
      DAT_UNKNOWN_ADDR_OUT  => rdo_regio_unknown_addr_in,

    --Bus Handler (SPI CTRL)
      BUS_READ_ENABLE_OUT(0)               => spictrl_read_en,
      BUS_WRITE_ENABLE_OUT(0)              => spictrl_write_en,
      BUS_DATA_OUT(0*32+31 downto 0*32)    => spictrl_data_in,
      BUS_ADDR_OUT(0*16)                   => spictrl_addr,
      BUS_ADDR_OUT(0*16+15 downto 0*16+1)  => open,
      BUS_TIMEOUT_OUT(0)                   => open,
      BUS_DATA_IN(0*32+31 downto 0*32)     => spictrl_data_out,
      BUS_DATAREADY_IN(0)                  => spictrl_ack,
      BUS_WRITE_ACK_IN(0)                  => spictrl_ack,
      BUS_NO_MORE_DATA_IN(0)               => spictrl_busy,
      BUS_UNKNOWN_ADDR_IN(0)               => '0',
    --Bus Handler (SPI Memory)
      BUS_READ_ENABLE_OUT(1)               => spimem_read_en,
      BUS_WRITE_ENABLE_OUT(1)              => spimem_write_en,
      BUS_DATA_OUT(1*32+31 downto 1*32)    => spimem_data_in,
      BUS_ADDR_OUT(1*16+5 downto 1*16)     => spimem_addr,
      BUS_ADDR_OUT(1*16+15 downto 1*16+6)  => open,
      BUS_TIMEOUT_OUT(1)                   => open,
      BUS_DATA_IN(1*32+31 downto 1*32)     => spimem_data_out,
      BUS_DATAREADY_IN(1)                  => spimem_ack,
      BUS_WRITE_ACK_IN(1)                  => spimem_ack,
      BUS_NO_MORE_DATA_IN(1)               => '0',
      BUS_UNKNOWN_ADDR_IN(1)               => '0',
      STAT_DEBUG  => open
      );


---------------------------------------------------------------------------
-- SPI / Flash
---------------------------------------------------------------------------

  THE_SPI_MASTER: spi_master
    port map(
      CLK_IN         => clk_100,
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
      SPI_CS_OUT     => SPI_CS_OUT,
      SPI_SDI_IN     => SPI_SO_IN,
      SPI_SDO_OUT    => SPI_SI_OUT,
      SPI_SCK_OUT    => SPI_CLK_OUT,
      -- BRAM for read/write data
      BRAM_A_OUT     => spi_bram_addr,
      BRAM_WR_D_IN   => spi_bram_wr_d,
      BRAM_RD_D_OUT  => spi_bram_rd_d,
      BRAM_WE_OUT    => spi_bram_we,
      -- Status lines
      STAT           => open
      );

  -- data memory for SPI accesses
  THE_SPI_MEMORY: spi_databus_memory
    port map(
      CLK_IN        => clk_100,
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
  PROC_REBOOT : process (clk_100)
    begin
      if reset_i = '1' then
        PROGRAMN_OUT             <= '1';
        delayed_restart_fpga     <= '0';
        restart_fpga_counter     <= x"FFF";
      elsif rising_edge(clk_100) then
        PROGRAMN_OUT             <= not delayed_restart_fpga;
        delayed_restart_fpga     <= '0';
        if rdo_regio_common_ctrl_reg_i(15) = '1' then
          restart_fpga_counter   <= x"000";
        elsif restart_fpga_counter /= x"FFF" then
          restart_fpga_counter   <= restart_fpga_counter + 1;
          if restart_fpga_counter >= x"F00" then
            delayed_restart_fpga <= '1';
          end if;
        end if;
      end if;
    end process;

---------------------------------------------------------------------------
-- I/O connection
---------------------------------------------------------------------------

  ONEWIRE_MONITOR_OUT <= cts_regio_onewire_monitor_i;


---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  PROC_REG_LED : process(clk_100)
    begin
      if rising_edge(clk_100) then
        LED_TRB_OK <= not cts_med_stat_op(9);
        LED_TRB_RX <= not cts_med_stat_op(10);
        LED_TRB_TX <= not cts_med_stat_op(11);
        LED_GBE_OK <= not rdo_med_stat_op(9);
        LED_GBE_RX <= not rdo_med_stat_op(10);
        LED_GBE_TX <= not rdo_med_stat_op(11);
      end if;
    end process;

  LED_RED     <= '1';
  LED_YELLOW  <= '1';
  LED_GREEN   <= '1';
  LED_ORANGE  <= '1';


end architecture;
