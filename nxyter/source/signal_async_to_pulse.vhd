library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.nxyter_components.all;

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

  signal pulse_ff      : std_logic_vector(NUM_FF - 1 downto 0);
  signal pulse_o       : std_logic;

  attribute syn_keep : boolean;
  attribute syn_keep of pulse_ff      : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of pulse_ff  : signal is true;
  
begin

  -----------------------------------------------------------------------------
  -- Clock CLK_IN Domain
  -----------------------------------------------------------------------------

  PROC_SYNC_PULSE: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      pulse_ff(NUM_FF - 1)             <= PULSE_A_IN;
      for i in NUM_FF - 2 downto 0 loop
        pulse_ff(i)                  <= pulse_ff(i + 1); 
      end loop;
    end if;
  end process PROC_SYNC_PULSE;

  level_to_pulse_1: level_to_pulse
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => pulse_ff(0),
      PULSE_OUT => pulse_o
      );

  -- Outputs
  PULSE_OUT     <= pulse_o;
    
end Behavioral;
