LIBRARY IEEE;
   USE IEEE.std_logic_1164.ALL;
   USE IEEE.numeric_std.all;

library work;
   use work.trb_net_std.all;
   use work.trb_net_components.all;
--   use work.med_sync_define.all;
   use work.cbmnet_interface_pkg.all;
   use work.cbmnet_phy_pkg.all;

entity CBMNET_PHY_RX_GEAR is
   generic(
      IS_SYNC_SLAVE   : integer := c_NO       --select slave mode
   );
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
      DEBUG_OUT   : out std_logic_vector(31 downto 0) := (others => '0')
   );
end entity;

architecture CBMNET_PHY_RX_GEAR_ARCH of CBMNET_PHY_RX_GEAR is
--    attribute HGROUP : string;
--    attribute HGROUP of CBMNET_PHY_RX_GEAR_ARCH : architecture  is "cbmnet_phy_rx_gear";


   type FSM_STATES_T is (FSM_START, FSM_WAIT_FOR_LOCK, FSM_LOCK_WAIT1, FSM_LOCK_WAIT2, FSM_LOCK_WAIT3, FSM_RESET, FSM_LOCKED);
   signal fsm_i : FSM_STATES_T;
   signal fsm_state_i : std_logic_vector(3 downto 0);
   
   signal delay_clock_i : std_logic;
   
   signal indi_alignment_i    : std_logic;
   signal indi_misalignment_i : std_logic;
   
   signal data_delay_i   : std_logic_vector(8 downto 0);
   signal data_out_buf250_i : std_logic_vector(17 downto 0);
   signal data_out_crs125_i : std_logic_vector(17 downto 0);
   signal data_out_buf125_i : std_logic_vector(17 downto 0);
   signal clk_125_i : std_logic;
   
   signal reset_timer_i : std_logic;
   signal timeout_i : std_logic;
   
   signal data_in_buf_i : std_logic_vector( 8 downto 0); 
   
   signal delay_clock_buf_i : std_logic;
   signal delay_clock_crs_i : std_logic;
   signal last_delay_clock_i : std_logic := '0';
   signal word_idx_i : std_logic := '0';   
begin

-- FSM sync part
   process is begin
      wait until rising_edge(clk_125_i);

      SERDES_RESET_OUT <= '0';
      RESET_OUT <= '1';
      reset_timer_i <= '0';
      delay_clock_i <= '0';
      fsm_state_i <= x"0";

      
      if PCS_READY_IN = '0' then
         fsm_i <= FSM_START;
         
      else
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
                  -- we're off by one 8+1 word. just wait a single 250 MHz clock cycle
                  delay_clock_i <= '1';
                  fsm_i <= FSM_LOCK_WAIT1;   -- ensure we only have a single delay clock cycle
               
               elsif timeout_i = '1' then
                  fsm_i <= FSM_RESET;
                  
               end if;
               
            when FSM_LOCK_WAIT1 =>
               fsm_state_i <= x"7";
               fsm_i <= FSM_LOCK_WAIT2;

            when FSM_LOCK_WAIT2 =>
               fsm_state_i <= x"7";
               fsm_i <= FSM_LOCK_WAIT3;

            when FSM_LOCK_WAIT3 =>
               fsm_state_i <= x"7";
               fsm_i <= FSM_WAIT_FOR_LOCK;
               
            when FSM_LOCKED =>
               fsm_state_i <= x"2";
               RESET_OUT <= '0';
               
               if RM_RESET_IN = '1' then
                  fsm_i <= FSM_RESET;
               
               elsif indi_misalignment_i = '1' then
                  -- in this state we should already have a stable and correct lock. 
                  -- if we, however, detect a missalignment, something is terribly wrong.
                  -- in this case, will perform a resychronisation
                  
                  fsm_i <= FSM_RESET;
               end if;
            
            
            when FSM_RESET =>
               fsm_state_i <= x"3";
               SERDES_RESET_OUT <= '1';
            
         end case;
      end if;
   end process;
   
-- Timeout (approx. 4ms)
   proc_timeout: process is 
      variable timer_v : unsigned(20 downto 0) := (others => '0');
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
   THE_DELAY_SYNC: signal_sync 
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => '0',
      CLK0 => clk_125_i,
      CLK1 => CLK_250_IN,
      D_IN(0) => delay_clock_i,
      D_OUT(0) => delay_clock_buf_i
   );
   
   proc_ctrl_gear: process
   begin
      wait until rising_edge(CLK_250_IN);

      if not (delay_clock_buf_i = '1' and last_delay_clock_i = '0') then -- or PCS_READY_IN='0' then
         word_idx_i <= not word_idx_i;
      end if;
      
      last_delay_clock_i <= delay_clock_buf_i;
   end process;
   
   data_in_buf_i <= DATA_IN when rising_edge(CLK_250_IN);

   proc_gear: process
   begin
      wait until rising_edge(CLK_250_IN);

      if word_idx_i = '0' then
         data_delay_i <= data_in_buf_i;
         clk_125_i <= '1';
      else
         data_out_buf250_i <=  data_in_buf_i(8) & data_delay_i(8)  & data_in_buf_i(7 downto 0) & data_delay_i(7 downto 0);
         clk_125_i <= '0';
      end if;      

   end process;

   -- meta stabilitiy should not be a problem at this point, as the slower clock is direved from the driving faster clock, but be to be sure ...
   THE_DATA_SYNC: signal_sync 
   generic map (WIDTH => 18, DEPTH => 3)
   port map (
      RESET => '0',
      CLK0 => CLK_250_IN,
      CLK1 => clk_125_i,
      D_IN => data_out_buf250_i,
      D_OUT => data_out_buf125_i
   );
   
   DATA_OUT    <= data_out_buf125_i;
   CLK_125_OUT <= clk_125_i;
   
   DEBUG_OUT(3 downto 0) <= STD_LOGIC_VECTOR(fsm_state_i);
   DEBUG_OUT(5) <= indi_alignment_i;
   DEBUG_OUT(6) <= indi_misalignment_i;
   
-- Detect Indications for correct or wrong alignment   
   indi_alignment_i <= '1' when data_out_buf125_i(17 downto 16) = "01" and data_out_buf125_i(15 downto 8) = x"00" and
      (data_out_buf125_i(7 downto 0) = CBMNET_READY_CHAR0 or data_out_buf125_i(7 downto 0) = CBMNET_READY_CHAR1 or data_out_buf125_i(7 downto 0) = CBMNET_ALIGN_CHAR) else '0';
   
   indi_misalignment_i <= '1' when data_out_buf125_i(17 downto 16) = "10" and data_out_buf125_i(7 downto 0) = x"00" and
      (data_out_buf125_i(15 downto 8) = CBMNET_READY_CHAR0 or data_out_buf125_i(15 downto 8) = CBMNET_READY_CHAR1 or data_out_buf125_i(15 downto 8) = CBMNET_ALIGN_CHAR) else '0';
   
end architecture CBMNET_PHY_RX_GEAR_ARCH;  