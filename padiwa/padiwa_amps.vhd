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


entity padiwa_amps is
  generic(
    TEMP_CORRECTION: integer := c_YES
    );
  port(
    CON         : out std_logic_vector(16 downto 1);
    INP         : in  std_logic_vector(16 downto 1);
    PWM         : out std_logic_vector(16 downto 1);
    DISCHARGE   : out std_logic_vector( 8 downto 1);

    DELAY_C_IN  : in  std_logic_vector( 8 downto 1);
    DELAY_R_IN  : in  std_logic_vector( 6 downto 1);
    DELAY_L_IN  : in  std_logic_vector( 5 downto 1);    
    DELAY_B_IN  : in  std_logic_vector( 5 downto 1);    
    DELAY_C_OUT : out std_logic_vector( 8 downto 1);
    DELAY_R_OUT : out std_logic_vector( 6 downto 1);
    DELAY_L_OUT : out std_logic_vector( 5 downto 1);    
    DELAY_B_OUT : out std_logic_vector( 5 downto 1);
    
    SPARE_LVDS  : out std_logic;
    LED         : out std_logic_vector( 8 downto 1);

    SPI_CLK     : in  std_logic;
    SPI_CS      : in  std_logic;
    SPI_IN      : in  std_logic;
    SPI_OUT     : out std_logic;
    TEMP_LINE   : inout std_logic;
    TEST_LINE   : out std_logic_vector(13 downto 0)
    );
end entity;






architecture padiwa_amps_arch of padiwa_amps is

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
    COMP_IN    : in  signed(15 downto 0);
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
    ufm_page  : in std_logic_vector(12 downto 0);
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

signal pwm_i : std_logic_vector(32 downto 1);
signal INP_i       : std_logic_vector(15 downto 0);
signal fast_input  : std_logic_vector(8  downto 1);
signal slow_input  : std_logic_vector(8  downto 1);
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
signal last_spi_channel: std_logic_vector(7 downto 0);

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
signal flash_page    : std_logic_vector(12 downto 0);
signal flash_go      : std_logic;
signal flash_busy    : std_logic;
signal flash_err     : std_logic;

signal inp_select    : integer range 0 to 31 := 0;
signal inp_invert   : std_logic_vector(15 downto 0);
signal input_enable : std_logic_vector(15 downto 0);
signal inp_status   : std_logic_vector(15 downto 0);
signal led_status   : std_logic_vector(8  downto 0) := "100000000";
signal discharge_disable  : std_logic_vector(8 downto 1);
signal discharge_highz    : std_logic_vector(8 downto 1);
signal discharge_override : std_logic_vector(8 downto 1);
signal delay_invert       : std_logic_vector(8 downto 1);


signal timer    : unsigned(18 downto 0) := (others => '0');
signal last_inp : std_logic_vector(15 downto 0) := (others => '0');
signal leds     : std_logic_vector(15 downto 0) := (others => '0');
signal last_leds: std_logic_vector(15 downto 0) := (others => '0');
signal onewire_monitor : std_logic;
signal onewire_reset   : std_logic;
signal inp_or            : std_logic;
signal inp_long_or            : std_logic;
signal inp_long_reg      : std_logic;
signal last_inp_long_reg : std_logic;

signal inp_stretch : std_logic_vector(15 downto 0);
signal inp_stretched : std_logic_vector(15 downto 0);
signal inp_hold    : std_logic_vector(15 downto 0);
signal inp_gated   : std_logic_vector(15 downto 0);
signal inp_hold_reg: std_logic_vector(15 downto 0);
signal last_inp_hold_reg: std_logic_vector(15 downto 0);
signal flash_go_tmp : std_logic_vector(5 downto 0);
signal flash_reset_n : std_logic;

signal pwm_data_i  : std_logic_vector(15 downto 0);
signal pwm_data_o  : std_logic_vector(15 downto 0);
signal pwm_write_i : std_logic;
signal pwm_addr_i  : std_logic_vector(3 downto 0);
type fsm_state is (IDLE, PWM_WRITE_GET_1, PWM_WRITE_GET_2, PWM_WRITE, PWM_WAIT);
signal fsm_copydat : fsm_state;

