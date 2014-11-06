library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.cbmnet_interface_pkg.all;
   use work.trb_net_std.all;
   use work.trb_net_components.all;
   use work.trb3_components.all;   

entity CBMNET_READOUT is
   port (
   -- TrbNet
      CLK_IN   : in std_logic;
      RESET_IN : in std_logic;

      -- connect to hub
      HUB_CTS_NUMBER_IN              : in  std_logic_vector (15 downto 0);
      HUB_CTS_CODE_IN                : in  std_logic_vector (7  downto 0);
      HUB_CTS_INFORMATION_IN         : in  std_logic_vector (7  downto 0);
      HUB_CTS_READOUT_TYPE_IN        : in  std_logic_vector (3  downto 0);
      HUB_CTS_START_READOUT_IN       : in  std_logic;
      HUB_CTS_READOUT_FINISHED_OUT   : out std_logic;  --no more data, end transfer, send TRM
      HUB_CTS_STATUS_BITS_OUT        : out std_logic_vector (31 downto 0);
      HUB_FEE_DATA_IN                : in  std_logic_vector (15 downto 0);
      HUB_FEE_DATAREADY_IN           : in  std_logic;
      HUB_FEE_READ_OUT               : out std_logic;  --must be high when idle, otherwise you will never get a dataready
      HUB_FEE_STATUS_BITS_IN         : in  std_logic_vector (31 downto 0);
      HUB_FEE_BUSY_IN                : in  std_logic;   

      -- connect to GbE
      GBE_CTS_NUMBER_OUT             : out std_logic_vector (15 downto 0);
      GBE_CTS_CODE_OUT               : out std_logic_vector (7  downto 0);
      GBE_CTS_INFORMATION_OUT        : out std_logic_vector (7  downto 0);
      GBE_CTS_READOUT_TYPE_OUT       : out std_logic_vector (3  downto 0);
      GBE_CTS_START_READOUT_OUT      : out std_logic;
      GBE_CTS_READOUT_FINISHED_IN    : in  std_logic;      --no more data, end transfer, send TRM
      GBE_CTS_STATUS_BITS_IN         : in  std_logic_vector (31 downto 0);
      GBE_FEE_DATA_OUT               : out std_logic_vector (15 downto 0);
      GBE_FEE_DATAREADY_OUT          : out std_logic;
      GBE_FEE_READ_IN                : in  std_logic;  --must be high when idle, otherwise you will never get a dataready
      GBE_FEE_STATUS_BITS_OUT        : out std_logic_vector (31 downto 0);
      GBE_FEE_BUSY_OUT               : out std_logic;

      -- reg io
      REGIO_IN                       : in  CTRLBUS_RX;
      REGIO_OUT                      : out CTRLBUS_TX;

   -- CBMNet
      CBMNET_CLK_IN     : in std_logic;
      CBMNET_RESET_IN   : in std_logic;
      CBMNET_LINK_ACTIVE_IN : in std_logic;

      CBMNET_DATA2SEND_STOP_IN   : in std_logic;
      CBMNET_DATA2SEND_START_OUT : out std_logic;
      CBMNET_DATA2SEND_END_OUT   : out std_logic;
      CBMNET_DATA2SEND_DATA_OUT  : out std_logic_vector(15 downto 0)
   );
end entity;

architecture cbmnet_readout_arch of CBMNET_READOUT is
   signal cbm_from_trb_reset_i : std_logic;
   signal reset_combined_i : std_logic;
   signal reset_combined_125_i : std_logic;

