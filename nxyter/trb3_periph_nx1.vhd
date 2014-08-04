library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;
use work.nxyter_components.all;

library ecp3;
use ecp3.components.all;


entity trb3_periph is
  port(
    --Clocks
    CLK_GPLL_RIGHT            : in    std_logic;  --Clock Manager 2/(2468), 200 MHz  <-- MAIN CLOCK for FPGA
    CLK_GPLL_LEFT        : in    std_logic;  --Clock Manager 1/(2468), 125 MHz
    CLK_PCLK_LEFT        : in    std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL left!
    CLK_PCLK_RIGHT       : in    std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!
    --Trigger
    TRIGGER_LEFT         : in    std_logic;  --left side trigger input from fan-out
    TRIGGER_RIGHT        : in    std_logic;  --Den Da nehmen sagt Jan midestend
                                             -- , right side trigger input from fan-out
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
    
    ---------------------------------------------------------------------------
    -- BEGIN AddonBoard nXyter
    ---------------------------------------------------------------------------
    --Connections to NXYTER-FEB 1

    NX1_RESET_OUT              : out   std_logic;     
    NX1_I2C_SDA_INOUT          : inout std_logic;
    NX1_I2C_SCL_INOUT          : inout std_logic;
    NX1_I2C_SM_RESET_OUT       : inout std_logic;
    NX1_I2C_REG_RESET_OUT      : out   std_logic;
    NX1_SPI_SCLK_OUT           : out   std_logic;
    NX1_SPI_SDIO_INOUT         : inout std_logic;
    NX1_SPI_CSB_OUT            : out   std_logic;
    NX1_DATA_CLK_IN            : in    std_logic;
    NX1_TIMESTAMP_IN           : in    std_logic_vector (7 downto 0);
    NX1_MAIN_CLK_OUT           : out   std_logic;
    NX1_TESTPULSE_OUT          : out   std_logic;
    NX1_TS_HOLD_OUT            : out   std_logic;
    NX1_ADC_FCLK_IN            : in    std_logic;
    NX1_ADC_DCLK_IN            : in    std_logic;
    NX1_ADC_SAMPLE_CLK_OUT     : out   std_logic;
    NX1_ADC_A_IN               : in    std_logic;
    NX1_ADC_B_IN               : in    std_logic;
    NX1_ADC_NX_IN              : in    std_logic;
    NX1_ADC_D_IN               : in    std_logic;
    NX1B_ADC_FCLK_IN           : in    std_logic;
    NX1B_ADC_DCLK_IN           : in    std_logic;
    NX1B_ADC_A_IN              : in    std_logic;
    NX1B_ADC_B_IN              : in    std_logic;
    NX1B_ADC_NX_IN             : in    std_logic;
    NX1B_ADC_D_IN              : in    std_logic;

    ---------------------------------------------------------------------------
    -- END AddonBoard nXyter
    ---------------------------------------------------------------------------
    
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
    TEST_LINE            : out   std_logic_vector(15 downto 0);
    NX1_DEBUG_LINE       : out   std_logic_vector(15 downto 0)
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
  attribute syn_useioff of TEST_LINE     : signal is false;
  attribute syn_useioff of NX1_DEBUG_LINE  : signal is false;
  --attribute syn_useioff of INP           : signal is false;
  attribute syn_useioff of NX1_TIMESTAMP_IN   : signal is true;

  --attribute syn_useioff of NX1_ADC_NX_IN   : signal is true;
  --attribute syn_useioff of NX1_ADC_D_IN    : signal is true;
  
  --attribute syn_useioff of NX1_ADC_NX_IN   : signal is true;
  --attribute syn_useioff of DAC_SDO       : signal is true;
  --attribute syn_useioff of DAC_SDI       : signal is true;
  --attribute syn_useioff of DAC_SCK       : signal is true;
  --attribute syn_useioff of DAC_CS        : signal is true;


end entity;


architecture trb3_periph_arch of trb3_periph is

  constant NUM_NXYTER : integer := 1;
    
  -- For 250MHz PLL nxyter clock, THE_32M_ODDR_1
  attribute ODDRAPPS : string;
  attribute ODDRAPPS of THE_NX_MAIN_ODDR_1       : label is "SCLK_ALIGNED";
  -- attribute ODDRAPPS of THE_ADC_SAMPLE_ODDR_1    : label is "SCLK_ALIGNED";

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
  signal fee_trg_release_i      : std_logic_vector(NUM_NXYTER-1 downto 0);
  signal fee_trg_statusbits_i   : std_logic_vector(NUM_NXYTER*32-1 downto 0);
  signal fee_data_i             : std_logic_vector(NUM_NXYTER*32-1 downto 0);
  signal fee_data_write_i       : std_logic_vector(NUM_NXYTER-1 downto 0);
  signal fee_data_finished_i    : std_logic_vector(NUM_NXYTER-1 downto 0);
  signal fee_almost_full_i      : std_logic_vector(NUM_NXYTER-1 downto 0);

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
  signal spidac_read_en   : std_logic;
  signal spidac_write_en  : std_logic;
  signal spidac_data_in   : std_logic_vector(31 downto 0);
  signal spidac_addr      : std_logic_vector(4 downto 0);
  signal spidac_data_out  : std_logic_vector(31 downto 0);
  signal spidac_ack       : std_logic;
  signal spidac_busy      : std_logic;

  signal dac_cs_i  : std_logic_vector(3 downto 0);
  signal dac_sck_i : std_logic;
  signal dac_sdi_i : std_logic;

  signal spi_bram_addr : std_logic_vector(7 downto 0);
  signal spi_bram_wr_d : std_logic_vector(7 downto 0);
  signal spi_bram_rd_d : std_logic_vector(7 downto 0);
  signal spi_bram_we   : std_logic;

  --FPGA Test

  signal time_counter : unsigned(31 downto 0);

  -- SED Detection
  signal sed_error  : std_logic;
  signal sed_din    : std_logic_vector(31 downto 0);
  signal sed_dout   : std_logic_vector(31 downto 0);
  signal sed_write  : std_logic := '0';
  signal sed_read   : std_logic := '0';
  signal sed_ack    : std_logic := '0';
  signal sed_nack   : std_logic := '0';
  signal sed_addr   : std_logic_vector(15 downto 0) := (others => '0');
  
  -- nXyter-FEB-Board Clocks
  signal nx_main_clk                : std_logic;
  signal nx_pll_clk_lock            : std_logic;
  signal nx_pll_reset               : std_logic;
  
  signal NX_CLK_ADC_DAT            : std_logic;
  signal nx_pll_adc_clk_lock       : std_logic;
  signal nx1_adc_sample_clk         : std_logic;

  -- nXyter 1 Regio Bus
  signal nx1_regio_addr_in           : std_logic_vector (15 downto 0);
  signal nx1_regio_data_in           : std_logic_vector (31 downto 0);
  signal nx1_regio_data_out          : std_logic_vector (31 downto 0);
  signal nx1_regio_read_enable_in    : std_logic;
  signal nx1_regio_write_enable_in   : std_logic;
  signal nx1_regio_timeout_in        : std_logic;
  signal nx1_regio_dataready_out     : std_logic;
  signal nx1_regio_write_ack_out     : std_logic;
  signal nx1_regio_no_more_data_out  : std_logic;
  signal nx1_regio_unknown_addr_out  : std_logic;

  signal nx1_debug_line_o            : std_logic_vector(15 downto 0);
  
  -- Internal Trigger
  signal fee1_trigger                : std_logic;

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
      CLK_IN        => CLK_PCLK_RIGHT,   -- raw master clock, NOT from PLL/DLL!
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
  THE_MAIN_PLL : entity work.pll_in200_out100
    port map(
      CLK     => CLK_PCLK_RIGHT,
      RESET   => '0',
      CLKOP   => clk_100_i,
      CLKOK   => clk_200_i,
      LOCK    => pll_lock
      );


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
      CLK                => CLK_PCLK_RIGHT,
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
      REGIO_NUM_STAT_REGS       => REGIO_NUM_STAT_REGS,  --4,  --16 stat reg
      REGIO_NUM_CTRL_REGS       => REGIO_NUM_CTRL_REGS,  --3,  --8 cotrol reg
      ADDRESS_MASK              => x"FFFF",
      BROADCAST_BITMASK         => x"FF",
      BROADCAST_SPECIAL_ADDR    => x"49",
      REGIO_COMPILE_TIME        => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME, 32)),
      REGIO_HARDWARE_VERSION    => x"9100_6000",
      REGIO_INIT_ADDRESS        => x"3800",
      REGIO_USE_VAR_ENDPOINT_ID => c_YES,
      CLOCK_FREQUENCY           => 100,
      TIMING_TRIGGER_RAW        => c_YES,

      -- Feature Register, see TRB# Docu page 12
      REGIO_INCLUDED_FEATURES   => x"0101_0000_0000_0000",
      
      --Configure data handler
      DATA_INTERFACE_NUMBER     => NUM_NXYTER,
      DATA_BUFFER_DEPTH         => 13,         --13
      DATA_BUFFER_WIDTH         => 32,
      DATA_BUFFER_FULL_THRESH   => 2**13-800,  --2**13-1024
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
      --LVL1 trigger to FEB
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

      --Response from FEB, i.e. nXyter #0
      FEE_TRG_RELEASE_IN(0)                       => fee_trg_release_i(0),
      FEE_TRG_STATUSBITS_IN(0*32+31  downto 0*32) => fee_trg_statusbits_i(0*32+31 downto 0*32),
      FEE_DATA_IN(0*32+31  downto 0*32)           => fee_data_i(0*32+31 downto 0*32),
      FEE_DATA_WRITE_IN(0)                        => fee_data_write_i(0),
      FEE_DATA_FINISHED_IN(0)                     => fee_data_finished_i(0),
      FEE_DATA_ALMOST_FULL_OUT(0)                 => fee_almost_full_i(0),

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

  timing_trg_received_i <= TRIGGER_LEFT;
  