signal pwm_fsm_data_i : std_logic_vector(15 downto 0);
signal pwm_fsm_addr   : std_logic_vector(3 downto 0);
signal pwm_fsm_write  : std_logic;
signal fsm_job        : std_logic_vector(1 downto 0);
signal ram_fsm_data_i : std_logic_vector(7 downto 0);
signal ram_fsm_addr_i : std_logic_vector(3 downto 0);
signal ram_fsm_write_i: std_logic;

signal enable_cfg_flash : std_logic;
signal comp_setting     : std_logic_vector(15 downto 0);
signal compensate_i     : signed(15 downto 0);
signal temp_calc_i      : signed(27 downto 0);
signal temperature_i_s  : std_logic_vector(11 downto 0);
signal comp_setting_s   : std_logic_vector(15 downto 0);

signal ffarr_data       : std_logic_vector(15 downto 0);
signal ffarr_read       : std_logic;


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

---------------------------------------------------------------------------
-- Input re-ordering
---------------------------------------------------------------------------

  INP_i <= INP;
  PWM <= pwm_i(16 downto 1);

   
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

spi_reg00_i <= pwm_data_o;
spi_reg10_i <= idram(to_integer(unsigned(spi_channel_i(2 downto 0))));
spi_reg40_i <= flash_busy & flash_err & "000000" & ram_data_o;

---------------------------------------------------------------------------
-- RAM Interface
---------------------------------------------------------------------------  
--CFG-Flash: 0 - 5758
--UFM-Flash: 7167 - 7936

PROC_CTRL_FLASH : process begin
  wait until rising_edge(clk_i);
  if(spi_write_i(5) = '1' and spi_channel_i(7 downto 4) = x"0") then
    flash_command <= spi_data_i(15 downto 13);
    if(enable_cfg_flash = '1') then
      flash_page    <= spi_data_i(12 downto 0);
    else
      flash_page    <= "111" & spi_data_i(9 downto 0);
    end if;
    flash_go_tmp(0)<= '1';
  else
    flash_go_tmp(5 downto 0) <= flash_go_tmp(4 downto 0) & '0';
  end if;
  if flash_reset_n = '0' then
    flash_go_tmp <= (others => '0');
  end if;
end process;

PROC_CTRL_FLASH_ENABLE : process begin
  wait until rising_edge(clk_i);
  if(spi_write_i(5) = '1' and spi_channel_i(7 downto 4) = x"C") then
    enable_cfg_flash <= spi_data_i(0);
  end if;
end process;

flash_go <= or_all(flash_go_tmp);


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

THE_FLASH : UFM_WB
  port map(
    clk_i => clk_26,
    rst_n => flash_reset_n,
    cmd       => flash_command,
    ufm_page  => flash_page,
    GO        => flash_go,
    BUSY      => flash_busy,
    ERR       => flash_err,
    mem_clk    => open,
    mem_we      => flashram_write_i,
    mem_ce      => flashram_cen_i,
    mem_addr    => flashram_addr_i,
    mem_wr_data => flashram_data_i,
    mem_rd_data => flashram_data_o
    );

PROC_DATA_COPY : process 
  variable count : integer range 0 to 31 := 0;
  variable tmp   : std_logic_vector(7 downto 0);
begin
  wait until rising_edge(clk_i);
  pwm_fsm_write   <= '0';
  ram_fsm_write_i <= '0';
  case fsm_copydat is
    when IDLE => 
      count := 0;
      if spi_write_i(5) = '1' and spi_channel_i(7 downto 4) = x"1" then
        fsm_copydat    <= PWM_WRITE_GET_1;
        ram_fsm_addr_i <= std_logic_vector(to_unsigned(count,4));
        fsm_job        <= spi_channel_i(1 downto 0);
        count := count + 1;
      end if;
    when PWM_WRITE_GET_1 =>
      ram_fsm_addr_i <= std_logic_vector(to_unsigned(count,4));
      count := count + 1;
      fsm_copydat <= PWM_WRITE_GET_2;
    when PWM_WRITE_GET_2 =>
      fsm_copydat <= PWM_WRITE;
      tmp := ram_data_o;
    when PWM_WRITE =>
      pwm_fsm_data_i <= tmp & ram_data_o;
      pwm_fsm_write  <= '1';
      pwm_fsm_addr   <= fsm_job(0) & std_logic_vector(to_unsigned(count/2-1,3));
     
      if(count < 15) then
        fsm_copydat <= PWM_WRITE_GET_1;
      else
        fsm_copydat <= PWM_WAIT;
      end if;
      
      ram_fsm_addr_i <= std_logic_vector(to_unsigned(count,4));
      count := count + 1;
      
    when PWM_WAIT =>
      fsm_copydat <= IDLE;
  end case;
  if onewire_reset = '1' then
    fsm_copydat <= IDLE;
  end if;
