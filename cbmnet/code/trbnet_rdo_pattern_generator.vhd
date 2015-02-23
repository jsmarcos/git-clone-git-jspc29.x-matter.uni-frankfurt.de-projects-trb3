library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity trbnet_rdo_pattern_generator is
   port (
      CLK_IN : in std_logic;
      RESET_IN : in std_logic;
   
      HUB_CTS_NUMBER_OUT           : out  std_logic_vector (15 downto 0);
      HUB_CTS_CODE_OUT             : out  std_logic_vector (7  downto 0);
      HUB_CTS_OUTFORMATION_OUT     : out  std_logic_vector (7  downto 0);
      HUB_CTS_READOUT_TYPE_OUT     : out  std_logic_vector (3  downto 0);
      HUB_CTS_START_READOUT_OUT    : out  std_logic;
      HUB_CTS_READOUT_FINISHED_IN  : in std_logic;  --no more data, end transfer, send TRM
      HUB_CTS_STATUS_BITS_IN       : in std_logic_vector (31 downto 0);
      HUB_FEE_DATA_OUT             : out  std_logic_vector (15 downto 0);
      HUB_FEE_DATAREADY_OUT        : out  std_logic;
      HUB_FEE_READ_IN              : in std_logic;  --must be high when idle, otherwise you will never get a dataready
      HUB_FEE_STATUS_BITS_OUT      : out  std_logic_vector (31 downto 0);
      HUB_FEE_BUSY_OUT             : out  std_logic;      


      REGIO_READ_ENABLE_IN   : in  std_logic; 
      REGIO_WRITE_ENABLE_IN  : in  std_logic; 
      REGIO_DATA_IN          : in  std_logic_vector (31 downto 0);
      REGIO_ADDR_IN          : in  std_logic_vector (15 downto 0);
      REGIO_TIMEOUT_IN       : in  std_logic; 
      REGIO_DATA_OUT         : out  std_logic_vector (31 downto 0);
      REGIO_DATAREADY_OUT    : out  std_logic; 
      REGIO_WRITE_ACK_OUT    : out  std_logic; 
      REGIO_NO_MORE_DATA_OUT : out  std_logic; 
      REGIO_UNKNOWN_ADDR_OUT : out  std_logic
   );
end entity;

architecture trbnet_rdo_pattern_generator_arch of trbnet_rdo_pattern_generator is
   type TRB_FSM_T is (
      IDLE, START_READOUT, START_READOUT_WAIT, FEE_BUSY, 
      SEND_EINF_H, SEND_EINF_L, 
      SEND_LENGTH, SEND_SOURCE, SEND_SOURCE_WAIT, 
      SEND_PAYLOAD_SSEHDR_H, SEND_PAYLOAD_SSEHDR_L,
      SEND_PAYLOAD_RT_H, SEND_PAYLOAD_RT_L, 
      SEND_PAYLOAD_H, SEND_PAYLOAD_L, 
      COMPL_WAIT, COMPL_NOT_BUSY_WAIT, EVT_WAIT
   );
   signal trb_fsm_i : TRB_FSM_T;

   signal send_enabled_i : std_logic;
   
   signal event_id : unsigned(31 downto 0);
   signal event_gap_i : unsigned(31 downto 0);
   signal event_gap_cnt_i : unsigned(31 downto 0);

   signal send_length_min_i  : unsigned(15 downto 0);
   signal send_length_max_i  : unsigned(15 downto 0);
   signal send_length_step_i : unsigned(15 downto 0);
   signal send_length_cnt_i  : unsigned(15 downto 0);

   signal send_counter_i : unsigned(15 downto 0);

