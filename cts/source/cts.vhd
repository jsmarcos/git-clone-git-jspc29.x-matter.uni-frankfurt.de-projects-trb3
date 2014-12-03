library IEEE;
   use IEEE.STD_LOGIC_1164.ALL;
   use IEEE.NUMERIC_STD.ALL;
   
library work;
   use work.trb_net_components.all;
   use work.trb_net_std.all;
   use work.CTS_PKG.ALL;

-- Debug and status registers
-- Address        Description
-- <address_table name="cts_register_block" prefix="0xa0">
--    0x00        Statistics: Number of clock cycles with trigger asserted
--    0x01        Statistics: Number of trigger rising edges
--    0x02        Statistics: Number of triggers accepted
--
--    0x03        Current trigger status
--      15 : 00   Trigger bitmask (before filtering)
--      19 : 16   Current trigger type
--           20   Trigger asserted
--
--    0x04        Buffered trigger status
--      15 : 00   Trigger bitmask (before filtering)
--      19  :16   Trigger type
--
--    0x05        TD FSM State (Trigger Distribution). One-Hot-Encoding:
--            0   TD_FSM_IDLE
--            1   TD_FSM_SEND_TRIGGER
--            2   TD_FSM_WAIT_FEE_RECV_TRIGGER
--            3   TD_FSM_FEE_ENQUEUE_INPUT_COUNTER 
--            4   TD_FSM_FEE_ENQUEUE_CHANNEL_COUNTER
--            5   TD_FSM_FEE_ENQUEUE_IDLE_COUNTER
--            6   TD_FSM_FEE_ENQUEUE_DEAD_COUNTER
--            7   TD_FSM_FEE_ENQUEUE_TRIGGER_ASSERTED_COUNTER
--            8   TD_FSM_FEE_ENQUEUE_TRIGGER_EDGES_COUNTER 
--            9   TD_FSM_FEE_ENQUEUE_TRIGGER_ACCEPTED_COUNTER 
--           10   TD_FSM_FEE_ENQUEUE_TIMESTAMP
--           11   TD_FSM_FEE_COMPLETE
--           12   TD_FSM_WAIT_TRIGGER_BECOME_IDLE
--           13   TD_FSM_DEBUG_LIMIT_REACHED
--
--
--    0x06        RO FSM State (Readout Handling). One-Hot-Encoding:
--            0   RO_FSM_IDLE
--            1   RO_FSM_SEND_REQUEST
--            2   RO_FSM_WAIT_BECOME_BUSY
--            3   RO_FSM_WAIT_BECOME_IDLE
--            4   RO_FSM_DEBUG_LIMIT_REACHED
--
--    0x07        Readout Queue
--      15 : 00   Words enqueued
--           30   Empty
--           31   Full
--
--    0x08        Debug FSM limits
--      15 : 00   Number of Triggers   (0xFFFF means no limit)
--      31 : 16   Number of Read-Outs  (0xFFFF means no limit)
--
--    0x09        Trigger information to be send in read-out (default: 0x00000000)
--            0   Input Counters
--            1   Channel Counters
--            2   Statistics: Idle- and Dead-Time counter
--            3   Statistics: Trigger asserted, -edges, -accepted
--            4   Timestamp
--
--    0x0a        Statistics: Dead time of last trigger
--                   (in clock cycles: 0xffffffff if n/a)
--
--    0x0b        Statistics: Time between last two accepted triggers 
--                   (in clock cycles: 0xffffffff if n/a)
--
--    0x0c        Event throttle
--      09 : 00   Maximal number of events accepted per millisecond
--        10      Throttle enabled
--        31      Stop Trigger
--   
--    0x0d        Event Builder selection
--      15 : 00   Event Builder mask (default: 0x1)
--      23 : 16   Number of events before selecting next builder (useful to aggregate events to support large data packets)
--      27 : 24   Event Builder number of calibration trigger
--        28      If asserted: Use special event builder for calibration trigger, otherwise, use ordinary round robin selection.
--
--    0x0e        Statistics: Total dead time of CTS (in clock cycles)
-- </address_table>

-- Header of data packet written to event builder
--       Bit   Description
-- <reg_table name="cts_data_header" >
--    15 : 0      ITC bitmask (state of all channels when trigger was accepted)
--    19 : 16     Number of Input included (two counters per input:
--                   lower word: num of clocks with input asserted. 
--                   upper word: num of rising edges.
--                   both counters overflow indepently)
--    24 : 20     Number of Channels included (same format as above)
--      25        Include last idle, dead time counters
--      26        Include Counters "Trigger asserted", "Trigger Edges", "Triggers Accepted"
--      27        Timestamp (1 word)
--    29 : 28     ETM Data amount
-- </reg_table>

