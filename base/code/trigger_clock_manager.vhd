library IEEE;
   use IEEE.STD_LOGIC_1164.ALL;
   use IEEE.NUMERIC_STD.ALL;
   
library work;
   use work.trb_net_components.all;
   use work.trb_net_std.all;
   use work.config.all;

entity trigger_clock_manager is
   port (
      TRB_CLK_IN   : in std_logic;
      INT_CLK_IN   : in std_logic;  -- dont care which clock, but not faster than TRB_CLK_IN

      RESET_IN : in std_logic;

      -- only single register, so no address
      REGIO_ADDRESS_IN               : in  std_logic_vector( 1 downto 0);
      REGIO_DATA_IN                  : in  std_logic_vector(31 downto 0);
      REGIO_READ_ENABLE_IN           : in  std_logic;
      REGIO_WRITE_ENABLE_IN          : in  std_logic;
      REGIO_DATA_OUT                 : out std_logic_vector(31 downto 0);
      REGIO_DATAREADY_OUT            : out std_logic;
      REGIO_WRITE_ACK_OUT            : out std_logic;
      REGIO_UNKNOWN_ADDRESS_OUT      : out std_logic;
      
      RESET_OUT     : out std_logic;
      TC_SELECT_OUT : out std_logic_vector(31 downto 0)
   );
end entity;

architecture RTL of trigger_clock_manager is
   constant USE_EXTERNAL_CLOCK_std : std_logic := std_logic_vector(to_unsigned(USE_EXTERNAL_CLOCK,1))(0);

   type REGIO_FSM_STATES_T is (READY, WAIT_FOR_ACK, WAIT_WHILE_ACK);
   signal regio_fsm_i : REGIO_FSM_STATES_T;
   signal regio_fsm_code_i : std_logic_vector(3 downto 0);
   
   signal regio_tc_select_i : std_logic_vector(31 downto 0);
   signal regio_request_reset_i : std_logic;
   signal regio_write_strobe_i : std_logic;
   
   type INT_FSM_STATES_T is (WAIT_FOR_STROBE, WAIT_WHILE_STROBE, WAIT_COUNTER, ISSUE_RESET);
   signal int_fsm_i : INT_FSM_STATES_T := WAIT_FOR_STROBE;
   signal int_fsm_code_i : std_logic_vector(3 downto 0);

   
   signal int_write_ack_i : std_logic;
   signal int_from_regio_write_strobe_buf_i : std_logic;
   signal int_from_regio_write_strobe_i : std_logic;
   signal int_from_regio_write_strobe_delay_i : std_logic;
  
   signal int_tc_select_i : std_logic_vector(31 downto 0) := (8 => USE_EXTERNAL_CLOCK_std, others => '0');
   
-- syncronised signals   
   signal regio_from_int_write_ack_buf_i : std_logic;
   signal regio_from_int_write_ack_i : std_logic;
   
   signal regio_from_int_fsm_code_buf_i : std_logic_vector(3 downto 0);
   signal regio_from_int_fsm_code_i     : std_logic_vector(3 downto 0);
   
   signal regio_from_int_tc_select_buf_i : std_logic_vector(31 downto 0);
   signal regio_from_int_tc_select_i : std_logic_vector(31 downto 0);
