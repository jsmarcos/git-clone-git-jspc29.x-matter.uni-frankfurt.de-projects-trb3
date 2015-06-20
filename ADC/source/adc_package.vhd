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
  
  constant EPOCH_COUNTER_SIZE : integer := 24; 

  type buffer_data_t is array (0 to DEVICES - 1) of std_logic_vector(31 downto 0);

  type std_logic_vector_array_18 is array (integer range <>) of std_logic_vector(17 downto 0);
  type std_logic_vector_array_10 is array (integer range <>) of std_logic_vector(9 downto 0);

  type unsigned_array_18 is array (integer range <>) of unsigned(17 downto 0);
  type unsigned_array_10 is array (integer range <>) of unsigned(9 downto 0);
  type unsigned_array_8 is array (integer range <>) of unsigned(7 downto 0);

  type cfg_t is record
    processing_mode      : integer range 0 to 3; --0: normal block processing, 1: pulse shape processing
    buffer_depth         : unsigned(10 downto 0);
    samples_after        : unsigned(10 downto 0);
    block_count          : unsigned(1 downto 0);
    trigger_threshold    : unsigned(17 downto 0);
    readout_threshold    : unsigned(17 downto 0);
    presum               : unsigned(7 downto 0);
    averaging            : unsigned(3 downto 0);
    trigger_enable       : std_logic_vector(47 downto 0);
    channel_disable      : std_logic_vector(47 downto 0);
    baseline_always_on   : std_logic;
    baseline_reset_value : unsigned(31 downto 0);
    block_avg            : unsigned_array_8(0 to 3);
    block_sums           : unsigned_array_8(0 to 3);
    block_scale          : unsigned_array_8(0 to 3);
    check_word1          : std_logic_vector(RESOLUTION - 1 downto 0);
    check_word2          : std_logic_vector(RESOLUTION - 1 downto 0);
    check_word_enable    : std_logic;
    cfd_window           : unsigned(7 downto 0);
    cfd_delay            : unsigned(3 downto 0);
  end record;

  type cfg_cfd_t is record
    DebugMode   : integer range 0 to 3; -- 0 CFD events, debug: 1 raw, 2 subtracted, 3 cfd
    InputThreshold   : unsigned(9 downto 0);
    PolarityInvert   : std_logic;
    BaselineAverage  : unsigned(4 downto 0);
    BaselineAlwaysOn : std_logic;
    CFDDelay         : unsigned(2 downto 0);
    CFDMult          : unsigned(2 downto 0);
    CFDMultDly       : unsigned(2 downto 0);
    IntegrateWindow  : unsigned(7 downto 0);
    TriggerDelay     : unsigned(11 downto 0);
    CheckWord1       : std_logic_vector(RESOLUTION - 1 downto 0);
    CheckWord2       : std_logic_vector(RESOLUTION - 1 downto 0);
    CheckWordEnable  : std_logic;
    TriggerEnable    : std_logic_vector(47 downto 0);
    ChannelDisable   : std_logic_vector(47 downto 0);
    DebugSamples     : unsigned(7 downto 0); -- for ProcessingMode>0
  end record;

  constant cfg_cfd_t_INIT : cfg_cfd_t := (
    DebugMode        => 0,
    InputThreshold   => (others => '0'),
    PolarityInvert   => '0',
    BaselineAverage  => (others => '0'),
    BaselineAlwaysOn => '0',
    CFDDelay         => (others => '0'),
    CFDMult          => (others => '0'),
    CFDMultDly       => (others => '0'),
    IntegrateWindow  => (others => '0'),
    TriggerDelay     => (others => '0'),
    CheckWord1       => (others => '0'),
    CheckWord2       => (others => '0'),
    CheckWordEnable  => '0',
    TriggerEnable    => (others => '0'),
    ChannelDisable   => (others => '0'),
    DebugSamples     => (others => '0')
  );

  type debug_cfd_t is record
    InvalidWordCount : unsigned(31 downto 0);
    Baseline         : unsigned(RESOLUTION - 1 downto 0);
    LastWord         : unsigned(RESOLUTION - 1 downto 0);
    Trigger          : std_logic;
  end record;

end package;

package body adc_package is

end package body;



