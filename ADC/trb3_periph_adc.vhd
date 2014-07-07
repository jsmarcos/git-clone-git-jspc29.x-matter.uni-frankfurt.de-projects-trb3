library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.config.all;
use work.version.all;


entity trb3_periph_adc is
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

    --Connection to AddOn               
    ADC1_CH              : in std_logic_vector(4 downto 0);
    ADC2_CH              : in std_logic_vector(4 downto 0);
    ADC3_CH              : in std_logic_vector(4 downto 0);
    ADC4_CH              : in std_logic_vector(4 downto 0);
    ADC5_CH              : in std_logic_vector(4 downto 0);
    ADC6_CH              : in std_logic_vector(4 downto 0);
    ADC7_CH              : in std_logic_vector(4 downto 0);
    ADC8_CH              : in std_logic_vector(4 downto 0);
    ADC9_CH              : in std_logic_vector(4 downto 0);
    ADC10_CH             : in std_logic_vector(4 downto 0);
    ADC11_CH             : in std_logic_vector(4 downto 0);
    ADC12_CH             : in std_logic_vector(4 downto 0);
    ADC_DCO              : in std_logic_vector(12 downto 1);

    SPI_ADC_SCK          : out std_logic;
    SPI_ADC_SDIO         : inout std_logic;
    
    LMK_CLK              : out std_logic;
    LMK_DATA             : out std_logic;
    LMK_LE_1             : out std_logic;
    LMK_LE_2             : out std_logic;
    
    P_CLOCK              : out std_logic;
    
    FPGA_CS              : out std_logic_vector(1 downto 0);
    FPGA_SCK             : out std_logic_vector(1 downto 0);
    FPGA_SDI             : out std_logic_vector(1 downto 0);
    FPGA_SDO             : in  std_logic_vector(1 downto 0);
    
    --Flash ROM & Reboot
    FLASH_CLK  : out   std_logic;
    FLASH_CS   : out   std_logic;
    FLASH_DIN  : out   std_logic;
    FLASH_DOUT : in    std_logic;
    PROGRAMN   : out   std_logic;       --reboot FPGA
    --Misc
    TEMPSENS   : inout std_logic;       --Temperature Sensor
    CODE_LINE  : in    std_logic_vector(1 downto 0);
    LED_GREEN  : out   std_logic;
    LED_ORANGE : out   std_logic;
    LED_RED    : out   std_logic;
    LED_YELLOW : out   std_logic;
    SUPPL      : in    std_logic;       --terminated diff pair, PCLK, Pads
    --Test Connectors
    TEST_LINE  : out   std_logic_vector(15 downto 0)
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

  

end entity;


architecture trb3_periph_adc_arch of trb3_periph_adc is

  attribute syn_keep     : boolean;
  attribute syn_preserve : boolean;

  --Clock / Reset
  signal clk_100_i                : std_logic;  --clock for main logic, 100 MHz, via Clock Manager and internal PLL
  signal clk_200_i                : std_logic;  --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
  signal clk_125_i                : std_logic;  -- 125 MHz, via Clock Manager and bypassed PLL
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
  signal common_stat_reg_strobe : std_logic_vector(std_COMSTATREG-1 downto 0);
  signal common_ctrl_reg_strobe : std_logic_vector(std_COMCTRLREG-1 downto 0);

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
  signal spimem_read_en          : std_logic;
  signal spimem_write_en         : std_logic;
  signal spimem_data_in          : std_logic_vector(31 downto 0);
  signal spimem_addr             : std_logic_vector(8 downto 0);
  signal spimem_data_out         : std_logic_vector(31 downto 0);
  signal spimem_dataready_out    : std_logic;
  signal spimem_no_more_data_out : std_logic;
  signal spimem_unknown_addr_out : std_logic;
  signal spimem_write_ack_out    : std_logic;

  --SPI to MachXO FPGA (and LMK01010, and ADC SPI) 
  signal spifpga_read_en   : std_logic;
  signal spifpga_write_en  : std_logic;
  signal spifpga_data_in   : std_logic_vector(31 downto 0);
  signal spifpga_addr      : std_logic_vector(4 downto 0);
  signal spifpga_data_out  : std_logic_vector(31 downto 0);
  signal spifpga_ack       : std_logic;
  signal spifpga_busy      : std_logic;

  signal spi_cs        					   : std_logic_vector(15 downto 0);
  signal spi_sdi, spi_sdo, spi_sck : std_logic;
  
  signal clk_adcfast_i     : std_logic;
  signal clk_adcref_i      : std_logic;
  signal debug_adc         : std_logic_vector(31 downto 0);
  signal adc_restart_i     : std_logic;

  signal adc_data : std_logic_vector(479 downto 0);

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
      REGIO_NUM_STAT_REGS       => 0,
      REGIO_NUM_CTRL_REGS       => 0,
      ADDRESS_MASK              => x"FFFF",
      BROADCAST_BITMASK         => x"48",
      BROADCAST_SPECIAL_ADDR    => BROADCAST_SPECIAL_ADDR,
      REGIO_COMPILE_TIME        => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME, 32)),
      REGIO_HARDWARE_VERSION    => HARDWARE_INFO,
      REGIO_INIT_ADDRESS        => INIT_ADDRESS,
      REGIO_USE_VAR_ENDPOINT_ID => c_YES,
      CLOCK_FREQUENCY           => CLOCK_FREQUENCY,
      TIMING_TRIGGER_RAW        => c_YES,
      --Configure data handler
      DATA_INTERFACE_NUMBER     => 1,
      DATA_BUFFER_DEPTH         => 13,           --13
      DATA_BUFFER_WIDTH         => 32,
      DATA_BUFFER_FULL_THRESH   => 2**13-800,    --2**13-(maximal 2**12) 
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
      REGIO_STAT_REG_IN                  => (others => '0'),
      REGIO_CTRL_REG_OUT                 => open,
      REGIO_STAT_STROBE_OUT              => open,
      REGIO_CTRL_STROBE_OUT              => open,
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


