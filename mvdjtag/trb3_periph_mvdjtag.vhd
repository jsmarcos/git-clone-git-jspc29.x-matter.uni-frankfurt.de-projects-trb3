library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;
use work.jtag_constants.all;


--Connector pinout, INP_n is the number of wire pair
-- LOCATE COMP  "MAPS_CLK_OUT_0"     #9  INP_2
-- LOCATE COMP  "MAPS_START_OUT_0"   #17 INP_4
-- LOCATE COMP  "MAPS_RESET_OUT_0"   #21 INP_5
-- LOCATE COMP  "JTAG_TCK_OUT_0"     #29 INP_7
-- LOCATE COMP  "JTAG_TMS_OUT_0"     #41 INP_10
-- LOCATE COMP  "JTAG_TDI_OUT_0"     #45 INP_11
-- LOCATE COMP  "JTAG_TDO_IN_0"      #33 INP_8



entity trb3_periph_mvdjtag is
  generic(
    NUM_CHAINS : integer := 1;
    SYNC_MODE : integer range 0 to 1 := c_NO   --use the RX clock for internal logic and transmission.
    );
  port(
    --Clocks
    CLK_GPLL_LEFT  : in std_logic;      --Clock Manager 6
    CLK_GPLL_RIGHT : in std_logic;      --Clock Manager 4  <-- MAIN CLOCK for FPGA
    CLK_PCLK_LEFT  : in std_logic;      --Clock Manager 3
    CLK_PCLK_RIGHT : in std_logic;      --Clock Manager 1
    --CLK_PCLK_RIGHT is the only clock with external termination !?
    CLK_EXTERNAL   : in std_logic;      --Clock Manager 9

    --Trigger
    TRIGGER_LEFT   : in std_logic;       --left side trigger input from fan-out
    TRIGGER_RIGHT  : in std_logic;       --right side trigger input from fan-out

    --Serdes
    CLK_SERDES_INT_RIGHT : in  std_logic;  --Clock Manager 0, not used
    SERDES_TX            : out std_logic_vector(3 downto 2);
    SERDES_RX            : in  std_logic_vector(3 downto 2);

    FPGA5_COMM : inout std_logic_vector(11 downto 0);
                                        --Bit 0/1 input, serial link RX active
                                        --Bit 2/3 output, serial link TX active

    --Connections
    MAPS_CLK_OUT    : out std_logic_vector(NUM_CHAINS-1 downto 0);
    MAPS_START_OUT  : out std_logic_vector(NUM_CHAINS-1 downto 0);
    MAPS_RESET_OUT  : out std_logic_vector(NUM_CHAINS-1 downto 0);
    JTAG_TCK_OUT    : out std_logic_vector(NUM_CHAINS-1 downto 0);
    JTAG_TMS_OUT    : out std_logic_vector(NUM_CHAINS-1 downto 0);
    JTAG_TDI_OUT    : out std_logic_vector(NUM_CHAINS-1 downto 0);
    JTAG_TDO_IN     : in  std_logic_vector(NUM_CHAINS-1 downto 0);
    
    --Flash ROM & Reboot
    FLASH_CLK  : out std_logic;
    FLASH_CS   : out std_logic;
    FLASH_DIN  : out std_logic;
    FLASH_DOUT : in  std_logic;
    PROGRAMN   : out std_logic;         --reboot FPGA

    --Misc
    TEMPSENS   : inout std_logic;       --Temperature Sensor
    CODE_LINE  : in    std_logic_vector(1 downto 0);
    LED_GREEN  : out   std_logic;
    LED_ORANGE : out   std_logic;
    LED_RED    : out   std_logic;
    LED_YELLOW : out   std_logic;

    --Test Connectors
    TEST_LINE : out std_logic_vector(15 downto 0)
    );


  attribute syn_useioff               : boolean;
  --no IO-FF for LEDs relaxes timing constraints
  attribute syn_useioff of LED_GREEN  : signal is false;
  attribute syn_useioff of LED_ORANGE : signal is false;
  attribute syn_useioff of LED_RED    : signal is false;
  attribute syn_useioff of LED_YELLOW : signal is false;
  attribute syn_useioff of TEMPSENS   : signal is false;
  attribute syn_useioff of PROGRAMN   : signal is false;

  --important signals _with_ IO-FF
  attribute syn_useioff of FLASH_CLK  : signal is true;
  attribute syn_useioff of FLASH_CS   : signal is true;
  attribute syn_useioff of FLASH_DIN  : signal is true;
  attribute syn_useioff of FLASH_DOUT : signal is true;
  attribute syn_useioff of TEST_LINE  : signal is true;
  attribute syn_useioff of JTAG_TCK_OUT  : signal is true;
  attribute syn_useioff of JTAG_TDI_OUT  : signal is true;
  attribute syn_useioff of JTAG_TMS_OUT  : signal is true;
  attribute syn_useioff of JTAG_TDO_IN  : signal is true;