entity CTS is
   generic (
      TRIGGER_INPUT_COUNT : integer range 0 to  8 := 4;
      TRIGGER_COIN_COUNT  : integer range 0 to 15 := 4;
      TRIGGER_PULSER_COUNT: integer range 0 to 15 := 4;
      TRIGGER_RAND_PULSER : integer range 0 to  1 := 1;
      
      ADDON_LINE_COUNT : integer := 22;                 -- number of lines available from add-on board
      
      TRIGGER_ADDON_COUNT : integer range 0 to 15 := 2;  -- number of module instances used to patch through those lines
      ADDON_GROUPS        : integer range 1 to 8 := 5;
      ADDON_GROUP_UPPER   : CTS_GROUP_CONFIG_T  := (3,7,11,12,13, others=>'0');
      
      PERIPH_TRIGGER_COUNT: integer range 0 to 1 := 1;
      
      OUTPUT_MULTIPLEXERS : integer range 0 to 255 := 0;
      
      EXTERNAL_TRIGGER_ID  : std_logic_vector(7 downto 0) := X"00";

      TIME_REFERENCE_COUNT : positive := 10;
      FIFO_ADDR_WIDTH : integer range 1 to 15 := 8
   );

   port (
      CLK       : in  std_logic;
      RESET     : in  std_logic;      
      
  -- Trigger Logic
      TRIGGERS_IN        : in std_logic_vector(max(0,TRIGGER_INPUT_COUNT-1) downto 0):= (others => '0');
      TRIGGER_BUSY_OUT   : out std_logic;
      TIME_REFERENCE_OUT : out std_logic;
      
      ADDON_TRIGGERS_IN  : in std_logic_vector(ADDON_LINE_COUNT-1 downto 0) := (others => '0');
      ADDON_GROUP_ACTIVITY_OUT : out std_logic_vector(ADDON_GROUPS-1 downto 0) := (others => '0');
      ADDON_GROUP_SELECTED_OUT : out std_logic_vector(ADDON_GROUPS-1 downto 0) := (others => '0');

      PERIPH_TRIGGER_IN : in std_logic_vector(19 downto 0) := (others => '0');
      
      OUTPUT_MULTIPLEXERS_OUT : out std_logic_vector(OUTPUT_MULTIPLEXERS-1 downto 0);
      
   -- External trigger logic
      EXT_TRIGGER_IN  : in std_logic;
      EXT_STATUS_IN   : in std_logic_vector(31 downto 0) := X"00000000";
      EXT_CONTROL_OUT : out std_logic_vector(31 downto 0);    
      EXT_HEADER_BITS_IN : in std_logic_vector( 1 downto 0) := "00";

  -- CTS Endpoint -----------------------------------------------------------
      --LVL1 trigger
      CTS_TRG_SEND_OUT             : out std_logic;
      CTS_TRG_TYPE_OUT             : out std_logic_vector( 3 downto 0);
      CTS_TRG_NUMBER_OUT           : out std_logic_vector(15 downto 0);
      CTS_TRG_INFORMATION_OUT      : out std_logic_vector(23 downto 0);
      CTS_TRG_RND_CODE_OUT         : out std_logic_vector( 7 downto 0);
      CTS_TRG_STATUS_BITS_IN       : in  std_logic_vector(31 downto 0);
      CTS_TRG_BUSY_IN              : in  std_logic;

      --IPU Channel
      CTS_IPU_SEND_OUT             : out std_logic;
      CTS_IPU_TYPE_OUT             : out std_logic_vector( 3 downto 0);
      CTS_IPU_NUMBER_OUT           : out std_logic_vector(15 downto 0);
      CTS_IPU_INFORMATION_OUT      : out std_logic_vector( 7 downto 0);
      CTS_IPU_RND_CODE_OUT         : out std_logic_vector( 7 downto 0);
      
      --Receiver port
      CTS_IPU_STATUS_BITS_IN       : in  std_logic_vector(31 downto 0);
      CTS_IPU_BUSY_IN              : in  std_logic;
      
      -- Slow Control
      CTS_REGIO_ADDR_IN            : in  std_logic_vector(15 downto 0);
      CTS_REGIO_DATA_IN            : in  std_logic_vector(31 downto 0);
      CTS_REGIO_READ_ENABLE_IN     : in  std_logic;
      CTS_REGIO_WRITE_ENABLE_IN    : in  std_logic;
      
      CTS_REGIO_DATA_OUT           : out std_logic_vector(31 downto 0);
      CTS_REGIO_DATAREADY_OUT      : out std_logic;
      CTS_REGIO_WRITE_ACK_OUT      : out std_logic;
      CTS_REGIO_UNKNOWN_ADDR_OUT   : out std_logic;
      
  -- Frontend Endpoint -----------------------------------------------------
      --Data Port
      LVL1_TRG_DATA_VALID_IN       : in std_logic;
      LVL1_VALID_TIMING_TRG_IN     : in std_logic;
      LVL1_VALID_NOTIMING_TRG_IN   : in std_logic;
      LVL1_INVALID_TRG_IN          : in std_logic;
      
      FEE_TRG_STATUSBITS_OUT       : out std_logic_vector(31 downto 0) := (others => '0');
      FEE_DATA_OUT                 : out std_logic_vector(31 downto 0) := (others => '0');
      FEE_DATA_WRITE_OUT           : out std_logic := '0';
      FEE_DATA_FINISHED_OUT        : out std_logic := '0'
   );
end entity;

architecture RTL of CTS is
   constant EFFECTIVE_INPUT_COUNT : integer := TRIGGER_INPUT_COUNT + TRIGGER_ADDON_COUNT;

   -- the time reference signal is generated by the time_reference_proc process
   -- and started by asserting time_reference_start_i for 1 cycle.
   signal time_reference_start_i : std_logic := '0';
   
   signal clk_1khz_i : std_logic := '0';

-- Trigger
   signal trigger_i : std_logic := '0';
   signal trigger_type_i, trigger_type_buf_i : std_logic_vector(3 downto 0);
   signal trigger_bitmask_i, trigger_bitmask_buf_i : std_logic_vector(15 downto 0);

    -- Counters
   signal input_counters_i,
          input_counters_buf_i,
          input_edge_counters_i,
          input_edge_counters_buf_i    : std_logic_vector(32 * (TRIGGER_INPUT_COUNT+TRIGGER_ADDON_COUNT) - 1 downto 0);
          
   signal channel_counters_i,
          channel_counters_buf_i,
          channel_edge_counters_i,
          channel_edge_counters_buf_i  : std_logic_vector(32 * 16 - 1 downto 0);
   
   signal num_of_itc_used_i : std_logic_vector(4 downto 0);
   
   -- Trigger <-> Bus handler 
   signal trg_regio_addr_in_i : std_logic_vector(15 downto 0);
   signal trg_regio_data_in_i, trg_regio_data_out_i : std_logic_vector(31 downto 0);
   signal trg_regio_read_enable_in_i, trg_regio_write_enable_in_i,
          trg_regio_timeout_in_i, trg_regio_dataready_out_i, 
          trg_regio_write_ack_out_i, trg_regio_no_more_data_out_i,
          trg_regio_unknown_addr_out_i : std_logic;      
   
-- FIFO
   signal fifo_data_in_i, fifo_data_out_i : std_logic_vector(31 downto 0);
   signal fifo_full_i, fifo_empty_i, fifo_enqueue_i, fifo_dequeue_i : std_logic := '0';
   signal fifo_words_in_fifo_i : std_logic_vector(FIFO_ADDR_WIDTH downto 0);

-- Throttle
   signal throttle_active_i, throttle_enabled_i : std_logic := '0';
   signal throttle_threshold_i,
          throttle_counter_i  : unsigned(9 downto 0) := (others => '0');

   signal stop_triggers_i : std_logic := '0';
   
