library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;

entity adc_processor is
  generic(
    DEVICE     : integer range 0 to 15 := 15
    );
  port(
    CLK        : in  std_logic;
    
    ADC_DATA   : in  std_logic_vector(RESOLUTION*CHANNELS-1 downto 0);
    ADC_VALID  : in  std_logic;
    STOP_IN    : in  std_logic;
    TRIGGER_OUT: out std_logic;
    
    CONTROL    : in  std_logic_vector(63 downto 0);
    CONFIG     : in  cfg_t;

    PSA_DATA     : in  std_logic_vector(8 downto 0);
    PSA_DATA_OUT : out std_logic_vector(8 downto 0);
    PSA_WRITE    : in  std_logic;
    PSA_ADDR     : in  std_logic_vector(7 downto 0);    
    
    DEBUG_BUFFER_READ : in  std_logic;
    DEBUG_BUFFER_ADDR : in  std_logic_vector(4 downto 0);
    DEBUG_BUFFER_DATA : out std_logic_vector(31 downto 0);
    DEBUG_BUFFER_READY: out std_logic;
    
    READOUT_RX : in  READOUT_RX;
    READOUT_TX : out READOUT_TX
    
    );
end entity;


architecture adc_processor_arch of adc_processor is
attribute syn_hier     : string;
attribute syn_ramstyle : string;
attribute syn_keep     : boolean;
attribute syn_preserve : boolean;
attribute syn_hier of adc_processor_arch : architecture is "hard";

type ram_t          is array (0 to 1023)       of unsigned(17 downto 0);
type ram_arr_t      is array (0 to 3)          of ram_t;
type arr_values_t   is array (0 to CHANNELS-1) of unsigned(15 downto 0);
type arr_CHAN_RES_t is array (0 to CHANNELS-1) of unsigned(31 downto 0);
type psa_ram_t      is array (0 to 256)        of std_logic_vector(8 downto 0);

signal ram               : ram_arr_t := (others => (others => (others => '0')));
attribute syn_ramstyle of ram     : signal is "block_ram";

signal ram_wr_pointer    : unsigned(9 downto 0) := (others => '0');
signal ram_rd_pointer    : unsigned_array_10(0 to CHANNELS-1) := (others => (others => '0'));
signal ram_count         : unsigned_array_10(0 to CHANNELS-1) := (others => (others => '0'));

signal ram_write         : std_logic := '0';
signal ram_remove        : std_logic := '0';
signal reg_ram_remove    : std_logic := '0';
signal reg2_ram_remove   : std_logic := '0';
signal ram_read          : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
signal ram_debug_read    : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
signal ram_clear         : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
signal ram_reset         : std_logic := '0';
signal ram_data_in       : unsigned_array_18(0 to CHANNELS-1) := (others => (others => '0'));
signal ram_data_out      : unsigned_array_18(0 to CHANNELS-1); -- := (others => (others => '0'));
signal reg_ram_data_out  : unsigned_array_18(0 to CHANNELS-1) := (others => (others => '0'));
signal reg_buffer_addr   : std_logic_vector(4 downto 0);
signal reg_buffer_read   : std_logic;
signal last_ramread      : std_logic := '0';
signal ram_valid         : std_logic := '0';
signal ram_rd_move       : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
signal ram_rd_move_value : unsigned(9 downto 0) := (others => '0');

signal CONF              : cfg_t;
attribute syn_keep     of CONF : signal is true;
attribute syn_preserve of CONF : signal is true;

signal stop_writing      : std_logic := '0';
signal stop_writing_rdo  : std_logic := '0';
signal finished_readout  : std_logic := '0';
signal baseline_reset    : std_logic := '0';
signal readout_reset     : std_logic := '0';
attribute syn_keep     of baseline_reset : signal is true;
attribute syn_preserve of baseline_reset : signal is true;

signal RDO_write_main : std_logic := '0';
signal RDO_write_proc : std_logic := '0';
signal RDO_data_main  : std_logic_vector(31 downto 0) := (others => '0');
signal RDO_data_proc  : std_logic_vector(31 downto 0) := (others => '0');

signal baseline_averages : arr_CHAN_RES_t := (others => (others => '0'));
signal baseline          : arr_values_t   := (others => (others => '0'));
signal trigger_gen       : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
signal reset_threshold_counter : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
signal thresh_counter    : unsigned_array_10(CHANNELS-1 downto 0) := (others => (others => '0'));
signal readout_flag      : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');

signal after_trg_cnt     : unsigned(11 downto 0) := (others => '1');

type state_t is (IDLE, DO_RELEASE, RELEASE_DIRECT, WAIT_FOR_END, CHECK_STATUS_TRIGGER, START, SEND_STATUS, READOUT, PSA_READOUT);
signal state : state_t;
signal statebits : std_logic_vector(7 downto 0);
signal word_counter : unsigned(7 downto 0);

