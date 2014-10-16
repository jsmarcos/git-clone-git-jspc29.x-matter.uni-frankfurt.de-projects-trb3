library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;


entity CBMNET_READOUT_FRAME_PACKER is
   port (
      CLK_IN   : in std_logic;
      RESET_IN : in std_logic; 

      -- fifo 
      FIFO_DATA_IN   : in std_logic_vector(17 downto 0);
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

architecture cbmnet_readout_frame_packer_arch of CBMNET_READOUT_FRAME_PACKER is
   type FSM_STATES_T is (
      IDLE,
      SETUP_TRANSACTION, SETUP_TRANSACTION_WAIT, SETUP_TRANSACTION_FETCH_LENGTH_H, SETUP_TRANSACTION_FETCH_LENGTH_L, 
      FIRST_FRAME_SEND_HDR, FIRST_FRAME_SEND_LENGTH_H,
      BEGIN_FRAME_WAIT, BEGIN_FRAME, BEGIN_FRAME_PRE_WAIT0, BEGIN_FRAME_PRE_WAIT1, BEGIN_FRAME_PRE_WAIT2, SEND_HDR,
      SEND_PAYLOAD, SEND_STOP_WORD,
      COMPLETE_TRANSACTION, COMPLETE_TRANSACTION_WAIT
   );
   
   type FSM_STATES_ENC_T is array(FSM_STATES_T) of std_logic_vector(3 downto 0);
   constant fsm_state_enc_c : FSM_STATES_ENC_T := (
      IDLE => x"0",
      SETUP_TRANSACTION => x"1", SETUP_TRANSACTION_WAIT => x"2", SETUP_TRANSACTION_FETCH_LENGTH_H => x"3", SETUP_TRANSACTION_FETCH_LENGTH_L => x"4", 
      FIRST_FRAME_SEND_HDR => x"5", FIRST_FRAME_SEND_LENGTH_H => x"6",
      BEGIN_FRAME => x"7", SEND_HDR => x"8", BEGIN_FRAME_WAIT => x"c", BEGIN_FRAME_PRE_WAIT0 => x"d", BEGIN_FRAME_PRE_WAIT1 => x"d", BEGIN_FRAME_PRE_WAIT2 => x"d",
      SEND_PAYLOAD => x"9", SEND_STOP_WORD => x"a",
      COMPLETE_TRANSACTION => x"b", COMPLETE_TRANSACTION_WAIT => x"b"
   );
   
   signal fsm_i : FSM_STATES_T;
   
   signal transaction_number_i : unsigned(15 downto 0);
   signal frame_number_i       : unsigned( 6 downto 0); -- frame in current transaction
   
   signal remaining_words_in_transaction_i : unsigned(15 downto 0);
   signal remaining_words_in_frame_i       : unsigned(15 downto 0);
   signal remaining_words_to_dequeue_i     : unsigned(15 downto 0);

   signal dequeue_i : std_logic;
   
   signal buf_length_h_i : std_logic_vector(15 downto 0);
   
   signal fifo_data_i : std_logic_vector(15 downto 0);
   signal fifo_token_i : std_logic_vector(1 downto 0);
   
begin
   fifo_data_i <= FIFO_DATA_IN(15 downto 0);
   fifo_token_i <= FIFO_DATA_IN(17 downto 16);


   PROC_TX_CNTL: process is 
      variable dequeue_forced_v : std_logic;
      variable dequeue_if_allowed_v : std_logic;
   begin
      wait until rising_edge(CLK_IN);
      
      CBMNET_START_OUT <= '0';
      CBMNET_END_OUT <= '0';
      CBMNET_DATA_OUT <= fifo_data_i;
      
      dequeue_if_allowed_v := '0';
      dequeue_forced_v := '0';
      
      FIFO_PACKET_COMPLETE_ACK_OUT <= '0';
      
      if RESET_IN = '1' then
         fsm_i <= IDLE;
         transaction_number_i <= (others => '0');
         
      else
         case(fsm_i) is
            when IDLE =>
               if FIFO_PACKET_COMPLETE_IN='1' then
                  fsm_i <= SETUP_TRANSACTION;
               end if;
            
            when SETUP_TRANSACTION =>
               frame_number_i <= (others => '0');
               transaction_number_i <= transaction_number_i + 1;
               dequeue_forced_v := '1';
               fsm_i <= SETUP_TRANSACTION_WAIT;
               
            when SETUP_TRANSACTION_WAIT =>
               fsm_i <= SETUP_TRANSACTION_FETCH_LENGTH_H;
            
            when SETUP_TRANSACTION_FETCH_LENGTH_H =>
               buf_length_h_i <= fifo_data_i;
               assert(fifo_token_i = "01") report "Invalid LENGHT_H token" severity failure;
               assert(fifo_data_i = x"0000") report "TrbNet length high-byte /= 0 and hence to long. This is not supported by this module" severity failure;
               fsm_i <= SETUP_TRANSACTION_FETCH_LENGTH_L;
            
            when SETUP_TRANSACTION_FETCH_LENGTH_L =>
               remaining_words_in_transaction_i <= (others =>'0');
               remaining_words_in_transaction_i(14 downto 0) <= UNSIGNED(fifo_data_i(15 downto 1));
               remaining_words_to_dequeue_i <= (others =>'0');
               remaining_words_to_dequeue_i(14 downto 0) <= UNSIGNED(fifo_data_i(15 downto 1)) - TO_UNSIGNED(1, 15);
               assert(fifo_token_i = "10") report "Invalid LENGTH_L token"  severity failure;
               assert(to_integer(UNSIGNED(fifo_data_i)) >= 24) report "TrbNet packet too short. Expect minimal length of 24 bytes." severity failure;
               assert(to_integer(UNSIGNED(fifo_data_i)) < 35536) report "TrbNet packet too long." severity failure;
               fsm_i <= FIRST_FRAME_SEND_HDR;
            
            when FIRST_FRAME_SEND_HDR =>
               CBMNET_DATA_OUT <= (others => '0');
               remaining_words_in_frame_i <= TO_UNSIGNED(31, 16);
               if remaining_words_in_transaction_i <= 31 then
                  CBMNET_DATA_OUT(15) <= '1'; -- stop
                  remaining_words_in_frame_i <= remaining_words_in_transaction_i;
               end if;
               CBMNET_DATA_OUT(14) <= '1'; -- start
               CBMNET_DATA_OUT(11 downto 0) <= STD_LOGIC_VECTOR(transaction_number_i(11 downto 0));
               
               if CBMNET_STOP_IN='0' then
                  dequeue_if_allowed_v := '1';
                  CBMNET_START_OUT <= '1';
                  fsm_i <= FIRST_FRAME_SEND_LENGTH_H;
               end if;
            
            when FIRST_FRAME_SEND_LENGTH_H =>
               CBMNET_DATA_OUT <= buf_length_h_i;
               dequeue_if_allowed_v := '1';
               remaining_words_in_frame_i <= remaining_words_in_frame_i - 1;
               remaining_words_in_transaction_i <= remaining_words_in_transaction_i - 1;
               fsm_i <= SEND_PAYLOAD;
            
            
            when BEGIN_FRAME_PRE_WAIT0 =>
               fsm_i <= BEGIN_FRAME_PRE_WAIT1;
            when BEGIN_FRAME_PRE_WAIT1 =>
               fsm_i <= BEGIN_FRAME_PRE_WAIT2;
            when BEGIN_FRAME_PRE_WAIT2 =>
               fsm_i <= BEGIN_FRAME;
            
            when BEGIN_FRAME =>
               if CBMNET_STOP_IN='0' then
                  dequeue_if_allowed_v := '1';
                  fsm_i <= SEND_HDR;
                  frame_number_i <= frame_number_i + 1;
               end if;
               
            when BEGIN_FRAME_WAIT =>
               dequeue_if_allowed_v := '1';
               fsm_i <= SEND_HDR;
            
            when SEND_HDR =>
               CBMNET_DATA_OUT <= (others => '0');
               remaining_words_in_frame_i <= TO_UNSIGNED(31, 16);
               
               if remaining_words_in_transaction_i <= 31 then
                  CBMNET_DATA_OUT(15) <= '1'; -- stop
                  CBMNET_DATA_OUT(11 downto 0) <= STD_LOGIC_VECTOR(transaction_number_i(11 downto 0));
                  
                  if remaining_words_in_transaction_i <= 3  then
                     remaining_words_in_frame_i <= TO_UNSIGNED(3, 16);
                  else
                     remaining_words_in_frame_i <= remaining_words_in_transaction_i;
                  end if;
                  
               else
                  CBMNET_DATA_OUT(11 downto 7) <= STD_LOGIC_VECTOR(transaction_number_i(4 downto 0));
                  CBMNET_DATA_OUT(6 downto 0)  <= STD_LOGIC_VECTOR(frame_number_i(6 downto 0));
               end if;

               dequeue_if_allowed_v := '1';
               CBMNET_START_OUT <= '1';
               fsm_i <= SEND_PAYLOAD;
            
            when SEND_PAYLOAD =>
               if remaining_words_in_transaction_i = 0 then
                  CBMNET_DATA_OUT <= x"aaaa";
               else
                  remaining_words_in_transaction_i <= remaining_words_in_transaction_i - 1;
               end if;
            
               remaining_words_in_frame_i <= remaining_words_in_frame_i - 1;
               if remaining_words_in_frame_i > 3 then
                  dequeue_if_allowed_v := '1';
               end if;
               
               if remaining_words_in_frame_i = 2 then
                  fsm_i <= SEND_STOP_WORD;
               end if;
               
               assert(fifo_token_i = "00" or fifo_token_i = "10" or (fifo_token_i = "11" and remaining_words_in_transaction_i < 2)) report "Invalid LENGHT_L / DATA / END token";
                  
            when SEND_STOP_WORD =>
               if remaining_words_in_transaction_i = 0 then
                  CBMNET_DATA_OUT <= x"aaaa";
               else
                  remaining_words_in_transaction_i <= remaining_words_in_transaction_i - 1;
               end if;
               remaining_words_in_frame_i <= remaining_words_in_frame_i - 1;
               dequeue_if_allowed_v := '1';

               CBMNET_END_OUT <= '1';
               if remaining_words_in_transaction_i = 1 or remaining_words_in_transaction_i = 0 then
                  fsm_i <= COMPLETE_TRANSACTION;
                  FIFO_PACKET_COMPLETE_ACK_OUT <= '1';
                  assert(fifo_token_i = "11") report "Invalid data token";
               else
                  fsm_i <= BEGIN_FRAME_PRE_WAIT0;
                  assert(fifo_token_i = "00") report "Invalid data token";
               end if;
            
            
            when COMPLETE_TRANSACTION =>
               assert(remaining_words_to_dequeue_i = 0) report "Fifo was not properly emptied";
               fsm_i <= COMPLETE_TRANSACTION_WAIT;
               
            when COMPLETE_TRANSACTION_WAIT =>
               fsm_i <= IDLE;
            
            
         end case;
         
         dequeue_i <= dequeue_forced_v;
         if dequeue_if_allowed_v = '1' and remaining_words_to_dequeue_i > 0 then
            dequeue_i <= '1';
            remaining_words_to_dequeue_i <= remaining_words_to_dequeue_i - 1;
         end if;
      end if;
   end process;
   
   FIFO_DEQUEUE_OUT <= dequeue_i;
   DEBUG_OUT(31 downto 4) <= (others => '0');
   DEBUG_OUT(3 downto 0) <= fsm_state_enc_c(fsm_i);
end architecture;

