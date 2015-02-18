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
  
begin
  
end architecture arch;
