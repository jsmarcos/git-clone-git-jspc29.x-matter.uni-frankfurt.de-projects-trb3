library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;

entity tb is
end entity;


architecture tb_arch of tb is

component adc_ad9219
  generic(NUM_DEVICES : integer := 5);
  port(CLK            : in  std_logic;
       CLK_ADCRAW     : in  std_logic;
       RESTART_IN     : in  std_logic;
       ADCCLK_OUT     : out std_logic;
       ADC_DATA       : in  std_logic_vector(NUM_DEVICES * (CHANNELS + 1) - 1 downto 0);
       ADC_DCO        : in  std_logic_vector(NUM_DEVICES downto 1);
       DATA_OUT       : out std_logic_vector(NUM_DEVICES * CHANNELS * RESOLUTION - 1 downto 0);
       FCO_OUT        : out std_logic_vector(NUM_DEVICES * RESOLUTION - 1 downto 0);
       DATA_VALID_OUT : out std_logic_vector(NUM_DEVICES - 1 downto 0);
       DEBUG          : out std_logic_vector(NUM_DEVICES * 32 - 1 downto 0));
end component adc_ad9219;

component adc_processor is
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
end component;

signal clock100 : std_logic := '1';
signal clock200 : std_logic := '1';
signal adc_data   : std_logic_vector(39 downto 0) := (others => '0');
signal adc_valid  : std_logic_vector(0 downto 0) := (others => '1');
signal stop_in    : std_logic := '0';
signal trigger_out: std_logic := '0';
signal config     : cfg_t;
signal readout_rx : READOUT_RX;
signal readout_tx : READOUT_TX;
signal control    : std_logic_vector(63 downto 0);

signal psa_data   : std_logic_vector(8 downto 0) := (others => '0');
signal psa_write  : std_logic := '0';
signal psa_addr   : std_logic_vector(7 downto 0) := (others => '0');

begin

clock100 <= not clock100 after 5 ns;

clock200 <= not clock200 after 2.5 ns;


-- 
-- config.buffer_depth      <= to_unsigned(100 ,11);
-- config.samples_after     <= to_unsigned(20  ,11);
-- config.block_count       <= to_unsigned(3   , 2); 
-- config.trigger_threshold <= to_unsigned(70  ,18);
-- config.readout_threshold <= to_unsigned(70  ,18);
-- config.presum            <= to_unsigned(0   , 8);           
-- config.averaging         <= to_unsigned(5   , 4);
-- config.block_avg(0)      <= to_unsigned(1   , 8);
-- config.block_avg(1)      <= to_unsigned(2   , 8);
-- config.block_avg(2)      <= to_unsigned(4   , 8);
-- config.block_avg(3)      <= to_unsigned(1   , 8);
-- config.block_sums(0)     <= to_unsigned(4   , 8);       
-- config.block_sums(1)     <= to_unsigned(4   , 8);       
-- config.block_sums(2)     <= to_unsigned(4   , 8);       
-- config.block_sums(3)     <= to_unsigned(2   , 8);       
-- config.block_scale(0)    <= to_unsigned(0   , 8);      
-- config.block_scale(1)    <= to_unsigned(0   , 8);      
-- config.block_scale(2)    <= to_unsigned(0   , 8);      
-- config.block_scale(3)    <= to_unsigned(0   , 8); 
-- config.baseline_reset_value <= x"300";

config.trigger_enable    <= x"0000_0000_0000", x"ffff_ffff_ffff" after 5 us;
config.baseline_always_on <= '0'; --'1', '0' after 40 us;

config.processing_mode   <= 2;
config.buffer_depth      <= to_unsigned(128 ,11);
config.samples_after     <= to_unsigned(8  ,11);
config.block_count       <= to_unsigned(2   , 2); 
config.trigger_threshold(15 downto 0) <= to_unsigned(30  ,16);
config.trigger_threshold(16) <= '1'; -- invert polarity
config.trigger_threshold(17) <= '1'; -- unused 
config.readout_threshold <= to_unsigned(30  ,18);
config.presum            <= to_unsigned(0   , 8);           
config.averaging         <= to_unsigned(8   , 4);
config.block_avg(0)      <= to_unsigned(4   , 8);
config.block_avg(1)      <= to_unsigned(1   , 8);
config.block_avg(2)      <= to_unsigned(1   , 8);
config.block_avg(3)      <= to_unsigned(1   , 8);
config.block_sums(0)     <= to_unsigned(5   , 8);       
config.block_sums(1)     <= to_unsigned(7   , 8);       
config.block_sums(2)     <= to_unsigned(4   , 8);       
config.block_sums(3)     <= to_unsigned(2   , 8);       
config.block_scale(0)    <= to_unsigned(0   , 8);      
config.block_scale(1)    <= to_unsigned(0   , 8);      
config.block_scale(2)    <= to_unsigned(0   , 8);      
config.block_scale(3)    <= to_unsigned(0   , 8); 
config.baseline_reset_value <= to_unsigned(2**(to_integer(config.averaging))*3*16*16, 32);
config.channel_disable <= (others => '0');
config.check_word1     <= (others => '0');
config.check_word2     <= (others => '0');
config.check_word_enable <= '0';
config.cfd_window <= to_unsigned(100, 8);
config.cfd_delay <= to_unsigned(2, 4);


