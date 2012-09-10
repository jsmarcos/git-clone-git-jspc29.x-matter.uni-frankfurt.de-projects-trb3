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

component flashram
  port (
    DataInA: in  std_logic_vector(7 downto 0); 
    DataInB: in  std_logic_vector(7 downto 0); 
    AddressA: in  std_logic_vector(3 downto 0); 
    AddressB: in  std_logic_vector(3 downto 0); 
    ClockA: in  std_logic; 
    ClockB: in  std_logic; 
    ClockEnA: in  std_logic; 
    ClockEnB: in  std_logic; 
    WrA: in  std_logic; 
    WrB: in  std_logic; 
    ResetA: in  std_logic; 
    ResetB: in  std_logic; 
    QA: out  std_logic_vector(7 downto 0); 
    QB: out  std_logic_vector(7 downto 0)
    );
end component;

component pll
    port (
        CLKI: in  std_logic; 
        CLKOP: out  std_logic; 
        CLKOS: out  std_logic; 
        LOCK: out  std_logic);
end component;


component UFM_WB
  port(
    clk_i : in std_logic;
    rst_n : in std_logic;
    cmd       : in std_logic_vector(2 downto 0);
    ufm_page  : in std_logic_vector(10 downto 0);
    GO        : in std_logic;
    BUSY      : out std_logic;
    ERR       : out std_logic;
    mem_clk   : out std_logic;
    mem_we    : out std_logic;
    mem_ce    : out std_logic;
    mem_addr  : out std_logic_vector(3 downto 0);
    mem_wr_data : out std_logic_vector(7 downto 0);
    mem_rd_data : in  std_logic_vector(7 downto 0)
    );
end component;

component PUR   port(PUR : in std_logic); end component;
component GSR   port(GSR : in std_logic); end component;
  


attribute NOM_FREQ : string;
attribute NOM_FREQ of clk_source : label is "133.00";
signal clk_i  : std_logic;

signal reset_i   : std_logic := '1';
signal reset_cnt : unsigned(3 downto 0) := x"0";
signal id_data_i : std_logic_vector(15 downto 0);
signal id_addr_i : std_logic_vector(2 downto 0);
signal id_write_i: std_logic;
signal ram_write_i : std_logic;
signal ram_data_i: std_logic_vector(7 downto 0);
signal ram_data_o: std_logic_vector(7 downto 0);
signal ram_addr_i: std_logic_vector(3 downto 0);
signal temperature_i : std_logic_vector(11 downto 0);

type idram_t is array(0 to 7) of std_logic_vector(15 downto 0);
signal idram : idram_t;
type ram_t is array(0 to 15) of std_logic_vector(15 downto 0);
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
signal buf_SPI_OUT     : std_logic;
signal spi_debug_i     : std_logic_vector(15 downto 0);

signal pll_lock : std_logic;
signal clk_26 : std_logic;
signal clk_osc : std_logic;

signal flashram_addr_i : std_logic_vector(3 downto 0);
signal flashram_cen_i  : std_logic;
signal flashram_reset  : std_logic;
signal flashram_write_i: std_logic;
signal flashram_data_i : std_logic_vector(7 downto 0);
signal flashram_data_o : std_logic_vector(7 downto 0);

signal flash_command : std_logic_vector(2 downto 0);
signal flash_page    : std_logic_vector(10 downto 0);
signal flash_go      : std_logic;
signal flash_busy    : std_logic;
signal flash_err     : std_logic;

signal inp_select    : integer range 0 to 15 := 0;
signal input_enable : std_logic_vector(15 downto 0);
signal inp_status   : std_logic_vector(15 downto 0);
signal led_status   : std_logic_vector(4  downto 0);

signal timer    : unsigned(18 downto 0) := (others => '0');
signal last_inp : std_logic_vector(3 downto 0) := (others => '0');
signal leds     : std_logic_vector(3 downto 0) := (others => '0');
signal last_leds: std_logic_vector(3 downto 0) := (others => '0');
signal onewire_monitor : std_logic;
signal onewire_reset   : std_logic;

begin

-- PROC_RESET : process begin
--   wait until rising_edge(clk_osc);
--   reset_i <= not pll_lock;
-- --   if reset_cnt /= x"F" then
-- --     reset_cnt <= reset_cnt + 1;
-- --     reset_i   <= '1';
-- --   end if;
-- end process;



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


---------------------------------------------------------------------------
-- SPI Interface
---------------------------------------------------------------------------  
THE_SPI_SLAVE : spi_slave
  port map(
		CLK        => clk_i,
    SPI_CLK    => SPI_CLK,
    SPI_CS     => SPI_CS,
    SPI_IN     => SPI_IN,
    SPI_OUT    => buf_SPI_OUT,
    DATA_OUT   => spi_data_i,
    REG00_IN   => spi_reg00_i,
    REG10_IN   => spi_reg10_i,
    REG20_IN   => spi_reg20_i,
    REG40_IN   => spi_reg40_i,
    OPERATION_OUT => spi_operation_i,
    CHANNEL_OUT   => spi_channel_i,
    WRITE_OUT     => spi_write_i,
    DEBUG_OUT     => spi_debug_i
    );

SPI_OUT <= buf_SPI_OUT;    
---------------------------------------------------------------------------
-- RAM Interface
---------------------------------------------------------------------------  

ram_write_i <= spi_write_i(4);                      --or signal from Flash entity
ram_data_i  <= spi_data_i(7 downto 0);                          --or signal from Flash entity
ram_addr_i  <= spi_channel_i(3 downto 0); --or signal from Flash entity

spi_reg40_i <= x"00" & ram_data_o;


