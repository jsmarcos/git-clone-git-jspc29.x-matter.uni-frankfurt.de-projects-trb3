library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.trb_net_std.all;

package cbmnet_phy_pkg is
  component cbmnet_phy_ecp3 is
    generic(
      IS_SYNC_SLAVE   : integer := c_NO       --select slave mode
    );
    port(
      CLK                : in  std_logic; -- *internal* 125 MHz reference clock
      RESET              : in  std_logic; -- synchronous reset
      
      --Internal Connection TX
      MED_TXDATA_IN      : in  std_logic_vector(15 downto 0);
      MED_TXDATA_K_IN    : in  std_logic_vector( 1 downto 0);
      
      --Internal Connection RX
      MED_RXDATA_OUT     : out std_logic_vector(15 downto 0) := (others => '0');
      MED_RXDATA_K_OUT   : out std_logic_vector( 1 downto 0) := (others => '0');
      
      CLK_RX_HALF_OUT    : out std_logic := '0';  -- recovered 125 MHz
      CLK_RX_FULL_OUT    : out std_logic := '0';  -- recovered 250 MHz
      CLK_RX_RESET_OUT   : out std_logic := '1';  -- set to 0, ~1us after link is assumed to be stable

      LINK_ACTIVE_OUT    : out std_logic; -- link is active and can send and receive data
      SERDES_ready       : out std_logic;
      
      --SFP Connection
      SD_RXD_P_IN        : in  std_logic := '0';
      SD_RXD_N_IN        : in  std_logic := '0';
      SD_TXD_P_OUT       : out std_logic := '0';
      SD_TXD_N_OUT       : out std_logic := '0';

      SD_PRSNT_N_IN      : in  std_logic;  -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
      SD_LOS_IN          : in  std_logic;  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
      SD_TXDIS_OUT       : out  std_logic := '0'; -- SFP disable

      --Control Interface
      SCI_DATA_IN        : in  std_logic_vector(7 downto 0) := (others => '0');
      SCI_DATA_OUT       : out std_logic_vector(7 downto 0) := (others => '0');
      SCI_ADDR           : in  std_logic_vector(8 downto 0) := (others => '0');
      SCI_READ           : in  std_logic := '0';
      SCI_WRITE          : in  std_logic := '0';
      SCI_ACK            : out std_logic := '0';
      SCI_NACK           : out std_logic := '0';
      
      -- Status and control port
      STAT_OP            : out std_logic_vector (15 downto 0);
      CTRL_OP            : in  std_logic_vector (15 downto 0) := (others => '0');
      STAT_DEBUG         : out std_logic_vector (63 downto 0);
      CTRL_DEBUG         : in  std_logic_vector (63 downto 0) := (others => '0')
    );
  end component;
end package cbmnet_phy_pkg;

package body cbmnet_phy_pkg is
end package body;