-- signals of readout chain (DECODER -> PACKER -> FIFO -> TX)
   signal fifo_rdata_i                : std_logic_vector(17 downto 0);
   signal fifo_rdequeue_i             : std_logic;
   signal fifo_rpacket_complete_i     : std_logic;
   signal fifo_rpacket_complete_ack_i : std_logic;

   signal fifo_wdata_i            : std_logic_vector(17 downto 0) := (others => '0');
   signal fifo_waddr_store_i      : std_logic;
   signal fifo_waddr_restore_i    : std_logic;
   signal fifo_wenqueue_i         : std_logic;
   signal fifo_wpacket_complete_i : std_logic;
   signal fifo_wfull_i            : std_logic;
   
   signal dec_evt_info_i   : std_logic_vector(31 downto 0);
   signal dec_length_i     : std_logic_vector(15 downto 0);
   signal dec_source_i     : std_logic_vector(15 downto 0);
   signal dec_data_i       : std_logic_vector(15 downto 0);
   
   signal dec_reset_i      : std_logic;
   signal dec_issue_reset_i: std_logic;
   signal dec_data_read_i  : std_logic;
   signal dec_error_i      : std_logic;
   signal dec_actice_i     : std_logic;
   signal dec_data_ready_i : std_logic;
   
   signal pack_source_i    : std_logic_vector(15 downto 0);

-- cbm strobe buffers
   signal frame_packer_start_i : std_logic;
   signal frame_packer_end_i   : std_logic;
   signal frame_packer_data_i  : std_logic_vector(15 downto 0);
   signal obuf_stop_i : std_logic;
   
   signal obuf_start_i : std_logic;
   signal obuf_end_i : std_logic;
   
   signal cbmnet_link_active_in_buf_i : std_logic;
   
-- stats and monitoring   
   signal cbm_stat_num_packets_i : unsigned(31 downto 0) := (others => '0');
   signal cbm_stat_num_send_completed_i : unsigned(31 downto 0) := (others => '0');
   signal cbm_stat_clks_dead_i   : unsigned(31 downto 0) := (others => '0');
   signal cbm_stat_connections_i : unsigned(31 downto 0) := (others => '0');
   signal cbm_stat_hwords_sent_i : unsigned(31 downto 0) := (others => '0');
   signal cbm_stat_transmitting_i : std_logic;
   signal cbm_stat_frame_length_i : unsigned(31 downto 0) := (others => '0');
   
   signal stat_num_packets_i : unsigned(31 downto 0);
   signal stat_num_send_completed_i : unsigned(31 downto 0);

   signal stat_num_packets_aborted_i : unsigned(31 downto 0) := (others => '0');   
   signal stat_clks_dead_i   : unsigned(31 downto 0);
   signal stat_connections_i : unsigned(31 downto 0);   
   
   signal stat_num_recv_completed_i : unsigned(31 downto 0);
   signal stat_link_inactive_i      : unsigned(31 downto 0);   
   signal stat_hwords_sent_i        : unsigned(31 downto 0);
   signal stat_frame_length_i       : unsigned(31 downto 0) := (others => '0');

   
   signal cbm_regio_read_i : std_logic;
   signal cbm_sync_ack_i : std_logic;
   signal trb_from_cbm_sync_ack_i : std_logic;

-- debug
   signal debug_decorder_i     : std_logic_vector(31 downto 0);
   signal debug_packer_i       : std_logic_vector(31 downto 0);
   signal debug_frame_packer_i : std_logic_vector(31 downto 0);
   signal debug_fifo_i         : std_logic_vector(31 downto 0);
   signal debug_obuf_i         : std_logic_vector(31 downto 0);

-- slow control and configuration   
   signal regio_data_status_i : std_logic_vector(31 downto 0);
   signal regio_data_ready_i : std_logic;
   signal regio_unkown_address_i : std_logic;

   signal cfg_enabled_i     : std_logic;
   signal cfg_include_gbe_i : std_logic := '1';
   signal cfg_source_i   : std_logic_vector(15 downto 0);
   signal cfg_source_override_i : std_logic;
   
   signal gbe_include_i : std_logic := '1';
