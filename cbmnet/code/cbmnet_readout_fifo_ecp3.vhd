library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;


entity CBMNET_READOUT_FIFO is
   generic (
      ADDR_WIDTH : positive := 10;
      WATERMARK  : positive := 4
   );

   port (
      -- write port
      WCLK_IN   : in std_logic; -- not faster than rclk_in
      WRESET_IN : in std_logic;
      
      WADDR_STORE_IN   : in std_logic;
      WADDR_RESTORE_IN : in std_logic;
      
      WDATA_IN    : in std_logic_vector(17 downto 0);
      WENQUEUE_IN : in std_logic;
      WPACKET_COMPLETE_IN : in std_logic;
      
      WALMOST_FULL_OUT : out std_logic;
      WFULL_OUT        : out std_logic;
      
      -- read port
      RCLK_IN   : in std_logic;
      RRESET_IN : in std_logic;  -- has to active at least two clocks AFTER (or while) write port was (is being) initialised
      
      RDATA_OUT   : out std_logic_vector(17 downto 0);
      RDEQUEUE_IN : in std_logic;
      
      RPACKET_COMPLETE_OUT : out std_logic;   -- atleast one packet is completed in fifo
      RPACKET_COMPLETE_ACK_IN : in std_logic; -- mark one event as dealt with (effectively decrease number of completed packets by one)
      
      DEBUG_OUT : out std_logic_vector(31 downto 0)
   );
end CBMNET_READOUT_FIFO;

architecture cbmnet_readout_fifo_arch of CBMNET_READOUT_FIFO is
   constant FIFO_NUM_C : positive := 2;
   
   component cbmnet_fifo_18x32k_dp is
      port (
         Data: in  std_logic_vector(17 downto 0); 
         WrClock: in  std_logic; 
         RdClock: in  std_logic; 
         WrEn: in  std_logic; 
         RdEn: in  std_logic; 
         Reset: in  std_logic; 
         RPReset: in  std_logic; 
         Q: out  std_logic_vector(17 downto 0); 
         Empty: out  std_logic; 
         Full: out  std_logic; 
         AlmostFull: out  std_logic
      );
   end component;
   
   
   signal rread_fifo_i, wread_fifo_i, rwrite_fifo_i, wwrite_fifo_i : integer range 0 to FIFO_NUM_C-1;
   
   signal fifo_enqueue_i     : std_logic_vector(FIFO_NUM_C-1 downto 0);
   signal fifo_dequeue_i     : std_logic_vector(FIFO_NUM_C-1 downto 0);
   signal fifo_empty_i       : std_logic_vector(FIFO_NUM_C-1 downto 0);
   signal fifo_full_i        : std_logic_vector(FIFO_NUM_C-1 downto 0);
   signal fifo_almost_full_i : std_logic_vector(FIFO_NUM_C-1 downto 0);
   
   signal fifo_data_i   : std_logic_vector(FIFO_NUM_C*18 - 1 downto 0);
   signal fifo_wcount_i : std_logic_vector(FIFO_NUM_C*16 - 1 downto 0);

   signal fifo_reset_i  : std_logic_vector(FIFO_NUM_C - 1 downto 0);
   signal fifo_rreset_i : std_logic_vector(FIFO_NUM_C - 1 downto 0);
   signal fifo_wreset_i : std_logic_vector(FIFO_NUM_C - 1 downto 0);
   
   signal wfifo_complete_i, rfifo_complete_i  : std_logic_vector(FIFO_NUM_C-1 downto 0);
   
   signal complete_ack_buf_i : std_logic_vector(1 downto 0);
   
   type RFSM_T is (WAIT_FOR_COMPLETED_FIFO, READ_FIRST_WORD, WAIT_FOR_ACK, WAIT_UNTIL_RESET);
   type RFSM_ENC_T is array(RFSM_T) of std_logic_vector(3 downto 0);
   signal rfsm_i : RFSM_T;
   constant rfsm_enc_i : RFSM_ENC_T := (WAIT_FOR_COMPLETED_FIFO => x"1", READ_FIRST_WORD => x"2", WAIT_FOR_ACK => x"3", WAIT_UNTIL_RESET => x"4");
   
   type WFSM_T is (WAIT_FOR_FREE_FIFO, WAIT_FOR_RESET, WAIT_FOR_COMPLETE, COMPLETED);
   type WFSM_ENC_T is array(WFSM_T) of std_logic_vector(3 downto 0);
   signal wfsm_i : WFSM_T;
   constant wfsm_enc_i : WFSM_ENC_T := (WAIT_FOR_FREE_FIFO => x"1", WAIT_FOR_RESET => x"2", WAIT_FOR_COMPLETE => x"3", COMPLETED => x"4");
