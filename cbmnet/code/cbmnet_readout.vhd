library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

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
begin

end architecture;

