library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.cbmnet_interface_pkg.all;

entity tb_cbmnet_fifotx is
end tb_cbmnet_fifotx;

architecture TB of tb_cbmnet_fifotx is
   constant ADDR_WIDTH : positive := 16;
   constant WATERMARK  : positive := 2;

-- write port
   signal WCLK_IN   : std_logic := '0'; -- not faster than rclk_in
   signal WRESET_IN : std_logic := '0';
   
   signal WADDR_STORE_IN   : std_logic := '0';
   signal WADDR_RESTORE_IN : std_logic := '0';
   
   signal WDATA_IN    : std_logic_vector(17 downto 0);
   signal WENQUEUE_IN : std_logic:= '0';
   signal WPACKET_COMPLETE_IN : std_logic:= '0';
   
   signal WALMOST_FULL_OUT : std_logic;
   signal WFULL_OUT        : std_logic;
   
   -- read port
   signal RCLK_IN   : std_logic := '0';
   signal RRESET_IN : std_logic:= '0';  -- has to active at least two clocks AFTER (or while) write port was (is being) initialised
   
   signal RDATA_OUT   : std_logic_vector(17 downto 0);
   signal RDEQUEUE_IN : std_logic:= '0';
   
   signal RPACKET_COMPLETE_OUT : std_logic;   -- atleast one packet is completed fifo
   signal RPACKET_COMPLETE_ACK_IN : std_logic:= '0'; -- mark one event as dealt with (effectively decrease number of completed packets by one)

   signal CBMNET_STOP_IN, CBMNET_START_OUT, CBMNET_END_OUT : std_logic := '0';
   signal CBMNET_DATA_OUT : std_logic_vector(15 downto 0);
   
begin
   WCLK_IN <= not WCLK_IN after 5 ns;
   RCLK_IN <= not RCLK_IN after 4 ns;

   WPROC: process is
      variable length : integer range 0 to 1024;
   begin
      WDATA_IN <= (others => '0');
      
      WRESET_IN <= '1'; wait for 20 ns; wait until rising_edge(WCLK_IN);
      WRESET_IN <= '0'; wait until rising_edge(WCLK_IN);
      
      WENQUEUE_IN <= '1';
      for j in 0 to 10 loop
         length := 100 + j * 50;
      
         WDATA_IN(15 downto 0) <= x"0000";
         wait until rising_edge(WCLK_IN);
         WDATA_IN(15 downto 0) <= STD_LOGIC_VECTOR(TO_UNSIGNED(length + 4, 16)) ;
         wait until rising_edge(WCLK_IN);
      
         for i in 1 to length / 2 loop
            WDATA_IN(15 downto 0) <= STD_LOGIC_VECTOR( TO_UNSIGNED(j, 8) ) &  STD_LOGIC_VECTOR ( TO_UNSIGNED(i, 8) );
            WPACKET_COMPLETE_IN <= '0';
            if i = length / 2 then
               WPACKET_COMPLETE_IN <= '1';
            end if;
            wait until rising_edge(WCLK_IN);
         end loop;
         WPACKET_COMPLETE_IN <= '0';

      end loop;

      
      wait;
   end process;
   
   RPROC: process is
   begin
      RRESET_IN <= '1';
      wait for 50 ns;
      RRESET_IN <= '0';
      
      wait;
   end process;
   
   process is begin
      wait until rising_edge(CBMNET_END_OUT);
      CBMNET_STOP_IN <= '1';
      wait for 32 ns;
      CBMNET_STOP_IN <= '0';
   end process;
   
   FIFO: cbmnet_readout_fifo 
   generic map (
      ADDR_WIDTH => ADDR_WIDTH,
      WATERMARK  => WATERMARK
   ) port map (
   -- write port
      WCLK_IN => WCLK_IN,
      WRESET_IN => WRESET_IN,
            
      WADDR_STORE_IN => WADDR_STORE_IN,
      WADDR_RESTORE_IN => WADDR_RESTORE_IN,
            
      WDATA_IN => WDATA_IN,
      WENQUEUE_IN => WENQUEUE_IN,
      WPACKET_COMPLETE_IN => WPACKET_COMPLETE_IN,
            
      WALMOST_FULL_OUT => WALMOST_FULL_OUT,
      WFULL_OUT => WFULL_OUT,
         
   -- read port
      RCLK_IN => RCLK_IN,
      RRESET_IN => RRESET_IN,
            
      RDATA_OUT => RDATA_OUT,
      RDEQUEUE_IN => RDEQUEUE_IN,
            
      RPACKET_COMPLETE_OUT => RPACKET_COMPLETE_OUT,
      RPACKET_COMPLETE_ACK_IN => RPACKET_COMPLETE_ACK_IN
   );
   
   TX_FSM: cbmnet_readout_tx_fsm port map (
      CLK_IN   => RCLK_IN,
      RESET_IN => RRESET_IN,

      -- fifo 
      FIFO_DATA_IN   => RDATA_OUT(15 downto 0),
      FIFO_DEQUEUE_OUT => RDEQUEUE_IN,
      FIFO_PACKET_COMPLETE_IN => RPACKET_COMPLETE_OUT,
      FIFO_PACKET_COMPLETE_ACK_OUT => RPACKET_COMPLETE_ACK_IN,

      -- cbmnet
      CBMNET_STOP_IN   => CBMNET_STOP_IN,
      CBMNET_START_OUT => CBMNET_START_OUT,
      CBMNET_END_OUT   => CBMNET_END_OUT,
      CBMNET_DATA_OUT  => CBMNET_DATA_OUT
   );
end architecture;