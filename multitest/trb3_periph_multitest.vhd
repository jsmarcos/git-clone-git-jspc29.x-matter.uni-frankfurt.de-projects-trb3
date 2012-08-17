library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;
use work.lattice_ecp2m_fifo.all;



entity trb3_periph_multitest is
  port(
    --Clocks
    CLK_GPLL_LEFT  : in std_logic;  --Clock Manager 2/(2468), 200 MHz  <-- MAIN CLOCK for FPGA
    CLK_GPLL_RIGHT : in std_logic;      --Clock Manager 1/(2468), 125 MHz
    CLK_PCLK_LEFT  : in std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!
    CLK_PCLK_RIGHT : in std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!

    --Trigger
    TRIGGER_LEFT  : in std_logic;       --left side trigger input from fan-out
    TRIGGER_RIGHT : in std_logic;       --right side trigger input from fan-out

    --Serdes
    CLK_SERDES_INT_LEFT  : in  std_logic;  --Clock Manager 1/(1357), off, 125 MHz possible
    CLK_SERDES_INT_RIGHT : in  std_logic;  --Clock Manager 2/(1357), 200 MHz, only in case of problems
    SERDES_INT_TX        : out std_logic_vector(3 downto 0);
    SERDES_INT_RX        : in  std_logic_vector(3 downto 0);
--     SERDES_ADDON_TX      : out std_logic_vector(11 downto 0);
--     SERDES_ADDON_RX      : in  std_logic_vector(11 downto 0);

    --Inter-FPGA Communication
    FPGA5_COMM : inout std_logic_vector(11 downto 0);
                                                      --Bit 0/1 input, serial link RX active
                                                      --Bit 2/3 output, serial link TX active
                                                      --others yet undefined
    --Connection to AddOn
    MADC1_CLK  : out   std_logic;
    MADC1_FCO  : in    std_logic;
    MADC1_DCO  : in    std_logic;
    MADC1_D    : in    std_logic_vector(8 downto 1);
    MADC1_SCLK : out   std_logic;
    MADC1_SDIO : inout std_logic;
    -- MADC1_CSB  : out   std_logic;  --input only pin...
    -- MADC1_PDWN : out   std_logic;  --input only pin...
    
    MADC2_CLK  : out   std_logic;
    MADC2_FCO  : in    std_logic;
    MADC2_DCO  : in    std_logic;
    -- MADC2_DCO_OPT : in std_logic;
    MADC2_D    : in    std_logic_vector(8 downto 1);
    MADC2_SCLK : out   std_logic;
    MADC2_SDIO : inout std_logic;
    MADC2_CSB  : out   std_logic := '1';
    MADC2_PDWN : out   std_logic := '0';
    
    KONR_ADC       : in  std_logic_vector(2 downto 1);
    KONR_ADC_THR   : out std_logic_vector(2 downto 1);
    KONR_ADC_N     : out std_logic_vector(2 downto 1);
    KONR_ADC_DISCH : out std_logic_vector(2 downto 1);
    
    WU_RAMP     : out   std_logic;
    
    LVDS_IO     : inout std_logic_vector(17 downto 1);
    LVDS_INP    : inout std_logic_vector( 8 downto 1);
    RJ45_LVDS   : inout std_logic_vector( 4 downto 1);
    
    PWM_DAC_INPUT : out std_logic_vector(4 downto 1);
    
    DAC_MUTEB  : out   std_logic;
    DAC_FSYNC  : out   std_logic;
    DAC_SCLK   : out   std_logic;
    DAC_DIN    : out   std_logic;
    DAC_BPB    : out   std_logic;
    DAC_RSTB   : out   std_logic;
    DAC_OSR    : inout std_logic_vector(2 downto 1);
    
    DAC12_SCK  : out   std_logic;
    DAC12_CSB  : out   std_logic;
    DAC12_SDI  : out   std_logic;
    DAC12_SDO  : in    std_logic;
    DAC12_CLRB : out   std_logic;
    
    LEDADDON_LINKOK : out   std_logic;
    LEDADDON_RXTX   : out   std_logic;
    LEDADDON_RED    : out   std_logic;
    LEDADDON_YELLOW : out   std_logic;
    LEDADDON_GREEN  : out   std_logic;
    LEDADDON_ORANGE : out   std_logic;

    SFP1_RATESEL    : out   std_logic;
    SFP1_TXDIS      : out   std_logic;
    SFP1_TXFAULT    : in    std_logic;
    SFP1_LOS        : in    std_logic;
    SFP1_MOD        : inout std_logic_vector(2 downto 0);
    
    --Flash ROM & Reboot
    FLASH_CLK  : out   std_logic;
    FLASH_CS   : out   std_logic;
    FLASH_DIN  : out   std_logic;
    FLASH_DOUT : in    std_logic;
    PROGRAMN   : out   std_logic;                     --reboot FPGA

    --Misc
    TEMPSENS   : inout std_logic;       --Temperature Sensor
    CODE_LINE  : in    std_logic_vector(1 downto 0);
    LED_GREEN  : out   std_logic;
    LED_ORANGE : out   std_logic;
    LED_RED    : out   std_logic;
    LED_YELLOW : out   std_logic;
    SUPPL      : in    std_logic;       --terminated diff pair, PCLK, Pads

    --Test Connectors
    TEST_LINE : out std_logic_vector(15 downto 0)
    );


  attribute syn_useioff                  : boolean;
  --no IO-FF for LEDs relaxes timing constraints
  attribute syn_useioff of LED_GREEN     : signal is false;
  attribute syn_useioff of LED_ORANGE    : signal is false;
  attribute syn_useioff of LED_RED       : signal is false;
  attribute syn_useioff of LED_YELLOW    : signal is false;
  attribute syn_useioff of LEDADDON_GREEN     : signal is false;
  attribute syn_useioff of LEDADDON_ORANGE    : signal is false;
  attribute syn_useioff of LEDADDON_RED       : signal is false;
  attribute syn_useioff of LEDADDON_YELLOW    : signal is false;
  attribute syn_useioff of LEDADDON_LINKOK    : signal is false;
  attribute syn_useioff of LEDADDON_RXTX      : signal is false;
  attribute syn_useioff of SFP1_RATESEL       : signal is false;
  attribute syn_useioff of SFP1_TXDIS         : signal is false;
  attribute syn_useioff of SFP1_TXFAULT       : signal is false;
  attribute syn_useioff of SFP1_LOS           : signal is false;
  attribute syn_useioff of TEMPSENS      : signal is false;
  attribute syn_useioff of PROGRAMN      : signal is false;
  attribute syn_useioff of CODE_LINE     : signal is false;
  attribute syn_useioff of TRIGGER_LEFT  : signal is false;
  attribute syn_useioff of TRIGGER_RIGHT : signal is false;

  --important signals _with_ IO-FF
  attribute syn_useioff of FLASH_CLK  : signal is true;
  attribute syn_useioff of FLASH_CS   : signal is true;
  attribute syn_useioff of FLASH_DIN  : signal is true;
  attribute syn_useioff of FLASH_DOUT : signal is true;
  attribute syn_useioff of FPGA5_COMM : signal is true;
  attribute syn_useioff of TEST_LINE  : signal is true;