begin
   GBE_CTS_NUMBER_OUT              <= HUB_CTS_NUMBER_IN;
   GBE_CTS_CODE_OUT                <= HUB_CTS_CODE_IN;
   GBE_CTS_INFORMATION_OUT         <= HUB_CTS_INFORMATION_IN;
   GBE_CTS_READOUT_TYPE_OUT        <= HUB_CTS_READOUT_TYPE_IN;
   GBE_CTS_START_READOUT_OUT       <= HUB_CTS_START_READOUT_IN and gbe_include_i;
   GBE_FEE_DATA_OUT                <= HUB_FEE_DATA_IN;
   GBE_FEE_DATAREADY_OUT           <= HUB_FEE_DATAREADY_IN and gbe_include_i;
   GBE_FEE_STATUS_BITS_OUT         <= HUB_FEE_STATUS_BITS_IN;
   GBE_FEE_BUSY_OUT                <= HUB_FEE_BUSY_IN and gbe_include_i;

   HUB_FEE_READ_OUT               <= GBE_FEE_READ_IN or not gbe_include_i;
   HUB_CTS_READOUT_FINISHED_OUT   <= GBE_CTS_READOUT_FINISHED_IN or not gbe_include_i;
   HUB_CTS_STATUS_BITS_OUT        <= GBE_CTS_STATUS_BITS_IN;
   
   proc_reset: process is
      variable counter_v : integer range 0 to 15 := 0;
   begin
      wait until rising_edge(CBMNET_CLK_IN);
      
      if cbm_from_trb_reset_i='1' or CBMNET_RESET_IN='1' or CBMNET_LINK_ACTIVE_IN='0' then
         counter_v := 0;
      elsif counter_v /= 15 then
         counter_v := counter_v + 1;
      end if;
      
      reset_combined_125_i <= '1';
      if counter_v = 15 then
         reset_combined_125_i <= '0';
      end if;
   end process;
   
   THE_RESET_SYNC: signal_sync 
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => '0',
      CLK0 => CLK_IN,
      CLK1 => CBMNET_CLK_IN,
      D_IN(0) => RESET_IN,
      D_OUT(0) => cbm_from_trb_reset_i
   );
   
   THE_RESET1_SYNC: signal_sync 
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => '0',
      CLK0 => CBMNET_CLK_IN,
      CLK1 => CLK_IN,
      D_IN(0) => reset_combined_125_i,
      D_OUT(0) => reset_combined_i
   );
   
   
   THE_DECODER: CBMNET_READOUT_TRBNET_DECODER
   port map (
   -- TrbNet
      CLK_IN   => CLK_IN, -- in std_logic;
      RESET_IN => dec_reset_i, -- in std_logic;
      ENABLED_IN => cfg_enabled_i,
      
      -- connect to hub
      HUB_CTS_START_READOUT_IN       => HUB_CTS_START_READOUT_IN, -- in  std_logic;
      HUB_FEE_DATA_IN                => HUB_FEE_DATA_IN, -- in  std_logic_vector (15 downto 0);
      HUB_FEE_DATAREADY_IN           => HUB_FEE_DATAREADY_IN, -- in  std_logic;
      GBE_FEE_READ_IN                => GBE_FEE_READ_IN, -- in std_logic;
      
      -- Decode
      DEC_EVT_INFO_OUT               => dec_evt_info_i, -- out std_logic_vector(31 downto 0);
      DEC_LENGTH_OUT                 => dec_length_i, -- out std_logic_vector(15 downto 0);
      DEC_SOURCE_OUT                 => dec_source_i, -- out std_logic_vector(15 downto 0);
      DEC_DATA_OUT                   => dec_data_i, -- out std_logic_vector(15 downto 0);
      DEC_DATA_READY_OUT             => dec_data_ready_i, -- out std_logic;
      DEC_DATA_READ_IN               => dec_data_read_i, -- in  std_logic;
      
      DEC_ACTIVE_OUT                 => dec_actice_i, -- out std_logic;
      DEC_ERROR_OUT                  => dec_error_i, -- out std_logic;
      
      DEBUG_OUT                      => debug_decorder_i -- out std_logic_vector(31 downto 0);
   );
   dec_reset_i <= reset_combined_i or dec_issue_reset_i;
   
   THE_PACKER: CBMNET_READOUT_EVENT_PACKER
   port map (
   -- TrbNet
      CLK_IN   => CLK_IN, -- in std_logic;
      RESET_IN => reset_combined_i, -- in std_logic;

      -- connect to hub
      HUB_CTS_NUMBER_IN              => HUB_CTS_NUMBER_IN,       -- in  std_logic_vector (15 downto 0);
      HUB_CTS_CODE_IN                => HUB_CTS_CODE_IN,         -- in  std_logic_vector (7  downto 0);
      HUB_CTS_INFORMATION_IN         => HUB_CTS_INFORMATION_IN,  -- in  std_logic_vector (7  downto 0);
      HUB_CTS_READOUT_TYPE_IN        => HUB_CTS_READOUT_TYPE_IN, -- in  std_logic_vector (3  downto 0);
      HUB_FEE_STATUS_BITS_IN         => HUB_FEE_STATUS_BITS_IN,  -- in  std_logic_vector (31 downto 0);
      
      -- connect to decoder
      DEC_EVT_INFO_IN                => dec_evt_info_i,    -- in  std_logic_vector(31 downto 0);
      DEC_LENGTH_IN                  => dec_length_i,      -- in  std_logic_vector(15 downto 0);
      DEC_SOURCE_IN                  => pack_source_i,     -- in  std_logic_vector(15 downto 0);
      DEC_DATA_IN                    => dec_data_i,        -- in  std_logic_vector(15 downto 0);
      DEC_DATA_READY_IN              => dec_data_ready_i,  -- in  std_logic;
      DEC_ACTIVE_IN                  => dec_actice_i,      -- in  std_logic;
      DEC_ERROR_IN                   => dec_error_i,       -- in  std_logic;
      
      DEC_DATA_READ_OUT              => dec_data_read_i,   -- out std_logic;
      DEC_RESET_OUT                  => dec_issue_reset_i, -- out std_logic;

      -- connect to fifo
      WADDR_STORE_OUT     => fifo_waddr_store_i,      -- out std_logic;
      WADDR_RESTORE_OUT   => fifo_waddr_restore_i,    -- out std_logic;
      WDATA_OUT           => fifo_wdata_i,            -- out std_logic_vector(17 downto 0);
      WENQUEUE_OUT        => fifo_wenqueue_i,         -- out std_logic;
      WPACKET_COMPLETE_OUT=> fifo_wpacket_complete_i, -- out std_logic;
      WFULL_IN            => fifo_wfull_i,            -- in  std_logic;
      
      DEBUG_OUT           => debug_packer_i -- out std_logic_vector(31 downto 0)
   );
   pack_source_i <= cfg_source_i when cfg_source_override_i = '1' else dec_source_i;
   

   THE_READOUT_FIFO: CBMNET_READOUT_FIFO 
   port map (
      -- write port
      WCLK_IN   => CLK_IN,   -- in std_logic; -- not faster than rclk_in
      WRESET_IN => reset_combined_i, -- in std_logic;
      
      WADDR_STORE_IN   => fifo_waddr_store_i,   -- in std_logic;
      WADDR_RESTORE_IN => fifo_waddr_restore_i, -- in std_logic;
      
      WDATA_IN    => fifo_wdata_i,    -- in std_logic_vector(17 downto 0);
      WENQUEUE_IN => fifo_wenqueue_i, -- in std_logic;
      WPACKET_COMPLETE_IN => fifo_wpacket_complete_i, -- in std_logic;
      
      WALMOST_FULL_OUT => fifo_wfull_i,         -- out std_logic;
      WFULL_OUT        => open, -- out std_logic;
      
      -- read port
      RCLK_IN   => CBMNET_CLK_IN,   -- in std_logic;
      RRESET_IN => reset_combined_125_i, -- in std_logic;  -- has to active at least two clocks AFTER (or while) write port was (is being) initialised
      
      RDATA_OUT   => fifo_rdata_i,    -- out std_logic_vector(17 downto 0);
      RDEQUEUE_IN => fifo_rdequeue_i, -- in std_logic;
      
      RPACKET_COMPLETE_OUT    => fifo_rpacket_complete_i,    -- out std_logic;   -- atleast one packet is completed in fifo
      RPACKET_COMPLETE_ACK_IN => fifo_rpacket_complete_ack_i, -- in std_logic -- mark one event as dealt with (effectively decrease number of completed packets by one)
      
      DEBUG_OUT => debug_fifo_i
   );
   
   THE_FRAME_PACKER: CBMNET_READOUT_FRAME_PACKER
   port map (
      CLK_IN   => CBMNET_CLK_IN,   -- in std_logic;
      RESET_IN => reset_combined_i, -- in std_logic; 

      -- fifo 
      FIFO_DATA_IN                 => fifo_rdata_i, -- in std_logic_vector(15 downto 0);
      FIFO_DEQUEUE_OUT             => fifo_rdequeue_i, -- out std_logic;
      FIFO_PACKET_COMPLETE_IN      => fifo_rpacket_complete_i, -- in std_logic;  
      FIFO_PACKET_COMPLETE_ACK_OUT => fifo_rpacket_complete_ack_i, -- out std_logic;

      -- cbmnet
      CBMNET_STOP_IN   => obuf_stop_i,   -- in std_logic;
      CBMNET_START_OUT => frame_packer_start_i, -- out std_logic;
      CBMNET_END_OUT   => frame_packer_end_i,   -- out std_logic;
      CBMNET_DATA_OUT  => frame_packer_data_i,   -- out std_logic_vector(15 downto 0)
      
      DEBUG_OUT => debug_frame_packer_i
   );
   