-- Trigger Distribution
   type td_fsm_t is (
         TD_FSM_IDLE, 
         TD_FSM_SEND_TRIGGER,
         TD_FSM_WAIT_FEE_RECV_TRIGGER,
         TD_FSM_FEE_ENQUEUE_INPUT_COUNTER,
         TD_FSM_FEE_ENQUEUE_CHANNEL_COUNTER,
         TD_FSM_FEE_ENQUEUE_IDLE_COUNTER,
         TD_FSM_FEE_ENQUEUE_DEAD_COUNTER,
         TD_FSM_FEE_ENQUEUE_TRIGGER_ASSERTED_COUNTER,
         TD_FSM_FEE_ENQUEUE_TRIGGER_EDGES_COUNTER,
         TD_FSM_FEE_ENQUEUE_TRIGGER_ACCEPTED_COUNTER,
         TD_FSM_FEE_ENQUEUE_TIMESTAMP,
         TD_FSM_FEE_COMPLETE,
         TD_FSM_WAIT_TRIGGER_BECOME_IDLE,
         TD_FSM_DEBUG_LIMIT_REACHED
   ); 
   signal td_fsm_i : td_fsm_t := TD_FSM_IDLE;
   signal td_trigger_id_i : std_logic_vector(15 downto 0);
   signal td_random_number_i : std_logic_vector(7 downto 0) := (others => '0');
   signal td_next_event_i : std_logic := '0';
   
   
   type td_fsm_encode_t is array(td_fsm_t) of std_logic_vector(31 downto 0);
   constant TD_FSM_ENCODE : td_fsm_encode_t := (
         TD_FSM_IDLE                                  => X"00000001", 
         TD_FSM_SEND_TRIGGER                          => X"00000002",
         TD_FSM_WAIT_FEE_RECV_TRIGGER                 => X"00000004",
         TD_FSM_FEE_ENQUEUE_INPUT_COUNTER             => X"00000008",
         TD_FSM_FEE_ENQUEUE_CHANNEL_COUNTER           => X"00000010",
         TD_FSM_FEE_ENQUEUE_IDLE_COUNTER              => X"00000020",
         TD_FSM_FEE_ENQUEUE_DEAD_COUNTER              => X"00000040",
         TD_FSM_FEE_ENQUEUE_TRIGGER_ASSERTED_COUNTER  => X"00000080",
         TD_FSM_FEE_ENQUEUE_TRIGGER_EDGES_COUNTER     => X"00000100",
         TD_FSM_FEE_ENQUEUE_TRIGGER_ACCEPTED_COUNTER  => X"00000200",
         TD_FSM_FEE_ENQUEUE_TIMESTAMP                 => X"00000400",
         TD_FSM_FEE_COMPLETE                          => X"00000800",
         TD_FSM_WAIT_TRIGGER_BECOME_IDLE              => X"00001000",
         TD_FSM_DEBUG_LIMIT_REACHED                   => X"00002000"
   );
   
-- Read-Out
   type ro_fsm_t is (
      RO_FSM_IDLE,
      RO_FSM_SEND_REQUEST,
      RO_FSM_WAIT_BECOME_BUSY,
      RO_FSM_WAIT_BECOME_IDLE,
      RO_FSM_DEBUG_LIMIT_REACHED
      
   );
   signal ro_fsm_i : ro_fsm_t;
   signal ro_next_cycle_i : std_logic := '0';

   type ro_fsm_encode_t is array(ro_fsm_t) of std_logic_vector(31 downto 0);
   constant RO_FSM_ENCODE : ro_fsm_encode_t := (
         RO_FSM_IDLE                => X"00000001",
         RO_FSM_SEND_REQUEST        => X"00000002",
         RO_FSM_WAIT_BECOME_BUSY    => X"00000004",
         RO_FSM_WAIT_BECOME_IDLE    => X"00000008",
         RO_FSM_DEBUG_LIMIT_REACHED => X"00000010"
   );
   
   signal ro_configuration_i, ro_configuration_buf_i : std_logic_vector(4 downto 0);
   