type rdo_state_t is (RDO_IDLE, READ_CHANNEL, NEXT_BLOCK, NEXT_CHANNEL, RDO_DONE, RDO_FINISH, RDO_WAIT_AFTER);
signal readout_state : rdo_state_t;
signal rdostatebits  : std_logic_vector(3 downto 0);
signal readout_finished : std_logic := '0';
signal readout_psa_finished : std_logic := '0';
signal channelselect, last_channelselect, channelselect_valid    : integer range 0 to 3 := 0;
signal prepare_header, last_prepare_header, prepare_header_valid : std_logic := '0';
signal blockcurrent, last_blockcurrent                           : integer range 0 to 3 := 0;
signal myavg : unsigned(7 downto 0);
signal ram_read_rdo        : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');

signal psa_data_i   : std_logic_vector(8 downto 0);
signal psa_write_i  : std_logic;
signal psa_addr_i   : std_logic_vector(7 downto 0);    
signal psa_ram      : psa_ram_t := (others => (others => '0'));
signal psa_ram_out, psa_ram_out_t  : std_logic_vector(8 downto 0);
signal psa_ram_out_ti : std_logic_vector(8 downto 0);
signal psa_output   : std_logic_vector(40 downto 0);
signal psa_clear    : std_logic;
signal psa_enable   : std_logic;
signal psa_pointer  : integer range 0 to 256 := 0;
signal ram_read_psa : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
type psa_state_t is (PSA_IDLE, PSA_START_CHANNEL, PSA_WAIT_RAM, PSA_WAIT_RAM2, PSA_CALC, PSA_WAITWRITE, PSA_WAITWRITE2, PSA_DOWRITE, PSA_FINISH, PSA_WAIT_AFTER);
signal psa_state    : psa_state_t := PSA_IDLE;
signal psa_adcdata  : std_logic_vector(15 downto 0);
signal RDO_write_psa : std_logic := '0';
signal RDO_data_psa  : std_logic_vector(31 downto 0) := (others => '0');


signal invalid_word_count : arr_CHAN_RES_t := (others => (others => '0'));

-- 800 - 83f last ADC values              (local 0x0 - 0x3)
-- 840 - 87f long-term average / baseline (local 0x4 - 0x7)
-- 880 - 8bf fifo access (debugging only) (local 0x8 - 0xb)

begin

reg_buffer_addr <= DEBUG_BUFFER_ADDR when rising_edge(CLK);
reg_buffer_read <= DEBUG_BUFFER_READ when rising_edge(CLK);

-------------------------------------------------------------------------------
-- Status registers
-------------------------------------------------------------------------------
PROC_REGS : process 
  variable c : integer range 0 to 3;
begin
  wait until rising_edge(CLK);
  c := to_integer(unsigned(reg_buffer_addr(1 downto 0)));
  DEBUG_BUFFER_DATA <= (others => '0');
  ram_debug_read    <= (others => '0');
  if reg_buffer_read = '1' then
    if reg_buffer_addr(4) = '0' then
      DEBUG_BUFFER_READY <= '1';
      case reg_buffer_addr(3 downto 2) is
        when "00" => DEBUG_BUFFER_DATA(RESOLUTION-1 downto 0) <= ADC_DATA(c*RESOLUTION+RESOLUTION-1 downto c*RESOLUTION); 
        when "01" => DEBUG_BUFFER_DATA(15 downto 0)  <= std_logic_vector(baseline(c)); 
        when "10" => DEBUG_BUFFER_DATA(17 downto 0)  <= std_logic_vector(reg_ram_data_out(to_integer(unsigned(reg_buffer_addr(1 downto 0)))));
                     ram_debug_read(to_integer(unsigned(reg_buffer_addr(1 downto 0)))) <= '1';
        when "11" => DEBUG_BUFFER_DATA  <= std_logic_vector(invalid_word_count(c));
        when others => null;  
      end case;
    else
      DEBUG_BUFFER_READY <= '1';
      DEBUG_BUFFER_DATA  <= (others => '0');
      case reg_buffer_addr(3 downto 0) is
        when x"0" => DEBUG_BUFFER_DATA <= std_logic_vector(resize(ram_count(1),16)) &  
                                          std_logic_vector(resize(ram_count(0),16));
        when x"1" => DEBUG_BUFFER_DATA <= std_logic_vector(resize(ram_count(3),16)) &  
                                          std_logic_vector(resize(ram_count(2),16));
        when x"2" => DEBUG_BUFFER_DATA(0)  <= stop_writing;
                     DEBUG_BUFFER_DATA(1)  <= stop_writing_rdo;
                     DEBUG_BUFFER_DATA(2)  <= STOP_IN;
                     DEBUG_BUFFER_DATA(3)  <= ram_remove;
                     DEBUG_BUFFER_DATA( 7 downto  4) <= ram_clear;
                     DEBUG_BUFFER_DATA(11 downto  8) <= ram_read;
                     DEBUG_BUFFER_DATA(12) <= ADC_VALID;
                     DEBUG_BUFFER_DATA(13) <= ram_write;
                     DEBUG_BUFFER_DATA(19 downto 16) <= trigger_gen;
                     DEBUG_BUFFER_DATA(23 downto 20) <= readout_flag;
        when x"3" => DEBUG_BUFFER_DATA <= std_logic_vector(resize(ram_wr_pointer,32));           
        when x"4" => DEBUG_BUFFER_DATA <= std_logic_vector(resize(ram_rd_pointer(1),16)) &  
                                          std_logic_vector(resize(ram_rd_pointer(0),16));           
        when x"5" => DEBUG_BUFFER_DATA <= std_logic_vector(resize(ram_rd_pointer(3),16)) &  
                                          std_logic_vector(resize(ram_rd_pointer(2),16));   
        when x"6" => DEBUG_BUFFER_DATA( 7 downto  0) <= statebits;
                     DEBUG_BUFFER_DATA(11 downto  8) <= rdostatebits;
        when others => null;
      end case;
    end if;  
  end if;
  
  DEBUG_BUFFER_READY <= reg_buffer_read;

