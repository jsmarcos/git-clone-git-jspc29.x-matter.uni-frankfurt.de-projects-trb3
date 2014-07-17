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
      WALMOST_FULL_IN  : in  std_logic;
      WFULL_IN         : in  std_logic;
      
      DEBUG_OUT                      : out std_logic_vector(31 downto 0)
   );
end entity;

architecture cbmnet_readout_event_packer_arch of CBMNET_READOUT_EVENT_PACKER is
   type FSM_STATES_T is (
      IDLE, 
      HDR_SIZE_H, HDR_SIZE_L, 
      HDR_DECODING_H, HDR_DECODING_L,
      HDR_ID_H, HDR_ID_L,
      HDR_NUMBER_H, HDR_NUMBER_L,
      PAYLOAD,
      FTR_TRAILER_H, FTR_TRAILER_L,
      FTR_STATUS_H, FTR_STATUS_L
   );
   
   signal fsm_i : FSM_STATES_T;
   signal header_data_i : std_logic_vector(15 downto 0);
   signal header_enqueue_i : std_logic;
begin
   THE_PACKER: process is
   begin
      wait until rising_edge(CLK_IN);
      
      WADDR_STORE_OUT <= '0';
      WADDR_RESTORE_OUT <= '0';
      DEC_RESET_OUT <= '0';    
      copy_payload_i <= '0';
      header_data_i <= (others => '-');
      header_enqueue_i <= '0';
      WPACKET_COMPLETE_OUT <= '0';
      
      if RESET_IN='1' then
         fsm_i <= IDLE;
       
      elsif fsm_i /= IDLE and (DEC_ERROR_IN = '1' or WFULL_IN = '1') then
         WADDR_RESTORE_OUT <= '1';
         DEC_RESET_OUT <= '1';
         fsm_i <= IDLE;
         
      else
         case(fsm_i) is
            when IDLE =>
               if DEC_ACTIVE_IN='1' then
                  WADDR_STORE_OUT <= '1';
                  fsm_i <= HDR_SIZE_H;
               end if;
               
            when HDR_SIZE_H =>
               header_data_i <= x"0000";
               header_enqueue_i <= '1';
               fsm_i <= HDR_SIZE_L;
            when HDR_SIZE_L =>
               header_data_i <= DEC_LENGTH_IN;
               header_enqueue_i <= '1';
               fsm_i <= HDR_DECODING_H;

            when HDR_DECODING_H =>
               header_data_i <= x"0003";
               header_enqueue_i <= '1';
               fsm_i <= HDR_DECODING_L;
            when HDR_DECODING_L =>
               header_data_i <= x"000" & HUB_CTS_READOUT_TYPE_IN;
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
               fsm_i <= HDR_SIZE_L;

            when PAYLOAD =>
               if DEC_ACTIVE_IN = '0' then
                  fsm_i <= FTR_TRAILER_H;
               else
                  copy_payload_i <= '1';
               end if;
               
            when FTR_TRAILER_H =>
               header_data_i <= x"0001";
               header_enqueue_i <= '1';
               fsm_i <= FTR_TRAILER_L;
            when FTR_TRAILER_L =>
               header_data_i <= x"5555";
               header_enqueue_i <= '1';
               fsm_i <= FTR_STATUS_H;            

            when FTR_STATUS_H =>
               header_data_i <= x"0001";
               header_enqueue_i <= '1';
               fsm_i <= FTR_STATUS_L;
            when FTR_STATUS_L =>
               header_data_i <= x"5555";
               header_enqueue_i <= '1';
               WPACKET_COMPLETE_OUT <= '1';
               fsm_i <= IDLE;                         
               
         end case;
      end if;
   end process;
   
   WDATA_OUT <= DEC_DATA_IN when copy_payload_i='1' else header_data_i;
   WENQUEUE_OUT <= header_data_i or DEC_DATA_READY_IN;
   DEC_DATA_READ_OUT <= copy_payload_i and DEC_DATA_READY_IN;
end architecture;