-- Debug and statistics
   type cts_status_registers_t is array(0 to 16#0e#) of std_logic_vector(31 downto 0);
   signal cts_status_registers_i : cts_status_registers_t := (others => (others => '0'));
   
   signal debug_lvl1_limit_i, debug_ipu_limit_i, 
          transfer_debug_lvl1_limit_i, transfer_debug_ipu_limit_i : unsigned(15 downto 0) := (others => '1');
   signal transfer_debug_limits_i : std_logic := '0';
   
   
   signal stat_trigger_enabled_i,
          stat_trigger_edges_i, 
          stat_trigger_accepted_i,
          stat_dead_time_i,
          stat_idle_time_i,
          stat_total_dead_time_i : unsigned(31 downto 0);
          
   signal stat_trigger_enabled_buf_i,
          stat_trigger_edges_buf_i, 
          stat_trigger_accepted_buf_i,
          stat_dead_time_buf_i,
          stat_idle_time_buf_i : std_logic_vector(31 downto 0);
   
   signal cts_regio_addr_in_i : std_logic_vector(15 downto 0); 
   signal cts_regio_data_in_i, cts_regio_data_out_i : std_logic_vector(31 downto 0);
   signal cts_regio_read_enable_in_i, cts_regio_write_enable_in_i,
          cts_regio_timeout_in_i, cts_regio_dataready_out_i, 
          cts_regio_write_ack_out_i, cts_regio_no_more_data_out_i,
          cts_regio_unknown_addr_out_i : std_logic := '0';
          
   signal timestamp_i : unsigned(31 downto 0) := (others => '0');
   
   signal eb_mask_i,
          eb_mask_buf_i : std_logic_vector(15 downto 0) := (0 => '1', others => '0');
   signal eb_aggr_threshold_i, eb_aggr_counter_i : unsigned(7 downto 0) := x"00";
   signal eb_selection_i : std_logic_vector(3 downto 0) := x"0";
   signal eb_special_calibration_eb_i     : std_logic_vector(3 downto 0) := x"0";
   signal eb_use_special_calibration_eb_i : std_logic := '0';
   
   signal eb_regio_updated_i : std_logic := '0';
begin
   assert(EFFECTIVE_INPUT_COUNT > 0) report "The CTS requires atleast 1 input or input multiplexer";
   assert(TRIGGER_ADDON_COUNT = 0 or ADDON_LINE_COUNT > 0) report "If you use an input multiplexer you have to provide atleast 1 addon input line";


-- Trigger Distribution
-----------------------------------------
   td_proc: process(CLK) is
      variable fee_input_counter_v : integer range 0 to 2*(EFFECTIVE_INPUT_COUNT) - 1 := 0;
      variable fee_channel_counter_v : integer range 0 to 2* channel_counters_i'LENGTH / 32 - 1 := 0;
      
   begin
      if rising_edge(CLK) then
         time_reference_start_i <= '0';
       
         fifo_enqueue_i <= '0';
         --fifo_data_in_i <= (others => '-');
     
      -- CTS Endpoint Interface
         -- TODO: Check CTS_TRG_NUMBER_OUT <= (others => '-');
         -- TODO: Check CTS_TRG_INFORMATION_OUT <= (others => '-');
         -- TODO: Check CTS_TRG_RND_CODE_OUT <= (others => '-');
         CTS_TRG_SEND_OUT <= '0';

      -- DATA Endpoint Interface
         FEE_DATA_OUT <= (others => '0');
         FEE_DATA_FINISHED_OUT <= '0';
         FEE_DATA_WRITE_OUT <= '0';
      
         if td_fsm_i /= TD_FSM_FEE_ENQUEUE_INPUT_COUNTER then
            fee_input_counter_v := 0;
         end if;
         
         if td_fsm_i /= TD_FSM_FEE_ENQUEUE_CHANNEL_COUNTER then
            fee_channel_counter_v := 0;
         end if;

         td_next_event_i <= '0';
         
         if RESET = '1' then
            td_fsm_i <= TD_FSM_IDLE;
            td_trigger_id_i <= (0 => '0', others => '0');
            debug_lvl1_limit_i <= (others => '1');
            
         else      
            case(td_fsm_i) is
               when TD_FSM_IDLE =>
                  if to_integer(debug_lvl1_limit_i) = 0 then
                     td_fsm_i <= TD_FSM_DEBUG_LIMIT_REACHED;
                  
                  elsif trigger_i = '1' and fifo_full_i = '0' and (throttle_active_i = '0' or throttle_enabled_i = '0') and (stop_triggers_i = '0') then
                     time_reference_start_i <= not trigger_type_i(3); -- if 3. bit is set, no timing ref is needed
                     trigger_type_buf_i <= trigger_type_i;
                     trigger_bitmask_buf_i <= trigger_bitmask_i;
                     
                     ro_configuration_buf_i <= ro_configuration_i;
                     if trigger_type_i = X"E" then
                        -- E-Trigger enqueues all data available
                        ro_configuration_buf_i <= (others => '1');
                     end if;

                     -- oh boy, that's gonna be expensive !
                     input_counters_buf_i        <= input_counters_i;
                     channel_counters_buf_i      <= channel_counters_i;
                     input_edge_counters_buf_i   <= input_edge_counters_i;
                     channel_edge_counters_buf_i <= channel_edge_counters_i;
                     
                     stat_trigger_enabled_buf_i  <= STD_LOGIC_VECTOR(stat_trigger_enabled_i);
                     stat_trigger_edges_buf_i    <= STD_LOGIC_VECTOR(stat_trigger_edges_i);
                     stat_trigger_accepted_buf_i <= STD_LOGIC_VECTOR(stat_trigger_accepted_i);
                     
                     td_fsm_i <= TD_FSM_SEND_TRIGGER;

                     if to_integer(debug_lvl1_limit_i) /= 2**debug_lvl1_limit_i'length-1 then
                        debug_lvl1_limit_i <= debug_lvl1_limit_i - 1;
                     end if;

                     td_next_event_i <= '1';
                  end if;
               
               when TD_FSM_SEND_TRIGGER =>
                  td_trigger_id_i <= STD_LOGIC_VECTOR(UNSIGNED(td_trigger_id_i) + TO_UNSIGNED(1,1));
               
               -- cts
                  CTS_TRG_NUMBER_OUT <= td_trigger_id_i;
                  CTS_TRG_INFORMATION_OUT <= (7 => trigger_type_buf_i(3), others => '0');
                  CTS_TRG_RND_CODE_OUT <= td_random_number_i; 
                  CTS_TRG_SEND_OUT <= '1';

               -- token header
                  fifo_data_in_i <= "----" & trigger_type_buf_i & td_random_number_i & td_trigger_id_i;

                  td_fsm_i <= TD_FSM_WAIT_FEE_RECV_TRIGGER;

               when TD_FSM_WAIT_FEE_RECV_TRIGGER =>
                  if LVL1_TRG_DATA_VALID_IN = '1' then

                  -- write packet header
                     FEE_DATA_OUT(15 downto  0) <= trigger_bitmask_buf_i;
                     if ro_configuration_buf_i(0) = '1' then
                        FEE_DATA_OUT(19 downto 16) <= STD_LOGIC_VECTOR(TO_UNSIGNED(EFFECTIVE_INPUT_COUNT, 4));
                     end if;
                     
                     if ro_configuration_buf_i(1) = '1' then
                        FEE_DATA_OUT(24 downto 20) <= num_of_itc_used_i;
                     end if;
                     
                     FEE_DATA_OUT(27 downto 25) <= ro_configuration_buf_i(4 downto 2);
                     FEE_DATA_OUT(29 downto 28) <= EXT_HEADER_BITS_IN;
                     
                     FEE_DATA_WRITE_OUT <= '1';

                     td_fsm_i <= TD_FSM_FEE_ENQUEUE_INPUT_COUNTER;
                  else
                     CTS_TRG_SEND_OUT <= '1';
                     
                  end if;
               
               when TD_FSM_FEE_ENQUEUE_INPUT_COUNTER =>
                  if ro_configuration_buf_i(0) = '1' then
                     FEE_DATA_WRITE_OUT <= '1';
                     if fee_input_counter_v mod 2 = 0 then
                        FEE_DATA_OUT <= input_counters_buf_i(32*fee_input_counter_v + 31 downto 32*fee_input_counter_v); 
                     else
                        FEE_DATA_OUT <= input_edge_counters_buf_i(32*fee_input_counter_v + 31 downto 32*fee_input_counter_v); 
                     end if;
                  end if;

                  if fee_input_counter_v = 2*EFFECTIVE_INPUT_COUNT - 1 or ro_configuration_buf_i(0) = '0' then
                     td_fsm_i <= TD_FSM_FEE_ENQUEUE_CHANNEL_COUNTER;
                  end if;

                  fee_input_counter_v := fee_input_counter_v + 1;

               when TD_FSM_FEE_ENQUEUE_CHANNEL_COUNTER =>
                  if ro_configuration_buf_i(1) = '1' then
                     if fee_channel_counter_v mod 2 = 0 then
                        FEE_DATA_OUT <= channel_counters_buf_i(32*fee_channel_counter_v + 31 downto 32*fee_channel_counter_v/2); 
                     else
                        FEE_DATA_OUT <= channel_edge_counters_buf_i(32*fee_channel_counter_v + 31 downto 32*fee_channel_counter_v/2); 
                     end if; 
                     
                     FEE_DATA_WRITE_OUT <= '1';
                  end if;

                  if fee_channel_counter_v = 2*to_integer(unsigned(num_of_itc_used_i)) - 1 or  ro_configuration_buf_i(1) = '0' then
                     td_fsm_i <= TD_FSM_FEE_ENQUEUE_IDLE_COUNTER;
                  end if;

                  fee_channel_counter_v := fee_channel_counter_v + 1;

               when TD_FSM_FEE_ENQUEUE_IDLE_COUNTER =>
                  FEE_DATA_OUT <= stat_idle_time_buf_i;
                  FEE_DATA_WRITE_OUT <= ro_configuration_buf_i(2);
                  
                  if ro_configuration_buf_i(2) = '1' then
                     td_fsm_i <= TD_FSM_FEE_ENQUEUE_DEAD_COUNTER;
                  else
                     td_fsm_i <= TD_FSM_FEE_ENQUEUE_TRIGGER_ASSERTED_COUNTER;
                  end if;
               
               when TD_FSM_FEE_ENQUEUE_DEAD_COUNTER =>
                  FEE_DATA_OUT <= stat_dead_time_buf_i;
                  FEE_DATA_WRITE_OUT <= '1';
                  
                  td_fsm_i <= TD_FSM_FEE_ENQUEUE_TRIGGER_ASSERTED_COUNTER;
                  
               when TD_FSM_FEE_ENQUEUE_TRIGGER_ASSERTED_COUNTER =>
                  FEE_DATA_OUT <= stat_trigger_enabled_buf_i;
                  FEE_DATA_WRITE_OUT <= ro_configuration_buf_i(3);

                  if ro_configuration_buf_i(3) = '1' then
                     td_fsm_i <= TD_FSM_FEE_ENQUEUE_TRIGGER_EDGES_COUNTER;
                  else
                     td_fsm_i <= TD_FSM_FEE_ENQUEUE_TIMESTAMP;
                  end if;
                  
               when TD_FSM_FEE_ENQUEUE_TRIGGER_EDGES_COUNTER =>
                  FEE_DATA_OUT <= stat_trigger_edges_buf_i;
                  FEE_DATA_WRITE_OUT <= '1';
                  td_fsm_i     <= TD_FSM_FEE_ENQUEUE_TRIGGER_ACCEPTED_COUNTER;

               when TD_FSM_FEE_ENQUEUE_TRIGGER_ACCEPTED_COUNTER =>                     
                  FEE_DATA_OUT <= stat_trigger_accepted_buf_i;
                  FEE_DATA_WRITE_OUT <= '1';
                  td_fsm_i     <= TD_FSM_FEE_ENQUEUE_TIMESTAMP;
                  
               when TD_FSM_FEE_ENQUEUE_TIMESTAMP =>
                  FEE_DATA_OUT <= STD_LOGIC_VECTOR(timestamp_i);
                  FEE_DATA_WRITE_OUT <= ro_configuration_i(4);
                  td_fsm_i     <= TD_FSM_FEE_COMPLETE;
                     
               when TD_FSM_FEE_COMPLETE =>
                  FEE_DATA_FINISHED_OUT <= '1';
                  td_fsm_i <= TD_FSM_WAIT_TRIGGER_BECOME_IDLE;
                   
               when TD_FSM_WAIT_TRIGGER_BECOME_IDLE =>
                  if CTS_TRG_BUSY_IN = '0' then
                     td_fsm_i <= TD_FSM_IDLE;
                     fifo_enqueue_i <= '1';
                  end if;
                  
               when TD_FSM_DEBUG_LIMIT_REACHED =>
                  if to_integer(debug_lvl1_limit_i) /= 0 then
                     td_fsm_i <= TD_FSM_IDLE;
                  end if;                  
                  
            end case;
            
            if transfer_debug_limits_i = '1' then
               debug_lvl1_limit_i <= transfer_debug_lvl1_limit_i;
            end if;            
         end if;
      end if;
   end process;
   
   CTS_TRG_TYPE_OUT <= trigger_type_buf_i;

   read_out_proc: process(CLK) is
   begin
      if rising_edge(CLK) then
         fifo_dequeue_i <= '0';
         CTS_IPU_SEND_OUT <= '0';
         ro_next_cycle_i <= '0';

         if RESET = '1' then
            ro_fsm_i <= RO_FSM_IDLE;
            debug_ipu_limit_i <= (others => '1');
            
         else
            case(ro_fsm_i) is
               when RO_FSM_IDLE =>
                  if to_integer(debug_ipu_limit_i) = 0 then
                     ro_fsm_i <= RO_FSM_DEBUG_LIMIT_REACHED;
                  
                  elsif fifo_empty_i = '0' then
                     ro_fsm_i <= RO_FSM_SEND_REQUEST;
                     if to_integer(debug_ipu_limit_i) /= 2**debug_ipu_limit_i'length-1 then
                        debug_ipu_limit_i <= debug_ipu_limit_i - 1;
                     end if;

                  end if;
                  
               when RO_FSM_SEND_REQUEST =>
                  ro_next_cycle_i <= '1';
                  -- TODO: Check whether this can be directly assigned outside of the process
                  CTS_IPU_NUMBER_OUT <= fifo_data_out_i(15 downto 0);
                  CTS_IPU_RND_CODE_OUT <= fifo_data_out_i(23 downto 16);
                  CTS_IPU_TYPE_OUT  <= fifo_data_out_i(27 downto 24);
                  CTS_IPU_INFORMATION_OUT <= X"00";
                  
                  if fifo_data_out_i(27 downto 24) = x"e" and eb_use_special_calibration_eb_i = '1' then
                    CTS_IPU_INFORMATION_OUT(3 downto 0) <= eb_special_calibration_eb_i;
                  elsif eb_aggr_threshold_i /= x"00" then
                    CTS_IPU_INFORMATION_OUT(3 downto 0) <= eb_selection_i;
                  end if;

                  
                  CTS_IPU_SEND_OUT <= '1';
               
                  fifo_dequeue_i <= '1';
                  
                  ro_fsm_i <= RO_FSM_WAIT_BECOME_BUSY;

               when RO_FSM_WAIT_BECOME_BUSY =>
                  if CTS_IPU_BUSY_IN = '1' then 
                     ro_fsm_i <= RO_FSM_WAIT_BECOME_IDLE;
                  end if;
                  
               when RO_FSM_WAIT_BECOME_IDLE =>
                  if CTS_IPU_BUSY_IN = '0' then 
                     ro_fsm_i <= RO_FSM_IDLE;
                  end if;
                  
               when RO_FSM_DEBUG_LIMIT_REACHED =>
                  if to_integer(debug_ipu_limit_i) /= 0 then
                     ro_fsm_i <= RO_FSM_IDLE;
                  end if;
             
            end case;
            
            if transfer_debug_limits_i = '1' then
               debug_ipu_limit_i <= transfer_debug_ipu_limit_i;
            end if;
         end if;
      end if;
   end process;

-- Time Reference   
-----------------------------------------
   time_reference_proc: process(CLK) is
      variable time_reference_counter_v : integer range 0 to TIME_REFERENCE_COUNT := TIME_REFERENCE_COUNT;
   begin
      if rising_edge(CLK) then
         TIME_REFERENCE_OUT <= '0';
         if RESET = '1' then
            time_reference_counter_v := TIME_REFERENCE_COUNT - 1;
         else
            if time_reference_start_i = '1' then
               -- start
               time_reference_counter_v := 0;
               TIME_REFERENCE_OUT <= '1';
            
            elsif time_reference_counter_v /= TIME_REFERENCE_COUNT - 1 then
               -- increment
               time_reference_counter_v := time_reference_counter_v + 1;
               TIME_REFERENCE_OUT <= '1';

            end if;
         end if;
      end if;
   end process;

-- Pseudo Random Number Generation
-----------------------------------------
   random_proc: process(CLK) is
   begin
      if rising_edge(CLK) then
         -- sequence (without external entropy) repeats every 256 iterations
         td_random_number_i <= STD_LOGIC_VECTOR(UNSIGNED(td_random_number_i) + TO_UNSIGNED(113, 8) + UNSIGNED(CTS_REGIO_ADDR_IN(7 downto 0))) 
            xor ("0" & LVL1_TRG_DATA_VALID_IN & "0" &LVL1_VALID_TIMING_TRG_IN & "0000");
      end if;
   end process;
   
-- FIFO   
-----------------------------------------
   my_fifo: CTS_FIFO
   generic map (
      WIDTH => fifo_data_in_i'LENGTH,
      ADDR_WIDTH => FIFO_ADDR_WIDTH
   )
   port map (
      CLK => CLK, RESET => RESET,
      DATA_IN => fifo_data_in_i,
      DATA_OUT => fifo_data_out_i,
      WORDS_IN_FIFO_OUT => fifo_words_in_fifo_i,
      ENQUEUE_IN => fifo_enqueue_i,
      DEQUEUE_IN => fifo_dequeue_i,
      FULL_OUT => fifo_full_i,
      EMPTY_OUT => fifo_empty_i
   ); 

-- Event Builder Selection
-----------------------------------------
   eb_proc: process(CLK) is
      variable next_eb_selection : unsigned(3 downto 0);
      variable get_next_eb : std_logic;
   begin
      if rising_edge(CLK) then
         if RESET='1' then
            eb_aggr_counter_i   <= x"00";
            eb_selection_i <= x"0";
            next_eb_selection := x"0";
            get_next_eb := '0';
         end if;
         
         if (eb_aggr_threshold_i = x"00" or eb_mask_i = x"0000") then
            -- no round-robin active
            eb_selection_i <= x"0";
            get_next_eb := '0';
            
         elsif ro_next_cycle_i = '1' then
            -- round-robin active active, and a new event just started
            if eb_aggr_threshold_i = eb_aggr_counter_i then
               eb_aggr_counter_i <= (others => '0');
               eb_selection_i <= next_eb_selection;
               get_next_eb := '1';
               
            else
               eb_aggr_counter_i <= eb_aggr_counter_i + TO_UNSIGNED(1,1);
               
            end if;

         end if;
         
         -- increment (with overflow) next_eb_selection until we find an active eb
         -- with this sequential approach, the result is ready in at most 16 cycles,
         -- i.e. the result is ready long before we need it for the (worst case) next event ...
         if get_next_eb='1' then
            next_eb_selection := next_eb_selection + TO_UNSIGNED(1,1);
            if eb_mask_i(to_integer(next_eb_selection)) = '1' then
               get_next_eb := '0';
            end if;
         end if;
      end if;
   end process;
   
-- Trigger
-----------------------------------------
   my_trigger : CTS_TRIGGER
   generic map (
      TRIGGER_INPUT_COUNT  => TRIGGER_INPUT_COUNT,
      TRIGGER_COIN_COUNT   => TRIGGER_COIN_COUNT,
      TRIGGER_PULSER_COUNT => TRIGGER_PULSER_COUNT,
      TRIGGER_RAND_PULSER  => TRIGGER_RAND_PULSER,
     
      ADDON_LINE_COUNT     => ADDON_LINE_COUNT,
      ADDON_GROUPS         => ADDON_GROUPS,
      ADDON_GROUP_UPPER    => ADDON_GROUP_UPPER,
      
      PERIPH_TRIGGER_COUNT => PERIPH_TRIGGER_COUNT,
      
      OUTPUT_MULTIPLEXERS  => OUTPUT_MULTIPLEXERS,
      
      TRIGGER_ADDON_COUNT  => TRIGGER_ADDON_COUNT,
      EXTERNAL_TRIGGER_ID  => EXTERNAL_TRIGGER_ID
   )
   port map (
      CLK_IN      => CLK,
      CLK_1KHZ_IN => clk_1khz_i,
      RESET_IN    => RESET,
         
      TRIGGERS_IN => TRIGGERS_IN,
      ADDON_TRIGGERS_IN => ADDON_TRIGGERS_IN,
      ADDON_GROUP_ACTIVITY_OUT => ADDON_GROUP_ACTIVITY_OUT,
      ADDON_GROUP_SELECTED_OUT => ADDON_GROUP_SELECTED_OUT,
      
      PERIPH_TRIGGER_IN => PERIPH_TRIGGER_IN,
      
      OUTPUT_MULTIPLEXERS_OUT => OUTPUT_MULTIPLEXERS_OUT,
      
      EXT_TRIGGER_IN  => EXT_TRIGGER_IN,
      EXT_STATUS_IN   => EXT_STATUS_IN,
      EXT_CONTROL_OUT => EXT_CONTROL_OUT,

      TRIGGER_OUT         => trigger_i,
      TRIGGER_TYPE_OUT    => trigger_type_i,
      TRIGGER_BITMASK_OUT => trigger_bitmask_i,
   
      INPUT_COUNTERS_OUT        => input_counters_i,
      INPUT_EDGE_COUNTERS_OUT   => input_edge_counters_i,
      CHANNEL_COUNTERS_OUT      => channel_counters_i,
      CHANNEL_EDGE_COUNTERS_OUT => channel_edge_counters_i,
      NUM_OF_ITC_USED_OUT       => num_of_itc_used_i,
      
    -- Slow Control
      REGIO_ADDR_IN            => trg_regio_addr_in_i,
      REGIO_DATA_IN            => trg_regio_data_in_i,
      REGIO_READ_ENABLE_IN     => trg_regio_read_enable_in_i,
      REGIO_WRITE_ENABLE_IN    => trg_regio_write_enable_in_i,
      REGIO_TIMEOUT_IN         => trg_regio_timeout_in_i,
      
      REGIO_DATA_OUT           => trg_regio_data_out_i,
      REGIO_DATAREADY_OUT      => trg_regio_dataready_out_i,
      REGIO_WRITE_ACK_OUT      => trg_regio_write_ack_out_i,
      REGIO_NO_MORE_DATA_OUT   => trg_regio_no_more_data_out_i,
      REGIO_UNKNOWN_ADDR_OUT   => trg_regio_unknown_addr_out_i      
   );
   
-- Statistics
-----------------------------------------
   stat_proc: process(CLK) is
      variable last_trigger_v : std_logic := '0';
      variable last_td_fsm_v  : td_fsm_t := TD_FSM_IDLE;
   begin
      if rising_edge(CLK) then
         if RESET='1' or stat_trigger_enabled_i = X"FFFFFFFF" then
            -- the first counter to overflow is trigger_enabled
            -- if this happends the remaining counters become worthless for obtaining
            -- scaling values. hence, all counters are reset
            
            stat_trigger_accepted_i <= (others => '0');
            stat_trigger_edges_i <= (others => '0');
            stat_trigger_enabled_i <= (others => '0');

         else
            if trigger_i = '1' then
               stat_trigger_enabled_i <= stat_trigger_enabled_i + 1;
            end if;
            
            if trigger_i = '1' and last_trigger_v = '0' then
               stat_trigger_edges_i <= stat_trigger_edges_i + 1;
            end if;
            
            if td_next_event_i = '1' then
               
               stat_trigger_accepted_i <= stat_trigger_accepted_i + 1;
            end if;
         end if;

      -- DEAD AND IDLE TIME
         if RESET='1' then
            stat_dead_time_i <= (others => '0');
            stat_total_dead_time_i <= (others => '0');
            stat_idle_time_i <= (others => '0');
            
            stat_dead_time_buf_i <= (others => '1');
            stat_idle_time_buf_i <= (others => '1');

         else
            if td_fsm_i = TD_FSM_IDLE then
               if last_td_fsm_v /= TD_FSM_IDLE then
                  stat_dead_time_buf_i <= STD_LOGIC_VECTOR(stat_dead_time_i);
                  stat_dead_time_i <= (others => '0');
               end if;
               
               if stat_idle_time_i /= X"ffffffff" then
                  stat_idle_time_i <= stat_idle_time_i + 1;
               end if;

            else
               if last_td_fsm_v = TD_FSM_IDLE then
                  stat_idle_time_buf_i <= STD_LOGIC_VECTOR(stat_idle_time_i);
                  stat_idle_time_i <= (others => '0');
               end if;
               
               if stat_dead_time_i /= X"ffffffff" then
                  stat_dead_time_i <= stat_dead_time_i + 1;
               end if;
               
               stat_total_dead_time_i <= stat_total_dead_time_i + 1;
            end if;
         end if;
       
         last_trigger_v := trigger_i;
         last_td_fsm_v  := td_fsm_i;
      end if;
   end process;   

-- Debug and Runtime information
-----------------------------------------
   cts_status_registers_i(16#00#) <= STD_LOGIC_VECTOR(stat_trigger_enabled_i);
   cts_status_registers_i(16#01#) <= STD_LOGIC_VECTOR(stat_trigger_edges_i);
   cts_status_registers_i(16#02#) <= STD_LOGIC_VECTOR(stat_trigger_accepted_i);
   
   cts_status_registers_i(16#03#)(20 downto 0) <= trigger_i & trigger_type_i & trigger_bitmask_i;
   cts_status_registers_i(16#04#)(19 downto 0) <= trigger_type_buf_i & trigger_bitmask_buf_i;
      
   cts_status_registers_i(16#05#) <= TD_FSM_ENCODE(td_fsm_i);
   cts_status_registers_i(16#06#) <= RO_FSM_ENCODE(ro_fsm_i);
   cts_status_registers_i(16#07#)(31 downto 30) <= fifo_full_i & fifo_empty_i;
   cts_status_registers_i(16#07#)(fifo_words_in_fifo_i'RANGE) <= fifo_words_in_fifo_i;

   -- control registers are mapped to status registers for read access
   cts_status_registers_i(16#08#) <= STD_LOGIC_VECTOR(debug_ipu_limit_i) & STD_LOGIC_VECTOR(debug_lvl1_limit_i);
   cts_status_registers_i(16#09#)(ro_configuration_i'RANGE) <= ro_configuration_i;
   
   cts_status_registers_i(16#0a#) <= stat_dead_time_buf_i;
   cts_status_registers_i(16#0b#) <= stat_idle_time_buf_i;
   cts_status_registers_i(16#0c#)(throttle_threshold_i'RANGE) <= STD_LOGIC_VECTOR(throttle_threshold_i);
   cts_status_registers_i(16#0c#)(throttle_threshold_i'LENGTH) <= throttle_enabled_i;
   cts_status_registers_i(16#0c#)(31) <= stop_triggers_i;
   
   cts_status_registers_i(16#0d#)(15 downto 0) <= eb_mask_i;
   cts_status_registers_i(16#0d#)(23 downto 16) <= STD_LOGIC_VECTOR(eb_aggr_threshold_i);
   cts_status_registers_i(16#0d#)(27 downto 24) <= eb_special_calibration_eb_i;
   cts_status_registers_i(16#0d#)(28) <= eb_use_special_calibration_eb_i;
   
   cts_status_registers_i(16#0e#) <= stat_total_dead_time_i;
   
   regio_proc: process(CLK) is
      variable addr : integer range 0 to 15;
   begin
      if rising_edge(CLK) then
         if RESET ='1' then
            ro_configuration_i <= (0 => '1', others => '0');
            throttle_threshold_i <= (others => '0');
            throttle_enabled_i <= '0';
            stop_triggers_i <= '0';

            eb_aggr_threshold_i <= x"00";
            eb_mask_i     <= (0 => '1', others => '0');
            eb_special_calibration_eb_i <= x"0";
            eb_use_special_calibration_eb_i <= '0';
            
         else
         
            addr := TO_INTEGER(UNSIGNED(cts_regio_addr_in_i(3 downto 0)));

            cts_regio_data_out_i <= (others => '0');
            cts_regio_write_ack_out_i <= '0';
            cts_regio_unknown_addr_out_i <= cts_regio_write_enable_in_i or cts_regio_read_enable_in_i;
            transfer_debug_limits_i <= '0';
            
            for i in 0 to cts_status_registers_i'HIGH loop
               if i = addr then
                  cts_regio_dataready_out_i <= cts_regio_read_enable_in_i;
                  cts_regio_data_out_i <= cts_status_registers_i(i);
                  cts_regio_unknown_addr_out_i <= cts_regio_write_enable_in_i;
               end if;
            end loop;
         
         -- write access to control registers
            if addr = 16#08# and cts_regio_write_enable_in_i = '1' then
               transfer_debug_lvl1_limit_i <= UNSIGNED(cts_regio_data_in_i(15 downto 0));
               transfer_debug_ipu_limit_i  <= UNSIGNED(cts_regio_data_in_i(31 downto 16));
               transfer_debug_limits_i     <= '1';
               
               cts_regio_write_ack_out_i   <= '1';
               cts_regio_unknown_addr_out_i <= '0';
            end if;
            
            if addr = 16#09# and cts_regio_write_enable_in_i = '1' then
               ro_configuration_i <= cts_regio_data_in_i(ro_configuration_i'RANGE);
               cts_regio_write_ack_out_i   <= '1';
               cts_regio_unknown_addr_out_i <= '0';
            end if;
         
            if addr = 16#0c# and cts_regio_write_enable_in_i = '1' then
               throttle_threshold_i <= UNSIGNED(cts_regio_data_in_i(throttle_threshold_i'RANGE));
               throttle_enabled_i   <= cts_regio_data_in_i(throttle_threshold_i'LENGTH);
               stop_triggers_i      <= cts_regio_data_in_i(31);
               cts_regio_write_ack_out_i   <= '1';
               cts_regio_unknown_addr_out_i <= '0';
            end if;

            eb_regio_updated_i <= '0';
            if addr = 16#0d# and cts_regio_write_enable_in_i = '1' then
               eb_mask_i <= cts_regio_data_in_i(15 downto 0);
               eb_aggr_threshold_i <= UNSIGNED(cts_regio_data_in_i(23 downto 16));
               eb_special_calibration_eb_i <= cts_regio_data_in_i(27 downto 24);
               eb_use_special_calibration_eb_i <= cts_regio_data_in_i(28);
               
               eb_regio_updated_i <= '1';
               
               cts_regio_write_ack_out_i <= '1';
               cts_regio_unknown_addr_out_i <= '0';
            end if;
         end if;
      end if;
   end process;

-- Throttle
-----------------------------------------
   process(CLK) is
   begin
      if rising_edge(CLK) then
      -- counter
         if clk_1khz_i = '1' then
         
            throttle_counter_i <= (others => '0');
         elsif td_next_event_i = '1' then
            -- increment each time a new trigger is accepted
            throttle_counter_i <= throttle_counter_i + "1";
         
         end if;

      -- throttle decision
         throttle_active_i <= '0';
         if throttle_counter_i > throttle_threshold_i then
            -- not realy nice, as the inhibit singal asserts one cycle delayed, however
            -- this is no problem as the td-fsm requires more than one cycle to complete.
            -- hence we can drop an addiotional adder
            throttle_active_i <= '1';
         end if;
      end if;
   end process;
   
-- 1 KHz clock divider
-----------------------------------------
   process(CLK) is
      variable counter_v : integer range 0 to 99999 := 0;
   begin
      if rising_edge(CLK) then
         if counter_v = 99999 then
            counter_v := 0;
            clk_1khz_i <= '1';
         else
            counter_v := counter_v + 1;
            clk_1khz_i <= '0';
         end if;
      end if;
   end process;
   
-- Timestamp
   process is
   begin
      wait until rising_edge(CLK);
      timestamp_i <= timestamp_i + "1";
   end process;
   
-- Bus Handler
-----------------------------------------
  my_bus_handler : trb_net16_regio_bus_handler
  generic map (
     PORT_NUMBER => 2,
     --                 trigger        debug
     PORT_ADDRESSES => (0 => X"A100", 1 => X"A000", others => X"0000"),
     PORT_ADDR_MASK => (0 => 8,       1 => 8,       others => 0)
  )
  port map (
     CLK => CLK,
     RESET => RESET,      
     
     DAT_ADDR_IN           => CTS_REGIO_ADDR_IN,
     DAT_DATA_IN           => CTS_REGIO_DATA_IN,
     DAT_DATA_OUT          => CTS_REGIO_DATA_OUT,
     DAT_READ_ENABLE_IN    => CTS_REGIO_READ_ENABLE_IN,
     DAT_WRITE_ENABLE_IN   => CTS_REGIO_WRITE_ENABLE_IN,
     DAT_TIMEOUT_IN        => '0',
     DAT_DATAREADY_OUT     => CTS_REGIO_DATAREADY_OUT,
     DAT_WRITE_ACK_OUT     => CTS_REGIO_WRITE_ACK_OUT,
     DAT_NO_MORE_DATA_OUT  => open,
     DAT_UNKNOWN_ADDR_OUT  => CTS_REGIO_UNKNOWN_ADDR_OUT,
  
     BUS_ADDR_OUT(0*16+15 downto 0*16) => trg_regio_addr_in_i,
     BUS_ADDR_OUT(1*16+15 downto 1*16) => cts_regio_addr_in_i,
     
     BUS_DATA_OUT(0*32+31 downto 0*32) => trg_regio_data_in_i,
     BUS_DATA_OUT(1*32+31 downto 1*32) => cts_regio_data_in_i,
     
     BUS_DATA_IN(0*32+31 downto 0*32)  => trg_regio_data_out_i,
     BUS_DATA_IN(1*32+31 downto 1*32)  => cts_regio_data_out_i,

     BUS_READ_ENABLE_OUT(0)  => trg_regio_read_enable_in_i,
     BUS_READ_ENABLE_OUT(1)  => cts_regio_read_enable_in_i,
     
     BUS_WRITE_ENABLE_OUT(0) => trg_regio_write_enable_in_i,
     BUS_WRITE_ENABLE_OUT(1) => cts_regio_write_enable_in_i,
     
     BUS_TIMEOUT_OUT(0)      => trg_regio_timeout_in_i,
     BUS_TIMEOUT_OUT(1)      => cts_regio_timeout_in_i,

     BUS_DATAREADY_IN(0)     => trg_regio_dataready_out_i,
     BUS_DATAREADY_IN(1)     => cts_regio_dataready_out_i,
     
     BUS_WRITE_ACK_IN(0)     => trg_regio_write_ack_out_i,
     BUS_WRITE_ACK_IN(1)     => cts_regio_write_ack_out_i,
     
     BUS_NO_MORE_DATA_IN(0)  => trg_regio_no_more_data_out_i,
     BUS_NO_MORE_DATA_IN(1)  => cts_regio_no_more_data_out_i,
     
     BUS_UNKNOWN_ADDR_IN(0)  => trg_regio_unknown_addr_out_i,
     BUS_UNKNOWN_ADDR_IN(1)  => cts_regio_unknown_addr_out_i,

     STAT_DEBUG            => open
 );
 
 cts_regio_no_more_data_out_i <= '0';
end architecture;
