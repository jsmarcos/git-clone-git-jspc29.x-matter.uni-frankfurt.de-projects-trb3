library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;


library machxo2;
use machxo2.all;


entity panda_dirc_wasa is
  generic(
    PADIWA_FLAVOUR : integer := 3;
    TEMP_CORRECTION: integer := c_YES;
    TDCTEST        : integer := c_NO
    );
  port(
    CON        : out std_logic_vector(16 downto 1);
    INP        : in  std_logic_vector(16 downto 1);
    PWM        : out std_logic_vector(16 downto 1);
    SPARE_LINE : out std_logic_vector(3 downto 0);
    SPARE_LVDS : out std_logic;
    LED_GREEN  : out std_logic;
    LED_ORANGE : out std_logic;
    LED_RED    : out std_logic;
    LED_YELLOW : out std_logic;
    SPI_CLK    : in  std_logic;
    SPI_CS     : in  std_logic;
    SPI_IN     : in  std_logic;
    SPI_OUT    : out std_logic;
    TEMP_LINE  : inout std_logic;
    TEST_LINE  : inout std_logic_vector(15 downto 0)
    );
end entity;

architecture panda_dirc_wasa_arch of panda_dirc_wasa is

component OSCH
-- synthesis translate_off
  generic (NOM_FREQ: string := "133.00");
-- synthesis translate_on
  port (
    STDBY :IN std_logic;
    OSC   :OUT std_logic;
    SEDSTDBY :OUT std_logic
    );
end component;

component pll
    port (
        CLKI: in  std_logic; 
        CLKOP: out  std_logic; 
        CLKOS: out  std_logic; 
        LOCK: out  std_logic);
end component;


attribute NOM_FREQ : string;
attribute NOM_FREQ of clk_source : label is "133.00";
signal clk_i  : std_logic;

signal onewire_reset   : std_logic := '1';
signal id_data_i : std_logic_vector(15 downto 0);
signal id_addr_i : std_logic_vector(2 downto 0);
signal id_write_i: std_logic;
signal temperature_i : std_logic_vector(11 downto 0);
signal timer    : unsigned(31 downto 0) := (others => '0');

type idram_t is array(0 to 7) of std_logic_vector(15 downto 0);
signal idram : idram_t;

signal pll_lock : std_logic;
signal clk_26 : std_logic;
signal clk_osc : std_logic;
signal input_i : std_logic_vector(255 downto 0);

begin


THE_PLL : pll
    port map(
        CLKI   => clk_osc,
        CLKOP  => clk_26, --33
        CLKOS  => clk_i, --133
        LOCK   => pll_lock  --no lock available!
        );

---------------------------------------------------------------------------
-- Clock
---------------------------------------------------------------------------
clk_source: OSCH
-- synthesis translate_off
  generic map ( NOM_FREQ => "133.00" )
-- synthesis translate_on
  port map (
    STDBY    => '0',
    OSC      => clk_osc,
    SEDSTDBY => open
  );

  
THE_LCD : entity work.lcd 
  port map(
    CLK   => clk_26,
    RESET => onewire_reset,
    
    MOSI  => TEST_LINE(4),
    SCK   => TEST_LINE(5),
    DC    => TEST_LINE(3),
    CS    => TEST_LINE(1),
    RST   => TEST_LINE(2),
    
    INPUT => input_i,
    LED   => open
    
    );
  
onewire_reset <= not TEST_LINE(15);  

input_i( 15 downto   0) <= idram(0);
input_i( 31 downto  16) <= idram(1);
input_i( 47 downto  32) <= idram(2);
input_i( 63 downto  48) <= idram(3);
input_i( 79 downto  64) <= idram(4);
input_i(223 downto  80) <= (others => '0');
input_i(255 downto 224) <= std_logic_vector(timer);

---------------------------------------------------------------------------
-- Temperature Sensor
---------------------------------------------------------------------------  
THE_ONEWIRE : trb_net_onewire
  generic map(
    USE_TEMPERATURE_READOUT => 1,
    PARASITIC_MODE => c_NO,
    CLK_PERIOD => 33
    )
  port map(
    CLK      => clk_26,
    RESET    => onewire_reset,
    READOUT_ENABLE_IN => '1',
    ONEWIRE  => TEMP_LINE,
    MONITOR_OUT => open,
    --connection to id ram, according to memory map in TrbNetRegIO
    DATA_OUT => id_data_i,
    ADDR_OUT => id_addr_i,
    WRITE_OUT=> id_write_i,
    TEMP_OUT => temperature_i,
    ID_OUT   => open,
    STAT     => open
    );

PROC_IDMEM : process begin
  wait until rising_edge(clk_i);
  if id_write_i = '1' then
    idram(to_integer(unsigned(id_addr_i))) <= id_data_i;
  else
    idram(4) <= "0000" & temperature_i;
  end if;
end process;

PROC_TIMER : process begin
  wait until rising_edge(clk_26);
  timer <= timer + 1;
end process;


end architecture;
