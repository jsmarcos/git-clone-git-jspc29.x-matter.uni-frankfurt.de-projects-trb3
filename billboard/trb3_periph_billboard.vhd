library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.config.all;
use work.version.all;

entity trb3_periph_billboard is
  port(
    --Clocks
    CLK_GPLL_LEFT        : in  std_logic;  --Clock Manager 1/(2468), 125 MHz
    CLK_GPLL_RIGHT       : in  std_logic;  --Clock Manager 2/(2468), 200 MHz  <-- MAIN CLOCK for FPGA
    CLK_PCLK_LEFT        : in  std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!
    CLK_PCLK_RIGHT       : in  std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!
    
    --Trigger
    TRIGGER_LEFT         : in  std_logic;  --left side trigger input from fan-out
    TRIGGER_RIGHT        : in  std_logic;  --right side trigger input from fan-out
    
    MBS_IN               : in  std_logic;
    
    --Serdes
    CLK_SERDES_INT_LEFT  : in  std_logic;  --Clock Manager 1/(1357), off, 125 MHz possible
    CLK_SERDES_INT_RIGHT : in  std_logic;  --Clock Manager 2/(1357), 200 MHz, only in case of problems
    SERDES_INT_TX        : out std_logic_vector(3 downto 0);
    SERDES_INT_RX        : in  std_logic_vector(3 downto 0);

    --Inter-FPGA Communication
    FPGA5_COMM           : inout std_logic_vector(11 downto 0);
                                        --Bit 0/1 input, serial link RX active
                                        --Bit 2/3 output, serial link TX active
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
  attribute syn_useioff of MBS_IN        : signal is false;
  --important signals
  attribute syn_useioff of FLASH_CLK     : signal is true;
  attribute syn_useioff of FLASH_CS      : signal is true;
  attribute syn_useioff of FLASH_DIN     : signal is true;
  attribute syn_useioff of FLASH_DOUT    : signal is true;
  attribute syn_useioff of FPGA5_COMM    : signal is true;
  attribute syn_useioff of TEST_LINE     : signal is true;
  
  
end entity;

architecture trb3_periph_billboard_arch of trb3_periph_billboard is
   constant DEVICES : integer := 2;

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

   --Slow Control channel
   signal common_stat_reg        : std_logic_vector(std_COMSTATREG*32-1 downto 0);
   signal common_ctrl_reg        : std_logic_vector(std_COMCTRLREG*32-1 downto 0);
   signal common_stat_reg_strobe : std_logic_vector(std_COMSTATREG-1 downto 0);
   signal common_ctrl_reg_strobe : std_logic_vector(std_COMCTRLREG-1 downto 0);

   --Timer
   signal global_time         : std_logic_vector(31 downto 0);
   signal local_time          : std_logic_vector(7 downto 0);
   signal time_since_last_trg : std_logic_vector(31 downto 0);
   signal timer_ticks         : std_logic_vector(1 downto 0);

   signal regio_rx, busmem_rx, regio_bb_rx, regio_mbs_rx : CTRLBUS_RX;
   signal regio_tx, busmem_tx, regio_bb_tx, regio_mbs_tx : CTRLBUS_TX;
   signal readout_rx : READOUT_RX;
   signal readout_tx : readout_tx_array_t(0 to DEVICES-1);

   signal fee_data_finished_in : std_logic_vector(DEVICES-1 downto 0);
   signal fee_data_write_in    : std_logic_vector(DEVICES-1 downto 0);
   signal fee_trg_release_in   : std_logic_vector(DEVICES-1 downto 0);
   signal fee_data_in           : std_logic_vector(32*DEVICES-1 downto 0);
   signal fee_trg_statusbits_in : std_logic_vector(32*DEVICES-1 downto 0);
  
   signal mbs_ctrl_i : std_logic_vector(31 downto 0);
   signal mbs_status_i : std_logic_vector(31 downto 0);  
   signal mbs_trg_sync_i : std_logic;
   signal mbs_trg_async_i : std_logic;

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
  THE_MAIN_PLL : pll_in200_out100
    port map(
      CLK   => CLK_PCLK_RIGHT,
      RESET => '0',
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
      REGIO_NUM_STAT_REGS       => 0,
      REGIO_NUM_CTRL_REGS       => 0,
      ADDRESS_MASK              => x"FFFF",
      BROADCAST_BITMASK         => x"ff",
      BROADCAST_SPECIAL_ADDR    => BROADCAST_SPECIAL_ADDR,
      REGIO_COMPILE_TIME        => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME, 32)),
      REGIO_HARDWARE_VERSION    => HARDWARE_INFO,
      REGIO_INIT_ADDRESS        => INIT_ADDRESS,
      REGIO_USE_VAR_ENDPOINT_ID => c_YES,
      REGIO_INCLUDED_FEATURES   => INCLUDED_FEATURES,
      CLOCK_FREQUENCY           => CLOCK_FREQUENCY,
      TIMING_TRIGGER_RAW        => c_YES,
      --Configure data handler
      DATA_INTERFACE_NUMBER     => DEVICES,
      DATA_BUFFER_DEPTH         => 10,
      DATA_BUFFER_WIDTH         => 32,
      DATA_BUFFER_FULL_THRESH   => 2**10-511,
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
      TRG_TIMING_TRG_RECEIVED_IN  => timing_trg_received_i,
      --LVL1 trigger to FEE
      LVL1_TRG_DATA_VALID_OUT     => readout_rx.data_valid,
      LVL1_VALID_TIMING_TRG_OUT   => readout_rx.valid_timing_trg,
      LVL1_VALID_NOTIMING_TRG_OUT => readout_rx.valid_notiming_trg,
      LVL1_INVALID_TRG_OUT        => readout_rx.invalid_trg,

      LVL1_TRG_TYPE_OUT        => readout_rx.trg_type,
      LVL1_TRG_NUMBER_OUT      => readout_rx.trg_number,
      LVL1_TRG_CODE_OUT        => readout_rx.trg_code,
      LVL1_TRG_INFORMATION_OUT => readout_rx.trg_information,
      LVL1_INT_TRG_NUMBER_OUT  => readout_rx.trg_int_number,

      --Information about trigger handler errors
      TRG_MULTIPLE_TRG_OUT     => readout_rx.trg_multiple,
      TRG_TIMEOUT_DETECTED_OUT => readout_rx.trg_timeout,
      TRG_SPURIOUS_TRG_OUT     => readout_rx.trg_spurious,
      TRG_MISSING_TMG_TRG_OUT  => readout_rx.trg_missing,
      TRG_SPIKE_DETECTED_OUT   => readout_rx.trg_spike,

      --Response from FEE
      FEE_TRG_RELEASE_IN           => fee_trg_release_in,
      FEE_TRG_STATUSBITS_IN        => fee_trg_statusbits_in,
      FEE_DATA_IN                  => fee_data_in,
      FEE_DATA_WRITE_IN            => fee_data_write_in,
      FEE_DATA_FINISHED_IN         => fee_data_finished_in,
      FEE_DATA_ALMOST_FULL_OUT(0)  => readout_rx.buffer_almost_full,
      
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

      BUS_ADDR_OUT         =>  regio_rx.addr, --regio_addr_out,
      BUS_READ_ENABLE_OUT  =>  regio_rx.read, --regio_read_enable_out,
      BUS_WRITE_ENABLE_OUT =>  regio_rx.write, --regio_write_enable_out,
      BUS_DATA_OUT         =>  regio_rx.data, --regio_data_out,
      BUS_DATA_IN          =>  regio_tx.data, --regio_data_in,
      BUS_DATAREADY_IN     =>  regio_tx.ack, --regio_dataready_in,
      BUS_NO_MORE_DATA_IN  =>  regio_tx.nack, --regio_no_more_data_in,
      BUS_WRITE_ACK_IN     =>  regio_tx.ack, --regio_write_ack_in,
      BUS_UNKNOWN_ADDR_IN  =>  regio_tx.unknown, --regio_unknown_addr_in,
      BUS_TIMEOUT_OUT      =>  regio_rx.timeout, --regio_timeout_out,
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