---------------------------------------------------------------------------
-- AddOn
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 4,
      PORT_ADDRESSES => (0 => x"d000",
                         1 => x"d100",
                         2 => x"8000",
                         3 => x"d500",
                         others => x"0000"),
      PORT_ADDR_MASK => (0 => 1,
                         1 => 6,
                         2 => 12,
                         3 => 4,
                         others => 0)
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

      --Bus Handler (nXyter1 trb_net16_regio_bus_handler)
      BUS_READ_ENABLE_OUT(2)               => nx1_regio_read_enable_in,
      BUS_WRITE_ENABLE_OUT(2)              => nx1_regio_write_enable_in,
      BUS_DATA_OUT(2*32+31 downto 2*32)    => nx1_regio_data_in,
      BUS_ADDR_OUT(2*16+11 downto 2*16)    => nx1_regio_addr_in(11 downto 0),
      BUS_ADDR_OUT(2*16+15 downto 2*16+12) => open,
      BUS_TIMEOUT_OUT(2)                   => open,  --nx1_regio_timeout_in,
      BUS_DATA_IN(2*32+31 downto 2*32)     => nx1_regio_data_out,
      BUS_DATAREADY_IN(2)                  => nx1_regio_dataready_out,
      BUS_WRITE_ACK_IN(2)                  => nx1_regio_write_ack_out,
      BUS_NO_MORE_DATA_IN(2)               => nx1_regio_no_more_data_out,
      BUS_UNKNOWN_ADDR_IN(2)               => nx1_regio_unknown_addr_out,

      BUS_READ_ENABLE_OUT(3)              => sed_read,
      BUS_WRITE_ENABLE_OUT(3)             => sed_write,
      BUS_DATA_OUT(3*32+31 downto 3*32)   => sed_din,
      BUS_ADDR_OUT(3*16+15 downto 3*16)   => sed_addr,
      BUS_TIMEOUT_OUT(3)                  => open,
      BUS_DATA_IN(3*32+31 downto 3*32)    => sed_dout,
      BUS_DATAREADY_IN(3)                 => sed_ack,
      BUS_WRITE_ACK_IN(3)                 => sed_ack,
      BUS_NO_MORE_DATA_IN(3)              => '0',
      BUS_UNKNOWN_ADDR_IN(3)              => sed_nack,
      
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
  LED_GREEN  <= not med_stat_op(9);
  LED_ORANGE <= not med_stat_op(10);
  LED_RED    <= timing_trg_received_i;
  LED_YELLOW <= not med_stat_op(11);

