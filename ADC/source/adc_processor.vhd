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
    
    CONFIG     : in  cfg_t;
   
    DEBUG_BUFFER_READ : in  std_logic;
    DEBUG_BUFFER_ADDR : in  std_logic_vector(3 downto 0);
    DEBUG_BUFFER_DATA : out std_logic_vector(31 downto 0);
    DEBUG_BUFFER_READY: out std_logic;
    
    READOUT_RX : in  READOUT_RX;
    READOUT_TX : out READOUT_TX
    
    );
end entity;


architecture adc_processor_arch of adc_processor is

type ram_t is array(0 to 1023) of std_logic_vector(17 downto 0);
type ram_arr_t is array(0 to 3) of ram_t;

signal ram : ram_arr_t;



begin

PROC_REGS : process begin
  wait until rising_edge(CLK);
--   if then
--   end if;
end process;

end architecture;

