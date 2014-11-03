library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   
library work;
   use work.cbmnet_interface_pkg.all;
   use work.trb_net_std.all;
   

entity cbmnet_sync_module is
   port(
   -- TRB
      TRB_CLK_IN     : in std_logic;  
      TRB_RESET_IN   : in std_logic;
      TRB_TRIGGER_OUT: out std_logic;

      --data output for read-out
      TRB_TRIGGER_IN       : in  std_logic;
      TRB_RDO_VALID_DATA_TRG_IN  : in  std_logic;
      TRB_RDO_VALID_NO_TIMING_IN : in  std_logic;
      TRB_RDO_DATA_OUT     : out std_logic_vector(31 downto 0);
      TRB_RDO_WRITE_OUT    : out std_logic;
      TRB_RDO_STATUSBIT_OUT: out std_logic_vector(31 downto 0);
      TRB_RDO_FINISHED_OUT : out std_logic;

      -- reg io
      TRB_REGIO_IN  : in  CTRLBUS_RX;
      TRB_REGIO_OUT : out CTRLBUS_TX;
      
   -- CBMNET
      CBM_CLK_IN           : in std_logic;
      CBM_CLK_250_IN       : in std_logic;
      CBM_LINK_ACTIVE_IN   : in std_logic;
      
      CBM_RESET_IN         : in std_logic;
      CBM_PHY_BARREL_SHIFTER_POS_IN : in std_logic_vector(3 downto 0);
      CBM_TIMING_TRIGGER_OUT : out std_logic;
      
      -- DLM port
      CBM_DLM_REC_IN       : in std_logic_vector(3 downto 0);
      CBM_DLM_REC_VALID_IN : in std_logic;
      CBM_DLM_SENSE_OUT    : out std_logic;
      CBM_PULSER_OUT       : out std_logic; -- connect to TDC
      
      -- Ctrl port
      CBM_CTRL_DATA_IN        : in std_logic_vector(15 downto 0);
      CBM_CTRL_DATA_START_IN  : in std_logic;
      CBM_CTRL_DATA_END_IN    : in std_logic;
      CBM_CTRL_DATA_STOP_OUT  : out std_logic;
      
      DEBUG_OUT      : out std_logic_vector(31 downto 0)    
   );
end entity;

architecture cbmnet_sync_module_arch of cbmnet_sync_module is
-- DETECT DLMs
   signal trb_dlm_sense_mask_i : std_logic_vector(15 downto 0);
   signal cbm_from_trb_dlm_sense_mask_i : std_logic_vector(15 downto 0);
   
   signal cbm_dlm_sensed_i : std_logic;
   signal trb_from_cbm_dlm_sensed_i : std_logic;

-- EPOCH
   signal cbm_from_trb_epoch_update_scheme_i : std_logic_vector(1 downto 0);

   signal cbm_current_epoch_i : std_logic_vector(31 downto 0);
   signal cbm_current_epoch_updated_i : std_logic;

   signal trb_next_epoch_i : std_logic_vector(31 downto 0);
   signal trb_next_epoch_updated_i : std_logic;
   
   signal cbm_next_epoch_i : std_logic_vector(31 downto 0);
   signal cbm_next_epoch_updated_i : std_logic;
   
   signal cbm_from_trb_next_epoch_i : std_logic_vector(31 downto 0);
   signal cbm_from_trb_next_epoch_updated_i : std_logic;
   signal trb_from_cbm_current_epoch_i : std_logic_vector(31 downto 0);
   signal trb_from_cbm_current_epoch_updated_i : std_logic;   
   
-- PULSER
   signal trb_pulser_threshold_i : std_logic_vector(31 downto 0);
   signal cbm_from_trb_pulser_threshold_i : unsigned(31 downto 0);
   signal cbm_pulser_period_counter_i : unsigned(31 downto 0);
   signal cbm_pulse_i : std_logic;
   signal trb_from_cbm_pulse_i : std_logic;

