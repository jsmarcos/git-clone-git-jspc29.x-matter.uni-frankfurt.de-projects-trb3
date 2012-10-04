library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE IEEE.std_logic_UNSIGNED.ALL;

library work;
   use work.trb_net_std.all;
   use work.trb_net_components.all;
   use work.trb3_components.all;
   use work.trb_net16_hub_func.all;
   use work.version.all;
   use work.trb_net_gbe_components.all;
   
   use work.cts_pkg.all;

--Ports:
--        LVL1/IPU       SCtrl
--  0     FPGA 1         FPGA 1
--  1     FPGA 2         FPGA 2
--  2     FPGA 3         FPGA 3
--  3     FPGA 4         FPGA 4
--  4     opt. link      opt. link
--  5     CTS read-out   internal         0 1 -   X X O   --downlink only
--  6     CTS TRG        Sctrl GbE        2 3 4   X X X   --uplink only

-- MII_NUMBER        => 5,
-- INT_NUMBER        => 5,
-- INT_CHANNELS      => (0,1,0,1,3),

-- No trigger / sctrl sent to optical link, slow control receiving possible
-- MII_IS_UPLINK        => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0);
-- MII_IS_DOWNLINK      => (1,1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0);
-- MII_IS_UPLINK_ONLY   => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0);

-- Trigger / sctrl sent to optical link, slow control receiving possible
-- MII_IS_UPLINK        => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0);
-- MII_IS_DOWNLINK      => (1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0);
-- MII_IS_UPLINK_ONLY   => (0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0);
-- & disable port 4 in c0 and c1 -- no triggers from/to optical link

--Slow Control
--    0 -    7  Readout endpoint common status
--   80 -   AF  Hub status registers
--   C0 -   CF  Hub control registers
-- 4000 - 40FF  Hub status registers
-- 7000 - 72FF  Readout endpoint registers
-- 8100 - 83FF  GbE configuration & status
-- A000 - A1FF  CTS configuration & status
-- D000 - D13F  Flash Programming




entity trb3_central is

  port(
    --Clocks
    CLK_EXT                        : in  std_logic_vector(4 downto 3); --from RJ45
    CLK_GPLL_LEFT                  : in  std_logic;  --Clock Manager 2/9, 200 MHz  <-- MAIN CLOCK
    CLK_GPLL_RIGHT                 : in  std_logic;  --Clock Manager 1/9, 125 MHz  <-- for GbE
    CLK_PCLK_LEFT                  : in  std_logic;  --Clock Fan-out, 200/400 MHz 
    CLK_PCLK_RIGHT                 : in  std_logic;  --Clock Fan-out, 200/400 MHz 

    --Trigger
    TRIGGER_LEFT                   : in  std_logic;  --left side trigger input from fan-out
    TRIGGER_RIGHT                  : in  std_logic;  --right side trigger input from fan-out
    TRIGGER_EXT                    : in  std_logic_vector(4 downto 2); --additional trigger from RJ45
    TRIGGER_OUT                    : out std_logic;  --trigger to second input of fan-out
    TRIGGER_OUT2                   : out std_logic;
    
    --Serdes
    CLK_SERDES_INT_LEFT            : in  std_logic;  --Clock Manager 2/0, 200 MHz, only in case of problems
    CLK_SERDES_INT_RIGHT           : in  std_logic;  --Clock Manager 1/0, off, 125 MHz possible
    
    --SFP
    SFP_RX_P                       : in  std_logic_vector(6 downto 1); 
    SFP_RX_N                       : in  std_logic_vector(6 downto 1); 
    SFP_TX_P                       : out std_logic_vector(6 downto 1); 
    SFP_TX_N                       : out std_logic_vector(6 downto 1); 
    SFP_TX_FAULT                   : in  std_logic_vector(8 downto 1); --TX broken
    SFP_RATE_SEL                   : out std_logic_vector(8 downto 1); --not supported by our SFP
    SFP_LOS                        : in  std_logic_vector(8 downto 1); --Loss of signal
    SFP_MOD0                       : in  std_logic_vector(8 downto 1); --SFP present
    SFP_MOD1                       : in  std_logic_vector(8 downto 1); --I2C interface
    SFP_MOD2                       : in  std_logic_vector(8 downto 1); --I2C interface
    SFP_TXDIS                      : out std_logic_vector(8 downto 1); --disable TX
    
    --Clock and Trigger Control
    TRIGGER_SELECT                 : out std_logic;  --trigger select for fan-out. 0: external, 1: signal from FPGA5
    CLOCK_SELECT                   : out std_logic;  --clock select for fan-out. 0: 200MHz, 1: external from RJ45
    CLK_MNGR1_USER                 : inout std_logic_vector(3 downto 0); --I/O lines to clock manager 1
    CLK_MNGR2_USER                 : inout std_logic_vector(3 downto 0); --I/O lines to clock manager 1
    
    --Inter-FPGA Communication
    FPGA1_COMM                     : inout std_logic_vector(11 downto 0);
    FPGA2_COMM                     : inout std_logic_vector(11 downto 0);
    FPGA3_COMM                     : inout std_logic_vector(11 downto 0);
    FPGA4_COMM                     : inout std_logic_vector(11 downto 0); 
                                    -- on all FPGAn_COMM:  --Bit 0/1 output, serial link TX active
                                                           --Bit 2/3 input, serial link RX active
                                                           --others yet undefined
    FPGA1_TTL                      : inout std_logic_vector(3 downto 0);
    FPGA2_TTL                      : inout std_logic_vector(3 downto 0);
    FPGA3_TTL                      : inout std_logic_vector(3 downto 0);
    FPGA4_TTL                      : inout std_logic_vector(3 downto 0);
                                    --only for not timing-sensitive signals

    --Communication to small addons
    FPGA1_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 2-3: LED for SFP3/4
    FPGA2_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 2-3: LED for SFP7/8
    FPGA3_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 0-1: LED for SFP5/6 
    FPGA4_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 0-1: LED for SFP1/2
                                                                         --Bit 0-3 connected to LED by default, two on each side
                                                                         
    --Big AddOn connector
    ADDON_RESET                    : out std_logic; --reset signal to AddOn
    ADDON_TO_TRB_CLK               : in  std_logic; --Clock from AddOn, connected to PCLK input
    TRB_TO_ADDON_CLK               : out std_logic; --Clock sent to AddOn
    ADO_LV                         : inout std_logic_vector(61 downto 0);
    ADO_TTL                        : inout std_logic_vector(46 downto 0);
    FS_PE                          : inout std_logic_vector(17 downto 0);
    
    --Flash ROM & Reboot
    FLASH_CLK                      : out std_logic;
    FLASH_CS                       : out std_logic;
    FLASH_DIN                      : out std_logic;
    FLASH_DOUT                     : in  std_logic;
    PROGRAMN                       : out std_logic := '1'; --reboot FPGA
    
    --Misc
    ENPIRION_CLOCK                 : out std_logic;  --Clock for power supply, not necessary, floating
    TEMPSENS                       : inout std_logic; --Temperature Sensor
    LED_CLOCK_GREEN                : out std_logic;
    LED_CLOCK_RED                  : out std_logic;
    LED_GREEN                      : out std_logic;
    LED_ORANGE                     : out std_logic; 
    LED_RED                        : out std_logic;
    LED_TRIGGER_GREEN              : out std_logic;
    LED_TRIGGER_RED                : out std_logic; 
    LED_YELLOW                     : out std_logic;

    --Test Connectors
    TEST_LINE                      : out std_logic_vector(31 downto 0)
    );
    
    attribute syn_useioff : boolean;
    --no IO-FF for LEDs relaxes timing constraints
    attribute syn_useioff of LED_CLOCK_GREEN    : signal is false;
    attribute syn_useioff of LED_CLOCK_RED      : signal is false;
    attribute syn_useioff of LED_GREEN          : signal is false;
    attribute syn_useioff of LED_ORANGE         : signal is false;
    attribute syn_useioff of LED_RED            : signal is false;
    attribute syn_useioff of LED_TRIGGER_GREEN  : signal is false;
    attribute syn_useioff of LED_TRIGGER_RED    : signal is false;
    attribute syn_useioff of LED_YELLOW         : signal is false;
    attribute syn_useioff of FPGA1_TTL          : signal is false;
    attribute syn_useioff of FPGA2_TTL          : signal is false;
    attribute syn_useioff of FPGA3_TTL          : signal is false;
    attribute syn_useioff of FPGA4_TTL          : signal is false;
    attribute syn_useioff of SFP_TXDIS          : signal is false;
    attribute syn_useioff of PROGRAMN           : signal is false;
    
    --important signals _with_ IO-FF
    attribute syn_useioff of FLASH_CLK          : signal is true;
    attribute syn_useioff of FLASH_CS           : signal is true;
    attribute syn_useioff of FLASH_DIN          : signal is true;
    attribute syn_useioff of FLASH_DOUT         : signal is true;
    attribute syn_useioff of FPGA1_COMM         : signal is true;
    attribute syn_useioff of FPGA2_COMM         : signal is true;
    attribute syn_useioff of FPGA3_COMM         : signal is true;
    attribute syn_useioff of FPGA4_COMM         : signal is true;


