library ieee;
USE IEEE.std_logic_1164.ALL;
use ieee.numeric_std.all;
use work.trb_net_std.all;

package config is


------------------------------------------------------------------------------
--Begin of design configuration
------------------------------------------------------------------------------

--Select the basic readout functionality of the firmware
    type READOUT_MODE_type is (READOUT_MODE_DUMMY, READOUT_MODE_PSA, READOUT_MODE_CFD);
    constant READOUT_MODE : READOUT_MODE_type := READOUT_MODE_CFD;
    
--Run wih 125 MHz instead of 100 MHz     
    constant USE_125_MHZ            : integer := c_NO;  --not implemented yet!  
    constant USE_EXTERNALCLOCK      : integer := c_NO;  --not implemented yet!  
    
--Use sync mode, RX clock for all parts of the FPGA
    constant USE_RXCLOCK            : integer := c_NO;  --not implemented yet!
    
   
--Address settings   
    constant INIT_ADDRESS           : std_logic_vector := x"F30a";
    constant BROADCAST_SPECIAL_ADDR : std_logic_vector := x"4b";
   
--ADC sampling frequency: 40, 64 or 80 MHz supported
--note that not all READOUT_MODEs will lead to timing-error free designs
--the READOUT_MODE_PSA mode is usually only working with 40MHz
--the READOUT_MODE_CFD mode is more robust against clock domain crossing issues 
    constant ADC_SAMPLING_RATE      : integer := 80;
    
--These are currently used for the included features table only
    constant ADC_BASELINE_LOGIC     : integer := c_YES;
    constant ADC_TRIGGER_LOGIC      : integer := c_YES;
    constant ADC_CHANNELS           : integer := 48;
    
------------------------------------------------------------------------------
--End of design configuration
------------------------------------------------------------------------------


------------------------------------------------------------------------------
--Select settings by configuration 
------------------------------------------------------------------------------
    type intlist_t is array(0 to 7) of integer;
    type hw_info_t is array(0 to 7) of unsigned(31 downto 0);
    constant HW_INFO_BASE            : unsigned(31 downto 0) := x"91009000";
    
    constant CLOCK_FREQUENCY_ARR  : intlist_t := (100,125, others => 0);
    constant MEDIA_FREQUENCY_ARR  : intlist_t := (200,125, others => 0);
                          
  --declare constants, filled in body                          
    constant HARDWARE_INFO        : std_logic_vector(31 downto 0);
    constant CLOCK_FREQUENCY      : integer;
    constant MEDIA_FREQUENCY      : integer;
    constant INCLUDED_FEATURES      : std_logic_vector(63 downto 0);
    
    
end;

package body config is
--compute correct configuration mode
  
  constant HARDWARE_INFO        : std_logic_vector(31 downto 0) := std_logic_vector(
                                      HW_INFO_BASE );
  constant CLOCK_FREQUENCY      : integer := CLOCK_FREQUENCY_ARR(USE_125_MHZ);
  constant MEDIA_FREQUENCY      : integer := MEDIA_FREQUENCY_ARR(USE_125_MHZ);

  
  
function generateIncludedFeatures return std_logic_vector is
  variable t : std_logic_vector(63 downto 0);
  variable proc_type : std_logic_vector(3 downto 0);
begin
  
  case READOUT_MODE is
    when READOUT_MODE_DUMMY =>
      proc_type := x"0";
    when READOUT_MODE_PSA =>
      proc_type := x"2";
    when READOUT_MODE_CFD =>
      proc_type := x"8";
  end case;

  t               := (others => '0');
  t(63 downto 56) := std_logic_vector(to_unsigned(4,8)); --table version 2
  t(7 downto 0)   := std_logic_vector(to_unsigned(ADC_SAMPLING_RATE,8));
  t(11 downto 8)  := proc_type; --processing type
  t(14 downto 14) := std_logic_vector(to_unsigned(ADC_BASELINE_LOGIC,1));
  t(15 downto 15) := std_logic_vector(to_unsigned(ADC_TRIGGER_LOGIC,1));
  t(23 downto 16) := std_logic_vector(to_unsigned(ADC_CHANNELS,8));
  t(42 downto 42) := "1"; --std_logic_vector(to_unsigned(INCLUDE_SPI,1));
  t(44 downto 44) := "0"; --std_logic_vector(to_unsigned(INCLUDE_STATISTICS,1));
  t(51 downto 48) := x"0";--std_logic_vector(to_unsigned(INCLUDE_TRIGGER_LOGIC,4));
  t(52 downto 52) := std_logic_vector(to_unsigned(USE_125_MHZ,1));
  t(53 downto 53) := std_logic_vector(to_unsigned(USE_RXCLOCK,1));
  t(54 downto 54) := std_logic_vector(to_unsigned(USE_EXTERNALCLOCK,1));
  return t;
end function;  

  constant INCLUDED_FEATURES : std_logic_vector(63 downto 0) := generateIncludedFeatures;    

end package body;
