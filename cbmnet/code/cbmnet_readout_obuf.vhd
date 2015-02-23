library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.cbmnet_interface_pkg.all;

-- this small output buffer is necessary, as the CBMNet interface directly switches to streaming
-- mode once it accepted a start flag. thus the latency between the main buffer over the frame packer to lp_top
-- is to large to corretly implement the stop - flag.
entity CBMNET_READOUT_OBUF is
   port(
      CLK_IN : std_logic;
      RESET_IN : std_logic;

      -- packer
      PACKER_STOP_OUT  : out std_logic;
      PACKER_START_IN  : in  std_logic;
      PACKER_END_IN    : in  std_logic;
      PACKER_DATA_IN   : in  std_logic_vector(15 downto 0);

      -- cbmnet
      CBMNET_STOP_IN   : in std_logic;
      CBMNET_START_OUT : out std_logic;
      CBMNET_END_OUT   : out std_logic;
      CBMNET_DATA_OUT  : out std_logic_vector(15 downto 0);
      
      DEBUG_OUT : out std_logic_vector(31 downto 0) := (others => '0')
   );
end entity;

architecture cbmnet_readout_obuf_arch of CBMNET_READOUT_OBUF is
   signal read_fifo_i, read_fifo_next_i, write_fifo_i : integer range 0 to 1 := 0;
   
   signal fifo_empty_i      : std_logic_vector(1 downto 0);
   signal fifo_enqueue_i    : std_logic_vector(1 downto 0);
   signal fifo_dequeue_i    : std_logic_vector(1 downto 0);
   signal fifo_last_i       : std_logic_vector(1 downto 0);
   signal fifo_set_filled_i : std_logic_vector(1 downto 0);
   signal fifo_get_filled_i : std_logic_vector(1 downto 0);
   
   signal fifo_read_data_i  : std_logic_vector(31 downto 0);
   signal fifo_write_data_i : std_logic_vector(15 downto 0);
   
   signal fifo_deq_i : std_logic;
   
   type WFSM_T is (OBTAIN_FREE_BUFFER, WAIT_FOR_START, WAIT_FOR_END, COMPLETE);
   type WFSM_DEC_T is array(WFSM_T) of std_logic_vector(3 downto 0);
   signal wfsm_i : WFSM_T;
   constant wfsm_dec_c : WFSM_DEC_T := (OBTAIN_FREE_BUFFER => x"1", WAIT_FOR_START => x"2", WAIT_FOR_END => x"3", COMPLETE => x"4");
   
   type RFSM_T is (OBTAIN_FULL_BUFFER, DELAY_WHILE_STOP, WAIT_WHILE_STOP, COPY, PADDING, COMPLETE);
   type RFSM_DEC_T is array(RFSM_T) of std_logic_vector(3 downto 0);
   signal rfsm_i, rfsm_next_i : RFSM_T;
   constant rfsm_dec_c : RFSM_DEC_T := (OBTAIN_FULL_BUFFER => x"1", WAIT_WHILE_STOP => x"2", COPY => x"3", COMPLETE => x"4", DELAY_WHILE_STOP => x"5", PADDING => x"6");
   
   signal delay_counter_i : integer range 0 to 15;
   signal reset_delay_counter_i : std_logic;

   signal transmit_length_i : integer range 0 to 63;
   
