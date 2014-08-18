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

type arr_CHAN_RES_t is array(0 to CHANNELS-1) of std_logic_vector(23 downto 0);
signal baseline_averages : arr_CHAN_RES_t;


-- 800 - 83f last ADC values              (local 0x0 - 0x3)
-- 840 - 87f long-term average / baseline (local 0x4 - 0x7)
-- 880 - 8bf fifo access (debugging only) (local 0x8 - 0xb)

begin

PROC_REGS : process 
  variable c : integer range 0 to 3;
begin
  wait until rising_edge(CLK);
  c := to_integer(unsigned(DEBUG_BUFFER_ADDR(1 downto 0)));
  DEBUG_BUFFER_READY <= '0';
  if DEBUG_BUFFER_READ = '1' then
    case DEBUG_BUFFER_ADDR(3 downto 2) is
      when "00" => DEBUG_BUFFER_DATA(RESOLUTION-1 downto 0) <= ADC_DATA(c*RESOLUTION+RESOLUTION-1 downto c*RESOLUTION); 
                   DEBUG_BUFFER_READY <= '1';
      when "01" => DEBUG_BUFFER_DATA(23 downto 0) <= baseline_averages(c); 
                   DEBUG_BUFFER_READY <= '1';
      when "10" => DEBUG_BUFFER_DATA  <= x"DEADBEAF";
                   DEBUG_BUFFER_READY <= '1';
      when "11" => DEBUG_BUFFER_DATA <= (others => '0'); DEBUG_BUFFER_READY <= '1';
    end case;
  end if;
  
  DEBUG_BUFFER_READY <= DEBUG_BUFFER_READ;
  DEBUG_BUFFER_DATA(3 downto 0)  <= DEBUG_BUFFER_ADDR;
end process;

end architecture;

