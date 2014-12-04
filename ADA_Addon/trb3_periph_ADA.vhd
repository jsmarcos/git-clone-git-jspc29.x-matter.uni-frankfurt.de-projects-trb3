library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.config.all;
use work.tdc_version.all;
use work.version.all;


entity trb3_periph_ADA is
  port(
    --Clocks
    CLK_GPLL_LEFT        : in    std_logic;  --Clock Manager 1/(2468), 125 MHz
    CLK_GPLL_RIGHT       : in    std_logic;  --Clock Manager 2/(2468), 200 MHz  <-- MAIN CLOCK for FPGA
    CLK_PCLK_LEFT        : in    std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!
    CLK_PCLK_RIGHT       : in    std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!
    --Trigger
    TRIGGER_LEFT         : in    std_logic;  --left side trigger input from fan-out
    TRIGGER_RIGHT        : in    std_logic;  --right side trigger input from fan-out
    --Serdes
    CLK_SERDES_INT_LEFT  : in    std_logic;  --Clock Manager 1/(1357), off, 125 MHz possible
    CLK_SERDES_INT_RIGHT : in    std_logic;  --Clock Manager 2/(1357), 200 MHz, only in case of problems
    SERDES_INT_TX        : out   std_logic_vector(3 downto 0);
    SERDES_INT_RX        : in    std_logic_vector(3 downto 0);
    SERDES_ADDON_TX      : out   std_logic_vector(11 downto 0);
    SERDES_ADDON_RX      : in    std_logic_vector(11 downto 0);
    --Inter-FPGA Communication
    FPGA5_COMM           : inout std_logic_vector(11 downto 0);
                                        --Bit 0/1 input, serial link RX active
                                        --Bit 2/3 output, serial link TX active
    --Connection to ADA AddOn
    SPARE_LINE           : inout std_logic_vector(3 downto 0);  --inputs only
    INP                  : in    std_logic_vector(63 downto 0);
    --DAC
    DAC_SDO              : in    std_logic;
    DAC_SDI              : out   std_logic;
    DAC_SCK              : out   std_logic;
    DAC_CS               : out   std_logic_vector(4 downto 1);
    --Flash ROM & Reboot
    FLASH_CLK            : out   std_logic;
    FLASH_CS             : out   std_logic;
    FLASH_DIN            : out   std_logic;
    FLASH_DOUT           : in    std_logic;
    PROGRAMN             : out   std_logic;  --reboot FPGA
    --Misc
    TEMPSENS             : inout std_logic;  --Temperature Sensor
    CODE_LINE            : in    std_logic_vector(1 downto 0);
    LED_GREEN            : out   std_logic;
    LED_ORANGE           : out   std_logic;
    LED_RED              : out   std_logic;
    LED_YELLOW           : out   std_logic;
    SUPPL                : in    std_logic;  --terminated diff pair, PCLK, Pads
    --Test Connectors
    TEST_LINE            : out   std_logic_vector(15 downto 0)
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
  --important signals
  attribute syn_useioff of FLASH_CLK     : signal is true;
  attribute syn_useioff of FLASH_CS      : signal is true;
  attribute syn_useioff of FLASH_DIN     : signal is true;
  attribute syn_useioff of FLASH_DOUT    : signal is true;
  attribute syn_useioff of FPGA5_COMM    : signal is true;
  attribute syn_useioff of TEST_LINE     : signal is true;
  attribute syn_useioff of INP           : signal is false;
  attribute syn_useioff of SPARE_LINE    : signal is true;
  attribute syn_useioff of DAC_SDI       : signal is true;
  attribute syn_useioff of DAC_SDO       : signal is true;
  attribute syn_useioff of DAC_SCK       : signal is true;
  attribute syn_useioff of DAC_CS        : signal is true;

end entity;


architecture trb3_periph_ADA_arch of trb3_periph_ADA is
  --Constants
  constant REGIO_NUM_STAT_REGS : integer := 3;
  constant REGIO_NUM_CTRL_REGS : integer := 3;

  attribute syn_keep     : boolean;
  attribute syn_preserve : boolean;

  --Clock / Reset
  signal clk_100_i                : std_logic;  --clock for main logic, 100 MHz, via Clock Manager and internal PLL
  signal clk_200_i                : std_logic;  --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
  signal osc_int                  : std_logic;  -- clock for calibrating the tdc, 2.5 MHz, via internal osscilator
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
  --signal spictrl_read_en  : std_logic;
  --signal spictrl_write_en : std_logic;
  --signal spictrl_data_in  : std_logic_vector(31 downto 0);
  --signal spictrl_addr     : std_logic;
  --signal spictrl_data_out : std_logic_vector(31 downto 0);
  --signal spictrl_ack      : std_logic;
  --signal spictrl_busy     : std_logic;
  --signal spimem_read_en   : std_logic;
  --signal spimem_write_en  : std_logic;
  --signal spimem_data_in   : std_logic_vector(31 downto 0);
  --signal spimem_addr      : std_logic_vector(5 downto 0);
  --signal spimem_data_out  : std_logic_vector(31 downto 0);
  --signal spimem_ack       : std_logic;

  signal spimem_read_en          : std_logic;
  signal spimem_write_en         : std_logic;
  signal spimem_data_in          : std_logic_vector(31 downto 0);
  signal spimem_addr             : std_logic_vector(8 downto 0);
  signal spimem_data_out         : std_logic_vector(31 downto 0);
  signal spimem_dataready_out    : std_logic;
  signal spimem_no_more_data_out : std_logic;
  signal spimem_unknown_addr_out : std_logic;
  signal spimem_write_ack_out    : std_logic;

  signal spidac_read_en   : std_logic;
  signal spidac_write_en  : std_logic;
  signal spidac_data_in   : std_logic_vector(31 downto 0);
  signal spidac_addr      : std_logic_vector(4 downto 0);
  signal spidac_data_out  : std_logic_vector(31 downto 0);
  signal spidac_ack       : std_logic;
  signal spidac_busy      : std_logic;

  signal hitreg_read_en    : std_logic;
  signal hitreg_write_en   : std_logic;
  signal hitreg_addr       : std_logic_vector(6 downto 0);
  signal hitreg_data_out   : std_logic_vector(31 downto 0);
  signal hitreg_data_ready : std_logic;
  signal hitreg_invalid    : std_logic;

  signal srb_read_en    : std_logic;
  signal srb_write_en   : std_logic;
  signal srb_addr       : std_logic_vector(6 downto 0);
  signal srb_data_out   : std_logic_vector(31 downto 0);
  signal srb_data_ready : std_logic;
  signal srb_invalid    : std_logic;

  signal cdb_read_en    : std_logic;
  signal cdb_write_en   : std_logic;
  signal cdb_data_in    : std_logic_vector(31 downto 0);
  signal cdb_addr       : std_logic_vector(6 downto 0);
  signal cdb_data_out   : std_logic_vector(31 downto 0);
  signal cdb_data_ready : std_logic;
  signal cdb_invalid    : std_logic;

  signal lhb_read_en    : std_logic;
  signal lhb_write_en   : std_logic;
  signal lhb_addr       : std_logic_vector(6 downto 0);
  signal lhb_data_out   : std_logic_vector(31 downto 0);
  signal lhb_data_ready : std_logic;
  signal lhb_invalid    : std_logic;

  signal esb_read_en    : std_logic;
  signal esb_write_en   : std_logic;
  signal esb_addr       : std_logic_vector(6 downto 0);
  signal esb_data_out   : std_logic_vector(31 downto 0);
  signal esb_data_ready : std_logic;
  signal esb_invalid    : std_logic;

  signal efb_read_en    : std_logic;
  signal efb_write_en   : std_logic;
  signal efb_addr       : std_logic_vector(6 downto 0);
  signal efb_data_out   : std_logic_vector(31 downto 0);
  signal efb_data_ready : std_logic;
  signal efb_invalid    : std_logic;

  signal tdc_ctrl_read      : std_logic;
  signal last_tdc_ctrl_read : std_logic;
  signal tdc_ctrl_write     : std_logic;
  signal tdc_ctrl_addr      : std_logic_vector(2 downto 0);
  signal tdc_ctrl_data_in   : std_logic_vector(31 downto 0);
  signal tdc_ctrl_data_out  : std_logic_vector(31 downto 0);
  signal tdc_ctrl_reg       : std_logic_vector(5*32+31 downto 0);

  signal spi_bram_addr : std_logic_vector(7 downto 0);
  signal spi_bram_wr_d : std_logic_vector(7 downto 0);
  signal spi_bram_rd_d : std_logic_vector(7 downto 0);
  signal spi_bram_we   : std_logic;

  signal trig_out   : std_logic_vector(3 downto 0);
  signal trig_din   : std_logic_vector(31 downto 0);
  signal trig_dout  : std_logic_vector(31 downto 0);
  signal trig_write : std_logic                     := '0';
  signal trig_read  : std_logic                     := '0';
  signal trig_ack   : std_logic                     := '0';
  signal trig_nack  : std_logic                     := '0';
  signal trig_addr  : std_logic_vector(15 downto 0) := (others => '0');

  signal stat_din   : std_logic_vector(31 downto 0);
  signal stat_dout  : std_logic_vector(31 downto 0);
  signal stat_write : std_logic                     := '0';
  signal stat_read  : std_logic                     := '0';
  signal stat_ack   : std_logic                     := '0';
  signal stat_nack  : std_logic                     := '0';
  signal stat_addr  : std_logic_vector(15 downto 0) := (others => '0');

  signal sed_error : std_logic;
  signal bussed_rx : CTRLBUS_RX;
  signal bussed_tx : CTRLBUS_TX;  

  --TDC
  signal hit_in_i         : std_logic_vector(64 downto 1);
  signal logic_analyser_i : std_logic_vector(15 downto 0);

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

  -- internal oscillator with frequency of 2.5MHz for tdc calibration
  OSCInst0 : OSCF
    port map (
      OSC => osc_int);

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
      CTRL_DEBUG         => (others => '0')
      );