---------------------------------------------------------------------------
-- AddOn
---------------------------------------------------------------------------
THE_ADC : entity work.adc_ad9219
  generic map(
    CHANNELS      => 4,
    DEVICES_LEFT  => 7,
    DEVICES_RIGHT => 5,
    RESOLUTION    => 10
    )
  port map(
    CLK        => clk_100_i,
    CLK_ADCRAW => CLK_PCLK_RIGHT,
    CLK_ADCREF => clk_adcref_i,
    CLK_ADCDAT => clk_adcfast_i,
    RESTART_IN => adc_restart_i,
    ADCCLK_OUT => P_CLOCK,
    
    ADC_DATA( 4 downto  0)   => ADC1_CH,
    ADC_DATA( 9 downto  5)   => ADC2_CH,
    ADC_DATA(14 downto 10)   => ADC3_CH,
    ADC_DATA(19 downto 15)   => ADC4_CH,
    ADC_DATA(24 downto 20)   => ADC5_CH,
    ADC_DATA(29 downto 25)   => ADC6_CH,
    ADC_DATA(34 downto 30)   => ADC7_CH,
    ADC_DATA(39 downto 35)   => ADC8_CH,
    ADC_DATA(44 downto 40)   => ADC9_CH,
    ADC_DATA(49 downto 45)   => ADC10_CH,
    ADC_DATA(54 downto 50)   => ADC11_CH,
    ADC_DATA(59 downto 55)   => ADC12_CH,
    
    ADC_DCO    => ADC_DCO,
    
    DATA_OUT       => adc_data,
    FCO_OUT        => open,
    DATA_VALID_OUT => open,
    DEBUG          => debug_adc
    );

adc_restart_i <= '0';

---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 2,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"d400",  others => x"0000"),
      PORT_ADDR_MASK => (0 => 9,       1 => 5,        others => 0)
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
      --Bus Handler (SPI to FPGA)
      BUS_READ_ENABLE_OUT(1)              => spifpga_read_en,
      BUS_WRITE_ENABLE_OUT(1)             => spifpga_write_en,
      BUS_DATA_OUT(1*32+31 downto 1*32)   => spifpga_data_in,
      BUS_ADDR_OUT(1*16+4 downto 1*16)    => spifpga_addr,
      BUS_ADDR_OUT(1*16+15 downto 1*16+5) => open,
      BUS_TIMEOUT_OUT(1)                  => open,
      BUS_DATA_IN(1*32+31 downto 1*32)    => spifpga_data_out,
      BUS_DATAREADY_IN(1)                 => spifpga_ack,
      BUS_WRITE_ACK_IN(1)                 => spifpga_ack,
      BUS_NO_MORE_DATA_IN(1)              => spifpga_busy,
      BUS_UNKNOWN_ADDR_IN(1)              => '0',

      STAT_DEBUG => open
      );


