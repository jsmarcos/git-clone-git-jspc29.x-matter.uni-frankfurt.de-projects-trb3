LIBRARY IEEE;
   USE IEEE.std_logic_1164.ALL;
   USE IEEE.numeric_std.all;

library work;
   use work.trb_net_std.all;
   use work.cbmnet_phy_pkg.all;
   
entity TB_CBMNET_PHY_TX_GEAR is
end entity;

architecture TB of TB_CBMNET_PHY_TX_GEAR is
   constant IS_SYNC_SLAVE : integer range 0 to 1 := c_YES;
   signal CLK_250_IN  : std_logic := '0';
   signal CLK_125_IN  : std_logic := '0';
   signal CLK_125_OUT : std_logic;
   signal RESET_IN    : std_logic := '1';
   signal DATA_IN     : std_logic_vector(17 downto 0) := (others => '0');
   signal DATA_OUT    : std_logic_vector(8 downto 0);
begin
   THE_GEAR: CBMNET_PHY_TX_GEAR 
   generic map (IS_SYNC_SLAVE => IS_SYNC_SLAVE)
   port map (
      CLK_250_IN => CLK_250_IN,
      CLK_125_IN => CLK_125_IN,
      CLK_125_OUT => CLK_125_OUT,
      RESET_IN => RESET_IN,
      DATA_IN => DATA_IN,
      DATA_OUT => DATA_OUT
   );
      
   CLK_250_IN <= not CLK_250_IN after 2 ns;
   RESET_IN <= '0' after 50 ns;
   
   proc_clk: process is
   begin
      wait until rising_edge(CLK_250_IN);
      wait for 1 ns;
      CLK_125_IN <= not CLK_125_IN;
   end process;
   
   process is
      variable counter : unsigned(7 downto 0) := (others => '0');
   begin
      wait until rising_edge(CLK_125_IN);
      DATA_IN(7 downto 0) <= STD_LOGIC_VECTOR(counter);
      DATA_IN(15 downto 8) <= STD_LOGIC_VECTOR(counter + TO_UNSIGNED(1,1));
      counter := counter + TO_UNSIGNED(2,2);
   end process;
end architecture;