library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;
use work.config.all;

entity adc_ad9219_chip is
  port(
    CLK            : in  std_logic;
    CLK_ADC        : in  std_logic;
    RESTART_IN     : in  std_logic;
    --FCO is another channel for each ADC, so no -1 here   
    ADC_Q          : in  std_logic_vector(19 downto 0);

    DATA_OUT       : out std_logic_vector(CHANNELS * RESOLUTION - 1 downto 0);
    FCO_OUT        : out std_logic_vector(RESOLUTION - 1 downto 0);
    DATA_VALID_OUT : out std_logic;
    DEBUG          : out std_logic_vector(31 downto 0)
  );
end entity;

architecture adc_ad9219_chip_arch of adc_ad9219_chip is
  -- Placer Directives
  --attribute HGROUP : string;
  --attribute HGROUP of adc_ad9219_chip_arch : architecture  is "ADC_AD9219_CHIP_group";
  
  signal qq, qqq : std_logic_vector(19 downto 0);

  signal clk_adcdata : std_logic;       --100MHz/162.5MHz
  signal restart_i   : std_logic;

  signal counter : unsigned(27 downto 0);

  type state_t is (S1, S2, S3, S4, S5);
  signal state   : state_t;
  signal state_q : state_t;

  type value_it is array (0 to 4) of std_logic_vector(9 downto 0);
  signal value      : value_it;
  signal fifo_input : value_it;

  signal fifo_output : std_logic_vector(49 downto 0);

  signal fifo_write      : std_logic;
  signal fifo_empty      : std_logic;
  signal fifo_last_empty : std_logic;

begin
  clk_adcdata <= CLK_ADC;

  restart_i <= RESTART_IN when rising_edge(clk_adcdata);

  qq <= ADC_Q when rising_edge(clk_adcdata);

  gen_data_mapping : for j in 0 to CHANNELS generate
    gen_data_mapping_bits : for k in 0 to 3 generate
      qqq(j * 4 + 3 - k) <= qq(k * (CHANNELS + 1) + j);
    end generate;
  end generate;

  proc_collect_data : process
  begin
    wait until rising_edge(clk_adcdata);
    fifo_write <= '0';
    case state is
      when S1 =>
        if qqq(19 downto 16) = "0011" then
          state                <= S2;
          value(0)(9 downto 8) <= qqq(1 downto 0);
          value(1)(9 downto 8) <= qqq(5 downto 4);
          value(2)(9 downto 8) <= qqq(9 downto 8);
          value(3)(9 downto 8) <= qqq(13 downto 12);
          value(4)(9 downto 8) <= qqq(17 downto 16);

          fifo_input                <= value;
          fifo_input(0)(1 downto 0) <= qqq(3 downto 2);
          fifo_input(1)(1 downto 0) <= qqq(7 downto 6);
          fifo_input(2)(1 downto 0) <= qqq(11 downto 10);
          fifo_input(3)(1 downto 0) <= qqq(15 downto 14);
          fifo_input(4)(1 downto 0) <= qqq(19 downto 18);
          fifo_write                <= '1';
        end if;
      when S2 =>
        state                <= S3;
        value(0)(7 downto 4) <= qqq(3 downto 0);
        value(1)(7 downto 4) <= qqq(7 downto 4);
        value(2)(7 downto 4) <= qqq(11 downto 8);
        value(3)(7 downto 4) <= qqq(15 downto 12);
        value(4)(7 downto 4) <= qqq(19 downto 16);
      when S3 =>
        state                     <= S4;
        fifo_input                <= value;
        fifo_input(0)(3 downto 0) <= qqq(3 downto 0);
        fifo_input(1)(3 downto 0) <= qqq(7 downto 4);
        fifo_input(2)(3 downto 0) <= qqq(11 downto 8);
        fifo_input(3)(3 downto 0) <= qqq(15 downto 12);
        fifo_input(4)(3 downto 0) <= qqq(19 downto 16);
        fifo_write                <= '1';
      when S4 =>
        state                <= S5;
        value(0)(9 downto 6) <= qqq(3 downto 0);
        value(1)(9 downto 6) <= qqq(7 downto 4);
        value(2)(9 downto 6) <= qqq(11 downto 8);
        value(3)(9 downto 6) <= qqq(15 downto 12);
        value(4)(9 downto 6) <= qqq(19 downto 16);
      when S5 =>
        state                <= S1;
        value(0)(5 downto 2) <= qqq(3 downto 0);
        value(1)(5 downto 2) <= qqq(7 downto 4);
        value(2)(5 downto 2) <= qqq(11 downto 8);
        value(3)(5 downto 2) <= qqq(15 downto 12);
        value(4)(5 downto 2) <= qqq(19 downto 16);
    end case;
    if restart_i = '1' then
      state <= S1;
    end if;
  end process;

  THE_FIFO : entity work.fifo_cdt_200_50 --50*16
    port map(
      Data(9 downto 0)   => fifo_input(0),
      Data(19 downto 10) => fifo_input(1),
      Data(29 downto 20) => fifo_input(2),
      Data(39 downto 30) => fifo_input(3),
      Data(49 downto 40) => fifo_input(4),
      WrClock            => clk_adcdata,
      RdClock            => CLK,
      WrEn               => fifo_write,
      RdEn               => '1',
      Reset              => '0',
      RPReset            => RESTART_IN,
      Q(49 downto 0)     => fifo_output,
      Empty              => fifo_empty,
      Full               => open
    );

  proc_output : process
  begin
    wait until rising_edge(CLK);
    fifo_last_empty <= fifo_empty;
    if fifo_last_empty = '0' then
      DATA_OUT(39 downto 0) <= fifo_output(39 downto 0);
      FCO_OUT(9 downto 0)   <= fifo_output(49 downto 40);
      DATA_VALID_OUT        <= '1';
      counter               <= counter + 1;
    else
      DATA_VALID_OUT <= '0';
    end if;
  end process;

  proc_debug : process
  begin
    wait until rising_edge(CLK);
    DEBUG(31 downto 4) <= std_logic_vector(counter);
    case state_q is
      when S1 => DEBUG(3 downto 0) <= x"1";
      when S2 => DEBUG(3 downto 0) <= x"2";
      when S3 => DEBUG(3 downto 0) <= x"3";
      when S4 => DEBUG(3 downto 0) <= x"4";
      when S5 => DEBUG(3 downto 0) <= x"5";
    end case;
  end process;

  state_q <= state when rising_edge(CLK);

end architecture;