--    THE_OBUF: CBMNET_READOUT_OBUF 
--    port map (
--       CLK_IN => CBMNET_CLK_IN, -- std_logic;
--       RESET_IN => reset_combined_125_i, -- std_logic;
-- 
--       -- packer
--       PACKER_STOP_OUT  => obuf_stop_i, -- out std_logic;
--       PACKER_START_IN  => frame_packer_start_i, -- in  std_logic;
--       PACKER_END_IN    => frame_packer_end_i, -- in  std_logic;
--       PACKER_DATA_IN   => frame_packer_data_i, -- in  std_logic_vector(15 downto 0);
-- 
--       -- cbmnet
--       CBMNET_STOP_IN   => CBMNET_DATA2SEND_STOP_IN, -- in std_logic;
--       CBMNET_START_OUT => obuf_start_i, -- out std_logic;
--       CBMNET_END_OUT   => obuf_end_i, -- out std_logic;
--       CBMNET_DATA_OUT  => CBMNET_DATA2SEND_DATA_OUT, -- out std_logic_vector(15 downto 0);
--       
--       DEBUG_OUT => debug_obuf_i -- out std_logic_vector(31 downto 0)
--    );
   debug_obuf_i <= x"deadbeaf";
   obuf_stop_i <= CBMNET_DATA2SEND_STOP_IN;
   obuf_start_i <= frame_packer_start_i;
   obuf_end_i <= frame_packer_end_i;
   CBMNET_DATA2SEND_DATA_OUT <= frame_packer_data_i;

   
   
   CBMNET_DATA2SEND_START_OUT <= obuf_start_i;
   CBMNET_DATA2SEND_END_OUT <= obuf_end_i;
