library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;

entity adc_processor_cfd_ch is
  generic(
    DEVICE  : integer range 0 to 15 := 0;
    CHANNEL : integer range 0 to 3 := 0
  );
  port(
    CLK      : in  std_logic;

    ADC_DATA : in  std_logic_vector(RESOLUTION - 1 downto 0);

    CONF     : in  cfg_cfd_t;

    RAM_ADDR : out  std_logic_vector(8 downto 0);
    RAM_DATA : out  std_logic_vector(31 downto 0);
    RAM_BSY_IN : in std_logic;
    RAM_BSY_OUT : out std_logic;

    DEBUG    : out debug_cfd_t;
    
    EPOCH_COUNTER_IN    : in unsigned(EPOCH_COUNTER_SIZE-1 downto 0)
  );
end entity adc_processor_cfd_ch;

architecture arch of adc_processor_cfd_ch is
  constant RESOLUTION_SUB  : integer := RESOLUTION + 1; -- one sign bit extra for baseline subtracted value
  constant RESOLUTION_PROD : integer := RESOLUTION_SUB + CONF.CFDMult'length; -- assume CONF.CFDMult length equals CFDMultDly
  constant RESOLUTION_CFD  : integer := RESOLUTION_PROD + 1; -- this should be 16 to fit into the readout ram

  constant RESOLUTION_BASEAVG : integer := RESOLUTION + 2 ** CONF.BaselineAverage'length - 1;
  constant LENGTH_BASEDLY     : integer := 32; -- longer than typical pulses?
  constant LENGTH_CFDDLY      : integer := 2 ** CONF.CFDDelay'length;
  constant LENGTH_INTDLY      : integer := 3;  -- must match CFD/zeroX calculation chain

  type unsigned_in_thresh_t is record
    value  : unsigned(RESOLUTION - 1 downto 0);
    thresh : std_logic;
  end record;
  constant unsigned_in_thresh_t_INIT : unsigned_in_thresh_t := (value => (others => '0'), thresh => '0');

  type subtracted_thresh_t is record
    value  : signed(RESOLUTION_SUB - 1 downto 0);
    thresh : std_logic;
  end record;
  constant subtracted_thresh_t_INIT : subtracted_thresh_t := (value => (others => '0'), thresh => '0');

  type product_thresh_t is record
    value  : signed(RESOLUTION_PROD - 1 downto 0);
    thresh : std_logic;
  end record;
  constant product_thresh_t_INIT : product_thresh_t := (value => (others => '0'), thresh => '0');

  type cfd_thresh_t is record
    value  : signed(RESOLUTION_CFD - 1 downto 0);
    thresh : std_logic;
  end record;
  constant cfd_thresh_t_INIT : cfd_thresh_t := (value => (others => '0'), thresh => '0');

  signal invalid_word_count : unsigned(DEBUG.InvalidWordCount'length - 1 downto 0) := (others => '0');

  signal baseline, input  : unsigned(RESOLUTION - 1 downto 0)         := (others => '0');
  signal baseline_average : unsigned(RESOLUTION_BASEAVG - 1 downto 0) := (others => '0');

  type delay_baseline_t is array (LENGTH_BASEDLY - 1 downto 0) of unsigned_in_thresh_t;
  signal delay_baseline     : delay_baseline_t     := (others => unsigned_in_thresh_t_INIT);
  signal delay_baseline_in  : unsigned_in_thresh_t := unsigned_in_thresh_t_INIT;
  signal delay_baseline_out : unsigned_in_thresh_t := unsigned_in_thresh_t_INIT;

  signal subtracted : subtracted_thresh_t := subtracted_thresh_t_INIT;

  type delay_cfd_t is array (LENGTH_CFDDLY - 1 downto 0) of signed(RESOLUTION_SUB - 1 downto 0);
  signal delay_cfd     : delay_cfd_t                         := (others => (others => '0'));
  signal delay_cfd_in  : signed(RESOLUTION_SUB - 1 downto 0) := (others => '0');
  signal delay_cfd_out : signed(RESOLUTION_SUB - 1 downto 0) := (others => '0');

  signal prod, prod_invert : product_thresh_t := product_thresh_t_INIT;
  signal prod_delay        : signed(RESOLUTION_PROD - 1 downto 0) := (others => '0');

  signal cfd                               : cfd_thresh_t                        := cfd_thresh_t_INIT; -- the bipolar signal
  signal cfd_prev, cfd_prev_save, cfd_save : signed(RESOLUTION_CFD - 1 downto 0) := (others => '0');

  type delay_integral_t is array (LENGTH_INTDLY - 1 downto 0) of signed(RESOLUTION_SUB - 1 downto 0);
  signal delay_integral     : delay_integral_t                         := (others => (others => '0'));
  signal delay_integral_in  : signed(RESOLUTION_SUB - 1 downto 0) := (others => '0');
  signal delay_integral_out : signed(RESOLUTION_SUB - 1 downto 0) := (others => '0');

  signal integral_sum                      : signed(RESOLUTION_CFD - 1 downto 0) := (others => '0');

  signal epoch_counter_save : unsigned(EPOCH_COUNTER_SIZE-1 downto 0) := (others => '0');
  type state_t is (IDLE, INTEGRATE, WRITE1, WRITE2, WRITE3, FINISH, LOCKED, DEBUG_DUMP);
  signal state : state_t := IDLE;

  signal ram_counter : unsigned(8 downto 0) := (others => '0'); 
  
  signal debug_mux : std_logic_vector(15 downto 0);
begin
  -- input ADC data interpreted as unsigned
  input <= unsigned(ADC_DATA);

  -- Tell the outer word some useful debug infos
  DEBUG.InvalidWordCount <= invalid_word_count when rising_edge(CLK);
  DEBUG.Baseline         <= baseline when rising_edge(CLK);
  DEBUG.LastWord         <= input when rising_edge(CLK);

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
    delay_baseline_in.value <= input;
    subtracted.value        <= sub;

    -- check if signal is above thresh
    if sub > thresh_s then
      thresh := '1';
    else
      thresh := '0';
    end if;
    delay_baseline_in.thresh <= thresh;
    subtracted.thresh        <= thresh;
    DEBUG.Trigger            <= thresh;
  end process proc_compare_invert;

  -- delay for baseline
  proc_baseline_delay : process is
  begin
    wait until rising_edge(CLK);
    delay_baseline     <= delay_baseline(delay_baseline'high - 1 downto 0) & delay_baseline_in;
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
    input_r := resize(delay_baseline_out.value, l);
    fract_r := resize(baseline_average(avg + RESOLUTION - 1 downto avg), l);
    if delay_baseline_out.thresh = '0' or CONF.BaselineAlwaysOn = '1' then
      baseline_average <= baseline_average + input_r - fract_r;
    end if;
    baseline <= baseline_average(avg + RESOLUTION - 1 downto avg);
  end process proc_baseline_average;

  -- CFD delay
  delay_cfd_in <= subtracted.value;
  proc_cfd_delay : process is
  begin
    wait until rising_edge(CLK);
    delay_cfd     <= delay_cfd(delay_cfd'high - 1 downto 0) & delay_cfd_in;
    delay_cfd_out <= delay_cfd(to_integer(CONF.CFDDelay));
  end process proc_cfd_delay;

  -- CFD multiply, invert, add
  proc_cfd_mult_inv_add : process is
    variable mult_s, mult_delay_s : signed(CONF.CFDMultDly'length downto 0); -- extra sign bit
    variable prod_s, prod_delay_s : signed(RESOLUTION_PROD downto 0); -- extra sign bit
  begin
    wait until rising_edge(CLK);

    -- delayed chain: input is output of delay, aka delay_cfd_out
    mult_delay_s := signed(resize(CONF.CFDMultDly, CONF.CFDMultDly'length + 1)); -- add extra zero sign bit
    prod_delay_s := mult_delay_s * delay_cfd_out;
    prod_delay   <= resize(prod_delay_s, RESOLUTION_PROD); -- get rid of extra bit again

    -- undelayed chain: input is subtracted signal
    mult_s      := signed(resize(CONF.CFDMult, CONF.CFDMult'length + 1)); -- add extra zero sign bit
    prod_s      := mult_s * subtracted.value;
    prod.value  <= resize(prod_s, RESOLUTION_PROD); -- get rid of extra bit again
    prod.thresh <= subtracted.thresh;

    -- invert
    prod_invert.value  <= -prod.value;
    prod_invert.thresh <= prod.thresh;

    -- add both signals to generate the bipolar cfd signal
    cfd.value  <= resize(prod_invert.value, RESOLUTION_CFD) + resize(prod_delay, RESOLUTION_CFD);
    cfd.thresh <= prod_invert.thresh;
  end process proc_cfd_mult_inv_add;

  -- Integrate delay
  delay_integral_in <= delay_cfd_out;
  proc_integral_delay : process is
  begin
    wait until rising_edge(CLK);
    delay_integral     <= delay_integral(delay_integral'high - 1 downto 0) & delay_integral_in;
    delay_integral_out <= delay_integral(delay_integral'high);
  end process proc_integral_delay;

  -- ZeroX detect, integrate, write to RAM
  RAM_ADDR <= std_logic_vector(resize(ram_counter,RAM_ADDR'length));
  proc_zeroX_gate : process is
    variable zeroX            : std_logic := '0';
    variable integral_counter : integer range 0 to 2 ** CONF.IntegrateWindow'length - 1;
    variable debug_counter : integer range 0 to 2 ** CONF.DebugSamples'length - 1;
    
  begin
    wait until rising_edge(CLK);

    cfd_prev <= cfd.value;
    if cfd_prev < 0 and cfd.value >= 0 and cfd.thresh = '1' then
      zeroX := '1';
    else
      zeroX := '0';
    end if;

    RAM_BSY_OUT <= '0';
    RAM_DATA <= (others => '0'); -- always write zeros as end marker
    

    case state is
      when IDLE =>
        if CONF.DebugMode = 0 and zeroX = '1' then
          state            <= INTEGRATE;
          integral_counter := to_integer(CONF.IntegrateWindow);
          integral_sum <= resize(delay_integral_out, RESOLUTION_CFD);
          cfd_prev_save <= cfd_prev; 
          cfd_save <= cfd.value;
          epoch_counter_save <= EPOCH_COUNTER_IN;
        elsif CONF.DebugMode = 0 and RAM_BSY_IN = '1' then
          state <= LOCKED;
        elsif CONF.DebugMode /= 0 and RAM_BSY_IN = '1' then
          -- at least one word is always dumped into the RAM
          -- don't move the ram pointer yet, it's already at next position
          RAM_DATA(31 downto 24) <= x"01";
          RAM_DATA(23 downto 20) <= std_logic_vector(to_unsigned(DEVICE, 4));
          RAM_DATA(19 downto 16) <= std_logic_vector(to_unsigned(CHANNEL, 4));
          RAM_DATA(15 downto  0) <= debug_mux;
          debug_counter := to_integer(CONF.DebugSamples);
          state <= DEBUG_DUMP;
        end if;        
      
      when DEBUG_DUMP =>
        -- always move the ram pointer
        ram_counter <= ram_counter + 1;                
        if debug_counter = 0 then
          -- indicate we're done
          state <= LOCKED;
        else
          debug_counter := debug_counter - 1;
          RAM_DATA(31 downto 24) <= x"01";
          RAM_DATA(23 downto 20) <= std_logic_vector(to_unsigned(DEVICE, 4));
          RAM_DATA(19 downto 16) <= std_logic_vector(to_unsigned(CHANNEL, 4));
          RAM_DATA(15 downto  0) <= debug_mux;
        end if;  
          
      
      when INTEGRATE =>
        if integral_counter = 0 then
          state         <= WRITE1;
        else
          integral_sum <= integral_sum + resize(delay_integral_out, RESOLUTION_CFD);
          integral_counter := integral_counter - 1;
        end if;
      
      when LOCKED =>
        RAM_BSY_OUT <= '1';
        if RAM_BSY_IN = '0' then
          state <= IDLE;           
        end if;
        
        
      when WRITE1 => 
        RAM_DATA(31 downto 24) <= x"d0";
        RAM_DATA(23 downto 20) <= std_logic_vector(to_unsigned(DEVICE, 4));
        RAM_DATA(19 downto 16) <= std_logic_vector(to_unsigned(CHANNEL, 4));
        RAM_DATA(15 downto  8) <= std_logic_vector(resize(epoch_counter_save(epoch_counter_save'high downto 16),8));
        RAM_DATA( 7 downto  0) <= (others => '0');
        -- assume that ram_counter is already at next position
        -- ram_counter <= ram_counter + 1;
        state <= WRITE2;
        
      when WRITE2 => 
        RAM_DATA(31 downto 16) <= std_logic_vector(epoch_counter_save(15 downto 0));
        RAM_DATA(15 downto  0) <= std_logic_vector(integral_sum); 
        ram_counter <= ram_counter + 1;
        state <= WRITE3;
        
      when WRITE3 => 
        RAM_DATA(31 downto 16) <= std_logic_vector(cfd_prev_save);
        RAM_DATA(15 downto  0) <= std_logic_vector(cfd_save);
        ram_counter <= ram_counter + 1;
        state <= FINISH;
        
      when FINISH =>
        -- move to next position
        ram_counter <= ram_counter + 1;
        state <= IDLE;  
                  
    end case;

  end process proc_zeroX_gate;
  
  -- debug multiplexer of some signals
  proc_mux_debug : process is
  begin
    wait until rising_edge(CLK);
    case CONF.DebugMode is
    when 0 =>
      debug_mux <= (others => '0');
    when 1 =>
      debug_mux <= std_logic_vector(resize(input,debug_mux'length));
    when 2 =>
      debug_mux <= std_logic_vector(resize(subtracted.value,debug_mux'length));  
    when 3 =>
      debug_mux <= std_logic_vector(resize(cfd.value,debug_mux'length));  
    end case;  
  end process proc_mux_debug;
  
  

end architecture arch;
