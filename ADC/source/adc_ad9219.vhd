library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;
use work.config.all;

entity adc_ad9219 is
  generic(
    NUM_DEVICES : integer := 5
  );
  port(
    CLK            : in  std_logic;
    CLK_ADCRAW     : in  std_logic;
    RESTART_IN     : in  std_logic;
    ADCCLK_OUT     : out std_logic;
    --FCO is another channel for each ADC    
    ADC_DATA       : in  std_logic_vector(NUM_DEVICES * (CHANNELS + 1) - 1 downto 0);
    ADC_DCO        : in  std_logic_vector(NUM_DEVICES downto 1);

    DATA_OUT       : out std_logic_vector(NUM_DEVICES * CHANNELS * RESOLUTION - 1 downto 0);
    FCO_OUT        : out std_logic_vector(NUM_DEVICES * RESOLUTION - 1 downto 0);
    DATA_VALID_OUT : out std_logic_vector(NUM_DEVICES - 1 downto 0);
    DEBUG          : out std_logic_vector(NUM_DEVICES * 32 - 1 downto 0)
  );
end entity;

architecture adc_ad9219_arch of adc_ad9219 is
  type q_t is array (0 to NUM_DEVICES - 1) of std_logic_vector(19 downto 0);
  signal q : q_t;

  signal clk_adcfast_i : std_logic;     --200MHz/325MHz
  signal clk_adcdata   : std_logic;     --100MHz/162.5MHz
  signal restart_i     : std_logic;

begin
  gen_40MHz : if ADC_SAMPLING_RATE = 40 generate
    THE_ADC_REF : entity work.pll_in200_out40
      port map(
        CLK   => CLK_ADCRAW,
        CLKOP => ADCCLK_OUT,
        LOCK  => open
      );
    THE_ADC_PLL_0 : entity work.pll_adc10bit
      port map(
        CLK   => CLK_ADCRAW,
        CLKOP => clk_adcfast_i,
        LOCK  => open
      );
  end generate;

  gen_65MHz : if ADC_SAMPLING_RATE = 65 generate
    THE_ADC_REF : entity work.pll_in200_out65
      port map(
        CLK   => CLK_ADCRAW,
        CLKOP => ADCCLK_OUT,
        LOCK  => open
      );
    THE_ADC_PLL_0 : entity work.pll_adc10bit_65
      port map(
        CLK   => CLK_ADCRAW,
        CLKOP => clk_adcfast_i,
        LOCK  => open
      );
  end generate;

  restart_i <= RESTART_IN when rising_edge(clk_adcdata);

  gen_7 : if NUM_DEVICES = 7 generate
    THE_7 : entity work.dqsinput_7x5
      port map(
        clk_0        => ADC_DCO(1),
        clk_1        => ADC_DCO(2),
        clk_2        => ADC_DCO(3),
        clk_3        => ADC_DCO(4),
        clk_4        => ADC_DCO(5),
        clk_5        => ADC_DCO(6),
        clk_6        => ADC_DCO(7),
        clkdiv_reset => RESTART_IN,
        eclk         => clk_adcfast_i,
        reset_0      => restart_i,
        reset_1      => restart_i,
        reset_2      => restart_i,
        reset_3      => restart_i,
        reset_4      => restart_i,
        reset_5      => restart_i,
        reset_6      => restart_i,
        sclk         => clk_adcdata,
        datain_0     => ADC_DATA(4 downto 0),
        datain_1     => ADC_DATA(9 downto 5),
        datain_2     => ADC_DATA(14 downto 10),
        datain_3     => ADC_DATA(19 downto 15),
        datain_4     => ADC_DATA(24 downto 20),
        datain_5     => ADC_DATA(29 downto 25),
        datain_6     => ADC_DATA(34 downto 30),
        q_0          => q(0),
        q_1          => q(1),
        q_2          => q(2),
        q_3          => q(3),
        q_4          => q(4),
        q_5          => q(5),
        q_6          => q(6)
      );
  end generate;

  gen_5 : if NUM_DEVICES = 5 generate
    THE_5 : entity work.dqsinput_5x5
      port map(
        clk_0        => ADC_DCO(1),
        clk_1        => ADC_DCO(2),
        clk_2        => ADC_DCO(3),
        clk_3        => ADC_DCO(4),
        clk_4        => ADC_DCO(5),
        clkdiv_reset => RESTART_IN,
        eclk         => clk_adcfast_i,
        reset_0      => restart_i,
        reset_1      => restart_i,
        reset_2      => restart_i,
        reset_3      => restart_i,
        reset_4      => restart_i,
        sclk         => clk_adcdata,
        datain_0     => ADC_DATA(4 downto 0),
        datain_1     => ADC_DATA(9 downto 5),
        datain_2     => ADC_DATA(14 downto 10),
        datain_3     => ADC_DATA(19 downto 15),
        datain_4     => ADC_DATA(24 downto 20),
        q_0          => q(0),
        q_1          => q(1),
        q_2          => q(2),
        q_3          => q(3),
        q_4          => q(4)
      );
  end generate;

  gen_chips : for i in 0 to NUM_DEVICES - 1 generate
    THE_CHIP : entity work.adc_ad9219_chip
      port map(CLK            => CLK,
               CLK_ADC        => clk_adcdata,
               RESTART_IN     => RESTART_IN,
               ADC_Q          => q(i),
               DATA_OUT       => DATA_OUT(i * 40 + 39 downto i * 40 + 0),
               FCO_OUT        => FCO_OUT(i * 10 + 9 downto i * 10 + 0),
               DATA_VALID_OUT => DATA_VALID_OUT(i),
               DEBUG          => DEBUG(i * 32 + 31 downto i * 32 + 0)
      );
  end generate;

end architecture;



