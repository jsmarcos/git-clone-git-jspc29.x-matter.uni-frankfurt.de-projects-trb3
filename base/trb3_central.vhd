library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;



entity trb3_central is
  port(
    --Clocks
    CLK_EXT                        : in  std_logic_vector(4 downto 3); --from RJ45
    CLK_GPLL_LEFT                  : in  std_logic;  --Clock Manager 2/9, 200 MHz  <-- MAIN CLOCK
    CLK_GPLL_RIGHT                 : in  std_logic;  --Clock Manager 1/9, 125 MHz  <-- for GbE
    CLK_PCLK_LEFT                  : in  std_logic;  --Clock Fan-out, 200 MHz      <-- for Serdes if GPLL doesn't work. Same oscillator as GPLL left!
    CLK_PCLK_RIGHT                 : in  std_logic;  --Clock Fan-out, 200 MHz      <-- use this clock for BASIC tests!

    --Trigger
    TRIGGER_LEFT                   : in  std_logic;  --left side trigger input from fan-out
    TRIGGER_RIGHT                  : in  std_logic;  --right side trigger input from fan-out
    TRIGGER_EXT                    : in  std_logic_vector(4 downto 2); --additional trigger from RJ45
    TRIGGER_OUT                    : out std_logic;  --trigger to second input of fan-out
    
    --Serdes
    CLK_SERDES_INT_LEFT            : in  std_logic;  --Clock Manager 2/0, 200 MHz, only in case of problems
    CLK_SERDES_INT_RIGHT           : in  std_logic;  --Clock Manager 1/0, off, 125 MHz possible
    
    --SFP
    SFP_TX_FAULT                   : in  std_logic_vector(7 downto 0); --TX broken
    SFP_RATE_SEL                   : out std_logic_vector(7 downto 0); --not supported by our SFP
    SFP_LOS                        : in  std_logic_vector(7 downto 0); --Loss of signal
    SFP_MOD0                       : in  std_logic_vector(7 downto 0); --SFP present
    SFP_MOD1                       : in  std_logic_vector(7 downto 0); --I2C interface
    SFP_MOD2                       : in  std_logic_vector(7 downto 0); --I2C interface
    SFP_TXDIS                      : out std_logic_vector(7 downto 0); --disable TX
    
    --Clock and Trigger Control
    TRIGGER_SELECT                 : out std_logic;  --trigger select for fan-out. 0: external, 1: signal from FPGA5
    CLOCK_SELECT                   : out std_logic;  --clock select for fan-out. 0: 200MHz, 1: external from RJ45
    CLK_MNGR1_USER                 : inout std_logic_vector(3 downto 0); --I/O lines to clock manager 1
    CLK_MNGR2_USER                 : inout std_logic_vector(3 downto 0); --I/O lines to clock manager 1
    
    --Inter-FPGA Communication
    FPGA1_COMM                     : inout std_logic_vector(11 downto 0);
    FPGA2_COMM                     : inout std_logic_vector(11 downto 0);
    FPGA3_COMM                     : inout std_logic_vector(11 downto 0);
    FPGA4_COMM                     : inout std_logic_vector(11 downto 0); 
                                    -- on all FPGAn_COMM:  --Bit 0/1 output, serial link TX active
                                                           --Bit 2/3 input, serial link RX active
                                                           --others yet undefined
    FPGA1_TTL                      : inout std_logic_vector(3 downto 0);
    FPGA2_TTL                      : inout std_logic_vector(3 downto 0);
    FPGA3_TTL                      : inout std_logic_vector(3 downto 0);
    FPGA4_TTL                      : inout std_logic_vector(3 downto 0);
                                    --only for not timing-sensitive signals

    --Communication to small addons
    FPGA1_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 2-3: LED for SFP3/4
    FPGA2_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 2-3: LED for SFP7/8
    FPGA3_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 0-1: LED for SFP5/6 
    FPGA4_CONNECTOR                : inout std_logic_vector(7 downto 0); --Bit 0-1: LED for SFP1/2
                                                                         --Bit 0-3 connected to LED by default, two on each side
                                                                         
    --Big AddOn connector
    ADDON_RESET                    : out std_logic; --reset signal to AddOn
    ADDON_TO_TRB_CLK               : in  std_logic; --Clock from AddOn, connected to PCLK input
    TRB_TO_ADDON_CLK               : out std_logic; --Clock sent to AddOn
    ADO_LV                         : inout std_logic_vector(61 downto 0);
    ADO_TTL                        : inout std_logic_vector(46 downto 0);
    FS_PE                          : inout std_logic_vector(17 downto 0);
    
    --Flash ROM & Reboot
    FLASH_CLK                      : out std_logic;
    FLASH_CS                       : out std_logic;
    FLASH_CIN                      : out std_logic;
    FLASH_DOUT                     : in  std_logic;
    PROGRAMN                       : out std_logic; --reboot FPGA
    
    --Misc
    ENPIRION_CLOCK                 : out std_logic;  --Clock for power supply, not necessary, floating
    TEMPSENS                       : inout std_logic; --Temperature Sensor
    LED_CLOCK_GREEN                : out std_logic;
    LED_CLOCK_RED                  : out std_logic;
    LED_GREEN                      : out std_logic;
    LED_ORANGE                     : out std_logic; 
    LED_RED                        : out std_logic;
    LED_TRIGGER_GREEN              : out std_logic;
    LED_TRIGGER_RED                : out std_logic; 
    LED_YELLOW                     : out std_logic;

    --Test Connectors
    TEST_LINE                      : out std_logic_vector(31 downto 0)
    );
    
    attribute syn_useioff : boolean;
    --no IO-FF for LEDs relaxes timing constraints
    attribute syn_useioff of LED_CLOCK_GREEN    : signal is false;
    attribute syn_useioff of LED_CLOCK_RED      : signal is false;
    attribute syn_useioff of LED_GREEN          : signal is false;
    attribute syn_useioff of LED_ORANGE         : signal is false;
    attribute syn_useioff of LED_RED            : signal is false;
    attribute syn_useioff of LED_TRIGGER_GREEN  : signal is false;
    attribute syn_useioff of LED_TRIGGER_RED    : signal is false;
    attribute syn_useioff of LED_YELLOW         : signal is false;
    attribute syn_useioff of FPGA1_TTL          : signal is false;
    attribute syn_useioff of FPGA2_TTL          : signal is false;
    attribute syn_useioff of FPGA3_TTL          : signal is false;
    attribute syn_useioff of FPGA4_TTL          : signal is false;
    attribute syn_useioff of SFP_TXDIS          : signal is false;
    
    --important signals _with_ IO-FF
    attribute syn_useioff of FLASH_CLK          : signal is true;
    attribute syn_useioff of FLASH_CS           : signal is true;
    attribute syn_useioff of FLASH_CIN          : signal is true;
    attribute syn_useioff of FLASH_DOUT         : signal is true;
    attribute syn_useioff of FPGA1_COMM         : signal is true;
    attribute syn_useioff of FPGA2_COMM         : signal is true;
    attribute syn_useioff of FPGA3_COMM         : signal is true;
    attribute syn_useioff of FPGA4_COMM         : signal is true;


