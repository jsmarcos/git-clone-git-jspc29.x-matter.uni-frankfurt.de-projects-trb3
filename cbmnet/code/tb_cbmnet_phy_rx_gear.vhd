LIBRARY IEEE;
   USE IEEE.std_logic_1164.ALL;
   USE IEEE.numeric_std.all;

library work;
   use work.cbmnet_phy_pkg.all;
   
entity TB_CBMNET_PHY_RX_GEAR is
end entity;

architecture TB of TB_CBMNET_PHY_RX_GEAR is
  -- SERDES PORT
  signal CLK_250_IN  :  std_logic := '0';
  signal PCS_READY_IN:  std_logic := '0';
  signal SERDES_RESET_OUT :  std_logic := '0';
  signal DATA_IN     :   std_logic_vector( 8 downto 0);

  -- RM PORT
  signal RM_RESET_IN :  std_logic := '0';
  signal CLK_125_OUT :  std_logic := '0';
  signal RESET_OUT   :  std_logic := '0';
  signal DATA_OUT    :  std_logic_vector(17 downto 0);

  -- DEBUG
  signal DEBUG_OUT   :  std_logic_vector(15 downto 0) := (others => '0');
  
begin
     THE_RX_GEAR: CBMNET_PHY_RX_GEAR port map (
   -- SERDES PORT
      CLK_250_IN      => CLK_250_IN,             -- in std_logic;
      PCS_READY_IN    => PCS_READY_IN, -- in std_logic;
      SERDES_RESET_OUT=> SERDES_RESET_OUT,    -- out std_logic;
      DATA_IN         => DATA_IN,               -- in  std_logic_vector( 8 downto 0);

   -- RM PORT
      RM_RESET_IN => RM_RESET_IN,     -- in std_logic;
      CLK_125_OUT => CLK_125_OUT,                -- out std_logic;
      RESET_OUT   => RESET_OUT,          -- out std_logic;
      DATA_OUT    => DATA_OUT,       -- out std_logic_vector(17 downto 0)
      
      DEBUG_OUT   => DEBUG_OUT
   );
   
   CLK_250_IN <= not CLK_250_IN after 2 ns;
   PCS_READY_IN <= '1' after 100 ns;
   
   process is
      variable counter_v : UNSIGNED(7 downto 0) := x"00";
   begin
      wait until rising_edge(CLK_250_IN);
     
      counter_v := counter_v + TO_UNSIGNED(1,1);
      if counter_v(0) = '1' then
          DATA_IN <= "0" & x"00";
      elsif counter_v(0) = '0' then
          DATA_IN <= "1" & x"9c";      
      else
          DATA_IN <= "0" & STD_LOGIC_VECTOR(counter_v);
      end if;
    end process;
   
end architecture;