end entity;

architecture trb3_central_arch of trb3_central is
   attribute syn_keep : boolean;
   attribute syn_preserve : boolean;

   signal clk_100_i   : std_logic; --clock for main logic, 100 MHz, via Clock Manager and internal PLL
   signal clk_200_i   : std_logic; --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
   signal pll_lock    : std_logic; --Internal PLL locked. E.g. used to reset all internal logic.
   signal clear_i     : std_logic;
   signal reset_i     : std_logic;
   signal GSR_N       : std_logic;
   attribute syn_keep of GSR_N : signal is true;
   attribute syn_preserve of GSR_N : signal is true;

   --FPGA Test
   signal time_counter, time_counter2 : unsigned(31 downto 0);

   --Media Interface
   signal med_stat_op             : std_logic_vector (5*16-1  downto 0);
   signal med_ctrl_op             : std_logic_vector (5*16-1  downto 0);
   signal med_stat_debug          : std_logic_vector (5*64-1  downto 0);
   signal med_ctrl_debug          : std_logic_vector (5*64-1  downto 0);
   signal med_data_out            : std_logic_vector (5*16-1  downto 0);
   signal med_packet_num_out      : std_logic_vector (5*3-1   downto 0);
   signal med_dataready_out       : std_logic_vector (5*1-1   downto 0);
   signal med_read_out            : std_logic_vector (5*1-1   downto 0);
   signal med_data_in             : std_logic_vector (5*16-1  downto 0);
   signal med_packet_num_in       : std_logic_vector (5*3-1   downto 0);
   signal med_dataready_in        : std_logic_vector (5*1-1   downto 0);
   signal med_read_in             : std_logic_vector (5*1-1   downto 0);

   --Hub
   signal common_stat_regs        : std_logic_vector (std_COMSTATREG*32-1 downto 0);
   signal common_ctrl_regs        : std_logic_vector (std_COMCTRLREG*32-1 downto 0);
   signal my_address              : std_logic_vector (16-1 downto 0);
   signal regio_addr_out          : std_logic_vector (16-1 downto 0);
   signal regio_read_enable_out   : std_logic;
   signal regio_write_enable_out  : std_logic;
   signal regio_data_out          : std_logic_vector (32-1 downto 0);
   signal regio_data_in           : std_logic_vector (32-1 downto 0);
   signal regio_dataready_in      : std_logic;
   signal regio_no_more_data_in   : std_logic;
   signal regio_write_ack_in      : std_logic;
   signal regio_unknown_addr_in   : std_logic;
   signal regio_timeout_out       : std_logic;

   signal spictrl_read_en         : std_logic;
   signal spictrl_write_en        : std_logic;
   signal spictrl_data_in         : std_logic_vector(31 downto 0);
   signal spictrl_addr            : std_logic;
   signal spictrl_data_out        : std_logic_vector(31 downto 0);
   signal spictrl_ack             : std_logic;
   signal spictrl_busy            : std_logic;
   signal spimem_read_en          : std_logic;
   signal spimem_write_en         : std_logic;
   signal spimem_data_in          : std_logic_vector(31 downto 0);
   signal spimem_addr             : std_logic_vector(5 downto 0);
   signal spimem_data_out         : std_logic_vector(31 downto 0);
   signal spimem_ack              : std_logic;

   signal spi_bram_addr           : std_logic_vector(7 downto 0);
   signal spi_bram_wr_d           : std_logic_vector(7 downto 0);
   signal spi_bram_rd_d           : std_logic_vector(7 downto 0);
   signal spi_bram_we             : std_logic;

   signal gbe_cts_number                   : std_logic_vector(15 downto 0);
   signal gbe_cts_code                     : std_logic_vector(7 downto 0);
   signal gbe_cts_information              : std_logic_vector(7 downto 0);
   signal gbe_cts_start_readout            : std_logic;
   signal gbe_cts_readout_type             : std_logic_vector(3 downto 0);
   signal gbe_cts_readout_finished         : std_logic;
   signal gbe_cts_status_bits              : std_logic_vector(31 downto 0);
   signal gbe_fee_data                     : std_logic_vector(15 downto 0);
   signal gbe_fee_dataready                : std_logic;
   signal gbe_fee_read                     : std_logic;
   signal gbe_fee_status_bits              : std_logic_vector(31 downto 0);
   signal gbe_fee_busy                     : std_logic;

   signal stage_stat_regs              : std_logic_vector (31 downto 0);
   signal stage_ctrl_regs              : std_logic_vector (31 downto 0);

   signal mb_stat_reg_data_wr          : std_logic_vector(31 downto 0);
   signal mb_stat_reg_data_rd          : std_logic_vector(31 downto 0);
   signal mb_stat_reg_read             : std_logic;
   signal mb_stat_reg_write            : std_logic;
   signal mb_stat_reg_ack              : std_logic;
   signal mb_ip_mem_addr               : std_logic_vector(15 downto 0); -- only [7:0] in used
   signal mb_ip_mem_data_wr            : std_logic_vector(31 downto 0);
   signal mb_ip_mem_data_rd            : std_logic_vector(31 downto 0);
   signal mb_ip_mem_read               : std_logic;
   signal mb_ip_mem_write              : std_logic;
   signal mb_ip_mem_ack                : std_logic;
   signal ip_cfg_mem_clk				: std_logic;
   signal ip_cfg_mem_addr				: std_logic_vector(7 downto 0);
   signal ip_cfg_mem_data				: std_logic_vector(31 downto 0);
   signal ctrl_reg_addr                : std_logic_vector(15 downto 0);
   signal gbe_stp_reg_addr             : std_logic_vector(15 downto 0);
   signal gbe_stp_data                 : std_logic_vector(31 downto 0);
   signal gbe_stp_reg_ack              : std_logic;
   signal gbe_stp_reg_data_wr          : std_logic_vector(31 downto 0);
   signal gbe_stp_reg_read             : std_logic;
   signal gbe_stp_reg_write            : std_logic;
   signal gbe_stp_reg_data_rd          : std_logic_vector(31 downto 0);

   signal debug : std_logic_vector(63 downto 0);

   signal next_reset, make_reset_via_network_q : std_logic;
   signal reset_counter : std_logic_vector(11 downto 0);
   signal link_ok : std_logic;

   signal gsc_init_data, gsc_reply_data : std_logic_vector(15 downto 0);
   signal gsc_init_read, gsc_reply_read : std_logic;
   signal gsc_init_dataready, gsc_reply_dataready : std_logic;
   signal gsc_init_packet_num, gsc_reply_packet_num : std_logic_vector(2 downto 0);
   signal gsc_busy : std_logic;
   signal mc_unique_id  : std_logic_vector(63 downto 0);
   signal trb_reset_in  : std_logic;
   signal reset_via_gbe : std_logic;
   signal reset_via_gbe_delayed : std_logic_vector(2 downto 0);
   signal reset_i_temp  : std_logic;

   signal cts_rdo_trigger             : std_logic;
   signal cts_rdo_trg_data_valid      : std_logic;
   signal cts_rdo_valid_timing_trg    : std_logic;
   signal cts_rdo_valid_notiming_trg  : std_logic;
   signal cts_rdo_invalid_trg         : std_logic;

   signal cts_rdo_trg_status_bits,
      cts_rdo_trg_status_bits_cts,
      cts_rdo_trg_status_bits_additional: std_logic_vector(31 downto 0) := (others => '0');
   signal cts_rdo_data                : std_logic_vector(31 downto 0);
   signal cts_rdo_write               : std_logic;
   signal cts_rdo_finished            : std_logic;

   signal cts_ext_trigger             : std_logic;
   signal cts_ext_status              : std_logic_vector(31 downto 0) := (others => '0');
   signal cts_ext_control             : std_logic_vector(31 downto 0);

   signal cts_rdo_additional_data     : std_logic_vector(31 downto 0);
   signal cts_rdo_additional_write    : std_logic := '0';
   signal cts_rdo_additional_finished : std_logic := '0';

   signal cts_trg_send                : std_logic;
   signal cts_trg_type                : std_logic_vector(3 downto 0);
   signal cts_trg_number              : std_logic_vector(15 downto 0);
   signal cts_trg_information         : std_logic_vector(23 downto 0);
   signal cts_trg_code                : std_logic_vector(7 downto 0);
   signal cts_trg_status_bits         : std_logic_vector(31 downto 0);
   signal cts_trg_busy                : std_logic;

   signal cts_ipu_send                : std_logic;
   signal cts_ipu_type                : std_logic_vector(3 downto 0);
   signal cts_ipu_number              : std_logic_vector(15 downto 0);
   signal cts_ipu_information         : std_logic_vector(7 downto 0);
   signal cts_ipu_code                : std_logic_vector(7 downto 0);
   signal cts_ipu_status_bits         : std_logic_vector(31 downto 0);
   signal cts_ipu_busy                : std_logic;

   signal cts_regio_addr              : std_logic_vector(15 downto 0);
   signal cts_regio_read              : std_logic;
   signal cts_regio_write             : std_logic;
   signal cts_regio_data_out          : std_logic_vector(31 downto 0);
   signal cts_regio_data_in           : std_logic_vector(31 downto 0);
   signal cts_regio_dataready         : std_logic;
   signal cts_regio_no_more_data      : std_logic;
   signal cts_regio_write_ack         : std_logic;
   signal cts_regio_unknown_addr      : std_logic;

   signal cts_trigger_out             : std_logic;
   signal external_send_reset         : std_logic;
   signal timer_ticks                 : std_logic_vector(1 downto 0);
   
   signal trigger_busy_i              : std_logic;
   signal trigger_in_buf_i            : std_logic_vector(3 downto 0);

   component mbs_vulom_recv is
   port(
      CLK        : in std_logic;  -- e.g. 100 MHz
      RESET_IN   : in std_logic;  -- could be used after busy_release to make sure entity is in correct state

      --Module inputs
      MBS_IN     : in std_logic;  -- raw input
      CLK_200    : in std_logic;  -- internal sampling clock
      
      --trigger outputs
      TRG_ASYNC_OUT  : out std_logic;  -- asynchronous rising edge, length varying, here: approx. 110 ns
      TRG_SYNC_OUT   : out std_logic;  -- sync. to CLK

      --data output for read-out
      TRIGGER_IN   : in  std_logic;
      DATA_OUT     : out std_logic_vector(31 downto 0);
      WRITE_OUT    : out std_logic;
      STATUSBIT_OUT: out std_logic_vector(31 downto 0);
      FINISHED_OUT : out std_logic;
      
      --Registers / Debug    
      CONTROL_REG_IN : in  std_logic_vector(31 downto 0);
      STATUS_REG_OUT : out std_logic_vector(31 downto 0);
      DEBUG          : out std_logic_vector(31 downto 0)    
      );
   end component;

