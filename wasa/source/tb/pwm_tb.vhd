library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;




entity tb is
end entity;



architecture arch of tb is

signal clk : std_logic := '1';

signal data : std_logic_vector(15 downto 0) := (others => '0');
signal write : std_logic := '0';
signal addr  : std_logic_vector(3 downto 0) := (others => '0');



component pwm_generator is
  port(
    CLK        : in std_logic;
    
    DATA_IN    : in  std_logic_vector(15 downto 0);
    DATA_OUT   : out std_logic_vector(15 downto 0);
    WRITE_IN   : in  std_logic;
    ADDR_IN    : in  std_logic_vector(3 downto 0);
    
    PWM        : out std_logic_vector(31 downto 0)
    
    );
end component;

begin

clk<= not clk after 5 ns;




process begin
  wait for 101 ns;
  data <= x"6234";
  write <= '1';
  addr <= x"0";
  wait for 10 ns;
  write <= '0';
  wait;
end process;

PWM : pwm_generator
  port map(
    CLK => clk,
    DATA_IN => data,
    DATA_OUT => open,
    WRITE_IN => write,
    ADDR_IN => addr,
    PWM => open
  );


end architecture;