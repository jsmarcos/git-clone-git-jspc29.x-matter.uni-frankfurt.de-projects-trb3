library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity level_to_pulse is
  
  port (
    CLK_IN        : in std_logic;  
    RESET_IN      : in std_logic;

    LEVEL_IN      : in std_logic;  
    PULSE_OUT     : out std_logic
    );

end entity;

architecture Behavioral of level_to_pulse is
  signal signal_ff        : std_logic_vector(1 downto 0);
  signal pulse_o          : std_logic;

begin

  signal_ff(1) <= LEVEL_IN when rising_edge(CLK_IN);
  signal_ff(0) <= signal_ff(1) when rising_edge(CLK_IN);
  pulse_o      <= '1' when signal_ff = "10" and RESET_IN = '0' else '0';

    -- Output Signals
  PULSE_OUT    <= pulse_o;
    
end Behavioral;
