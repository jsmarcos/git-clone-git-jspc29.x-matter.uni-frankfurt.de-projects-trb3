LIBRARY IEEE;
   USE IEEE.std_logic_1164.ALL;
   USE IEEE.numeric_std.all;

library work;
--   use work.trb_net_std.all;
--   use work.trb_net_components.all;
--   use work.med_sync_define.all;
   use work.cbmnet_interface_pkg.all;
   use work.cbmnet_phy_pkg.all;

entity CBMNET_PHY_RX_GEAR is
   port (
   -- SERDES PORT
      CLK_250_IN  : in std_logic;
      PCS_READY_IN: in std_logic;
      SERDES_RESET_OUT : out std_logic;
      DATA_IN     : in  std_logic_vector( 8 downto 0);

   -- RM PORT
      RM_RESET_IN : in std_logic;
      CLK_125_OUT : out std_logic;
      RESET_OUT   : out std_logic;
      DATA_OUT    : out std_logic_vector(17 downto 0);
      
   -- DEBUG
      DEBUG_OUT   : out std_logic_vector(15 downto 0) := (others => '0')
   );
end entity;

architecture CBMNET_PHY_RX_GEAR_ARCH of CBMNET_PHY_RX_GEAR is
   type FSM_STATES_T is (FSM_START, FSM_WAIT_FOR_LOCK, FSM_RESET, FSM_LOCKED);
   signal fsm_i : FSM_STATES_T;
   signal fsm_state_i : std_logic_vector(3 downto 0);
   
   signal delay_clock_i : std_logic;
   
   signal indi_alignment_i    : std_logic;
   signal indi_misalignment_i : std_logic;
   
   signal data_delay_i   : std_logic_vector(8 downto 0);
   signal data_out_buf_i : std_logic_vector(17 downto 0);
   signal clk_125_i : std_logic;
   
   signal reset_timer_i : std_logic;
   signal timeout_i : std_logic;
begin
-- FSM sync part
   process is begin
      wait until rising_edge(clk_125_i);
      
      if PCS_READY_IN = '0' then
         fsm_i <= FSM_START;
         
         RESET_OUT <= '1';
         delay_clock_i <= '0';
         fsm_state_i <= x"0";
         
      elsif rising_edge(clk_125_i) then
         SERDES_RESET_OUT <= '0';
         RESET_OUT <= '1';
         reset_timer_i <= '0';
         delay_clock_i <= '0';
         
         case (fsm_i) is
            when FSM_START =>
               fsm_state_i <= x"0";
               reset_timer_i <= '1';
               fsm_i <= FSM_WAIT_FOR_LOCK;
               
            when FSM_WAIT_FOR_LOCK =>
               fsm_state_i <= x"1";
               if indi_alignment_i = '1' then
                  -- already correctly aligned, so just fix current state
                  fsm_i <= FSM_LOCKED;
                  
               elsif indi_misalignment_i = '1' then
                  -- we're off by one word. just wait a single frame
                  delay_clock_i <= '1';
   --               fsm_i <= FSM_LOCKED;
               
               elsif timeout_i = '1' then
                  fsm_i <= FSM_RESET;
                  
               end if;

            when FSM_LOCKED =>
               fsm_state_i <= x"2";
               RESET_OUT <= '0';
               
               if RM_RESET_IN = '1' then
                  fsm_i <= FSM_RESET;
               
               elsif indi_misalignment_i = '1' then
                  -- in this state we should already have a stable and correct lock. 
                  -- if we, however detect a missalignment, something is terribly wrong.
                  -- in this case, will perform a resychronisation
                  
                  fsm_i <= FSM_RESET;
               end if;
            
            
            when FSM_RESET =>
               fsm_state_i <= x"3";
               SERDES_RESET_OUT <= '1';
            
         end case;
      end if;
   end process;
   
-- Timeout (approx. 1ms)
   proc_timeout: process is 
      variable timer_v : unsigned(17 downto 0);
   begin
      wait until rising_edge(clk_125_i);
      
      if reset_timer_i = '1' then
         timer_v := TO_UNSIGNED(0, timer_v'length);
         
      elsif timer_v(timer_v'high) = '0' then
         timer_v := timer_v + TO_UNSIGNED(1,1);
         
      end if;

      timeout_i <= timer_v(timer_v'high);
   end process;

-- Implement the 2:1 gearing and clock down-sampling
   proc_gear: process is
      variable last_delay_clock_v : std_logic := '0';
      variable word_idx_v : std_logic := '0';
   begin
      wait until rising_edge(CLK_250_IN);

      if word_idx_v = '0' then
         data_delay_i <= DATA_IN;
         clk_125_i <= '0';
      else
         data_out_buf_i <= data_delay_i(8) & DATA_IN(8) & data_delay_i(7 downto 0) & DATA_IN(7 downto 0);
         clk_125_i <= '1';
      end if;      

      if not (delay_clock_i = '1' and last_delay_clock_v = '0') then
         word_idx_v := not word_idx_v;
      end if;
      
      last_delay_clock_v := delay_clock_i;
   end process;
   
   DATA_OUT <= data_out_buf_i;
   CLK_125_OUT <= clk_125_i;
   
   DEBUG_OUT(3 downto 0) <= STD_LOGIC_VECTOR(fsm_state_i);
   DEBUG_OUT(4) <= delay_clock_i;
   
-- Detect Indications for correct or wrong alignment   
   indi_alignment_i <= '1' when data_out_buf_i(17 downto 16) = "01" and data_out_buf_i(15 downto 8) = x"00" and
      (data_out_buf_i(7 downto 0) = CBMNET_READY_CHAR0 or data_out_buf_i(7 downto 0) = CBMNET_READY_CHAR1 or data_out_buf_i(7 downto 0) = CBMNET_ALIGN_CHAR) else '0';
   
   indi_misalignment_i <= '1' when data_out_buf_i(17 downto 16) = "10" and data_out_buf_i(7 downto 0) = x"00" and
      (data_out_buf_i(15 downto 8) = CBMNET_READY_CHAR0 or data_out_buf_i(15 downto 8) = CBMNET_READY_CHAR1 or data_out_buf_i(15 downto 8) = CBMNET_ALIGN_CHAR) else '0';
   
end architecture CBMNET_PHY_RX_GEAR_ARCH;  