end entity;

architecture trb3_periph_arch of trb3_periph_multitest is

component pll_adc12bit is
    port (
        CLK: in std_logic; 
        CLKOP: out std_logic;
        CLKOS: out std_logic;
        CLKOK: out std_logic; 
        LOCK: out std_logic);
end component;

  --Constants
  constant REGIO_NUM_STAT_REGS : integer := 2;
  constant REGIO_NUM_CTRL_REGS : integer := 2;

  attribute syn_keep     : boolean;
  attribute syn_preserve : boolean;

  --Clock / Reset
  signal clk_100_i                : std_logic;  --clock for main logic, 100 MHz, via Clock Manager and internal PLL
  signal clk_200_i                : std_logic;  --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
  signal clk_adcref_i             : std_logic;  --reference for ADC
  signal clk_adcfast_i            : std_logic;  --data clock reference for ADC
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
  signal timing_trg_received_i : std_logic;
  signal trg_data_valid_i      : std_logic;
  signal trg_timing_valid_i    : std_logic;
  signal trg_notiming_valid_i  : std_logic;
  signal trg_invalid_i         : std_logic;
  signal trg_type_i            : std_logic_vector(3 downto 0);
  signal trg_number_i          : std_logic_vector(15 downto 0);
  signal trg_code_i            : std_logic_vector(7 downto 0);
  signal trg_information_i     : std_logic_vector(23 downto 0);
  signal trg_int_number_i      : std_logic_vector(15 downto 0);
  signal trg_multiple_trg_i    : std_logic;
  signal trg_timeout_detected_i: std_logic;
  signal trg_spurious_trg_i    : std_logic;
  signal trg_missing_tmg_trg_i : std_logic;
  signal trg_spike_detected_i  : std_logic;
  
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

  signal spi_bram_addr : std_logic_vector(7 downto 0);
  signal spi_bram_wr_d : std_logic_vector(7 downto 0);
  signal spi_bram_rd_d : std_logic_vector(7 downto 0);
  signal spi_bram_we   : std_logic;

  signal dac_read_en   : std_logic;
  signal dac_write_en  : std_logic;
  signal dac_data_in   : std_logic_vector(31 downto 0);
  signal dac_addr      : std_logic_vector(4 downto 0);
  signal dac_data_out  : std_logic_vector(31 downto 0);
  signal dac_ack       : std_logic;
  signal dac_busy      : std_logic;
  --FPGA Test
  signal time_counter : unsigned(31 downto 0);

  signal clk_adc  : std_logic;
  signal adc_data : std_logic_vector(8*12-1 downto 0);
  signal adc_fco  : std_logic_vector(2*12-1 downto 0);
  signal adc_datavalid : std_logic_vector(1 downto 0);

  signal adcbus_empty : std_logic;
  signal adcbus_write : std_logic;
  signal adcbus_read  : std_logic;
  signal adcbus_addr  : std_logic_vector(2 downto 0);
  signal adcbus_dataout : std_logic_vector(31 downto 0);
  signal last_adcbus_read : std_logic;
  signal ll_adcbus_read : std_logic;
  signal lll_adcbus_read : std_logic;
  signal llll_adcbus_read : std_logic;

  signal adcfifo_data_out : std_logic_vector(32*8-1 downto 0);
  signal adcfifo_read     : std_logic_vector(7 downto 0);
  signal adcfifo_empty    : std_logic_vector(7 downto 0);
  signal adcdebug         : std_logic_vector(31 downto 0);
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

  THE_MAIN_PLL : pll_adc12bit
    port map(
      CLK   => CLK_PCLK_LEFT,
      CLKOS => clk_200_i,
      CLKOP => clk_adcfast_i,
      CLKOK => clk_adcref_i,
      LOCK  => open
      );

  THE_MAIN_PLL_2 : pll_in200_out100
    port map(
      CLK   => clk_200_i,
      CLKOP => clk_100_i,
      CLKOK => open,
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
      REGIO_NUM_STAT_REGS       => REGIO_NUM_STAT_REGS,  --4,    --16 stat reg
      REGIO_NUM_CTRL_REGS       => REGIO_NUM_CTRL_REGS,  --3,    --8 cotrol reg
      ADDRESS_MASK              => x"FFFF",
      BROADCAST_BITMASK         => x"FF",
      BROADCAST_SPECIAL_ADDR    => x"45",
      REGIO_COMPILE_TIME        => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME, 32)),
      REGIO_HARDWARE_VERSION    => x"91002000",
      REGIO_INIT_ADDRESS        => x"f300",
      REGIO_USE_VAR_ENDPOINT_ID => c_YES,
      CLOCK_FREQUENCY           => 125,
      TIMING_TRIGGER_RAW        => c_YES,
      --Configure data handler
      DATA_INTERFACE_NUMBER     => 1,
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
      TRG_MULTIPLE_TRG_OUT         => trg_multiple_trg_i,
      TRG_TIMEOUT_DETECTED_OUT     => trg_timeout_detected_i,
      TRG_SPURIOUS_TRG_OUT         => trg_spurious_trg_i,
      TRG_MISSING_TMG_TRG_OUT      => trg_missing_tmg_trg_i,
      TRG_SPIKE_DETECTED_OUT       => trg_spike_detected_i,
      
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