end entity;

architecture trb3_periph_mvdjtag_arch of trb3_periph_mvdjtag is
  --Constants
  constant REGIO_NUM_STAT_REGS : integer := 4;
  constant REGIO_NUM_CTRL_REGS : integer := 2;

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
  signal clk_100_internal         : std_logic;
  signal clk_200_internal         : std_logic;
  signal rx_clock_100             : std_logic;
  signal rx_clock_200             : std_logic;
--   signal clk_tdc                  : std_logic;
  signal time_counter, time_counter2 : unsigned(31 downto 0);
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

  --Serdes registers
  signal sci1_ack      : std_logic;
  signal sci1_write    : std_logic;
  signal sci1_read     : std_logic;
  signal sci1_data_in  : std_logic_vector(7 downto 0);
  signal sci1_data_out : std_logic_vector(7 downto 0);
  signal sci1_addr     : std_logic_vector(8 downto 0);  

  -- JTAG_CMD_M26C connection signals
  signal jtag_addr_in          : std_logic_vector(12 downto 0);
  signal jtag_data_in          : std_logic_vector(31 downto 0);
  signal jtag_read_enable_in   : std_logic;
  signal jtag_write_enable_in  : std_logic;
  signal jtag_data_out         : std_logic_vector(31 downto 0);
  signal jtag_dataready_out    : std_logic;
  signal jtag_write_ack_out    : std_logic;
  signal jtag_no_more_data_out : std_logic;
  signal jtag_unknown_addr_out : std_logic;
  
  signal jtag_status           : std_logic_vector(256*NUM_CHAINS-1 downto 0);
  signal jtag_tck              : std_logic_vector(NUM_CHAINS-1 downto 0);
  signal jtag_tms              : std_logic_vector(NUM_CHAINS-1 downto 0);
  signal jtag_tdi              : std_logic_vector(NUM_CHAINS-1 downto 0);
  signal jtag_tdo              : std_logic_vector(NUM_CHAINS-1 downto 0);  
  signal maps_clk              : std_logic_vector(NUM_CHAINS-1 downto 0);  
  signal maps_start            : std_logic_vector(NUM_CHAINS-1 downto 0);  
  signal maps_reset            : std_logic_vector(NUM_CHAINS-1 downto 0);  


  
  
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
      CLK_IN        => clk_200_internal, -- raw master clock, NOT from PLL/DLL!
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
      CLK   => CLK_PCLK_LEFT,
      CLKOP => clk_100_internal,
      CLKOK => clk_200_internal,
      LOCK  => pll_lock
      );

  gen_sync_clocks : if SYNC_MODE = c_YES generate
    clk_100_i <= rx_clock_100;
    clk_200_i <= rx_clock_200;
--     clk_tdc   <= rx_clock_200;
  end generate;

  gen_local_clocks : if SYNC_MODE = c_NO generate
    clk_100_i <= clk_100_internal;
    clk_200_i <= clk_200_internal;
--     clk_tdc   <= CLK_PCLK_LEFT;
  end generate;

