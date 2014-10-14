library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity CBMNET_READOUT_EVENT_PACKER is
   port (
   -- TrbNet
      CLK_IN   : in std_logic;
      RESET_IN : in std_logic;

      -- connect to hub
      HUB_CTS_NUMBER_IN              : in  std_logic_vector (15 downto 0);
      HUB_CTS_CODE_IN                : in  std_logic_vector (7  downto 0);
      HUB_CTS_INFORMATION_IN         : in  std_logic_vector (7  downto 0);
      HUB_CTS_READOUT_TYPE_IN        : in  std_logic_vector (3  downto 0);
      HUB_FEE_STATUS_BITS_IN         : in  std_logic_vector (31 downto 0);
      
      
      -- connect to decoder
      DEC_EVT_INFO_IN                : in  std_logic_vector(31 downto 0);
      DEC_LENGTH_IN                  : in  std_logic_vector(15 downto 0);
      DEC_SOURCE_IN                  : in  std_logic_vector(15 downto 0);
      DEC_DATA_IN                    : in  std_logic_vector(15 downto 0);
      DEC_DATA_READY_IN              : in  std_logic;
      DEC_ACTIVE_IN                  : in  std_logic;
      DEC_ERROR_IN                   : in  std_logic;
      
      DEC_DATA_READ_OUT              : out std_logic;
      DEC_RESET_OUT                  : out std_logic;

      -- connect to fifo
      WADDR_STORE_OUT  : out std_logic;
      WADDR_RESTORE_OUT: out std_logic;
      WDATA_OUT        : out std_logic_vector(17 downto 0);
      WENQUEUE_OUT     : out std_logic;
      WPACKET_COMPLETE_OUT: out std_logic;
      WFULL_IN         : in  std_logic;
      
      DEBUG_OUT                      : out std_logic_vector(31 downto 0)
   );
end entity;

architecture cbmnet_readout_event_packer_arch of CBMNET_READOUT_EVENT_PACKER is
   type FSM_STATES_T is (
      WAIT_FOR_IDLE, IDLE, 
      HDR_SIZE_H, HDR_SIZE_L, 
      HDR_DECODING_H, HDR_DECODING_L,
      HDR_ID_H, HDR_ID_L,
      HDR_NUMBER_H, HDR_NUMBER_L,
      PAYLOAD,
      TRL_TRAILER_H, TRL_TRAILER_L,
      TRL_STATUS_H, TRL_STATUS_L
   );
   
   type FSM_STATES_ENC_T is array(FSM_STATES_T) of std_logic_vector(3 downto 0);
   constant fsm_states_enc_c : FSM_STATES_ENC_T := (
      WAIT_FOR_IDLE => x"0",
      IDLE          => x"1",
      HDR_SIZE_H    => x"2",
      HDR_SIZE_L    => x"3",
      HDR_DECODING_H=> x"4",
      HDR_DECODING_L=> x"5",
      HDR_ID_H      => x"6",
      HDR_ID_L      => x"7",
      HDR_NUMBER_H  => x"8",
      HDR_NUMBER_L  => x"9",
      PAYLOAD       => x"a",
      TRL_TRAILER_H => x"b",
      TRL_TRAILER_L => x"c",
      TRL_STATUS_H  => x"d",
      TRL_STATUS_L  => x"e"
   );
   
   signal fsm_i : FSM_STATES_T;
   signal header_data_i : std_logic_vector(15 downto 0);
   signal header_enqueue_i : std_logic;
   signal header_token_i : std_logic_vector(1 downto 0);
   
   signal copy_payload_i : std_logic;
   
   signal data_read_i, data_read_delayed_i : std_logic;

-- local buffers   
   signal wenqueue_i : std_logic;
   signal wpacket_complete_i : std_logic;
   signal waddr_restore_i : std_logic;
   signal waddr_store_i : std_logic;
