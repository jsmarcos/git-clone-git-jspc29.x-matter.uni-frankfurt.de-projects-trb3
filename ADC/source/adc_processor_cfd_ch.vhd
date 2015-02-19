library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;

entity adc_processor_cfd_ch is
  port(
    CLK         : in  std_logic;

    ADC_DATA    : in  std_logic_vector(RESOLUTION - 1 downto 0);

    CONF        : in  cfg_cfd_t;

    RAM_RD      : in  std_logic;
    RAM_ADDR    : in  std_logic_vector(7 downto 0);
    RAM_DATA    : out std_logic_vector(31 downto 0);

    TRIGGER_OUT : out std_logic
  );
end entity adc_processor_cfd_ch;

architecture arch of adc_processor_cfd_ch is
  signal invalid_word_count : unsigned(31 downto 0) := (others => '0');

  type unsigned_in_thresh_t is record
    word   : unsigned(RESOLUTION - 1 downto 0);
    thresh : std_logic;
  end record;
  constant unsigned_in_thresh_t_INIT : unsigned_in_thresh_t := (word => (others => '0'), thresh => '0');

  signal baseline, input : unsigned(RESOLUTION - 1 downto 0);

  signal baseline_average : unsigned(RESOLUTION + 2 ** CONF.BaselineAverage'length - 1 - 1 downto 0) := (others => '0');

  type delay_baseline_t is array (31 downto 0) of unsigned_in_thresh_t;
  signal delay_baseline     : delay_baseline_t     := (others => unsigned_in_thresh_t_INIT);
  signal delay_baseline_in  : unsigned_in_thresh_t := unsigned_in_thresh_t_INIT;
  signal delay_baseline_out : unsigned_in_thresh_t := unsigned_in_thresh_t_INIT;

  type subtracted_thresh_t is record
    word   : signed(RESOLUTION downto 0);
    thresh : std_logic;
  end record;
  constant subtracted_thresh_t_INIT : subtracted_thresh_t := (word => (others => '0'), thresh => '0');

  signal subtracted : subtracted_thresh_t := subtracted_thresh_t_INIT;

  type delay_cfd_t is array (2 ** (CONF.CFDDelay'length) - 1 downto 0) of signed(RESOLUTION downto 0);
  signal delay_cfd     : delay_cfd_t                 := (others => (others => '0'));
  signal delay_cfd_in  : signed(RESOLUTION downto 0) := (others => '0');
  signal delay_cfd_out : signed(RESOLUTION downto 0) := (others => '0');

begin
  input <= unsigned(ADC_DATA);

  -- word checker, needed for ADC phase adjustment
  gen_word_checker : for i in 0 to CHANNELS - 1 generate
    process
    begin
      wait until rising_edge(CLK);
      if ADC_DATA /= CONF.CheckWord1 and ADC_DATA /= CONF.CheckWord2 and CONF.CheckWordEnable = '1' then
        invalid_word_count <= invalid_word_count + 1;
      end if;
    end process;
  end generate;

  -- baseline subtraction, polarity inverter, threshold bit generator
  proc_compare_invert : process is
    variable sub, baseline_s, input_s, thresh_s : signed(RESOLUTION downto 0);
    variable thresh                             : std_logic;
  begin
    wait until rising_edge(CLK);

    -- add sign bit to various inputs
    baseline_s := signed(resize(baseline, RESOLUTION + 1));
    input_s    := signed(resize(input, RESOLUTION + 1));
    thresh_s   := signed(resize(CONF.InputThreshold, RESOLUTION + 1));

    -- subtract baseline such that sub is always positive
    -- so invert if required
    if CONF.PolarityInvert = '1' then
      sub := baseline_s - input_s;
    else
      sub := input_s - baseline_s;
    end if;

    -- output
    delay_baseline_in.word <= input;
    subtracted.word        <= sub;

    -- check if signal is above thresh
    if sub > thresh_s then
      thresh := '1';
    else
      thresh := '0';
    end if;
    delay_baseline_in.thresh <= thresh;
    subtracted.thresh        <= thresh;
    TRIGGER_OUT              <= thresh;
  end process proc_compare_invert;

  -- delay for baseline
  proc_baseline_delay : process is
  begin
    wait until rising_edge(CLK);
    delay_baseline     <= delay_baseline(delay_baseline'high-1 downto 0) & delay_baseline_in;
    delay_baseline_out <= delay_baseline(delay_baseline'high);
  end process proc_baseline_delay;

  -- average baseline
  proc_baseline_average : process is
    variable avg              : integer range 0 to 2 ** CONF.BaselineAverage'length - 1;
    constant l                : integer := baseline_average'length;
    variable input_r, fract_r : unsigned(l - 1 downto 0);
  begin
    wait until rising_edge(CLK);
    avg     := to_integer(CONF.BaselineAverage);
    input_r := resize(delay_baseline_out.word, l);
    fract_r := resize(baseline_average(avg + RESOLUTION - 1 downto avg), l);
    if delay_baseline_out.thresh = '0' or CONF.BaselineAlwaysOn = '1' then
      baseline_average <= baseline_average + input_r - fract_r;
    end if;
    baseline <= baseline_average(avg + RESOLUTION - 1 downto avg);
  end process proc_baseline_average;



end architecture arch;
