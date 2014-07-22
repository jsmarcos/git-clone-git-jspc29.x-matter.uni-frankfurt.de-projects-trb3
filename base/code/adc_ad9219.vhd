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
    CLK_ADCRAW : in std_logic;
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

type s_t is array(0 to 11) of integer range 0 to 1;
constant fpgaside : s_t := (0,0,0,0,0,0,1,0,1,1,1,1);

type q_t is array(0 to 11) of std_logic_vector(19 downto 0);
signal q : q_t;
signal tmp : q_t;

signal clk_adcfast_i : std_logic_vector(1 downto 0); --200MHz
signal clk_data      : std_logic_vector(1 downto 0); --100MHz
signal restart_i  : std_logic_vector(1 downto 0);

type state_t is (S1,S2,S3,S4,S5);
type states_t is array(0 to 11) of state_t;
signal state : states_t;

type value_it is array(0 to 4) of std_logic_vector(9 downto 0);
type value_t is array(0 to 11) of value_it;
signal value : value_t;
signal fifo_input : value_t;

type fifo_t is array(0 to 11) of std_logic_vector(49 downto 0);
signal fifo_output: fifo_t;

signal fifo_write      : std_logic_vector(11 downto 0);
signal fifo_empty      : std_logic_vector(11 downto 0);
signal fifo_last_empty : std_logic_vector(11 downto 0);


begin

  THE_ADC_REF : entity work.pll_in200_out40
    port map(
      CLK   => CLK_ADCRAW,
      CLKOP => ADCCLK_OUT,
      LOCK  => open
      );

  THE_ADC_PLL_0 : entity work.pll_adc10bit
    port map(
      CLK   => CLK_ADCRAW,
      CLKOP => clk_adcfast_i(0),
      LOCK  => open
      );
      
  THE_ADC_PLL_1 : entity work.pll_adc10bit
    port map(
      CLK   => CLK_ADCRAW,
      CLKOP => clk_adcfast_i(1),
      LOCK  => open
      );

 
  restart_i(0) <= RESTART_IN when rising_edge(clk_data(0));
  restart_i(1) <= RESTART_IN when rising_edge(clk_data(1));

THE_LEFT : entity work.dqsinput_7x5
    port map(
        clk_0  => ADC_DCO(1),
        clk_1  => ADC_DCO(2), 
        clk_2  => ADC_DCO(3), 
        clk_3  => ADC_DCO(4),
        clk_4  => ADC_DCO(5),
        clk_5  => ADC_DCO(6),
        clk_6  => ADC_DCO(8),
        clkdiv_reset => restart_i(0),
        eclk   => clk_adcfast_i(0), 
        reset_0 => restart_i(0),
        reset_1 => restart_i(0), 
        reset_2 => restart_i(0),
        reset_3 => restart_i(0),
        reset_4 => restart_i(0),
        reset_5 => restart_i(0),
        reset_6 => restart_i(0),
        sclk    => clk_data(0),
        datain_0 => ADC_DATA( 4 downto  0),
        datain_1 => ADC_DATA( 9 downto  5),
        datain_2 => ADC_DATA(14 downto 10),
        datain_3 => ADC_DATA(19 downto 15),
        datain_4 => ADC_DATA(24 downto 20),
        datain_5 => ADC_DATA(29 downto 25),
        datain_6 => ADC_DATA(39 downto 35),
        q_0      => q(0),
        q_1      => q(1),
        q_2      => q(2),
        q_3      => q(3),
        q_4      => q(4),
        q_5      => q(5),
        q_6      => q(7)
        );
  
THE_RIGHT : entity work.dqsinput_5x5
    port map(
        clk_0  => ADC_DCO(7),
        clk_1  => ADC_DCO(9), 
        clk_2  => ADC_DCO(10), 
        clk_3  => ADC_DCO(11),
        clk_4  => ADC_DCO(12),
        clkdiv_reset => restart_i(1),
        eclk   => clk_adcfast_i(1), 
        reset_0 => restart_i(1),
        reset_1 => restart_i(1), 
        reset_2 => restart_i(1),
        reset_3 => restart_i(1),
        reset_4 => restart_i(1),
        sclk    => clk_data(1),
        datain_0 => ADC_DATA(34 downto 30),
        datain_1 => ADC_DATA(44 downto 40),
        datain_2 => ADC_DATA(49 downto 45),
        datain_3 => ADC_DATA(54 downto 50),
        datain_4 => ADC_DATA(59 downto 55),
        q_0      => q(6),
        q_1      => q(8),
        q_2      => q(9),
        q_3      => q(10),
        q_4      => q(11)
        );
        
        