-- TIMESTAMPS
   signal trb_timestamp_i          : unsigned(31 downto 0);
   signal trb_timestamp_last_dlm_i : unsigned(31 downto 0);
   signal trb_timestamp_last_pulse_i : unsigned(31 downto 0);
   signal trb_reset_counter_i      : unsigned(15 downto 0);
   
   signal cbm_timestamp_i          : unsigned(31 downto 0);
   signal cbm_timestamp_last_dlm_i : unsigned(31 downto 0);
   signal cbm_timestamp_last_pulse_i : unsigned(31 downto 0);
   signal cbm_reset_counter_i      : unsigned(15 downto 0);
   signal cbm_dlm_counter_i        : unsigned(31 downto 0);
   signal cbm_pulse_counter_i     : unsigned(31 downto 0);

   -- same signals as above, but in trbnet clock domain
   signal trb_from_cbm_timestamp_i          : unsigned(31 downto 0);
   signal trb_from_cbm_timestamp_last_dlm_i : unsigned(31 downto 0);
   signal trb_from_cbm_timestamp_last_pulse_i : unsigned(31 downto 0);
   signal trb_from_cbm_reset_counter_i      : unsigned(15 downto 0);   
   signal trb_from_cbm_dlm_counter_i        : unsigned(31 downto 0);
   signal trb_from_cbm_pulse_counter_i     : unsigned(31 downto 0);

   
-- CBMNET slow control
   signal cbm_next_epoch_half_buf_i : std_logic_vector(15 downto 0);
   type CBM_SLOW_CTRL_FSM_T is (WAIT_FOR_START, SHIFT_LOW_WORD);
   signal cbm_slow_ctrl_fsm_i : CBM_SLOW_CTRL_FSM_T;

-- TrbNet slow control
   constant trb_sync_lowest_address_c : integer := 3;

   type TRB_SYNC_BUFFER_T is array (trb_sync_lowest_address_c+1 to trb_sync_lowest_address_c+9) of std_logic_vector(31 downto 0);
   signal trb_sync_buffer_i : TRB_SYNC_BUFFER_T;
   signal trb_regio_addr_i : integer range 0 to 15;
   signal trb_epoch_update_scheme_i : std_logic_vector(1 downto 0);
   
-- TrbNet read-out   
   constant TRB_RDO_HDR_EXT_MARKER_C : integer := 27;
   constant TRB_RDO_HDR_LINK_ACTIVE_C : integer := 26;
   
   type TRB_RDO_BUFFER_T is array (0 to 10) of std_logic_vector(31 downto 0);
   signal trb_rdo_buffer_i : TRB_RDO_BUFFER_T;
   type TRB_RDO_FSM_T is (WAIT_FOR_TRIGGER, WAIT_FOR_VALID, COPY_DATA, FINISH);
   signal trb_rdo_fsm_i : TRB_RDO_FSM_T;
   signal trb_rdo_fsm_state_i : std_logic_vector(3 downto 0);
   
   signal trb_rdo_counter_i : integer range 0 to trb_rdo_buffer_i'high;
   signal trb_rdo_finished_i : std_logic;
   
   type CBM_TRB_RDO_FSM_T is (IDLE, WAIT_FOR_RELEASE, WAIT_BEFORE_IDLE);
   signal cbm_trb_rdo_fsm_i : CBM_TRB_RDO_FSM_T;
   
   signal cbm_rdo_registered_i : std_logic;
   signal trb_from_cbm_rdo_registered_i : std_logic;
   
   signal cbm_from_trb_trigger_in  : std_logic;
   signal cbm_from_trb_trigger_buf_in  : std_logic;
   signal cbm_from_trb_rdo_valid_no_timing_in  : std_logic;
   signal cbm_from_trb_rdo_finished_i : std_logic;
   signal cbm_from_trb_reset_in : std_logic;
   
