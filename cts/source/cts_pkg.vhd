library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

package cts_pkg is
   type CTS_GROUP_CONFIG_T is array(0 to 7) of integer;
   
   function MIN(x : integer; y : integer) return integer;
   function MAX(x : integer; y : integer) return integer;
   
   component CTS is
      generic (
         -- The total number of trigger units below has to be below 16
         TRIGGER_INPUT_COUNT : integer range 0 to  8 := 4;
         TRIGGER_COIN_COUNT  : integer range 0 to 15 := 2;
         TRIGGER_PULSER_COUNT: integer range 0 to 15 := 4;
         TRIGGER_RAND_PULSER : integer range 0 to 15 := 1;
         TRIGGER_ADDON_COUNT : integer range 0 to 15 := 2;  -- number of module instances used to patch through those lines
         PERIPH_TRIGGER_COUNT: integer range 0 to 15 := 2;
      
         ADDON_GROUPS        : integer range 1 to  8 := 5;
         ADDON_LINE_COUNT    : integer range 0 to 255 := 22;                 -- number of lines available from add-on board
         ADDON_GROUP_UPPER   : CTS_GROUP_CONFIG_T  := (3,7,11,12,13, others=>'0');

         
         OUTPUT_MULTIPLEXERS : integer range 0 to 255 := 0;

         EXTERNAL_TRIGGER_ID : std_logic_vector(7 downto 0) := X"00";
         
         TIME_REFERENCE_COUNT: positive := 10;          -- Number of clock cycles the time reference needs to stay asserted (100ns)
         FIFO_ADDR_WIDTH     : integer range 1 to 31 := 9   -- 2**(FIFO_ADDR_WIDTH-1) events can be stored in read-out buffer of CTS
      );

      port (
         CLK       : in  std_logic;
         RESET     : in  std_logic;      
         
   -- Trigger Logic
         TRIGGERS_IN        : in std_logic_vector(MAX(0,TRIGGER_INPUT_COUNT-1) downto 0);
         TRIGGER_BUSY_OUT   : out std_logic;
         TIME_REFERENCE_OUT : out std_logic;

         ADDON_TRIGGERS_IN  : in std_logic_vector(ADDON_LINE_COUNT-1 downto 0) := (others => '0');
         ADDON_GROUP_ACTIVITY_OUT : out std_logic_vector(ADDON_GROUPS-1 downto 0) := (others => '0');
         ADDON_GROUP_SELECTED_OUT : out std_logic_vector(ADDON_GROUPS-1 downto 0) := (others => '0');
         
         PERIPH_TRIGGER_IN : in std_logic_vector(19 downto 0) := (others => '0');
         
         OUTPUT_MULTIPLEXERS_OUT : out std_logic_vector(OUTPUT_MULTIPLEXERS-1 downto 0);
         
   -- External trigger logic
         EXT_TRIGGER_IN  : in std_logic;
         EXT_STATUS_IN   : in std_logic_vector(31 downto 0) := X"00000000";
         EXT_CONTROL_OUT : out std_logic_vector(31 downto 0);
         EXT_HEADER_BITS_IN : in std_logic_vector( 1 downto 0) := "00";         


   -- CTS Endpoint -----------------------------------------------------------
         --LVL1 trigger
         CTS_TRG_SEND_OUT             : out std_logic;
         CTS_TRG_TYPE_OUT             : out std_logic_vector( 3 downto 0);
         CTS_TRG_NUMBER_OUT           : out std_logic_vector(15 downto 0);
         CTS_TRG_INFORMATION_OUT      : out std_logic_vector(23 downto 0);
         CTS_TRG_RND_CODE_OUT         : out std_logic_vector( 7 downto 0);
         CTS_TRG_STATUS_BITS_IN       : in  std_logic_vector(31 downto 0);
         CTS_TRG_BUSY_IN              : in  std_logic;

         --IPU Channel
         CTS_IPU_SEND_OUT             : out std_logic;
         CTS_IPU_TYPE_OUT             : out std_logic_vector( 3 downto 0);
         CTS_IPU_NUMBER_OUT           : out std_logic_vector(15 downto 0);
         CTS_IPU_INFORMATION_OUT      : out std_logic_vector( 7 downto 0);
         CTS_IPU_RND_CODE_OUT         : out std_logic_vector( 7 downto 0);
         
         --Receiver port
         CTS_IPU_STATUS_BITS_IN       : in  std_logic_vector(31 downto 0);
         CTS_IPU_BUSY_IN              : in  std_logic;
         
         -- Slow Control
         CTS_REGIO_ADDR_IN            : in  std_logic_vector(15 downto 0);
         CTS_REGIO_DATA_IN            : in  std_logic_vector(31 downto 0);
         CTS_REGIO_READ_ENABLE_IN     : in  std_logic;
         CTS_REGIO_WRITE_ENABLE_IN    : in  std_logic;
         
         CTS_REGIO_DATA_OUT           : out std_logic_vector(31 downto 0);
         CTS_REGIO_DATAREADY_OUT      : out std_logic;
         CTS_REGIO_WRITE_ACK_OUT      : out std_logic;
         CTS_REGIO_UNKNOWN_ADDR_OUT   : out std_logic;
         
      
   -- Frontend Endpoint -----------------------------------------------------
         --Data Port
         LVL1_TRG_DATA_VALID_IN       : in std_logic;
         LVL1_VALID_TIMING_TRG_IN     : in std_logic;
         LVL1_VALID_NOTIMING_TRG_IN   : in std_logic;
         LVL1_INVALID_TRG_IN          : in std_logic;
      
         FEE_TRG_STATUSBITS_OUT       : out std_logic_vector(31 downto 0) := (others => '0');
         FEE_DATA_OUT                 : out std_logic_vector(31 downto 0) := (others => '0');
         FEE_DATA_WRITE_OUT           : out std_logic := '0';
         FEE_DATA_FINISHED_OUT        : out std_logic := '0'
      );
   end component;

   component CTS_FIFO is
      generic (
         ADDR_WIDTH : integer range 1 to 32;
         WIDTH : positive
      );
      
      port (
         CLK         : in std_logic;
         RESET       : in std_logic;
         
         DATA_IN     : in  std_logic_vector(WIDTH-1 downto 0);
         DATA_OUT    : out std_logic_vector(WIDTH-1 downto 0);
         
         WORDS_IN_FIFO_OUT : out std_logic_vector(ADDR_WIDTH downto 0);
         
         ENQUEUE_IN  : in std_logic;
         DEQUEUE_IN  : in std_logic;
         
         FULL_OUT    : out std_logic;
         EMPTY_OUT   : out std_logic
      );
   end component;

   component mbs_vulom_recv is
   port(
      CLK        : in std_logic;  -- e.g. 100 MHz
      RESET_IN   : in std_logic;  -- could be used after busy_release to make sure entity is in correct state

      --Module inputs
      MBS_IN     : in std_logic;  -- raw input
      CLK_200    : in std_logic;  -- internal sampling clock
      
      --trigger outputs
      TRG_ASYNC_OUT  : out std_logic;  -- asynchronous rising edge, length varying, here: approx. 110 ns
      TRG_SYNC_OUT   : out std_logic;  -- sync. to CLK

      --data output for read-out
      TRIGGER_IN   : in  std_logic;
      DATA_OUT     : out std_logic_vector(31 downto 0);
      WRITE_OUT    : out std_logic;
      STATUSBIT_OUT: out std_logic_vector(31 downto 0);
      FINISHED_OUT : out std_logic;
      
      --Registers / Debug    
      CONTROL_REG_IN : in  std_logic_vector(31 downto 0);
      STATUS_REG_OUT : out std_logic_vector(31 downto 0);
      HEADER_REG_OUT : out std_logic_vector(1 downto 0);
      DEBUG          : out std_logic_vector(31 downto 0)    
      );
   end component;   

   component mainz_a2_recv is
      port (
         CLK							 : in	 std_logic;
         RESET_IN					 : in	 std_logic;
         TIMER_TICK_1US_IN : in	 std_logic;
         SERIAL_IN				 : in	 std_logic;
         EXT_TRG_IN				 : in	 std_logic;
         TRG_SYNC_OUT			 : out std_logic;
         TRIGGER_IN				 : in	 std_logic;
         DATA_OUT					 : out std_logic_vector(31 downto 0);
         WRITE_OUT				 : out std_logic;
         STATUSBIT_OUT		 : out std_logic_vector(31 downto 0);
         FINISHED_OUT			 : out std_logic;
         CONTROL_REG_IN		 : in	 std_logic_vector(31 downto 0);
         STATUS_REG_OUT		 : out std_logic_vector(31 downto 0) := (others => '0');
         HEADER_REG_OUT    : out std_logic_vector(1 downto 0);
         DEBUG						 : out std_logic_vector(31 downto 0));
   end component mainz_a2_recv;

   component CTS_TRIGGER is
      generic (
         TRIGGER_INPUT_COUNT  : integer range 0 to  8 := 4;
         TRIGGER_COIN_COUNT   : integer range 0 to 15 := 4;
         TRIGGER_PULSER_COUNT : integer range 0 to 15 := 2;
         TRIGGER_RAND_PULSER  : integer range 0 to 15 := 1;
        
         ADDON_LINE_COUNT     : integer range 0 to 255 := 22;  -- number of lines available from add-on board
         TRIGGER_ADDON_COUNT  : integer range 0 to 15 := 2;  -- number of module instances used to patch through those lines
         ADDON_GROUPS         : integer range 1 to 8 := 5;
         ADDON_GROUP_UPPER    : CTS_GROUP_CONFIG_T  := (3,7,11,12,13, others=>'0');
      
         PERIPH_TRIGGER_COUNT: integer range 0 to 15 := 2;
         
         OUTPUT_MULTIPLEXERS : integer range 0 to 255 := 0;
         
         EXTERNAL_TRIGGER_ID  : std_logic_vector(7 downto 0) := X"00"
      );

      port (
         CLK_IN       : in  std_logic;
         CLK_1KHZ_IN  : in  std_logic;
         RESET_IN     : in  std_logic;      
         
      -- Input pins
         TRIGGERS_IN : in std_logic_vector(MAX(0,TRIGGER_INPUT_COUNT-1) downto 0);
         ADDON_TRIGGERS_IN  : in std_logic_vector(ADDON_LINE_COUNT-1 downto 0) := (others => '0');
         ADDON_GROUP_ACTIVITY_OUT : out std_logic_vector(ADDON_GROUPS-1 downto 0) := (others => '0');
         ADDON_GROUP_SELECTED_OUT : out std_logic_vector(ADDON_GROUPS-1 downto 0) := (others => '0');

         PERIPH_TRIGGER_IN : in std_logic_vector(19 downto 0) := (others => '0');
         
         OUTPUT_MULTIPLEXERS_OUT : out std_logic_vector(OUTPUT_MULTIPLEXERS-1 downto 0);
         
      -- External 
         EXT_TRIGGER_IN  : in std_logic;
         EXT_STATUS_IN   : in std_logic_vector(31 downto 0) := X"00000000";
         EXT_CONTROL_OUT : out std_logic_vector(31 downto 0);

      -- Output
         TRIGGER_OUT         : out std_logic; -- asserted when trigger detected
         TRIGGER_TYPE_OUT    : out std_logic_vector(3 downto 0);
         TRIGGER_BITMASK_OUT : out std_logic_vector(15 downto 0);
         
      -- Counters
         INPUT_COUNTERS_OUT         : out std_logic_vector(32 * (TRIGGER_INPUT_COUNT + TRIGGER_ADDON_COUNT) - 1 downto 0) := (others => '0');
         INPUT_EDGE_COUNTERS_OUT    : out std_logic_vector(32 * (TRIGGER_INPUT_COUNT + TRIGGER_ADDON_COUNT) - 1 downto 0) := (others => '0');
         
         CHANNEL_COUNTERS_OUT       : out std_logic_vector(32 * 16 - 1 downto 0) := (others => '0');
         CHANNEL_EDGE_COUNTERS_OUT  : out std_logic_vector(32 * 16 - 1 downto 0) := (others => '0');
         NUM_OF_ITC_USED_OUT        : out std_logic_vector(4 downto 0);
         
      -- Slow Control
         REGIO_ADDR_IN            : in  std_logic_vector(15 downto 0);
         REGIO_DATA_IN            : in  std_logic_vector(31 downto 0);
         REGIO_READ_ENABLE_IN     : in  std_logic;
         REGIO_WRITE_ENABLE_IN    : in  std_logic;
         REGIO_TIMEOUT_IN         : in  std_logic;
         
         REGIO_DATA_OUT           : out std_logic_vector(31 downto 0);
         REGIO_DATAREADY_OUT      : out std_logic;
         REGIO_WRITE_ACK_OUT      : out std_logic;
         REGIO_NO_MORE_DATA_OUT   : out std_logic := '0';
         REGIO_UNKNOWN_ADDR_OUT   : out std_logic
      );
   end component;
   
   component CTS_TRG_INPUT is
   port (
      CLK_IN      : in  std_logic;
      RST_IN      : in  std_logic;
      DATA_IN     : in  std_logic;
      DATA_OUT    : out std_logic;
      CONFIG_IN   : in  std_logic_vector(10 downto 0) := (others => '0')
   );
   end component;
   
   component CTS_TRG_COIN is
      generic (
         INPUT_COUNT       : integer range 1 to 8 := 4
      );
   
      port (
         CLK_IN          : in  std_logic;
         RST_IN          : in  std_logic;
         
         DATA_IN         : in  std_logic_vector(INPUT_COUNT - 1 downto 0);
         TRIGGER_OUT     : out std_logic;
         
         CONFIG_IN       : in  std_logic_vector(31 downto 0) := (others => '0')
      );
   end component;   

   component CTS_TRG_PSEUDORAND_PULSER is
      generic (
         DATA_XOR     : std_logic_vector(31 downto 0) := (others => '0')
      );
      port (
         clk_in       : in  std_logic;
         threshold_in : in  std_logic_vector(31 downto 0); 
         trigger_out  : out std_logic
      );
   end component;