end process;

CONF <= CONFIG when rising_edge(CLK);

ram_clear      <= (others => CONTROL(4)) when rising_edge(CLK);
ram_reset      <= CONTROL(5)  when rising_edge(CLK);
baseline_reset <= CONTROL(8)  when rising_edge(CLK);
readout_reset  <= CONTROL(12) when rising_edge(CLK);

-------------------------------------------------------------------------------
-- Check words
-------------------------------------------------------------------------------
gen_word_checker : for i in 0 to CHANNELS-1 generate
  process begin
    wait until rising_edge(CLK);
    if ADC_VALID = '1' then
      if ADC_DATA(RESOLUTION*(i+1)-1 downto RESOLUTION*i) /= CONF.check_word1 and
         ADC_DATA(RESOLUTION*(i+1)-1 downto RESOLUTION*i) /= CONF.check_word2 and 
         CONF.check_word_enable = '1' then
        invalid_word_count(i) <= invalid_word_count(i) + 1; 
      end if;
    end if;
  end process;
end generate;


-------------------------------------------------------------------------------
-- Preprocessing
-------------------------------------------------------------------------------
  proc_preprocessor : process 
    variable cnt : integer range 0 to 255 := 0;
  begin
    wait until rising_edge(CLK);
    ram_write <= '0';
    if ADC_VALID = '1' then
    
      gen_buffer_input : for i in 0 to CHANNELS-1 loop
        if cnt = 0 then
          ram_data_in(i)(15 downto 0) <=                  resize(unsigned(ADC_DATA(RESOLUTION*(i+1)-1 downto RESOLUTION*i)),16);
          ram_data_in(i)(17) <= trigger_gen(i);
        else
          ram_data_in(i)(15 downto 0) <= ram_data_in(i)(15 downto 0) + resize(unsigned(ADC_DATA(RESOLUTION*(i+1)-1 downto RESOLUTION*i)),16);
          ram_data_in(i)(17) <= ram_data_in(i)(17) or trigger_gen(i);
        end if;
      end loop;  
     
      if cnt = to_integer(CONF.presum) then
        cnt := 0;
        ram_write <= not stop_writing;
      elsif CONF.presum /= 0 then
        cnt := cnt + 1;
      end if;
    end if;
    
  end process;

--         if after_trg_cnt = 0 then
--           state <= READOUT;
--           stop_writing_rdo <= '1';
--         else
--           after_trg_cnt <= after_trg_cnt - 1;
--         end if;  

-------------------------------------------------------------------------------
-- Data buffers
-------------------------------------------------------------------------------
proc_buffer_enable : process begin
  wait until rising_edge(CLK);
  if READOUT_RX.valid_timing_trg = '1' then
    after_trg_cnt(10 downto 0) <= CONF.samples_after;
    after_trg_cnt(11)          <= '0';
  elsif state = IDLE then
    stop_writing_rdo <= '0';
    after_trg_cnt    <= (others => '1');  
  elsif or_all(std_logic_vector(after_trg_cnt)) = '0' then
    stop_writing_rdo <= '1';
    after_trg_cnt    <= (others => '1');
  elsif after_trg_cnt(11) = '0' then
    after_trg_cnt <= after_trg_cnt - 1;
  end if;
  
  stop_writing <= stop_writing_rdo or STOP_IN;
    
end process;


gen_buffers : for i in 0 to CHANNELS-1 generate
  process begin
    wait until rising_edge(CLK);
    if ram_write = '1' then
      ram(i)(to_integer(ram_wr_pointer)) <= ram_data_in(i);
    end if; 
    ram_data_out(i)     <= ram(i)(to_integer(ram_rd_pointer(i)));
    reg_ram_data_out(i) <= ram_data_out(i);
  end process;  