---------------------------------------------------------------------------
-- Endpoint
---------------------------------------------------------------------------
  
  THE_ENDPOINT : trb_net16_endpoint_hades_full_handler
    generic map(
      REGIO_NUM_STAT_REGS       => REGIO_NUM_STAT_REGS,
      REGIO_NUM_CTRL_REGS       => REGIO_NUM_CTRL_REGS,
      ADDRESS_MASK              => x"FFFF",
      BROADCAST_BITMASK         => x"FF",
      BROADCAST_SPECIAL_ADDR    => BROADCAST_SPECIAL_ADDR,
      REGIO_COMPILE_TIME        => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME, 32)),
      REGIO_HARDWARE_VERSION    => HARDWARE_INFO,
      REGIO_INCLUDED_FEATURES   => INCLUDED_FEATURES,
      REGIO_INIT_ADDRESS        => INIT_ADDRESS,
      REGIO_USE_VAR_ENDPOINT_ID => c_YES,
      CLOCK_FREQUENCY           => CLOCK_FREQUENCY,
      TIMING_TRIGGER_RAW        => c_YES,
      --Configure data handler
      DATA_INTERFACE_NUMBER     => 1,
      DATA_BUFFER_DEPTH         => 13,         --13
      DATA_BUFFER_WIDTH         => 32,
      DATA_BUFFER_FULL_THRESH   => 2**13-800,  --2**13-(maximal 2**12) 
      TRG_RELEASE_AFTER_DATA    => c_YES,
      HEADER_BUFFER_DEPTH       => 9,
      HEADER_BUFFER_FULL_THRESH => 2**9-16
      )
    port map(
      CLK                => clk_100_i,
      RESET              => reset_i,
      CLK_EN             => '1',
      MED_DATAREADY_OUT  => med_dataready_out,  -- open,  --
      MED_DATA_OUT       => med_data_out,  -- open,  --
      MED_PACKET_NUM_OUT => med_packet_num_out,  -- open,  --
      MED_READ_IN        => med_read_in,
      MED_DATAREADY_IN   => med_dataready_in,
      MED_DATA_IN        => med_data_in,
      MED_PACKET_NUM_IN  => med_packet_num_in,
      MED_READ_OUT       => med_read_out,  -- open,  --
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

  timing_trg_received_i <= TRIGGER_LEFT;  --TRIGGER_RIGHT;  --
  common_stat_reg       <= (others => '0');
  stat_reg              <= (others => '0');

---------------------------------------------------------------------------
-- AddOn
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 9,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"cf80", 2 => x"d400", 3 => x"c000", 4 => x"c100",
                         5 => x"c800", 6 => x"cf00", 7 => x"d500", 8 => x"c200", others => x"0000"),
      PORT_ADDR_MASK => (0 => 9, 1 => 7, 2 => 5, 3 => 7, 4 => 5,
                         5 => 3, 6 => 6, 7 => 4, 8 => 7, others => 0)
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

      ----Bus Handler (SPI CTRL)
      --BUS_READ_ENABLE_OUT(0)              => spictrl_read_en,
      --BUS_WRITE_ENABLE_OUT(0)             => spictrl_write_en,
      --BUS_DATA_OUT(0*32+31 downto 0*32)   => spictrl_data_in,
      --BUS_ADDR_OUT(0*16)                  => spictrl_addr,
      --BUS_ADDR_OUT(0*16+15 downto 0*16+1) => open,
      --BUS_TIMEOUT_OUT(0)                  => open,
      --BUS_DATA_IN(0*32+31 downto 0*32)    => spictrl_data_out,
      --BUS_DATAREADY_IN(0)                 => spictrl_ack,
      --BUS_WRITE_ACK_IN(0)                 => spictrl_ack,
      --BUS_NO_MORE_DATA_IN(0)              => spictrl_busy,
      --BUS_UNKNOWN_ADDR_IN(0)              => '0',
      ----Bus Handler (SPI Memory)
      --BUS_READ_ENABLE_OUT(1)              => spimem_read_en,
      --BUS_WRITE_ENABLE_OUT(1)             => spimem_write_en,
      --BUS_DATA_OUT(1*32+31 downto 1*32)   => spimem_data_in,
      --BUS_ADDR_OUT(1*16+5 downto 1*16)    => spimem_addr,
      --BUS_ADDR_OUT(1*16+15 downto 1*16+6) => open,
      --BUS_TIMEOUT_OUT(1)                  => open,
      --BUS_DATA_IN(1*32+31 downto 1*32)    => spimem_data_out,
      --BUS_DATAREADY_IN(1)                 => spimem_ack,
      --BUS_WRITE_ACK_IN(1)                 => spimem_ack,
      --BUS_NO_MORE_DATA_IN(1)              => '0',
      --BUS_UNKNOWN_ADDR_IN(1)              => '0',

      --Bus Handler (SPI Flash control)
      BUS_READ_ENABLE_OUT(0)              => spimem_read_en,
      BUS_WRITE_ENABLE_OUT(0)             => spimem_write_en,
      BUS_DATA_OUT(0*32+31 downto 0*32)   => spimem_data_in,
      BUS_ADDR_OUT(0*16+8 downto 0*16)    => spimem_addr,
      BUS_ADDR_OUT(0*16+15 downto 0*16+9) => open,
      BUS_TIMEOUT_OUT(0)                  => open,
      BUS_DATA_IN(0*32+31 downto 0*32)    => spimem_data_out,
      BUS_DATAREADY_IN(0)                 => spimem_dataready_out,
      BUS_WRITE_ACK_IN(0)                 => spimem_write_ack_out,
      BUS_NO_MORE_DATA_IN(0)              => spimem_no_more_data_out,
      BUS_UNKNOWN_ADDR_IN(0)              => spimem_unknown_addr_out,
      --Input statistics
      BUS_READ_ENABLE_OUT(1)              => stat_read,
      BUS_WRITE_ENABLE_OUT(1)             => stat_write,
      BUS_DATA_OUT(1*32+31 downto 1*32)   => stat_din,
      BUS_ADDR_OUT(1*16+15 downto 1*16)   => stat_addr,
      BUS_TIMEOUT_OUT(1)                  => open,
      BUS_DATA_IN(1*32+31 downto 1*32)    => stat_dout,
      BUS_DATAREADY_IN(1)                 => stat_ack,
      BUS_WRITE_ACK_IN(1)                 => stat_ack,
      BUS_NO_MORE_DATA_IN(1)              => '0',
      BUS_UNKNOWN_ADDR_IN(1)              => stat_nack,
      --Bus Handler (SPI DAC)
      BUS_READ_ENABLE_OUT(2)              => spidac_read_en,
      BUS_WRITE_ENABLE_OUT(2)             => spidac_write_en,
      BUS_DATA_OUT(2*32+31 downto 2*32)   => spidac_data_in,
      BUS_ADDR_OUT(2*16+4 downto 2*16)    => spidac_addr,
      BUS_ADDR_OUT(2*16+15 downto 2*16+5) => open,
      BUS_TIMEOUT_OUT(2)                  => open,
      BUS_DATA_IN(2*32+31 downto 2*32)    => spidac_data_out,
      BUS_DATAREADY_IN(2)                 => spidac_ack,
      BUS_WRITE_ACK_IN(2)                 => spidac_ack,
      BUS_NO_MORE_DATA_IN(2)              => spidac_busy,
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
      ----Encoder Start Registers
      --BUS_READ_ENABLE_OUT(5)              => esb_read_en,
      --BUS_WRITE_ENABLE_OUT(5)             => esb_write_en,
      --BUS_DATA_OUT(5*32+31 downto 5*32)   => open,
      --BUS_ADDR_OUT(5*16+6 downto 5*16)    => esb_addr,
      --BUS_ADDR_OUT(5*16+15 downto 5*16+7) => open,
      --BUS_TIMEOUT_OUT(5)                  => open,
      --BUS_DATA_IN(5*32+31 downto 5*32)    => esb_data_out,
      --BUS_DATAREADY_IN(5)                 => esb_data_ready,
      --BUS_WRITE_ACK_IN(5)                 => '0',
      --BUS_NO_MORE_DATA_IN(5)              => '0',
      --BUS_UNKNOWN_ADDR_IN(5)              => esb_invalid,
      ----Fifo Write Registers
      --BUS_READ_ENABLE_OUT(6)              => efb_read_en,
      --BUS_WRITE_ENABLE_OUT(6)             => efb_write_en,
      --BUS_DATA_OUT(6*32+31 downto 6*32)   => open,
      --BUS_ADDR_OUT(6*16+6 downto 6*16)    => efb_addr,
      --BUS_ADDR_OUT(6*16+15 downto 6*16+7) => open,
      --BUS_TIMEOUT_OUT(6)                  => open,
      --BUS_DATA_IN(6*32+31 downto 6*32)    => efb_data_out,
      --BUS_DATAREADY_IN(6)                 => efb_data_ready,
      --BUS_WRITE_ACK_IN(6)                 => '0',
      --BUS_NO_MORE_DATA_IN(6)              => '0',
      --BUS_UNKNOWN_ADDR_IN(6)              => efb_invalid,
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
      --TDC config registers
      BUS_READ_ENABLE_OUT(5)              => tdc_ctrl_read,
      BUS_WRITE_ENABLE_OUT(5)             => tdc_ctrl_write,
      BUS_DATA_OUT(5*32+31 downto 5*32)   => tdc_ctrl_data_in,
      BUS_ADDR_OUT(5*16+2 downto 5*16)    => tdc_ctrl_addr,
      BUS_ADDR_OUT(5*16+15 downto 5*16+3) => open,
      BUS_TIMEOUT_OUT(5)                  => open,
      BUS_DATA_IN(5*32+31 downto 5*32)    => tdc_ctrl_data_out,
      BUS_DATAREADY_IN(5)                 => last_tdc_ctrl_read,
      BUS_WRITE_ACK_IN(5)                 => tdc_ctrl_write,
      BUS_NO_MORE_DATA_IN(5)              => '0',
      BUS_UNKNOWN_ADDR_IN(5)              => '0',
      --Trigger logic registers
      BUS_READ_ENABLE_OUT(6)              => trig_read,
      BUS_WRITE_ENABLE_OUT(6)             => trig_write,
      BUS_DATA_OUT(6*32+31 downto 6*32)   => trig_din,
      BUS_ADDR_OUT(6*16+15 downto 6*16)   => trig_addr,
      BUS_TIMEOUT_OUT(6)                  => open,
      BUS_DATA_IN(6*32+31 downto 6*32)    => trig_dout,
      BUS_DATAREADY_IN(6)                 => trig_ack,
      BUS_WRITE_ACK_IN(6)                 => trig_ack,
      BUS_NO_MORE_DATA_IN(6)              => '0',
      BUS_UNKNOWN_ADDR_IN(6)              => trig_nack,
      --SEU Detection
      BUS_READ_ENABLE_OUT(7)              => bussed_rx.read,
      BUS_WRITE_ENABLE_OUT(7)             => bussed_rx.write,
      BUS_DATA_OUT(7*32+31 downto 7*32)   => bussed_rx.data,
      BUS_ADDR_OUT(7*16+15 downto 7*16)   => bussed_rx.addr,
      BUS_TIMEOUT_OUT(7)                  => bussed_rx.timeout,
      BUS_DATA_IN(7*32+31 downto 7*32)    => bussed_tx.data,
      BUS_DATAREADY_IN(7)                 => bussed_tx.ack,
      BUS_WRITE_ACK_IN(7)                 => bussed_tx.ack,
      BUS_NO_MORE_DATA_IN(7)              => bussed_tx.nack,
      BUS_UNKNOWN_ADDR_IN(7)              => bussed_tx.unknown,
      --Channel Debug Registers
      BUS_READ_ENABLE_OUT(8)              => cdb_read_en,
      BUS_WRITE_ENABLE_OUT(8)             => cdb_write_en,
      BUS_DATA_OUT(8*32+31 downto 8*32)   => open,
      BUS_ADDR_OUT(8*16+6 downto 8*16)    => cdb_addr,
      BUS_ADDR_OUT(8*16+15 downto 8*16+7) => open,
      BUS_TIMEOUT_OUT(8)                  => open,
      BUS_DATA_IN(8*32+31 downto 8*32)    => cdb_data_out,
      BUS_DATAREADY_IN(8)                 => cdb_data_ready,
      BUS_WRITE_ACK_IN(8)                 => '0',
      BUS_NO_MORE_DATA_IN(8)              => '0',
      BUS_UNKNOWN_ADDR_IN(8)              => cdb_invalid,

      

      STAT_DEBUG => open
      );

  PROC_TDC_CTRL_REG : process
    variable pos : integer;
  begin
    wait until rising_edge(clk_100_i);
    pos                := to_integer(unsigned(tdc_ctrl_addr))*32;
    tdc_ctrl_data_out  <= tdc_ctrl_reg(pos+31 downto pos);
    last_tdc_ctrl_read <= tdc_ctrl_read;
    if tdc_ctrl_write = '1' then
      tdc_ctrl_reg(pos+31 downto pos) <= tdc_ctrl_data_in;
    end if;
  end process;

