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
      
      DATA_IN     : in std_logic_vector(17 downto 0);
      DATA_OUT    : out std_logic_vector(8 downto 0);
      
      TX_READY_OUT: out std_logic;
      
      DEBUG_OUT   : out std_logic_vector(31 downto 0)
   );
end entity;

architecture CBMNET_PHY_TX_GEAR_ARCH of CBMNET_PHY_TX_GEAR is
--    attribute HGROUP : string;
--    attribute HGROUP of CBMNET_PHY_TX_GEAR_ARCH : architecture  is "cbmnet_phy_tx_gear";
   attribute syn_hier : string;
   attribute syn_hier of CBMNET_PHY_TX_GEAR_ARCH : architecture is "hard";


   type   FSM_STATES is (FSM_LOCKING, FSM_HIGH, FSM_LOW);
   signal fsm_i : FSM_STATES;
   
   signal reset_i, reset_delay_i : std_logic;
   
   signal data_in_buf250_i : std_logic_vector(17 downto 0);
   
   constant MEM_ADDR_DEPTH : integer := 3;
   type MEM_T is array(0 to 2**MEM_ADDR_DEPTH-1) of std_logic_vector(17 downto 0);
   signal mem_i : MEM_T;
   attribute syn_ramstyle : string;
   attribute syn_ramstyle of mem_i : signal is "registers";

   signal mem_read_ptr_i, mem_write_ptr_i : unsigned(MEM_ADDR_DEPTH-1 downto 0) := (others => '0');
   signal overflow_read_ptr_i, overflow_write_ptr_i : std_logic;
   
   signal mem_sync_i : std_logic;
   signal fsm_locked_i, fsm_locked_slow_i : std_logic;
   
   signal delay_data_i : std_logic_vector(8 downto 0);
begin
   process is begin
      wait until rising_edge(CLK_250_IN);
      
      CLK_125_OUT <= '0';
      
      DATA_OUT <= delay_data_i;
      fsm_locked_i <= '0';
      
      case fsm_i is
         when FSM_HIGH =>
            CLK_125_OUT <= '1';
            delay_data_i <= data_in_buf250_i(17) & data_in_buf250_i(15 downto 8);
            DATA_OUT     <= data_in_buf250_i(16) & data_in_buf250_i( 7 downto 0);
            fsm_locked_i <= '1';
            fsm_i <= FSM_LOW;
           
         when FSM_LOW =>
            fsm_i <= FSM_HIGH;
            data_in_buf250_i <= mem_i(to_integer(mem_write_ptr_i));
            mem_write_ptr_i <= mem_write_ptr_i + TO_UNSIGNED(1,1);
            fsm_locked_i <= '1';
            
         when others =>
            if mem_sync_i = '1' then
               fsm_i <= FSM_LOW;
            end if;
            mem_write_ptr_i <= "110";
      end case;

      if reset_i = '1' and reset_delay_i='1' then
         fsm_i <= FSM_LOCKING;
         mem_write_ptr_i <= "110";
      end if;
      
      reset_delay_i <= reset_i;
   end process;
   
   PROC_MEM125: process is
   begin
      wait until rising_edge(CLK_125_IN);
      mem_i(to_integer(mem_read_ptr_i)) <= DATA_IN;
      mem_read_ptr_i <= mem_read_ptr_i + TO_UNSIGNED(1,1);
   end process;
   
   TX_READY_OUT <= fsm_locked_slow_i and not RESET_IN;

   THE_DATA_SYNC: signal_sync 
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => RESET_IN,
      CLK0 => CLK_125_IN,
      CLK1 => CLK_250_IN,
      D_IN(0)  => overflow_read_ptr_i,
      D_OUT(0) => mem_sync_i
   );

   THE_RESET_SYNC: signal_sync 
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => '0',
      CLK0 => CLK_125_IN,
      CLK1 => CLK_250_IN,
      D_IN(0) => RESET_IN,
      D_OUT(0) => reset_i
   );
   
   THE_LOCKED_SYNC: signal_sync 
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => RESET_IN,
      CLK0 => CLK_250_IN,
      CLK1 => CLK_125_IN,
      D_IN(0) => fsm_locked_i,
      D_OUT(0) => fsm_locked_slow_i
   );
   
   PROC_DEBUG_PTR: process is
      variable delay_read_ptr, buf_read_ptr : unsigned(MEM_ADDR_DEPTH-1 downto 0) := (others => '1');
      variable wait_cntr : unsigned(7 downto 0) := x"00"; -- lower the odds of a meta-stab when sampling over regio
      variable cnt : unsigned(7 downto 0) := x"00";
   begin
      wait until rising_edge(CLK_250_IN);
      
      if wait_cntr = x"00" then
         if delay_read_ptr = buf_read_ptr then
            -- stable, let's compare
            DEBUG_OUT(15 downto 0) <= x"0000";
            DEBUG_OUT(MEM_ADDR_DEPTH-1 downto 0) <= std_logic_vector(buf_read_ptr);
            DEBUG_OUT(MEM_ADDR_DEPTH+3 downto 4) <= std_logic_vector(mem_write_ptr_i);
            DEBUG_OUT(15 downto 8) <= std_logic_vector(cnt);
            wait_cntr := cnt;
            wait_cntr(7) := '1';
            cnt := cnt + TO_UNSIGNED(1,1);
         end if;
      else
         wait_cntr := wait_cntr - TO_UNSIGNED(1,1);
      end if;
   
      delay_read_ptr := buf_read_ptr;
      buf_read_ptr := mem_read_ptr_i;
   end process;
   
   DEBUG_OUT(31 downto 18) <= (others => '0'); -- x"0000" & STD_LOGIC_VECTOR( delay_counter_i );
   
   overflow_read_ptr_i  <= '1' when mem_read_ptr_i  = "000" else '0';
   overflow_write_ptr_i <= '1' when mem_write_ptr_i = "000" else '0';
   DEBUG_OUT(17 downto 16) <= overflow_write_ptr_i & overflow_read_ptr_i;
   
end architecture CBMNET_PHY_TX_GEAR_ARCH;