end generate;


proc_buffer_write : process begin
  wait until rising_edge(CLK);
  if ram_reset = '1' then
    ram_wr_pointer <= (others => '0');
  elsif ram_write = '1' then
    ram_wr_pointer <= ram_wr_pointer + 1;
  end if;
end process;


proc_buffer_rotate  : process begin
  wait until rising_edge(CLK);
  if ram_count(0) >= CONF.buffer_depth and ram_write = '1' then
    ram_remove  <= '1';
  else  
    ram_remove  <= '0';
  end if;
  reg_ram_remove  <= ram_remove;
  reg2_ram_remove <= reg_ram_remove;
end process;


gen_buffer_reader : for i in 0 to CHANNELS-1 generate
  proc_buffer_reader : process begin
    wait until rising_edge(CLK);
    
    if (ram_read(i) or ram_remove or ram_debug_read(i)) = ram_write then
      ram_count(i)        <= ram_wr_pointer - ram_rd_pointer(i);
    elsif (ram_read(i) or ram_remove or ram_debug_read(i)) = '1' then
      ram_count(i)        <= ram_wr_pointer - ram_rd_pointer(i) -1;
    elsif ram_write = '1' then
      ram_count(i)        <= ram_wr_pointer - ram_rd_pointer(i) +1;
    end if;
    
    if ram_reset = '1' then
      ram_rd_pointer(i)  <= (others => '1'); --one behind write pointer
    elsif ram_clear(i) = '1' then
      ram_rd_pointer(i)  <= ram_wr_pointer;
    elsif ram_read(i) = '1' then
      ram_rd_pointer(i)  <= ram_rd_pointer(i) + 1;
    elsif ram_debug_read(i) = '1' then  
      ram_rd_pointer(i)  <= ram_rd_pointer(i) + 1;
    elsif ram_remove = '1' then
      ram_rd_pointer(i)  <= ram_rd_pointer(i) + 1;
    elsif ram_rd_move(i) = '1' then
      ram_rd_pointer(i) <= ram_rd_pointer(i) - ram_rd_move_value;
    end if;
    
  end process;  
end generate;
 


-------------------------------------------------------------------------------
-- Baseline
-------------------------------------------------------------------------------
gen_baselines : for i in 0 to CHANNELS-1 generate
  proc_baseline_calc : process begin
    wait until rising_edge(CLK);
    if baseline_reset = '1' or CONF.baseline_reset_value(31) = '1' then
      baseline_averages(i) <= "00" & CONF.baseline_reset_value(29 downto 0);
    elsif reg2_ram_remove = '1' and (reg_ram_data_out(i)(17) = '0' or CONF.baseline_always_on = '1') then
      baseline_averages(i) <= baseline_averages(i) 
                              + resize(reg_ram_data_out(i)(15 downto 0),32) 
                              - resize(baseline_averages(i)(to_integer(CONF.averaging)+15 downto to_integer(CONF.averaging)),32);
    end if;
    baseline(i) <= baseline_averages(i)(to_integer(CONF.averaging)+15 downto to_integer(CONF.averaging));
  end process;
end generate;





-------------------------------------------------------------------------------
-- Trigger Output
-------------------------------------------------------------------------------
gen_triggers : for i in 0 to CHANNELS-1 generate
  proc_trigger : process begin
    wait until rising_edge(CLK);
    if ram_write = '1' then
      if   (ram_data_in(i)(15 downto 0) > unsigned(signed(baseline(i)) + CONF.trigger_threshold(15 downto 0)) and CONF.trigger_threshold(16) = '0') 
        or (ram_data_in(i)(15 downto 0) < unsigned(signed(baseline(i)) + CONF.trigger_threshold(15 downto 0)) and CONF.trigger_threshold(16) = '1') then
        trigger_gen(i) <= '1';
      else  
        trigger_gen(i) <= '0';
      end if;   
--     elsif stop_writing = '1' then
--       trigger_gen(i) <= '0';
    end if;  
  end process;
end generate;

TRIGGER_OUT <= or_all(trigger_gen and CONF.trigger_enable((DEVICE+1)*CHANNELS-1 downto DEVICE*CHANNELS)) when rising_edge(CLK);


