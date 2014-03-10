library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hit_inv is
  
  port (
    PORT_IN  : in  std_logic;
    PORT_OUT : out std_logic);

end entity hit_inv;

architecture behavioral of hit_inv is

  signal hit_buf : std_logic;
  attribute syn_keep                : boolean;
  attribute syn_keep of hit_buf     : signal is true;
  attribute syn_preserve            : boolean;
  attribute syn_preserve of hit_buf : signal is true;


begin  -- architecture behavioral

  hit_buf  <= PORT_IN;
  PORT_OUT <= not hit_buf;

end architecture behavioral;