end process;

---------------------------------------------------------------------------
-- PWM
---------------------------------------------------------------------------  

THE_PWM_GEN : pwm_generator
  port map(
    CLK        => clk_i,
    DATA_IN    => pwm_data_i,
    DATA_OUT   => pwm_data_o,
    COMP_IN    => compensate_i,
    WRITE_IN   => pwm_write_i,
    ADDR_IN    => pwm_addr_i,
    PWM        => pwm_i
    );



PROC_PWM_DATA_MUX : process(fsm_copydat, spi_data_i, spi_write_i, spi_channel_i,
                            pwm_fsm_addr, pwm_fsm_data_i, pwm_fsm_write,
                            ram_fsm_addr_i, ram_fsm_data_i, ram_fsm_write_i)
begin
  if(fsm_copydat = IDLE) then
    pwm_data_i  <= spi_data_i;
    pwm_write_i <= spi_write_i(0);
    pwm_addr_i  <= spi_channel_i(3 downto 0);
    ram_write_i <= spi_write_i(4);
    ram_data_i  <= spi_data_i(7 downto 0);
    ram_addr_i  <= spi_channel_i(3 downto 0);
  else
    pwm_data_i  <= pwm_fsm_data_i;
    pwm_write_i <= pwm_fsm_write;
    pwm_addr_i  <= pwm_fsm_addr;
    ram_write_i <= ram_fsm_write_i;
    ram_data_i  <= ram_fsm_data_i;
    ram_addr_i  <= ram_fsm_addr_i;
  end if;
end process;

    
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
  
  if spi_write_i(1) = '1' then
    onewire_reset <= spi_data_i(0);
  end if;
end process;

flash_reset_n <= not onewire_reset;

---------------------------------------------------------------------------
-- I/O Register 0x20
---------------------------------------------------------------------------  
THE_IO_REG_READ : process begin
  wait until rising_edge(clk_i);
  if spi_channel_i(4) = '0' then
    case spi_channel_i(3 downto 0) is
      when x"0" => spi_reg20_i <= input_enable;
      when x"1" => spi_reg20_i <= inp_status;
      when x"2" => spi_reg20_i <= x"0" & "000" & led_status(8) & leds(14) & leds(12) & leds(10) & leds(8) & leds(6) & leds(4) & leds(2) & leds(0) ;
      when x"3" => spi_reg20_i <= x"00" & "000" & std_logic_vector(to_unsigned(inp_select,5));
      when x"4" => spi_reg20_i <= inp_invert;
      when x"5" => spi_reg20_i <= inp_stretch;
      when x"6" => spi_reg20_i <= comp_setting;
      when x"7" => spi_reg20_i <= x"00" & discharge_disable;
      when x"8" => spi_reg20_i <= x"00" & discharge_override;
      when x"9" => spi_reg20_i <= x"00" & discharge_highz;
      when x"a" => spi_reg20_i <= x"00" & delay_invert;
      when x"f" => spi_reg20_i <= ffarr_data; 
      when others => null;
    end case;
  else
    case spi_channel_i(3 downto 0) is
      when x"0" => spi_reg20_i <= std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,16));
      when x"1" => spi_reg20_i <= std_logic_vector(to_unsigned(VERSION_NUMBER_TIME/2**16,16));
      when x"2" => spi_reg20_i <= x"0000";
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
      when x"2" => led_status <= spi_data_i(8 downto 0);
      when x"3" => inp_select <= to_integer(unsigned(spi_data_i(4 downto 0)));
      when x"4" => inp_invert <= spi_data_i;
      when x"5" => inp_stretch <= spi_data_i;
      when x"6" => comp_setting <= spi_data_i;
      when x"7" => discharge_disable  <= spi_data_i(7 downto 0);
      when x"8" => discharge_override <= spi_data_i(7 downto 0);
      when x"9" => discharge_highz    <= spi_data_i(7 downto 0);
      when x"a" => delay_invert       <= spi_data_i(7 downto 0);
      when others => null;
    end case;
  end if;