gen_rdo_tx : for i in 0 to DEVICES-1 generate
      fee_trg_release_in(i)                      <= readout_tx(i).busy_release;
      fee_trg_statusbits_in(i*32+31 downto i*32) <= readout_tx(i).statusbits;
      fee_data_in(i*32+31 downto i*32)           <= readout_tx(i).data;
      fee_data_write_in(i)                       <= readout_tx(i).data_write;
      fee_data_finished_in(i)                    <= readout_tx(i).data_finished;
end generate;


   THE_BILLBOARD: entity work.billboard
   generic map (
      BLOCK_ADDR_WIDTH => 8
   ) port map (
      CLK_IN => clk_100_i,
      RESET_IN => reset_i,
      REGIO_IN => regio_bb_rx,
      REGIO_OUT => regio_bb_tx,
      RDO_IN => readout_rx,
      RDO_OUT => readout_tx(1)
   );
   
   THE_MBS_RECV: entity work.mbs_vulom_recv
   generic map (
      INCL_RDO_TIMESTAMP => c_YES,
      INCL_REGIO => c_YES
   )
   port map (
      CLK        => clk_100_i , -- in std_logic;  -- e.g. 100 MHz
      RESET_IN   => reset_i, -- in std_logic;  -- could be used after busy_release to make sure entity is in correct state

      --Module inputs
      MBS_IN     => MBS_IN, -- in std_logic;  -- raw input
      CLK_200    => clk_200_i, -- in std_logic;  -- internal sampling clock

      --trigger outputs
      TRG_ASYNC_OUT  => open, -- out std_logic;  -- asynchronous rising edge, length varying, here=> , -- approx. 110 ns
      TRG_SYNC_OUT   => mbs_trg_sync_i, -- out std_logic;  -- sync. to CLK

      TRG_NUMBER_IN  => readout_rx.trg_number,
      TRG_CODE_IN    => readout_rx.trg_code,
      TIMING_TRG_IN  => TRIGGER_LEFT,     
      
      --data output for read-out
      TRIGGER_IN   => readout_rx.data_valid, -- in  std_logic;
      DATA_OUT     => readout_tx(0).data , -- out std_logic_vector(31 downto 0);
      WRITE_OUT    => readout_tx(0).data_write, -- out std_logic;
      STATUSBIT_OUT=> readout_tx(0).statusbits, -- out std_logic_vector(31 downto 0) => , --= (others => '0');
      FINISHED_OUT => readout_tx(0).data_finished, -- out std_logic;

      --Registers / Debug    
      REGIO_IN => regio_mbs_rx,
      REGIO_OUT => regio_mbs_tx,
      
      CONTROL_REG_IN => (others => '0'),   -- in  std_logic_vector(31 downto 0);
      STATUS_REG_OUT => open, -- out std_logic_vector(31 downto 0) => , --= (others => '0');
      HEADER_REG_OUT => open, -- out std_logic_vector(1 downto 0);
      DEBUG          => open  -- out std_logic_vector(31 downto 0)    
   );
   readout_tx(0).busy_release <= readout_tx(0).data_finished;
   
   FPGA5_COMM(10 downto 7) <= "00" & mbs_trg_sync_i & mbs_trg_async_i;
    
