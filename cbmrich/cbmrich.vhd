library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;



entity cbmrich is
  port(
    --Clocks
    CLK_GPLL_LEFT  : in std_logic;      --Clock Manager 6
    CLK_GPLL_RIGHT : in std_logic;  --Clock Manager 4  <-- MAIN CLOCK for FPGA
    CLK_PCLK_LEFT  : in std_logic;      --Clock Manager 3
    CLK_PCLK_RIGHT : in std_logic;      --Clock Manager 1
    --CLK_PCLK_RIGHT is the only clock with external termination !?
    CLK_EXTERNAL   : in std_logic;      --Clock Manager 9


--     --Trigger
--     TRIGGER_LEFT  : in std_logic;       --left side trigger input from fan-out
--     TRIGGER_RIGHT : in std_logic;       --right side trigger input from fan-out

    --Serdes
    CLK_SERDES_INT_RIGHT : in    std_logic;  --Clock Manager 0, not used
    SERDES_TX            : out   std_logic_vector(1 downto 0);
    SERDES_RX            : in    std_logic_vector(1 downto 0);
    SFP_TXDIS            : out   std_logic;
    SFP_MOD              : inout std_logic_vector(2 downto 0);
    SFP_LOS              : in    std_logic;

    --Connections
    SPARE_LINE : inout std_logic_vector(2 downto 0);  --LVDS, ext. termination, 1 used for trigger
    LVDS       : inout std_logic_vector(2 downto 1);
    INPUT      : in    std_logic_vector(64 downto 1);

    --Flash ROM & Reboot
    FLASH_CLK  : out std_logic;
    FLASH_CS   : out std_logic;
    FLASH_DIN  : out std_logic;
    FLASH_DOUT : in  std_logic;
    PROGRAMN   : out std_logic;         --reboot FPGA

    --DAC
    DAC_SDO       : in    std_logic;
    DAC_SDI       : out   std_logic;
    DAC_SCK       : out   std_logic;
    DAC_CS        : out   std_logic;
    --Misc
    TEMPSENS      : inout std_logic;    --Temperature Sensor
    LED_GREEN     : out   std_logic;
    LED_ORANGE    : out   std_logic;
    LED_RED       : out   std_logic;
    LED_YELLOW    : out   std_logic;
    LED_CLK_GREEN : out   std_logic;
    LED_CLK_RED   : out   std_logic;
    LED_SFP_GREEN : out   std_logic;
    LED_SFP_RED   : out   std_logic;

    CLK_MNGR_USER : inout std_logic_vector(3 downto 0);

    --Test Connectors
    TEST_LINE : out std_logic_vector(15 downto 0)
    );


  attribute syn_useioff                  : boolean;
  --no IO-FF for LEDs relaxes timing constraints
  attribute syn_useioff of LED_GREEN     : signal is false;
  attribute syn_useioff of LED_ORANGE    : signal is false;
  attribute syn_useioff of LED_RED       : signal is false;
  attribute syn_useioff of LED_YELLOW    : signal is false;
  attribute syn_useioff of LED_CLK_GREEN : signal is false;
  attribute syn_useioff of LED_CLK_RED   : signal is false;
  attribute syn_useioff of LED_SFP_RED   : signal is false;
  attribute syn_useioff of LED_SFP_GREEN : signal is false;
  attribute syn_useioff of TEMPSENS      : signal is false;
  attribute syn_useioff of PROGRAMN      : signal is false;

  --important signals _with_ IO-FF
  attribute syn_useioff of DAC_SCK    : signal is true;
  attribute syn_useioff of DAC_CS     : signal is true;
  attribute syn_useioff of DAC_SDI    : signal is true;
  attribute syn_useioff of DAC_SDO    : signal is true;
  attribute syn_useioff of FLASH_CLK  : signal is true;
  attribute syn_useioff of FLASH_CS   : signal is true;
  attribute syn_useioff of FLASH_DIN  : signal is true;
  attribute syn_useioff of FLASH_DOUT : signal is true;
  attribute syn_useioff of TEST_LINE  : signal is true;
  attribute syn_useioff of SPARE_LINE : signal is true;
  attribute syn_useioff of LVDS       : signal is true;


end entity;