THE_FLASH_RAM : flashram
  port map(
    DataInA   => ram_data_i,
    DataInB   => flashram_data_i,
    AddressA  => ram_addr_i,
    AddressB  => flashram_addr_i,
    ClockA    => clk_i, 
    ClockB    => clk_26,
    ClockEnA  => '1',
    ClockEnB  => flashram_cen_i,
    WrA       => ram_write_i, 
    WrB       => flashram_write_i, 
    ResetA    => '0',
    ResetB    => flashram_reset,
    QA        => ram_data_o,
    QB        => flashram_data_o
    );

---------------------------------------------------------------------------
-- Flash Controller
---------------------------------------------------------------------------  

-- THE_FLASH : UFM_WB
--   port map(
--     clk_i => clk_26,
--     rst_n => '1',
--     cmd       => flash_command,
--     ufm_page  => flash_page,
--     GO        => flash_go,
--     BUSY      => flash_busy,
--     ERR       => flash_err,
--     mem_clk    => open,
--     mem_we      => flashram_write_i,
--     mem_ce      => flashram_cen_i,
--     mem_addr    => flashram_addr_i,
--     mem_wr_data => flashram_data_i,
--     mem_rd_data => flashram_data_o
--     );

    
--     PUR_INST : PUR port map(PUR=>'1');
--     GSR_INST : GSR port map(GSR=>'1');
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

    PWM <= pwm_i(15 downto 0);

-- PWM_ODDR : oddr16
--   port map(
--     clk    => clk_i,
--     clkout => open,
--     reset  => '0',
--     sclk   => open,
--     dataout => pwm_i,
--     dout    => PWM
--     );


    
---------------------------------------------------------------------------
-- Temperature Sensor
---------------------------------------------------------------------------  
  
THE_ONEWIRE : trb_net_onewire
  generic map(
    USE_TEMPERATURE_READOUT => 1,
    PARASITIC_MODE => c_NO,
    CLK_PERIOD => 40
    )
  port map(
    CLK      => clk_26,
    RESET    => onewire_reset,
    READOUT_ENABLE_IN => '1',
    ONEWIRE  => TEMP_LINE,
    MONITOR_OUT => onewire_monitor,
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
  spi_reg10_i <= idram(to_integer(unsigned(spi_channel_i(2 downto 0))));
  
  if spi_write_i(1) = '1' then
    onewire_reset <= spi_data_i(0);
  end if;
end process;



---------------------------------------------------------------------------
-- I/O Register 0x20
---------------------------------------------------------------------------  
THE_IO_REG_READ : process begin
  wait until rising_edge(clk_i);
  if spi_channel_i(4) = '0' then
    case spi_channel_i(3 downto 0) is
      when x"0" => spi_reg20_i <= input_enable;
      when x"1" => spi_reg20_i <= inp_status;
      when x"2" => spi_reg20_i <= x"00" & "000" & led_status(4) & leds;
      when x"3" => spi_reg20_i <= x"000" & std_logic_vector(to_unsigned(inp_select,4));
      when others => null;
    end case;
  else
    case spi_channel_i(3 downto 0) is
      when x"0" => spi_reg20_i <= std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,16));
      when x"1" => spi_reg20_i <= std_logic_vector(to_unsigned(VERSION_NUMBER_TIME/2**16,16));
      when others => null;
    end case;
  end if;
end process;

THE_IO_REG_WRITE : process begin
  wait until rising_edge(clk_i);
  if spi_write_i(2) = '1' then
    case spi_channel_i(3 downto 0) is
      when x"0" => input_enable <= spi_data_i;
      when x"1" => null;
      when x"2" => led_status <= spi_data_i(4 downto 0);
      when x"3" => inp_select <= to_integer(unsigned(spi_data_i(3 downto 0)));
      when others => null;
    end case;
  end if;
end process;

inp_status <= INP when rising_edge(clk_i);
last_inp <= inp_status(3 downto 0) when rising_edge(clk_i);
---------------------------------------------------------------------------
-- LED blinking when activity on inputs
---------------------------------------------------------------------------
PROC_TIMER : process begin
  wait until rising_edge(clk_i);
  timer <= timer + 1;
  leds <= (last_inp xor inp_status(3 downto 0)) or leds or last_leds;
  if timer = 0 then
    leds <= not inp_status(3 downto 0);
    last_leds <= x"0";
  end if;
end process;


---------------------------------------------------------------------------
-- Rest of the I/O
---------------------------------------------------------------------------
CON <= INP and not input_enable;

SPARE_LINE(0) <= '0'; --clk_26;
SPARE_LINE(1) <= '0'; --clk_i;
SPARE_LINE(2) <= '0'; --timer(18);
SPARE_LINE(3) <= '0';

SPARE_LVDS <= INP(inp_select+1);

-- TEST_LINE(0) <= '0';
-- TEST_LINE(15 downto 1) <= (others => '0');

TEST_LINE(7 downto 0) <= spi_debug_i(7 downto 0);
TEST_LINE(10 downto 8) <= id_addr_i(2 downto 0);
TEST_LINE(11) <= onewire_monitor;
TEST_LINE(12) <= id_write_i;
TEST_LINE(15 downto 13) <= id_data_i(2 downto 0);

LED_GREEN  <= not leds(0) when led_status(4) = '0' else not led_status(0);
LED_ORANGE <= not leds(1) when led_status(4) = '0' else not led_status(1);
LED_RED    <= not leds(2) when led_status(4) = '0' else not led_status(2);
LED_YELLOW <= not leds(3) when led_status(4) = '0' else not led_status(3);

end architecture;