---------------------------------------------------------------------------
-- The TrbNet media interface (to other FPGA)
---------------------------------------------------------------------------
  THE_MEDIA_UPLINK : trb_net16_med_ecp3_sfp
    generic map(
      SERDES_NUM  => 1,     --number of serdes in quad
      EXT_CLOCK   => c_NO,  --use internal clock
      USE_200_MHZ => c_YES, --run on 200 MHz clock
      USE_CTC     => c_NO,
      USE_SLAVE   => SYNC_MODE
      )      
    port map(
      CLK                => clk_200_internal,
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
      CLK_RX_HALF_OUT    => rx_clock_100,
      CLK_RX_FULL_OUT    => rx_clock_200,
      
      --SFP Connection
      SD_RXD_P_IN        => SERDES_RX(2),
      SD_RXD_N_IN        => SERDES_RX(3),
      SD_TXD_P_OUT       => SERDES_TX(2),
      SD_TXD_N_OUT       => SERDES_TX(3),
      SD_REFCLK_P_IN     => open,
      SD_REFCLK_N_IN     => open,
      SD_PRSNT_N_IN      => FPGA5_COMM(0),
      SD_LOS_IN          => FPGA5_COMM(0),
      SD_TXDIS_OUT       => FPGA5_COMM(2),
      
      SCI_DATA_IN        => sci1_data_in,
      SCI_DATA_OUT       => sci1_data_out,
      SCI_ADDR           => sci1_addr,
      SCI_READ           => sci1_read,
      SCI_WRITE          => sci1_write,
      SCI_ACK            => sci1_ack,        
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
      REGIO_HARDWARE_VERSION    => x"91000000",
      REGIO_INIT_ADDRESS        => x"f308",
      REGIO_USE_VAR_ENDPOINT_ID => c_YES,
      CLOCK_FREQUENCY           => 100,
      TIMING_TRIGGER_RAW        => c_YES,
      --Configure data handler
      DATA_INTERFACE_NUMBER     => 1,
      DATA_BUFFER_DEPTH         => 9,  --13
      DATA_BUFFER_WIDTH         => 32,
      DATA_BUFFER_FULL_THRESH   => 2**9-100,
      TRG_RELEASE_AFTER_DATA    => c_YES,
      HEADER_BUFFER_DEPTH       => 9,
      HEADER_BUFFER_FULL_THRESH => 2**9-16
      )
    port map(
      CLK                => clk_100_i,
      RESET              => reset_i,
      CLK_EN             => '1',
      MED_DATAREADY_OUT  => med_dataready_out,
      MED_DATA_OUT       => med_data_out,
      MED_PACKET_NUM_OUT => med_packet_num_out,
      MED_READ_IN        => med_read_in,
      MED_DATAREADY_IN   => med_dataready_in,
      MED_DATA_IN        => med_data_in,
      MED_PACKET_NUM_IN  => med_packet_num_in,
      MED_READ_OUT       => med_read_out,
      MED_STAT_OP_IN     => med_stat_op,
      MED_CTRL_OP_OUT    => med_ctrl_op,

      --Timing trigger in
      TRG_TIMING_TRG_RECEIVED_IN  => '0',
      --LVL1 trigger to FEE
      LVL1_TRG_DATA_VALID_OUT     => open,
      LVL1_VALID_TIMING_TRG_OUT   => open,
      LVL1_VALID_NOTIMING_TRG_OUT => open,
      LVL1_INVALID_TRG_OUT        => open,

      LVL1_TRG_TYPE_OUT        => open,
      LVL1_TRG_NUMBER_OUT      => open,
      LVL1_TRG_CODE_OUT        => open,
      LVL1_TRG_INFORMATION_OUT => open,
      LVL1_INT_TRG_NUMBER_OUT  => open,

      --Information about trigger handler errors
      TRG_MULTIPLE_TRG_OUT     => open,
      TRG_TIMEOUT_DETECTED_OUT => open,
      TRG_SPURIOUS_TRG_OUT     => open,
      TRG_MISSING_TMG_TRG_OUT  => open,
      TRG_SPIKE_DETECTED_OUT   => open,

      --Response from FEE
      FEE_TRG_RELEASE_IN(0)       => '1',
      FEE_TRG_STATUSBITS_IN       => x"00000000",
      FEE_DATA_IN                 => x"00000000",
      FEE_DATA_WRITE_IN(0)        => '0',
      FEE_DATA_FINISHED_IN(0)     => '1',
      FEE_DATA_ALMOST_FULL_OUT(0) => open,

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
-- Bus Handler
---------------------------------------------------------------------------
  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 4,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", 2 => x"b000", 3 => x"a000", others => x"0000"),
      PORT_ADDR_MASK => (0 => 1, 1 => 6, 2 => 9, 3 => 13, others => 0)
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

      --SCI first Media Interface
      BUS_READ_ENABLE_OUT(2)              => sci1_read,
      BUS_WRITE_ENABLE_OUT(2)             => sci1_write,
      BUS_DATA_OUT(2*32+7 downto 2*32)    => sci1_data_in,
      BUS_DATA_OUT(2*32+31 downto 2*32+8) => open,
      BUS_ADDR_OUT(2*16+8 downto 2*16)    => sci1_addr,
      BUS_ADDR_OUT(2*16+15 downto 2*16+9) => open,
      BUS_TIMEOUT_OUT(2)                  => open,
      BUS_DATA_IN(2*32+7 downto 2*32)     => sci1_data_out,
      BUS_DATAREADY_IN(2)                 => sci1_ack,
      BUS_WRITE_ACK_IN(2)                 => sci1_ack,
      BUS_NO_MORE_DATA_IN(2)              => '0',
      BUS_UNKNOWN_ADDR_IN(2)              => '0',

      --First JTAG Chain
      BUS_ADDR_OUT(3*16+12 downto 3*16)    => jtag_addr_in,
      BUS_ADDR_OUT(3*16+15 downto 3*16+13) => open,
      BUS_DATA_OUT(3*32+31 downto 3*32)    => jtag_data_in,
      BUS_READ_ENABLE_OUT(3)               => jtag_read_enable_in,
      BUS_WRITE_ENABLE_OUT(3)              => jtag_write_enable_in,
      BUS_TIMEOUT_OUT(3)                   => open,
      BUS_DATA_IN(3*32+31 downto 3*32)     => jtag_data_out,
      BUS_DATAREADY_IN(3)                  => jtag_dataready_out,
      BUS_WRITE_ACK_IN(3)                  => jtag_write_ack_out,
      BUS_NO_MORE_DATA_IN(3)               => jtag_no_more_data_out,
      BUS_UNKNOWN_ADDR_IN(3)               => jtag_unknown_addr_out,
      
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
-- JTAG Chain
---------------------------------------------------------------------------
THE_JTAG : entity work.jtag_mvd
  generic map(
    NUM_CHAINS => NUM_CHAINS
    )
  port map(
    CLK_IN            => clk_100_i,
    CLK_MAPS_IN       => CLK_PCLK_LEFT,
    RESET             => reset_i,
    
    MAPS_CLK_OUT      => maps_clk,
    MAPS_START_OUT    => maps_start,
    MAPS_RESET_OUT    => maps_reset,
    
    JTAG_TDI_OUT      => jtag_tdi,
    JTAG_TMS_OUT      => jtag_tms,
    JTAG_TCK_OUT      => jtag_tck,
    JTAG_TDO_IN       => jtag_tdo,
    
    BUS_DATA_IN          => jtag_data_in,
    BUS_DATA_OUT         => jtag_data_out,
    BUS_ADDR_IN          => jtag_addr_in,
    BUS_WRITE_IN         => jtag_write_enable_in,
    BUS_READ_IN          => jtag_read_enable_in,
    BUS_DATAREADY_OUT    => jtag_dataready_out,
    BUS_WRITE_ACK_OUT    => jtag_write_ack_out,
    BUS_NO_MORE_DATA_OUT => jtag_no_more_data_out,
    BUS_UNKNOWN_OUT      => jtag_unknown_addr_out,
    
    STATUS_OUT        => jtag_status,
    DEBUG_OUT         => open
    );
    
  stat_reg(255 downto 0)   <= (others => '0');  
  stat_reg(511 downto 256) <= jtag_status;    
    
---------------------------------------------------------------------------
-- I/O connections
---------------------------------------------------------------------------
  JTAG_TDI_OUT <= jtag_tdi;
  JTAG_TMS_OUT <= jtag_tms;
  JTAG_TCK_OUT <= jtag_tck;
  jtag_tdo  <= JTAG_TDO_IN;  
  
  MAPS_CLK_OUT   <= maps_clk;
  MAPS_START_OUT <= maps_start;
  MAPS_RESET_OUT <= maps_reset;
    
---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  LED_ORANGE <= not reset_i when rising_edge(clk_100_internal);
  LED_YELLOW <= '1';
  LED_GREEN  <= not med_stat_op(9);
  LED_RED    <= not (med_stat_op(10) or med_stat_op(11));

---------------------------------------------------------------------------
-- Test Connector
---------------------------------------------------------------------------    
--  TEST_LINE(15 downto 0) <= (others => '0');
---------------------------------------------------------------------------
-- Test Circuits
---------------------------------------------------------------------------
  process
    begin
      wait until rising_edge(clk_100_internal);
      time_counter <= time_counter + 1;
    end process;



end architecture;