-- Block identification header
--       Bit   Description
--    <reg_table name="cts_trg_header" >
--             Block identification header      
--       7:0   Block type
--      15:8   Number of addresses in this block exclusively this header word
--      20:16  First internal trigger channel assigned to this block (0 if it does not apply)
--      25:21  Number of internal trigger channel assigned to this block  (0 if it does not apply)
--       31    Last block indicator. Enumeration stops after reading this block
--    </reg_table>
   function CTS_BLOCK_HEADER(
      constant ID  : integer range 0 to 255;
      constant LEN : integer range 0 to 255;
      constant ITC_BASE : integer range 0 to 15 := 0;
      constant ITC_NUM : integer  range 0 to 15 := 0;
      constant LAST : boolean := false
   ) return std_logic_vector;
end package cts_pkg;

package body cts_pkg is
   function CTS_BLOCK_HEADER(
      constant ID  : integer range 0 to 255;
      constant LEN : integer range 0 to 255;
      constant ITC_BASE : integer range 0 to 15 := 0;
      constant ITC_NUM : integer  range 0 to 15 := 0;
      constant LAST : boolean := false
   ) return std_logic_vector 
   is
      variable result : std_logic_vector(31 downto 0) := (others => '0');
   begin
      result( 7 downto  0) := std_logic_vector(to_unsigned(ID, 8));
      result(15 downto  8) := std_logic_vector(to_unsigned(LEN, 8));
      result(20 downto 16) := std_logic_vector(to_unsigned(ITC_BASE, 5));
      result(25 downto 21) := std_logic_vector(to_unsigned(ITC_NUM,  5));
      
      if LAST then
         result(31) := '1';
      end if;
      
      return result;
   end CTS_BLOCK_HEADER;
   
   function MIN(x : integer; y : integer)
    return integer is
   begin
     if x < y then
       return x;
     else
       return y;
     end if;
   end MIN;
   
   function MAX(x : integer; y : integer)
    return integer is
   begin
     if x > y then
       return x;
     else
       return y;
     end if;
   end MAX;
end package body cts_pkg;