architecture cbmrich_arch of cbmrich is
  --Constants
  constant REGIO_NUM_STAT_REGS : integer := 5;
  constant REGIO_NUM_CTRL_REGS : integer := 3;

  attribute syn_keep     : boolean;
  attribute syn_preserve : boolean;

  --Clock / Reset
  signal clk_100_i                : std_logic;  --clock for main logic, 100 MHz, via Clock Manager and internal PLL
  signal clk_200_i                : std_logic;  --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
  signal pll_lock                 : std_logic;  --Internal PLL locked. E.g. used to reset all internal logic.
  signal clear_i                  : std_logic;
  signal reset_i                  : std_logic;
  signal GSR_N                    : std_logic;
  attribute syn_keep of GSR_N     : signal is true;
  attribute syn_preserve of GSR_N : signal is true;

  --Media Interface
  signal med_stat_op        : std_logic_vector (1*16-1 downto 0);
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
  signal timing_trg_received_i  : std_logic;
  signal trg_data_valid_i       : std_logic;
  signal trg_timing_valid_i     : std_logic;
  signal trg_notiming_valid_i   : std_logic;
  signal trg_invalid_i          : std_logic;
  signal trg_type_i             : std_logic_vector(3 downto 0);
  signal trg_number_i           : std_logic_vector(15 downto 0);
  signal trg_code_i             : std_logic_vector(7 downto 0);
  signal trg_information_i      : std_logic_vector(23 downto 0);
  signal trg_int_number_i       : std_logic_vector(15 downto 0);
  signal trg_multiple_trg_i     : std_logic;
  signal trg_timeout_detected_i : std_logic;
  signal trg_spurious_trg_i     : std_logic;
  signal trg_missing_tmg_trg_i  : std_logic;
  signal trg_spike_detected_i   : std_logic;

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

  signal dac_read_en  : std_logic;
  signal dac_write_en : std_logic;
  signal dac_data_in  : std_logic_vector(31 downto 0);
  signal dac_addr     : std_logic_vector(4 downto 0);
  signal dac_data_out : std_logic_vector(31 downto 0);
  signal dac_ack      : std_logic;
  signal dac_busy     : std_logic;

  signal hitreg_read_en    : std_logic;
  signal hitreg_write_en   : std_logic;
  signal hitreg_data_in    : std_logic_vector(31 downto 0);
  signal hitreg_addr       : std_logic_vector(6 downto 0);
  signal hitreg_data_out   : std_logic_vector(31 downto 0);
  signal hitreg_data_ready : std_logic;
  signal hitreg_invalid    : std_logic;

  signal srb_read_en    : std_logic;
  signal srb_write_en   : std_logic;
  signal srb_data_in    : std_logic_vector(31 downto 0);
  signal srb_addr       : std_logic_vector(6 downto 0);
  signal srb_data_out   : std_logic_vector(31 downto 0);
  signal srb_data_ready : std_logic;
  signal srb_invalid    : std_logic;

  signal lhb_read_en    : std_logic;
  signal lhb_write_en   : std_logic;
  signal lhb_data_in    : std_logic_vector(31 downto 0);
  signal lhb_addr       : std_logic_vector(6 downto 0);
  signal lhb_data_out   : std_logic_vector(31 downto 0);
  signal lhb_data_ready : std_logic;
  signal lhb_invalid    : std_logic;

  signal esb_read_en    : std_logic;
  signal esb_write_en   : std_logic;
  signal esb_data_in    : std_logic_vector(31 downto 0);
  signal esb_addr       : std_logic_vector(6 downto 0);
  signal esb_data_out   : std_logic_vector(31 downto 0);
  signal esb_data_ready : std_logic;
  signal esb_invalid    : std_logic;

  signal fwb_read_en    : std_logic;
  signal fwb_write_en   : std_logic;
  signal fwb_data_in    : std_logic_vector(31 downto 0);
  signal fwb_addr       : std_logic_vector(6 downto 0);
  signal fwb_data_out   : std_logic_vector(31 downto 0);
  signal fwb_data_ready : std_logic;
  signal fwb_invalid    : std_logic;


  signal spi_bram_addr : std_logic_vector(7 downto 0);
  signal spi_bram_wr_d : std_logic_vector(7 downto 0);
  signal spi_bram_rd_d : std_logic_vector(7 downto 0);
  signal spi_bram_we   : std_logic;


  --FPGA Test
  signal time_counter : unsigned(31 downto 0);

  --TDC
  signal hit_in_i : std_logic_vector(64 downto 1);

