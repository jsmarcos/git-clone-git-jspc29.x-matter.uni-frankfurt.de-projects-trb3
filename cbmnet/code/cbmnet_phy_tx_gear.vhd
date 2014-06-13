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
   type   FSM_STATES is (FSM_HIGH, FSM_LOW);
   signal fsm_i : FSM_STATES;
   
   signal data_in_buf125_i : std_logic_vector(17 downto 0);
   signal low_data_i : std_logic_vector(8 downto 0);
   
   signal clk_125_xfer_i     : std_logic := '0';
   signal clk_125_xfer_buf_i : std_logic := '0';
   signal clk_125_xfer_del_i : std_logic := '0';
   
   signal delay_counter_i : unsigned(15 downto 0);
begin
   process is begin
      wait until rising_edge(CLK_250_IN);
      
      if RESET_IN='1' then
         delay_counter_i <= TO_UNSIGNED(0,16);
      end if;
      
      clk_125_xfer_buf_i <= clk_125_xfer_i;
      clk_125_xfer_del_i <= clk_125_xfer_buf_i;
      CLK_125_OUT <= '0';
      
      case fsm_i is
         when FSM_HIGH =>
            CLK_125_OUT <= '1';
            
            DATA_OUT   <= data_in_buf125_i(17) & data_in_buf125_i(15 downto 8);
            low_data_i <= data_in_buf125_i(16) & data_in_buf125_i( 7 downto 0);
            fsm_i <= FSM_LOW;

            if clk_125_xfer_buf_i /= clk_125_xfer_del_i and ALLOW_RELOCK_IN = '1' then
               fsm_i <= FSM_HIGH;
               delay_counter_i <= delay_counter_i + 1;
            end if;

            
         when others =>
            DATA_OUT <= low_data_i;
            fsm_i <= FSM_HIGH;
      end case;
   end process;
   
   TX_READY_OUT <= not RESET_IN;
   
   process is begin
      wait until rising_edge(CLK_125_IN);
      
      data_in_buf125_i <= DATA_IN;
      clk_125_xfer_i   <= not clk_125_xfer_i;
   end process;
   
   DEBUG_OUT <= x"0000" & STD_LOGIC_VECTOR( delay_counter_i );
end architecture CBMNET_PHY_TX_GEAR_ARCH;