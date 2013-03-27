library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity risingEdgeDetect is
  port (
    CLK       : in  std_logic;
    SIGNAL_IN : in  std_logic;
    PULSE_OUT : out std_logic);
end risingEdgeDetect;

architecture Behavioral of risingEdgeDetect is
  
  signal signal_d : std_logic;
  
begin
  signal_d  <= SIGNAL_IN                    when rising_edge(CLK);
  PULSE_OUT <= (not signal_d) and SIGNAL_IN when rising_edge(CLK);
end Behavioral;