begin
-- MBS Module
   THE_CMB: mbs_vulom_recv
   port map (
      CLK => clk_100_i,
      RESET_IN => reset_i,
      
      MBS_IN => CLK_EXT(3),
      CLK_200 => clk_200_i,
      
      -- TRG_ASYNC_OUT => ,
      TRG_SYNC_OUT => cts_ext_trigger,
      
      TRIGGER_IN     => cts_rdo_trg_data_valid,
      DATA_OUT       => cts_rdo_additional_data,
      WRITE_OUT      => cts_rdo_additional_write,
      STATUSBIT_OUT  => cts_rdo_trg_status_bits_additional,
      FINISHED_OUT   => cts_rdo_additional_finished,

      CONTROL_REG_IN => cts_ext_control,
      STATUS_REG_OUT => cts_ext_status
      
      -- DEBUG => ''
   );

   trigger_in_buf_i(1 downto 0) <= CLK_EXT;
   trigger_in_buf_i(3 downto 2) <= TRIGGER_EXT(3 downto 2);

   THE_CTS: CTS 
   generic map (
      EXTERNAL_TRIGGER_ID  => X"60", --, fill in trigger logic enumeration id of external trigger logic
      TRIGGER_INPUT_COUNT  => 4,
      TRIGGER_COIN_COUNT   => 4,
      TRIGGER_PULSER_COUNT => 4,
      TRIGGER_RAND_PULSER  => 1
   )
   port map ( 
      CLK => clk_100_i,
      RESET => reset_i,
      
      TRIGGERS_IN => trigger_in_buf_i,
      TRIGGER_BUSY_OUT => trigger_busy_i,
      TIME_REFERENCE_OUT => cts_trigger_out,
      
      EXT_TRIGGER_IN => cts_ext_trigger,
      EXT_STATUS_IN  => cts_ext_status,
      EXT_CONTROL_OUT => cts_ext_control, 
      
      CTS_TRG_SEND_OUT => cts_trg_send,
      CTS_TRG_TYPE_OUT => cts_trg_type,
      CTS_TRG_NUMBER_OUT => cts_trg_number,
      CTS_TRG_INFORMATION_OUT => cts_trg_information,
      CTS_TRG_RND_CODE_OUT => cts_trg_code,
      CTS_TRG_STATUS_BITS_IN => cts_trg_status_bits,
      CTS_TRG_BUSY_IN => cts_trg_busy,
       
      CTS_IPU_SEND_OUT => cts_ipu_send,
      CTS_IPU_TYPE_OUT => cts_ipu_type,
      CTS_IPU_NUMBER_OUT => cts_ipu_number,
      CTS_IPU_INFORMATION_OUT => cts_ipu_information,
      CTS_IPU_RND_CODE_OUT => cts_ipu_code,
      CTS_IPU_STATUS_BITS_IN => cts_ipu_status_bits,
      CTS_IPU_BUSY_IN => cts_ipu_busy,
       
      CTS_REGIO_ADDR_IN => cts_regio_addr,
      CTS_REGIO_DATA_IN => cts_regio_data_out,
      CTS_REGIO_READ_ENABLE_IN => cts_regio_read,
      CTS_REGIO_WRITE_ENABLE_IN => cts_regio_write,
      CTS_REGIO_DATA_OUT => cts_regio_data_in,
      CTS_REGIO_DATAREADY_OUT => cts_regio_dataready,
      CTS_REGIO_WRITE_ACK_OUT => cts_regio_write_ack,
      CTS_REGIO_UNKNOWN_ADDR_OUT => cts_regio_unknown_addr,
  
      LVL1_TRG_DATA_VALID_IN    => cts_rdo_trg_data_valid,
      LVL1_VALID_TIMING_TRG_IN  => cts_rdo_valid_timing_trg,
      LVL1_VALID_NOTIMING_TRG_IN=> cts_rdo_valid_notiming_trg,
      LVL1_INVALID_TRG_IN       => cts_rdo_invalid_trg,
  
      FEE_TRG_STATUSBITS_OUT  => cts_rdo_trg_status_bits_cts,
      FEE_DATA_OUT            => cts_rdo_data,
      FEE_DATA_WRITE_OUT      => cts_rdo_write,
      FEE_DATA_FINISHED_OUT   => cts_rdo_finished
   );   
   
