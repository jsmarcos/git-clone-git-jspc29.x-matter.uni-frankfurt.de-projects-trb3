library ieee;
USE IEEE.std_logic_1164.ALL;
use ieee.numeric_std.all;
use work.trb_net_std.all;

package adc_package is



constant DEVICES    : integer := 12;
constant DEVICES_1  : integer := 7;
constant DEVICES_2  : integer := 5;
constant CHANNELS   : integer := 4;
constant RESOLUTION : integer := 10;



type cfg_t is record
  buffer_depth      : std_logic_vector(10 downto 0);
  samples_after     : std_logic_vector(10 downto 0);
  block_count       : std_logic_vector( 1 downto 0);
  trigger_threshold : std_logic_vector(17 downto 0);
  readout_threshold : std_logic_vector(17 downto 0);
  presum            : std_logic_vector( 7 downto 0);
end record;

type buffer_data_t    is array(0 to DEVICES-1)          of std_logic_vector(31 downto 0);

end package;


package body adc_package is
end package body;