-------------------------------------------------------------------------------
-- Readout Threshold
-------------------------------------------------------------------------------
gen_rdo_thresh : for i in 0 to CHANNELS-1 generate
  proc_readout_threshold : process begin
    wait until rising_edge(CLK);
    if thresh_counter(i) > 0 and ram_write = '1' then
      thresh_counter(i) <= thresh_counter(i) - 1;    
    end if;  
    
    if thresh_counter(i) > 0 then
      readout_flag(i) <= '1';
    else
      readout_flag(i) <= '0';
    end if;
    
    if     (ram_data_in(i)(15 downto 0) > unsigned(signed(baseline(i)) + CONF.readout_threshold(15 downto 0)) and CONF.readout_threshold(16) = '0') 
        or (ram_data_in(i)(15 downto 0) < unsigned(signed(baseline(i)) + CONF.readout_threshold(15 downto 0)) and CONF.readout_threshold(16) = '1') then
      reset_threshold_counter(i) <= '1';
    else
      reset_threshold_counter(i) <= '0';   
    end if;
    
    if reset_threshold_counter(i) = '1' then
      thresh_counter(i) <= CONF.buffer_depth(9 downto 0);  
    end if;    
  end process;
end generate;


-------------------------------------------------------------------------------
-- Memory for PSA coefficients
-------------------------------------------------------------------------------
psa_write_i <= PSA_WRITE when rising_edge(CLK);
psa_addr_i  <= PSA_ADDR  when rising_edge(CLK);
psa_data_i  <= PSA_DATA  when rising_edge(CLK);
PSA_DATA_OUT<= psa_ram_out_ti when rising_edge(CLK);
psa_ram_out <= psa_ram_out_t  when rising_edge(CLK);

THE_PSA_MEMORY: process begin
  wait until rising_edge(CLK);
  if psa_write_i = '1' then
    psa_ram(to_integer(unsigned('0' & psa_addr_i))) <= psa_data_i;
  end if; 
  psa_ram_out_ti     <= psa_ram(to_integer(unsigned('0' & psa_addr_i)));
  psa_ram_out_t      <= psa_ram(psa_pointer);
end process;  

-------------------------------------------------------------------------------
-- Multiply Accumulate for PSA
-------------------------------------------------------------------------------
THE_MULACC : entity work.mulacc2
  port map(
    CLK0 => CLK,
    CE0  => psa_enable,
    RST0 => psa_clear, 
    ACCUMSLOAD => '0',
    A => psa_ram_out,
    B => psa_adcdata,
    LD => (others => '0'),
    OVERFLOW => open, 
    ACCUM => psa_output
    );