-----------------------------------------------------------------------------
-- The xXyter-FEB #1
-----------------------------------------------------------------------------

  nXyter_FEE_board_0: nXyter_FEE_board
    generic map (
      BOARD_ID => "01"
      )
    port map (
      CLK_IN                     => clk_100_i,
      RESET_IN                   => reset_i,
      CLK_NX_MAIN_IN             => nx_main_clk,
      CLK_ADC_IN                 => NX_CLK_ADC_DAT,
      PLL_NX_CLK_LOCK_IN         => nx_pll_clk_lock,
      PLL_ADC_DCLK_LOCK_IN       => nx_pll_adc_clk_lock,
      PLL_RESET_OUT              => nx_pll_reset,
      
      TRIGGER_OUT                => fee1_trigger,                       
      
      I2C_SDA_INOUT              => NX1_I2C_SDA_INOUT,
      I2C_SCL_INOUT              => NX1_I2C_SCL_INOUT,
      I2C_SM_RESET_OUT           => NX1_I2C_SM_RESET_OUT,
      I2C_REG_RESET_OUT          => NX1_I2C_REG_RESET_OUT,
                                 
      SPI_SCLK_OUT               => NX1_SPI_SCLK_OUT,
      SPI_SDIO_INOUT             => NX1_SPI_SDIO_INOUT,
      SPI_CSB_OUT                => NX1_SPI_CSB_OUT,
                                 
      NX_DATA_CLK_IN             => NX1_DATA_CLK_IN,
      NX_TIMESTAMP_IN            => NX1_TIMESTAMP_IN,
                                 
      NX_RESET_OUT               => NX1_RESET_OUT,
      NX_TESTPULSE_OUT           => NX1_TESTPULSE_OUT,
      NX_TIMESTAMP_TRIGGER_OUT   => NX1_TS_HOLD_OUT,
      
      ADC_FCLK_IN(0)             => NX1_ADC_FCLK_IN,
      ADC_FCLK_IN(1)             => NX1B_ADC_FCLK_IN,
      ADC_DCLK_IN(0)             => NX1_ADC_DCLK_IN,
      ADC_DCLK_IN(1)             => NX1B_ADC_DCLK_IN,
      ADC_SAMPLE_CLK_OUT         => nx1_adc_sample_clk,
      ADC_A_IN(0)                => NX1_ADC_A_IN,
      ADC_A_IN(1)                => NX1B_ADC_A_IN,
      ADC_B_IN(0)                => NX1_ADC_B_IN,
      ADC_B_IN(1)                => NX1B_ADC_B_IN,
      ADC_NX_IN(0)               => NX1_ADC_NX_IN,
      ADC_NX_IN(1)               => NX1B_ADC_NX_IN,
      ADC_D_IN(0)                => NX1_ADC_D_IN,
      ADC_D_IN(1)                => NX1B_ADC_D_IN,

      TIMING_TRIGGER_IN          => TRIGGER_RIGHT, 
      LVL1_TRG_DATA_VALID_IN     => trg_data_valid_i,
      LVL1_VALID_TIMING_TRG_IN   => trg_timing_valid_i,
      LVL1_VALID_NOTIMING_TRG_IN => trg_notiming_valid_i,
      LVL1_INVALID_TRG_IN        => trg_invalid_i,
      LVL1_TRG_TYPE_IN           => trg_type_i,
      LVL1_TRG_NUMBER_IN         => trg_number_i,
      LVL1_TRG_CODE_IN           => trg_code_i,
      LVL1_TRG_INFORMATION_IN    => trg_information_i,
      LVL1_INT_TRG_NUMBER_IN     => trg_int_number_i,
      
      FEE_TRG_RELEASE_OUT        => fee_trg_release_i(0),
      FEE_TRG_STATUSBITS_OUT     => fee_trg_statusbits_i(31 downto 0),
      FEE_DATA_OUT               => fee_data_i(31 downto 0),
      FEE_DATA_WRITE_OUT         => fee_data_write_i(0),
      FEE_DATA_FINISHED_OUT      => fee_data_finished_i(0),
      FEE_DATA_ALMOST_FULL_IN    => fee_almost_full_i(0),
      
      REGIO_ADDR_IN              => nx1_regio_addr_in,
      REGIO_DATA_IN              => nx1_regio_data_in,
      REGIO_DATA_OUT             => nx1_regio_data_out,
      REGIO_READ_ENABLE_IN       => nx1_regio_read_enable_in,
      REGIO_WRITE_ENABLE_IN      => nx1_regio_write_enable_in,
      REGIO_TIMEOUT_IN           => nx1_regio_timeout_in,
      REGIO_DATAREADY_OUT        => nx1_regio_dataready_out,
      REGIO_WRITE_ACK_OUT        => nx1_regio_write_ack_out,
      REGIO_NO_MORE_DATA_OUT     => nx1_regio_no_more_data_out,
      REGIO_UNKNOWN_ADDR_OUT     => nx1_regio_unknown_addr_out,
                                 
      DEBUG_LINE_OUT             => nx1_debug_line_o
      --DEBUG_LINE_OUT                => open
      );

  TEST_LINE                     <= nx1_debug_line_o;
  NX1_DEBUG_LINE                <= nx1_debug_line_o;

  FPGA5_COMM(10)                <= fee1_trigger;

  ---------------------------------------------------------------------------
  -- SED Detection
  ---------------------------------------------------------------------------

  THE_SED : entity work.sedcheck
    port map(
      CLK        => clk_100_i,
      ERROR_OUT  => sed_error,
    
      DATA_IN    => sed_din,
      DATA_OUT   => sed_dout, 
      WRITE_IN   => sed_write,
      READ_IN    => sed_read,
      ACK_OUT    => sed_ack,  
      NACK_OUT   => sed_nack, 
      ADDR_IN    => sed_addr
      );
  
  -----------------------------------------------------------------------------
  -- nXyter Main and ADC Clocks
  -----------------------------------------------------------------------------

  -- nXyter Main Clock (250MHz)
  pll_nx_clk250_1: entity work.pll_nx_clk250
    port map (
      CLK   => CLK_PCLK_RIGHT,
      RESET => nx_pll_reset,
      CLKOP => nx_main_clk,
      LOCK  => nx_pll_clk_lock
      );
  
  -- Port FF for Nxyter Main Clocks
  THE_NX_MAIN_ODDR_1: ODDRXD1
    port map(
      SCLK  => nx_main_clk,
      DA    => '1',
      DB    => '0',
      Q     => NX1_MAIN_CLK_OUT
      );
  
  NX1_ADC_SAMPLE_CLK_OUT <= nx1_adc_sample_clk;
  
  -- ADC Receiver Clock (nXyter Main Clock * 3/4 (187.5), must be 
  -- based on same ClockSource as nXyter Main Clock)
  pll_adc_clk_1: pll_adc_clk
    port map (
      CLK   => CLK_PCLK_RIGHT,
      RESET => nx_pll_reset,
      CLKOP => NX_CLK_ADC_DAT,
      LOCK  => nx_pll_adc_clk_lock
      );

end architecture;
