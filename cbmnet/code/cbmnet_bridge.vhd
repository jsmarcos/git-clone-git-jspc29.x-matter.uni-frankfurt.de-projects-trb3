Library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.std_logic_unsigned.all;

library work;
   use work.trb_net_std.all;
   use work.trb_net_components.all;
   use work.trb3_components.all;
   use work.trb_net16_hub_func.all;
   use work.cbmnet_interface_pkg.all;
   use work.cbmnet_phy_pkg.all;
   
entity cbmnet_bridge is
   port (
   -- clock and reset
      CLK125_IN : in std_logic;
      ASYNC_RESET_IN : in std_logic;
      TRB_CLK_IN : in std_logic;
      TRB_RESET_IN : in std_logic;
      
      CBM_CLK_OUT : out std_logic;
      CBM_RESET_OUT: out std_logic;
      
   -- Media Interface
      SD_RXD_P_IN        : in  std_logic := '0';
      SD_RXD_N_IN        : in  std_logic := '0';
      SD_TXD_P_OUT       : out std_logic := '0';
      SD_TXD_N_OUT       : out std_logic := '0';

      SD_PRSNT_N_IN      : in  std_logic;  -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
      SD_LOS_IN          : in  std_logic;  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
      SD_TXDIS_OUT       : out  std_logic := '0'; -- SFP disable

      LED_RX_OUT         : out std_logic;
      LED_TX_OUT         : out std_logic;
      LED_OK_OUT         : out std_logic;
      
   -- Status and strobes
      CBM_LINK_ACTIVE_OUT     : out std_logic;
      CBM_DLM_OUT             : out std_logic;
      CBM_TIMING_TRIGGER_OUT  : out std_logic;
      CBM_SYNC_PULSER_OUT     : out std_logic;

   -- TRBNet Terminal
      --data output for read-out
      TRB_TRIGGER_IN       : in  std_logic;
      TRB_RDO_VALID_DATA_TRG_IN  : in  std_logic;
      TRB_RDO_VALID_NO_TIMING_IN : in  std_logic;
      TRB_RDO_DATA_OUT     : out std_logic_vector(31 downto 0);
      TRB_RDO_WRITE_OUT    : out std_logic;
      TRB_RDO_STATUSBIT_OUT: out std_logic_vector(31 downto 0);
      TRB_RDO_FINISHED_OUT : out std_logic;
      
      TRB_TRIGGER_OUT : out std_logic;
   
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
      REGIO_TIMEOUT_IN               : in  std_logic;
      REGIO_DATA_OUT                 : out std_logic_vector(31 downto 0);
      REGIO_DATAREADY_OUT            : out std_logic;
      REGIO_WRITE_ACK_OUT            : out std_logic;
      REGIO_NO_MORE_DATA_OUT         : out std_logic;
      REGIO_UNKNOWN_ADDR_OUT         : out std_logic
   );
end entity;

architecture cbmnet_bridge_arch of cbmnet_bridge is
   attribute syn_hier : string;
   attribute syn_hier of cbmnet_bridge_arch : architecture is "hard";


