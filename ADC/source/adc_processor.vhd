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

attribute syn_hier of adc_processor_arch : architecture is "flatten, firm";

type ram_t          is array (0 to 1023)       of unsigned(17 downto 0);
type ram_arr_t      is array (0 to 3)          of ram_t;
type arr_values_t   is array (0 to CHANNELS-1) of unsigned(15 downto 0);
type arr_CHAN_RES_t is array (0 to CHANNELS-1) of unsigned(31 downto 0);

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
signal ram_data_out      : unsigned_array_18(0 to CHANNELS-1) := (others => (others => '0'));
signal reg_ram_data_out  : unsigned_array_18(0 to CHANNELS-1) := (others => (others => '0'));
signal reg_buffer_addr   : std_logic_vector(4 downto 0);
signal reg_buffer_read   : std_logic;

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

signal baseline_averages : arr_CHAN_RES_t := (others => (others => '0'));
signal baseline          : arr_values_t   := (others => (others => '0'));
signal trigger_gen       : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
signal reset_threshold_counter : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
signal thresh_counter    : unsigned_array_10(CHANNELS-1 downto 0) := (others => (others => '0'));
signal readout_flag      : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');

signal after_trg_cnt     : unsigned(11 downto 0) := (others => '1');

type state_t is (IDLE, RELEASE_DIRECT, WAIT_FOR_END, CHECK_STATUS_TRIGGER, START, SEND_STATUS, READOUT, NEXT_BLOCK);
signal state : state_t;

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
        when "11" => 
          DEBUG_BUFFER_DATA  <= (others => '0');
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
  elsif after_trg_cnt(11) = '0' then
    after_trg_cnt <= after_trg_cnt - 1;
  end if;
  
  if or_all(std_logic_vector(after_trg_cnt)) = '0' then
    stop_writing_rdo <= '1';
    after_trg_cnt    <= (others => '1');
  end if;  
  
  if finished_readout = '1' then
    stop_writing_rdo <= '0';
  end if;  
  
  stop_writing <= stop_writing_rdo or STOP_IN;
  
  if readout_reset = '1' then
    stop_writing_rdo <= '0';
    after_trg_cnt    <= (others => '1');
  end if;
  
end process;


gen_buffers : for i in 0 to CHANNELS-1 generate
  process begin
    wait until rising_edge(CLK);
    if ram_write = '1' then
      ram(i)(to_integer(ram_wr_pointer)) <= ram_data_in(i);
    end if; 
    ram_data_out(i) <= ram(i)(to_integer(ram_rd_pointer(i)));
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
    
    reg_ram_data_out(i) <= ram_data_out(i);
    
    if ram_reset = '1' then
      ram_rd_pointer(i) <= (others => '1'); --one behind write pointer
    elsif ram_clear(i) = '1' then
      ram_rd_pointer(i) <= ram_wr_pointer;
    elsif ram_read(i) = '1' then
      ram_rd_pointer(i)  <= ram_rd_pointer(i) + 1;
    elsif ram_debug_read(i) = '1' then  
      ram_rd_pointer(i)  <= ram_rd_pointer(i) + 1;
    elsif ram_remove = '1' then
      ram_rd_pointer(i) <= ram_rd_pointer(i) + 1;
    end if;
    
  end process;  
end generate;
 


-------------------------------------------------------------------------------
-- Baseline
-------------------------------------------------------------------------------
gen_baselines : for i in 0 to CHANNELS-1 generate
  proc_baseline_calc : process begin
    wait until rising_edge(CLK);
    if baseline_reset = '1' then
      baseline_averages(i) <= CONF.baseline_reset_value;
    elsif reg2_ram_remove = '1' and (ram_data_out(i)(17) = '0' or CONF.baseline_always_on = '1') then
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
      if   (ram_data_in(i)(15 downto 0) > baseline(i) + CONF.trigger_threshold(15 downto 0) and CONF.trigger_threshold(16) = '0') 
        or (ram_data_in(i)(15 downto 0) < baseline(i) + CONF.trigger_threshold(15 downto 0) and CONF.trigger_threshold(16) = '1') then
        trigger_gen(i) <= '1';
      else  
        trigger_gen(i) <= '0';
      end if;   
    elsif stop_writing = '1' then
      trigger_gen(i) <= '0';
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
    
    if  (ram_data_in(i)(15 downto 0) > baseline(i) + CONF.readout_threshold(15 downto 0) and CONF.readout_threshold(16) = '0') 
        or (ram_data_in(i)(15 downto 0) < baseline(i) + CONF.readout_threshold(15 downto 0) and CONF.readout_threshold(16) = '1') then
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
-- Readout State Machine
-------------------------------------------------------------------------------
proc_readout : process 
  variable wordcount   : integer range 0 to 1023 := 0;
  variable blockcount  : integer range 0 to 3    := 0;
  variable sumcount    : integer range 0 to 1023 := 0;
begin
  wait until rising_edge(CLK);
  READOUT_TX.busy_release  <= '0';
  READOUT_TX.data_finished <= '0';
  READOUT_TX.data_write    <= '0';
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
        else
          state <= RELEASE_DIRECT;
        end if;
      end if;  
      
    when START =>
      if stop_writing_rdo = '1' then
        state <= READOUT;
      end if;
    
    when READOUT =>
      state <= RELEASE_DIRECT;
      READOUT_TX.data <= x"DEADBEEF";
      READOUT_TX.data_write <= '1';
          
    when NEXT_BLOCK =>
      if blockcount = CONF.block_count -1 then
        state      <= RELEASE_DIRECT;
        blockcount := 0;
      else  
        state      <= READOUT;
        blockcount := blockcount + 1;
      end if;
      
    when SEND_STATUS =>
      state <= RELEASE_DIRECT;
      READOUT_TX.data <= x"DECAFBAD";
      READOUT_TX.data_write <= '1';      
  end case;
end process;

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