--    cts_rdo_trg_status_bits <= cts_rdo_trg_status_bits_cts OR cts_rdo_trg_status_bits_additional;
   
---------------------------------------------------------------------------
-- Reset Generation
---------------------------------------------------------------------------

GSR_N   <= pll_lock;
  
-- THE_RESET_HANDLER : trb_net_reset_handler
--   generic map(
--     RESET_DELAY     => x"FEEE"
--     )
--   port map(
--     CLEAR_IN        => '0',             -- reset input (high active, async)
--     CLEAR_N_IN      => '1',             -- reset input (low active, async)
--     CLK_IN          => clk_200_i,       -- raw master clock, NOT from PLL/DLL!
--     SYSCLK_IN       => clk_100_i,       -- PLL/DLL remastered clock
--     PLL_LOCKED_IN   => pll_lock,        -- master PLL lock signal (async)
--     RESET_IN        => '0',             -- general reset signal (SYSCLK)
--     TRB_RESET_IN    => trb_reset_in, -- TRBnet reset signal (SYSCLK)
--     CLEAR_OUT       => clear_i,         -- async reset out, USE WITH CARE!
--     RESET_OUT       => reset_i,         -- synchronous reset out (SYSCLK)
--     DEBUG_OUT       => open
--   );
-- 
-- trb_reset_in <= med_stat_op(4*16+13) or reset_via_gbe;

THE_RESET_HANDLER : trb_net_reset_handler
  generic map(
    RESET_DELAY     => x"FEEE"
    )
  port map(
    CLEAR_IN        => '0',             -- reset input (high active, async)
    CLEAR_N_IN      => '1',             -- reset input (low active, async)
    CLK_IN          => clk_200_i,       -- raw master clock, NOT from PLL/DLL!
    SYSCLK_IN       => clk_100_i,       -- PLL/DLL remastered clock
    PLL_LOCKED_IN   => pll_lock,        -- master PLL lock signal (async)
    RESET_IN        => '0',             -- general reset signal (SYSCLK)
    TRB_RESET_IN    => '0',             -- TRBnet reset signal (SYSCLK)
    CLEAR_OUT       => clear_i,         -- async reset out, USE WITH CARE!
    RESET_OUT       => reset_i_temp,    -- synchronous reset out (SYSCLK)
    DEBUG_OUT       => open
  );

trb_reset_in <= reset_via_gbe_delayed(2) or MED_STAT_OP(4*16+13);
reset_i <= reset_i_temp or trb_reset_in;

