LIBRARY IEEE;
   USE IEEE.std_logic_1164.ALL;
   USE IEEE.numeric_std.all;

library work;
   use work.trb_net_std.all;
   use work.trb_net_components.all;
   use work.med_sync_define.all;
   use work.cbmnet_interface_pkg.all;
   use work.cbmnet_phy_pkg.all;

entity CBMNET_PHY_TX_GEAR is
   generic (
      IS_SYNC_SLAVE : integer range 0 to 1 := c_YES
   );
   port (
   -- SERDES PORT
      CLK_250_IN  : in std_logic;
      CLK_TX_FULL_IN : in std_logic;
      CLK_125_IN  : in std_logic;
      CLK_125_OUT : out std_logic;
      
      RESET_IN    : in std_logic;
      ALLOW_RELOCK_IN : in std_logic;
      
      DATA_IN     : in std_logic_vector(17 downto 0);
      DATA_OUT    : out std_logic_vector(8 downto 0);
      
      TX_READY_OUT: out std_logic;
      
      DEBUG_OUT   : out std_logic_vector(31 downto 0)
   );
end entity;

architecture CBMNET_PHY_TX_GEAR_ARCH of CBMNET_PHY_TX_GEAR is
--    attribute HGROUP : string;
--    attribute HGROUP of CBMNET_PHY_TX_GEAR_ARCH : architecture  is "cbmnet_phy_tx_gear";

   type   FSM_STATES is (FSM_LOCKING, FSM_HIGH, FSM_LOW);
   signal fsm_i : FSM_STATES;
   
   signal reset_i, reset_delay_i : std_logic;
   
   signal data_in_buf250_i : std_logic_vector(17 downto 0);
   
   signal delay_data_i : std_logic_vector(8 downto 0);
   
   signal clk_125_xfer_i     : std_logic := '0';
   signal clk_125_xfer_buf_i : std_logic := '0';
   signal clk_125_xfer_del_i : std_logic := '0';
   
   signal delay_counter_i : unsigned(15 downto 0);
begin
   process is begin
      wait until rising_edge(CLK_250_IN);
      
      clk_125_xfer_del_i <= clk_125_xfer_buf_i;
      CLK_125_OUT <= '0';
      
      DATA_OUT <= delay_data_i;
      
      case fsm_i is
         when FSM_HIGH =>
            CLK_125_OUT <= '1';
            
            delay_data_i <= data_in_buf250_i(17) & data_in_buf250_i(15 downto 8);
            DATA_OUT     <= data_in_buf250_i(16) & data_in_buf250_i( 7 downto 0);
            fsm_i <= FSM_LOW;
           
         when FSM_LOW =>
            fsm_i <= FSM_HIGH;
            
         when others =>
            if clk_125_xfer_del_i = '0' and clk_125_xfer_buf_i = '1' then
               fsm_i <= FSM_HIGH;
            end if;
      end case;
      
      reset_delay_i <= reset_i;
      
      if reset_i = '1' and reset_delay_i='1' then
         fsm_i <= FSM_LOCKING;
      end if;
   end process;
   
   TX_READY_OUT <= not RESET_IN;

   THE_DATA_SYNC: signal_sync 
   generic map (WIDTH => 18, DEPTH => 3)
   port map (
      RESET => RESET_IN,
      CLK0 => CLK_125_IN,
      CLK1 => CLK_250_IN,
      D_IN => DATA_IN,
      D_OUT => data_in_buf250_i
   );
   
   THE_CLK_SYNC: signal_sync 
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => RESET_IN,
      CLK0 => CLK_250_IN,
      CLK1 => CLK_250_IN,
      D_IN(0) => CLK_125_IN,
      D_OUT(0) => clk_125_xfer_buf_i
   );
   
   THE_RESET_SYNC: signal_sync 
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => RESET_IN,
      CLK0 => CLK_125_IN,
      CLK1 => CLK_250_IN,
      D_IN(0) => RESET_IN,
      D_OUT(0) => reset_i
   );
   
   DEBUG_OUT <= (others => '0'); -- x"0000" & STD_LOGIC_VECTOR( delay_counter_i );
end architecture CBMNET_PHY_TX_GEAR_ARCH;