----------------------------------------
-- Slow control and monitoring
----------------------------------------   
   -- gather stats in CBMNet clock domain
   PROC_CBM_STATS: process is
      variable last_link_active_v, last_end_v : std_logic;
   begin
      wait until rising_edge(CBMNET_CLK_IN);
      
      if CBMNET_LINK_ACTIVE_IN = '1' and last_link_active_v = '0' then
         cbm_stat_connections_i <= cbm_stat_connections_i + 1;
      end if;
      
      if frame_packer_end_i = '1' and last_end_v = '0' then
         cbm_stat_num_packets_i <= cbm_stat_num_packets_i + 1;
      end if;
         
      if CBMNET_DATA2SEND_STOP_IN = '1' then
         cbm_stat_clks_dead_i <= cbm_stat_clks_dead_i + 1;
      end if;
      
      if fifo_rpacket_complete_ack_i = '1' then
         cbm_stat_num_send_completed_i <= cbm_stat_num_send_completed_i + 1;
      end if;

      if cbm_stat_transmitting_i='1' then
         cbm_stat_hwords_sent_i <= cbm_stat_hwords_sent_i + 1;
         cbm_stat_frame_length_i <= cbm_stat_frame_length_i + 1;
      end if;
      
      if obuf_start_i='1' and CBMNET_DATA2SEND_STOP_IN='0' then
         cbm_stat_transmitting_i <= '1';
         cbm_stat_frame_length_i <= (0 => '1', others => '0');
         cbm_stat_hwords_sent_i <= cbm_stat_hwords_sent_i + 1;
      elsif CBMNET_LINK_ACTIVE_IN='0' or obuf_end_i='1' then
         cbm_stat_transmitting_i <= '0';
      end if;
   
      last_link_active_v := CBMNET_LINK_ACTIVE_IN;
      last_end_v := frame_packer_end_i;
   end process;
   
   -- and cross over to TrbNet clock domain
   PROC_CBM_SYNC: process is
      variable ack_delay : std_logic := '0';
   begin
      wait until rising_edge(CBMNET_CLK_IN);
      
      cbm_sync_ack_i <= ack_delay;
      ack_delay := '0';

      if cbm_regio_read_i = '1' then
         cbm_sync_ack_i <= '0';
         
      else
         ack_delay := '1';
      
         stat_connections_i <= cbm_stat_connections_i;
         stat_num_packets_i <= cbm_stat_num_packets_i;
         stat_clks_dead_i   <= cbm_stat_clks_dead_i;
         stat_num_send_completed_i <= cbm_stat_num_send_completed_i;
         stat_hwords_sent_i <= cbm_stat_hwords_sent_i;
         stat_frame_length_i <= cbm_stat_frame_length_i;
      end if;
   end process;
   
   THE_REGIO_READ_SYNC: signal_sync 
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => reset_combined_i,
      CLK0 => CLK_IN,
      CLK1 => CBMNET_CLK_IN,
      D_IN(0) => REGIO_IN.read,
      D_OUT(0) => cbm_regio_read_i
   );
   
   THE_REGIO_READ_ACK_SYNC: pos_edge_strech_sync port map (
      IN_CLK_IN => CBMNET_CLK_IN, OUT_CLK_IN => CLK_IN,
      DATA_IN   => cbm_sync_ack_i,
      DATA_OUT  => trb_from_cbm_sync_ack_i
   );
   
   -- statistics in TrbNet clock domain
   PROC_STATS: process is
      variable fifo_waddr_restore_delay : std_logic;
   begin
      wait until rising_edge(CLK_IN);
      
      if cbmnet_link_active_in_buf_i = '0' then
         stat_link_inactive_i <= stat_link_inactive_i + 1;
      end if;
      cbmnet_link_active_in_buf_i <= CBMNET_LINK_ACTIVE_IN;
      
      if fifo_wpacket_complete_i = '1' then
         stat_num_recv_completed_i <= stat_num_recv_completed_i + 1;
      end if;
      
      if fifo_waddr_restore_i = '1' and fifo_waddr_restore_delay = '0' then
         stat_num_packets_aborted_i <= stat_num_packets_aborted_i + 1;
      end if;
      fifo_waddr_restore_delay := fifo_waddr_restore_i;
   end process;
   
   PROC_READOUT_MUX: process is
      variable addr : integer;
   begin
      wait until rising_edge(CLK_IN);
      
      regio_data_ready_i <= REGIO_IN.read;
      regio_unkown_address_i <= '0';
      regio_data_status_i <= x"00000000";
      
      addr := to_integer(UNSIGNED(REGIO_IN.addr(6 downto 0)));
      
   -- read
      case addr is
         when 16#00# => 
            regio_data_status_i(0) <= cfg_enabled_i;
            regio_data_status_i(1) <= cfg_include_gbe_i;
         when 16#01# => regio_data_status_i(16 downto 0) <= cfg_source_override_i & cfg_source_i;
         
         when 16#02# => regio_data_status_i <= std_logic_vector(stat_connections_i); regio_data_ready_i <= trb_from_cbm_sync_ack_i;
         when 16#03# => regio_data_status_i <= std_logic_vector(stat_clks_dead_i); regio_data_ready_i <= trb_from_cbm_sync_ack_i;
         when 16#04# => regio_data_status_i <= std_logic_vector(stat_num_send_completed_i); regio_data_ready_i <= trb_from_cbm_sync_ack_i;
         when 16#05# => regio_data_status_i <= std_logic_vector(stat_num_packets_i); regio_data_ready_i <= trb_from_cbm_sync_ack_i;
         when 16#06# => regio_data_status_i <= std_logic_vector(stat_num_recv_completed_i);
         when 16#07# => regio_data_status_i <= std_logic_vector(stat_link_inactive_i);
         when 16#08# => regio_data_status_i <= std_logic_vector(stat_num_packets_aborted_i);
         when 16#09# => regio_data_status_i <= std_logic_vector(stat_hwords_sent_i); regio_data_ready_i <= trb_from_cbm_sync_ack_i;
         when 16#0a# => regio_data_status_i <= std_logic_vector(stat_frame_length_i); regio_data_ready_i <= trb_from_cbm_sync_ack_i;
         
         -- debug only ports
         when 16#10# => regio_data_status_i <= debug_decorder_i;
         when 16#11# => regio_data_status_i <= debug_packer_i;
         when 16#12# => regio_data_status_i <= debug_frame_packer_i;
         when 16#13# => regio_data_status_i(1 downto 0) <= fifo_wfull_i & fifo_rpacket_complete_i;
         when 16#14# => regio_data_status_i <= HUB_CTS_INFORMATION_IN & HUB_CTS_CODE_IN & HUB_CTS_NUMBER_IN;
         when 16#15# => regio_data_status_i <= dec_evt_info_i;
         when 16#16# => regio_data_status_i <= dec_source_i & dec_length_i;
         
         when 16#17# => regio_data_status_i <= debug_fifo_i;
         when 16#18# => regio_data_status_i <= debug_obuf_i;
         
         when others => regio_unkown_address_i <= REGIO_IN.read;
      end case;

   -- write 
      if REGIO_IN.write = '1' then
         case addr is
            when 16#0# =>
               cfg_enabled_i <= REGIO_IN.data(0);
               cfg_include_gbe_i <= REGIO_IN.data(1);
               
            when 16#1# =>
               cfg_source_i  <= REGIO_IN.data(15 downto 0);
               cfg_source_override_i <= REGIO_IN.data(16);
               
            when others =>
               regio_unkown_address_i <= '1';
         end case;
      end if;
      
      if RESET_IN = '1' then 
         cfg_enabled_i <= '0';
         cfg_include_gbe_i <= '1';
      end if;
      
      -- make sure, we enable/disable gbe not during an ongoing rdo
      if HUB_CTS_START_READOUT_IN='0' and HUB_FEE_BUSY_IN='0' then
         gbe_include_i <= cfg_include_gbe_i;
      end if;
   end process;
   
      
   REGIO_OUT.data         <= regio_data_status_i;
   REGIO_OUT.unknown <= regio_unkown_address_i;
   
   REGIO_OUT.rack <= REGIO_IN.read  when rising_edge(CLK_IN);
   REGIO_OUT.wack <= REGIO_IN.write when rising_edge(CLK_IN);
   
end architecture;

