library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;  
   use work.cbmnet_interface_pkg.all;
   
entity tb_cbmnet_readout2 is
end tb_cbmnet_readout2;

architecture TB of tb_cbmnet_readout2 is
   component TB_CBMNET_LOGGER is
      generic (
         log_file : string
      );
      port (
         CLK_IN : in std_logic;
         RESET_IN : in std_logic;
         LINK_ACTIVE_IN : in std_logic;

         DATA2SEND_IN : std_logic_vector(15 downto 0);
         DATA2SEND_STOP_IN : std_logic;
         DATA2SEND_START_IN : std_logic;
         DATA2SEND_END_IN : std_logic
      );
   end component;


   signal CLK_IN   : std_logic := '0';
   signal RESET_IN : std_logic := '0';

   -- connect to hub
   signal HUB_CTS_NUMBER_IN              :  std_logic_vector (15 downto 0) := (others => '0');
   signal HUB_CTS_CODE_IN                :  std_logic_vector (7  downto 0) := (others => '0');
   signal HUB_CTS_INFORMATION_IN         :  std_logic_vector (7  downto 0) := (others => '0');
   signal HUB_CTS_READOUT_TYPE_IN        :  std_logic_vector (3  downto 0) := (others => '0');
   signal HUB_CTS_START_READOUT_IN       :  std_logic := '0';
   signal HUB_CTS_READOUT_FINISHED_OUT   :  std_logic := '0';  --no more data, end transfer, send TRM
   signal HUB_CTS_STATUS_BITS_OUT        :  std_logic_vector (31 downto 0) := (others => '0');
   signal HUB_FEE_DATA_IN                :  std_logic_vector (15 downto 0) := (others => '0');
   signal HUB_FEE_DATAREADY_IN           :  std_logic := '0';
   signal HUB_FEE_READ_OUT               :  std_logic := '0';  --must be high when idle, otherwise you will never get a dataready
   signal HUB_FEE_STATUS_BITS_IN         :  std_logic_vector (31 downto 0) := (others => '0');
   signal HUB_FEE_BUSY_IN                :  std_logic := '0';   

   -- connect to GbE
   signal GBE_CTS_NUMBER_OUT             :  std_logic_vector (15 downto 0) := (others => '0');
   signal GBE_CTS_CODE_OUT               :  std_logic_vector (7  downto 0) := (others => '0');
   signal GBE_CTS_INFORMATION_OUT        :  std_logic_vector (7  downto 0) := (others => '0');
   signal GBE_CTS_READOUT_TYPE_OUT       :  std_logic_vector (3  downto 0) := (others => '0');
   signal GBE_CTS_START_READOUT_OUT      :  std_logic := '0';
   signal GBE_CTS_READOUT_FINISHED_IN    :  std_logic := '0';      --no more data, end transfer, send TRM
   signal GBE_CTS_STATUS_BITS_IN         :  std_logic_vector (31 downto 0) := (others => '0');
   signal GBE_FEE_DATA_OUT               :  std_logic_vector (15 downto 0) := (others => '0');
   signal GBE_FEE_DATAREADY_OUT          :  std_logic := '0';
   signal GBE_FEE_READ_IN                :  std_logic := '0';  --must be high when idle, otherwise you will never get a dataready
   signal GBE_FEE_STATUS_BITS_OUT        :  std_logic_vector (31 downto 0) := (others => '0');
   signal GBE_FEE_BUSY_OUT               :  std_logic := '0';

   -- reg io
   signal REGIO_ADDR_IN                  :  std_logic_vector(15 downto 0) := (others => '0');
   signal REGIO_DATA_IN                  :  std_logic_vector(31 downto 0) := (others => '0');
   signal REGIO_READ_ENABLE_IN           :  std_logic := '0';
   signal REGIO_WRITE_ENABLE_IN          :  std_logic := '0';
   signal REGIO_DATA_OUT                 :  std_logic_vector(31 downto 0) := (others => '0');
   signal REGIO_DATAREADY_OUT            :  std_logic := '0';
   signal REGIO_WRITE_ACK_OUT            :  std_logic := '0';
   signal REGIO_UNKNOWN_ADDR_OUT         :  std_logic := '0';

   -- CBMNet
   signal CBMNET_CLK_IN     : std_logic := '0';
   signal CBMNET_RESET_IN   : std_logic := '0';
   signal CBMNET_LINK_ACTIVE_IN : std_logic := '0';

   signal CBMNET_DATA2SEND_STOP_IN   : std_logic := '0';
   signal CBMNET_DATA2SEND_START_OUT :  std_logic := '0';
   signal CBMNET_DATA2SEND_END_OUT   :  std_logic := '0';
   signal CBMNET_DATA2SEND_DATA_OUT  :  std_logic_vector(15 downto 0) := (others => '0');

   signal send_wait_counter_i : unsigned(31 downto 0);
   signal send_wait_threshold_i : unsigned(31 downto 0) := x"0000_0010";

   signal event_id : unsigned(15 downto 0) := x"0000";
   signal send_length_i : unsigned(15 downto 0) := x"0100";
   signal send_counter_i : unsigned(15 downto 0);

   signal send_enabled_i : std_logic := '0';
   
   
   type TRB_FSM_T is (IDLE, START_READOUT, START_READOUT_WAIT, FEE_BUSY, SEND_EINF_H, SEND_EINF_L, SEND_LENGTH, SEND_SOURCE, SEND_SOURCE_WAIT, SEND_PAYLOAD_H, SEND_PAYLOAD_L, COMPL_WAIT, COMPL_NOT_BUSY_WAIT, EVT_WAIT);
   signal trb_fsm_i : TRB_FSM_T;
   
   
   -- FEEs
   signal fee_cbm_data_from_link_i, flib_cbm_data2link_i, flib_cbm_data_from_link_i, fee_cbm_data2link_i : std_logic_vector(17 downto 0);
   signal flib_cbm_serdes_ready_i, fee_cbm_serdes_ready_i, flib_cbm_link_active_i, fee_cbm_link_active_i : std_logic;
   signal cbm_reset_n_i1, cbm_reset_n_i2 : std_logic;
   signal flib_data_rec_i : std_logic_vector(15 downto 0);
   signal flib_data_rec_start_i, flib_data_rec_end_i, flib_data_rec_stop_i : std_logic := '0';
   
