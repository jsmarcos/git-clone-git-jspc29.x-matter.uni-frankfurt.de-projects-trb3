library ieee;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use work.trb_net_std.all;

package config is


------------------------------------------------------------------------------
--Begin of design configuration
------------------------------------------------------------------------------

--TDC settings
  constant NUM_TDC_CHANNELS        : integer range 1 to 65   := 33;
  constant NUM_TDC_CHANNELS_POWER2 : integer range 0 to 6    := 5;  --the nearest power of two, for convenience reasons 
  constant USE_DOUBLE_EDGE         : integer                 := c_YES;
  constant RING_BUFFER_SIZE        : integer range 32 to 128 := 64; --ring buffer size: 32,64,128

--use only every fourth input as in HPTDC high precision mode    
  constant USE_HPTDC_FASTMODE_PINOUT : integer    := c_YES;

--Include SPI on AddOn connector    
  constant INCLUDE_SPI               : integer    := c_YES;

--Add logic to generate configurable trigger signal from input signals.
  constant INCLUDE_TRIGGER_LOGIC     : integer    := c_YES;
  constant INCLUDE_STATISTICS        : integer    := c_YES; --Do histos of all inputs
  constant PHYSICAL_INPUTS           : integer    := 16;    --number of inputs connected

--Run wih 125 MHz instead of 100 MHz, use received clock from serdes or external clock input
  constant USE_125_MHZ               : integer    := c_NO;  --not implemented yet!  
  constant USE_RXCLOCK               : integer    := c_NO;  --not implemented yet!
  constant USE_EXTERNALCLOCK         : integer    := c_NO;  --not implemented yet!

--Address settings   
  constant INIT_ADDRESS           : std_logic_vector := x"F305";
  constant BROADCAST_SPECIAL_ADDR : std_logic_vector := x"4e";

------------------------------------------------------------------------------
--End of design configuration
------------------------------------------------------------------------------



------------------------------------------------------------------------------
--Select settings by configuration 
------------------------------------------------------------------------------
  type intlist_t is array(0 to 7) of integer;
  type hw_info_t is array(0 to 7) of unsigned(31 downto 0);
  constant HW_INFO_BASE        : unsigned(31 downto 0) := x"91001000";
  constant CLOCK_FREQUENCY_ARR : intlist_t := (100, 125, others => 0);
  constant MEDIA_FREQUENCY_ARR : intlist_t := (200, 125, others => 0);

  --declare constants, filled in body                          
  constant HARDWARE_INFO   : std_logic_vector(31 downto 0);
  constant CLOCK_FREQUENCY : integer;
  constant MEDIA_FREQUENCY : integer;
  constant INCLUDED_FEATURES      : std_logic_vector(63 downto 0);
  
function generateIncludedFeatures return std_logic_vector;

  
  
end;

package body config is
--compute correct configuration mode
  
function generateIncludedFeatures return std_logic_vector is
  variable t : std_logic_vector(63 downto 0);
begin
  t               := (others => '0');
  t(63 downto 56) := std_logic_vector(to_unsigned(2,8)); --table version 2
  t(7 downto 0)   := std_logic_vector(to_unsigned(USE_HPTDC_FASTMODE_PINOUT*3,8));
  t(11 downto 8)  := std_logic_vector(to_unsigned(USE_DOUBLE_EDGE*2,4));
  t(15)           := '1'; --TDC
  t(42 downto 42) := std_logic_vector(to_unsigned(INCLUDE_SPI,1));
  t(44 downto 44) := std_logic_vector(to_unsigned(INCLUDE_STATISTICS,1));
  t(51 downto 48) := std_logic_vector(to_unsigned(INCLUDE_TRIGGER_LOGIC,4));
  t(52 downto 52) := std_logic_vector(to_unsigned(USE_125_MHZ,1));
  t(53 downto 53) := std_logic_vector(to_unsigned(USE_RXCLOCK,1));
  t(54 downto 54) := std_logic_vector(to_unsigned(USE_EXTERNALCLOCK,1));
  return t;
end function;  
  
  constant HARDWARE_INFO : std_logic_vector(31 downto 0) := std_logic_vector( HW_INFO_BASE );
  constant CLOCK_FREQUENCY : integer := CLOCK_FREQUENCY_ARR(USE_125_MHZ);
  constant MEDIA_FREQUENCY : integer := MEDIA_FREQUENCY_ARR(USE_125_MHZ);
  
  constant INCLUDED_FEATURES : std_logic_vector := generateIncludedFeatures;  
end package body;