process begin
  wait until rising_edge(clk_100_i);
    if reset_i = '1' then
      reset_via_gbe_delayed <= "000";
    elsif timer_ticks(0) = '1' then
      reset_via_gbe_delayed <= reset_via_gbe_delayed(1 downto 0) & reset_via_gbe;
    end if;
  end process;


---------------------------------------------------------------------------
-- Clock Handling
---------------------------------------------------------------------------
THE_MAIN_PLL : pll_in200_out100
  port map(
    CLK    => CLK_GPLL_LEFT,
    CLKOP  => clk_100_i,
    CLKOK  => clk_200_i,
    LOCK   => pll_lock
    );


---------------------------------------------------------------------------
-- The TrbNet media interface (Uplink)
---------------------------------------------------------------------------
THE_MEDIA_UPLINK : trb_net16_med_ecp3_sfp
  generic map(
    SERDES_NUM  => 0,     --number of serdes in quad
    EXT_CLOCK   => c_NO,  --use internal clock
    USE_200_MHZ => c_YES, --run on 200 MHz clock
    USE_CTC     => c_YES
    )
  port map(
    CLK                => clk_200_i,
    SYSCLK             => clk_100_i,
    RESET              => reset_i,
    CLEAR              => clear_i,
    CLK_EN             => '1',
    --Internal Connection
    MED_DATA_IN        => med_data_out(79 downto 64),
    MED_PACKET_NUM_IN  => med_packet_num_out(14 downto 12),
    MED_DATAREADY_IN   => med_dataready_out(4),
    MED_READ_OUT       => med_read_in(4),
    MED_DATA_OUT       => med_data_in(79 downto 64),
    MED_PACKET_NUM_OUT => med_packet_num_in(14 downto 12),
    MED_DATAREADY_OUT  => med_dataready_in(4),
    MED_READ_IN        => med_read_out(4),
    REFCLK2CORE_OUT    => open,
    --SFP Connection
    SD_RXD_P_IN        => SFP_RX_P(1),
    SD_RXD_N_IN        => SFP_RX_N(1),
    SD_TXD_P_OUT       => SFP_TX_P(1),
    SD_TXD_N_OUT       => SFP_TX_N(1),
    SD_REFCLK_P_IN     => open,
    SD_REFCLK_N_IN     => open,
    SD_PRSNT_N_IN      => SFP_MOD0(1),
    SD_LOS_IN          => SFP_LOS(1),
    SD_TXDIS_OUT       => SFP_TXDIS(1),
    -- Status and control port
    STAT_OP            => med_stat_op(79 downto 64),
    CTRL_OP            => med_ctrl_op(79 downto 64),
    STAT_DEBUG         => med_stat_debug(4*64+63 downto 4*64),
    CTRL_DEBUG         => (others => '0')
   );


SFP_TXDIS(7 downto 2) <= (others => '1');

---------------------------------------------------------------------------
-- The TrbNet media interface (to other FPGA)
---------------------------------------------------------------------------
THE_MEDIA_ONBOARD : trb_net16_med_ecp3_sfp_4_onboard
  port map(
    CLK                => clk_200_i,
    SYSCLK             => clk_100_i,
    RESET              => reset_i,
    CLEAR              => clear_i,
    CLK_EN             => '1',
    --Internal Connection
    MED_DATA_IN        => med_data_out(63 downto 0),
    MED_PACKET_NUM_IN  => med_packet_num_out(11 downto 0),
    MED_DATAREADY_IN   => med_dataready_out(3 downto 0),
    MED_READ_OUT       => med_read_in(3 downto 0),
    MED_DATA_OUT       => med_data_in(63 downto 0),
    MED_PACKET_NUM_OUT => med_packet_num_in(11 downto 0),
    MED_DATAREADY_OUT  => med_dataready_in(3 downto 0),
    MED_READ_IN        => med_read_out(3 downto 0),
    REFCLK2CORE_OUT    => open,
    --SFP Connection
    SD_RXD_P_IN        => SFP_RX_P(5 downto 2),
    SD_RXD_N_IN        => SFP_RX_N(5 downto 2),
    SD_TXD_P_OUT       => SFP_TX_P(5 downto 2),
    SD_TXD_N_OUT       => SFP_TX_N(5 downto 2),
    SD_REFCLK_P_IN     => open,
    SD_REFCLK_N_IN     => open,
    SD_PRSNT_N_IN(0)   => FPGA1_COMM(2),
    SD_PRSNT_N_IN(1)   => FPGA2_COMM(2),
    SD_PRSNT_N_IN(2)   => FPGA3_COMM(2),
    SD_PRSNT_N_IN(3)   => FPGA4_COMM(2),
    SD_LOS_IN(0)       => FPGA1_COMM(2),
    SD_LOS_IN(1)       => FPGA2_COMM(2),
    SD_LOS_IN(2)       => FPGA3_COMM(2),
    SD_LOS_IN(3)       => FPGA4_COMM(2),
    SD_TXDIS_OUT(0)    => FPGA1_COMM(0),
    SD_TXDIS_OUT(1)    => FPGA2_COMM(0),
    SD_TXDIS_OUT(2)    => FPGA3_COMM(0),
    SD_TXDIS_OUT(3)    => FPGA4_COMM(0),
    -- Status and control port
    STAT_OP            => med_stat_op(63 downto 0),
    CTRL_OP            => med_ctrl_op(63 downto 0),
    STAT_DEBUG         => med_stat_debug(3*64+63 downto 0*64),
    CTRL_DEBUG         => (others => '0')
   );