---------------------------------------------------------------------------
-- SPI / Flash
---------------------------------------------------------------------------

  --THE_SPI_MASTER : spi_master
  --  port map(
  --    CLK_IN         => clk_100_i,
  --    RESET_IN       => reset_i,
  --    -- Slave bus
  --    BUS_READ_IN    => spictrl_read_en,
  --    BUS_WRITE_IN   => spictrl_write_en,
  --    BUS_BUSY_OUT   => spictrl_busy,
  --    BUS_ACK_OUT    => spictrl_ack,
  --    BUS_ADDR_IN(0) => spictrl_addr,
  --    BUS_DATA_IN    => spictrl_data_in,
  --    BUS_DATA_OUT   => spictrl_data_out,
  --    -- SPI connections
  --    SPI_CS_OUT     => FLASH_CS,
  --    SPI_SDI_IN     => FLASH_DOUT,
  --    SPI_SDO_OUT    => FLASH_DIN,
  --    SPI_SCK_OUT    => FLASH_CLK,
  --    -- BRAM for read/write data
  --    BRAM_A_OUT     => spi_bram_addr,
  --    BRAM_WR_D_IN   => spi_bram_wr_d,
  --    BRAM_RD_D_OUT  => spi_bram_rd_d,
  --    BRAM_WE_OUT    => spi_bram_we,
  --    -- Status lines
  --    STAT           => open
  --    );

  ---- data memory for SPI accesses
  --THE_SPI_MEMORY : spi_databus_memory
  --  port map(
  --    CLK_IN        => clk_100_i,
  --    RESET_IN      => reset_i,
  --    -- Slave bus
  --    BUS_ADDR_IN   => spimem_addr,
  --    BUS_READ_IN   => spimem_read_en,
  --    BUS_WRITE_IN  => spimem_write_en,
  --    BUS_ACK_OUT   => spimem_ack,
  --    BUS_DATA_IN   => spimem_data_in,
  --    BUS_DATA_OUT  => spimem_data_out,
  --    -- state machine connections
  --    BRAM_ADDR_IN  => spi_bram_addr,
  --    BRAM_WR_D_OUT => spi_bram_wr_d,
  --    BRAM_RD_D_IN  => spi_bram_rd_d,
  --    BRAM_WE_IN    => spi_bram_we,
  --    -- Status lines
  --    STAT          => open
  --    );

    THE_SPI_RELOAD : entity spi_flash_and_fpga_reload
    port map(
      CLK_IN   => clk_100_i,
      RESET_IN => reset_i,

      BUS_ADDR_IN          => spimem_addr,
      BUS_READ_IN          => spimem_read_en,
      BUS_WRITE_IN         => spimem_write_en,
      BUS_DATAREADY_OUT    => spimem_dataready_out,
      BUS_WRITE_ACK_OUT    => spimem_write_ack_out,
      BUS_UNKNOWN_ADDR_OUT => spimem_unknown_addr_out,
      BUS_NO_MORE_DATA_OUT => spimem_no_more_data_out,
      BUS_DATA_IN          => spimem_data_in,
      BUS_DATA_OUT         => spimem_data_out,

      DO_REBOOT_IN => common_ctrl_reg(15),
      PROGRAMN     => PROGRAMN,

      SPI_CS_OUT  => FLASH_CS,
      SPI_SCK_OUT => FLASH_CLK,
      SPI_SDO_OUT => FLASH_DIN,
      SPI_SDI_IN  => FLASH_DOUT
      );

