library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;



entity trb3_periph is
  port(
    --Clocks
    CLK_GPLL_LEFT                  : in  std_logic;  --Clock Manager 1/(2468), 125 MHz
    CLK_GPLL_RIGHT                 : in  std_logic;  --Clock Manager 2/(2468), 200 MHz  <-- MAIN CLOCK for FPGA
    CLK_PCLK_LEFT                  : in  std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!
    CLK_PCLK_RIGHT                 : in  std_logic;  --Clock Fan-out, 200/400 MHz <-- For TDC. Same oscillator as GPLL right!

    --Trigger
    TRIGGER_LEFT                   : in  std_logic;  --left side trigger input from fan-out
    TRIGGER_RIGHT                  : in  std_logic;  --right side trigger input from fan-out
    
    --Serdes
    CLK_SERDES_INT_LEFT            : in  std_logic;  --Clock Manager 1/(1357), off, 125 MHz possible
    CLK_SERDES_INT_RIGHT           : in  std_logic;  --Clock Manager 2/(1357), 200 MHz, only in case of problems
    SERDES_INT_TX                  : out std_logic_vector(3 downto 0);
    SERDES_INT_RX                  : in  std_logic_vector(3 downto 0);
    SERDES_ADDON_TX                : out std_logic_vector(11 downto 0);
    SERDES_ADDON_RX                : in  std_logic_vector(11 downto 0);
    
    --Inter-FPGA Communication
    FPGA5_COMM                     : inout std_logic_vector(11 downto 0);
                                                           --Bit 0/1 input, serial link RX active
                                                           --Bit 2/3 output, serial link TX active
                                                           --others yet undefined
    --Connection to AddOn
    SPARE_LINE                     : inout std_logic_vector(5 downto 0); --inputs only
    DQUL                           : inout std_logic_vector(45 downto 0);                              
    DQLL                           : inout std_logic_vector(47 downto 0);                              
    DQUR                           : inout std_logic_vector(33 downto 0);
    DQLR                           : inout std_logic_vector(35 downto 0);                              
                                    --All DQ groups from one bank are grouped.
                                    --All DQS are inserted in the DQ lines at position 6 and 7, DQ 6-9 are shifted to 8-11
                                    --Order per bank is kept, i.e. adjacent numbers have adjacent pins
                                    --all DQ blocks are 6+2+4=12 Pins wide, only DQUL3 is 6+2+2=10.
                                    --even numbers are positive LVDS line, odd numbers are negative LVDS line
                                    --DQUL can be switched to 1.8V
    --Flash ROM & Reboot
    FLASH_CLK                      : out std_logic;
    FLASH_CS                       : out std_logic;
    FLASH_CIN                      : out std_logic;
    FLASH_DOUT                     : in  std_logic;
    PROGRAMN                       : out std_logic; --reboot FPGA
    
    --Misc
    TEMPSENS                       : inout std_logic; --Temperature Sensor
    CODE_LINE                      : in  std_logic_vector(1 downto 0);
    LED_GREEN                      : out std_logic;
    LED_ORANGE                     : out std_logic; 
    LED_RED                        : out std_logic;
    LED_YELLOW                     : out std_logic;
    SUPPL                          : in  std_logic; --terminated diff pair, PCLK, Pads

    --Test Connectors
    TEST_LINE                      : out std_logic_vector(15 downto 0)
    );


    attribute syn_useioff : boolean;
    --no IO-FF for LEDs relaxes timing constraints
    attribute syn_useioff of LED_GREEN          : signal is false;
    attribute syn_useioff of LED_ORANGE         : signal is false;
    attribute syn_useioff of LED_RED            : signal is false;
    attribute syn_useioff of LED_YELLOW         : signal is false;
    attribute syn_useioff of TEMPSENS           : signal is false;
    attribute syn_useioff of PROGRAMN           : signal is false;
    attribute syn_useioff of CODE_LINE          : signal is false;
    attribute syn_useioff of TRIGGER_LEFT       : signal is false;
    attribute syn_useioff of TRIGGER_RIGHT      : signal is false;
    
    --important signals _with_ IO-FF
    attribute syn_useioff of FLASH_CLK          : signal is true;
    attribute syn_useioff of FLASH_CS           : signal is true;
    attribute syn_useioff of FLASH_CIN          : signal is true;
    attribute syn_useioff of FLASH_DOUT         : signal is true;
    attribute syn_useioff of FPGA5_COMM         : signal is true;
    attribute syn_useioff of TEST_LINE          : signal is true;
    attribute syn_useioff of DQLL               : signal is true;
    attribute syn_useioff of DQUL               : signal is true;
    attribute syn_useioff of DQLR               : signal is true;
    attribute syn_useioff of DQUR               : signal is true;
    attribute syn_useioff of SPARE_LINE         : signal is true;
    attribute syn_useioff of FPGA5_COMM         : signal is true;

end entity;

architecture trb3_periph_arch of trb3_periph is

  signal clk_100_i   : std_logic; --clock for main logic, 100 MHz, via Clock Manager and internal PLL
  signal clk_200_i   : std_logic; --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
                                  --TDC clock is separate
  signal pll_lock    : std_logic; --Internal PLL locked. E.g. used to reset all internal logic.

  
  --FPGA Test
  signal time_counter : unsigned(31 downto 0);
begin

---------------------------------------------------------------------------
-- Clock Handling
---------------------------------------------------------------------------
  THE_MAIN_PLL : pll_in200_out100
    port map(
      CLK    => CLK_GPLL_LEFT,
      CLKOP  => clk_100_i,
      CLKOK  => clk_200_i,
      LOCK   => pll_lock
      );


---------------------------------------------------------------------------
-- FPGA communication
---------------------------------------------------------------------------
  FPGA5_COMM <= (others => '0');


---------------------------------------------------------------------------
-- AddOn
---------------------------------------------------------------------------
  DQLL <= (others => '0');
  DQUL <= (others => '0');
  DQLR <= (others => '0');
  DQUR <= (others => '0');
  

---------------------------------------------------------------------------
-- Flash ROM
---------------------------------------------------------------------------
  FLASH_CLK <= '0';
  FLASH_CS  <= '0';
  FLASH_CIN <= '0';
  PROGRAMN  <= '1';

---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  LED_GREEN                      <= not time_counter(24);
  LED_ORANGE                     <= not time_counter(25); 
  LED_RED                        <= not time_counter(26);
  LED_YELLOW                     <= not time_counter(27);


---------------------------------------------------------------------------
-- Test Connector
---------------------------------------------------------------------------    
  TEST_LINE                     <= (others => '0');


---------------------------------------------------------------------------
-- Test Circuits
---------------------------------------------------------------------------
  process
    begin
      wait until rising_edge(clk_100_i);
      time_counter <= time_counter + 1;
    end process;

end architecture;