-- link port
   signal cbm_clk_i             : std_logic;
   signal cbm_clk250_i          : std_logic;
   signal cbm_reset_i           : std_logic;
   signal cbm_reset_n_i         : std_logic;

   signal cbm_ctrl2send_stop_i  :  std_logic := '0'; -- send control interface
   signal cbm_ctrl2send_start_i :  std_logic := '0';
   signal cbm_ctrl2send_end_i   :  std_logic := '0';
   signal cbm_ctrl2send_i       :  std_logic_vector(15 downto 0) := (others => '0');

   signal cbm_data2send_stop_i  :  std_logic; -- send data interface
   signal cbm_data2send_start_i :  std_logic;
   signal cbm_data2send_end_i   :  std_logic;
   signal cbm_data2send_i       :  std_logic_vector(15 downto 0) := (others => '0');

   signal cbm_dlm2send_va_i     :  std_logic := '0';                      -- send dlm interface
   signal cbm_dlm2send_i        :  std_logic_vector(3 downto 0) := (others => '0');

   signal cbm_dlm_ref_rec_type_i:  std_logic_vector(3 downto 0) := (others => '0');   -- receive dlm interface
   signal cbm_dlm_ref_rec_va_i  :  std_logic := '0';

   signal cbm_dlm_rec_type_i    :  std_logic_vector(3 downto 0) := (others => '0');   -- receive dlm interface
   signal cbm_dlm_rec_va_i      :  std_logic := '0';

   signal cbm_data_rec_i        :  std_logic_vector(15 downto 0);   -- receive data interface
   signal cbm_data_rec_start_i  :  std_logic;
   signal cbm_data_rec_end_i    :  std_logic;         
   signal cbm_data_rec_stop_i   :  std_logic := '1';  

   signal cbm_ctrl_rec_i        :  std_logic_vector(15 downto 0);       -- receive control interface
   signal cbm_ctrl_rec_start_i  :  std_logic;
   signal cbm_ctrl_rec_end_i    :  std_logic;                 
   signal cbm_ctrl_rec_stop_i   :  std_logic;

   signal cbm_data_from_link_i  :  std_logic_vector(17 downto 0);   -- interface from the phy
   signal cbm_data2link_i       :  std_logic_vector(17 downto 0);   -- interface to the phy

   signal cbm_serdes_ready_i    :  std_logic;    --   signalize when phy ready  
   signal cbm_link_active_i     :  std_logic;    --   signalize when lp_top is ready
   
   signal cbm_phy_debug : std_logic_vector(511 downto 0);


-- data port mux
   signal cbm_data_mux_i : std_logic := '0'; -- 0: connected with readout, 1: connected with link tester
   signal cbm_data_mux_buf_i : std_logic := '0'; -- 0: connected with readout, 1: connected with link tester
   signal cbm_data_mux_crs_i : std_logic := '0'; -- 0: connected with readout, 1: connected with link tester

   signal cbm_lt_data_enable_buf_i : std_logic;
   signal cbm_lt_data_enable_crs_i : std_logic;

   signal cbm_lt_data_enable_i : std_logic;
   signal cbm_lt_ctrl_enable_i : std_logic;
   signal cbm_lt_force_stop_i : std_logic;
   signal cbm_lt_ctrl_valid_i : std_logic;
   signal cbm_lt_dlm_valid_i : std_logic;

   signal cbm_lt_data2send_stop_i : std_logic;
   signal cbm_lt_data2send_start_i : std_logic;
   signal cbm_lt_data2send_end_i : std_logic;
   signal cbm_lt_data2send_i : std_logic_vector(15 downto 0);

   signal cbm_rdo_data2send_stop_i : std_logic;
   signal cbm_rdo_data2send_start_i : std_logic;
   signal cbm_rdo_data2send_end_i : std_logic;
   signal cbm_rdo_data2send_i : std_logic_vector(15 downto 0);

-- regio
   signal cbm_rdo_regio_addr_i         : std_logic_vector(15 downto 0);
   signal cbm_rdo_regio_data_status_i  : std_logic_vector(31 downto 0);
   signal cbm_rdo_regio_read_enable_i  : std_logic;
   signal cbm_rdo_regio_write_enable_i : std_logic;
   signal cbm_rdo_regio_data_ctrl_i    : std_logic_vector(31 downto 0);
   signal cbm_rdo_regio_dataready_i    : std_logic;
   signal cbm_rdo_regio_write_ack_i    : std_logic;
   signal cbm_rdo_regio_unknown_addr_i : std_logic;

   signal cbm_phy_regio_addr_i         : std_logic_vector(15 downto 0);
   signal cbm_phy_regio_data_status_i  : std_logic_vector(31 downto 0);
   signal cbm_phy_regio_read_enable_i  : std_logic;
   signal cbm_phy_regio_write_enable_i : std_logic;
   signal cbm_phy_regio_data_ctrl_i    : std_logic_vector(31 downto 0);
   signal cbm_phy_regio_dataready_i    : std_logic;
   signal cbm_phy_regio_write_ack_i    : std_logic;
   signal cbm_phy_regio_unknown_addr_i : std_logic;  

   signal cbm_sync_regio_read_en_i     : std_logic;
   signal cbm_sync_regio_write_en_i    : std_logic;
   signal cbm_sync_regio_status_data_i : std_logic_vector(31 downto 0);
   signal cbm_sync_regio_addr_i        : std_logic_vector(3 downto 0);
   signal cbm_sync_regio_config_data_i : std_logic_vector(31 downto 0);
   signal cbm_sync_regio_read_ack_i    : std_logic;
   signal cbm_sync_regio_write_ack_i   : std_logic;
   signal cbm_sync_regio_unknown_i     : std_logic;

