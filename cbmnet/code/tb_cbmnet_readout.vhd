library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.cbmnet_interface_pkg.all;

entity tb_cbmnet_readout is
end tb_cbmnet_readout;

architecture TB of tb_cbmnet_readout is
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
begin
   CLK_IN <= not CLK_IN after 5 ns;
   RESET_IN <= '1', '0' after 30 ns;
   
   CBMNET_CLK_IN <= not CBMNET_CLK_IN after 4 ns;
   CBMNET_RESET_IN <= '1', '0' after 20 ns;
   CBMNET_LINK_ACTIVE_IN <= '1';
   
   PROC_TRBNET: process is 
      variable evt_num : integer := 16#1234#;
      variable trg_code : std_logic_vector(7 downto 0) := x"ab";
      variable trg_type : std_logic_vector(3 downto 0) := x"e";
      variable trg_conf : std_logic_vector(3 downto 0) := x"0";
   begin
      wait for 100 ns;
      
      HUB_CTS_START_READOUT_IN <= '1';
      HUB_CTS_NUMBER_IN <= STD_LOGIC_VECTOR(TO_UNSIGNED(evt_num, 16));
      evt_num := evt_num + 1;
      HUB_CTS_READOUT_TYPE_IN <= x"e";
      GBE_CTS_STATUS_BITS_IN <= x"12345678";
      
      wait until rising_edge(CLK_IN);
      wait until rising_edge(CLK_IN);
      wait until rising_edge(CLK_IN);
      wait until rising_edge(CLK_IN);
      HUB_FEE_BUSY_IN <= '1';
      wait until rising_edge(CLK_IN);
      wait until rising_edge(CLK_IN);
      wait until rising_edge(CLK_IN);
      wait until rising_edge(CLK_IN);

      for i in 0 to 103 loop
         case i is
            when 0 => HUB_FEE_DATA_IN <= trg_conf & trg_type & trg_code;
            when 1 => HUB_FEE_DATA_IN <= HUB_CTS_NUMBER_IN;
            when 2 => HUB_FEE_DATA_IN <= STD_LOGIC_VECTOR(TO_UNSIGNED(50, 16));
            when 3 => HUB_FEE_DATA_IN <= x"affe";
            when others => HUB_FEE_DATA_IN <= STD_LOGIC_VECTOR(TO_UNSIGNED(i-3, 16));
         end case;
         
         HUB_FEE_DATAREADY_IN <= '1';
         
         wait until rising_edge(CLK_IN);
         
         while GBE_FEE_READ_IN = '0' loop
            wait until rising_edge(CLK_IN);
         end loop;
      end loop;
      
      HUB_FEE_DATAREADY_IN <= '0';

      wait until rising_edge(CLK_IN);
      wait until rising_edge(CLK_IN);

      HUB_FEE_BUSY_IN <= '0';

      wait until rising_edge(CLK_IN);
      wait until rising_edge(CLK_IN);
      wait until rising_edge(CLK_IN);
      wait until rising_edge(CLK_IN);
      
      HUB_CTS_START_READOUT_IN <= '0';
      
      wait until rising_edge(CLK_IN);
      wait until rising_edge(CLK_IN);      
      
   end process;
   
   PROC_CBMNET: process is
   begin
      CBMNET_DATA2SEND_STOP_IN <= '0';
      wait until falling_edge(CBMNET_DATA2SEND_END_OUT);
      CBMNET_DATA2SEND_STOP_IN <= '1';
      wait until rising_edge(CBMNET_CLK_IN);
      wait until rising_edge(CBMNET_CLK_IN);
      wait until rising_edge(CBMNET_CLK_IN);
      wait until rising_edge(CBMNET_CLK_IN);
   end process;

   GBE_FEE_READ_IN <= HUB_FEE_DATAREADY_IN;

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

end architecture;