-------------------------------------------------------------------------------
-- SPI
-------------------------------------------------------------------------------
  gen_SPI : if INCLUDE_SPI = 1 generate
    DAC_SPI : spi_ltc2600
      port map (
        CLK_IN                 => clk_100_i,
        RESET_IN               => reset_i,
        -- Slave bus
        BUS_READ_IN            => spidac_read_en,
        BUS_WRITE_IN           => spidac_write_en,
        BUS_BUSY_OUT           => spidac_busy,
        BUS_ACK_OUT            => spidac_ack,
        BUS_ADDR_IN            => spidac_addr,
        BUS_DATA_IN            => spidac_data_in,
        BUS_DATA_OUT           => spidac_data_out,
        -- SPI connections
        SPI_CS_OUT(3 downto 0) => DAC_CS,
        SPI_SDI_IN             => '0',
        SPI_SDO_OUT            => DAC_SDI,
        SPI_SCK_OUT            => DAC_SCK,
        SPI_CLR_OUT            => open);
  end generate;

---------------------------------------------------------------------------
-- Trigger logic
---------------------------------------------------------------------------
  gen_TRIGGER_LOGIC : if INCLUDE_TRIGGER_LOGIC = 1 generate
    THE_TRIG_LOGIC : entity input_to_trigger_logic
      generic map(
        INPUTS  => PHYSICAL_INPUTS,
        OUTPUTS => 4
        )
      port map(
        CLK => clk_100_i,

        INPUT  => INP(PHYSICAL_INPUTS-1 downto 0),
        OUTPUT => trig_out,

        DATA_IN  => trig_din,
        DATA_OUT => trig_dout,
        WRITE_IN => trig_write,
        READ_IN  => trig_read,
        ACK_OUT  => trig_ack,
        NACK_OUT => trig_nack,
        ADDR_IN  => trig_addr
        );
    -- Trigger on a TDC Channel
    FPGA5_COMM(10 downto 7) <= trig_out;
    FPGA5_COMM(6 downto 3)  <= (others => 'Z');
    FPGA5_COMM(1)           <= 'Z';
  end generate;