begin
   REGIO_ADDR_IN <= (others => '0');
   REGIO_DATA_IN <= x"0000_0001";
   REGIO_WRITE_ENABLE_IN <= '1';

   CLK_IN <= not CLK_IN after 5 ns;
   RESET_IN <= '1', '0' after 20 ns;
   
   CBMNET_CLK_IN <= not CBMNET_CLK_IN after 4 ns;
   CBMNET_RESET_IN <= '1', '0' after 40 ns;
--    CBMNET_LINK_ACTIVE_IN <= '0', '1' after 50 us;
   
   gbe_fee_read_in <= '1';
   gbe_cts_status_bits_in <= x"beafc0de";
   
   send_enabled_i <= '0', '1' after 100 ns;
   
   process is
      variable wait_cnt_v : integer range 0 to 15 := 0;

      variable seed1, seed2: positive;               -- seed values for random generator
      variable rand: real;                           -- random real-number value in range 0 to 1.0
      variable int_rand: integer;                    -- random integer value in range 0..4095
      
      
   begin
      wait until rising_edge(CLK_IN);
      
      HUB_CTS_START_READOUT_IN <= '1';
      HUB_FEE_BUSY_IN <= '1';
      HUB_FEE_DATAREADY_IN <= '0';
      
      case(trb_fsm_i) is
         when IDLE =>
            HUB_CTS_START_READOUT_IN <= '0';
            HUB_FEE_BUSY_IN <= '0';
            if send_enabled_i = '1' then
               trb_fsm_i <= START_READOUT;
            end if;
            
         when START_READOUT => 
            trb_fsm_i <= START_READOUT_WAIT;
            wait_cnt_v := 10;
            HUB_FEE_BUSY_IN <= '0';
            event_id <= event_id + 1;
            
         when START_READOUT_WAIT => 
            if wait_cnt_v = 0 then
               trb_fsm_i <= FEE_BUSY;
               wait_cnt_v := 5;
            else
               wait_cnt_v := wait_cnt_v - 1;
            end if;
            
            HUB_FEE_BUSY_IN <= '0';
         
         when FEE_BUSY =>
            if wait_cnt_v = 0 then
               trb_fsm_i <= SEND_EINF_H;
            else
               wait_cnt_v := wait_cnt_v - 1;
            end if;
            
            HUB_FEE_BUSY_IN <= '1';
            
         when SEND_EINF_H =>
            HUB_FEE_DATA_IN <= x"8765";
            HUB_FEE_DATAREADY_IN <= '1';
            trb_fsm_i <= SEND_EINF_L;
         when SEND_EINF_L =>
            HUB_FEE_DATA_IN <= std_logic_vector(event_id);
            HUB_FEE_DATAREADY_IN <= '1';
            trb_fsm_i <= SEND_LENGTH;
            
         when SEND_LENGTH =>
            HUB_FEE_DATA_IN <= std_logic_vector(send_length_i);
            send_counter_i <= send_length_i;
            HUB_FEE_DATAREADY_IN <= '1';
            trb_fsm_i <= SEND_SOURCE;
         when SEND_SOURCE =>
            HUB_FEE_DATA_IN <= x"affe";
            HUB_FEE_DATAREADY_IN <= '1';
            trb_fsm_i <= SEND_SOURCE_WAIT;

         when SEND_SOURCE_WAIT =>
            trb_fsm_i <= SEND_PAYLOAD_H;
            
         when SEND_PAYLOAD_H =>
            HUB_FEE_DATA_IN <= x"bb" & std_logic_vector(event_id(7 downto 0));
            HUB_FEE_DATAREADY_IN <= '1';
            trb_fsm_i <= SEND_PAYLOAD_L;
            
         when SEND_PAYLOAD_L =>
            HUB_FEE_DATA_IN <= x"c" & std_logic_vector(send_counter_i(11 downto 0));
            HUB_FEE_DATAREADY_IN <= '1';
            trb_fsm_i <= SEND_PAYLOAD_H;
            send_counter_i <= send_counter_i - 1;
            
            if send_counter_i = 1 then
               trb_fsm_i <= COMPL_WAIT;
               wait_cnt_v := 5;
            end if;
            
         when COMPL_WAIT =>
            if wait_cnt_v = 0 then
               wait_cnt_v := 5;
               trb_fsm_i <= COMPL_NOT_BUSY_WAIT;
            else
               wait_cnt_v := wait_cnt_v - 1;
            end if;
            
            HUB_FEE_BUSY_IN <= '1';

         
         when COMPL_NOT_BUSY_WAIT => 
            HUB_CTS_START_READOUT_IN <= '0';
            if wait_cnt_v = 0 then
               trb_fsm_i <= EVT_WAIT;
               wait_cnt_v := 5;
            else
               wait_cnt_v := wait_cnt_v - 1;
            end if;
            
            HUB_FEE_BUSY_IN <= '0';
            send_wait_counter_i <= (others => '0');
            
            
         when EVT_WAIT =>
            HUB_CTS_START_READOUT_IN <= '0';
            HUB_FEE_BUSY_IN <= '0';

            send_wait_counter_i <= send_wait_counter_i + 1;
            if send_wait_counter_i >= UNSIGNED(send_wait_threshold_i) then
               --send_length_i(8 downto 0) <= send_length_i(8 downto 0) + 1;
               --if send_length_i = x"01ff" then
               --   send_length_i <= x"0001";
               --end if;
               
               uniform(seed1, seed2, rand);
               int_rand := 2+integer(trunc(rand*990.0));
               --int_rand := 2;
               send_length_i(9 downto 0) <= TO_UNSIGNED(int_rand, 10);
               
               trb_fsm_i <= IDLE;
            end if;
            
      end case;
   end process;
      
   
   PROC_CBMNET: process is
      variable wait_dur : integer range 0 to 10000 := 4;
      variable seed1, seed2: positive;               -- seed values for random generator
      variable rand: real;                           -- random real-number value in range 0 to 1.0
      variable int_rand: integer;                    -- random integer value in range 0..4095
   begin
      flib_data_rec_stop_i <= '0';
      wait until rising_edge(CBMNET_CLK_IN);
      uniform(seed1, seed2, rand);
      int_rand := 4+integer(trunc(rand*10000.0));
      wait for int_rand * 8 ns;

      flib_data_rec_stop_i <= '1';
      wait until rising_edge(CBMNET_CLK_IN);
      uniform(seed1, seed2, rand);
      int_rand := 4+integer(trunc(rand*256.0));
      wait for int_rand * 8 ns;
   end process;

   --GBE_FEE_READ_IN <= HUB_FEE_DATAREADY_IN;

   DUT: cbmnet_readout
   port map (
      CLK_IN   => CLK_IN,    -- in std_logic;
      RESET_IN => RESET_IN,  -- in std_logic;

      -- connect to hub
      HUB_CTS_NUMBER_IN              => HUB_CTS_NUMBER_IN,               -- in  std_logic_vector (15 downto 0);
      HUB_CTS_CODE_IN                => HUB_CTS_CODE_IN,                 -- in  std_logic_vector (7  downto 0);
      HUB_CTS_INFORMATION_IN         => HUB_CTS_INFORMATION_IN,          -- in  std_logic_vector (7  downto 0);
      HUB_CTS_READOUT_TYPE_IN        => HUB_CTS_READOUT_TYPE_IN,         -- in  std_logic_vector (3  downto 0);
      HUB_CTS_START_READOUT_IN       => HUB_CTS_START_READOUT_IN,        -- in  std_logic;
      HUB_CTS_READOUT_FINISHED_OUT   => HUB_CTS_READOUT_FINISHED_OUT,    -- out std_logic;  --no more data, end transfer, send TRM
      HUB_CTS_STATUS_BITS_OUT        => HUB_CTS_STATUS_BITS_OUT,         -- out std_logic_vector (31 downto 0);
      HUB_FEE_DATA_IN                => HUB_FEE_DATA_IN,                 -- in  std_logic_vector (15 downto 0);
      HUB_FEE_DATAREADY_IN           => HUB_FEE_DATAREADY_IN,            -- in  std_logic;
      HUB_FEE_READ_OUT               => HUB_FEE_READ_OUT,                -- out std_logic;  --must be high when idle, otherwise you will never get a dataready
      HUB_FEE_STATUS_BITS_IN         => HUB_FEE_STATUS_BITS_IN,          -- in  std_logic_vector (31 downto 0);
      HUB_FEE_BUSY_IN                => HUB_FEE_BUSY_IN,                 -- in  std_logic;   

      -- connect to GbE
      GBE_CTS_NUMBER_OUT             => GBE_CTS_NUMBER_OUT,              -- out std_logic_vector (15 downto 0);
      GBE_CTS_CODE_OUT               => GBE_CTS_CODE_OUT,                -- out std_logic_vector (7  downto 0);
      GBE_CTS_INFORMATION_OUT        => GBE_CTS_INFORMATION_OUT,         -- out std_logic_vector (7  downto 0);
      GBE_CTS_READOUT_TYPE_OUT       => GBE_CTS_READOUT_TYPE_OUT,        -- out std_logic_vector (3  downto 0);
      GBE_CTS_START_READOUT_OUT      => GBE_CTS_START_READOUT_OUT,       -- out std_logic;
      GBE_CTS_READOUT_FINISHED_IN    => GBE_CTS_READOUT_FINISHED_IN,     -- in  std_logic;      --no more data, end transfer, send TRM
      GBE_CTS_STATUS_BITS_IN         => GBE_CTS_STATUS_BITS_IN,          -- in  std_logic_vector (31 downto 0);
      GBE_FEE_DATA_OUT               => GBE_FEE_DATA_OUT,                -- out std_logic_vector (15 downto 0);
      GBE_FEE_DATAREADY_OUT          => GBE_FEE_DATAREADY_OUT,           -- out std_logic;
      GBE_FEE_READ_IN                => GBE_FEE_READ_IN,                 -- in  std_logic;  --must be high when idle, otherwise you will never get a dataready
      GBE_FEE_STATUS_BITS_OUT        => GBE_FEE_STATUS_BITS_OUT,         -- out std_logic_vector (31 downto 0);
      GBE_FEE_BUSY_OUT               => GBE_FEE_BUSY_OUT,                -- out std_logic;

      -- reg io
      REGIO_ADDR_IN                  => REGIO_ADDR_IN,                   -- in  std_logic_vector(15 downto 0);
      REGIO_DATA_IN                  => REGIO_DATA_IN,                   -- in  std_logic_vector(31 downto 0);
      REGIO_READ_ENABLE_IN           => REGIO_READ_ENABLE_IN,            -- in  std_logic;
      REGIO_WRITE_ENABLE_IN          => REGIO_WRITE_ENABLE_IN,           -- in  std_logic;
      REGIO_DATA_OUT                 => REGIO_DATA_OUT,                  -- out std_logic_vector(31 downto 0);
      REGIO_DATAREADY_OUT            => REGIO_DATAREADY_OUT,             -- out std_logic;
      REGIO_WRITE_ACK_OUT            => REGIO_WRITE_ACK_OUT,             -- out std_logic;
      REGIO_UNKNOWN_ADDR_OUT         => REGIO_UNKNOWN_ADDR_OUT,          -- out std_logic;

      -- CBMNet
      CBMNET_CLK_IN     => CBMNET_CLK_IN,      -- in std_logic;
      CBMNET_RESET_IN   => CBMNET_RESET_IN,    -- in std_logic;
      CBMNET_LINK_ACTIVE_IN => CBMNET_LINK_ACTIVE_IN,  -- in std_logic;

      CBMNET_DATA2SEND_STOP_IN   => CBMNET_DATA2SEND_STOP_IN,    -- in std_logic;
      CBMNET_DATA2SEND_START_OUT => CBMNET_DATA2SEND_START_OUT,  -- out std_logic;
      CBMNET_DATA2SEND_END_OUT   => CBMNET_DATA2SEND_END_OUT,    -- out std_logic;
      CBMNET_DATA2SEND_DATA_OUT  =>CBMNET_DATA2SEND_DATA_OUT     -- out std_logic_vector(15 downto 0)
   );
   CBMNET_LINK_ACTIVE_IN <= fee_cbm_link_active_i;
   
   
   THE_FEE_ENDPOINT: lp_top 
   generic map (
      NUM_LANES => 1,
      TX_SLAVE  => 0
   )
   port map (
   -- Clk & Reset
      clk => CBMNET_CLK_IN,
      res_n => cbm_reset_n_i1,

   -- Phy
      data_from_link => fee_cbm_data_from_link_i,
      data2link => fee_cbm_data2link_i,
      link_activeovr => '0',
      link_readyovr => '0', 
      SERDES_ready => fee_cbm_serdes_ready_i,

   -- CBMNet Interface
      link_active => fee_cbm_link_active_i,
      ctrl2send_stop => open,
      ctrl2send_start => '0',
      ctrl2send_end => '0',
      ctrl2send => x"0000",
      
      data2send_stop(0) => CBMNET_DATA2SEND_STOP_IN,
      data2send_start(0) => CBMNET_DATA2SEND_START_OUT,
      data2send_end(0) => CBMNET_DATA2SEND_END_OUT,
      data2send => CBMNET_DATA2SEND_DATA_OUT,
      
      dlm2send_va => '0',
      dlm2send => x"0",
      
      dlm_rec_type => open,
      dlm_rec_va => open,

      data_rec => open,
      data_rec_start => open,
      data_rec_end => open,
      data_rec_stop => "0",
      
      ctrl_rec => open,
      ctrl_rec_start => open,
      ctrl_rec_end => open,
      ctrl_rec_stop => '0',
      
      -- diagnostics Lane0
      crc_error_cntr_flag_0     => open,      --  out std_logic;
      retrans_cntr_flag_0       => open,        --  out std_logic;
      retrans_error_cntr_flag_0 => open,  --  out std_logic;
      crc_error_cntr_0          => open,           --  out std_logic_vector(15 downto 0);
      retrans_cntr_0            => open,             --  out std_logic_vector(15 downto 0);
      retrans_error_cntr_0      => open,       --  out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_0      => '0',       --  in std_logic;
      retrans_cntr_clr_0        => '0',         --  in std_logic;
      retrans_error_cntr_clr_0  => '0',   --  in std_logic;

      -- diagnostics Lane1
      crc_error_cntr_flag_1     => open, -- out std_logic;
      retrans_cntr_flag_1       => open, -- out std_logic;
      retrans_error_cntr_flag_1 => open, -- out std_logic;
      crc_error_cntr_1          => open, -- out std_logic_vector(15 downto 0);
      retrans_cntr_1            => open, -- out std_logic_vector(15 downto 0);
      retrans_error_cntr_1      => open, -- out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_1      => '0', -- in std_logic;   
      retrans_cntr_clr_1        => '0', -- in std_logic;    
      retrans_error_cntr_clr_1  => '0', -- in std_logic; 

      -- diagnostics Lane2
      crc_error_cntr_flag_2     => open, -- out std_logic;
      retrans_cntr_flag_2       => open, -- out std_logic;
      retrans_error_cntr_flag_2 => open, -- out std_logic;
      crc_error_cntr_2          => open, -- out std_logic_vector(15 downto 0);
      retrans_cntr_2            => open, -- out std_logic_vector(15 downto 0);
      retrans_error_cntr_2      => open, -- out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_2      => '0', -- in std_logic;   
      retrans_cntr_clr_2        => '0', -- in std_logic;    
      retrans_error_cntr_clr_2  => '0', -- in std_logic; 

      -- diagnostics Lane3
      crc_error_cntr_flag_3     => open, -- out std_logic;
      retrans_cntr_flag_3       => open, -- out std_logic;
      retrans_error_cntr_flag_3 => open, -- out std_logic;
      crc_error_cntr_3          => open, -- out std_logic_vector(15 downto 0);
      retrans_cntr_3            => open, -- out std_logic_vector(15 downto 0);
      retrans_error_cntr_3      => open, -- out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_3      => '0', -- in std_logic;   
      retrans_cntr_clr_3        => '0', -- in std_logic;    
      retrans_error_cntr_clr_3  => '0'  -- in std_logic
   );   
   
   fee_cbm_data_from_link_i  <= flib_cbm_data2link_i when rising_edge(CBMNET_CLK_IN);
   flib_cbm_data_from_link_i <= fee_cbm_data2link_i  when rising_edge(CBMNET_CLK_IN);
   
   fee_cbm_serdes_ready_i <= '0', '1' after 100 ns;
   flib_cbm_serdes_ready_i <= '0', '1' after 100 ns;

   cbm_reset_n_i2 <= not CBMNET_RESET_IN;
   cbm_reset_n_i1 <= transport not CBMNET_RESET_IN  after 40 ns;

   THE_FLIB_ENDPOINT: lp_top 
   generic map (
      NUM_LANES => 1,
      TX_SLAVE  => 0
   )
   port map (
   -- Clk & Reset
      clk => CBMNET_CLK_IN,
      res_n => cbm_reset_n_i2,

   -- Phy
      data_from_link => flib_cbm_data_from_link_i,
      data2link => flib_cbm_data2link_i,
      link_activeovr => '0',
      link_readyovr => '0', 
      SERDES_ready => flib_cbm_serdes_ready_i,

   -- CBMNet Interface
      link_active => flib_cbm_link_active_i,
      ctrl2send_stop => open,
      ctrl2send_start => '0',
      ctrl2send_end => '0',
      ctrl2send => x"0000",
      
      data2send_stop => open,
      data2send_start => "0",
      data2send_end => "0",
      data2send => x"0000",
      
      dlm2send_va => '0',
      dlm2send => x"0",
      
      dlm_rec_type => open,
      dlm_rec_va => open,

      data_rec => flib_data_rec_i,
      data_rec_start(0) => flib_data_rec_start_i,
      data_rec_end(0) => flib_data_rec_end_i,
      data_rec_stop(0) => flib_data_rec_stop_i,
      
      ctrl_rec => open,
      ctrl_rec_start => open,
      ctrl_rec_end => open,
      ctrl_rec_stop => '0',
      
      -- diagnostics Lane0
      crc_error_cntr_flag_0     => open,      --  out std_logic;
      retrans_cntr_flag_0       => open,        --  out std_logic;
      retrans_error_cntr_flag_0 => open,  --  out std_logic;
      crc_error_cntr_0          => open,           --  out std_logic_vector(15 downto 0);
      retrans_cntr_0            => open,             --  out std_logic_vector(15 downto 0);
      retrans_error_cntr_0      => open,       --  out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_0      => '0',       --  in std_logic;
      retrans_cntr_clr_0        => '0',         --  in std_logic;
      retrans_error_cntr_clr_0  => '0',   --  in std_logic;

      -- diagnostics Lane1
      crc_error_cntr_flag_1     => open, -- out std_logic;
      retrans_cntr_flag_1       => open, -- out std_logic;
      retrans_error_cntr_flag_1 => open, -- out std_logic;
      crc_error_cntr_1          => open, -- out std_logic_vector(15 downto 0);
      retrans_cntr_1            => open, -- out std_logic_vector(15 downto 0);
      retrans_error_cntr_1      => open, -- out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_1      => '0', -- in std_logic;   
      retrans_cntr_clr_1        => '0', -- in std_logic;    
      retrans_error_cntr_clr_1  => '0', -- in std_logic; 

      -- diagnostics Lane2
      crc_error_cntr_flag_2     => open, -- out std_logic;
      retrans_cntr_flag_2       => open, -- out std_logic;
      retrans_error_cntr_flag_2 => open, -- out std_logic;
      crc_error_cntr_2          => open, -- out std_logic_vector(15 downto 0);
      retrans_cntr_2            => open, -- out std_logic_vector(15 downto 0);
      retrans_error_cntr_2      => open, -- out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_2      => '0', -- in std_logic;   
      retrans_cntr_clr_2        => '0', -- in std_logic;    
      retrans_error_cntr_clr_2  => '0', -- in std_logic; 

      -- diagnostics Lane3
      crc_error_cntr_flag_3     => open, -- out std_logic;
      retrans_cntr_flag_3       => open, -- out std_logic;
      retrans_error_cntr_flag_3 => open, -- out std_logic;
      crc_error_cntr_3          => open, -- out std_logic_vector(15 downto 0);
      retrans_cntr_3            => open, -- out std_logic_vector(15 downto 0);
      retrans_error_cntr_3      => open, -- out std_logic_vector(15 downto 0);
      crc_error_cntr_clr_3      => '0', -- in std_logic;   
      retrans_cntr_clr_3        => '0', -- in std_logic;    
      retrans_error_cntr_clr_3  => '0'  -- in std_logic
   );   
   
   
   
   
   THE_LOGGER : TB_CBMNET_LOGGER 
   generic map (log_file => "frames2.txt")
   port map (
      CLK_IN => CBMNET_CLK_IN, --  in std_logic;
      RESET_IN => CBMNET_RESET_IN, --  in std_logic;
      LINK_ACTIVE_IN => CBMNET_LINK_ACTIVE_IN, --  in std_logic;

      DATA2SEND_IN => CBMNET_DATA2SEND_DATA_OUT, --  std_logic_vector(15 downto 0);
      DATA2SEND_STOP_IN => CBMNET_DATA2SEND_STOP_IN, --  std_logic;
      DATA2SEND_START_IN => CBMNET_DATA2SEND_START_OUT, --  std_logic;
      DATA2SEND_END_IN => CBMNET_DATA2SEND_END_OUT --  std_logic
   );

   THE_LOGGER_RECV : TB_CBMNET_LOGGER 
   generic map (log_file => "recv_frames2.txt")
   port map (
      CLK_IN => CBMNET_CLK_IN, --  in std_logic;
      RESET_IN => CBMNET_RESET_IN, --  in std_logic;
      LINK_ACTIVE_IN => flib_cbm_link_active_i, --  in std_logic;

      DATA2SEND_IN => flib_data_rec_i, --  std_logic_vector(15 downto 0);
      DATA2SEND_STOP_IN => '0', --  std_logic;
      DATA2SEND_START_IN => flib_data_rec_start_i, --  std_logic;
      DATA2SEND_END_IN => flib_data_rec_end_i --  std_logic
   );

end architecture;