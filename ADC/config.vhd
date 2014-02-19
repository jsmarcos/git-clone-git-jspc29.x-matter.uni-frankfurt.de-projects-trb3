library ieee;
USE IEEE.std_logic_1164.ALL;
use ieee.numeric_std.all;
use work.trb_net_std.all;

package config is


------------------------------------------------------------------------------
--Begin of design configuration
------------------------------------------------------------------------------


    
--Run wih 125 MHz instead of 100 MHz     
    constant USE_125_MHZ            : integer := c_NO;  --not implemented yet!  
    
--Use sync mode, RX clock for all parts of the FPGA
    constant USE_RXCLOCK            : integer := c_NO;  --not implemented yet!
    
   
--Address settings   
    constant INIT_ADDRESS           : std_logic_vector := x"F30a";
    constant BROADCAST_SPECIAL_ADDR : std_logic_vector := x"4b";
   
------------------------------------------------------------------------------
--End of design configuration
------------------------------------------------------------------------------


------------------------------------------------------------------------------
--Select settings by configuration 
------------------------------------------------------------------------------
    type intlist_t is array(0 to 7) of integer;
    type hw_info_t is array(0 to 7) of unsigned(31 downto 0);
    constant HW_INFO_BASE            : unsigned(31 downto 0) := x"91009480";
    
    constant CLOCK_FREQUENCY_ARR  : intlist_t := (100,125, others => 0);
    constant MEDIA_FREQUENCY_ARR  : intlist_t := (200,125, others => 0);
                          
  --declare constants, filled in body                          
    constant HARDWARE_INFO        : std_logic_vector(31 downto 0);
    constant CLOCK_FREQUENCY      : integer;
    constant MEDIA_FREQUENCY      : integer;

end;

package body config is
--compute correct configuration mode
  
  constant HARDWARE_INFO        : std_logic_vector(31 downto 0) := std_logic_vector(
                                      HW_INFO_BASE );
  constant CLOCK_FREQUENCY      : integer := CLOCK_FREQUENCY_ARR(USE_125_MHZ);
  constant MEDIA_FREQUENCY      : integer := MEDIA_FREQUENCY_ARR(USE_125_MHZ);
  
end package body;