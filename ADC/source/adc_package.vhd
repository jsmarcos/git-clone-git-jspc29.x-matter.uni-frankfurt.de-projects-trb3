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


type buffer_data_t    is array(0 to DEVICES-1)          of std_logic_vector(31 downto 0);

type std_logic_vector_array_18 is array (integer range <>) of std_logic_vector(17 downto 0);
type std_logic_vector_array_10 is array (integer range <>) of std_logic_vector( 9 downto 0);

type unsigned_array_18 is array (integer range <>) of unsigned(17 downto 0);
type unsigned_array_10 is array (integer range <>) of unsigned( 9 downto 0);
type unsigned_array_8  is array (integer range <>) of unsigned( 7 downto 0);


type cfg_t is record
  processing_mode   : integer range 0 to 3; --0: normal block processing, 1: pulse shape processing
  buffer_depth      : unsigned(10 downto 0);
  samples_after     : unsigned(10 downto 0);
  block_count       : unsigned( 1 downto 0);
  trigger_threshold : signed  (17 downto 0);
  readout_threshold : signed  (17 downto 0);
  presum            : unsigned( 7 downto 0);
  averaging         : unsigned( 3 downto 0);
  trigger_enable    : std_logic_vector(47 downto 0);
  channel_disable   : std_logic_vector(47 downto 0);
  baseline_always_on: std_logic;
  baseline_reset_value : unsigned(31 downto 0);
  baseline_fix_value : unsigned(31 downto 0);
  block_avg         : unsigned_array_8(0 to 3);
  block_sums        : unsigned_array_8(0 to 3);
  block_scale       : unsigned_array_8(0 to 3);
  check_word1       : std_logic_vector(RESOLUTION-1 downto 0);
  check_word2       : std_logic_vector(RESOLUTION-1 downto 0);
  check_word_enable : std_logic;
end record;

end package;


package body adc_package is
end package body;



