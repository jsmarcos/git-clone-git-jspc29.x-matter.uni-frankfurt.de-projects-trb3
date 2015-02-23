library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   
-- receives data stream from hub and extracts header information
-- payload is then stored in an 16 word fifo, which gives the event packer roughly 8 cycles grace time
-- (8 words are required for the header structure expected from the event builders)

-- DEC_ACTIVE_OUT is asserted as soon as DEC_EVT_INFO_OUT, DEC_LENGTH_OUT and DEC_SOURCE_OUT are valid
-- Once DEC_ERROR_OUT is asserted at least one word was lost and no gurantees for correct operations 
-- are given. In this case, discarding of the event and reset of the decoder are recommended
entity CBMNET_READOUT_TRBNET_DECODER is
   port (
   -- TrbNet
      CLK_IN   : in std_logic;
      RESET_IN : in std_logic;
      ENABLED_IN : in std_logic;

      -- connect to hub
      HUB_CTS_START_READOUT_IN       : in  std_logic;
      HUB_FEE_DATA_IN                : in  std_logic_vector (15 downto 0);
      HUB_FEE_DATAREADY_IN           : in  std_logic;
      GBE_FEE_READ_IN                : in std_logic;
      
      -- Decode
      DEC_EVT_INFO_OUT               : out std_logic_vector(31 downto 0);
      DEC_LENGTH_OUT                 : out std_logic_vector(15 downto 0);  -- bytes of payload 
      DEC_SOURCE_OUT                 : out std_logic_vector(15 downto 0);
      DEC_DATA_OUT                   : out std_logic_vector(15 downto 0);
      DEC_DATA_READY_OUT             : out std_logic;
      DEC_DATA_READ_IN               : in  std_logic;
      
      DEC_ACTIVE_OUT                 : out std_logic;
      DEC_ERROR_OUT                  : out std_logic;
      
      DEBUG_OUT                      : out std_logic_vector(31 downto 0)
   );
end entity;

architecture cbmnet_readout_trbnet_decoder_arch of CBMNET_READOUT_TRBNET_DECODER is
   constant FIFO_LENGTH_C : integer := 4;
   type FIFO_MEM_T is array(0 to 2**FIFO_LENGTH_C-1) of std_logic_vector(15 downto 0);
   signal fifo_mem_i : FIFO_MEM_T;

   attribute syn_ramstyle : string;
   attribute syn_ramstyle of fifo_mem_i : signal is "block_ram";

   type FSM_STATES_T is (WAIT_FOR_IDLE, IDLE, RECV_EVT_INFO_H, RECV_EVT_INFO_L, RECV_EVT_LENGTH, RECV_EVT_SOURCE, RECV_PAYLOAD, ERROR_COND);
   signal fsm_i : FSM_STATES_T;
   
   signal data_i : std_logic_vector(15 downto 0);
   signal dec_evt_info_i : std_logic_vector(31 downto 0);
   signal dec_length_i   : std_logic_vector(15 downto 0); -- in bytes !
   signal dec_source_i   : std_logic_vector(15 downto 0);
   signal dec_error_i    : std_logic;
   
   signal word_counter_i : unsigned(15 downto 0);
   signal word_counter_set_i : std_logic;
   signal word_counter_done_i : std_logic;
   
   signal read_word_i    : std_logic;
   
   signal fifo_active_i  : std_logic;
   signal fifo_enqueue_i : std_logic;
   signal fifo_full_i : std_logic;
   signal fifo_empty_i : std_logic;
   
   signal fifo_data_i : std_logic_vector(15 downto 0);
   
   signal fifo_raddr_i : UNSIGNED(FIFO_LENGTH_C-1 downto 0);
   signal fifo_waddr_i : UNSIGNED(FIFO_LENGTH_C-1 downto 0);
begin
   data_i <= HUB_FEE_DATA_IN;
   
   THE_FSM: process is
   begin
      wait until rising_edge(CLK_IN);
      
      fifo_active_i <= '0';
      DEC_ACTIVE_OUT <= '0';
      word_counter_set_i <= '0';
      dec_error_i <= dec_error_i or (not HUB_CTS_START_READOUT_IN and not word_counter_done_i);
      
      if RESET_IN = '1' then
         fsm_i <= WAIT_FOR_IDLE;
         dec_error_i <= '0';
      
      else
         case(fsm_i) is
            when WAIT_FOR_IDLE =>
               DEBUG_OUT(3 downto 0) <= x"0";
               if HUB_CTS_START_READOUT_IN = '0' and ENABLED_IN = '1' then 
                  fsm_i <= IDLE;
               end if;
         
            when IDLE =>
               DEBUG_OUT(3 downto 0) <= x"1";
               dec_error_i <= '0';
               if HUB_CTS_START_READOUT_IN = '1' then
                  fsm_i <= RECV_EVT_INFO_H;
               end if;
            
            when RECV_EVT_INFO_H =>
               DEBUG_OUT(3 downto 0) <= x"2";
               if read_word_i = '1' then
                  dec_evt_info_i(31 downto 16) <= data_i;
                  fsm_i <= RECV_EVT_INFO_L;
               end if;
         
            when RECV_EVT_INFO_L =>
               DEBUG_OUT(3 downto 0) <= x"3";
               if read_word_i = '1' then
                  dec_evt_info_i(15 downto  0) <= data_i;
                  fsm_i <= RECV_EVT_LENGTH;
               end if;
         
            when RECV_EVT_LENGTH =>
               DEBUG_OUT(3 downto 0) <= x"4";
               word_counter_set_i <= '1';
               if read_word_i = '1' then
                  dec_length_i <= data_i(13 downto 0) & "00";