end process;

inp_status <= INP_i when rising_edge(clk_i);
last_inp <= inp_status(15 downto 0) when rising_edge(clk_i);

temperature_i_s <= temperature_i when rising_edge(clk_26);
comp_setting_s <= comp_setting when rising_edge(clk_26);
temp_calc_i <= signed(temperature_i_s) * signed(comp_setting_s) when rising_edge(clk_26);

gen_comp: if TEMP_CORRECTION = 1 generate
  compensate_i <= temp_calc_i(27 downto 12) when rising_edge(clk_26);
end generate;
gen_no_comp: if TEMP_CORRECTION = 0 generate
  compensate_i <= (others => '0');
end generate;


---------------------------------------------------------------------------
-- Delay generation
---------------------------------------------------------------------------


gen_discharge : for i in 1 to 8 generate
DISCHARGE(i) <= 'Z'                               when  discharge_highz(i) = '1' else
                (DELAY_C_IN(i) and slow_input(i)) when  discharge_disable(i) = '0' else
                discharge_override(i)             when  discharge_disable(i) = '1';
                
DELAY_C_OUT(i) <= (fast_input(i) or slow_input(i)) xor delay_invert(i);
end generate;
                
fast_input <= inp_gated(14) & inp_gated(12) & inp_gated(10) & inp_gated(8) & inp_gated(6) & inp_gated(4) & inp_gated(2) & inp_gated(0);
slow_input <= inp_gated(15) & inp_gated(13) & inp_gated(11) & inp_gated(9) & inp_gated(7) & inp_gated(5) & inp_gated(3) & inp_gated(1);


---------------------------------------------------------------------------
-- LED blinking when activity on inputs
---------------------------------------------------------------------------
PROC_TIMER : process begin
  wait until rising_edge(clk_i);
  timer <= timer + 1;
  leds <= (last_inp xor inp_status(15 downto 0)) or leds or last_leds;
  if timer = 0 then
    leds <= not inp_status(15 downto 0);
    last_leds <= x"0000";
  end if;
end process;


---------------------------------------------------------------------------
-- Rest of the I/O
---------------------------------------------------------------------------

inp_gated <= (INP_i xor inp_invert) and not input_enable;
CON <= inp_gated or (inp_stretched and inp_stretch);


inp_hold <= (inp_gated or inp_hold) and not inp_hold_reg;
inp_hold_reg <= inp_hold when rising_edge(clk_i);
last_inp_hold_reg <= inp_hold_reg when rising_edge(clk_i);
inp_stretched <= inp_hold_reg or last_inp_hold_reg or inp_hold;





SPARE_OUTPUT : process(INP_i, inp_select, inp_or, inp_long_or, inp_long_reg, last_inp_long_reg)
  begin
    if inp_select < 16 then
      SPARE_LVDS <= INP_i(inp_select);
    elsif inp_select < 24 then
      SPARE_LVDS <= inp_or;
    else
      SPARE_LVDS <= inp_long_reg or last_inp_long_reg or inp_long_or ;
    end if;
  end process;

inp_or <= or_all((INP_i xor inp_invert) and not input_enable);
inp_long_or <= (inp_or or inp_long_or) and not inp_long_reg;
inp_long_reg      <= inp_long_or when rising_edge(clk_i);
last_inp_long_reg <= inp_long_reg when rising_edge(clk_i);


TEST_LINE               <= (others => '0');


gen_leds : for i in 1 to 8 generate
  LED(i) <= not leds((i-1)*2) when led_status(8) = '1' else not led_status(i-1);
end generate;


end architecture;