gen_chips_left : for i in 0 to DEVICES_LEFT+DEVICES_RIGHT-1 generate

  proc_collect_data : process begin
    wait until rising_edge(clk_data(fpgaside(i)));
    fifo_write(i) <= '0';
    case state(i) is
      when S1 =>
        if q(i)(19 downto 16) = x"0011" then
          state(i) <= S2;
          value(i)(0)(9 downto 8) <= q(i)(1  downto 0 );
          value(i)(1)(9 downto 8) <= q(i)(5  downto 4 );
          value(i)(2)(9 downto 8) <= q(i)(9  downto 8 );
          value(i)(3)(9 downto 8) <= q(i)(13 downto 12);
          value(i)(4)(9 downto 8) <= q(i)(17 downto 16);
          
          fifo_input(i) <= value(i);
          fifo_input(i)(0)(1 downto 0) <= q(i)(3  downto 2 );
          fifo_input(i)(1)(1 downto 0) <= q(i)(7  downto 6 );
          fifo_input(i)(2)(1 downto 0) <= q(i)(11 downto 10);
          fifo_input(i)(3)(1 downto 0) <= q(i)(15 downto 14);
          fifo_input(i)(4)(1 downto 0) <= q(i)(19 downto 18);
          fifo_write(i) <= '1';
        end if;
      when S2 =>  
          state(i) <= S3;
          value(i)(0)(7 downto 4) <= q(i)(3  downto 0 );
          value(i)(1)(7 downto 4) <= q(i)(7  downto 4 );
          value(i)(2)(7 downto 4) <= q(i)(11 downto 8 );
          value(i)(3)(7 downto 4) <= q(i)(15 downto 12);
          value(i)(4)(7 downto 4) <= q(i)(19 downto 16);
      when S3 =>  
          state(i) <= S4;
          fifo_input(i) <= value(i);
          fifo_input(i)(0)(3 downto 0) <= q(i)(3  downto 0 );
          fifo_input(i)(1)(3 downto 0) <= q(i)(7  downto 4 );
          fifo_input(i)(2)(3 downto 0) <= q(i)(11 downto 8 );
          fifo_input(i)(3)(3 downto 0) <= q(i)(15 downto 12);
          fifo_input(i)(4)(3 downto 0) <= q(i)(19 downto 16);
          fifo_write(i) <= '1';
      when S4 =>
          state(i) <= S5;
          value(i)(0)(9 downto 6) <= q(i)(3  downto 0 );
          value(i)(1)(9 downto 6) <= q(i)(7  downto 4 );
          value(i)(2)(9 downto 6) <= q(i)(11 downto 8 );
          value(i)(3)(9 downto 6) <= q(i)(15 downto 12);
          value(i)(4)(9 downto 6) <= q(i)(19 downto 16);
      when S5 =>    
          state(i) <= S1;
          value(i)(0)(5 downto 2) <= q(i)(3  downto 0 );
          value(i)(1)(5 downto 2) <= q(i)(7  downto 4 );
          value(i)(2)(5 downto 2) <= q(i)(11 downto 8 );
          value(i)(3)(5 downto 2) <= q(i)(15 downto 12);
          value(i)(4)(5 downto 2) <= q(i)(19 downto 16);
    end case;
    if restart_i(fpgaside(i)) = '1' then
      state(i) <= S1;
    end if;
  end process;

  THE_FIFO : fifo_cdt_200   --60*16
    port map(
      Data(9 downto   0)  => fifo_input(i)(0),
      Data(19 downto 10)  => fifo_input(i)(1),
      Data(29 downto 20)  => fifo_input(i)(2),
      Data(39 downto 30)  => fifo_input(i)(3),
      Data(49 downto 40)  => fifo_input(i)(4),
      WrClock  => clk_data(fpgaside(i)),
      RdClock  => CLK,
      WrEn     => fifo_write(i),
      RdEn     => '1',
      Reset    => restart_i(fpgaside(i)),
      RPReset  => RESTART_IN,
      Q(49 downto 0)        => fifo_output(i),
      Empty    => fifo_empty(i),
      Full     => open
      );
  DEBUG(i) <= or_all(tmp(i));    
  
  proc_output : process begin
    wait until rising_edge(CLK);
    if fifo_last_empty(i) = '0' then
      DATA_OUT(i*40+39 downto i*40+0) <= fifo_output(i)(39 downto 0);
      FCO_OUT (i*10+9  downto i*10+0) <= fifo_output(i)(49 downto 40);
      DATA_VALID_OUT(i)               <= '1';
    else
      DATA_VALID_OUT(i)               <= '0';
    end if;
  end process;
  
end generate;    



end architecture;



