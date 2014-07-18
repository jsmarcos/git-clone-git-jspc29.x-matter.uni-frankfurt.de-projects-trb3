library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.cbmnet_interface_pkg.all;

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
      REGIO_ADDR_IN                  : in  std_logic_vector(15 downto 0);
      REGIO_DATA_IN                  : in  std_logic_vector(31 downto 0);
      REGIO_READ_ENABLE_IN           : in  std_logic;
      REGIO_WRITE_ENABLE_IN          : in  std_logic;
      REGIO_DATA_OUT                 : out std_logic_vector(31 downto 0);
      REGIO_DATAREADY_OUT            : out std_logic;
      REGIO_WRITE_ACK_OUT            : out std_logic;
      REGIO_UNKNOWN_ADDR_OUT         : out std_logic;

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
   
begin
   GBE_CTS_NUMBER_OUT              <= HUB_CTS_NUMBER_IN;
   GBE_CTS_CODE_OUT                <= HUB_CTS_CODE_IN;
   GBE_CTS_INFORMATION_OUT         <= HUB_CTS_INFORMATION_IN;
   GBE_CTS_READOUT_TYPE_OUT        <= HUB_CTS_READOUT_TYPE_IN;
   GBE_CTS_START_READOUT_OUT       <= HUB_CTS_START_READOUT_IN;
   GBE_FEE_DATA_OUT                <= HUB_FEE_DATA_IN;
   GBE_FEE_DATAREADY_OUT           <= HUB_FEE_DATAREADY_IN;
   GBE_FEE_STATUS_BITS_OUT         <= HUB_FEE_STATUS_BITS_IN;
   GBE_FEE_BUSY_OUT                <= HUB_FEE_BUSY_IN;

   HUB_FEE_READ_OUT               <= GBE_FEE_READ_IN;
   HUB_CTS_READOUT_FINISHED_OUT   <= GBE_CTS_READOUT_FINISHED_IN;
   HUB_CTS_STATUS_BITS_OUT        <= GBE_CTS_STATUS_BITS_IN;
   
   THE_DECODER: CBMNET_READOUT_TRBNET_DECODER
   port map (
   -- TrbNet
      CLK_IN   => CLK_IN, -- in std_logic;
      RESET_IN => dec_reset_i, -- in std_logic;

      -- connect to hub
      HUB_CTS_START_READOUT_IN       => HUB_CTS_START_READOUT_IN, -- in  std_logic;
      HUB_CTS_READOUT_FINISHED_OUT   => HUB_CTS_READOUT_FINISHED_OUT, -- out std_logic;  --no more data, end transfer, send TRM
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
      
      DEBUG_OUT                      => open -- out std_logic_vector(31 downto 0);
   );
   dec_reset_i <= RESET_IN or dec_issue_reset_i;
   
   THE_PACKER: CBMNET_READOUT_EVENT_PACKER
   port map (
   -- TrbNet
      CLK_IN   => CLK_IN, -- in std_logic;
      RESET_IN => RESET_IN, -- in std_logic;

      -- connect to hub
      HUB_CTS_NUMBER_IN              => HUB_CTS_NUMBER_IN,       -- in  std_logic_vector (15 downto 0);
      HUB_CTS_CODE_IN                => HUB_CTS_CODE_IN,         -- in  std_logic_vector (7  downto 0);
      HUB_CTS_INFORMATION_IN         => HUB_CTS_INFORMATION_IN,  -- in  std_logic_vector (7  downto 0);
      HUB_CTS_READOUT_TYPE_IN        => HUB_CTS_READOUT_TYPE_IN, -- in  std_logic_vector (3  downto 0);
      GBE_CTS_STATUS_BITS_IN         => GBE_CTS_STATUS_BITS_IN,  -- in  std_logic_vector (31 downto 0);
      
      
      -- connect to decoder
      DEC_EVT_INFO_IN                => dec_evt_info_i, -- in  std_logic_vector(31 downto 0);
      DEC_LENGTH_IN                  => dec_length_i, -- in  std_logic_vector(15 downto 0);
      DEC_SOURCE_IN                  => dec_source_i, -- in  std_logic_vector(15 downto 0);
      DEC_DATA_IN                    => dec_data_i, -- in  std_logic_vector(15 downto 0);
      DEC_DATA_READY_IN              => dec_data_ready_i, -- in  std_logic;
      DEC_ACTIVE_IN                  => dec_actice_i, -- in  std_logic;
      DEC_ERROR_IN                   => dec_error_i, -- in  std_logic;
      
      DEC_DATA_READ_OUT              => dec_data_read_i, -- out std_logic;
      DEC_RESET_OUT                  => dec_issue_reset_i, -- out std_logic;

      -- connect to fifo
      WADDR_STORE_OUT     => fifo_waddr_store_i,      -- out std_logic;
      WADDR_RESTORE_OUT   => fifo_waddr_restore_i,    -- out std_logic;
      WDATA_OUT           => fifo_wdata_i,            -- out std_logic_vector(17 downto 0);
      WENQUEUE_OUT        => fifo_wenqueue_i,         -- out std_logic;
      WPACKET_COMPLETE_OUT=> fifo_wpacket_complete_i, -- out std_logic;
      WFULL_IN            => fifo_wfull_i,            -- in  std_logic;
      
      DEBUG_OUT           => open -- out std_logic_vector(31 downto 0)
   );

   THE_READOUT_FIFO: CBMNET_READOUT_FIFO 
   generic map (
      ADDR_WIDTH => 10, 
      WATERMARK  => 2
   ) port map (
      -- write port
      WCLK_IN   => CLK_IN, -- in std_logic; -- not faster than rclk_in
      WRESET_IN => RESET_IN, -- in std_logic;
      
      WADDR_STORE_IN   => fifo_waddr_store_i, -- in std_logic;
      WADDR_RESTORE_IN => fifo_waddr_restore_i, -- in std_logic;
      
      WDATA_IN    => fifo_wdata_i, -- in std_logic_vector(17 downto 0);
      WENQUEUE_IN => fifo_wenqueue_i, -- in std_logic;
      WPACKET_COMPLETE_IN => fifo_wpacket_complete_i, -- in std_logic;
      
      WALMOST_FULL_OUT => open, -- out std_logic;
      WFULL_OUT        => fifo_wfull_i, -- out std_logic;
      
      -- read port
      RCLK_IN   => CBMNET_CLK_IN, -- in std_logic;
      RRESET_IN => CBMNET_RESET_IN, -- in std_logic;  -- has to active at least two clocks AFTER (or while) write port was (is being) initialised
      
      RDATA_OUT   => fifo_rdata_i, -- out std_logic_vector(17 downto 0);
      RDEQUEUE_IN => fifo_rdequeue_i, -- in std_logic;
      
      RPACKET_COMPLETE_OUT    => fifo_rpacket_complete_i, -- out std_logic;   -- atleast one packet is completed in fifo
      RPACKET_COMPLETE_ACK_IN => fifo_rpacket_complete_ack_i -- in std_logic -- mark one event as dealt with (effectively decrease number of completed packets by one)
   );
   
   THE_TX_FSM: CBMNET_READOUT_TX_FSM
   port map (
      CLK_IN   => CBMNET_CLK_IN,   -- in std_logic;
      RESET_IN => CBMNET_RESET_IN, -- in std_logic; 

      -- fifo 
      FIFO_DATA_IN                 => fifo_rdata_i(15 downto 0), -- in std_logic_vector(15 downto 0);
      FIFO_DEQUEUE_OUT             => fifo_rdequeue_i, -- out std_logic;
      FIFO_PACKET_COMPLETE_IN      => fifo_rpacket_complete_i, -- in std_logic;  
      FIFO_PACKET_COMPLETE_ACK_OUT => fifo_rpacket_complete_ack_i, -- out std_logic;

      -- cbmnet
      CBMNET_STOP_IN   => CBMNET_DATA2SEND_STOP_IN,   -- in std_logic;
      CBMNET_START_OUT => CBMNET_DATA2SEND_START_OUT, -- out std_logic;
      CBMNET_END_OUT   => CBMNET_DATA2SEND_END_OUT,   -- out std_logic;
      CBMNET_DATA_OUT  => CBMNET_DATA2SEND_DATA_OUT   -- out std_logic_vector(15 downto 0)
   );
   
end architecture;