---------------------------------------------------------------------------
-- The TrbNet Hub
---------------------------------------------------------------------------


  THE_HUB: trb_net16_hub_streaming_port_sctrl_cts
  generic map( 
	  INIT_ADDRESS        => x"F3C0",
	  MII_NUMBER          => 5,
-- 	  MII_IS_UPLINK       => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0),
-- 	  MII_IS_DOWNLINK     => (1,1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0),
-- 	  MII_IS_UPLINK_ONLY  => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0),
    MII_IS_UPLINK        => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0),
    MII_IS_DOWNLINK      => (1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0),
    MII_IS_UPLINK_ONLY   => (0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0),	  
    COMPILE_TIME                     => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,32)),
    COMPILE_VERSION                  => x"0001",
    HARDWARE_VERSION                 => x"9000CEE0",
    INIT_ENDPOINT_ID                 => x"0005",
    BROADCAST_BITMASK                => x"7E",
    CLOCK_FREQUENCY                  => 100,
    USE_ONEWIRE                      => c_YES,
    BROADCAST_SPECIAL_ADDR           => x"35",
    RDO_ADDITIONAL_PORT              => c_YES,
    RDO_DATA_BUFFER_DEPTH            => 9,
    RDO_DATA_BUFFER_FULL_THRESH      => 2**8,
    RDO_HEADER_BUFFER_DEPTH          => 9,
    RDO_HEADER_BUFFER_FULL_THRESH    => 2**8	  
    )
  port map( 
	  CLK                     => clk_100_i,
	  RESET                   => reset_i,
	  CLK_EN                  => '1',
 
	  --Media interfacces
	  MED_DATAREADY_OUT(5*1-1 downto 0)   => med_dataready_out,
	  MED_DATA_OUT(5*16-1 downto 0)       => med_data_out,
	  MED_PACKET_NUM_OUT(5*3-1 downto 0)  => med_packet_num_out,
	  MED_READ_IN(5*1-1 downto 0)         => med_read_in,
	  MED_DATAREADY_IN(5*1-1 downto 0)    => med_dataready_in,
	  MED_DATA_IN(5*16-1 downto 0)        => med_data_in,
	  MED_PACKET_NUM_IN(5*3-1 downto 0)   => med_packet_num_in,
	  MED_READ_OUT(5*1-1 downto 0)        => med_read_out,
	  MED_STAT_OP(5*16-1 downto 0)        => med_stat_op,
	  MED_CTRL_OP(5*16-1 downto 0)        => med_ctrl_op,

-- Gbe Read-out Path ---------------------------------------------------------------
    --Event information coming from CTS for GbE
    GBE_CTS_NUMBER_OUT             => gbe_cts_number,
    GBE_CTS_CODE_OUT               => gbe_cts_code,
    GBE_CTS_INFORMATION_OUT        => gbe_cts_information,
    GBE_CTS_READOUT_TYPE_OUT       => gbe_cts_readout_type,
    GBE_CTS_START_READOUT_OUT      => gbe_cts_start_readout,
    --Information sent to CTS
    GBE_CTS_READOUT_FINISHED_IN    => gbe_cts_readout_finished,
    GBE_CTS_STATUS_BITS_IN         => gbe_cts_status_bits,
    -- Data from Frontends
    GBE_FEE_DATA_OUT               => gbe_fee_data,
    GBE_FEE_DATAREADY_OUT          => gbe_fee_dataready,
    GBE_FEE_READ_IN                => gbe_fee_read,
    GBE_FEE_STATUS_BITS_OUT        => gbe_fee_status_bits,
    GBE_FEE_BUSY_OUT               => gbe_fee_busy,

-- CTS Request Sending -------------------------------------------------------------
    --LVL1 trigger
    CTS_TRG_SEND_IN                => cts_trg_send,
    CTS_TRG_TYPE_IN                => cts_trg_type,
    CTS_TRG_NUMBER_IN              => cts_trg_number,
    CTS_TRG_INFORMATION_IN         => cts_trg_information,
    CTS_TRG_RND_CODE_IN            => cts_trg_code,
    CTS_TRG_STATUS_BITS_OUT        => cts_trg_status_bits,
    CTS_TRG_BUSY_OUT               => cts_trg_busy,
    --IPU Channel
    CTS_IPU_SEND_IN                => cts_ipu_send,
    CTS_IPU_TYPE_IN                => cts_ipu_type,
    CTS_IPU_NUMBER_IN              => cts_ipu_number,
    CTS_IPU_INFORMATION_IN         => cts_ipu_information,
    CTS_IPU_RND_CODE_IN            => cts_ipu_code,
    -- Receiver port
    CTS_IPU_STATUS_BITS_OUT        => cts_ipu_status_bits,
    CTS_IPU_BUSY_OUT               => cts_ipu_busy,
    
-- CTS Data Readout ----------------------------------------------------------------
    --Trigger In
    RDO_TRIGGER_IN                 => cts_rdo_trigger,
    RDO_TRG_DATA_VALID_OUT         => cts_rdo_trg_data_valid,
    RDO_VALID_TIMING_TRG_OUT       => cts_rdo_valid_timing_trg,
    RDO_VALID_NOTIMING_TRG_OUT     => cts_rdo_valid_notiming_trg,
    RDO_INVALID_TRG_OUT            => cts_rdo_invalid_trg,
    --Data out
    RDO_TRG_STATUSBITS_IN          => cts_rdo_trg_status_bits_cts,
    RDO_DATA_IN                    => cts_rdo_data,
    RDO_DATA_WRITE_IN              => cts_rdo_write,
    RDO_DATA_FINISHED_IN           => cts_rdo_finished,
    
    RDO_ADDITIONAL_STATUSBITS_IN   => cts_rdo_trg_status_bits_additional,
    RDO_ADDITIONAL_DATA            => cts_rdo_additional_data,
    RDO_ADDITIONAL_WRITE           => cts_rdo_additional_write,
    RDO_ADDITIONAL_FINISHED        => cts_rdo_additional_finished,
    
	  COMMON_STAT_REGS        => common_stat_regs, --open,
	  COMMON_CTRL_REGS        => common_ctrl_regs, --open,
	  ONEWIRE                 => TEMPSENS,
	  ONEWIRE_MONITOR_IN      => open,
	  MY_ADDRESS_OUT          => my_address,
    UNIQUE_ID_OUT           => mc_unique_id,
    TIMER_TICKS_OUT         => timer_ticks,
    EXTERNAL_SEND_RESET     => reset_via_gbe,

	  REGIO_ADDR_OUT          => regio_addr_out,
	  REGIO_READ_ENABLE_OUT   => regio_read_enable_out,
	  REGIO_WRITE_ENABLE_OUT  => regio_write_enable_out,
	  REGIO_DATA_OUT          => regio_data_out,
	  REGIO_DATA_IN           => regio_data_in,
	  REGIO_DATAREADY_IN      => regio_dataready_in,
	  REGIO_NO_MORE_DATA_IN   => regio_no_more_data_in,
	  REGIO_WRITE_ACK_IN      => regio_write_ack_in,
	  REGIO_UNKNOWN_ADDR_IN   => regio_unknown_addr_in,
	  REGIO_TIMEOUT_OUT       => regio_timeout_out,

    --Gbe Sctrl Input
    GSC_INIT_DATAREADY_IN        => gsc_init_dataready,
    GSC_INIT_DATA_IN             => gsc_init_data,
    GSC_INIT_PACKET_NUM_IN       => gsc_init_packet_num,
    GSC_INIT_READ_OUT            => gsc_init_read,
    GSC_REPLY_DATAREADY_OUT      => gsc_reply_dataready,
    GSC_REPLY_DATA_OUT           => gsc_reply_data,
    GSC_REPLY_PACKET_NUM_OUT     => gsc_reply_packet_num,
    GSC_REPLY_READ_IN            => gsc_reply_read,
    GSC_BUSY_OUT                 => gsc_busy,

  --status and control ports
    HUB_STAT_CHANNEL             => open,
    HUB_STAT_GEN                 => open,
    MPLEX_CTRL                   => (others => '0'),
    MPLEX_STAT                   => open,
    STAT_REGS                    => open,
    STAT_CTRL_REGS               => open,

	  --Fixed status and control ports
	  STAT_DEBUG              => open,
	  CTRL_DEBUG              => (others => '0')
  );

  
  ---------------------------------------------------------------------
  -- The GbE machine for blasting out data from TRBnet
  ---------------------------------------------------------------------

  GBE: trb_net16_gbe_buf
  generic map( 
	  DO_SIMULATION               => c_NO,
	  USE_125MHZ_EXTCLK           => c_NO
  )
  port map( 
	  CLK                         => clk_100_i,
	  TEST_CLK                    => '0',
	  CLK_125_IN                  => CLK_GPLL_RIGHT,
	  RESET                       => reset_i,
	  GSR_N                       => gsr_n,
	  --Debug
	  STAGE_STAT_REGS_OUT         => open, --stage_stat_regs, -- should be come STATUS or similar
	  STAGE_CTRL_REGS_IN          => stage_ctrl_regs, -- OBSELETE!
	  ----gk 22.04.10 not used any more, ip_configurator moved inside
	  ---configuration interface
	  IP_CFG_START_IN              => stage_ctrl_regs(15),
	  IP_CFG_BANK_SEL_IN           => stage_ctrl_regs(11 downto 8),
	  IP_CFG_DONE_OUT              => open,
	  IP_CFG_MEM_ADDR_OUT          => ip_cfg_mem_addr,
	  IP_CFG_MEM_DATA_IN           => ip_cfg_mem_data,
	  IP_CFG_MEM_CLK_OUT           => ip_cfg_mem_clk,
	  MR_RESET_IN                  => stage_ctrl_regs(3),
	  MR_MODE_IN                   => stage_ctrl_regs(1),
	  MR_RESTART_IN                => stage_ctrl_regs(0),
	  ---gk 29.03.10
	  --interface to ip_configurator memory
	  SLV_ADDR_IN                  => mb_ip_mem_addr(7 downto 0),
	  SLV_READ_IN                  => mb_ip_mem_read,
	  SLV_WRITE_IN                 => mb_ip_mem_write,
	  SLV_BUSY_OUT                 => open,
	  SLV_ACK_OUT                  => mb_ip_mem_ack,
	  SLV_DATA_IN                  => mb_ip_mem_data_wr,
	  SLV_DATA_OUT                 => mb_ip_mem_data_rd,
	  --gk 26.04.10
	  ---gk 22.04.10
	  ---registers setup interface
	  BUS_ADDR_IN                 => gbe_stp_reg_addr(7 downto 0), --ctrl_reg_addr(7 downto 0),
	  BUS_DATA_IN                 => gbe_stp_reg_data_wr, --stage_ctrl_regs,
	  BUS_DATA_OUT                => gbe_stp_reg_data_rd,
	  BUS_WRITE_EN_IN             => gbe_stp_reg_write,
	  BUS_READ_EN_IN              => gbe_stp_reg_read,
	  BUS_ACK_OUT                 => gbe_stp_reg_ack,
	  --gk 23.04.10
	  LED_PACKET_SENT_OUT         => open, --buf_SFP_LED_ORANGE(17),
	  LED_AN_DONE_N_OUT           => link_ok, --buf_SFP_LED_GREEN(17),
    --CTS interface
    CTS_NUMBER_IN               => gbe_cts_number,
    CTS_CODE_IN                 => gbe_cts_code,
    CTS_INFORMATION_IN          => gbe_cts_information,
    CTS_READOUT_TYPE_IN         => gbe_cts_readout_type,
    CTS_START_READOUT_IN        => gbe_cts_start_readout,
    CTS_DATA_OUT                => open,
    CTS_DATAREADY_OUT           => open,
    CTS_READOUT_FINISHED_OUT    => gbe_cts_readout_finished,
    CTS_READ_IN                 => '1',
    CTS_LENGTH_OUT              => open,
    CTS_ERROR_PATTERN_OUT       => gbe_cts_status_bits,
    --Data payload interface
    FEE_DATA_IN                 => gbe_fee_data,
    FEE_DATAREADY_IN            => gbe_fee_dataready,
    FEE_READ_OUT                => gbe_fee_read,
    FEE_STATUS_BITS_IN          => gbe_fee_status_bits,
    FEE_BUSY_IN                 => gbe_fee_busy,
	  --SFP   Connection
	  SFP_RXD_P_IN                => SFP_RX_P(6), --these ports are don't care
	  SFP_RXD_N_IN                => SFP_RX_N(6),
	  SFP_TXD_P_OUT               => SFP_TX_P(6),
	  SFP_TXD_N_OUT               => SFP_TX_N(6),
	  SFP_REFCLK_P_IN             => open, --SFP_REFCLKP(2),
	  SFP_REFCLK_N_IN             => open, --SFP_REFCLKN(2),
	  SFP_PRSNT_N_IN              => SFP_MOD0(8), -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
	  SFP_LOS_IN                  => SFP_LOS(8), -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
	  SFP_TXDIS_OUT               => SFP_TXDIS(8),  -- SFP disable

    -- interface between main_controller and hub logic
    MC_UNIQUE_ID_IN          => mc_unique_id,
    GSC_CLK_IN               => clk_100_i,
    GSC_INIT_DATAREADY_OUT   => gsc_init_dataready,
    GSC_INIT_DATA_OUT        => gsc_init_data,
    GSC_INIT_PACKET_NUM_OUT  => gsc_init_packet_num,
    GSC_INIT_READ_IN         => gsc_init_read,
    GSC_REPLY_DATAREADY_IN   => gsc_reply_dataready,
    GSC_REPLY_DATA_IN        => gsc_reply_data,
    GSC_REPLY_PACKET_NUM_IN  => gsc_reply_packet_num,
    GSC_REPLY_READ_OUT       => gsc_reply_read,
    GSC_BUSY_IN              => gsc_busy,

    MAKE_RESET_OUT           => reset_via_gbe,

	  --for simulation of receiving part only
	  MAC_RX_EOF_IN		=> '0',
	  MAC_RXD_IN		=> "00000000",
	  MAC_RX_EN_IN		=> '0',

	  ANALYZER_DEBUG_OUT          => debug
  );


