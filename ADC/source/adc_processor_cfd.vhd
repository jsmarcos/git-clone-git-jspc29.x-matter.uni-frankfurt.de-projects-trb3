library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;

entity adc_processor_cfd is
  generic(
    DEVICE : integer range 0 to 15 := 15
  );
  port(
    CLK                : in  std_logic;

    ADC_DATA           : in  std_logic_vector(RESOLUTION * CHANNELS - 1 downto 0);
    STOP_IN            : in  std_logic;
    TRIGGER_OUT        : out std_logic;

    CONTROL            : in  std_logic_vector(63 downto 0);
    CONFIG             : in  cfg_cfd_t;

    DEBUG_BUFFER_READ  : in  std_logic;
    DEBUG_BUFFER_ADDR  : in  std_logic_vector(4 downto 0);
    DEBUG_BUFFER_DATA  : out std_logic_vector(31 downto 0);
    DEBUG_BUFFER_READY : out std_logic;

    READOUT_RX         : in  READOUT_RX;
    READOUT_TX         : out READOUT_TX
  );
end entity adc_processor_cfd;

architecture arch of adc_processor_cfd is
  signal CONF : cfg_cfd_t;
  
  signal trigger : std_logic_vector(CHANNELS-1 downto 0);
  type invalid_word_count_t is array (0 to CHANNELS - 1) of unsigned(31 downto 0);
  signal invalid_word_count : invalid_word_count_t := (others => (others => '0'));
begin
  
  CONF <= CONFIG when rising_edge(CLK);
  
  TRIGGER_OUT <= or_all(trigger);
    
  gen_cfd : for i in 0 to CHANNELS-1 generate
    THE_CFD : entity work.adc_processor_cfd_ch
      port map(CLK      => CLK,
               ADC_DATA => ADC_DATA(RESOLUTION*(i+1)-1 downto RESOLUTION*i),
               CONF     => CONF,
               RAM_RD   => '0',
               RAM_ADDR => (others => '0'),
               RAM_DATA => open,
               TRIGGER_OUT => trigger(i)
               );   
    
  end generate;  
    

  
end architecture arch;