-------------------------------------------------------------------------------
-- Readout State Machine
-------------------------------------------------------------------------------
proc_readout : process 
begin
  wait until rising_edge(CLK);
  READOUT_TX.busy_release  <= '0';
  READOUT_TX.data_finished <= '0';
  RDO_data_main            <= (others => '0');
  RDO_write_main           <= '0';
  finished_readout         <= '0';
  
  case state is
    when IDLE =>
      READOUT_TX.statusbits <= (others => '0');
      if READOUT_RX.valid_notiming_trg = '1' then
        state <= CHECK_STATUS_TRIGGER;
      elsif READOUT_RX.data_valid = '1' then   --seems to have missed trigger...
        READOUT_TX.statusbits    <= (23 => '1', others => '0');  --event not found
        state <= RELEASE_DIRECT;
      elsif READOUT_RX.valid_timing_trg = '1' then
        state <= START;
      end if;  
      
    when RELEASE_DIRECT =>
      state <= DO_RELEASE;
      
    when DO_RELEASE =>  
      if READOUT_RX.data_valid = '1' then
        finished_readout         <= '1';
        READOUT_TX.busy_release  <= '1';
        READOUT_TX.data_finished <= '1';
        state                    <= WAIT_FOR_END;
      end if;  
    
    when WAIT_FOR_END =>
      if READOUT_RX.data_valid = '0' then
        state <= IDLE;
      end if;
      
    when CHECK_STATUS_TRIGGER =>    
      if READOUT_RX.data_valid = '1' then
        if READOUT_RX.trg_type = x"E" then
          state <= SEND_STATUS;
          word_counter <= (others => '0');
        else
          state <= RELEASE_DIRECT;
        end if;
      end if;  
      
    when START =>
      if stop_writing_rdo = '1' and CONF.processing_mode = 0 then
        state <= READOUT;
      elsif stop_writing_rdo = '1' and CONF.processing_mode = 1 then 
        state <= PSA_READOUT;
      end if;
    
    when READOUT =>
      if readout_finished  = '1' then
        state <= RELEASE_DIRECT;
      end if;

    when PSA_READOUT =>
      if readout_psa_finished  = '1' then
        state <= RELEASE_DIRECT;
      end if;
      
    when SEND_STATUS =>
      RDO_write_main <= '1';   
      RDO_data_main  <= x"2" & std_logic_vector(word_counter) & x"00000";
      word_counter <= word_counter + 1;
      case word_counter is
        when x"00" =>
          if DEVICE = 0 then
            RDO_data_main(31 downto 0) <= x"40" & std_logic_vector(to_unsigned(DEVICE,4)) & x"F00" & x"0d" ;
          else
            RDO_data_main(31 downto 0) <= x"40" & std_logic_vector(to_unsigned(DEVICE,4)) & x"F00" & x"04" ;
            word_counter <= x"10";
          end if;
        when x"01" =>  
          RDO_data_main(10 downto 0) <= std_logic_vector(CONF.buffer_depth);
        when x"02" =>
          RDO_data_main(10 downto 0) <= std_logic_vector(CONF.samples_after);
        when x"03" =>
          RDO_data_main(17 downto 0) <= std_logic_vector(CONF.trigger_threshold);
        when x"04" =>
          RDO_data_main(17 downto 0) <= std_logic_vector(CONF.readout_threshold);
        when x"05" =>
          RDO_data_main( 7 downto 0)  <= std_logic_vector(CONF.presum);
          RDO_data_main(11 downto 8)  <= std_logic_vector(CONF.averaging);
          RDO_data_main(13 downto 12) <= std_logic_vector(CONF.block_count);
        when x"06" =>
          RDO_data_main( 7 downto  0) <= std_logic_vector(CONF.block_avg(0));
          RDO_data_main(15 downto  8) <= std_logic_vector(CONF.block_sums(0));
          RDO_data_main(19 downto 16) <= std_logic_vector(CONF.block_scale(0)(3 downto 0));
        when x"07" =>
          RDO_data_main( 7 downto  0) <= std_logic_vector(CONF.block_avg(1));
          RDO_data_main(15 downto  8) <= std_logic_vector(CONF.block_sums(1));
          RDO_data_main(19 downto 16) <= std_logic_vector(CONF.block_scale(1)(3 downto 0));
        when x"08" =>
          RDO_data_main( 7 downto  0) <= std_logic_vector(CONF.block_avg(2));
          RDO_data_main(15 downto  8) <= std_logic_vector(CONF.block_sums(2));
          RDO_data_main(19 downto 16) <= std_logic_vector(CONF.block_scale(2)(3 downto 0));
        when x"09" =>
          RDO_data_main( 7 downto  0) <= std_logic_vector(CONF.block_avg(3));
          RDO_data_main(15 downto  8) <= std_logic_vector(CONF.block_sums(3));
          RDO_data_main(19 downto 16) <= std_logic_vector(CONF.block_scale(3)(3 downto 0));
          word_counter <= x"10";
        when x"10" =>
          RDO_data_main(15 downto  0) <= std_logic_vector(baseline(0));
        when x"11" =>
          RDO_data_main(15 downto  0) <= std_logic_vector(baseline(1));
        when x"12" =>
          RDO_data_main(15 downto  0) <= std_logic_vector(baseline(2));
        when x"13" =>
          RDO_data_main(15 downto  0) <= std_logic_vector(baseline(3));
          state                 <= RELEASE_DIRECT;
        when others =>
          state <= RELEASE_DIRECT;
      end case;
  end case;
  
  if readout_reset = '1' then
    state <= IDLE;
  end if;
end process;


-------------------------------------------------------------------------------
-- Data Reading State Machine
-------------------------------------------------------------------------------
PROC_RDO_FSM : process 
  variable readcount     : integer range 0 to 255 := 0;
begin
  wait until rising_edge(CLK);
  readout_finished <= '0';
  ram_read_rdo     <= (others => '0');
  prepare_header   <= '0';
  
  case readout_state is
    when RDO_IDLE =>
      if state = READOUT then
        channelselect <= 0;
        blockcurrent  <= 0;
        readcount     := to_integer(CONF.block_sums(0) * CONF.block_avg(0));
        readout_state <= READ_CHANNEL;
        prepare_header <= '1';
      end if;
    
    when READ_CHANNEL =>
      ram_read_rdo(channelselect) <= '1';
      if readcount = 1 or ram_count(channelselect) = 1 then
        if blockcurrent < to_integer(CONF.block_count)-1 then
          readout_state <= NEXT_BLOCK;
        elsif channelselect < 3 then
          readout_state <= NEXT_CHANNEL;
        else
          readout_state <= RDO_DONE;
        end if;    
      else
        readcount := readcount - 1;
      end if;
      
    when NEXT_BLOCK =>
      channelselect <= channelselect;
      blockcurrent  <= blockcurrent + 1;
      readcount     := to_integer(CONF.block_sums(blockcurrent + 1) * CONF.block_avg(blockcurrent + 1));
      readout_state <= READ_CHANNEL;      
      
    when NEXT_CHANNEL =>
      channelselect  <= channelselect + 1;
      blockcurrent   <= 0;
      readcount      := to_integer(CONF.block_sums(0) * CONF.block_avg(0));
      readout_state  <= READ_CHANNEL;      
      prepare_header <= '1';
    
    when RDO_DONE =>
      readout_state <= RDO_FINISH;
    
    when RDO_FINISH =>
      readout_finished <= '1';
      readout_state    <= RDO_WAIT_AFTER;
      
    when RDO_WAIT_AFTER =>
      readout_state    <= RDO_IDLE;
      
  end case;  