begin
-- TRBNet read-out
   TRBNET_READOUT_PROC: process is
      variable header_v : std_logic_vector(31 downto 0);
      
      variable valid_trg_v : std_logic;
      
   begin
      wait until rising_edge(TRB_CLK_IN);
      header_v := (others => '0'); -- prevent storage
      
      TRB_RDO_WRITE_OUT <= '0';
      TRB_RDO_STATUSBIT_OUT <= (others => '0');
      trb_rdo_finished_i <= '0';
      trb_rdo_counter_i <= 0;
      
      if TRB_RESET_IN='1' then
         trb_rdo_fsm_i <= WAIT_FOR_TRIGGER;
      else
         case (trb_rdo_fsm_i) is
            when WAIT_FOR_TRIGGER =>
               trb_rdo_fsm_state_i <= x"0";
               valid_trg_v := '0';

               if TRB_TRIGGER_IN = '1' or TRB_RDO_VALID_NO_TIMING_IN = '1' then
               -- store data
                  header_v(31 downto 28) := "0001"; -- version
                  header_v(23 downto  8) := std_logic_vector(trb_pulser_threshold_i(15 downto 0));
                  header_v( 7 downto  4) := CBM_PHY_BARREL_SHIFTER_POS_IN;
                  header_v( 3 downto  0) := trb_from_cbm_current_epoch_updated_i & "0" & trb_epoch_update_scheme_i;
                  
                  header_v(TRB_RDO_HDR_LINK_ACTIVE_C) := CBM_LINK_ACTIVE_IN;
                  header_v(TRB_RDO_HDR_EXT_MARKER_C)  := CBM_LINK_ACTIVE_IN and not TRB_TRIGGER_IN;
                  
                  -- signals commented out are registered in the cbm clock domain in the next process
                  trb_rdo_buffer_i( 0) <= header_v;
                  trb_rdo_buffer_i( 1) <= std_logic_vector(trb_timestamp_i);
               -- trb_rdo_buffer_i( 2) <= std_logic_vector(cbm_timestamp_i);
                  trb_rdo_buffer_i( 3) <= std_logic_vector(trb_timestamp_last_pulse_i);
               -- trb_rdo_buffer_i( 4) <= std_logic_vector(cbm_timestamp_last_pulse_i);
               -- trb_rdo_buffer_i( 5) <= std_logic_vector(cbm_current_epoch_i);
               -- trb_rdo_buffer_i( 6) <= std_logic_vector(cbm_timestamp_last_dlm_i);
                  trb_rdo_buffer_i( 7) <= std_logic_vector(trb_timestamp_last_dlm_i);
               -- trb_rdo_buffer_i( 8) <= std_logic_vector(cbm_dlm_counter_i);
               -- trb_rdo_buffer_i( 9) <= std_logic_vector(cbm_pulse_counter_i);
                  trb_rdo_buffer_i(10)(31 downto 16) <= std_logic_vector(trb_reset_counter_i);
               -- trb_rdo_buffer_i(10)(15 downto  0) <= cbm_reset_counter_i);
               
                  trb_rdo_fsm_i <= WAIT_FOR_VALID;
               end if;
               
            when WAIT_FOR_VALID =>
               valid_trg_v := valid_trg_v or TRB_RDO_VALID_DATA_TRG_IN;

               trb_rdo_fsm_state_i <= x"1";
               if (trb_rdo_buffer_i(0)(TRB_RDO_HDR_LINK_ACTIVE_C)='0' or trb_from_cbm_rdo_registered_i = '1') and 
                  valid_trg_v = '1' then
                  trb_rdo_fsm_i <= COPY_DATA;
               end if;
               
               if CBM_LINK_ACTIVE_IN = '0' then
                  trb_rdo_buffer_i(0)(TRB_RDO_HDR_EXT_MARKER_C) <= '0';
                  trb_rdo_buffer_i(0)(TRB_RDO_HDR_LINK_ACTIVE_C) <= '0';
               end if;
               
            when COPY_DATA =>
               trb_rdo_fsm_state_i <= x"2";
               TRB_RDO_DATA_OUT <= trb_rdo_buffer_i(trb_rdo_counter_i);
               TRB_RDO_WRITE_OUT <= '1';

               if (trb_rdo_buffer_i(0)(TRB_RDO_HDR_LINK_ACTIVE_C) = '0') or
                  (trb_rdo_buffer_i(0)(TRB_RDO_HDR_EXT_MARKER_C) = '1' and trb_rdo_counter_i = 10) or
                  (trb_rdo_buffer_i(0)(TRB_RDO_HDR_EXT_MARKER_C) = '0' and trb_rdo_counter_i = 4)
               then
                  trb_rdo_fsm_i <= FINISH;
               end if;
               
               trb_rdo_counter_i <= trb_rdo_counter_i + 1;
               
            when FINISH =>
               trb_rdo_fsm_state_i <= x"3";
               trb_rdo_finished_i <= '1';
               trb_rdo_fsm_i <= WAIT_FOR_TRIGGER;
            
         end case;
      end if;
   end process;
   TRB_RDO_FINISHED_OUT <= trb_rdo_finished_i;
   
   CBM_TRBNET_READOUT_PROC: process is
      variable block_v : std_logic := '0';
   begin
      wait until rising_edge(CBM_CLK_IN);
      
      CBM_TIMING_TRIGGER_OUT <= '0';
      
      if CBM_RESET_IN='1' or cbm_from_trb_reset_in ='1' then
         cbm_trb_rdo_fsm_i <= IDLE;
      end if;
      
      cbm_rdo_registered_i <= '0';
      
      case (cbm_trb_rdo_fsm_i) is
         when IDLE =>
            if cbm_from_trb_trigger_in = '1' then
               CBM_TIMING_TRIGGER_OUT <= '1';
            end if;
         
            if cbm_from_trb_trigger_in = '1' or cbm_from_trb_rdo_valid_no_timing_in = '1' then
               trb_rdo_buffer_i( 2) <= std_logic_vector(cbm_timestamp_i);
               trb_rdo_buffer_i( 4) <= std_logic_vector(cbm_timestamp_last_pulse_i);
               trb_rdo_buffer_i( 5) <= std_logic_vector(cbm_current_epoch_i);
               trb_rdo_buffer_i( 6) <= std_logic_vector(cbm_timestamp_last_dlm_i);
               trb_rdo_buffer_i( 8) <= std_logic_vector(cbm_dlm_counter_i);
               trb_rdo_buffer_i( 9) <= std_logic_vector(cbm_pulse_counter_i);
               trb_rdo_buffer_i(10)(15 downto  0) <= std_logic_vector(cbm_reset_counter_i);
               
               cbm_trb_rdo_fsm_i <= WAIT_FOR_RELEASE;
            end if;
            
         when WAIT_FOR_RELEASE => 
            cbm_rdo_registered_i <= '1';
            if cbm_from_trb_rdo_finished_i = '1' then
               cbm_trb_rdo_fsm_i <= WAIT_BEFORE_IDLE;
            end if;
            
         when WAIT_BEFORE_IDLE =>
            cbm_trb_rdo_fsm_i <= IDLE;
      end case;
   end process;