end entity;

architecture trb3_central_arch of trb3_central is

  signal clk_100_i   : std_logic; --clock for main logic, 100 MHz, via Clock Manager and internal PLL
  signal clk_200_i   : std_logic; --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
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
-- Clock and Trigger Configuration
---------------------------------------------------------------------------
  TRIGGER_SELECT <= '0'; --always external trigger source
  CLOCK_SELECT   <= '0'; --use on-board oscillator
  CLK_MNGR1_USER <= (others => '0');
  CLK_MNGR2_USER <= (others => '0'); 

  TRIGGER_OUT    <= '0';

  SFP_TXDIS <= (others => '0');
---------------------------------------------------------------------------
-- FPGA communication
---------------------------------------------------------------------------
  FPGA1_COMM <= (others => '0');
  FPGA2_COMM <= (others => '0');
  FPGA3_COMM <= (others => '0');
  FPGA4_COMM <= (others => '0');

  FPGA1_TTL <= (others => '0');
  FPGA2_TTL <= (others => '0');
  FPGA3_TTL <= (others => '0');
  FPGA4_TTL <= (others => '0');

  FPGA1_CONNECTOR <= (others => '0');
  FPGA2_CONNECTOR <= (others => '0');
  FPGA3_CONNECTOR <= (others => '0');
  FPGA4_CONNECTOR <= (others => '0');


---------------------------------------------------------------------------
-- Flash ROM
---------------------------------------------------------------------------
  FLASH_CLK <= '0';
  FLASH_CS  <= '0';
  FLASH_CIN <= '0';


---------------------------------------------------------------------------
-- Big AddOn Connector
---------------------------------------------------------------------------
  ADDON_RESET      <= '1';
  TRB_TO_ADDON_CLK <= '0';
  ADO_LV           <= (others => 'Z');
  ADO_TTL          <= (others => 'Z');
  FS_PE            <= (others => 'Z');


---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  LED_CLOCK_GREEN                <= '0';
  LED_CLOCK_RED                  <= '1';
  LED_GREEN                      <= not time_counter(24);
  LED_ORANGE                     <= not time_counter(25); 
  LED_RED                        <= not time_counter(26);
  LED_TRIGGER_GREEN              <= '0';
  LED_TRIGGER_RED                <= '1';
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