end process;

last_ramread         <= ram_read(channelselect) when rising_edge(CLK);
ram_valid            <= last_ramread when rising_edge(CLK);
last_prepare_header  <= prepare_header when rising_edge(CLK);
prepare_header_valid <= last_prepare_header when rising_edge(CLK);
last_channelselect   <= channelselect when rising_edge(CLK);
channelselect_valid  <= last_channelselect when rising_edge(CLK);
last_blockcurrent    <= blockcurrent when rising_edge(CLK);
myavg                <= CONF.block_avg(last_blockcurrent) when rising_edge(CLK);


PROC_DATA_PROCESSOR: process 
  variable cnt      : integer range 0 to 255 := 0; 
begin
  wait until rising_edge(CLK);
  RDO_write_proc <= '0';
  
  if prepare_header_valid = '1' or ram_valid = '0' then
    cnt := 0;
  end if;  
  
  if ram_valid = '1' and readout_state /= RDO_IDLE then
    if cnt = 0 then
      RDO_data_proc(15 downto  0) <= std_logic_vector(reg_ram_data_out(channelselect_valid)(15 downto 0));
      RDO_data_proc(19 downto 16) <= std_logic_vector(to_unsigned(channelselect_valid,4));
      RDO_data_proc(23 downto 20) <= std_logic_vector(to_unsigned(DEVICE,4)); 
      RDO_data_proc(31 downto 24) <= (others => '0');
    else
      RDO_data_proc(15 downto  0) <= std_logic_vector(unsigned(RDO_data_proc(15 downto 0)) + reg_ram_data_out(channelselect_valid)(15 downto 0));
    end if;
    if cnt = to_integer(myavg-1) then
      cnt := 0;
      RDO_write_proc <= not CONF.channel_disable(DEVICE*CHANNELS+channelselect_valid);
    elsif myavg /= 0 then
      cnt := cnt + 1;
    end if;
  end if;  

  if readout_state = RDO_IDLE then
    RDO_data_proc <= (others => '0');
    RDO_write_proc <= '0';
  end if;  
  
end process;


-------------------------------------------------------------------------------
-- Data Reading State Machine
-------------------------------------------------------------------------------
PROC_PULSE_SHAPE_READOUT : process 
  variable wordcount : integer range 0 to 256 := 0;
  variable readcount : integer range 0 to 255 := 0;
  variable channel   : integer range 0 to CHANNELS-1 := 0;
  variable time_cnt   : integer range 0 to 5 := 0;
begin
  wait until rising_edge(CLK);
  ram_read_psa         <= (others => '0');
  ram_rd_move          <= (others => '0');
  readout_psa_finished <= '0';
  psa_adcdata          <= std_logic_vector(reg_ram_data_out(channel)(15 downto 0));
  psa_clear            <= '0';
  psa_enable           <= '1';
  RDO_write_psa        <= '0';
  case psa_state is
    when PSA_IDLE =>
      channel        := 0;
      readcount      := to_integer(CONF.block_avg(0));
      wordcount      := to_integer(CONF.block_sums(0));
      psa_pointer    <= 256;
      psa_clear      <= '1';
      if state = PSA_READOUT then
        psa_state      <= PSA_START_CHANNEL;
      end if;
    when PSA_START_CHANNEL =>
      ram_read_psa(channel) <= '1';
      readcount   := readcount - 1;
      psa_clear   <= '1';
      psa_state   <= PSA_WAIT_RAM;
    when PSA_WAIT_RAM =>
      ram_read_psa(channel) <= '1';
      readcount   := readcount - 1;
      psa_clear   <= '1';
      psa_state   <= PSA_WAIT_RAM2;
    when PSA_WAIT_RAM2 =>
      ram_read_psa(channel) <= '1';
      psa_pointer <= 0;
      psa_clear   <= '1';
      psa_state   <= PSA_CALC;
    when PSA_CALC =>
      if readcount = 1 then
        psa_pointer <= psa_pointer + 1;
        psa_state   <= PSA_WAITWRITE;
      else
        ram_read_psa(channel) <= '1';
        psa_pointer <= psa_pointer + 1;
        readcount   := readcount - 1;    
      end if;
    when PSA_WAITWRITE   =>
      time_cnt    := 4;
      psa_pointer <= psa_pointer + 1;
      psa_state   <= PSA_WAITWRITE2;
    
    when PSA_WAITWRITE2 =>
      psa_pointer <= 256;
      time_cnt    := time_cnt -1;
      if time_cnt = 0 then
        psa_state <= PSA_DOWRITE;
      end if;  
    when PSA_DOWRITE =>
      RDO_write_psa <= '1';
      RDO_data_psa(15 downto  0) <= psa_output(to_integer(CONF.block_scale(0))+15 downto to_integer(CONF.block_scale(0)));
      RDO_data_psa(19 downto 16) <= std_logic_vector(to_unsigned(channel,4));
      RDO_data_psa(23 downto 20) <= std_logic_vector(to_unsigned(DEVICE,4)); 
      RDO_data_psa(27 downto 24) <= x"0";
      RDO_data_psa(31 downto 28) <= x"3";
      if wordcount > 1 then
        wordcount := wordcount - 1;
        readcount := to_integer(CONF.block_avg(0));
        psa_state <= PSA_START_CHANNEL;
        ram_rd_move(channel) <= '1';
        ram_rd_move_value <= ("00" & CONF.block_avg(0)) - 1;
      elsif channel < 3 then
        channel   := channel + 1;
        readcount := to_integer(CONF.block_avg(0));
        wordcount := to_integer(CONF.block_sums(0));
        psa_state <= PSA_START_CHANNEL;
      else
        psa_state <= PSA_FINISH;
      end if;
      
    when PSA_FINISH =>
      readout_psa_finished <= '1';
      psa_state            <= PSA_WAIT_AFTER;
      
    when PSA_WAIT_AFTER =>
      psa_state    <= PSA_IDLE;
      
  
  end case;