---------------------------------------------------------------------------
-- SPI / Flash
---------------------------------------------------------------------------

THE_SPI_RELOAD : entity work.spi_flash_and_fpga_reload
  port map(
    CLK_IN               => clk_100_i,
    RESET_IN             => reset_i,
    
    BUS_ADDR_IN          => spimem_addr,
    BUS_READ_IN          => spimem_read_en,
    BUS_WRITE_IN         => spimem_write_en,
    BUS_DATAREADY_OUT    => spimem_dataready_out,
    BUS_WRITE_ACK_OUT    => spimem_write_ack_out,
    BUS_UNKNOWN_ADDR_OUT => spimem_unknown_addr_out,
    BUS_NO_MORE_DATA_OUT => spimem_no_more_data_out,
    BUS_DATA_IN          => spimem_data_in,
    BUS_DATA_OUT         => spimem_data_out,
    
    DO_REBOOT_IN         => common_ctrl_reg(15),     
    PROGRAMN             => PROGRAMN,
    
    SPI_CS_OUT           => FLASH_CS,
    SPI_SCK_OUT          => FLASH_CLK,
    SPI_SDO_OUT          => FLASH_DIN,
    SPI_SDI_IN           => FLASH_DOUT
    );

-------------------------------------------------------------------------------
-- SPI
-------------------------------------------------------------------------------

  FPGA_SPI : spi_ltc2600
	  generic map (
		  BITS       => 32,
		  WAITCYCLES => 15)
	  port map (
		  CLK_IN         => clk_100_i,
		  RESET_IN       => reset_i,
		  -- Slave bus
		  BUS_READ_IN    => spifpga_read_en,
		  BUS_WRITE_IN   => spifpga_write_en,
		  BUS_BUSY_OUT   => spifpga_busy,
		  BUS_ACK_OUT    => spifpga_ack,
		  BUS_ADDR_IN    => spifpga_addr,
		  BUS_DATA_IN    => spifpga_data_in,
		  BUS_DATA_OUT   => spifpga_data_out,
		  -- SPI connections
		  SPI_CS_OUT  => spi_CS,
		  SPI_SDI_IN  => spi_SDI,
		  SPI_SDO_OUT => spi_SDO,
		  SPI_SCK_OUT => spi_SCK,
		  SPI_CLR_OUT => open
		  );

  -- the bits spi_CS (chip select) determines which SPI device is to be programmed
  -- it is already inverted, such that spi_CS=0xffff when nothing is to be programmed
  -- since the CS of the ADCs can only be controlled via the FPGA,
  -- we multiplex the SDI/O and SCK lines according to CS. This way we can control
  -- when which SPI device should be addressed via software

  FPGA_CS_mux: process (spi_CS(2 downto 0)) is
	begin  -- process FPGA_CS_mux
		case spi_CS(2 downto 0) is
			when b"110"  =>
				FPGA_CS <= b"00";
			when b"101"  =>
				FPGA_CS <= b"01";
			when b"011"  =>
				FPGA_CS <= b"10";				
			when others =>
				FPGA_CS <= b"11";
		end case;
	end process FPGA_CS_mux;
  
  FPGA_SCK(0) <= spi_SCK     when spi_CS(2 downto 0) /= b"111" else '1';
  FPGA_SDI(0) <= spi_SDO     when spi_CS(2 downto 0) /= b"111" else '0';
  spi_SDI     <= FPGA_SDO(0) when spi_CS(2 downto 0) /= b"111" else '0';
  
  SPI_ADC_SCK         <= spi_SCK when spi_CS(3) = '0' else '1';
  SPI_ADC_SDIO        <= spi_SDO when spi_CS(3) = '0' else '0';
  
  LMK_CLK             <= spi_SCK when spi_CS(5 downto 4) /= b"11" else '1' ;
  LMK_DATA            <= spi_SDO when spi_CS(5 downto 4) /= b"11" else '0' ;
  LMK_LE_1            <= spi_CS(4); -- active low
  LMK_LE_2            <= spi_CS(5); -- active low
  

---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
LED_GREEN  <= not med_stat_op(9);
LED_ORANGE <= not med_stat_op(10);
LED_RED    <= not or_all(debug_adc) when rising_edge(clk_100_i);
LED_YELLOW <= not med_stat_op(11);

---------------------------------------------------------------------------
-- Test Connector - Logic Analyser
---------------------------------------------------------------------------

  TEST_LINE <= (others => '0');

end architecture;