begin
-- Complete and Reset flags
   RPROC_COMP: process is
   begin
      wait until rising_edge(RCLK_IN);
      
      complete_ack_buf_i <= "0" & complete_ack_buf_i(complete_ack_buf_i'high downto 1);
      
      if RRESET_IN='1' then
         complete_ack_buf_i <= (others => '0');
      
      elsif RPACKET_COMPLETE_ACK_IN='1' or rfsm_i = WAIT_UNTIL_RESET then
         complete_ack_buf_i <= (others => '1');
         
      end if;
   end process;

   WPROC_COMP: process is
      variable last_v : std_logic;
   begin
      wait until rising_edge(WCLK_IN);
      
      fifo_reset_i <= (others => '0');
      if complete_ack_buf_i(0) = '1' then
         fifo_reset_i(wread_fifo_i) <= '1';
      end if;
      last_v := complete_ack_buf_i(0);
      
      if WADDR_RESTORE_IN='1' and wfsm_i = WAIT_FOR_COMPLETE then
         fifo_reset_i(wwrite_fifo_i) <= '1';
      end if;
   end process;
   
   WPROC_RESET: process is
   begin
      wait until rising_edge(WCLK_IN);
      
      if WRESET_IN='1' then
         fifo_wreset_i <= (others => '1');
         wfifo_complete_i <= (others => '0');
      else
         fifo_wreset_i <= fifo_reset_i;
         wfifo_complete_i <= wfifo_complete_i and (not fifo_reset_i);
      end if;
      
      if WPACKET_COMPLETE_IN='1' then
         wfifo_complete_i(wwrite_fifo_i) <= '1';
      end if;
   end process;
   
   RPROC_RESET: process is
   begin
      wait until rising_edge(RCLK_IN);
      if RRESET_IN='1' then
         fifo_rreset_i <= (others => '1');
      else
         fifo_rreset_i <= fifo_reset_i;
      end if;
   end process;
   
   RFIFO_SELECTION: process is
   begin
      wait until rising_edge(RCLK_IN);
      RPACKET_COMPLETE_OUT <= '0';
      
      if RRESET_IN='1' then
         rfsm_i <= WAIT_FOR_COMPLETED_FIFO;
         
      else
         case(rfsm_i) is
            when WAIT_FOR_COMPLETED_FIFO =>
               for i in 0 to FIFO_NUM_C-1 loop
                  if rfifo_complete_i(i)='1' then
                     rread_fifo_i <= i;
                     rfsm_i <= READ_FIRST_WORD;
                  end if;
               end loop;
            
            when READ_FIRST_WORD =>
               rfsm_i <= WAIT_FOR_ACK;
               
            when WAIT_FOR_ACK =>
               RPACKET_COMPLETE_OUT <= '1';
               if RPACKET_COMPLETE_ACK_IN='1' then
                  RPACKET_COMPLETE_OUT <= '0';
                  rfsm_i <= WAIT_UNTIL_RESET;
               end if;
               
            when WAIT_UNTIL_RESET =>
               if rfifo_complete_i(rread_fifo_i)='0' then
                  rfsm_i <= WAIT_FOR_COMPLETED_FIFO;
               end if;
         end case;
      end if;
   end process;
   
   
   WFIFO_SELECTION: process is
   begin
      wait until rising_edge(WCLK_IN);
      
      if WRESET_IN='1' then
         wfsm_i <= WAIT_FOR_FREE_FIFO;
      else
         case(wfsm_i) is
            when WAIT_FOR_FREE_FIFO =>
               for i in 0 to FIFO_NUM_C-1 loop
                  if wfifo_complete_i(i)='0' then
                     wwrite_fifo_i <= i;
                     wfsm_i <= WAIT_FOR_RESET;
                  end if;
               end loop;
            
            when WAIT_FOR_RESET =>
               if fifo_rreset_i(wwrite_fifo_i) = '0' and fifo_wreset_i(wwrite_fifo_i) = '0' then
                  wfsm_i <= WAIT_FOR_COMPLETE;
               end if;
            
            when WAIT_FOR_COMPLETE =>
               if WPACKET_COMPLETE_IN='1' then
                  wfsm_i <= COMPLETED;
               end if;
               
            when COMPLETED =>
               wfsm_i <= WAIT_FOR_FREE_FIFO;
            
         end case;
      end if;
   end process;
   
   assert(not (wfsm_i = WAIT_FOR_COMPLETE and rfsm_i = WAIT_FOR_ACK and rread_fifo_i = wwrite_fifo_i));
   
   
   wread_fifo_i <= rread_fifo_i when rising_edge(WCLK_IN);
   rwrite_fifo_i <= wwrite_fifo_i when rising_edge(RCLK_IN);
   rfifo_complete_i <= wfifo_complete_i when rising_edge(RCLK_IN);
   

-- READ PORT mux and decoder   
   RDATA_OUT <= fifo_data_i(17+ 18*rread_fifo_i downto 18*rread_fifo_i); -- when rising_edge(RCLK_IN);
   PROC_DEQUEUE: process(rread_fifo_i, RDEQUEUE_IN, rfsm_i) is
   begin
      fifo_dequeue_i <= (others => '0');
      if RDEQUEUE_IN='1' or rfsm_i = READ_FIRST_WORD then
         fifo_dequeue_i(rread_fifo_i) <= '1';
      end if;
   end process;

-- WRITE PORT   
   PROC_WPORT: process(wwrite_fifo_i, wfsm_i, WENQUEUE_IN, fifo_full_i, fifo_almost_full_i) is
   begin
      fifo_enqueue_i <= (others => '0');
      fifo_enqueue_i(wwrite_fifo_i) <= WENQUEUE_IN;
      
      WFULL_OUT <= '0';
      if (wfsm_i /= WAIT_FOR_COMPLETE) or fifo_full_i(wwrite_fifo_i)='1' then
         WFULL_OUT <= '1';
      end if;
      
      WALMOST_FULL_OUT <= '0';
      if (wfsm_i /= WAIT_FOR_COMPLETE) or fifo_almost_full_i(wwrite_fifo_i)='1' then
         WALMOST_FULL_OUT <= '1';
      end if;
   end process;


   GEN_FIFOS: for i in 0 to FIFO_NUM_C-1 generate
      THE_FIFO: cbmnet_fifo_18x32k_dp
      port map (
         Data    => WDATA_IN, -- in  std_logic_vector(17 downto 0); 
         WrClock => WCLK_IN, -- in  std_logic; 
         RdClock => RCLK_IN, -- in  std_logic; 
         WrEn    => fifo_enqueue_i(i), -- in  std_logic; 
         RdEn    => fifo_dequeue_i(i), -- in  std_logic; 
         Reset   => fifo_wreset_i(i), -- in  std_logic; 
         RPReset => fifo_rreset_i(i), -- in  std_logic; 
         Q       => fifo_data_i(17 + 18*i downto 18*i), -- out  std_logic_vector(17 downto 0); 
         Empty   => fifo_empty_i(i), -- out  std_logic; 
         Full    => fifo_full_i(i), -- out  std_logic; 
         AlmostFull => fifo_almost_full_i(i) -- out  std_logic
      );
   end generate;
   
   DEBUG_OUT( 3 downto  0) <= STD_LOGIC_VECTOR(TO_UNSIGNED(wwrite_fifo_i, 4));
   DEBUG_OUT( 7 downto  4) <= STD_LOGIC_VECTOR(TO_UNSIGNED(wread_fifo_i, 4));
   DEBUG_OUT(11 downto  8) <= wfsm_enc_i(wfsm_i);
   DEBUG_OUT(15 downto 12) <= rfsm_enc_i(rfsm_i);
   DEBUG_OUT(19 downto 16) <= "0" & fifo_full_i(0) & fifo_almost_full_i(0) & fifo_empty_i(0);
   DEBUG_OUT(23 downto 20) <= "0" & fifo_full_i(1) & fifo_almost_full_i(1) & fifo_empty_i(1);   
   DEBUG_OUT(27 downto 24) <= "00" & wfifo_complete_i;
   DEBUG_OUT(31 downto 28) <= "00" & fifo_wreset_i;
end architecture;