---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
   THE_BUS_HANDLER : entity work.trb_net16_regio_bus_handler_record
   generic map(
      PORT_NUMBER      => 3,
      PORT_ADDRESSES   => (0 => x"d000", 1 => x"b000", 2 => x"b800", others => x"0000"),
      PORT_ADDR_MASK   => (0 => 9,       1 => 9,       2 => 2,  others => 0),
      PORT_MASK_ENABLE => 1
   )
   port map(
      CLK   => clk_100_i,
      RESET => reset_i,

      REGIO_RX  => regio_rx,
      REGIO_TX  => regio_tx,

      BUS_RX(0) => busmem_rx, --Flash
      BUS_RX(1) => regio_bb_rx, -- Billboard
      BUS_RX(2) => regio_mbs_rx, -- MBS
      BUS_TX(0) => busmem_tx,
      BUS_TX(1) => regio_bb_tx,
      BUS_TX(2) => regio_mbs_tx,

      STAT_DEBUG => open
   );


---------------------------------------------------------------------------
-- SPI / Flash
---------------------------------------------------------------------------

THE_SPI_RELOAD : entity work.spi_flash_and_fpga_reload
  port map(
    CLK_IN               => clk_100_i,
    RESET_IN             => reset_i,
    
    BUS_ADDR_IN          => busmem_rx.addr(8 downto 0),
    BUS_READ_IN          => busmem_rx.read,
    BUS_WRITE_IN         => busmem_rx.write,
    BUS_DATAREADY_OUT    => busmem_tx.rack,
    BUS_WRITE_ACK_OUT    => busmem_tx.wack,
    BUS_UNKNOWN_ADDR_OUT => busmem_tx.unknown,
    BUS_NO_MORE_DATA_OUT => busmem_tx.nack,
    BUS_DATA_IN          => busmem_rx.data,
    BUS_DATA_OUT         => busmem_tx.data,
    
    DO_REBOOT_IN         => common_ctrl_reg(15),     
    PROGRAMN             => PROGRAMN,
    
    SPI_CS_OUT           => FLASH_CS,
    SPI_SCK_OUT          => FLASH_CLK,
    SPI_SDO_OUT          => FLASH_DIN,
    SPI_SDI_IN           => FLASH_DOUT
    );


---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
   LED_GREEN  <= not med_stat_op(9);
   LED_ORANGE <= not med_stat_op(10);
   LED_RED    <= MBS_IN;
   LED_YELLOW <= not med_stat_op(11);

---------------------------------------------------------------------------
-- Test Connector - Logic Analyser
---------------------------------------------------------------------------

  TEST_LINE <= (others => '0');

end architecture;