-- synopsys translate_off
   assert data_i(13 downto 0) & "00" /= x"0000" report "TrbNet packet must not be of length 0" severity warning;
-- synopsys translate_on
                  fsm_i <= RECV_EVT_SOURCE;
               end if;
         
            when RECV_EVT_SOURCE =>
               DEBUG_OUT(3 downto 0) <= x"5";
               if read_word_i = '1' then
                  dec_source_i <= data_i;
                  fsm_i <= RECV_PAYLOAD;
                  --fifo_active_i <= '1';
               end if;
         
            when RECV_PAYLOAD =>
               DEBUG_OUT(3 downto 0) <= x"6";
               fifo_active_i <= '1';
               DEC_ACTIVE_OUT <= '1';
               
               if fifo_full_i = '1' and read_word_i = '1' then
                  fsm_i <= ERROR_COND;
               end if;
               
               if fifo_empty_i = '1' and word_counter_done_i = '1' then
                  fsm_i <= WAIT_FOR_IDLE; --LAST_WORD;
               end if;
               
--             when LAST_WORD =>
--                DEC_ACTIVE_OUT <= '1';
--                if DEC_DATA_READ_IN = '1' then
--                   fsm_i <= WAIT_FOR_IDLE;
--                end if;
               
            when others => -- error cond
               DEBUG_OUT(3 downto 0) <= x"7";
               dec_error_i <= '1';
               
         end case;
      end if;
      
      DEBUG_OUT(3 downto 0) <= x"0";
   end process;
   
   
   THE_COUNTER: process is
   begin
      wait until rising_edge(CLK_IN);
      
      if word_counter_set_i = '1' then
         word_counter_i(15) <= '0';
         word_counter_i(14 downto 0) <= UNSIGNED(dec_length_i(15 downto 1));
         
      elsif word_counter_done_i = '0' and fifo_enqueue_i = '1' then
         word_counter_i <= word_counter_i - 1;
         
      end if;
      
      DEBUG_OUT(31 downto 16) <= STD_LOGIC_VECTOR(word_counter_i);
   end process;
   
   word_counter_done_i <= '1' when word_counter_i = x"0000" else '0';
   
   PROC_FIFO: process is
      variable count_v : integer range 0 to 2**FIFO_LENGTH_C := 0;
   begin
      wait until rising_edge(CLK_IN);
      
      if RESET_IN='1' then
         count_v := 0;
         fifo_waddr_i <= (others=>'0');
         fifo_raddr_i <= (others=>'0');
      else
         if fifo_enqueue_i = '1' then
            count_v := count_v + 1;
            fifo_waddr_i <= fifo_waddr_i + TO_UNSIGNED(1,1);
            fifo_mem_i(to_integer(fifo_waddr_i)) <= HUB_FEE_DATA_IN;
         end if;
         
         if DEC_DATA_READ_IN = '1' then
            count_v := count_v - 1;
            fifo_raddr_i <= fifo_raddr_i + TO_UNSIGNED(1,1);
         end if;
      end if;
      
      fifo_empty_i <= '0';
      fifo_full_i <= '0';
      
      if count_v = 0 then
         fifo_empty_i <= '1';
      end if;
      
      if count_v >= 2**FIFO_LENGTH_C then
         fifo_full_i <= '1';
      end if;
   end process;
   fifo_data_i <= fifo_mem_i(to_integer(fifo_raddr_i));
   
   read_word_i <= HUB_FEE_DATAREADY_IN and GBE_FEE_READ_IN;
   fifo_enqueue_i <= fifo_active_i and read_word_i;
   
   DEC_ERROR_OUT <= dec_error_i;
   DEC_LENGTH_OUT <= dec_length_i;
   DEC_EVT_INFO_OUT <= dec_evt_info_i;
   DEC_SOURCE_OUT <= dec_source_i;
   DEC_DATA_READY_OUT <= not fifo_empty_i;
   
   DEC_DATA_OUT <= fifo_data_i;
   
end architecture;