---------------------------------------------------------------------------
-- AddOn ADC
---------------------------------------------------------------------------
THE_ADC : adc_ad9222
  port map(
    CLK        => clk_100_i,
    CLK_ADCREF => clk_adcref_i,
    CLK_ADCDAT => clk_adcfast_i,
    RESTART_IN => adcbus_write,
    ADCCLK_OUT => clk_adc,
    ADC_DATA(3 downto 0) => MADC1_D(4 downto 1),
    ADC_DATA(7 downto 4) => MADC2_D(4 downto 1),
    ADC_FCO(0) => MADC1_FCO,    
    ADC_FCO(1) => MADC2_FCO,    
    ADC_DCO(0) => MADC1_DCO,
    ADC_DCO(1) => MADC2_DCO,
    
    DATA_OUT       => adc_data,
    FCO_OUT        => adc_fco,
    DATA_VALID_OUT => adc_datavalid,
    DEBUG          => adcdebug
    );

MADC1_CLK <= clk_adc;
MADC2_CLK <= clk_adc;
-- MADC1_PDWN <= '0'; Ha Ha Ha
MADC2_PDWN <= '0';
MADC2_CSB  <= '1';
MADC2_SCLK <= '0';
MADC2_SDIO <= 'Z';
MADC1_SCLK <= '0';
MADC1_SDIO <= 'Z';


