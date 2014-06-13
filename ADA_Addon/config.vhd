library ieee;
USE IEEE.std_logic_1164.ALL;
use ieee.numeric_std.all;
use work.trb_net_std.all;

package config is


------------------------------------------------------------------------------
--Begin of design configuration
------------------------------------------------------------------------------

--Include GbE logic     
    constant NUM_TDC_CHANNELS        : integer range 1 to 65 := 33;
    constant NUM_TDC_CHANNELS_POWER2 : integer range 0 to 6  := 5;  --the nearest power of two, for convenience reasons
    constant USE_DOUBLE_EDGE         : integer               := c_YES;

--Include SPI on AddOn connector    
    constant INCLUDE_SPI            : integer := c_YES;

--Add logic to generate configurable trigger signal from input signals.
    constant INCLUDE_TRIGGER_LOGIC  : integer := c_YES;

--Do histos of all inputs
  constant INCLUDE_STATISTICS : integer := c_YES;

--number of real inputs to the FPGA    
  constant PHYSICAL_INPUTS : integer := 16;

--Define ringbuffer size for TDC channels: 32-64-128
  constant RING_BUFFER_SIZE : integer range 32 to 128 := 128;

--Run wih 125 MHz instead of 100 MHz
    constant USE_125_MHZ            : integer := c_NO;  --not implemented yet!
    
--Use sync mode, RX clock for all parts of the FPGA
    constant USE_RXCLOCK            : integer := c_NO;  --not implemented yet!
    
   
--Address settings
    constant INIT_ADDRESS           : std_logic_vector := x"F305";
    constant BROADCAST_SPECIAL_ADDR : std_logic_vector := x"48";
   
------------------------------------------------------------------------------
--End of design configuration
------------------------------------------------------------------------------


------------------------------------------------------------------------------
--Select settings by configuration 
------------------------------------------------------------------------------
    type intlist_t is array(0 to 7) of integer;
    type hw_info_t is array(0 to 7) of unsigned(31 downto 0);
    constant HW_INFO_BASE            : unsigned(31 downto 0) := x"91001000";
    constant HW_INFO_SPI             : hw_info_t := (x"00000000",x"00000400", others => x"00000000");
    constant HW_INFO_DOUBLE_EDGE     : hw_info_t := (x"00000000",x"00000800", others => x"00000000");
    constant HW_INFO_NUM_CHANS       : hw_info_t := (x"00000000",x"00000010",x"00000020",x"00000030",
                                                     x"00000040",x"00000050",x"00000060",x"00000070", others => x"00000000");
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
                                      HW_INFO_BASE + HW_INFO_SPI(INCLUDE_SPI) + HW_INFO_DOUBLE_EDGE(USE_DOUBLE_EDGE) +
                                      HW_INFO_NUM_CHANS(NUM_TDC_CHANNELS_POWER2));
  constant CLOCK_FREQUENCY      : integer := CLOCK_FREQUENCY_ARR(USE_125_MHZ);
  constant MEDIA_FREQUENCY      : integer := MEDIA_FREQUENCY_ARR(USE_125_MHZ);
  
end package body;