begin
   WPROC: process is
   begin
      wait until rising_edge(CLK_IN);
      
      fifo_enqueue_i <= "00";
      fifo_set_filled_i <= "00";
      PACKER_STOP_OUT <= '0';
      
      if RESET_IN='1' then
         wfsm_i <= OBTAIN_FREE_BUFFER;
        
      else
         case (wfsm_i) is
            when OBTAIN_FREE_BUFFER =>
               if fifo_get_filled_i(0) = '0' then
                  write_fifo_i <= 0;
                  wfsm_i <= WAIT_FOR_START;
               elsif fifo_get_filled_i(1) = '0' then
                  write_fifo_i <= 1;
                  wfsm_i <= WAIT_FOR_START;
               else
                  PACKER_STOP_OUT <= '1';
               end if;
               
            when WAIT_FOR_START =>
               if PACKER_START_IN='1' then
                  fifo_enqueue_i(write_fifo_i) <= '1';
                  wfsm_i <= WAIT_FOR_END;
               end if;
               
               
            when WAIT_FOR_END =>
               fifo_enqueue_i(write_fifo_i) <= '1';
               if PACKER_END_IN='1' then
                  fifo_set_filled_i(write_fifo_i) <= '1';
                  wfsm_i <= COMPLETE;
               end if;
                  
            when COMPLETE =>
               PACKER_STOP_OUT <= '1';            
               wfsm_i <= OBTAIN_FREE_BUFFER;
            
         end case;
      end if;
   end process;

   RSYNC: process is
   begin 
      wait until rising_edge(CLK_IN);
      
      if RESET_IN='1' then 
         rfsm_i <= OBTAIN_FULL_BUFFER;
      else
         rfsm_i <= rfsm_next_i;
      end if;
      
      if rfsm_next_i = OBTAIN_FULL_BUFFER then
         transmit_length_i <= 0;
      elsif rfsm_next_i = COPY or rfsm_next_i = PADDING then
         transmit_length_i <= transmit_length_i + 1;
      end if;
      
      if CBMNET_STOP_IN='1' then
         delay_counter_i <= 7;
      elsif delay_counter_i /= 0 then
         delay_counter_i <= delay_counter_i - 1;
      end if;
      
      read_fifo_i <= read_fifo_next_i;
   end process;
   
   RASYNC: process(rfsm_i, fifo_get_filled_i, fifo_last_i, CBMNET_STOP_IN) is
   begin
      CBMNET_START_OUT <= '0';
      CBMNET_END_OUT   <= '0';

      fifo_deq_i <= '0';
      rfsm_next_i <= rfsm_i;
      read_fifo_next_i <= read_fifo_i;
      fifo_empty_i <= "00";
      
      case(rfsm_i) is
         when OBTAIN_FULL_BUFFER =>
            if fifo_get_filled_i(0) = '1' then
               read_fifo_next_i <= 0;
               rfsm_next_i <= WAIT_WHILE_STOP;
            elsif fifo_get_filled_i(1) = '1' then
               read_fifo_next_i <= 1;
               rfsm_next_i <= WAIT_WHILE_STOP;
            end if;
            
         when DELAY_WHILE_STOP =>
            if delay_counter_i = 0 then
               rfsm_next_i <= WAIT_WHILE_STOP;
            end if;
            
         when WAIT_WHILE_STOP =>
            CBMNET_START_OUT <= '1';
            if CBMNET_STOP_IN='0' then
               fifo_deq_i <= '1';
               rfsm_next_i <= COPY;
            end if;
            
         when COPY =>
            fifo_deq_i <= '1';
            if fifo_last_i(read_fifo_i)='1' then
               if transmit_length_i < 3 then
                  rfsm_next_i <= PADDING;
               else
                  CBMNET_END_OUT <= '1';
                  rfsm_next_i <= COMPLETE;
               end if;
            end if;
         
         when PADDING =>
            if transmit_length_i >= 3 then
               CBMNET_END_OUT <= '1';
               rfsm_next_i <= COMPLETE;
            end if;
            
         
         when others =>
            fifo_empty_i(read_fifo_i) <= '1';
            rfsm_next_i <= OBTAIN_FULL_BUFFER;
      end case;
   end process;
   
   -- fifo multiplexer
   fifo_dequeue_i <= "0" & fifo_deq_i when read_fifo_i=0 else fifo_deq_i&"0";   
   CBMNET_DATA_OUT <= fifo_read_data_i(read_fifo_i*16 + 15 downto read_fifo_i*16);

   THE_FIFO_0: CBMNET_READOUT_TX_FIFO
   port map (
      CLK_IN => CLK_IN, -- in std_logic;
      RESET_IN => RESET_IN, -- in std_logic;
      EMPTY_IN => fifo_empty_i(0), -- in std_logic;   -- identical to reset_in
      
      DATA_IN  => fifo_write_data_i, -- in  std_logic_vector(15 downto 0);
      DATA_OUT => fifo_read_data_i(0*16 + 15 downto 0*16), -- out std_logic_vector(15 downto 0);
      
      ENQUEUE_IN => fifo_enqueue_i(0), -- in std_logic;
      DEQUEUE_IN => fifo_dequeue_i(0), -- in std_logic;
      
      LAST_OUT => fifo_last_i(0), -- out std_logic;
      
      FILLED_IN => fifo_set_filled_i(0), -- in std_logic;
      FILLED_OUT => fifo_get_filled_i(0) -- out std_logic;
   );
   
   THE_FIFO_1: CBMNET_READOUT_TX_FIFO
   port map (
      CLK_IN => CLK_IN, -- in std_logic;
      RESET_IN => RESET_IN, -- in std_logic;
      EMPTY_IN => fifo_empty_i(1), -- in std_logic;   -- identical to reset_in
      
      DATA_IN  => fifo_write_data_i, -- in  std_logic_vector(15 downto 0);
      DATA_OUT => fifo_read_data_i(1*16 + 15 downto 1*16), -- out std_logic_vector(15 downto 0);
      
      ENQUEUE_IN => fifo_enqueue_i(1), -- in std_logic;
      DEQUEUE_IN => fifo_dequeue_i(1), -- in std_logic;
      
      LAST_OUT => fifo_last_i(1), -- out std_logic;
      
      FILLED_IN => fifo_set_filled_i(1), -- in std_logic;
      FILLED_OUT => fifo_get_filled_i(1) -- out std_logic;
   );
   
   fifo_write_data_i <= PACKER_DATA_IN when rising_edge(CLK_IN);
   
   DEBUG_OUT( 3 downto  0) <= STD_LOGIC_VECTOR(TO_UNSIGNED(write_fifo_i, 4));
   DEBUG_OUT( 7 downto  4) <= STD_LOGIC_VECTOR(TO_UNSIGNED(read_fifo_i,  4));
   DEBUG_OUT(11 downto  8) <= wfsm_dec_c(wfsm_i);
   DEBUG_OUT(15 downto 12) <= rfsm_dec_c(rfsm_i);
   DEBUG_OUT(19 downto 16) <= fifo_get_filled_i(0) & fifo_last_i(0) & fifo_enqueue_i(0) & fifo_dequeue_i(0);
   DEBUG_OUT(23 downto 20) <= fifo_get_filled_i(1) & fifo_last_i(1) & fifo_enqueue_i(1) & fifo_dequeue_i(1);

end architecture;