gen_adc_fifos : for i in 0 to 7 generate
  THE_ADC_FIFO : fifo_36x8k_oreg
    port map(
      Data(11 downto 0)  => adc_data(i*12+11 downto i*12),
      Data(15 downto 12) => x"0",
      Data(27 downto 16) => adc_fco((i / 4)*12+11 downto (i / 4)*12),
      Data(35 downto 28) => x"00",
      Clock  => clk_100_i, 
      WrEn   => adc_datavalid(i / 4), 
      RdEn   => adcfifo_read(i), 
      Reset  => adcbus_write,
      Q(31 downto 0) => adcfifo_data_out(i*32+31 downto i*32),
      Empty  => adcfifo_empty(i),
      AmFullThresh => (others => '1'),
      Full   => open
      );
end generate;


LVDS_IO <= adcdebug(16 downto 0);


---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 4,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", 2 => x"d400", 3 => x"c000", others => x"0000"),
      PORT_ADDR_MASK => (0 => 1, 1 => 6, 2 => 5, 3 => 3, others => 0)
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
      --ADC
      BUS_READ_ENABLE_OUT(3)              => adcbus_read,
      BUS_WRITE_ENABLE_OUT(3)             => adcbus_write,
      BUS_DATA_OUT(3*32+31 downto 3*32)   => open,
      BUS_ADDR_OUT(3*16+2 downto 3*16)    => adcbus_addr,
      BUS_ADDR_OUT(3*16+15 downto 3*16+3) => open,
      BUS_TIMEOUT_OUT(3)                  => open,
      BUS_DATA_IN(3*32+31 downto 3*32)    => adcbus_dataout,
      BUS_DATAREADY_IN(3)                 => llll_adcbus_read,
      BUS_WRITE_ACK_IN(3)                 => adcbus_write,
      BUS_NO_MORE_DATA_IN(3)              => adcbus_empty,
      BUS_UNKNOWN_ADDR_IN(3)              => '0',
      STAT_DEBUG => open
      );


last_adcbus_read <= adcbus_read when rising_edge(clk_100_i);
ll_adcbus_read <= last_adcbus_read when rising_edge(clk_100_i);
lll_adcbus_read <= ll_adcbus_read when rising_edge(clk_100_i);
llll_adcbus_read <= lll_adcbus_read when rising_edge(clk_100_i);


  proc_read_adc_fifo : process 
    variable chan : integer range 0 to 7;
    begin
    wait until rising_edge(clk_100_i);
    adcbus_empty <= '0';
    adcfifo_read <= (others => '0');
    if adcbus_read = '1' then
      chan := to_integer(unsigned(adcbus_addr));
      if adcfifo_empty(chan) = '1' then
        adcbus_empty <= '1';
      else
        adcfifo_read(chan) <= '1';
      end if;
    end if;
    adcbus_dataout <= adcfifo_data_out(chan*32+31 downto chan*32);
  end process;



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
      SPI_CS_OUT(0) => DAC12_CSB,
      SPI_SDI_IN    => DAC12_SDO,
      SPI_SDO_OUT   => DAC12_SDI,
      SPI_SCK_OUT   => DAC12_SCK
      );

      DAC12_CLRB <= '0';
      
---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  LED_GREEN  <= not med_stat_op(9);
  LED_ORANGE <= not med_stat_op(10);
  LED_RED    <= not time_counter(26);
  LED_YELLOW <= not med_stat_op(11);
  
  LEDADDON_GREEN  <= '0';
  LEDADDON_LINKOK <= '0';
  LEDADDON_ORANGE <= '0';
  LEDADDON_RED    <= '0';
  LEDADDON_YELLOW <= '0';

---------------------------------------------------------------------------
-- Test Connector
---------------------------------------------------------------------------    
--   TEST_LINE(7 downto 0)   <= med_data_in(7 downto 0);
--   TEST_LINE(8)            <= med_dataready_in;
--   TEST_LINE(9)            <= med_dataready_out;
--   TEST_LINE(10)           <= stat_reg_strobe(0);
  TEST_LINE(15 downto 0) <= (others => '0');


---------------------------------------------------------------------------
-- Test Circuits
---------------------------------------------------------------------------
  process
  begin
    wait until rising_edge(clk_100_i);
    time_counter <= time_counter + 1;
  end process;

end architecture;