begin
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
      LOCK  => pll_lock
      );


---------------------------------------------------------------------------
-- The TrbNet media interface (to other FPGA)
---------------------------------------------------------------------------
  THE_MEDIA_UPLINK : trb_net16_med_ecp3_sfp
    generic map(
      SERDES_NUM  => 0,                 --number of serdes in quad
      EXT_CLOCK   => c_NO,              --use internal clock
      USE_200_MHZ => c_YES,             --run on 200 MHz clock
      USE_CTC     => c_YES              --CTC required
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
      SD_RXD_P_IN        => SERDES_RX(0),
      SD_RXD_N_IN        => SERDES_RX(1),
      SD_TXD_P_OUT       => SERDES_TX(0),
      SD_TXD_N_OUT       => SERDES_TX(1),
      SD_REFCLK_P_IN     => open,
      SD_REFCLK_N_IN     => open,
      SD_PRSNT_N_IN      => SFP_MOD(0),
      SD_LOS_IN          => SFP_LOS,
      SD_TXDIS_OUT       => SFP_TXDIS,
      -- Status and control port
      STAT_OP            => med_stat_op,
      CTRL_OP            => med_ctrl_op,
      STAT_DEBUG         => med_stat_debug,
      CTRL_DEBUG         => (others => '0')
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
      BROADCAST_SPECIAL_ADDR    => x"50",
      REGIO_COMPILE_TIME        => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME, 32)),
      REGIO_HARDWARE_VERSION    => x"92000000",
      REGIO_INIT_ADDRESS        => x"f300",
      REGIO_USE_VAR_ENDPOINT_ID => c_YES,
      CLOCK_FREQUENCY           => 100,
      TIMING_TRIGGER_RAW        => c_YES,
      --Configure data handler
      DATA_INTERFACE_NUMBER     => 1,
      DATA_BUFFER_DEPTH         => 13,  --13
      DATA_BUFFER_WIDTH         => 32,
      DATA_BUFFER_FULL_THRESH   => 2**13-800,
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
      TRG_MULTIPLE_TRG_OUT     => trg_multiple_trg_i,
      TRG_TIMEOUT_DETECTED_OUT => trg_timeout_detected_i,
      TRG_SPURIOUS_TRG_OUT     => trg_spurious_trg_i,
      TRG_MISSING_TMG_TRG_OUT  => trg_missing_tmg_trg_i,
      TRG_SPIKE_DETECTED_OUT   => trg_spike_detected_i,

      --Response from FEE
      FEE_TRG_RELEASE_IN(0)       => fee_trg_release_i,
      FEE_TRG_STATUSBITS_IN       => fee_trg_statusbits_i,
      FEE_DATA_IN                 => fee_data_i,
      FEE_DATA_WRITE_IN(0)        => fee_data_write_i,
      FEE_DATA_FINISHED_IN(0)     => fee_data_finished_i,
      FEE_DATA_ALMOST_FULL_OUT(0) => fee_almost_full_i,

      -- Slow Control Data Port
      REGIO_COMMON_STAT_REG_IN     => common_stat_reg,  --0x00
      REGIO_COMMON_CTRL_REG_OUT    => common_ctrl_reg,  --0x20
      REGIO_COMMON_STAT_STROBE_OUT => common_stat_reg_strobe,
      REGIO_COMMON_CTRL_STROBE_OUT => common_ctrl_reg_strobe,
      REGIO_STAT_REG_IN            => stat_reg,         --start 0x80
      REGIO_CTRL_REG_OUT           => ctrl_reg,         --start 0xc0
      REGIO_STAT_STROBE_OUT        => stat_reg_strobe,
      REGIO_CTRL_STROBE_OUT        => ctrl_reg_strobe,
      REGIO_VAR_ENDPOINT_ID        => (others => '0'),

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
-- I/O
---------------------------------------------------------------------------
  timing_trg_received_i <= SPARE_LINE(0);