---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
THE_BUS_HANDLER : trb_net16_regio_bus_handler
  generic map(
    PORT_NUMBER    => 5,
    PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", 2 => x"8100", 3 => x"8300", 4 => x"a000", others => x"0000"),
    PORT_ADDR_MASK => (0 => 1,       1 => 6,       2 => 8,       3 => 8,       4 => 9,       others => 0)
    )
  port map(
    CLK                   => clk_100_i,
    RESET                 => reset_i,

    DAT_ADDR_IN           => regio_addr_out,
    DAT_DATA_IN           => regio_data_out,
    DAT_DATA_OUT          => regio_data_in,
    DAT_READ_ENABLE_IN    => regio_read_enable_out,
    DAT_WRITE_ENABLE_IN   => regio_write_enable_out,
    DAT_TIMEOUT_IN        => regio_timeout_out,
    DAT_DATAREADY_OUT     => regio_dataready_in,
    DAT_WRITE_ACK_OUT     => regio_write_ack_in,
    DAT_NO_MORE_DATA_OUT  => regio_no_more_data_in,
    DAT_UNKNOWN_ADDR_OUT  => regio_unknown_addr_in,

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

	-- third one - IP config memory
	BUS_ADDR_OUT(3*16-1 downto 2*16) => mb_ip_mem_addr,
	BUS_DATA_OUT(3*32-1 downto 2*32) => mb_ip_mem_data_wr,
	BUS_READ_ENABLE_OUT(2)           => mb_ip_mem_read,
	BUS_WRITE_ENABLE_OUT(2)          => mb_ip_mem_write,
	BUS_TIMEOUT_OUT(2)               => open,
	BUS_DATA_IN(3*32-1 downto 2*32)  => mb_ip_mem_data_rd,
	BUS_DATAREADY_IN(2)              => mb_ip_mem_ack,
	BUS_WRITE_ACK_IN(2)              => mb_ip_mem_ack,
	BUS_NO_MORE_DATA_IN(2)           => '0',
	BUS_UNKNOWN_ADDR_IN(2)           => '0',

	-- gk 22.04.10
	-- gbe setup
	BUS_ADDR_OUT(4*16-1 downto 3*16) => gbe_stp_reg_addr,
	BUS_DATA_OUT(4*32-1 downto 3*32) => gbe_stp_reg_data_wr,
	BUS_READ_ENABLE_OUT(3)           => gbe_stp_reg_read,
	BUS_WRITE_ENABLE_OUT(3)          => gbe_stp_reg_write,
	BUS_TIMEOUT_OUT(3)               => open,
	BUS_DATA_IN(4*32-1 downto 3*32)  => gbe_stp_reg_data_rd,
	BUS_DATAREADY_IN(3)              => gbe_stp_reg_ack,
	BUS_WRITE_ACK_IN(3)              => gbe_stp_reg_ack,
	BUS_NO_MORE_DATA_IN(3)           => '0',
	BUS_UNKNOWN_ADDR_IN(3)           => '0',
	
	-- CTS
   BUS_ADDR_OUT(5*16-1 downto 4*16) => cts_regio_addr,
   BUS_DATA_OUT(5*32-1 downto 4*32) => cts_regio_data_out,
   BUS_READ_ENABLE_OUT(4)           => cts_regio_read,
   BUS_WRITE_ENABLE_OUT(4)          => cts_regio_write,
   BUS_TIMEOUT_OUT(4)               => open,
   BUS_DATA_IN(5*32-1 downto 4*32)  => cts_regio_data_in,
   BUS_DATAREADY_IN(4)              => cts_regio_dataready,
   BUS_WRITE_ACK_IN(4)              => cts_regio_write_ack,
   BUS_NO_MORE_DATA_IN(4)           => '0',
   BUS_UNKNOWN_ADDR_IN(4)           => cts_regio_unknown_addr,
   
   STAT_DEBUG  => open
    );