begin
   PROC_PGEN_REGIO: process is
      variable address : integer;
   begin
      wait until rising_edge(CLK_IN);
      
      address := to_integer(UNSIGNED(REGIO_ADDR_IN(3 downto 0)));
      
      REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
      REGIO_WRITE_ACK_OUT <= REGIO_WRITE_ENABLE_IN;
      REGIO_UNKNOWN_ADDR_OUT <= '0';
      REGIO_NO_MORE_DATA_OUT <= '0';
      REGIO_DATA_OUT <= (others => '0');
      
      if RESET_IN = '1' then
         send_length_min_i <= x"0010";
         send_length_max_i <= x"0800";
         send_length_step_i <= x"0001";
         send_enabled_i <= '0';
         event_gap_i <= x"00001000";
         
      else
         case address is
            when 0 =>
               REGIO_DATA_OUT(0) <= send_enabled_i;
               
            when 1 => REGIO_DATA_OUT(15 downto 0) <= std_logic_vector(send_length_min_i);
            when 2 => REGIO_DATA_OUT(15 downto 0) <= std_logic_vector(send_length_max_i);
            when 3 => REGIO_DATA_OUT(15 downto 0) <= std_logic_vector(send_length_step_i);
            when 4 => REGIO_DATA_OUT <= std_logic_vector(event_id);
            when 5 => REGIO_DATA_OUT <= std_logic_vector(event_gap_i);
               
            when others => 
               REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN or REGIO_READ_ENABLE_IN;

         end case;
         
         if REGIO_WRITE_ENABLE_IN = '1' then
            case address is
               when 0 => send_enabled_i <= REGIO_DATA_IN(0);
               when 1 => send_length_min_i <= unsigned(REGIO_DATA_IN(15 downto 0));
               when 2 => send_length_max_i <= unsigned(REGIO_DATA_IN(15 downto 0));
               when 3 => send_length_step_i <= unsigned(REGIO_DATA_IN(15 downto 0));
               when 5 => event_gap_i <= unsigned(REGIO_DATA_IN);
                  
               when others => 
                  REGIO_WRITE_ACK_OUT <= '0';

            end case;
         end if;
      end if;
   end process;
   
   
   PROC_TRB_DATA: process is
      variable wait_cnt_v : integer range 0 to 15 := 0;
   begin
      wait until rising_edge(CLK_IN);
      
      HUB_CTS_START_READOUT_OUT <= '1';
      HUB_FEE_BUSY_OUT <= '1';
      HUB_FEE_DATAREADY_OUT <= '0';
      
      if RESET_IN='1' then
         trb_fsm_i <= IDLE;
      else
         case(trb_fsm_i) is
            when IDLE =>
               HUB_CTS_START_READOUT_OUT <= '0';
               HUB_FEE_BUSY_OUT <= '0';
               if send_enabled_i = '1' then
                  trb_fsm_i <= START_READOUT;
               end if;
               
               if send_length_cnt_i < send_length_min_i then
                  send_length_cnt_i <= send_length_min_i;
               else
                  send_length_cnt_i <= send_length_cnt_i + 1;
               end if;
               
            when START_READOUT => 
               if send_length_cnt_i < send_length_min_i or send_length_cnt_i > send_length_max_i then
                  send_length_cnt_i <= send_length_min_i;
               end if;

               trb_fsm_i <= START_READOUT_WAIT;
               wait_cnt_v := 10;
               HUB_FEE_BUSY_OUT <= '0';
               event_id <= event_id + 1;
               
            when START_READOUT_WAIT => 
               if wait_cnt_v = 0 then
                  trb_fsm_i <= FEE_BUSY;
                  wait_cnt_v := 5;
               else
                  wait_cnt_v := wait_cnt_v - 1;
               end if;
               
               HUB_FEE_BUSY_OUT <= '0';
            
            when FEE_BUSY =>
               if wait_cnt_v = 0 then
                  trb_fsm_i <= SEND_EINF_H;
               else
                  wait_cnt_v := wait_cnt_v - 1;
               end if;
               
               HUB_FEE_BUSY_OUT <= '1';
               
            when SEND_EINF_H =>
               HUB_FEE_DATA_OUT <= x"0e" & STD_LOGIC_VECTOR(event_id(23 downto 16));
               HUB_FEE_DATAREADY_OUT <= '1';
               trb_fsm_i <= SEND_EINF_L;
            when SEND_EINF_L =>
               HUB_FEE_DATA_OUT <= std_logic_vector(event_id(15 downto 0));
               HUB_FEE_DATAREADY_OUT <= '1';
               trb_fsm_i <= SEND_LENGTH;
               
            when SEND_LENGTH =>
               HUB_FEE_DATA_OUT <= std_logic_vector(send_length_cnt_i);
               send_counter_i <= send_length_cnt_i;
               HUB_FEE_DATAREADY_OUT <= '1';
               trb_fsm_i <= SEND_SOURCE;
            when SEND_SOURCE =>
               HUB_FEE_DATA_OUT <= x"affe";
               HUB_FEE_DATAREADY_OUT <= '1';
               trb_fsm_i <= SEND_SOURCE_WAIT;

            when SEND_SOURCE_WAIT =>
               trb_fsm_i <= SEND_PAYLOAD_SSEHDR_H;

            when SEND_PAYLOAD_SSEHDR_H =>
               HUB_FEE_DATA_OUT <= std_logic_vector(send_counter_i - 1);
               HUB_FEE_DATAREADY_OUT <= '1';
               trb_fsm_i <= SEND_PAYLOAD_SSEHDR_L;
               
            when SEND_PAYLOAD_SSEHDR_L =>
               HUB_FEE_DATA_OUT <= x"4444";
               HUB_FEE_DATAREADY_OUT <= '1';
               trb_fsm_i <= SEND_PAYLOAD_H;
               send_counter_i <= send_counter_i - 1;
               
               trb_fsm_i <= SEND_PAYLOAD_RT_H;
               
            when SEND_PAYLOAD_RT_H =>
               HUB_FEE_DATA_OUT <= x"dead";
               HUB_FEE_DATAREADY_OUT <= '1';
               trb_fsm_i <= SEND_PAYLOAD_RT_L;
               
            when SEND_PAYLOAD_RT_L =>
               HUB_FEE_DATA_OUT <= x"affe";
               HUB_FEE_DATAREADY_OUT <= '1';
               trb_fsm_i <= SEND_PAYLOAD_H;
               send_counter_i <= send_counter_i - 1;
               
               if send_counter_i = 1 then
                  trb_fsm_i <= COMPL_WAIT;
                  wait_cnt_v := 5;
               end if;
               
            when SEND_PAYLOAD_H =>
               HUB_FEE_DATA_OUT <= x"bb" & std_logic_vector(event_id(7 downto 0));
               HUB_FEE_DATAREADY_OUT <= '1';
               trb_fsm_i <= SEND_PAYLOAD_L;
               
            when SEND_PAYLOAD_L =>
               HUB_FEE_DATA_OUT <= x"c" & std_logic_vector(send_counter_i(11 downto 0));
               HUB_FEE_DATAREADY_OUT <= '1';
               trb_fsm_i <= SEND_PAYLOAD_H;
               send_counter_i <= send_counter_i - 1;
               
               if send_counter_i = 1 then
                  trb_fsm_i <= COMPL_WAIT;
                  wait_cnt_v := 5;
               end if;
               
            when COMPL_WAIT =>
               if wait_cnt_v = 0 then
                  wait_cnt_v := 5;
                  trb_fsm_i <= COMPL_NOT_BUSY_WAIT;
               else
                  wait_cnt_v := wait_cnt_v - 1;
               end if;
               
               HUB_FEE_BUSY_OUT <= '1';

            
            when COMPL_NOT_BUSY_WAIT => 
               HUB_CTS_START_READOUT_OUT <= '0';
               if wait_cnt_v = 0 then
                  trb_fsm_i <= EVT_WAIT;
                  wait_cnt_v := 5;
               else
                  wait_cnt_v := wait_cnt_v - 1;
               end if;
               
               HUB_FEE_BUSY_OUT <= '0';
               event_gap_cnt_i <= (others => '0');
               
               
            when EVT_WAIT =>
               HUB_CTS_START_READOUT_OUT <= '0';
               HUB_FEE_BUSY_OUT <= '0';
               
               event_gap_cnt_i <= event_gap_cnt_i + 1;
               
               if event_gap_cnt_i >= UNSIGNED(event_gap_i) then
                  trb_fsm_i <= IDLE;
               end if;
               
         end case;
      end if;
   end process;
   
end architecture;