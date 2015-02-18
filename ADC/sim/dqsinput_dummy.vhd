library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dqsinput_dummy is
  port (
    eclk : in std_logic;
    sclk : out std_logic;
    q_0 : out  std_logic_vector(19 downto 0)
  );
end entity dqsinput_dummy;

architecture arch of dqsinput_dummy is
  signal sclk_int : std_logic := '0';
  signal q : std_logic_vector(19 downto 0) := (others =>'0');
begin
  
  sclk <= sclk_int;
  clkdiv : process is
  begin
    wait until rising_edge(eclk);
    sclk_int <= not sclk_int;
  end process clkdiv;
  
  q_0 <= q;
  
  dataoutput : process is
  begin
    wait until rising_edge(sclk_int);
    q <= (others => '0');
    
    wait until rising_edge(sclk_int);
    q <= (others => '1');
  end process dataoutput;  
end architecture arch;

