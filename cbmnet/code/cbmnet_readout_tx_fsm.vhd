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
      CBMNET_DATA_OUT  : out std_logic_vector(15 downto 0)
   );
end entity;

architecture cbmnet_readout_tx_fsm_arch of CBMNET_READOUT_TX_FSM is
   constant PAYLOAD_PER_PACKET_C : integer := 62; -- bytes


   type FSM_STATES_T is (WAIT_FOR_COMPL_PACKET, READ_LENGTH_H, SETUP_TRANSACTION, SEND_HEADER, SEND_PAYLOAD, FINISH_TRANSACTION);
   signal fsm_i : FSM_STATES_T;
   
   signal trans_length_high_i : std_logic_vector(15 downto 0);
   signal trans_remaining_length_i : unsigned(15 downto 0);
   
   signal pack_num_i : unsigned(10 downto 0);
   signal pack_payload_words_i : unsigned(4 downto 0);
   
   signal pack_start_i, pack_stop_i : std_logic;
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
      else
         case(fsm_i) is
            when WAIT_FOR_COMPL_PACKET =>
               if FIFO_PACKET_COMPLETE_IN = '1' then
                  fsm_i <= READ_LENGTH_H;
                  FIFO_DEQUEUE_OUT <= '1';
               end if;
               
            when READ_LENGTH_H =>
               trans_length_high_i <= FIFO_DATA_IN(15 downto 0);
               fsm_i <= SETUP_TRANSACTION;
            
            when SETUP_TRANSACTION =>
               trans_remaining_length_i <= UNSIGNED(FIFO_DATA_IN(15 downto 0));
               pack_start_i <= '1';
               pack_num_i <= (others => '0');
               fsm_i <= SEND_HEADER;
            
            when SEND_HEADER =>
               if CBMNET_STOP_IN = '0' then
                  CBMNET_DATA_OUT( 5 downto 0) <= STD_LOGIC_VECTOR(pack_num_i);
                  CBMNET_DATA_OUT(14) <= pack_start_i;
                  CBMNET_DATA_OUT(15) <= pack_stop_i;
                  CBMNET_START_OUT <= '1';

                  if trans_remaining_length_i < PAYLOAD_PER_PACKET_C then
                     -- TODO: i dont think that odd packet lengths are supported by TrbNet, but check it !
                     pack_payload_words_i <= UNSIGNED(trans_remaining_length_i(pack_payload_words_i'high + 1 downto 1));
                  else
                     pack_payload_words_i <= TO_UNSIGNED(PAYLOAD_PER_PACKET_C / 2, pack_payload_words_i'length);
                  end if;
               
                  FIFO_DEQUEUE_OUT <= not pack_start_i;
                  fsm_i <= SEND_PAYLOAD;
               end if;
            
            when SEND_PAYLOAD =>
               if pack_start_i = '1' then
                  CBMNET_DATA_OUT <= trans_length_high_i;
                  FIFO_DEQUEUE_OUT <= '1';
                  
               else
                  if pack_payload_words_i = 1 then
                     CBMNET_END_OUT <= '1';
                     pack_num_i <= pack_num_i + 1;
                     
                     if trans_remaining_length_i = 2 then
                        fsm_i <= FINISH_TRANSACTION;
                     else
                        fsm_i <= SEND_HEADER;
                     end if;
                     
                  else
                     FIFO_DEQUEUE_OUT <= '1';
                  end if;
               end if;
               
               pack_start_i <= '0';
               pack_payload_words_i <= pack_payload_words_i - 1;
               trans_remaining_length_i <= trans_remaining_length_i - 2;
            
            when FINISH_TRANSACTION =>
               FIFO_PACKET_COMPLETE_ACK_OUT <= '1';
               fsm_i <= WAIT_FOR_COMPL_PACKET;
         
         end case;
      end if;
   end process;




   pack_stop_i <= '1' when trans_remaining_length_i < PAYLOAD_PER_PACKET_C else '0';
end architecture;