-- TRBNet slow control
   trb_regio_addr_i <= to_integer(UNSIGNED(TRB_REGIO_IN.addr(3 downto 0)));
   
   TRB_SLOW_CTRL_PROC: process is
   begin
      wait until rising_edge(TRB_CLK_IN);

      TRB_REGIO_OUT.rack <= TRB_REGIO_IN.read;
      TRB_REGIO_OUT.wack <= TRB_REGIO_IN.write;
      TRB_REGIO_OUT.unknown <= '0';
      TRB_REGIO_OUT.data <= (others => '0');
      TRB_REGIO_OUT.nack <= '0';
      TRB_REGIO_OUT.ack <= '0';
      
      if trb_from_cbm_dlm_sensed_i = '1' then
         trb_next_epoch_updated_i <= '0';
      end if;
      
      if TRB_RESET_IN = '1' then
         trb_dlm_sense_mask_i <= x"0000";
         trb_epoch_update_scheme_i <= "00";
         trb_pulser_threshold_i <= (others => '0');
         
         trb_next_epoch_updated_i <= '0';
         trb_next_epoch_i <= x"deadc0de";
         
      else
         case (trb_regio_addr_i) is
            when 0 => 
               TRB_REGIO_OUT.data(31 downto 16) <= trb_dlm_sense_mask_i;
               TRB_REGIO_OUT.data(11 downto  8) <= trb_rdo_fsm_state_i;
               TRB_REGIO_OUT.data(5) <= CBM_LINK_ACTIVE_IN;
               TRB_REGIO_OUT.data(4) <= trb_from_cbm_current_epoch_updated_i;
               TRB_REGIO_OUT.data( 3 downto  0) <= "00" & trb_epoch_update_scheme_i;
            
            when 1 =>
               TRB_REGIO_OUT.data <= std_logic_vector(trb_pulser_threshold_i);
               
            when 2 =>
               TRB_REGIO_OUT.data <= trb_next_epoch_i;
            
            when trb_sync_lowest_address_c =>
               TRB_REGIO_OUT.data <= trb_from_cbm_current_epoch_i;
               trb_sync_buffer_i(trb_sync_lowest_address_c+1) <= std_logic_vector(trb_from_cbm_timestamp_i);
               trb_sync_buffer_i(trb_sync_lowest_address_c+2) <= std_logic_vector(trb_from_cbm_timestamp_last_dlm_i);
               trb_sync_buffer_i(trb_sync_lowest_address_c+3) <= std_logic_vector(trb_from_cbm_timestamp_last_pulse_i);
               trb_sync_buffer_i(trb_sync_lowest_address_c+4) <= std_logic_vector(trb_timestamp_i);
               trb_sync_buffer_i(trb_sync_lowest_address_c+5) <= std_logic_vector(trb_timestamp_last_dlm_i);
               trb_sync_buffer_i(trb_sync_lowest_address_c+6) <= std_logic_vector(trb_timestamp_last_pulse_i);
               trb_sync_buffer_i(trb_sync_lowest_address_c+7) <= std_logic_vector(trb_from_cbm_dlm_counter_i);
               trb_sync_buffer_i(trb_sync_lowest_address_c+8) <= std_logic_vector(trb_from_cbm_pulse_counter_i);
               trb_sync_buffer_i(trb_sync_lowest_address_c+9) <= STD_LOGIC_VECTOR(trb_reset_counter_i) & STD_LOGIC_VECTOR(trb_from_cbm_reset_counter_i);               
            
            when trb_sync_lowest_address_c + 1 to trb_sync_lowest_address_c =>
               TRB_REGIO_OUT.data <= trb_sync_buffer_i(trb_regio_addr_i);
               
            when others =>
               TRB_REGIO_OUT.unknown <= TRB_REGIO_IN.read or TRB_REGIO_IN.write;
               
         end case;
         
         if TRB_REGIO_IN.write = '1' then
            case (trb_regio_addr_i) is
               when 0 =>
                  trb_dlm_sense_mask_i      <= TRB_REGIO_IN.data(31 downto 16);
                  trb_epoch_update_scheme_i <= TRB_REGIO_IN.data(1 downto 0);
               
               when 1 =>
                  trb_pulser_threshold_i <= TRB_REGIO_IN.data;
                  
               when 2 =>
                  trb_next_epoch_i <= TRB_REGIO_IN.data;
                  trb_next_epoch_updated_i <= '1';
               
               when others =>
                  TRB_REGIO_OUT.unknown <= '1';
            end case;
         end if;
      end if;
   end process;

