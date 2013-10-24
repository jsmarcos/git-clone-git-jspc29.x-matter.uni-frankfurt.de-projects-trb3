LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.med_sync_define.all;
use work.cbmnet_interface_pkg.all;
use work.cbmnet_phy_pkg.all;

entity TB_PHY_ECP3 is
end entity;

architecture TB of TB_PHY_ECP3 is
   signal m_CLK,                s_CLK                : std_logic := '0';
   signal m_RESET,              s_RESET              : std_logic := '1';
   signal m_CLEAR,              s_CLEAR              : std_logic := '0';

   --Internal Connection TX
   signal m_PHY_TXDATA_IN,      s_PHY_TXDATA_IN      : std_logic_vector(15 downto 0);
   signal m_PHY_TXDATA_K_IN,    s_PHY_TXDATA_K_IN    : std_logic_vector( 1 downto 0);

   --Internal Connection RX
   signal m_PHY_RXDATA_OUT,     s_PHY_RXDATA_OUT     : std_logic_vector(15 downto 0) := (others => '0');
   signal m_PHY_RXDATA_K_OUT,   s_PHY_RXDATA_K_OUT   : std_logic_vector( 1 downto 0) := (others => '0');

   signal m_CLK_RX_HALF_OUT,    s_CLK_RX_HALF_OUT    : std_logic := '0';
   signal m_CLK_RX_FULL_OUT,    s_CLK_RX_FULL_OUT    : std_logic := '0';
   signal m_CLK_RX_RESET_OUT,   s_CLK_RX_RESET_OUT   : std_logic := '1';

   signal m_LINK_ACTIVE_OUT,    s_LINK_ACTIVE_OUT    : std_logic;
   signal m_SERDES_ready,       s_SERDES_ready       : std_logic;

   --SFP Connection
   signal m_SD_RXD_P_IN,        s_SD_RXD_P_IN        : std_logic := '0';
   signal m_SD_RXD_N_IN,        s_SD_RXD_N_IN        : std_logic := '0';
   signal m_SD_TXD_P_OUT,       s_SD_TXD_P_OUT       : std_logic := '0';
   signal m_SD_TXD_N_OUT,       s_SD_TXD_N_OUT       : std_logic := '0';

   signal m_SD_PRSNT_N_IN,      s_SD_PRSNT_N_IN      : std_logic;
   signal m_SD_LOS_IN,          s_SD_LOS_IN          : std_logic;
   signal m_SD_TXDIS_OUT,       s_SD_TXDIS_OUT       : std_logic := '0';

   -- Status and control port
   signal m_STAT_OP,            s_STAT_OP            : std_logic_vector (15 downto 0);
   signal m_CTRL_OP,            s_CTRL_OP            : std_logic_vector (15 downto 0) := (others => '0');
   signal m_STAT_DEBUG,         s_STAT_DEBUG         : std_logic_vector (63 downto 0);
   signal m_CTRL_DEBUG,         s_CTRL_DEBUG         : std_logic_vector (63 downto 0) := (others => '0');
begin
   THE_MASTER: CBMNET_PHY_ECP3
   generic map (IS_SYNC_SLAVE => c_NO, IS_SIMULATED => c_YES)
   port map (
      CLK                => m_CLK,
      RESET              => m_RESET,
      CLEAR              => m_CLEAR,

      --Internal Connection TX
      PHY_TXDATA_IN      => m_PHY_TXDATA_IN,
      PHY_TXDATA_K_IN    => m_PHY_TXDATA_K_IN,

      --Internal Connection RX
      PHY_RXDATA_OUT     => m_PHY_RXDATA_OUT,
      PHY_RXDATA_K_OUT   => m_PHY_RXDATA_K_OUT,

      CLK_RX_HALF_OUT    => m_CLK_RX_HALF_OUT,
      CLK_RX_FULL_OUT    => m_CLK_RX_FULL_OUT,
      CLK_RX_RESET_OUT   => m_CLK_RX_RESET_OUT,

      LINK_ACTIVE_OUT    => m_LINK_ACTIVE_OUT,
      SERDES_ready       => m_SERDES_ready,

      --SFP Connection
      SD_RXD_P_IN        => m_SD_RXD_P_IN,
      SD_RXD_N_IN        => m_SD_RXD_N_IN,
      SD_TXD_P_OUT       => m_SD_TXD_P_OUT,
      SD_TXD_N_OUT       => m_SD_TXD_N_OUT,

      SD_PRSNT_N_IN      => m_SD_PRSNT_N_IN,
      SD_LOS_IN          => m_SD_LOS_IN,
      SD_TXDIS_OUT       => m_SD_TXDIS_OUT,

      -- Status and control port
      STAT_OP            => m_STAT_OP,
      CTRL_OP            => m_CTRL_OP
   );


   THE_CLIENT: CBMNET_PHY_ECP3
   generic map (IS_SYNC_SLAVE => c_YES, IS_SIMULATED => c_YES) 
   port map (
      CLK                => s_CLK,
      RESET              => s_RESET,
      CLEAR              => s_CLEAR,

      --Internal Connection TX
      PHY_TXDATA_IN      => s_PHY_TXDATA_IN,
      PHY_TXDATA_K_IN    => s_PHY_TXDATA_K_IN,

      --Internal Connection RX
      PHY_RXDATA_OUT     => s_PHY_RXDATA_OUT,
      PHY_RXDATA_K_OUT   => s_PHY_RXDATA_K_OUT,

      CLK_RX_HALF_OUT    => s_CLK_RX_HALF_OUT,
      CLK_RX_FULL_OUT    => s_CLK_RX_FULL_OUT,
      CLK_RX_RESET_OUT   => s_CLK_RX_RESET_OUT,

      LINK_ACTIVE_OUT    => s_LINK_ACTIVE_OUT,
      SERDES_ready       => s_SERDES_ready,

      --SFP Connection
      SD_RXD_P_IN        => s_SD_RXD_P_IN,
      SD_RXD_N_IN        => s_SD_RXD_N_IN,
      SD_TXD_P_OUT       => s_SD_TXD_P_OUT,
      SD_TXD_N_OUT       => s_SD_TXD_N_OUT,

      SD_PRSNT_N_IN      => s_SD_PRSNT_N_IN,
      SD_LOS_IN          => s_SD_LOS_IN,
      SD_TXDIS_OUT       => s_SD_TXDIS_OUT,

      -- Status and control port
      STAT_OP            => s_STAT_OP,
      CTRL_OP            => s_CTRL_OP
   );

   m_CLK <= not m_CLK after 8 ns;
   s_CLK <= not s_CLK after (8 ns * (1.0003));
   m_RESET <= '1', '0' after 100 ns;
   s_RESET <= '1', '0' after 110 ns;
   
   s_SD_RXD_N_IN <= m_SD_TXD_N_OUT;
   s_SD_RXD_P_IN <= m_SD_TXD_P_OUT;
   
   m_SD_RXD_N_IN <= s_SD_TXD_N_OUT;
   m_SD_RXD_P_IN <= s_SD_TXD_P_OUT;
   
   m_SD_PRSNT_N_IN <= '1';
   m_SD_PRSNT_N_IN <= '0';
   
   s_SD_PRSNT_N_IN <= '1';
   s_SD_PRSNT_N_IN <= '0';
end architecture;