end process;

-------------------------------------------------------------------------------
-- Data Output
-------------------------------------------------------------------------------

ram_read <= ram_read_rdo or ram_read_psa;
READOUT_TX.data_write <= RDO_write_main or RDO_write_proc or RDO_write_psa when rising_edge(CLK);
READOUT_TX.data       <= RDO_data_main  or RDO_data_proc  or RDO_data_psa  when rising_edge(CLK);



-------------------------------------------------------------------------------
-- Status Information
-------------------------------------------------------------------------------
statebits <= x"00" when state = IDLE else
             x"01" when state = RELEASE_DIRECT else
             x"02" when state = WAIT_FOR_END else
             x"03" when state = CHECK_STATUS_TRIGGER else
             x"04" when state = START else
             x"05" when state = READOUT else
             x"06" when state = DO_RELEASE else
             x"07" when state = SEND_STATUS else
             x"FF";

rdostatebits <= x"0" when readout_state = RDO_IDLE else
                x"1" when readout_state = READ_CHANNEL else
                x"2" when readout_state = NEXT_BLOCK else
                x"3" when readout_state = NEXT_CHANNEL else
                x"4" when readout_state = RDO_DONE else
                x"5" when readout_state = RDO_WAIT_AFTER else
                x"F";
             
end architecture;


--   type READOUT_RX is record 
--     data_valid         : std_logic;
--     valid_timing_trg   : std_logic;
--     valid_notiming_trg : std_logic;
--     invalid_trg        : std_logic;
--     --
--     trg_type           : std_logic_vector( 3 downto 0);
--     trg_number         : std_logic_vector(15 downto 0);
--     trg_code           : std_logic_vector( 7 downto 0);
--     trg_information    : std_logic_vector(23 downto 0);
--     trg_int_number     : std_logic_vector(15 downto 0);    
--     --
--     trg_multiple       : std_logic;
--     trg_timeout        : std_logic;
--     trg_spurious       : std_logic;
--     trg_missing        : std_logic;
--     trg_spike          : std_logic;
--     --
--     buffer_almost_full : std_logic;
--   end record; 
--   
--   
--   type READOUT_TX is record
--     busy_release  : std_logic;
--     statusbits    : std_logic_vector(31 downto 0);
--     data          : std_logic_vector(31 downto 0);
--     data_write    : std_logic;
--     data_finished : std_logic;
--   end record;
--  

-- 
-- type cfg_t is record
--   buffer_depth      : unsigned(10 downto 0);
--   samples_after     : unsigned(10 downto 0);
--   block_count       : unsigned( 1 downto 0);
--   trigger_threshold : unsigned(17 downto 0);
--   readout_threshold : unsigned(17 downto 0);
--   presum            : unsigned( 7 downto 0);
--   averaging         : unsigned( 3 downto 0);
--   block_avg         : unsigned_array_8(0 to 3);
--   block_sums        : unsigned_array_8(0 to 3);
--   block_scale       : unsigned_array_8(0 to 3);
-- end record;

-- 0-ACVVVV  -- ADC data, 16 bit data, MSN=0x0
-- vVVVvVVV  -- ADC data, 2x 15 bit only after 0x0 channel header, MSB=1
-- VVVVVVVV  -- ADC data  2x 16 bit, only after 0x4 channel header
-- 1SSSSSSS  -- Status word, MSN=0x1
-- 4-AC--LL  -- ADC Header, L: number of data words that follow, MSN=0x4
-- 2RRVVVVV  -- Configuration data
-- 3-ACVVVV  -- Processed values
