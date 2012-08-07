library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;

library machxo2;
use machxo2.all;


entity panda_dirc_wasa is
  port(
    CON        : out std_logic_vector(16 downto 1);
    INP        : in  std_logic_vector(16 downto 1);
    PWM        : out std_logic_vector(16 downto 1);
    SPARE_LINE : out std_logic_vector(5 downto 0);
    LED_GREEN  : out std_logic;
    LED_ORANGE : out std_logic;
    LED_RED    : out std_logic;
    LED_YELLOW : out std_logic;
    SPI_CLK    : in  std_logic;
    SPI_CS     : in  std_logic;
    SPI_IN     : in  std_logic;
    SPI_OUT    : out std_logic;
    TEMP_LINE  : inout std_logic;
    TEST_LINE  : out std_logic_vector(15 downto 0)
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

component oddr16 is
    port (
        clk: in  std_logic; 
        clkout: out  std_logic; 
        reset: in  std_logic; 
        sclk: out  std_logic; 
        dataout: in  std_logic_vector(31 downto 0); 
        dout: out  std_logic_vector(15 downto 0));
end component;

component spi_slave
  port(
    CLK        : in  std_logic;
    SPI_CLK    : in  std_logic;
    SPI_CS     : in  std_logic;
    SPI_IN     : in  std_logic;
    SPI_OUT    : out std_logic;
  
    DATA_OUT   : out std_logic_vector(15 downto 0);
    REG00_IN   : in  std_logic_vector(15 downto 0);
    REG10_IN   : in  std_logic_vector(15 downto 0);
    REG20_IN   : in  std_logic_vector(15 downto 0);
    REG40_IN   : in  std_logic_vector(15 downto 0);
    
    OPERATION_OUT : out std_logic_vector(3 downto 0);
    CHANNEL_OUT   : out std_logic_vector(7 downto 0);
    WRITE_OUT     : out std_logic_vector(15 downto 0);

    DEBUG_OUT     : out std_logic_vector(15 downto 0)
    );
end component;


component pwm_generator
  port(
    CLK        : in std_logic;
    DATA_IN    : in  std_logic_vector(15 downto 0);
    DATA_OUT   : out std_logic_vector(15 downto 0);
    WRITE_IN   : in  std_logic;
    ADDR_IN    : in  std_logic_vector(3 downto 0);
    PWM        : out std_logic_vector(31 downto 0)
    );
end component;

attribute NOM_FREQ : string;
attribute NOM_FREQ of clk_source : label is "133.00";
signal clk_i  : std_logic;

signal reset_i   : std_logic := '1';
signal reset_cnt : unsigned(3 downto 0) := x"0";
signal id_data_i : std_logic_vector(15 downto 0);
signal id_addr_i : std_logic_vector(2 downto 0);
signal id_write_i: std_logic;
signal ram_write_i : std_logic;
signal ram_data_i: std_logic_vector(15 downto 0);
signal ram_data_o: std_logic_vector(15 downto 0);
signal ram_addr_i: integer range 0 to 15;
signal temperature_i : std_logic_vector(11 downto 0);

type ram_t is array(0 to 15) of std_logic_vector(15 downto 0);
signal idram : ram_t;
signal ram   : ram_t;

signal pwm_i : std_logic_vector(31 downto 0);

signal spi_reg00_i : std_logic_vector(15 downto 0);
signal spi_reg10_i : std_logic_vector(15 downto 0);
signal spi_reg20_i : std_logic_vector(15 downto 0);
signal spi_reg40_i : std_logic_vector(15 downto 0);
signal spi_data_i  : std_logic_vector(15 downto 0);
signal spi_operation_i : std_logic_vector(3 downto 0);
signal spi_channel_i   : std_logic_vector(7 downto 0);
signal spi_write_i     : std_logic_vector(15 downto 0);

begin

PROC_RESET : process begin
  wait until rising_edge(clk_i);
  reset_i <= '0';
  if reset_cnt /= x"F" then
    reset_cnt <= reset_cnt + 1;
    reset_i   <= '1';
  end if;
end process;

---------------------------------------------------------------------------
-- Clock
---------------------------------------------------------------------------
clk_source: OSCH
-- synthesis translate_off
  generic map ( NOM_FREQ => "133.00" )
-- synthesis translate_on
  port map (
    STDBY    => '0',
    OSC      => clk_i,
    SEDSTDBY => open
  );


---------------------------------------------------------------------------
-- SPI Interface
---------------------------------------------------------------------------  
THE_SPI_SLAVE : spi_slave
  port map(
		CLK        => clk_i,
    SPI_CLK    => SPI_CLK,
    SPI_CS     => SPI_CS,
    SPI_IN     => SPI_IN,
    SPI_OUT    => SPI_OUT,
    DATA_OUT   => spi_data_i,
    REG00_IN   => spi_reg00_i,
    REG10_IN   => spi_reg10_i,
    REG20_IN   => spi_reg20_i,
    REG40_IN   => spi_reg40_i,
    OPERATION_OUT => spi_operation_i,
    CHANNEL_OUT   => spi_channel_i,
    WRITE_OUT     => spi_write_i,
    DEBUG_OUT     => open
    );

ram_write_i <= spi_write_i(4);                      --or signal from Flash entity
ram_data_i  <= spi_data_i;                          --or signal from Flash entity
ram_addr_i  <= to_integer(unsigned(spi_channel_i(3 downto 0))); --or signal from Flash entity

PROC_RAM : process begin
  wait until rising_edge(clk_i);
  if ram_write_i = '1' then
    ram(ram_addr_i) <= ram_data_i;
  end if;
  ram_data_o  <= ram(ram_addr_i);
  spi_reg40_i <= ram(to_integer(unsigned(spi_channel_i(3 downto 0))));
end process;
    
---------------------------------------------------------------------------
-- PWM
---------------------------------------------------------------------------  

THE_PWM_GEN : pwm_generator
  port map(
    CLK        => clk_i,
    DATA_IN    => spi_data_i,
    DATA_OUT   => spi_reg00_i,
    WRITE_IN   => spi_write_i(0),
    ADDR_IN    => spi_channel_i(3 downto 0),
    PWM        => pwm_i
    );


PWM_ODDR : oddr16
  port map(
    clk    => clk_i,
    clkout => open,
    reset  => '0',
    sclk   => open,
    dataout => pwm_i,
    dout    => PWM
    );


    
---------------------------------------------------------------------------
-- Temperature Sensor
---------------------------------------------------------------------------  
  
THE_ONEWIRE : trb_net_onewire
  port map(
    CLK      => clk_i,
    RESET    => reset_i,
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
  spi_reg10_i <= idram(to_integer(unsigned(spi_channel_i(3 downto 0))));
end process;
    

---------------------------------------------------------------------------
-- Rest of the I/O
---------------------------------------------------------------------------
CON <= INP;


SPARE_LINE <= (others => '0');

TEST_LINE(0) <= clk_i;
TEST_LINE(15 downto 1) <= (others => '0');

LED_GREEN  <= '0';
LED_ORANGE <= '0';
LED_RED    <= '0';
LED_YELLOW <= '0';

end architecture;

