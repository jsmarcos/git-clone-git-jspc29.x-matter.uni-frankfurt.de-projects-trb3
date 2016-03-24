library ieee;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use work.trb_net_std.all;

package config is

------------------------------------------------------------------------------
--Begin of design configuration
------------------------------------------------------------------------------

--TDC settings
  constant NUM_TDC_MODULES         : integer range 1 to 4  := 1;  -- number of tdc modules to implement
  constant NUM_TDC_CHANNELS        : integer range 1 to 65 := 5; -- number of tdc channels per module
  constant NUM_TDC_CHANNELS_POWER2 : integer range 0 to 6  := 6;  --the nearest power of two, for convenience reasons
  constant DOUBLE_EDGE_TYPE        : integer range 0 to 3  := 3;  --double edge type:  0, 1, 2,  3
  -- 0: single edge only,
  -- 1: same channel,
  -- 2: alternating channels,
  -- 3: same channel with stretcher
  constant RING_BUFFER_SIZE        : integer range 0 to 7  := 0;  --ring buffer size
  -- mode:  0,  1,  2,   3,   7
  -- size: 32, 64, 96, 128, dyn
  constant TDC_DATA_FORMAT         : integer range 0 to 15 := 0;  --type of data format for the TDC
  --  0: Single fine time as the sum of the two transitions
  --  1: Double fine time, individual transitions
  -- 13: Debug - single fine time and the chain for the 0x3ff hits
  -- 14: Debug - single fine time and the ROM addresses for the two transitions
  -- 15: Debug - complete carry chain dump
  
  constant EVENT_BUFFER_SIZE : integer range 9 to 13 := 11;  -- size of the event buffer, 2**N
  constant EVENT_MAX_SIZE    : integer               := 1024;  --maximum event size. Should not exceed EVENT_BUFFER_SIZE/2

  constant INCLUDE_UART           : integer  := c_NO;
  constant INCLUDE_SPI            : integer  := c_YES;
  constant INCLUDE_LCD            : integer  := c_NO;
  constant INCLUDE_DEBUG_INTERFACE: integer  := c_NO;

  --input monitor and trigger generation logic
  constant INCLUDE_TRIGGER_LOGIC  : integer  := c_YES;
  constant INCLUDE_STATISTICS     : integer  := c_YES;
  constant TRIG_GEN_INPUT_NUM     : integer  := 32;
  constant TRIG_GEN_OUTPUT_NUM    : integer  := 4;
  constant MONITOR_INPUT_NUM      : integer  := 36;    
  constant USE_SINGLE_FIFO        : integer := c_YES;  -- single fifo for statistics

    --Run wih 125 MHz instead of 100 MHz, use received clock from serdes or external clock input
  constant USE_125_MHZ               : integer    := c_NO;  --not implemented yet!
  constant USE_RXCLOCK               : integer    := c_NO;  --not implemented yet!
  constant USE_EXTERNALCLOCK         : integer    := c_NO;  --not implemented yet!

--Address settings
  constant INIT_ADDRESS           : std_logic_vector := x"F305";
  constant BROADCAST_SPECIAL_ADDR : std_logic_vector := x"48";

------------------------------------------------------------------------------
--End of design configuration
------------------------------------------------------------------------------


  type data_t is array (0 to 1023) of std_logic_vector(7 downto 0);
  constant LCD_DATA : data_t := (
      x"36",x"48",x"3A",x"55",x"29",x"2A",x"00",x"00", --config don't touch
      x"00",x"EF",x"2B",x"00",x"00",x"01",x"3F",x"2C", --config don't touch
      x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00", --config don't touch
      x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00", --config don't touch
      
      x"54", x"72", x"62", x"33", x"73", x"63", x"0a",
      x"0a",
      x"41", x"64", x"64", x"72", x"65", x"73", x"73", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"80",                     x"0a",                            
      x"43", x"6f", x"6d", x"70", x"69", x"6c", x"65", x"54", x"69", x"6d", x"65", x"20", x"20", x"84",                      x"83",                     x"0a", 
      x"54", x"69", x"6d", x"65", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"82",                      x"81",                     x"0a",
      others => x"00");


------------------------------------------------------------------------------
--Select settings by configuration 
------------------------------------------------------------------------------
  type intlist_t is array(0 to 7) of integer;
  type hw_info_t is array(0 to 7) of unsigned(31 downto 0);
  constant HW_INFO_BASE        : unsigned(31 downto 0) := x"91007000";
  constant CLOCK_FREQUENCY_ARR : intlist_t := (100, 125, others => 0);
  constant MEDIA_FREQUENCY_ARR : intlist_t := (200, 125, others => 0);

  --declare constants, filled in body                          
  constant HARDWARE_INFO     : std_logic_vector(31 downto 0);
  constant CLOCK_FREQUENCY   : integer;
  constant MEDIA_FREQUENCY   : integer;
  constant INCLUDED_FEATURES : std_logic_vector(63 downto 0);
  
function generateIncludedFeatures return std_logic_vector;

  
  
end;

package body config is
--compute correct configuration mode
  
function generateIncludedFeatures return std_logic_vector is
  variable t : std_logic_vector(63 downto 0);
begin
  t               := (others => '0');
  t(63 downto 56) := std_logic_vector(to_unsigned(2,8)); --table version 2
  t(7 downto 0)   := std_logic_vector(to_unsigned(1,8));
  t(11 downto 8)  := std_logic_vector(to_unsigned(DOUBLE_EDGE_TYPE,4));
  t(14 downto 12) := std_logic_vector(to_unsigned(RING_BUFFER_SIZE,3));
  t(15)           := '1'; --TDC
  t(17 downto 16) := std_logic_vector(to_unsigned(NUM_TDC_MODULES-1,2));
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
