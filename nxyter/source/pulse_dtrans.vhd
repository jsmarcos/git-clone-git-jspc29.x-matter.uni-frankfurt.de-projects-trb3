library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.nxyter_components.all;

entity pulse_dtrans is
  generic (
    CLK_RATIO : integer range 2 to 15 := 4
    );
  port (
    CLK_A_IN     : in  std_logic;
    RESET_A_IN   : in  std_logic;
    PULSE_A_IN   : in  std_logic;
    CLK_B_IN     : in  std_logic;
    RESET_B_IN   : in  std_logic;
    PULSE_B_OUT  : out std_logic
    );

end entity;

architecture Behavioral of pulse_dtrans is
--  attribute HGROUP : string;
--  attribute HGROUP of Behavioral : architecture is "PULSE_DTRANS";

  signal pulse_a_l      : std_logic;
  signal pulse_b_o      : std_logic;

begin
  -----------------------------------------------------------------------------
  -- Clock A Domain
  -----------------------------------------------------------------------------
  pulse_to_level_1: pulse_to_level
    generic map (
      NUM_CYCLES => CLK_RATIO
      )
    port map (
      CLK_IN     => CLK_A_IN,
      RESET_IN   => RESET_A_IN,
      PULSE_IN   => PULSE_A_IN, 
      LEVEL_OUT  => pulse_a_l
      );

  -----------------------------------------------------------------------------
  -- Clock B Domain
  -----------------------------------------------------------------------------

  signal_async_to_pulse_1: signal_async_to_pulse
    generic map (
      NUM_FF => 2
      )
    port map (
      CLK_IN     => CLK_B_IN,
      RESET_IN   => RESET_B_IN,
      PULSE_A_IN => pulse_a_l,
      PULSE_OUT  => pulse_b_o
      );

  -- Outputs
  PULSE_B_OUT   <= pulse_b_o;
    
end Behavioral;
