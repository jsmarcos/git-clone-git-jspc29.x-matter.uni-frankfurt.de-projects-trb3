library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;

entity adc_ad9219 is
  generic(
    CHANNELS       : integer range 4 to 4 := 4;
    DEVICES_LEFT   : integer range 1 to 7 := 7;
    DEVICES_RIGHT  : integer range 1 to 7 := 5;
    RESOLUTION     : integer range 10 to 10 := 10
    );
  port(
    CLK        : in std_logic;
    CLK_ADCREF : in std_logic;
    CLK_ADCDAT : in std_logic;
    RESTART_IN : in std_logic;
    ADCCLK_OUT : out std_logic;
        --FCO is another channel for each ADC    
    ADC_DATA   : in  std_logic_vector((DEVICES_LEFT+DEVICES_RIGHT)*(CHANNELS+1)-1 downto 0);
    ADC_DCO    : in  std_logic_vector((DEVICES_LEFT+DEVICES_RIGHT) downto 1);
    
    DATA_OUT       : out std_logic_vector((DEVICES_LEFT+DEVICES_RIGHT)*CHANNELS*RESOLUTION-1 downto 0);
    FCO_OUT        : out std_logic_vector((DEVICES_LEFT+DEVICES_RIGHT)*RESOLUTION-1 downto 0);
    DATA_VALID_OUT : out std_logic_vector((DEVICES_LEFT+DEVICES_RIGHT)-1 downto 0);
    DEBUG          : out std_logic_vector(31 downto 0)
    );
end entity;



architecture adc_ad9219_arch of  adc_ad9219 is

type q_t is array(0 to 11) of std_logic_vector(19 downto 0);
signal q : q_t;
signal tmp : q_t;

signal clk_data_left   : std_logic;
signal clk_data_right  : std_logic;
signal restart_i   : std_logic;

begin

  ADCCLK_OUT <= CLK_ADCREF;
  restart_i <= RESTART_IN when rising_edge(clk_data_left);

THE_LEFT : entity work.dqsinput_7x5
    port map(
        clk_0  => ADC_DCO(1),
        clk_1  => ADC_DCO(2), 
        clk_2  => ADC_DCO(3), 
        clk_3  => ADC_DCO(4),
        clk_4  => ADC_DCO(5),
        clk_5  => ADC_DCO(6),
        clk_6  => ADC_DCO(7),
        clkdiv_reset => restart_i,
        eclk   => CLK_ADCREF, 
        reset_0 => restart_i,
        reset_1 => restart_i, 
        reset_2 => restart_i,
        reset_3 => restart_i,
        reset_4 => restart_i,
        reset_5 => restart_i,
        reset_6 => restart_i,
        sclk    => clk_data_left,
        datain_0 => ADC_DATA( 4 downto  0),
        datain_1 => ADC_DATA( 9 downto  5),
        datain_2 => ADC_DATA(14 downto 10),
        datain_3 => ADC_DATA(19 downto 15),
        datain_4 => ADC_DATA(24 downto 20),
        datain_5 => ADC_DATA(29 downto 25),
        datain_6 => ADC_DATA(34 downto 30),
        q_0      => q(0),
        q_1      => q(1),
        q_2      => q(2),
        q_3      => q(3),
        q_4      => q(4),
        q_5      => q(5),
        q_6      => q(6)
        );
  
THE_RIGHT : entity work.dqsinput_5x5
    port map(
        clk_0  => ADC_DCO(8),
        clk_1  => ADC_DCO(9), 
        clk_2  => ADC_DCO(10), 
        clk_3  => ADC_DCO(11),
        clk_4  => ADC_DCO(12),
        clkdiv_reset => restart_i,
        eclk   => CLK_ADCREF, 
        reset_0 => restart_i,
        reset_1 => restart_i, 
        reset_2 => restart_i,
        reset_3 => restart_i,
        reset_4 => restart_i,
        sclk    => clk_data_right,
        datain_0 => ADC_DATA(39 downto 35),
        datain_1 => ADC_DATA(44 downto 40),
        datain_2 => ADC_DATA(49 downto 45),
        datain_3 => ADC_DATA(54 downto 50),
        datain_4 => ADC_DATA(59 downto 55),
        q_0      => q(7),
        q_1      => q(8),
        q_2      => q(9),
        q_3      => q(10),
        q_4      => q(11)
        );
        
        
gen_chips_left : for i in 0 to DEVICES_LEFT-1 generate
  THE_FIFO : fifo_cdt_200
    port map(
      Data(19 downto 0)  => q(i),
      WrClock  => clk_data_left,
      RdClock  => CLK,
      WrEn     => '1',
      RdEn     => '1',
      Reset    => '0',
      RPReset  => restart_i,
      Q        => open,
      Empty    => open,
      Full     => open
      );
  DEBUG(i) <= or_all(tmp(i));    
end generate;    

gen_chips_right : for i in DEVICES_LEFT to DEVICES_LEFT+DEVICES_RIGHT-1 generate
  THE_FIFO : fifo_cdt_200
    port map(
      Data(19 downto 0)  => q(i),
      WrClock  => clk_data_right,
      RdClock  => CLK,
      WrEn     => '1',
      RdEn     => '1',
      Reset    => '0',
      RPReset  => restart_i,
      Q(19 downto 0)  => tmp(i),
      Empty    => open,
      Full     => open
      );
  DEBUG(i) <= or_all(tmp(i));    
end generate;    


end architecture;