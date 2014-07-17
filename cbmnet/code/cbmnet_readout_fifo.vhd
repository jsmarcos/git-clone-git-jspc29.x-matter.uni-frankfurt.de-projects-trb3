library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;


entity CBMNET_READOUT_FIFO is
   generic (
      ADDR_WIDTH : positive := 10;
      WATERMARK  : positive := 2
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
      RPACKET_COMPLETE_ACK_IN : in std_logic -- mark one event as dealt with (effectively decrease number of completed packets by one)
   );
end CBMNET_READOUT_FIFO;

architecture cbmnet_readout_fifo_arch of CBMNET_READOUT_FIFO is
   signal waddr_i, waddr_stored_i, wread_pointer_i, wwords_remaining_i : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
   signal wfull_i, walmost_full_i : std_logic;
   signal wpacket_complete_xchange_i : std_logic := '0';
   
   signal raddr_i, raddr_stored_i, rwrite_pointer_i, rpacket_counter_i : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
   signal rpacket_complete_xchange_i : std_logic := '0'; 

   type FIFO_MEM_T is array(0 to 2**ADDR_WIDTH-1) of std_logic_vector(17 downto 0);
   signal mem_i : FIFO_MEM_T;
begin
-- Memory
   MEM_WRITE_PORT: process is
      variable last_full_v : std_logic := '1';
   begin
      wait until rising_edge(WCLK_IN);
      if (wfull_i = '0' or last_full_v = '0') and WENQUEUE_IN = '1' then
         mem_i(to_integer(waddr_i)) <= WDATA_IN;
      end if;
      
      last_full_v := wfull_i;
   end process;

-- Read Port
   raddr_stored_i <= waddr_stored_i when rising_edge(RCLK_IN);
   rwrite_pointer_i <= waddr_i when rising_edge(RCLK_IN);
   
   RPROC_COMPLETE_COUNTER: process is
      variable delta_v : unsigned(1 downto 0);
   begin
      wait until rising_edge(RCLK_IN);
      delta_v := TO_UNSIGNED(1, delta_v'length);
      rpacket_complete_xchange_i <= wpacket_complete_xchange_i;
      RPACKET_COMPLETE_OUT <= '0';
      
      if RRESET_IN = '1' then
         rpacket_counter_i <= (others => '0');
      else
         if RPACKET_COMPLETE_ACK_IN = '1' then
            delta_v := TO_UNSIGNED(0, delta_v'length);
         end if;
      
         if rpacket_complete_xchange_i /= wpacket_complete_xchange_i then
            delta_v := delta_v + TO_UNSIGNED(1, delta_v'length);
         end if;
         
         rpacket_counter_i <= rpacket_counter_i + delta_v -  TO_UNSIGNED(1, 1);
         
         if rpacket_counter_i /= 0 or delta_v = 2 then
            RPACKET_COMPLETE_OUT <= '1';
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
         if RDEQUEUE_IN = '1' and raddr_i + 1 /= rwrite_pointer_i then
            next_addr_v := next_addr_v + 1;
         end if;
      end if;
      
      raddr_i <= next_addr_v;
   end process;
   RDATA_OUT <= mem_i(to_integer(raddr_i));

-- Write Port
   wread_pointer_i <= raddr_i when rising_edge(WCLK_IN);
   WPROC_ADDRESSING: process is 
   begin
      wait until rising_edge(WCLK_IN);
      if WADDR_RESTORE_IN = '1' then
         waddr_i <= waddr_stored_i;
      elsif wfull_i = '0' and WENQUEUE_IN = '1' then
         waddr_i <= waddr_i + 1;
      end if;
   end process;

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
      variable last_v : std_logic;
   begin
      wait until rising_edge(WCLK_IN);
      if WPACKET_COMPLETE_IN = '1' and last_v = '0' then
         wpacket_complete_xchange_i <= not wpacket_complete_xchange_i;
      end if;
      last_v := WPACKET_COMPLETE_IN;
   end process;
   
   WALMOST_FULL_OUT <= walmost_full_i;
   WFULL_OUT <= wfull_i;
end architecture;