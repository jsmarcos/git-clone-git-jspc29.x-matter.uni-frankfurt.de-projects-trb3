library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity fallingEdgeDetect is
  port (CLK       : in  std_logic;
        SIGNAL_IN : in  std_logic;
        PULSE_OUT : out std_logic);
end fallingEdgeDetect;

architecture Behavioral of fallingEdgeDetect is
  
  signal signal_d : std_logic;
  
begin
  signal_d  <= SIGNAL_IN                    when rising_edge(CLK);
  PULSE_OUT <= (not SIGNAL_IN) and signal_d when rising_edge(CLK);
end Behavioral;