---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 7,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", 2 => x"d400", 3 => x"c000", 4 => x"c100", 5 => x"c200", 6 => x"c300", others => x"0000"),
      PORT_ADDR_MASK => (0 => 1, 1 => 6, 2 => 5, 3 => 7, 4 => 5, 5 => 7, 6 => 7, others => 0)
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
      --DAC
      BUS_READ_ENABLE_OUT(2)              => dac_read_en,
      BUS_WRITE_ENABLE_OUT(2)             => dac_write_en,
      BUS_DATA_OUT(2*32+31 downto 2*32)   => dac_data_in,
      BUS_ADDR_OUT(2*16+4 downto 2*16)    => dac_addr,
      BUS_ADDR_OUT(2*16+15 downto 2*16+5) => open,
      BUS_TIMEOUT_OUT(2)                  => open,
      BUS_DATA_IN(2*32+31 downto 2*32)    => dac_data_out,
      BUS_DATAREADY_IN(2)                 => dac_ack,
      BUS_WRITE_ACK_IN(2)                 => dac_ack,
      BUS_NO_MORE_DATA_IN(2)              => dac_busy,
      BUS_UNKNOWN_ADDR_IN(2)              => '0',
      --HitRegisters
      BUS_READ_ENABLE_OUT(3)              => hitreg_read_en,
      BUS_WRITE_ENABLE_OUT(3)             => hitreg_write_en,
      BUS_DATA_OUT(3*32+31 downto 3*32)   => open,
      BUS_ADDR_OUT(3*16+6 downto 3*16)    => hitreg_addr,
      BUS_ADDR_OUT(3*16+15 downto 3*16+7) => open,
      BUS_TIMEOUT_OUT(3)                  => open,
      BUS_DATA_IN(3*32+31 downto 3*32)    => hitreg_data_out,
      BUS_DATAREADY_IN(3)                 => hitreg_data_ready,
      BUS_WRITE_ACK_IN(3)                 => '0',
      BUS_NO_MORE_DATA_IN(3)              => '0',
      BUS_UNKNOWN_ADDR_IN(3)              => hitreg_invalid,
      --Status Registers
      BUS_READ_ENABLE_OUT(4)              => srb_read_en,
      BUS_WRITE_ENABLE_OUT(4)             => srb_write_en,
      BUS_DATA_OUT(4*32+31 downto 4*32)   => open,
      BUS_ADDR_OUT(4*16+6 downto 4*16)    => srb_addr,
      BUS_ADDR_OUT(4*16+15 downto 4*16+7) => open,
      BUS_TIMEOUT_OUT(4)                  => open,
      BUS_DATA_IN(4*32+31 downto 4*32)    => srb_data_out,
      BUS_DATAREADY_IN(4)                 => srb_data_ready,
      BUS_WRITE_ACK_IN(4)                 => '0',
      BUS_NO_MORE_DATA_IN(4)              => '0',
      BUS_UNKNOWN_ADDR_IN(4)              => srb_invalid,
      --Encoder Start Registers
      BUS_READ_ENABLE_OUT(5)              => esb_read_en,
      BUS_WRITE_ENABLE_OUT(5)             => esb_write_en,
      BUS_DATA_OUT(5*32+31 downto 5*32)   => open,
      BUS_ADDR_OUT(5*16+6 downto 5*16)    => esb_addr,
      BUS_ADDR_OUT(5*16+15 downto 5*16+7) => open,
      BUS_TIMEOUT_OUT(5)                  => open,
      BUS_DATA_IN(5*32+31 downto 5*32)    => esb_data_out,
      BUS_DATAREADY_IN(5)                 => esb_data_ready,
      BUS_WRITE_ACK_IN(5)                 => '0',
      BUS_NO_MORE_DATA_IN(5)              => '0',
      BUS_UNKNOWN_ADDR_IN(5)              => esb_invalid,
      --Fifo Write Registers
      BUS_READ_ENABLE_OUT(6)              => fwb_read_en,
      BUS_WRITE_ENABLE_OUT(6)             => fwb_write_en,
      BUS_DATA_OUT(6*32+31 downto 6*32)   => open,
      BUS_ADDR_OUT(6*16+6 downto 6*16)    => fwb_addr,
      BUS_ADDR_OUT(6*16+15 downto 6*16+7) => open,
      BUS_TIMEOUT_OUT(6)                  => open,
      BUS_DATA_IN(6*32+31 downto 6*32)    => fwb_data_out,
      BUS_DATAREADY_IN(6)                 => fwb_data_ready,
      BUS_WRITE_ACK_IN(6)                 => '0',
      BUS_NO_MORE_DATA_IN(6)              => '0',
      BUS_UNKNOWN_ADDR_IN(6)              => fwb_invalid,
      ----Lost Hit Registers
      --BUS_READ_ENABLE_OUT(7)              => lhb_read_en,
      --BUS_WRITE_ENABLE_OUT(7)             => lhb_write_en,
      --BUS_DATA_OUT(7*32+31 downto 7*32)   => open,
      --BUS_ADDR_OUT(7*16+6 downto 7*16)    => lhb_addr,
      --BUS_ADDR_OUT(7*16+15 downto 7*16+7) => open,
      --BUS_TIMEOUT_OUT(7)                  => open,
      --BUS_DATA_IN(7*32+31 downto 7*32)    => lhb_data_out,
      --BUS_DATAREADY_IN(7)                 => lhb_data_ready,
      --BUS_WRITE_ACK_IN(7)                 => '0',
      --BUS_NO_MORE_DATA_IN(7)              => '0',
      --BUS_UNKNOWN_ADDR_IN(7)              => lhb_invalid,

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
-- DAC
---------------------------------------------------------------------------      
  THE_DAC_SPI : spi_ltc2600
    port map(
      CLK_IN        => clk_100_i,
      RESET_IN      => reset_i,
      -- Slave bus
      BUS_ADDR_IN   => dac_addr,
      BUS_READ_IN   => dac_read_en,
      BUS_WRITE_IN  => dac_write_en,
      BUS_ACK_OUT   => dac_ack,
      BUS_BUSY_OUT  => dac_busy,
      BUS_DATA_IN   => dac_data_in,
      BUS_DATA_OUT  => dac_data_out,
      -- SPI connections
      SPI_CS_OUT(0) => DAC_CS,
      SPI_SDI_IN    => DAC_SDO,
      SPI_SDO_OUT   => DAC_SDI,
      SPI_SCK_OUT   => DAC_SCK
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
  LED_GREEN     <= not time_counter(24);
  LED_ORANGE    <= not time_counter(25);
  LED_RED       <= not time_counter(26);
  LED_YELLOW    <= not time_counter(27);
  LED_SFP_GREEN <= not med_stat_op(9);
  LED_SFP_RED   <= not (med_stat_op(10) or med_stat_op(11));

---------------------------------------------------------------------------
-- Test Connector
---------------------------------------------------------------------------    
  TEST_LINE(15 downto 1) <= INPUT(15 downto 1);
  TEST_LINE(0)           <= SPARE_LINE(0);


  LVDS(1) <= or_all(INPUT);
  LVDS(2) <= SPARE_LINE(0);

---------------------------------------------------------------------------
-- Test Circuits
---------------------------------------------------------------------------
  process
  begin
    wait until rising_edge(clk_100_i);
    time_counter <= time_counter + 1;
  end process;

-------------------------------------------------------------------------------
-- TDC
-------------------------------------------------------------------------------
  THE_TDC : TDC
    generic map (
      CHANNEL_NUMBER => 65,             -- Number of TDC channels
      STATUS_REG_NR  => REGIO_NUM_STAT_REGS,
      CONTROL_REG_NR => REGIO_NUM_CTRL_REGS)
    port map (
      RESET                 => reset_i,
      CLK_TDC               => CLK_PCLK_LEFT,  -- Clock used for the time measurement
      CLK_READOUT           => clk_100_i,   -- Clock for the readout
      REFERENCE_TIME        => timing_trg_received_i,  -- Reference time input
      HIT_IN                => hit_in_i(64 downto 1),  -- Channel start signals
      TRG_WIN_PRE           => ctrl_reg(42 downto 32),  -- Pre-Trigger window width
      TRG_WIN_POST          => ctrl_reg(58 downto 48),  -- Post-Trigger window width
      --
      -- Trigger signals from handler
      TRG_DATA_VALID_IN     => trg_data_valid_i,  -- trig data valid signal from trbnet
      VALID_TIMING_TRG_IN   => trg_timing_valid_i,  -- valid timing trigger signal from trbnet
      VALID_NOTIMING_TRG_IN => trg_notiming_valid_i,  -- valid notiming signal from trbnet
      INVALID_TRG_IN        => trg_invalid_i,  -- invalid trigger signal from trbnet
      TMGTRG_TIMEOUT_IN     => trg_timeout_detected_i,  -- timing trigger timeout signal from trbnet
      SPIKE_DETECTED_IN     => trg_spike_detected_i,
      MULTI_TMG_TRG_IN      => trg_multiple_trg_i,
      SPURIOUS_TRG_IN       => trg_spurious_trg_i,
      --
      TRG_NUMBER_IN         => trg_number_i,  -- LVL1 trigger information package
      TRG_CODE_IN           => trg_code_i,  --
      TRG_INFORMATION_IN    => trg_information_i,   --
      TRG_TYPE_IN           => trg_type_i,  -- LVL1 trigger information package
      --
      --Response to handler
      TRG_RELEASE_OUT       => fee_trg_release_i,   -- trigger release signal
      TRG_STATUSBIT_OUT     => fee_trg_statusbits_i,  -- status information of the tdc
      DATA_OUT              => fee_data_i,  -- tdc data
      DATA_WRITE_OUT        => fee_data_write_i,  -- data valid signal
      DATA_FINISHED_OUT     => fee_data_finished_i,  -- readout finished signal
      --
      --Hit Counter Bus
      HCB_READ_EN_IN        => hitreg_read_en,    -- bus read en strobe
      HCB_WRITE_EN_IN       => hitreg_write_en,   -- bus write en strobe
      HCB_ADDR_IN           => hitreg_addr,   -- bus address
      HCB_DATA_OUT          => hitreg_data_out,   -- bus data
      HCB_DATAREADY_OUT     => hitreg_data_ready,   -- bus data ready strobe
      HCB_UNKNOWN_ADDR_OUT  => hitreg_invalid,    -- bus invalid addr
      --Status Registers Bus
      SRB_READ_EN_IN        => srb_read_en,   -- bus read en strobe
      SRB_WRITE_EN_IN       => srb_write_en,  -- bus write en strobe
      SRB_ADDR_IN           => srb_addr,    -- bus address
      SRB_DATA_OUT          => srb_data_out,  -- bus data
      SRB_DATAREADY_OUT     => srb_data_ready,    -- bus data ready strobe
      SRB_UNKNOWN_ADDR_OUT  => srb_invalid,   -- bus invalid addr
      --Encoder Start Registers Bus
      ESB_READ_EN_IN        => esb_read_en,   -- bus read en strobe
      ESB_WRITE_EN_IN       => esb_write_en,  -- bus write en strobe
      ESB_ADDR_IN           => esb_addr,    -- bus address
      ESB_DATA_OUT          => esb_data_out,  -- bus data
      ESB_DATAREADY_OUT     => esb_data_ready,    -- bus data ready strobe
      ESB_UNKNOWN_ADDR_OUT  => esb_invalid,   -- bus invalid addr
      --Fifo Write Registers Bus
      FWB_READ_EN_IN        => fwb_read_en,   -- bus read en strobe
      FWB_WRITE_EN_IN       => fwb_write_en,  -- bus write en strobe
      FWB_ADDR_IN           => fwb_addr,    -- bus address
      FWB_DATA_OUT          => fwb_data_out,  -- bus data
      FWB_DATAREADY_OUT     => fwb_data_ready,    -- bus data ready strobe
      FWB_UNKNOWN_ADDR_OUT  => fwb_invalid,   -- bus invalid addr
      --Lost Hit Registers Bus
      LHB_READ_EN_IN        => '0',  -- lhb_read_en,   -- bus read en strobe
      LHB_WRITE_EN_IN       => '0',  -- lhb_write_en,  -- bus write en strobe
      LHB_ADDR_IN           => (others => '0'),  -- lhb_addr,    -- bus address
      LHB_DATA_OUT          => open,  -- lhb_data_out,  -- bus data
      LHB_DATAREADY_OUT     => open,  -- lhb_data_ready,    -- bus data ready strobe
      LHB_UNKNOWN_ADDR_OUT  => open,  -- lhb_invalid,   -- bus invalid addr
      --
      LOGIC_ANALYSER_OUT    => open,    --TEST_LINE,
      CONTROL_REG_IN        => ctrl_reg);


--  hit_in_i <= INPUT;

  -- to detect rising & falling edges
  Gen_Hit_In_Signals : for i in 1 to 32 generate
    hit_in_i(i*2-1) <= INPUT(i);
    hit_in_i(i*2)   <= not INPUT(i);
  end generate Gen_Hit_In_Signals;

end architecture;
