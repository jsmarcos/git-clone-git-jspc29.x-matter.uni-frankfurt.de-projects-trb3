library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.cbmnet_interface_pkg.all;

entity tb_cbmnet_readout_fifo is
end tb_cbmnet_readout_fifo;

architecture TB of tb_cbmnet_readout_fifo is
   constant ADDR_WIDTH : positive := 4;
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

begin
   WCLK_IN <= not WCLK_IN after 5 ns;
   RCLK_IN <= not RCLK_IN after 4 ns;

   WPROC: process is
   begin
      WRESET_IN <= '1'; wait for 20 ns; wait until rising_edge(WCLK_IN);
      WRESET_IN <= '0'; wait until rising_edge(WCLK_IN);
      
      for i in 3*2**ADDR_WIDTH downto 0 loop
         WDATA_IN <= STD_LOGIC_VECTOR(TO_UNSIGNED(i, WDATA_IN'length));
         WENQUEUE_IN <= '1';
         
         WADDR_STORE_IN <= '0';
         if i = 3*2**ADDR_WIDTH - (2**(ADDR_WIDTH-1)) then
            WADDR_STORE_IN <= '1';
         end if;
         WADDR_RESTORE_IN <= '0';
         if i = 2*2**ADDR_WIDTH then
            WADDR_RESTORE_IN <= '1';
         end if;
         
         wait until rising_edge(WCLK_IN);
      end loop;

      WENQUEUE_IN <= '0';

      
      wait;
   end process;
   
   RPROC: process is
   begin
      RRESET_IN <= '1';
      wait for 50 ns;
      RRESET_IN <= '0';
      
      wait for 250 ns;
      
      RDEQUEUE_IN <= '1';
      wait until rising_edge(RCLK_IN);
      wait until rising_edge(RCLK_IN);
      RDEQUEUE_IN <= '0';
      wait until rising_edge(RCLK_IN);

      RRESET_IN <= '1';
      wait until rising_edge(RCLK_IN);
      RRESET_IN <= '0';

      wait until rising_edge(RCLK_IN);
      wait until rising_edge(RCLK_IN);
      wait until rising_edge(RCLK_IN);
      
      RDEQUEUE_IN <= '1';
      
      wait;
   end process;
   
      
      
   


   DUT: cbmnet_readout_fifo 
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
end architecture;