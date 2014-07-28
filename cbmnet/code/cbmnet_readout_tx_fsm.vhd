library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;


entity CBMNET_READOUT_TX_FSM is
   port (
      CLK_IN   : in std_logic;
      RESET_IN : in std_logic; 

      -- fifo 
      FIFO_DATA_IN   : in std_logic_vector(15 downto 0);
      FIFO_DEQUEUE_OUT : out std_logic;
      FIFO_PACKET_COMPLETE_IN : in std_logic;  
      FIFO_PACKET_COMPLETE_ACK_OUT : out std_logic;

      -- cbmnet
      CBMNET_STOP_IN   : in std_logic;
      CBMNET_START_OUT : out std_logic;
      CBMNET_END_OUT   : out std_logic;
      CBMNET_DATA_OUT  : out std_logic_vector(15 downto 0);
      
      -- debug
      DEBUG_OUT : out std_logic_vector(31 downto 0)
   );
end entity;

architecture cbmnet_readout_tx_fsm_arch of CBMNET_READOUT_TX_FSM is
   constant PAYLOAD_PER_PACKET_C : integer := 62; -- bytes


   type FSM_STATES_T is (WAIT_FOR_COMPL_PACKET, SETUP_TRANSACTION, SEND_HEADER, SEND_PAYLOAD, SEND_PACKET_GAP, FINISH_TRANSACTION, FINISH_WAIT1, FINISH_WAIT2);
   signal fsm_i : FSM_STATES_T;
   signal fsm_state_i : unsigned(3 downto 0);
   
   signal trans_num_i : unsigned(5 downto 0);
   
   signal trans_bytes_length_i : unsigned(15 downto 0) := x"0000";
   signal trans_bytes_send_i   : unsigned(15 downto 0);
   
   signal pack_num_i : unsigned(5 downto 0);
   signal pack_payload_words_i : unsigned(4 downto 0);
   
   signal pack_start_i, pack_stop_i : std_logic;
   
   signal trans_complete_i : std_logic;
   


begin
   PROC_TX_CNTL: process is 
   begin
      wait until rising_edge(CLK_IN);
      
      CBMNET_START_OUT <= '0';
      CBMNET_END_OUT <= '0';
      CBMNET_DATA_OUT <= FIFO_DATA_IN;
      
      FIFO_DEQUEUE_OUT <= '0';
      FIFO_PACKET_COMPLETE_ACK_OUT <= '0';
      
      if RESET_IN = '1' then
         fsm_i <= WAIT_FOR_COMPL_PACKET;
         trans_num_i <= (others => '0');
         fsm_state_i <= x"0";         
         
      else
         case(fsm_i) is
            when WAIT_FOR_COMPL_PACKET =>
               fsm_state_i <= x"1";
               if FIFO_PACKET_COMPLETE_IN = '1' then
                  fsm_i <= SETUP_TRANSACTION;
               end if;
                       
            when SETUP_TRANSACTION =>
               fsm_state_i <= x"2";
               trans_bytes_send_i <= (others => '0');
               pack_num_i <= (others => '0');
               pack_start_i <= '1';
               trans_bytes_length_i(15) <= '1'; -- dont really care which value as long as it's > 2, so it ensured that the first word of the SE-Hdr is sent!

               fsm_i <= SEND_HEADER;
            
            when SEND_HEADER =>
               fsm_state_i <= x"3";
               if CBMNET_STOP_IN = '0' then
                  CBMNET_DATA_OUT <= (others => '0');
                  CBMNET_DATA_OUT( 5 downto 0) <= STD_LOGIC_VECTOR(pack_num_i);
                  CBMNET_DATA_OUT(11 downto 6) <= STD_LOGIC_VECTOR(trans_num_i);
                  CBMNET_DATA_OUT(14) <= pack_start_i;
                  CBMNET_DATA_OUT(15) <= pack_stop_i;
                  CBMNET_START_OUT <= '1';

                  pack_payload_words_i <= (others => '0');
               
                  FIFO_DEQUEUE_OUT <= '1';
                  fsm_i <= SEND_PAYLOAD;
               end if;
            
            when SEND_PAYLOAD =>
               fsm_state_i <= x"4";
               if pack_payload_words_i = 30 or trans_complete_i = '1' then
                  CBMNET_END_OUT <= '1';
                  pack_num_i <= pack_num_i + 1;
                  
                  if trans_complete_i = '1' then
                     fsm_i <= FINISH_TRANSACTION;
                  else
                     fsm_i <= SEND_PACKET_GAP;
                  end if;
                  
               else
                  FIFO_DEQUEUE_OUT <= '1';
               end if;

               if trans_bytes_send_i = 2 then
                  trans_bytes_length_i <= UNSIGNED(FIFO_DATA_IN);
               end if;
               
               pack_start_i <= '0';
               pack_payload_words_i <= pack_payload_words_i + 1;
               trans_bytes_send_i <= trans_bytes_send_i + 2;
               
               
            when SEND_PACKET_GAP =>
               fsm_state_i <= x"5";
               fsm_i <= SEND_HEADER;
            
            when FINISH_TRANSACTION =>
               fsm_state_i <= x"6";
               FIFO_PACKET_COMPLETE_ACK_OUT <= '1';
               trans_num_i <= trans_num_i + 1;
               fsm_i <= FINISH_WAIT1;
         
            when FINISH_WAIT1 =>
               fsm_state_i <= x"6";
               fsm_i <= FINISH_WAIT2;
            
            when FINISH_WAIT2 =>
               fsm_state_i <= x"6";
               fsm_i <= WAIT_FOR_COMPL_PACKET;
         
         end case;
      end if;
   end process;

   pack_stop_i <= '1' when trans_bytes_length_i - trans_bytes_send_i < PAYLOAD_PER_PACKET_C else '0';
   trans_complete_i <= '1' when trans_bytes_length_i = trans_bytes_send_i else '0';
   
   DEBUG_OUT(3 downto 0) <= fsm_state_i;
end architecture;

