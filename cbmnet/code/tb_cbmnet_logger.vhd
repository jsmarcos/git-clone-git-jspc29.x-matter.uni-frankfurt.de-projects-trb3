library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.txt_util.all;

entity TB_CBMNET_LOGGER is
   generic (
      log_file : string
   );
   port (
      CLK_IN : in std_logic;
      RESET_IN : in std_logic;
      LINK_ACTIVE_IN : in std_logic;

      DATA2SEND_IN : std_logic_vector(15 downto 0);
      DATA2SEND_STOP_IN : std_logic;
      DATA2SEND_START_IN : std_logic;
      DATA2SEND_END_IN : std_logic
   );
end entity;

architecture TB of TB_CBMNET_LOGGER is
   file l_file: TEXT open write_mode is log_file;


   type fsm_states_t is (IDLE, SENDING);
   signal fsm_i : fsm_states_t;

   signal word_count_i : integer;

begin
   PROC_RECV: process is
      variable frame_line_v  : line;
   begin
      wait until rising_edge(CLK_IN);
     
      if RESET_IN = '0' and LINK_ACTIVE_IN = '1' then
         case (fsm_i) is
            when IDLE =>
               word_count_i <= 1;
               if DATA2SEND_START_IN = '1' and DATA2SEND_STOP_IN = '0' then
                  fsm_i <= SENDING;
                  write(frame_line_v, string'("DATA("));
                  write(frame_line_v, time'image(now));
                  write(frame_line_v, string'("): "));
                  write(frame_line_v, hstr(DATA2SEND_IN));
               end if;
            
            when SENDING =>
               write(frame_line_v, " " & hstr(DATA2SEND_IN));
               word_count_i <= word_count_i + 1;
            
               if DATA2SEND_END_IN = '1' then
                  writeline(l_file, frame_line_v);
                  --println ("DATA(" & str(word_count_i*2) & ") :" & frame_str_i);
                  fsm_i <= IDLE;
               end if;
      
         end case;
      elsif RESET_IN = '1' then
         fsm_i <= IDLE;
         
      end if;
   end process;

   assert word_count_i <= 32 report "CBMNet frame must not be longer than 64 bytes" severity warning;
   
end architecture;