-- CBMNet slow control
   CBMNET_SLOW_CTRL_PROC: process is
   begin
      wait until rising_edge(CBM_CLK_IN);
      
      if CBM_RESET_IN = '1' then
         CBM_CTRL_DATA_STOP_OUT <= '1';
         cbm_next_epoch_updated_i <= '0';
         cbm_slow_ctrl_fsm_i <= WAIT_FOR_START;
         
      else
         CBM_CTRL_DATA_STOP_OUT <= '0';
         case cbm_slow_ctrl_fsm_i is
            when WAIT_FOR_START =>
               if CBM_CTRL_DATA_START_IN = '1' then
                  cbm_next_epoch_half_buf_i <= CBM_CTRL_DATA_IN;
                  cbm_slow_ctrl_fsm_i <= SHIFT_LOW_WORD;
               end if;
               
            when SHIFT_LOW_WORD =>
               cbm_slow_ctrl_fsm_i <= WAIT_FOR_START;
               if CBM_CTRL_DATA_END_IN = '1' then
                  cbm_next_epoch_i <= cbm_next_epoch_half_buf_i & CBM_CTRL_DATA_IN;
                  cbm_next_epoch_updated_i <= '1';
               end if;
         end case;

         if cbm_dlm_sensed_i = '1' then
            cbm_next_epoch_updated_i <= '0';
         end if;
      end if;
   end process;