---------------------------------------------------------------------------
-- SPI / Flash
---------------------------------------------------------------------------

THE_SPI_MASTER: spi_master
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
THE_SPI_MEMORY: spi_databus_memory
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
    DO_REBOOT => common_ctrl_regs(15),
    PROGRAMN  => PROGRAMN
    );

    
---------------------------------------------------------------------------
-- Clock and Trigger Configuration
---------------------------------------------------------------------------
  TRIGGER_SELECT <= '1'; --always internal trigger source
  CLOCK_SELECT   <= '0'; --use on-board oscillator
  CLK_MNGR1_USER <= (others => '0');
  CLK_MNGR2_USER <= (others => '0'); 

  TRIGGER_OUT    <= cts_trigger_out;
  TRIGGER_OUT2   <= cts_trigger_out;

---------------------------------------------------------------------------
-- FPGA communication
---------------------------------------------------------------------------
--   FPGA1_COMM <= (others => 'Z');
--   FPGA2_COMM <= (others => 'Z');
--   FPGA3_COMM <= (others => 'Z');
--   FPGA4_COMM <= (others => 'Z');

  FPGA1_TTL <= (others => 'Z');
  FPGA2_TTL <= (others => 'Z');
  FPGA3_TTL <= (others => 'Z');
  FPGA4_TTL <= (others => 'Z');

  FPGA1_CONNECTOR <= (others => 'Z');
  FPGA2_CONNECTOR <= (others => 'Z');
  FPGA3_CONNECTOR <= (others => 'Z');
  FPGA4_CONNECTOR <= (others => 'Z');


---------------------------------------------------------------------------
-- Big AddOn Connector
---------------------------------------------------------------------------
  ADDON_RESET      <= '1';
  TRB_TO_ADDON_CLK <= '0';
  ADO_LV           <= (others => 'Z');
  ADO_TTL          <= (others => 'Z');
  FS_PE            <= (others => 'Z');


---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  LED_CLOCK_GREEN                <= not med_stat_op(15);
  LED_CLOCK_RED                  <= not reset_via_gbe;
--   LED_GREEN                      <= not med_stat_op(9);
--   LED_YELLOW                     <= not med_stat_op(10);
--   LED_ORANGE                     <= not med_stat_op(11); 
--   LED_RED                        <= '1';
  LED_TRIGGER_GREEN              <= not med_stat_op(4*16+9);
  LED_TRIGGER_RED                <= not (med_stat_op(4*16+11) or med_stat_op(4*16+10));


LED_GREEN <= debug(0);
LED_ORANGE <= debug(1);
LED_RED <= debug(2);
LED_YELLOW <= link_ok; --debug(3);


---------------------------------------------------------------------------
-- Test Connector
---------------------------------------------------------------------------    

--   TEST_LINE(7 downto 0)   <= med_data_in(7 downto 0);
--   TEST_LINE(8)            <= med_dataready_in(0);
--   TEST_LINE(9)            <= med_dataready_out(0);

  
  TEST_LINE(31 downto 0) <= (others => '0');


---------------------------------------------------------------------------
-- Test Circuits
---------------------------------------------------------------------------
  process
    begin
      wait until rising_edge(clk_100_i);
      time_counter <= time_counter + 1;
    end process;


end architecture;
