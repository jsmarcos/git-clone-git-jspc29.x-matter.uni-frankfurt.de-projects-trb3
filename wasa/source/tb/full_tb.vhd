library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;




entity tb is
end entity;



architecture full_tb of tb is

signal clk, reset : std_logic := '1';

signal spi_clk, spi_in, spi_out : std_logic;

signal spi_cs  : std_logic_vector(15 downto 0) := x"ffff";
signal bus_addr :  std_logic_vector( 4 downto 0) := "00000";    
signal bus_data :  std_logic_vector(31 downto 0) := (others => '0');    
signal bus_write:  std_logic := '0';

component spi_ltc2600 is
  port(
    CLK_IN          : in   std_logic;
    RESET_IN        : in   std_logic;
    -- Slave bus
    BUS_READ_IN     : in   std_logic;
    BUS_WRITE_IN    : in   std_logic;
    BUS_BUSY_OUT    : out  std_logic;
    BUS_ACK_OUT     : out  std_logic;
    BUS_ADDR_IN     : in   std_logic_vector(4 downto 0);
    BUS_DATA_IN     : in   std_logic_vector(31 downto 0);
    BUS_DATA_OUT    : out  std_logic_vector(31 downto 0);
    -- SPI connections
    SPI_CS_OUT      : out  std_logic_vector(15 downto 0);
    SPI_SDI_IN      : in   std_logic;
    SPI_SDO_OUT     : out  std_logic;
    SPI_SCK_OUT     : out  std_logic
    );
end component;


component panda_dirc_wasa is
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
    TEST_LINE  : out std_logic_vector(15 downto 0)
    );
end component;

begin

clk <= not clk after 5 ns;
reset <= '0' after 30 ns;

process begin
  wait for 101 ns;
  bus_addr  <= "00000";
  bus_data  <= x"51800000";
  bus_write <= '1';
  wait for 10 ns;
  bus_write <= '0';

  wait for 101 ns;
  bus_addr  <= "10000";
  bus_data  <= x"00000001";
  bus_write <= '1';
  wait for 10 ns;
  bus_write <= '0';

  wait for 101 ns;
  bus_addr  <= "10001";
  bus_data  <= x"00000001";
  bus_write <= '1';
  wait for 10 ns;
  bus_write <= '0';

  wait for 10010 ns;
  bus_addr  <= "00000";
  bus_data  <= x"51810000";
  bus_write <= '1';
  wait for 10 ns;
  bus_write <= '0';

  wait for 101 ns;
  bus_addr  <= "10000";
  bus_data  <= x"00000001";
  bus_write <= '1';
  wait for 10 ns;
  bus_write <= '0';

  wait for 101 ns;
  bus_addr  <= "10001";
  bus_data  <= x"00000001";
  bus_write <= '1';
  wait for 10 ns;
  bus_write <= '0';    
  
  wait for 10010 ns;
  bus_addr  <= "00000";
  bus_data  <= x"0080ffff";
  bus_write <= '1';
  wait for 10 ns;
  bus_write <= '0';

  wait for 101 ns;
  bus_addr  <= "10000";
  bus_data  <= x"00000001";
  bus_write <= '1';
  wait for 10 ns;
  bus_write <= '0';

  wait for 101 ns;
  bus_addr  <= "10001";
  bus_data  <= x"00000001";
  bus_write <= '1';
  wait for 10 ns;
  bus_write <= '0';  
  wait;
end process;

PWM : panda_dirc_wasa
  port map(
    CON => open,
    INP => (others => '0'),
    PWM => open,
    SPARE_LINE => open,
    LED_GREEN => open,
    LED_ORANGE => open,
    LED_RED => open,
    LED_YELLOW => open,
    SPI_CLK => spi_clk,
    SPI_CS => spi_cs(0),
    SPI_IN => spi_in,
    SPI_OUT => spi_out,
    TEMP_LINE => open,
    TEST_LINE => open
  );


THE_SPI : spi_ltc2600
  port map(
    CLK_IN          => clk,
    RESET_IN        => reset,
    -- Slave bus
    BUS_READ_IN     => '0',
    BUS_WRITE_IN    => bus_write,
    BUS_BUSY_OUT    => open,
    BUS_ACK_OUT     => open,
    BUS_ADDR_IN     => bus_addr, 
    BUS_DATA_IN     => bus_data,
    BUS_DATA_OUT    => open,
    -- SPI connections
    SPI_CS_OUT      => spi_cs,
    SPI_SDI_IN      => spi_out,
    SPI_SDO_OUT     => spi_in,
    SPI_SCK_OUT     => spi_clk
    );


    
end architecture;