---------------------------------------------------------------------------
-- Reboot FPGA
---------------------------------------------------------------------------
  --THE_FPGA_REBOOT : fpga_reboot
  --  port map(
  --    CLK       => clk_100_i,
  --    RESET     => reset_i,
  --    DO_REBOOT => common_ctrl_reg(15),
  --    PROGRAMN  => PROGRAMN
  --    );

---------------------------------------------------------------------------
-- Input Statistics
---------------------------------------------------------------------------
  gen_STATISTICS : if INCLUDE_STATISTICS = 1 generate

    THE_STAT_LOGIC : entity input_statistics
      generic map(
        INPUTS => PHYSICAL_INPUTS
        )
      port map(
        CLK => clk_100_i,

        INPUT => INP(PHYSICAL_INPUTS-1 downto 0),

        DATA_IN  => stat_din,
        DATA_OUT => stat_dout,
        WRITE_IN => stat_write,
        READ_IN  => stat_read,
        ACK_OUT  => stat_ack,
        NACK_OUT => stat_nack,
        ADDR_IN  => stat_addr
        );
  end generate;

---------------------------------------------------------------------------
-- SED Detection
---------------------------------------------------------------------------
  THE_SED : entity sedcheck
    port map(
      CLK       => clk_100_i,
      ERROR_OUT => sed_error,
      BUS_RX    => bussed_rx,
      BUS_TX    => bussed_tx
      );  