begin
   int_fsm_proc: process is
      variable counter_v : integer range 0 to 2047;
   begin
      wait until rising_edge(INT_CLK_IN);

      RESET_OUT <= '0';
      int_write_ack_i <= '0';
      
      case int_fsm_i is
         when WAIT_FOR_STROBE =>
            int_fsm_code_i <= x"1";
            if int_from_regio_write_strobe_i = '1' and int_from_regio_write_strobe_delay_i = '1' then
               int_tc_select_i <= regio_tc_select_i; -- no sync necessary, as already done via strobe !
               int_write_ack_i <= '1';
               counter_v := 2047;
               if regio_request_reset_i = '1' then
                  int_fsm_i <= WAIT_COUNTER;
               else
                  int_fsm_i <= WAIT_WHILE_STROBE;
               end if;
            end if;
         
         when WAIT_WHILE_STROBE =>
            int_fsm_code_i <= x"2";
            int_write_ack_i <= '1';
            
            if int_from_regio_write_strobe_i = '0' then
               int_fsm_i <= WAIT_FOR_STROBE;
            end if;
            
         when WAIT_COUNTER =>
            int_fsm_code_i <= x"3";         
            if counter_v = 0 then
               int_fsm_i <= ISSUE_RESET;
            end if;
            
            counter_v := counter_v - 1;
            
         when ISSUE_RESET =>
            int_fsm_code_i <= x"4";         
            RESET_OUT <= '1';
            int_fsm_i <= WAIT_FOR_STROBE;
            
      end case;
   end process;
            
   TC_SELECT_OUT <= int_tc_select_i when rising_edge(INT_CLK_IN);

   regio_fsm_proc: process is
      variable addr : integer;
   begin
      wait until rising_edge(TRB_CLK_IN);

      REGIO_UNKNOWN_ADDRESS_OUT <= '0';
      REGIO_DATA_OUT      <= regio_from_int_tc_select_i;
      REGIO_WRITE_ACK_OUT <= '0';
      
      regio_write_strobe_i <= '0';
      
      addr := to_integer(UNSIGNED(REGIO_ADDRESS_IN));
      
      if RESET_IN='1' then
         regio_fsm_i <= READY;
         regio_request_reset_i <= '0';
         regio_fsm_code_i <= x"1";
         
      else
         case regio_fsm_i is
            -- state machine ensures, that no update happens, while the fsm running on the internal fsm is blocked
            when READY =>
               regio_fsm_code_i <= x"1";
               if REGIO_WRITE_ENABLE_IN='1' and addr=0 then
                  regio_tc_select_i <= REGIO_DATA_IN(31 downto 0);
                  regio_fsm_i <= WAIT_FOR_ACK;
                  REGIO_WRITE_ACK_OUT <= '1';
               end if;
            
            when WAIT_FOR_ACK =>
               regio_fsm_code_i <= x"2";
               regio_write_strobe_i <= '1';
               if regio_from_int_write_ack_i = '1' then
                  regio_fsm_i <= WAIT_WHILE_ACK;
               end if;
               
            when WAIT_WHILE_ACK =>
               regio_fsm_code_i <= x"3";
               if regio_from_int_write_ack_i = '0' then
                  regio_fsm_i <= READY;
               end if;
               
         end case;
         
         case addr is
            when 0 =>
               REGIO_DATA_OUT <= regio_from_int_tc_select_i;
            
            when 1 =>
               REGIO_DATA_OUT <= (others => '0');
               REGIO_DATA_OUT(31 downto 28) <= regio_from_int_fsm_code_i;
               REGIO_DATA_OUT(27 downto 24) <= regio_fsm_code_i;
               REGIO_DATA_OUT(0) <= regio_request_reset_i;
               
               if REGIO_WRITE_ENABLE_IN = '1' then
                  regio_request_reset_i <= REGIO_DATA_IN(0);
                  REGIO_WRITE_ACK_OUT <= '1';
               end if;
               
            when others =>
               REGIO_UNKNOWN_ADDRESS_OUT <= REGIO_READ_ENABLE_IN or REGIO_WRITE_ENABLE_IN;
               
         end case;
         
      end if;
      
      REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;

   end process;
   
   
   regio_from_int_write_ack_buf_i <= int_write_ack_i when rising_edge(TRB_CLK_IN);
   regio_from_int_write_ack_i     <= regio_from_int_write_ack_buf_i when rising_edge(TRB_CLK_IN);
   
   regio_from_int_fsm_code_buf_i <= int_fsm_code_i when rising_edge(TRB_CLK_IN);
   regio_from_int_fsm_code_i     <= regio_from_int_fsm_code_buf_i when rising_edge(TRB_CLK_IN);

   regio_from_int_tc_select_buf_i <= int_tc_select_i when rising_edge(TRB_CLK_IN);
   regio_from_int_tc_select_i     <= regio_from_int_tc_select_buf_i when rising_edge(TRB_CLK_IN);

end architecture;