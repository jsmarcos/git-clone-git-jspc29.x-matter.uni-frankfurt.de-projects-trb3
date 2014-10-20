library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use work.trb_net_std.all;

entity pos_edge_strech_sync is
   generic (
      LENGTH : positive := 2
   );
   port (
      IN_CLK_IN : in std_logic;
      DATA_IN   : in std_logic;
      OUT_CLK_IN : in std_logic;
      DATA_OUT : out std_logic
   );
end entity;

architecture RTL of pos_edge_strech_sync is
   signal in_buffer_i : std_logic_vector(LENGTH - 1 downto 0) := (others => '0');
   signal in_buffer_aggr_i : std_logic;
   signal out_buffer_i : std_logic := '0';
begin
   IN_PROC: process is
   begin
      wait until rising_edge(IN_CLK_IN);
      in_buffer_i <= in_buffer_i(LENGTH-2 downto 0) & DATA_IN;
   end process;
   
   OUT_PROC: process is
   begin
      wait until rising_edge(OUT_CLK_IN);
      
      in_buffer_aggr_i <= OR_ALL(in_buffer_i);
      
      out_buffer_i <= '0';
      if out_buffer_i = '0' and in_buffer_aggr_i = '1' then
         out_buffer_i <= '1';
      end if;
   end process;
   DATA_OUT <= out_buffer_i;
end architecture;