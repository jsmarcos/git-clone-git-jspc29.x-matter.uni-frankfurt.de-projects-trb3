library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;


entity CBMNET_READOUT_FIFO is
   generic (
      ADDR_WIDTH : positive := 10;
      WATERMARK  : positive := 4
   );

   port (
      -- write port
      WCLK_IN   : in std_logic; -- not faster than rclk_in
      WRESET_IN : in std_logic;
      
      WADDR_STORE_IN   : in std_logic;
      WADDR_RESTORE_IN : in std_logic;
      
      WDATA_IN    : in std_logic_vector(17 downto 0);
      WENQUEUE_IN : in std_logic;
      WPACKET_COMPLETE_IN : in std_logic;
      
      WALMOST_FULL_OUT : out std_logic;
      WFULL_OUT        : out std_logic;
      
      -- read port
      RCLK_IN   : in std_logic;
      RRESET_IN : in std_logic;  -- has to active at least two clocks AFTER (or while) write port was (is being) initialised
      
      RDATA_OUT   : out std_logic_vector(17 downto 0);
      RDEQUEUE_IN : in std_logic;
      
      RPACKET_COMPLETE_OUT : out std_logic;   -- atleast one packet is completed in fifo
      RPACKET_COMPLETE_ACK_IN : in std_logic; -- mark one event as dealt with (effectively decrease number of completed packets by one)
      
      DEBUG_OUT : out std_logic_vector(31 downto 0)
   );
end CBMNET_READOUT_FIFO;

architecture cbmnet_readout_fifo_arch of CBMNET_READOUT_FIFO is
   signal waddr_i, waddr_stored_i, wread_pointer_i, wwords_remaining_i : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
   signal wfull_i, walmost_full_i : std_logic;
   signal wpacket_complete_xchange_i : std_logic_vector(2 downto 0) := (others => '0');
   
   signal raddr_i, raddr_stored_i, rwrite_pointer_i, rpacket_counter_i : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
   signal rpacket_complete_xchange_i : std_logic := '0'; 
   
   type FIFO_MEM_T is array(0 to 2**ADDR_WIDTH-1) of std_logic_vector(15 downto 0);
   signal mem_i : FIFO_MEM_T;
   
   attribute syn_ramstyle : string;
   attribute syn_ramstyle of mem_i : signal is "block_ram";
begin
-- Memory
   MEM_WRITE_PORT: process is
      variable last_full_v : std_logic := '1';
   begin
      wait until rising_edge(WCLK_IN);
      if (wfull_i = '0' ) and WENQUEUE_IN = '1' then
         mem_i(to_integer(waddr_i)) <= WDATA_IN(15 downto 0);
      end if;
      
      if WENQUEUE_IN='1' then
         last_full_v := wfull_i;
      end if;
   end process;

-- Read Port
   raddr_stored_i <= waddr_stored_i when rising_edge(RCLK_IN);
   rwrite_pointer_i <= waddr_i when rising_edge(RCLK_IN);
   
   RPROC_COMPLETE_COUNTER: process is
      variable delta_v    : integer range -1 to 1;
      variable deadtime_v : integer range 0 to 7;
   begin
      wait until rising_edge(RCLK_IN);
      delta_v := 0;
      rpacket_complete_xchange_i <= wpacket_complete_xchange_i(0);
      RPACKET_COMPLETE_OUT <= '0';
      
      if RRESET_IN = '1' then
         rpacket_counter_i <= (others => '0');
         deadtime_v := 0;
      else
         if RPACKET_COMPLETE_ACK_IN = '1' then
            delta_v := 1;
         end if;
      
         if deadtime_v = 0 and rpacket_complete_xchange_i = '1' then
            delta_v := delta_v - 1;
            deadtime_v := 7;
         end if;
         
         
         if rpacket_counter_i /= 0 or delta_v /= 0 then
            rpacket_counter_i <= rpacket_counter_i + TO_UNSIGNED(delta_v, rpacket_counter_i'length);
         end if;
         
         if (rpacket_counter_i /= 0) then
            RPACKET_COMPLETE_OUT <= '1';
         end if;

         if deadtime_v /= 0 then
            deadtime_v := deadtime_v - 1;
         end if;
      end if;
   end process;
   
   RPROC_ADDRESSING: process is
      variable next_addr_v : unsigned(raddr_i'range);
   begin
      wait until rising_edge(RCLK_IN);
      
      next_addr_v := raddr_i;
      
      if RRESET_IN = '1' then
         next_addr_v := raddr_stored_i;
      else
         if RDEQUEUE_IN = '1' then -- and raddr_i + 1 /= rwrite_pointer_i then
            next_addr_v := next_addr_v + 1;
         end if;
      end if;
      
      raddr_i <= next_addr_v;
   end process;
   RDATA_OUT(15 downto 0) <= mem_i(to_integer(raddr_i)) when rising_edge(RCLK_IN);

-- Write Port
   wread_pointer_i <= raddr_i when rising_edge(WCLK_IN);
   WPROC_ADDRESSING: process is 
   begin
      wait until rising_edge(WCLK_IN);
      if WADDR_RESTORE_IN = '1' then
         waddr_i <= waddr_stored_i;
      elsif WENQUEUE_IN = '1' and wfull_i = '0' then
         waddr_i <= waddr_i + 1;
      end if;
   end process;
   
-- synopsys translate_off
   assert not(WENQUEUE_IN='1' and wfull_i='1' and rising_edge(WCLK_IN)) report "Enqueued into full fifo" severity warning;
-- synopsys translate_on

   WPROC_STORE_ADDR: process is
   begin
      wait until rising_edge(WCLK_IN);
      if WRESET_IN = '1' then
         waddr_stored_i <= (others => '0');
      elsif WADDR_STORE_IN = '1' then
         waddr_stored_i <= waddr_i;
      end if;
   end process;

   wwords_remaining_i <= wread_pointer_i - waddr_i - 1;
   WPROC_FULL_INDICATOR: process(wwords_remaining_i) is
   begin
      wfull_i <= '0';
      if wwords_remaining_i = 0 then
         wfull_i <= '1';
      end if;
      
      walmost_full_i <= '0';
      if wwords_remaining_i < WATERMARK then
         walmost_full_i <= '1';
      end if;
   end process;
   
   WPROC_PACKET_COMPLETE: process is
   begin
      wait until rising_edge(WCLK_IN);
      if WRESET_IN = '1' then
         wpacket_complete_xchange_i <= (others => '0');
      elsif WPACKET_COMPLETE_IN = '1' then
         wpacket_complete_xchange_i <= (others => '1');
      else
         wpacket_complete_xchange_i <= "0" & wpacket_complete_xchange_i(wpacket_complete_xchange_i'high downto 1);
      end if;
   end process;
   
   WALMOST_FULL_OUT <= walmost_full_i;
   WFULL_OUT <= wfull_i;
   
   WPROC_DEBUG: process is
   begin
      wait until rising_edge(WCLK_IN);
      DEBUG_OUT(11 downto  0) <= waddr_i;
      DEBUG_OUT(23 downto 12) <= raddr_i;
      DEBUG_OUT(31 downto 24) <= rpacket_counter_i(7 downto 0);
   end process;
end architecture;