---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  LED_GREEN  <= not med_stat_op(9);
  LED_ORANGE <= not med_stat_op(10);
  LED_RED    <= not INP(0);
  LED_YELLOW <= not med_stat_op(11);

---------------------------------------------------------------------------
-- Test Connector - Logic Analyser
---------------------------------------------------------------------------

  TEST_LINE <= logic_analyser_i;

-------------------------------------------------------------------------------
-- TDC
-------------------------------------------------------------------------------
  
  THE_TDC : entity TDC
    generic map (
      CHANNEL_NUMBER => NUM_TDC_CHANNELS,   -- Number of TDC channels
      STATUS_REG_NR  => 21,             -- Number of status regs
      CONTROL_REG_NR => 6,  -- Number of control regs - higher than 8 check tdc_ctrl_addr
      TDC_VERSION    => TDC_VERSION,         -- TDC version number
      DEBUG          => c_YES,
      SIMULATION     => c_NO)
    port map (
      RESET                 => reset_i,
      CLK_TDC               => CLK_PCLK_LEFT,  -- Clock used for the time measurement
      CLK_READOUT           => clk_100_i,   -- Clock for the readout
      REFERENCE_TIME        => timing_trg_received_i,   -- Reference time input
      HIT_IN                => hit_in_i(NUM_TDC_CHANNELS-1 downto 1),  -- Channel start signals
      HIT_CALIBRATION       => osc_int,     -- Hits for calibrating the TDC
      TRG_WIN_PRE           => tdc_ctrl_reg(42 downto 32),  -- Pre-Trigger window width
      TRG_WIN_POST          => tdc_ctrl_reg(58 downto 48),  -- Post-Trigger window width
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
      --Channel Debug Bus
      CDB_READ_EN_IN        => cdb_read_en,   -- bus read en strobe
      CDB_WRITE_EN_IN       => cdb_write_en,  -- bus write en strobe
      CDB_ADDR_IN           => cdb_addr,    -- bus address
      CDB_DATA_OUT          => cdb_data_out,  -- bus data
      CDB_DATAREADY_OUT     => cdb_data_ready,    -- bus data ready strobe
      CDB_UNKNOWN_ADDR_OUT  => cdb_invalid,   -- bus invalid addr
      --Encoder Start Registers Bus
      ESB_READ_EN_IN        => esb_read_en,   -- bus read en strobe
      ESB_WRITE_EN_IN       => esb_write_en,  -- bus write en strobe
      ESB_ADDR_IN           => esb_addr,    -- bus address
      ESB_DATA_OUT          => esb_data_out,  -- bus data
      ESB_DATAREADY_OUT     => esb_data_ready,    -- bus data ready strobe
      ESB_UNKNOWN_ADDR_OUT  => esb_invalid,   -- bus invalid addr
      --Fifo Write Registers Bus
      EFB_READ_EN_IN        => efb_read_en,   -- bus read en strobe
      EFB_WRITE_EN_IN       => efb_write_en,  -- bus write en strobe
      EFB_ADDR_IN           => efb_addr,    -- bus address
      EFB_DATA_OUT          => efb_data_out,  -- bus data
      EFB_DATAREADY_OUT     => efb_data_ready,    -- bus data ready strobe
      EFB_UNKNOWN_ADDR_OUT  => efb_invalid,   -- bus invalid addr
      --Lost Hit Registers Bus
      LHB_READ_EN_IN        => lhb_read_en,   -- bus read en strobe
      LHB_WRITE_EN_IN       => lhb_write_en,  -- bus write en strobe
      LHB_ADDR_IN           => lhb_addr,    -- bus address
      LHB_DATA_OUT          => lhb_data_out,  -- bus data
      LHB_DATAREADY_OUT     => lhb_data_ready,    -- bus data ready strobe
      LHB_UNKNOWN_ADDR_OUT  => lhb_invalid,   -- bus invalid addr
      --
      LOGIC_ANALYSER_OUT    => logic_analyser_i,
      CONTROL_REG_IN        => tdc_ctrl_reg);

  -- For single edge measurements
  gen_single : if DOUBLE_EDGE_TYPE = 0 or DOUBLE_EDGE_TYPE = 1 or DOUBLE_EDGE_TYPE = 3 generate
    hit_in_i <= INP;
  end generate;

  -- For ToT Measurements
  gen_double : if DOUBLE_EDGE_TYPE = 2 generate
    Gen_Hit_In_Signals : for i in 1 to 32 generate
      hit_in_i(i*2-1) <= INP(i-1);
      hit_in_i(i*2)   <= not INP(i-1);
    end generate Gen_Hit_In_Signals;
  end generate;

end architecture;