readout_rx.valid_notiming_trg <= '0';
readout_rx.invalid_trg        <= '0';
readout_rx.trg_type           <= (others => '0');
readout_rx.trg_number         <= (others => '0');
readout_rx.trg_code           <= (others => '0');
readout_rx.trg_information    <= (others => '0');
readout_rx.trg_int_number     <= (others => '0');    
readout_rx.trg_multiple       <= '0';
readout_rx.trg_timeout        <= '0';
readout_rx.trg_spurious       <= '0';
readout_rx.trg_missing        <= '0';
readout_rx.trg_spike          <= '0';
readout_rx.buffer_almost_full <= '0';

control <= (others => '0'), (8 => '1',others => '0') after 1 us, (others => '0') after 1.01 us,(5 => '1',others => '0') after 5 us, (others => '0') after 5.01 us ;

proc_write_psa : process begin
  wait for 1 us;
  wait until rising_edge(clock100); wait for 0.5 ns;
  psa_write <= '1';
  psa_addr <= x"00";
  psa_data <= "0"&x"01";
  wait until rising_edge(clock100); wait for 0.5 ns;
  psa_addr <= x"01";
  psa_data <= "0"&x"02";
  wait until rising_edge(clock100); wait for 0.5 ns;
  psa_addr <= x"02";
  psa_data <= "0"&x"03";
  wait until rising_edge(clock100); wait for 0.5 ns;
  psa_addr <= x"03";
  psa_data <= "1"&x"ff";
  wait until rising_edge(clock100); wait for 0.5 ns;
  psa_write <= '0';
  wait;
end process;


proc_rdo : process begin
  readout_rx.data_valid       <= '0';
  readout_rx.valid_timing_trg <= '0';
  wait for 15 us; wait until rising_edge(clock100); wait for 0.5 ns;
  readout_rx.valid_timing_trg <= '1';
  wait until rising_edge(clock100); wait for 0.5 ns;
  readout_rx.valid_timing_trg <= '0';
  wait for 250 ns; wait until rising_edge(clock100); wait for 0.5 ns;
  readout_rx.data_valid       <= '1';
  wait until readout_tx.busy_release = '1';
  wait for 10 ns; wait until rising_edge(clock100); wait for 0.5 ns;
  readout_rx.data_valid       <= '0';
end process;

THE_ADC : adc_ad9219
  generic map(
    NUM_DEVICES => 1
  )
  port map(CLK            => clock100,
           CLK_ADCRAW     => clock200,
           RESTART_IN     => '0',
           ADCCLK_OUT     => open,
           ADC_DATA       => (others => '0'),
           ADC_DCO        => (others => '0'),
           DATA_OUT       => adc_data,
           FCO_OUT        => open,
           DATA_VALID_OUT => adc_valid,
           DEBUG          => open
           );

UUT: adc_processor
  generic map(
    DEVICE => 0
    )
  port map(
    CLK        => clock100,
    ADC_DATA   => adc_data,
    ADC_VALID  => adc_valid(0),
    STOP_IN    => stop_in,
    TRIGGER_OUT=> trigger_out,
    
    CONTROL    => control,
    CONFIG     => config,

    PSA_DATA           => psa_data,
    PSA_DATA_OUT       => open,
    PSA_ADDR           => psa_addr,
    PSA_WRITE          => psa_write,    
    
    DEBUG_BUFFER_READ => '0',
    DEBUG_BUFFER_ADDR => (others => '0'),
    DEBUG_BUFFER_DATA => open,
    DEBUG_BUFFER_READY=> open,
    
    READOUT_TX => readout_tx,
    READOUT_RX => readout_rx
    );

    
PROC_ADC : process begin
  wait until rising_edge(clock100); wait for 0.5 ns;

end process;
    

    
    
    
    
end architecture;