begin
   THE_PACKER: process is
   begin
      wait until rising_edge(CLK_IN);
      
      waddr_store_i <= '0';
      waddr_restore_i <= '0';
      DEC_RESET_OUT <= '0';    
      copy_payload_i <= '0';
      header_data_i <= (others => '-');
      header_enqueue_i <= '0';
      wpacket_complete_i <= '0';
      header_token_i <= "00";
      
      if RESET_IN='1' then
         fsm_i <= WAIT_FOR_IDLE;
       
      elsif fsm_i /= IDLE and (DEC_ERROR_IN = '1' or (DEC_ACTIVE_IN='1' and WFULL_IN = '1')) then
         waddr_restore_i <= '1';
         DEC_RESET_OUT <= '1';
         fsm_i <= WAIT_FOR_IDLE;
         
      else
         case(fsm_i) is
            when WAIT_FOR_IDLE =>
               if DEC_ACTIVE_IN='0' then
                  fsm_i <= IDLE;
               end if;
         
            when IDLE =>
               if DEC_ACTIVE_IN='1' then
                  waddr_store_i <= '1';
                  fsm_i <= HDR_SIZE_H;
               end if;
               
            when HDR_SIZE_H =>
               header_token_i <= "01";
               header_data_i <= x"0000";
               header_enqueue_i <= '1';
               fsm_i <= HDR_SIZE_L;
               
            when HDR_SIZE_L =>
               header_token_i <= "10";
               
               header_data_i <= STD_LOGIC_VECTOR(UNSIGNED(DEC_LENGTH_IN) + TO_UNSIGNED(16+8, 16)); -- 8 words of SE-Hdr and 4 words for SE-trailer 
               header_enqueue_i <= '1';
               fsm_i <= HDR_DECODING_H;

            when HDR_DECODING_H =>
               header_data_i <= x"0002";
               header_enqueue_i <= '1';
               fsm_i <= HDR_DECODING_L;
            when HDR_DECODING_L =>
               header_data_i <= x"00" & HUB_CTS_READOUT_TYPE_IN & x"1";
               header_enqueue_i <= '1';
               fsm_i <= HDR_ID_H;

            when HDR_ID_H =>
               header_data_i <= x"0000";
               header_enqueue_i <= '1';
               fsm_i <= HDR_ID_L;
            when HDR_ID_L =>
               header_data_i <= x"beaf";
               header_enqueue_i <= '1';
               fsm_i <= HDR_NUMBER_H;

            when HDR_NUMBER_H =>
               header_data_i <= x"00" & HUB_CTS_NUMBER_IN(15 downto 8);
               header_enqueue_i <= '1';
               fsm_i <= HDR_NUMBER_L;
            when HDR_NUMBER_L =>
               header_data_i <= HUB_CTS_NUMBER_IN(7 downto 0) & HUB_CTS_CODE_IN;
               header_enqueue_i <= '1';
               fsm_i <= PAYLOAD;

            when PAYLOAD =>
               if DEC_ACTIVE_IN = '0' then
                  fsm_i <= TRL_TRAILER_H;
               else
                  copy_payload_i <= '1';
               end if;
               
            when TRL_TRAILER_H =>
               header_data_i <= x"0001";
               header_enqueue_i <= '1';
               fsm_i <= TRL_TRAILER_L;
            when TRL_TRAILER_L =>
               header_data_i <= x"5555";
               header_enqueue_i <= '1';
               fsm_i <= TRL_STATUS_H;            

            when TRL_STATUS_H =>
               header_data_i <= HUB_FEE_STATUS_BITS_IN(31 downto 16);
               header_enqueue_i <= '1';
               fsm_i <= TRL_STATUS_L;
            when TRL_STATUS_L =>
               header_token_i <= "11";
               header_data_i <= HUB_FEE_STATUS_BITS_IN(15 downto  0);
               header_enqueue_i <= '1';
               wpacket_complete_i <= '1';
               fsm_i <= IDLE;                         
               
         end case;
      end if;
   end process;
   
   WDATA_OUT(17 downto 0) <= "00" & DEC_DATA_IN when copy_payload_i='1' else header_token_i & header_data_i;
   wenqueue_i <= header_enqueue_i or data_read_i;
   
   data_read_i <= copy_payload_i and DEC_DATA_READY_IN;
   DEC_DATA_READ_OUT <= data_read_i;
   data_read_delayed_i <= data_read_i when rising_edge(CLK_IN);

-- Outputs   
   WADDR_STORE_OUT <= waddr_store_i;
   WADDR_RESTORE_OUT <= waddr_restore_i;
   WENQUEUE_OUT <= wenqueue_i;
   WPACKET_COMPLETE_OUT <= wpacket_complete_i;
   
-- Debug
   DEBUG_OUT( 3 downto  0) <= fsm_states_enc_c(fsm_i);
   DEBUG_OUT( 7 downto  4) <= DEC_DATA_READY_IN & DEC_ACTIVE_IN & DEC_ERROR_IN & data_read_i;
   DEBUG_OUT(11 downto  8) <= wpacket_complete_i & waddr_restore_i & waddr_store_i & wenqueue_i;
   DEBUG_OUT(15 downto 12) <= "000" & WFULL_IN;
end architecture;