-- CBMNet DLM selection
   CBM_DLM_SENSE_PROC: process is
      variable dlm_v : integer range 0 to 15;
      variable sensed_v : std_logic;
   begin
      wait until rising_edge(CBM_CLK_IN);
      
      dlm_v := to_integer(UNSIGNED(CBM_DLM_REC_IN));
      sensed_v := cbm_from_trb_dlm_sense_mask_i(dlm_v) and CBM_DLM_REC_VALID_IN;
      cbm_dlm_sensed_i <= sensed_v;
      
      if CBM_RESET_IN='1' then
         cbm_dlm_counter_i <= (others=>'0');
      elsif sensed_v='1' then
         cbm_dlm_counter_i <= cbm_dlm_counter_i + 1;
      end if;
   end process;
   
   CBM_DLM_SENSE_OUT <= cbm_dlm_sensed_i;
   
   CBM_EPOCH_PROC: process is
   begin
      wait until rising_edge(CBM_CLK_IN);
      
      if CBM_RESET_IN = '1' then
         cbm_current_epoch_updated_i <= '0';
         cbm_current_epoch_i <= (others => '0');
         
      elsif cbm_dlm_sensed_i = '1' then
         case cbm_from_trb_epoch_update_scheme_i is
            when "01" => -- TRB defined
               cbm_current_epoch_i <= cbm_from_trb_next_epoch_i;
               cbm_current_epoch_updated_i <= cbm_from_trb_next_epoch_updated_i;
               
            when "10" => -- CBM defined
               cbm_current_epoch_i <= cbm_next_epoch_i;
               cbm_current_epoch_updated_i <= cbm_next_epoch_updated_i;
               
            when others =>
               cbm_current_epoch_i <= STD_LOGIC_VECTOR(UNSIGNED(cbm_current_epoch_i) + TO_UNSIGNED(1,32));
               cbm_current_epoch_updated_i <= '1';
         
         end case;
      end if;
   end process;
         
-- TIMESTAMPS
   CBM_CLOCK_PROC: process is
      variable last_reset_v : std_logic := '1';
   begin
      wait until rising_edge(CBM_CLK_IN);
      if CBM_RESET_IN='1' then
         cbm_timestamp_i <= (others => '0');
         if last_reset_v = '0' then
            cbm_reset_counter_i <= cbm_reset_counter_i + 1;
         end if;
      else
         if cbm_dlm_sensed_i = '1' then
            cbm_timestamp_last_dlm_i <= cbm_timestamp_i;
         end if;
      
         cbm_timestamp_i <= cbm_timestamp_i + 1;
      end if;
      last_reset_v := CBM_RESET_IN;
   end process;
   
   CBM_PULSER_PROC: process is
   begin
      wait until rising_edge(CBM_CLK_IN);
      
      cbm_from_trb_pulser_threshold_i <= unsigned(trb_pulser_threshold_i);
      cbm_pulse_i <= '0';
      
      if CBM_RESET_IN='1' then
         cbm_pulse_counter_i <= (others=>'0');
      end if;
      
      
      if CBM_RESET_IN='1' or cbm_from_trb_pulser_threshold_i=x"00000000" then
         cbm_pulser_period_counter_i <= (others=>'0');
         
      elsif cbm_pulser_period_counter_i = cbm_from_trb_pulser_threshold_i then
         cbm_pulser_period_counter_i <= (others=>'0');
         cbm_pulse_counter_i <= cbm_pulse_counter_i + 1;
         cbm_timestamp_last_pulse_i <= cbm_timestamp_i;
         cbm_pulse_i <= '1';
      
      elsif cbm_pulser_period_counter_i > cbm_from_trb_pulser_threshold_i then
         cbm_pulser_period_counter_i <= (others=>'0');
         
      else
         cbm_pulser_period_counter_i <= cbm_pulser_period_counter_i + 1;
      
      end if;
   end process;
   CBM_PULSER_OUT <= cbm_pulse_i;

   TRB_CLOCK_PROC: process is
      variable last_reset_v : std_logic := '1';
   begin
      wait until rising_edge(TRB_CLK_IN);
      if TRB_RESET_IN='1' then
         trb_timestamp_i <= (others => '0');
         if last_reset_v = '0' then
            trb_reset_counter_i <= trb_reset_counter_i + 1;
         end if;
      else
         if trb_from_cbm_dlm_sensed_i = '1' then
            trb_timestamp_last_dlm_i <= trb_timestamp_i;
         end if;

         if trb_from_cbm_pulse_i = '1' then
            trb_timestamp_last_pulse_i <= trb_timestamp_i;
         end if;
         
         trb_timestamp_i <= trb_timestamp_i + 1;
      end if;
      last_reset_v := TRB_RESET_IN;
   end process;
   