begin
   THE_CBM_PHY: cbmnet_phy_ecp3
   generic map (
      IS_SYNC_SLAVE => c_YES,
      DETERMINISTIC_LATENCY => c_YES
   )
   port map (
      CLK                => CLK125_IN,
      RESET              => TRB_RESET_IN,
      CLEAR              => ASYNC_RESET_IN,
         
      --Internal Connection TX
      PHY_TXDATA_IN      => cbm_data2link_i(15 downto  0),
      PHY_TXDATA_K_IN    => cbm_data2link_i(17 downto 16),
      
      --Internal Connection RX
      PHY_RXDATA_OUT     => cbm_data_from_link_i(15 downto 0),
      PHY_RXDATA_K_OUT   => cbm_data_from_link_i(17 downto 16),
      
      CLK_RX_HALF_OUT    => cbm_clk_i,
      CLK_RX_FULL_OUT    => cbm_clk250_i,
      CLK_RX_RESET_OUT   => cbm_reset_i,

      SERDES_ready       => cbm_serdes_ready_i,
      
      --SFP Connection
      SD_RXD_P_IN        => SD_RXD_P_IN,
      SD_RXD_N_IN        => SD_RXD_N_IN,
      SD_TXD_P_OUT       => SD_TXD_P_OUT,
      SD_TXD_N_OUT       => SD_TXD_N_OUT,

      SD_PRSNT_N_IN      => SD_PRSNT_N_IN,
      SD_LOS_IN          => SD_LOS_IN,
      SD_TXDIS_OUT       => SD_TXDIS_OUT,
      
      LED_RX_OUT         => LED_RX_OUT,
      LED_TX_OUT         => LED_TX_OUT,
      LED_OK_OUT         => LED_OK_OUT,
      
      -- Status and control port
      STAT_OP            => open,
      CTRL_OP            => open,
      DEBUG_OUT          => cbm_phy_debug
   );
   CBM_CLK_OUT <= cbm_clk_i;
   CBM_RESET_OUT <= cbm_reset_i;
   
   proc_debug_regio: process is 
      variable addr : integer range 0 to 31;
   begin
      wait until rising_edge(TRB_CLK_IN);
      addr := to_integer(unsigned(cbm_phy_regio_addr_i(4 downto 0)));
      
      cbm_phy_regio_dataready_i <= cbm_phy_regio_read_enable_i;
      cbm_phy_regio_unknown_addr_i <= '0';
      cbm_phy_regio_write_ack_i <= '0';
      
      cbm_phy_regio_data_status_i <= (others => '0');
      
      if addr < 16 then
         cbm_phy_regio_data_status_i <= cbm_phy_debug(addr*32+31 downto addr*32);
         
      elsif addr = 16 then
         cbm_phy_regio_data_status_i(11 downto 8) <= "0" & cbm_data2send_stop_i &  cbm_serdes_ready_i & cbm_link_active_i;
         cbm_phy_regio_data_status_i(7 downto 4) <= "00" & cbm_lt_dlm_valid_i & cbm_lt_ctrl_valid_i;
         cbm_phy_regio_data_status_i(3 downto 0) <= cbm_data_mux_i & cbm_lt_data_enable_i & cbm_lt_ctrl_enable_i & cbm_lt_force_stop_i;
      
         if cbm_phy_regio_write_enable_i='1' then
            cbm_data_mux_i       <= cbm_phy_regio_data_ctrl_i(3);
            cbm_lt_data_enable_i <= cbm_phy_regio_data_ctrl_i(2);
            cbm_lt_ctrl_enable_i <= cbm_phy_regio_data_ctrl_i(1);
            cbm_lt_force_stop_i  <= cbm_phy_regio_data_ctrl_i(0);
            
            cbm_phy_regio_write_ack_i <= '1';
         end if;
         
      else
         cbm_phy_regio_unknown_addr_i <= cbm_phy_regio_write_enable_i or cbm_phy_regio_read_enable_i;
      
      end if;
      
      if TRB_RESET_IN='1' then
         cbm_lt_data_enable_i <= '0';
         cbm_lt_ctrl_enable_i <= '0';
         cbm_lt_force_stop_i  <= '1';
         cbm_data_mux_i <= '0';
      end if;
   end process;
   
   THE_CBM_ENDPOINT: cn_lp_top 
   port map (
   -- Clk & Reset
      clk => cbm_clk_i,
      res_n => cbm_reset_n_i,

   -- Phy
      data_from_link => cbm_data_from_link_i,
      data2link => cbm_data2link_i,
      serdes_ready => cbm_serdes_ready_i,

   -- CBMNet Interface
      link_active => cbm_link_active_i,
      ctrl2send_stop => cbm_ctrl2send_stop_i,
      ctrl2send_start => cbm_ctrl2send_start_i,
      ctrl2send_end => cbm_ctrl2send_end_i,
      ctrl2send => cbm_ctrl2send_i,
      
      data2send_stop => cbm_data2send_stop_i,
      data2send_start => cbm_data2send_start_i,
      data2send_end => cbm_data2send_end_i,
      data2send => cbm_data2send_i,
      
      dlm2send_va => cbm_dlm2send_va_i,
      dlm2send => cbm_dlm2send_i,
      
      dlm_rec => cbm_dlm_ref_rec_type_i,
      dlm_rec_va => cbm_dlm_ref_rec_va_i,

      data_rec => cbm_data_rec_i,
      data_rec_start => cbm_data_rec_start_i,
      data_rec_end => cbm_data_rec_end_i,
      data_rec_stop => cbm_data_rec_stop_i,
      
      ctrl_rec => cbm_ctrl_rec_i,
      ctrl_rec_start => cbm_ctrl_rec_start_i,
      ctrl_rec_end => cbm_ctrl_rec_end_i,
      ctrl_rec_stop => cbm_ctrl_rec_stop_i
   );
   cbm_reset_n_i <= not cbm_reset_i when rising_edge(cbm_clk_i);
   CBM_LINK_ACTIVE_OUT <= cbm_link_active_i;

   THE_DLM_REFLECT: dlm_reflect
   port map (
      clk            => cbm_clk_i,       -- in std_logic;
      res_n          => cbm_reset_n_i,    -- in std_logic;
      
      -- from interface
      dlm_rec_in     => cbm_dlm_ref_rec_type_i, -- in std_logic_vector(3 downto 0);
      dlm_rec_va_in  => cbm_dlm_ref_rec_va_i,   -- in std_logic;
      
      -- to application logic
      dlm_rec_out    => cbm_dlm_rec_type_i,     -- out std_logic_vector(3 downto 0);
      dlm_rec_va_out => cbm_dlm_rec_va_i,       -- out std_logic;
      
      -- to interface
      dlm2send_va    => cbm_dlm2send_va_i,  -- out std_logic;
      dlm2send       => cbm_dlm2send_i      -- out std_logic_vector(3 downto 0)
   );
   
   THE_CBMNET_READOUT: cbmnet_readout 
   port map(
   -- TrbNet
      CLK_IN   => TRB_CLK_IN, -- in std_logic;
      RESET_IN => TRB_RESET_IN, -- in std_logic;

      -- connect to hub
      HUB_CTS_NUMBER_IN              => HUB_CTS_NUMBER_IN,
      HUB_CTS_CODE_IN                => HUB_CTS_CODE_IN,
      HUB_CTS_INFORMATION_IN         => HUB_CTS_INFORMATION_IN,
      HUB_CTS_READOUT_TYPE_IN        => HUB_CTS_READOUT_TYPE_IN,
      HUB_CTS_START_READOUT_IN       => HUB_CTS_START_READOUT_IN,
      HUB_CTS_READOUT_FINISHED_OUT   => HUB_CTS_READOUT_FINISHED_OUT,
      HUB_CTS_STATUS_BITS_OUT        => HUB_CTS_STATUS_BITS_OUT,
      HUB_FEE_DATA_IN                => HUB_FEE_DATA_IN,
      HUB_FEE_DATAREADY_IN           => HUB_FEE_DATAREADY_IN,
      HUB_FEE_READ_OUT               => HUB_FEE_READ_OUT,
      HUB_FEE_STATUS_BITS_IN         => HUB_FEE_STATUS_BITS_IN,
      HUB_FEE_BUSY_IN                => HUB_FEE_BUSY_IN,

      -- connect to GbE
      GBE_CTS_NUMBER_OUT             => GBE_CTS_NUMBER_OUT,
      GBE_CTS_CODE_OUT               => GBE_CTS_CODE_OUT,
      GBE_CTS_INFORMATION_OUT        => GBE_CTS_INFORMATION_OUT,
      GBE_CTS_READOUT_TYPE_OUT       => GBE_CTS_READOUT_TYPE_OUT,
      GBE_CTS_START_READOUT_OUT      => GBE_CTS_START_READOUT_OUT,
      GBE_CTS_READOUT_FINISHED_IN    => GBE_CTS_READOUT_FINISHED_IN,
      GBE_CTS_STATUS_BITS_IN         => GBE_CTS_STATUS_BITS_IN,
      GBE_FEE_DATA_OUT               => GBE_FEE_DATA_OUT,
      GBE_FEE_DATAREADY_OUT          => GBE_FEE_DATAREADY_OUT,
      GBE_FEE_READ_IN                => GBE_FEE_READ_IN,
      GBE_FEE_STATUS_BITS_OUT        => GBE_FEE_STATUS_BITS_OUT,
      GBE_FEE_BUSY_OUT               => GBE_FEE_BUSY_OUT,

      -- reg io
      REGIO_ADDR_IN                  => cbm_rdo_regio_addr_i, -- in  std_logic_vector(15 downto 0);
      REGIO_DATA_IN                  => cbm_rdo_regio_data_ctrl_i, -- in  std_logic_vector(31 downto 0);
      REGIO_READ_ENABLE_IN           => cbm_rdo_regio_read_enable_i, -- in  std_logic;
      REGIO_WRITE_ENABLE_IN          => cbm_rdo_regio_write_enable_i, -- in  std_logic;
      REGIO_DATA_OUT                 => cbm_rdo_regio_data_status_i, -- out std_logic_vector(31 downto 0);
      REGIO_DATAREADY_OUT            => cbm_rdo_regio_dataready_i, -- out std_logic;
      REGIO_WRITE_ACK_OUT            => cbm_rdo_regio_write_ack_i, -- out std_logic;
      REGIO_UNKNOWN_ADDR_OUT         => cbm_rdo_regio_unknown_addr_i, -- out std_logic;

   -- CBMNet
      CBMNET_CLK_IN         => cbm_clk_i, -- in std_logic;
      CBMNET_RESET_IN       => cbm_reset_i, -- in std_logic;
      CBMNET_LINK_ACTIVE_IN => cbm_link_active_i, -- in std_logic;
         
      CBMNET_DATA2SEND_STOP_IN   => cbm_rdo_data2send_stop_i,  -- in std_logic;
      CBMNET_DATA2SEND_START_OUT => cbm_rdo_data2send_start_i, -- out std_logic;
      CBMNET_DATA2SEND_END_OUT   => cbm_rdo_data2send_end_i,   -- out std_logic;
      CBMNET_DATA2SEND_DATA_OUT  => cbm_rdo_data2send_i        -- out std_logic_vector(15 downto 0)         
   );
   
   
   THE_CBM_LINK_TESTER: link_tester_fe 
   generic map (
      MIN_PACKET_SIZE => 8,
      MAX_PACKET_SIZE => 64,
      PACKET_GRAN => 2,
      MIN_CTRL_PACKET_SIZE => 12,
      MAX_CTRL_PACKET_SIZE => 60,


      CTRL_PADDING => 16#A5A5#,
      OWN_ADDR => x"0000",
      DEST_ADDR => "0000000000000000",
      PACKET_MODE => 1 --if enabled generates another packet size order to test further corner cases
   ) port map (
      clk => cbm_clk_i , -- in std_logic;
      res_n => cbm_reset_n_i, -- in std_logic;
      link_active => cbm_link_active_i, -- in std_logic;

      data_en => cbm_lt_data_enable_crs_i, -- in std_logic;     -- enable data packet generation
      ctrl_en => cbm_lt_ctrl_enable_i, -- in std_logic;     -- enable ctrl packet generation
      force_rec_ctrl_stop => cbm_lt_force_stop_i, -- in std_logic;  -- force ctrl flow to stop

      ctrl2send_stop  => cbm_ctrl2send_stop_i, -- in std_logic;
      ctrl2send_start => cbm_ctrl2send_start_i, -- out std_logic;
      ctrl2send_end   => cbm_ctrl2send_end_i, -- out std_logic;
      ctrl2send       => cbm_ctrl2send_i, -- out std_logic_vector(15 downto 0);

      data2send_stop  => cbm_lt_data2send_stop_i, -- in std_logic;
      data2send_start => cbm_lt_data2send_start_i, -- out std_logic;
      data2send_end   => cbm_lt_data2send_end_i, -- out std_logic;
      data2send       => cbm_lt_data2send_i, -- out std_logic_vector(15 downto 0);

      dlm2send_valid => open, -- out std_logic;
      dlm2send => open, -- out std_logic_vector(3 downto 0);

      dlm_rec => cbm_dlm_rec_type_i, -- in std_logic_vector(3 downto 0);
      dlm_rec_valid => cbm_dlm_rec_va_i, -- in std_logic;

      data_rec_start => '0', -- in std_logic;
      data_rec_end => '0', -- in std_logic;
      data_rec => x"0000", -- in std_logic_vector(15 downto 0);
      data_rec_stop => open, -- out std_logic;

      ctrl_rec_start => '0', -- in std_logic;
      ctrl_rec_end => '0', -- in std_logic;
      ctrl_rec => x"0000", -- in std_logic_vector(15 downto 0);
      ctrl_rec_stop => open, -- out std_logic;

      ctrl_valid => cbm_lt_ctrl_valid_i, -- out std_logic;
      dlm_valid => cbm_lt_dlm_valid_i -- out std_logic
   );
   
   THE_SYNC_MODULE: cbmnet_sync_module port map (
   -- TRB
      TRB_CLK_IN      => TRB_CLK_IN, --  in std_logic;  
      TRB_RESET_IN    => TRB_RESET_IN, --  in std_logic;
      TRB_TRIGGER_OUT => TRB_TRIGGER_OUT, --  out std_logic;

      --data output for read-out
      TRB_TRIGGER_IN        => TRB_TRIGGER_IN, --  in  std_logic

      TRB_RDO_VALID_DATA_TRG_IN   => TRB_RDO_VALID_DATA_TRG_IN,
      TRB_RDO_VALID_NO_TIMING_IN  => TRB_RDO_VALID_NO_TIMING_IN,
      TRB_RDO_DATA_OUT      => TRB_RDO_DATA_OUT, --  out std_logic_vector(31 downto 0);
      TRB_RDO_WRITE_OUT     => TRB_RDO_WRITE_OUT, --  out std_logic;
      TRB_RDO_FINISHED_OUT  => TRB_RDO_FINISHED_OUT, --  out std_logic;
      TRB_RDO_STATUSBIT_OUT  => open,
      
      -- reg io
      TRB_REGIO_ADDR_IN(15 downto 4)      => x"000",
      TRB_REGIO_ADDR_IN(3 downto 0)       => cbm_sync_regio_addr_i, --  in  std_logic_vector(15 downto 0);
      TRB_REGIO_DATA_IN                   => cbm_sync_regio_config_data_i, --  in  std_logic_vector(31 downto 0);
      TRB_REGIO_READ_ENABLE_IN            => cbm_sync_regio_read_en_i, --  in  std_logic;
      TRB_REGIO_WRITE_ENABLE_IN           => cbm_sync_regio_write_en_i, --  in  std_logic;
      TRB_REGIO_DATA_OUT                  => cbm_sync_regio_status_data_i, --  out std_logic_vector(31 downto 0);
      TRB_REGIO_DATAREADY_OUT             => cbm_sync_regio_read_ack_i, --  out std_logic;
      TRB_REGIO_WRITE_ACK_OUT             => cbm_sync_regio_write_ack_i, --  out std_logic;
      TRB_REGIO_UNKNOWN_ADDR_OUT          => cbm_sync_regio_unknown_i, --  out std_logic;
      
   -- CBMNET
      CBM_CLK_IN            => cbm_clk_i,     --  in std_logic;
      CBM_CLK_250_IN        => cbm_clk250_i,
      CBM_RESET_IN          => cbm_reset_i,   --  in std_logic;
      CBM_LINK_ACTIVE_IN    => cbm_link_active_i,
      CBM_PHY_BARREL_SHIFTER_POS_IN  => x"0", --  in std_logic_vector(3 downto 0);
      
      CBM_TIMING_TRIGGER_OUT => CBM_TIMING_TRIGGER_OUT,
      
      -- DLM port
      CBM_DLM_REC_IN        => cbm_dlm_rec_type_i,    --  in std_logic_vector(3 downto 0);
      CBM_DLM_REC_VALID_IN  => cbm_dlm_rec_va_i,      --  in std_logic;
      CBM_DLM_SENSE_OUT     => CBM_DLM_OUT, --  out std_logic;
      CBM_PULSER_OUT        => CBM_SYNC_PULSER_OUT,     --  out std_logic; -- connect to TDC
      
      -- Ctrl port
      CBM_CTRL_DATA_IN         => cbm_ctrl_rec_i,       --  in std_logic_vector(15 downto 0);
      CBM_CTRL_DATA_START_IN   => cbm_ctrl_rec_start_i, --  in std_logic;
      CBM_CTRL_DATA_END_IN     => cbm_ctrl_rec_end_i,   --  in std_logic;
      CBM_CTRL_DATA_STOP_OUT   => cbm_ctrl_rec_stop_i,  --  out std_logic;
      
      
      DEBUG_OUT       => open --  out std_logic_vector(31 downto 0)    
   );      

   cbm_lt_data_enable_buf_i <= cbm_lt_data_enable_i     when rising_edge(cbm_clk_i);
   cbm_lt_data_enable_crs_i <= cbm_lt_data_enable_buf_i when rising_edge(cbm_clk_i);
   
   cbm_data_mux_buf_i <= cbm_data_mux_i     when rising_edge(cbm_clk_i);
   cbm_data_mux_crs_i <= cbm_data_mux_buf_i when rising_edge(cbm_clk_i);
   
   cbm_data2send_start_i <= cbm_lt_data2send_start_i when cbm_data_mux_crs_i = '1' else cbm_rdo_data2send_start_i;
   cbm_data2send_end_i   <= cbm_lt_data2send_end_i   when cbm_data_mux_crs_i = '1' else cbm_rdo_data2send_end_i;
   cbm_data2send_i       <= cbm_lt_data2send_i       when cbm_data_mux_crs_i = '1' else cbm_rdo_data2send_i;
   cbm_lt_data2send_stop_i   <= (not cbm_data_mux_crs_i) or cbm_data2send_stop_i;
   cbm_rdo_data2send_stop_i  <= cbm_data_mux_crs_i or cbm_data2send_stop_i;
   
   cbm_data_rec_stop_i <= '1';
   
   THE_BUS_HANDLER : trb_net16_regio_bus_handler
   generic map(
      PORT_NUMBER    => 3,
      PORT_ADDRESSES => (0 => x"0000", 1 => x"0080", 2 => x"0100",  others => x"0000"),
      PORT_ADDR_MASK => (0 => 7,       1 => 7,       2 => 7,        others => 0)
   )
   port map(
      CLK                   => TRB_CLK_IN,
      RESET                 => TRB_RESET_IN,

      DAT_ADDR_IN(8 downto 0)  => REGIO_ADDR_IN(8 downto 0),
      DAT_ADDR_IN(15 downto 9) => (others => '0'),
      DAT_DATA_IN           => REGIO_DATA_IN,
      DAT_DATA_OUT          => REGIO_DATA_OUT,
      DAT_READ_ENABLE_IN    => REGIO_READ_ENABLE_IN,
      DAT_WRITE_ENABLE_IN   => REGIO_WRITE_ENABLE_IN,
      DAT_TIMEOUT_IN        => REGIO_TIMEOUT_IN,
      DAT_DATAREADY_OUT     => REGIO_DATAREADY_OUT,
      DAT_WRITE_ACK_OUT     => REGIO_WRITE_ACK_OUT,
      DAT_NO_MORE_DATA_OUT  => REGIO_NO_MORE_DATA_OUT,
      DAT_UNKNOWN_ADDR_OUT  => REGIO_UNKNOWN_ADDR_OUT,
      
      --CBMNet (read-out)
      BUS_READ_ENABLE_OUT(0)              => cbm_rdo_regio_read_enable_i,
      BUS_WRITE_ENABLE_OUT(0)             => cbm_rdo_regio_write_enable_i,
      BUS_DATA_OUT(0*32+31 downto 0*32)  => cbm_rdo_regio_data_ctrl_i,
      BUS_ADDR_OUT(0*16+15 downto 0*16)  => cbm_rdo_regio_addr_i,
      BUS_TIMEOUT_OUT(0)                  => open,
      BUS_DATA_IN(0*32+31 downto 0*32)   => cbm_rdo_regio_data_status_i,
      BUS_DATAREADY_IN(0)                 => cbm_rdo_regio_dataready_i,
      BUS_WRITE_ACK_IN(0)                 => cbm_rdo_regio_write_ack_i,
      BUS_NO_MORE_DATA_IN(0)              => '0',
      BUS_UNKNOWN_ADDR_IN(0)              => cbm_rdo_regio_unknown_addr_i,  

      --CBMNet (phy)
      BUS_READ_ENABLE_OUT(1)              => cbm_phy_regio_read_enable_i,
      BUS_WRITE_ENABLE_OUT(1)             => cbm_phy_regio_write_enable_i,
      BUS_DATA_OUT(1*32+31 downto 1*32)  => cbm_phy_regio_data_ctrl_i,
      BUS_ADDR_OUT(1*16+15 downto 1*16)  => cbm_phy_regio_addr_i,
      BUS_TIMEOUT_OUT(1)                  => open,
      BUS_DATA_IN(1*32+31 downto 1*32)   => cbm_phy_regio_data_status_i,
      BUS_DATAREADY_IN(1)                 => cbm_phy_regio_dataready_i,
      BUS_WRITE_ACK_IN(1)                 => cbm_phy_regio_write_ack_i,
      BUS_NO_MORE_DATA_IN(1)              => '0',
      BUS_UNKNOWN_ADDR_IN(1)              => cbm_phy_regio_unknown_addr_i,  

      --CBMNet (sync)
      BUS_READ_ENABLE_OUT(2)              => cbm_sync_regio_read_en_i,
      BUS_WRITE_ENABLE_OUT(2)             => cbm_sync_regio_write_en_i,
      BUS_DATA_OUT(2*32+31 downto 2*32)   => cbm_sync_regio_config_data_i,
      BUS_ADDR_OUT(2*16+3 downto 2*16)    => cbm_sync_regio_addr_i,
      BUS_ADDR_OUT(2*16+15 downto 2*16+4) => open,
      BUS_TIMEOUT_OUT(2)                  => open,
      BUS_DATA_IN(2*32+31 downto 2*32)    => cbm_sync_regio_status_data_i,
      BUS_DATAREADY_IN(2)                 => cbm_sync_regio_read_ack_i,
      BUS_WRITE_ACK_IN(2)                 => cbm_sync_regio_write_ack_i,
      BUS_NO_MORE_DATA_IN(2)              => '0',
      BUS_UNKNOWN_ADDR_IN(2)              => cbm_sync_regio_unknown_i,
      
      stat_debug => open
   );
   
   
end architecture;