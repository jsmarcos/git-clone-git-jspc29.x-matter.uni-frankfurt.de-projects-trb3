library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.scaler_components.all;

entity signal_async_to_pulse is
  generic (
    NUM_FF : integer range 2 to 4 := 2
    );
  port (
    CLK_IN       : in  std_logic;
    RESET_IN     : in  std_logic;
    PULSE_A_IN   : in  std_logic;
    PULSE_OUT    : out std_logic
    );

end entity;

architecture Behavioral of signal_async_to_pulse is
--  attribute HGROUP : string;
--  attribute HGROUP of Behavioral : architecture is "SIGNAL_ASYNC_TO_PULSE";

  signal pulse_ff      : std_logic_vector(NUM_FF downto 0);
  signal pulse_o       : std_logic;

  attribute syn_keep : boolean;
  attribute syn_keep of pulse_ff      : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of pulse_ff  : signal is true;
  
begin

  -----------------------------------------------------------------------------
  -- Clock CLK_IN Domain
  -----------------------------------------------------------------------------

  pulse_ff(NUM_FF)   <= PULSE_A_IN when rising_edge(CLK_IN);
  L1: for I in (NUM_FF - 1) downto 0 generate
    pulse_ff(I)      <= pulse_ff(I + 1) when rising_edge(CLK_IN); 
  end generate L1;  

  pulse_o <= '1' when pulse_ff(1 downto 0) = "10" and RESET_IN = '0' else '0'; 
  
  -- Outputs
  PULSE_OUT     <= pulse_o;
    
end Behavioral;