-- Clock Domain Crossing CBM -> TRB
   THE_PULSE_SYNC: pos_edge_strech_sync port map (
      IN_CLK_IN => CBM_CLK_IN, OUT_CLK_IN => TRB_CLK_IN,
      DATA_IN   => cbm_pulse_i,
      DATA_OUT  => trb_from_cbm_pulse_i
   );
   
   THE_DLM_SENSE_SYNC: pos_edge_strech_sync port map (
      IN_CLK_IN => CBM_CLK_IN, OUT_CLK_IN => TRB_CLK_IN,
      DATA_IN   => cbm_dlm_sensed_i,
      DATA_OUT  => trb_from_cbm_dlm_sensed_i
   );
   
   TRB_TRIGGER_OUT <= trb_from_cbm_dlm_sensed_i;

   trb_from_cbm_timestamp_i             <= cbm_timestamp_i             when rising_edge(TRB_CLK_IN);
   trb_from_cbm_timestamp_last_dlm_i    <= cbm_timestamp_last_dlm_i    when rising_edge(TRB_CLK_IN);
   trb_from_cbm_reset_counter_i         <= cbm_reset_counter_i         when rising_edge(TRB_CLK_IN);
   trb_from_cbm_dlm_counter_i           <= cbm_dlm_counter_i           when rising_edge(TRB_CLK_IN);
   trb_from_cbm_pulse_counter_i         <= cbm_pulse_counter_i         when rising_edge(TRB_CLK_IN);
   trb_from_cbm_timestamp_last_pulse_i  <= cbm_timestamp_last_pulse_i  when rising_edge(TRB_CLK_IN);

   trb_from_cbm_rdo_registered_i        <= cbm_rdo_registered_i        when rising_edge(TRB_CLK_IN);
   
   trb_from_cbm_current_epoch_i         <= cbm_current_epoch_i         when rising_edge(TRB_CLK_IN);
   trb_from_cbm_current_epoch_updated_i <= cbm_current_epoch_updated_i when rising_edge(TRB_CLK_IN);

-- Clock Domain Crossing TRB -> CBM
   cbm_from_trb_epoch_update_scheme_i   <= trb_epoch_update_scheme_i   when rising_edge(CBM_CLK_IN);
   cbm_from_trb_next_epoch_i            <= trb_next_epoch_i            when rising_edge(CBM_CLK_IN);
   cbm_from_trb_next_epoch_updated_i    <= trb_next_epoch_updated_i    when rising_edge(CBM_CLK_IN);
   cbm_from_trb_dlm_sense_mask_i        <= trb_dlm_sense_mask_i        when rising_edge(CBM_CLK_IN);
   
   cbm_from_trb_trigger_buf_in          <= TRB_TRIGGER_IN              when rising_edge(CBM_CLK_IN);
   cbm_from_trb_trigger_in              <= cbm_from_trb_trigger_buf_in when rising_edge(CBM_CLK_IN);
   cbm_from_trb_rdo_valid_no_timing_in  <= TRB_RDO_VALID_NO_TIMING_IN  when rising_edge(CBM_CLK_IN);
   cbm_from_trb_rdo_finished_i          <= trb_rdo_finished_i          when rising_edge(CBM_CLK_IN);
   cbm_from_trb_reset_in                <= TRB_RESET_IN                when rising_edge(CBM_CLK_IN);
   
-- DEBUG
   DEBUG_OUT <= (others => '0');
   
end architecture;